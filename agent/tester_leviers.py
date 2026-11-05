# =====================================================================
# ESSAI DES LEVIERS 1, 2 et 3 (05/11/2026) — sans rien publier
# ---------------------------------------------------------------------
# Sur les dernières fiches publiées qui ont d'autres sources :
#   AVANT : rédaction à partir du seul article principal, vérifications d'avant ;
#   APRÈS : article principal + jusqu'à 2 autres sources (levier 1), seuil de
#           richesse (levier 2, indiqué), nouvelles vérifications (levier 3).
# Rapport : agent/essai/rapport_leviers.md
# =====================================================================

import os
import sys
import time
from datetime import datetime, timedelta, timezone

import requests
from anthropic import Anthropic

import main as agent
import redaction

MODELE, PRIX = "claude-haiku-5-5", (0.10, 0.50)
NB = int(os.environ.get("NB") or 8)


def bloc(nom, f):
    if not f:
        return f"**{nom}** : (échec)\n"
    mots = " ; ".join(f"**{m.get('mot')}** → {m.get('definition')}" for m in f.get("mots") or []) or "(aucun)"
    return (f"**{nom}**\n\n- **Titre** : {f.get('title')}\n- **Avant** : {f.get('avant')}\n"
            f"- **Découverte** : {f.get('decouverte')}\n- **Et après** : {f.get('apres')}\n"
            f"- **Mots** : {mots}\n- **Type** : {f.get('type_etude')}\n")


def main() -> int:
    client = Anthropic()
    db = agent.Supabase(os.environ["SUPABASE_URL"], os.environ["SUPABASE_SECRET_KEY"])
    depuis = (datetime.now(timezone.utc) - timedelta(days=12)).isoformat()
    r = requests.get(db.base, headers=db.headers, timeout=30, params={
        "select": "title,feed,importance,type_etude,source_url,source_name,autres_sources,created_at",
        "created_at": f"gte.{depuis}", "order": "created_at.desc", "limit": "200"})
    r.raise_for_status()
    fiches = [f for f in r.json() if f.get("autres_sources")]
    print(f"{len(fiches)} fiches récentes avec d'autres sources", flush=True)
    cas = []
    for f in fiches:
        if len(cas) >= NB:
            break
        art = {"url": f["source_url"], "source_name": f["source_name"], "title": f["title"], "text": ""}
        agent.lire_page(art)
        if not art.get("page_lue") or len(art["text"]) < agent.TEXTE_MIN:
            continue
        art["_membres"] = [{"url": s.get("url"), "source_name": s.get("nom"), "text": ""}
                           for s in f["autres_sources"] if s.get("url")]
        agent.lire_complements(art)
        cas.append((f, art))
    print(f"{len(cas)} articles retenus pour l'essai", flush=True)
    items_avant = [(f"c{i}", art, f["feed"], {"title": f["title"], "importance": f["importance"],
                                              "type_etude": f.get("type_etude")}) for i, (f, art) in enumerate(cas)]
    items_apres = [(cid, agent.texte_pour_redaction(art), fil, br) for cid, art, fil, br in items_avant]
    redaction.VERIFS_V2 = False
    avant, c_avant = redaction.rediger_lot(client, MODELE, PRIX, items_avant, log=lambda m: print(m, flush=True))
    redaction.VERIFS_V2 = True
    apres, c_apres = redaction.rediger_lot(client, MODELE, PRIX, items_apres, log=lambda m: print(m, flush=True))
    out = [f"# Essai des leviers 1, 2 et 3 — {time.strftime('%d/%m/%Y %H:%M')} UTC\n",
           "AVANT = article principal seul + vérifications d'avant · APRÈS = + autres sources (levier 1), "
           "seuil de richesse (levier 2), nouvelles vérifications (levier 3). Rien n'est publié.\n",
           f"Coût : avant {c_avant:.4f} $ · après {c_apres:.4f} $\n"]
    for i, (f, art) in enumerate(cas):
        cid = f"c{i}"
        total = len(art["text"]) + sum(len(t) for _, t in art.get("_complements", []))
        verdict = "garde" if total >= agent.TEXTE_RICHE else f"ÉCARTÉ par le levier 2 ({total} < {agent.TEXTE_RICHE})"
        comp = ", ".join(f"{n} ({len(t)} car.)" for n, t in art.get("_complements", [])) or "aucune lisible"
        out.append(f"\n---\n\n## {i + 1}. {f['title']}\n\nPrincipal : {art['source_name']} ({len(art['text'])} car.) · "
                   f"autres sources lues : {comp} · levier 2 : {verdict}\n")
        for nom, res in (("AVANT", avant), ("APRÈS", apres)):
            x = res.get(cid) or {}
            redaction.VERIFS_V2 = True       # mêmes vérifications pour comparer
            restants = redaction.verifications(x["finale"]) if x.get("finale") else []
            out.append(bloc(f"{nom} ({x.get('relectures', 0)} relecture(s), {x.get('cout', 0):.4f} $)", x.get("finale")))
            out.append(f"- _Défauts mesurés restants_ : {' ; '.join(restants) or 'aucun'}\n")
    os.makedirs("essai", exist_ok=True)
    with open("essai/rapport_leviers.md", "w", encoding="utf-8") as fh:
        fh.write("\n".join(out))
    print(f"Coût total : {c_avant + c_apres:.4f} $", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
