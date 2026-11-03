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
    r = requests.get(base, headers=h, timeout=30, params={"select": champs, "avant": "not.is.null",
                                                          "order": "created_at.desc", "limit": str(nb * 2),
                                                          "offset": str(decalage)})
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
    for i, f in enumerate(liste, 1):
        art = {"url": f["source_url"], "source_name": f["source_name"], "title": f["title"], "text": ""}
        agent.lire_page(art)
        out.append(f"\n---\n\n## {i}. {f['title']}\n\nFil : {f['feed']} · {f['importance']}★ · "
                   f"source : {f['source_name']} · page lue : {'oui' if art.get('page_lue') else 'NON'} "
                   f"({len(art.get('text', ''))} caractères) · {f['source_url']}\n")
        out.append(bloc("Actuel (publié)", f))
        if not art.get("text"):
            out.append("_Article illisible : pas de réécriture._\n")
            continue
        for nom in noms:
            if cout > plafond:
                out.append(f"_Plafond de coût atteint ({plafond} $)._\n")
                break
            modele, prix = MODELES[nom]
            res = redaction.rediger_complet(client, modele, prix, art, f["feed"], f)
            jetons["fiches"] += 1
            for k in ("in", "out", "cache_r", "cache_w"):
                jetons[k] += res["jetons"][k]
            cout += res["cout"]
            d, r = res["redacteur"], res["finale"]
            if not d:
                out.append(f"**{nom}** : échec de la réécriture ({res['diag']})\n")
                continue
            if r:
                pbs = res["problemes"]
                out.append(bloc(f"Final après {res['relectures']} relecture(s) ({nom})", r))
                out.append("- _Défauts trouvés par le relecteur_ : "
                           + (" | ".join(f"[{p.get('type')}] « {p.get('extrait')} » → {p.get('explication')}" for p in pbs)
                              or "aucun") + "\n")
                out.append(f"- _Défauts mesurés restants_ : {' ; '.join(res['restants']) or 'aucun'} · coût {res['cout']:.4f} $\n")
            else:
                out.append(f"_Relecture impossible ({res['diag']})_\n")
            out.append(bloc(f"Version du rédacteur ({nom})", d))
            out.append(f"- _Faits relevés_ : {' | '.join(d.get('faits') or [])}\n"
                       f"- _Nouveauté selon l'article_ : {d.get('nouveaute')}\n"
                       f"- _Jargon_ : {' | '.join(d.get('jargon') or [])}\n"
                       f"- _Contrôle_ : {json.dumps(d.get('controle'), ensure_ascii=False)}\n"
                       f"- _Alertes automatiques_ : {' ; '.join(redaction.alertes(d)) or 'aucune'}\n")
        print(f"  {i}/{len(liste)} · coût cumulé {cout:.4f} $", flush=True)
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
