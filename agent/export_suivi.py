"""Copie privée pour le suivi qualité (27/11/2026, demandé par Maxime).

Après chaque passage, ce script dépose dans le repo PRIVÉ `novastem-suivi` :
  • passages/<date>-<run>/sources/<id>.json : le texte de l'article lu par l'agent pour chaque fiche publiée
    (pour vérifier l'exactitude ; jamais publié : le repo principal est public, celui-ci est privé) ;
  • passages/<date>-<run>/lectures.json : le nombre anonyme de lectures, d'articles ouverts, de favoris,
    de partages et de masquages par fiche sur les 7 derniers jours (table stats ; aucune donnée personnelle).
Les dossiers de plus de 14 jours sont supprimés. Gratuit, aucun appel à Claude.
Sans le secret SUIVI_TOKEN, le script ne fait rien (jamais bloquant pour l'agent).
"""
import glob
import json
import os
import shutil
import subprocess
import sys
import tempfile
from collections import defaultdict
from datetime import datetime, timedelta, timezone

import requests

TOKEN = os.environ.get("SUIVI_TOKEN", "").strip()
DEPOT = os.environ.get("SUIVI_DEPOT", "jd136413-lab/novastem-suivi")
GARDER_JOURS = 14
EVENEMENTS = ("lecture", "article", "favori", "partage", "masquee")


def lectures() -> dict:
    base = os.environ["SUPABASE_URL"].rstrip("/") + "/rest/v1"
    cle = os.environ["SUPABASE_SECRET_KEY"]
    h = {"apikey": cle, "Authorization": f"Bearer {cle}"}
    depuis = (datetime.now(timezone.utc) - timedelta(days=7)).isoformat()
    lignes, debut = [], 0
    while debut < 200000:                       # Supabase renvoie au plus 1 000 lignes par appel
        r = requests.get(f"{base}/stats", headers=h, timeout=60, params={
            "select": "evenement,avancee_id,valeur", "cree_le": f"gte.{depuis}", "avancee_id": "not.is.null",
            "evenement": f"in.({','.join(EVENEMENTS)})", "order": "id.asc", "offset": str(debut), "limit": "1000"})
        r.raise_for_status()
        lignes += r.json()
        if len(r.json()) < 1000:
            break
        debut += 1000
    par_fiche = defaultdict(lambda: defaultdict(int))
    origines = defaultdict(lambda: defaultdict(int))
    for s in lignes:
        par_fiche[s["avancee_id"]][s["evenement"]] += 1
        if s["evenement"] == "lecture" and s.get("valeur"):
            origines[s["avancee_id"]][s["valeur"][:30]] += 1
    ids = list(par_fiche)
    fiches = {}
    for i in range(0, len(ids), 100):
        q = requests.get(f"{base}/advances", headers=h, timeout=60, params={
            "select": "id,title,feed,family,importance,created_at", "id": f"in.({','.join(ids[i:i + 100])})"})
        if q.ok:
            fiches.update({f["id"]: f for f in q.json()})
    res = []
    for id_, c in par_fiche.items():
        f = fiches.get(id_, {})
        res.append({"id": id_, "titre": f.get("title"), "fil": f.get("feed"), "famille": f.get("family"),
                    "etoiles": f.get("importance"), "ajoutee": f.get("created_at"), **dict(c),
                    "origine_lectures": dict(origines.get(id_, {}))})
    res.sort(key=lambda x: -x.get("lecture", 0))
    return {"periode": "7 derniers jours", "genere_le": datetime.now(timezone.utc).isoformat(), "fiches": res}


def main():
    if not TOKEN:
        print("ℹ Suivi qualité : secret SUIVI_TOKEN absent, aucune copie privée.")
        return
    jour = datetime.now(timezone.utc).strftime("%Y-%m-%d-%H%M")
    dossier_run = f"passages/{jour}-{os.environ.get('GITHUB_RUN_ID', 'local')}"
    tmp = tempfile.mkdtemp()
    url = f"https://x-access-token:{TOKEN}@github.com/{DEPOT}.git"
    if subprocess.run(["git", "clone", "--depth", "1", "-q", url, tmp], capture_output=True).returncode != 0:
        print("⚠ Suivi qualité : repo privé inaccessible (nom ou jeton à vérifier).")
        return
    cible = os.path.join(tmp, dossier_run)
    os.makedirs(os.path.join(cible, "sources"), exist_ok=True)
    n = 0
    for f in glob.glob("sources_suivi/*.json"):
        shutil.copy(f, os.path.join(cible, "sources"))
        n += 1
    try:
        json.dump(lectures(), open(os.path.join(cible, "lectures.json"), "w", encoding="utf-8"),
                  ensure_ascii=False, indent=1)
    except Exception as ex:
        print(f"⚠ Suivi qualité : lectures non exportées ({ex.__class__.__name__})")
    limite = (datetime.now(timezone.utc) - timedelta(days=GARDER_JOURS)).strftime("%Y-%m-%d")
    for d in glob.glob(os.path.join(tmp, "passages", "*")):
        if os.path.basename(d)[:10] < limite:
            shutil.rmtree(d, ignore_errors=True)
    git = ["git", "-C", tmp, "-c", "user.name=agent-novastem", "-c", "user.email=agent@novastem.invalid"]
    subprocess.run(git + ["add", "-A"], check=True)
    subprocess.run(git + ["commit", "-q", "-m", f"Passage {jour} : {n} source(s) + lectures"], capture_output=True)
    p = subprocess.run(git + ["push", "-q"], capture_output=True)
    print(f"{'✔' if p.returncode == 0 else '⚠'} Suivi qualité : {n} source(s) et les lectures copiées dans le repo privé.")


if __name__ == "__main__":
    try:
        main()
    except Exception as ex:                       # jamais bloquant
        print(f"⚠ Suivi qualité : copie privée non faite ({ex.__class__.__name__})")
    sys.exit(0)
