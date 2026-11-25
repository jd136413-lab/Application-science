"""Nettoyage ponctuel des cartes À venir déjà écrites (25/11, bilan du passage de 18h20).

Gratuit : aucun appel à Claude. Applique aux résumés à blocs déjà en base les règles ajoutées
le 25/11 (fiche_blocs) :
  • limites qui s'adressent à l'équipe (« à vérifier avant publication ») ou sur une étape passée : retirées ;
  • phrases qui s'adressent à l'équipe dans le chapô et les paragraphes : retirées ;
plus une correction de fond relevée à la relecture :
  • Europa Clipper : les 49 survols rapprochés concernent Europe, pas Ganymède.
Lancé à la main par le workflow « Corriger les cartes À venir ».
"""
import json
import os

import requests

import fiche_blocs as fb

URL = os.environ["SUPABASE_URL"].rstrip("/") + "/rest/v1/upcoming_events"
CLE = os.environ["SUPABASE_SECRET_KEY"]
ENTETES = {"apikey": CLE, "Authorization": f"Bearer {CLE}", "Content-Type": "application/json"}

CORRECTIONS = {   # (début du titre, ancien texte, nouveau texte)
    "europa": [("Nombre de passages prévus près de Ganymède", "Survols rapprochés d'Europe prévus")],
}


def nettoyer(blocs: list, titre: str) -> tuple[list, list]:
    notes, res = [], []
    for b in blocs:
        b = dict(b)
        if b.get("cle") == "limites":
            garde = fb.limites_finales(b.get("puces"), notes)
            if garde:
                res.append({**b, "puces": garde})
            continue
        if b.get("cle") == "en_chiffres":
            items = []
            for it in b.get("items") or []:
                it = dict(it)
                for cle, corr in CORRECTIONS.items():
                    if cle in titre.lower():
                        for avant, apres in corr:
                            if it.get("sens") == avant:
                                notes.append(f"chiffre corrigé : {avant} → {apres}")
                                it["sens"] = apres
                items.append(it)
            res.append({**b, "items": items})
            continue
        if b.get("texte"):
            t = fb.sans_note_redacteur(b["texte"])
            if t != b["texte"]:
                notes.append(f"phrase pour l'équipe retirée ({b.get('cle')})")
            if not t:
                continue
            b["texte"] = t
        res.append(b)
    return res, notes


def main():
    r = requests.get(URL, headers=ENTETES, timeout=30,
                     params={"select": "id,title,blocs", "blocs": "neq.[]", "limit": "500"})
    r.raise_for_status()
    modifiees = 0
    for e in r.json():
        blocs = e["blocs"] if isinstance(e["blocs"], list) else json.loads(e["blocs"] or "[]")
        neufs, notes = nettoyer(blocs, e.get("title") or "")
        if neufs == blocs:
            continue
        p = requests.patch(URL, headers=dict(ENTETES, Prefer="return=minimal"), timeout=30,
                           params={"id": f"eq.{e['id']}"}, json={"blocs": neufs})
        ok = p.status_code < 300
        modifiees += ok
        print(f"{'✔' if ok else '✖ ' + str(p.status_code)} {e['title'][:70]}")
        for n in notes:
            print(f"     · {n}")
    print(f"\n{modifiees} carte(s) corrigée(s).")


if __name__ == "__main__":
    main()
