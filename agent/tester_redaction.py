# =====================================================================
# TEST DE LA RÉDACTION (redaction.py) — sans rien publier
# ---------------------------------------------------------------------
# Prend des fiches déjà publiées, relit leur article source, demande à
# Claude de les réécrire avec la nouvelle consigne (un ou plusieurs
# modèles) et écrit un rapport « avant / après » dans
# agent/tests_redaction.md. Aucune écriture dans la base.
# Workflow « Tester la rédaction » (branche « redaction/… »).
# Réglages par variables d'environnement : MODELES (ex. « haiku,sonnet »),
# NB (nombre de fiches récentes), TITRES (morceaux de titres à inclure,
# séparés par « | »), PLAFOND (coût maximum en $).
# =====================================================================

import json
import os
import sys
import time

import requests
from anthropic import Anthropic

import main as agent
import redaction

MODELES = {"haiku": ("claude-haiku-5-5", (0.10, 0.50)), "sonnet": ("claude-sonnet-5-5", (2.00, 10.00))}


def fiches(base: str, cle: str, nb: int, titres: list[str], decalage: int = 0) -> list[dict]:
    h = {"apikey": cle, "Authorization": f"Bearer {cle}"}
    champs = "id,title,feed,importance,theme,source_url,source_name,avant,decouverte,apres,mots,type_etude,created_at"
    res, vus = [], set()
    for t in titres:
        r = requests.get(base, headers=h, timeout=30, params={"select": champs, "title": f"ilike.*{t}*", "limit": "1",
                                                              "order": "created_at.desc"})
        for f in r.json() if r.ok else []:
            if f["id"] not in vus:
                vus.add(f["id"]), res.append(f)
    params = {"select": champs, "avant": "not.is.null", "order": "created_at.desc", "limit": str(nb * 2),
              "offset": str(decalage)}
    if os.environ.get("DEPUIS"):                       # bilan sur une période (08/11)
        params["created_at"] = "gte." + os.environ["DEPUIS"]
    r = requests.get(base, headers=h, timeout=30, params=params)
    for f in r.json() if r.ok else []:
        if len(res) >= nb + len(titres):
            break
        if f["id"] not in vus:
            vus.add(f["id"]), res.append(f)
    return res


def bloc(nom: str, f: dict) -> str:
    mots = " ; ".join(f"**{m.get('mot')}** → {m.get('definition')}" for m in f.get("mots") or []) or "(aucun)"
    return (f"**{nom}**\n\n- **Titre** : {f.get('title')}\n- **Avant** : {f.get('avant')}\n"
            f"- **Découverte** : {f.get('decouverte')}\n- **Et après** : {f.get('apres')}\n"
            f"- **Mots** : {mots}\n- **Type** : {f.get('type_etude')}\n")


def main() -> int:
    client = Anthropic()
    base = os.environ["SUPABASE_URL"].rstrip("/") + "/rest/v1/advances"
    cle = os.environ["SUPABASE_SECRET_KEY"]
    noms = [m.strip() for m in (os.environ.get("MODELES") or "haiku").split(",") if m.strip() in MODELES]
    nb = int(os.environ.get("NB") or 8)
    titres = [t.strip() for t in (os.environ.get("TITRES") or "").split("|") if t.strip()]
    plafond = float(os.environ.get("PLAFOND") or 1.0)
    liste = fiches(base, cle, nb, titres, int(os.environ.get("DECALAGE") or 0))
    print(f"{len(liste)} fiche(s) à tester avec {', '.join(noms)}", flush=True)
    out = [f"# Test de la rédaction — {time.strftime('%d/%m/%Y %H:%M')} UTC\n",
           f"Modèles : {', '.join(noms)} · {len(liste)} fiches\n"]
    cout = 0.0
    jetons = {"in": 0, "out": 0, "cache_r": 0, "cache_w": 0, "fiches": 0}
    nom = noms[0]
    modele, prix = MODELES[nom]
    entetes, items = {}, []
    for i, f in enumerate(liste, 1):
        art = {"url": f["source_url"], "source_name": f["source_name"], "title": f["title"], "text": ""}
        if not os.environ.get("SANS_LECTURE"):
            agent.lire_page(art)
        entetes[i] = [f"\n---\n\n## {i}. {f['title']}\n\nFil : {f['feed']} · {f['importance']}★ · "
                      f"source : {f['source_name']} · page lue : {'oui' if art.get('page_lue') else 'NON'} "
                      f"({len(art.get('text', ''))} caractères) · {f['source_url']}\n", bloc("Actuel (publié)", f)]
        if os.environ.get("LECTURE_SEULE"):          # relire les fiches publiées, sans appel à Claude
            entetes[i].append(f"- _Mesures automatiques_ : {' ; '.join(redaction.verifications(f)) or 'aucun défaut'}\n"
                              f"- _Ajoutée le_ : {f.get('created_at')}\n")
            continue
        if len(art.get("text", "")) < agent.TEXTE_MIN or not art.get("page_lue"):
            entetes[i].append("_Article illisible ou trop court : pas de fiche (comme dans l'agent)._\n")
            continue
        # Comme dans l'agent depuis le 04/11 : le trieur ne donne qu'un titre provisoire
        brouillon = {k: f.get(k) for k in ("title", "importance", "type_etude")} if os.environ.get("TRI_SEUL") else f
        items.append((f"f{i}", art, f["feed"], brouillon))
    resultats, cout = ({}, 0.0) if not items else redaction.rediger_lot(
        client, modele, prix, items, par_lot=bool(os.environ.get("PAR_LOT")), attente_lot=900,
        log=lambda m: print(m, flush=True))
    for i in entetes:
        out += entetes[i]
        res = resultats.get(f"f{i}")
        if not res:
            continue
        jetons["fiches"] += 1
        for k in ("in", "out", "cache_r", "cache_w"):
            jetons[k] += res["jetons"][k]
        d, r = res["redacteur"], res["finale"]
        if not d:
            out.append(f"**{nom}** : échec de la réécriture ({res['diag']})\n")
            continue
        if r:
            pbs = res["problemes"]
            out.append(bloc(f"Final après {res['relectures']} relecture(s) ({nom}{', lot' if res['lot'] else ''})", r))
            out.append("- _Défauts trouvés par le relecteur_ : "
                       + (" | ".join(f"[{p.get('type')}] « {p.get('extrait')} » → {p.get('explication')}" for p in pbs)
                          or "aucun") + "\n")
            out.append(f"- _Défauts mesurés restants_ : {' ; '.join(res['restants']) or 'aucun'} · coût {res['cout']:.4f} $\n")
        out.append(bloc(f"Version du rédacteur ({nom})", d))
        out.append(f"- _Contrôle_ : {json.dumps(d.get('controle'), ensure_ascii=False)}\n")
    n = max(1, jetons["fiches"])
    out.append(f"\n---\n\nCoût total du test : {cout:.4f} $ · par fiche : {cout / n:.4f} $ · tokens moyens par fiche "
               f"(rédaction + relecture) : entrée {jetons['in'] // n}, cache lu {jetons['cache_r'] // n}, "
               f"cache écrit {jetons['cache_w'] // n}, sortie {jetons['out'] // n}\n")
    with open("tests_redaction.md", "w", encoding="utf-8") as fh:
        fh.write("\n".join(out))
    print(f"Coût total : {cout:.4f} $", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
