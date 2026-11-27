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

# 26/11 (suivi qualité, validé par Maxime) : remplacements de texte, dans le titre et les paragraphes
TEXTES = [
    ("Fusées : Ariane 64 lance des satellites Internet européens",
     "Fusées : Ariane 64 lance des satellites Internet d'Amazon"),
    ("La fusée Vulcan doit aussi remplacer deux lanceurs de ULA, Atlas V et Delta IV Heavy, qui sont retirés.",
     "La fusée Vulcan doit à terme remplacer deux lanceurs de ULA : la Delta IV Heavy, retirée en 2024, et "
     "l'Atlas V, qui vole encore jusqu'à ses derniers exemplaires."),
]

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


def refaire():
    """25/11 : les résumés déjà écrits sont vidés pour être réécrits avec les nouvelles lignes
    « En pratique » (seulement l'utile, sans répétition). Le prochain passage de l'agent les refait."""
    from datetime import date
    p = requests.patch(URL, headers=dict(ENTETES, Prefer="return=representation"), timeout=30,
                       params={"blocs": "neq.[]", "event_date": f"gte.{date.today().isoformat()}", "select": "title"},
                       json={"blocs": []})
    p.raise_for_status()
    for e in p.json():
        print(f"↺ à réécrire : {e['title'][:70]}")
    print(f"\n{len(p.json())} résumé(s) remis à réécrire au prochain passage.")


# 27/11 (Maxime : « tu peux appliquer les corrections de fiches en autonomie ») : le suivi qualité inscrit ses
# corrections de texte dans qualite/corrections_texte.json, puis lance ce workflow (gratuit). Chaque entrée :
#   {"table": "advances" | "upcoming_events", "avant": "texte exact", "apres": "texte corrigé", "fait": false}
# Le remplacement touche le titre, les anciens champs et les blocs. Pour une fiche, ses traductions sont
# vidées : l'agent les refait au passage suivant (quelques dixièmes de centime).
FICHIER_TEXTES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "qualite", "corrections_texte.json")
CHAMPS = {"advances": ["title", "summary", "avant", "decouverte", "apres"],
          "upcoming_events": ["title", "prevu", "pourquoi"]}


def _remplacer_blocs(blocs, avant, apres):
    n = 0
    for b in blocs or []:
        for k in ("texte", "question"):
            if avant in (b.get(k) or ""):
                b[k] = b[k].replace(avant, apres); n += 1
        if b.get("puces"):
            b["puces"] = [x.replace(avant, apres) if avant in x else x for x in b["puces"]]
            n += sum(1 for x in b["puces"] if apres in x)
        for it in b.get("items") or []:
            for k in ("valeur", "sens"):
                if avant in (it.get(k) or ""):
                    it[k] = it[k].replace(avant, apres); n += 1
    return n


def corriger_textes() -> int:
    try:
        entrees = json.load(open(FICHIER_TEXTES, encoding="utf-8"))
    except FileNotFoundError:
        return 0
    faites = 0
    for c in [c for c in entrees if not c.get("fait") and c.get("avant") and c.get("apres") is not None]:
        table = c.get("table", "advances")
        if table not in CHAMPS:
            continue
        url = os.environ["SUPABASE_URL"].rstrip("/") + f"/rest/v1/{table}"
        champs = CHAMPS[table]
        # recherche dans les lignes récentes (simple et sûr : pas de filtre JSON côté base)
        ordre = "created_at.desc" if table == "advances" else "event_date.desc"
        r = requests.get(url, headers=ENTETES, timeout=60,
                         params={"select": "id," + ",".join(champs + ["blocs"]), "order": ordre, "limit": "600"})
        r.raise_for_status()
        trouve = [x["id"] for x in r.json() if c["avant"] in json.dumps(x, ensure_ascii=False)]
        for id_ in trouve:
            r = requests.get(url, headers=ENTETES, timeout=30,
                             params={"select": ",".join(champs + ["blocs"]), "id": f"eq.{id_}"})
            if not r.ok or not r.json():
                continue
            ligne = r.json()[0]
            maj, n = {}, 0
            for ch in champs:
                if c["avant"] in (ligne.get(ch) or ""):
                    maj[ch] = ligne[ch].replace(c["avant"], c["apres"]); n += 1
            blocs = ligne.get("blocs")
            if isinstance(blocs, str):
                blocs = json.loads(blocs or "[]")
            if blocs and _remplacer_blocs(blocs, c["avant"], c["apres"]):
                maj["blocs"] = blocs; n += 1
            if not maj:
                continue
            if table == "advances":
                maj["traductions"] = {}
            p = requests.patch(url, headers=dict(ENTETES, Prefer="return=minimal"), timeout=30,
                               params={"id": f"eq.{id_}"}, json=maj)
            print(f"{'✔' if p.status_code < 300 else '✖ ' + str(p.status_code)} {table} {id_} : "
                  f"« {c['avant'][:50]} » → « {c['apres'][:50]} »")
            if p.status_code < 300:
                faites += 1
                c["fait"] = True
        if not c.get("fait"):
            print(f"· introuvable : « {c['avant'][:60]} »")
    json.dump(entrees, open(FICHIER_TEXTES, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"{faites} correction(s) de texte appliquée(s).")
    return faites


def main():
    if os.environ.get("REFAIRE") == "oui":
        return refaire()
    corriger_textes()
    r = requests.get(URL, headers=ENTETES, timeout=30,
                     params={"select": "id,title,blocs", "limit": "500"})
    r.raise_for_status()
    modifiees = 0
    for e in r.json():
        blocs = e["blocs"] if isinstance(e["blocs"], list) else json.loads(e["blocs"] or "[]")
        neufs, notes = nettoyer(blocs, e.get("title") or "")
        titre = e.get("title") or ""
        for avant, apres in TEXTES:
            if avant in titre:
                titre = titre.replace(avant, apres)
                notes.append("titre corrigé")
            for b in neufs:
                if avant in (b.get("texte") or ""):
                    b["texte"] = b["texte"].replace(avant, apres)
                    notes.append(f"texte corrigé ({b.get('cle')})")
        if neufs == blocs and titre == e.get("title"):
            continue
        maj = {"blocs": neufs}
        if titre != e.get("title"):
            maj["title"] = titre
        p = requests.patch(URL, headers=dict(ENTETES, Prefer="return=minimal"), timeout=30,
                           params={"id": f"eq.{e['id']}"}, json=maj)
        ok = p.status_code < 300
        modifiees += ok
        print(f"{'✔' if ok else '✖ ' + str(p.status_code)} {e['title'][:70]}")
        for n in notes:
            print(f"     · {n}")
    print(f"\n{modifiees} carte(s) corrigée(s).")


if __name__ == "__main__":
    main()
