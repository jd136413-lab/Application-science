"""Essai Haiku / Sonnet / Haiku + accroche (18/11/2026, demande de Maxime). RIEN n'est publié.

Pour 5 fiches récentes (familles et fils variés), on relit l'article source UNE fois, puis on
fait rédiger la fiche trois fois, à partir d'exactement la même base (même texte d'article,
même titre provisoire, même importance, même rédaction + relecture que l'agent) :
  • H  : Haiku, consignes actuelles (ce que fait l'agent aujourd'hui) ;
  • S  : Sonnet, consignes actuelles ;
  • HA : Haiku, consignes actuelles + une règle « accroche » (1re phrase : le résultat et
         pourquoi il compte, avec une comparaison de la vie courante si l'article donne un chiffre).
Les 15 fiches sont écrites dans le journal, sous des lettres mélangées (X, Y, Z) pour une
comparaison à l'aveugle ; la correspondance est donnée tout à la fin. Coût prévu ≈ 0,35 $.
"""

import json
import os
import random
import sys

import requests
from anthropic import Anthropic

import main as agent
import redaction

N_FICHES = 5
PLAFOND = 0.80   # $ : arrêt de l'essai au-delà

ACCROCHE = """

# Règle en plus : ACCROCHE
La 1re phrase de « decouverte » donne le résultat principal ET pourquoi il compte (pour la vie courante, la santé, l'environnement ou la science), en mots simples, sans exagérer : l'intérêt doit venir de l'article, jamais de toi. Si l'article donne un chiffre clé, rends-le parlant avec une comparaison de la vie courante (« 6 minutes, le temps d'un café », « l'épaisseur d'un cheveu ») quand c'est exact. Le reste de la fiche ne change pas."""


def fiches_recentes(url: str, h: dict) -> list[dict]:
    r = requests.get(f"{url}/rest/v1/advances", headers=h, timeout=30, params={
        "select": "id,title,importance,family,feed,theme,source_url,source_name,avant,decouverte,apres,proposee",
        "order": "created_at.desc", "limit": "80"})
    r.raise_for_status()
    return [f for f in r.json() if not f.get("proposee") and (f.get("importance") or 0) >= 2]


def choisir(fiches: list[dict]) -> list[tuple[dict, dict]]:
    """5 fiches de familles différentes, en alternant les fils, dont l'article se lit bien."""
    choix, familles = [], set()
    for fil in ["science", "tech"] * 10:
        for f in fiches:
            if len(choix) >= N_FICHES:
                return choix
            if f["feed"] != fil or f["family"] in familles or any(f["id"] == c[0]["id"] for c in choix):
                continue
            art = {"url": f["source_url"], "title": f["title"], "text": "", "source_name": f["source_name"], "videos": []}
            agent.lire_page(art)
            if len(art.get("text", "")) >= 1500:
                choix.append((f, art))
                familles.add(f["family"])
                break
    return choix


def rediger(client, modele: str, art: dict, f: dict) -> tuple[dict | None, float]:
    m = agent.MODELES[modele]
    brouillon = {"title": f["title"], "importance": f["importance"], "theme": f["theme"]}   # pas de premier jet
    res, cout = redaction.rediger_lot(client, m["id"], m["prix"], [("x", art, f["feed"], brouillon)],
                                      par_lot=False, relectures_max=2, plafond=0.5, attente_lot=0, log=lambda *_: None)
    return (res.get("x") or {}).get("finale"), cout


def texte(fiche: dict | None) -> str:
    if not fiche:
        return "(échec de la rédaction)"
    mots = "; ".join(f"{m.get('mot', '')} = {m.get('definition', '')}" for m in fiche.get("mots") or [])
    return (f"TITRE : {fiche.get('title', '')}\nAVANT : {fiche.get('avant', '')}\n"
            f"DÉCOUVERTE : {fiche.get('decouverte', '')}\nET APRÈS : {fiche.get('apres', '')}\nMOTS : {mots}")


def principal() -> int:
    url = os.environ["SUPABASE_URL"].rstrip("/")
    cle = os.environ["SUPABASE_SECRET_KEY"]
    h = {"apikey": cle, "Authorization": f"Bearer {cle}"}
    client = Anthropic()
    choix = choisir(fiches_recentes(url, h))
    print(f"{len(choix)} fiches choisies.\n")
    consigne = redaction.CONSIGNE
    total, couts, cle_aveugle, sortie = 0.0, {"H": 0.0, "S": 0.0, "HA": 0.0}, {}, []
    rnd = random.Random(18112026)
    for k, (f, art) in enumerate(choix, 1):
        versions = {}
        for nom, modele, avec_accroche in (("H", "haiku", False), ("S", "sonnet", False), ("HA", "haiku", True)):
            if total >= PLAFOND:
                print("⛔ plafond atteint")
                break
            redaction.CONSIGNE = consigne + ACCROCHE if avec_accroche else consigne
            fiche, c = rediger(client, modele, art, f)
            redaction.CONSIGNE = consigne
            total += c
            couts[nom] += c
            versions[nom] = fiche
        lettres = ["X", "Y", "Z"]
        rnd.shuffle(lettres)
        cle_aveugle[k] = dict(zip(lettres, versions.keys()))
        bloc = [f"\n===== ARTICLE {k} — {f['feed']} · {f['family']} · {f['importance']}★ — {f['source_name']}",
                f"Source : {f['source_url']}",
                f"Fiche publiée aujourd'hui : {f['title']}"]
        for lettre, nom in sorted(cle_aveugle[k].items()):
            bloc.append(f"\n--- VERSION {lettre}\n{texte(versions.get(nom))}")
        sortie.append("\n".join(bloc))
        print(sortie[-1], flush=True)
    print("\n===== COÛTS (pour", len(choix), "fiches)")
    for nom, c in couts.items():
        print(f"  {nom} : {c:.4f} $ ({c / max(1, len(choix)):.4f} $ par fiche)")
    print(f"  Total : {total:.4f} $")
    print("\n===== CLÉ (à lire APRÈS avoir comparé)")
    print(json.dumps(cle_aveugle, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(principal())
