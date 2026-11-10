# =====================================================================
# TRADUCTION DES ÉVÉNEMENTS « À VENIR » — NovaSTEM (10/11/2026)
# ---------------------------------------------------------------------
# Comme pour les fiches (traduction.py), Claude traduit UNE FOIS chaque
# événement à venir (titre, « ce qui est prévu », « pourquoi c'est
# important », lieu, visibilité, raison d'un report, infos pratiques).
# Les traductions sont rangées dans la colonne « traductions » de la table
# upcoming_events (migration 015) sous la forme
#   {"en": {"texte français": "English text", ...}}
# Le téléphone les affiche telles quelles, tout de suite (plus de français
# qui s'affiche d'abord, plus de noms propres déformés par la traduction
# automatique du téléphone).
# Appelé à chaque passage de l'agent (a_venir.passage_agent). Jamais bloquant.
# =====================================================================
import json

import requests

from traduction import LANGUES, MODELE, PRIX

MAX_PAR_PASSAGE = 60     # événements traduits au plus par passage (le premier passage rattrape tout)

CONSIGNE = """Tu es le traducteur de NovaSTEM, une application qui présente les avancées scientifiques et technologiques et un calendrier des grands événements à venir (lancements de fusées, sorties de produits, sommets, phénomènes dans le ciel…), pour un large public. Tu traduis du français vers l'{langue} des textes courts d'un même événement.

Règles :
- Fidélité totale : mêmes faits, mêmes dates, mêmes chiffres, mêmes précautions. N'ajoute rien, n'enlève rien.
- Ton simple et naturel, comme un journaliste dont c'est la langue maternelle, pas mot à mot.
- Titres : garde la forme « Thème : sujet + verbe », sans point final ; ponctuation et majuscules normales de la langue cible (en anglais : « Rockets: … », majuscule seulement au premier mot et aux noms propres).
- Noms propres, fusées, missions, sondes, produits, entreprises : TOUJOURS tels quels, avec leur nom officiel dans la langue cible s'il existe (ex. « Longue Marche 10A » → « Long March 10A », « Agence spatiale européenne » → « European Space Agency »). Ne traduis jamais un nom propre mot à mot.
- Lieux : nom usuel dans la langue cible (« Guyane » → « French Guiana », « Chine » → « China »).
- Nombres et unités : système métrique, nombres écrits à la manière de la langue cible.
- Un texte très court (une étiquette comme « Lieu » ou « Heure de départ ») se traduit par une étiquette équivalente.

Tu reçois une liste numérotée de textes. Réponds uniquement avec le JSON demandé : une traduction par texte, avec le même numéro « n »."""

SCHEMA = {
    "type": "object",
    "properties": {"textes": {"type": "array", "items": {
        "type": "object",
        "properties": {"n": {"type": "integer"}, "t": {"type": "string"}},
        "required": ["n", "t"], "additionalProperties": False}}},
    "required": ["textes"], "additionalProperties": False,
}

CHAMPS = ("title", "prevu", "pourquoi", "lieu", "visible_texte", "statut_raison")


def _propre(x) -> str:
    return str(x or "").strip()


def textes(e: dict) -> list[str]:
    """Tous les textes français affichés par l'app pour cet événement."""
    res = [_propre(e.get(c)) for c in CHAMPS]
    pratique = e.get("pratique") or []
    if isinstance(pratique, str):
        try:
            pratique = json.loads(pratique)
        except Exception:
            pratique = []
    for ligne in pratique if isinstance(pratique, list) else []:
        if isinstance(ligne, dict):
            res += [_propre(ligne.get("t")), _propre(ligne.get("v"))]
    vus, uniques = set(), []
    for t in res:
        if t and t not in vus:
            vus.add(t)
            uniques.append(t)
    return uniques


def _url(db) -> str:
    return db.base.rsplit("/", 1)[0] + "/upcoming_events"


def _traduire(client, liste: list[str], code: str, conso: dict) -> dict[str, str]:
    r = client.messages.create(
        model=MODELE, max_tokens=4000, system=CONSIGNE.format(langue=LANGUES[code]),
        messages=[{"role": "user", "content": json.dumps(
            {"textes": [{"n": i, "texte": t} for i, t in enumerate(liste)]}, ensure_ascii=False)}],
        output_config={"format": {"type": "json_schema", "schema": SCHEMA}})
    conso["in"] += r.usage.input_tokens
    conso["out"] += r.usage.output_tokens
    rep = json.loads("".join(b.text for b in r.content if getattr(b, "type", "") == "text") or "{}")
    res = {}
    for x in rep.get("textes", []):
        n, t = x.get("n"), _propre(x.get("t"))
        if isinstance(n, int) and 0 <= n < len(liste) and t:
            res[liste[n]] = t
    return res


def passage(db, client, log, depuis: str, maximum: int = MAX_PAR_PASSAGE) -> float:
    """Traduit les événements (à partir de la date `depuis`) dont une traduction manque.
    Renvoie le coût en $. Ne lève jamais d'exception."""
    conso = {"in": 0, "out": 0}
    try:
        r = requests.get(_url(db), headers=db.headers, timeout=30, params={
            "select": "*", "event_date": f"gte.{depuis}", "order": "event_date.asc", "limit": "400"})
        if r.status_code >= 400:
            if "traductions" not in r.text:
                log(f"  ⚠ À venir (traduction) : lecture impossible ({r.status_code})")
            return 0.0
        evenements = r.json()
        if evenements and "traductions" not in evenements[0]:
            log("ℹ À venir : traductions en attente (lancer database/migration_015_a_venir_traductions.sql).")
            return 0.0
        faits = 0
        for e in evenements:
            if faits >= maximum:
                break
            tr = e.get("traductions") or {}
            liste = textes(e)
            change = False
            for code in LANGUES:
                deja = tr.get(code) or {}
                manque = [t for t in liste if t not in deja]
                if not manque:
                    continue
                try:
                    deja.update(_traduire(client, manque, code, conso))
                    tr[code] = deja
                    change = True
                except Exception as ex:
                    log(f"  ⚠ À venir : traduction ({code}) impossible pour « {e.get('title', '')[:50]} » ({ex.__class__.__name__})")
            if change:
                p = requests.patch(_url(db), headers=dict(db.headers, Prefer="return=minimal"), timeout=30,
                                   params={"id": f"eq.{e['id']}"}, json={"traductions": tr})
                if p.status_code < 300:
                    faits += 1
        cout = (conso["in"] * PRIX[0] + conso["out"] * PRIX[1]) / 1e6
        if faits:
            log(f"À venir : {faits} événement(s) traduit(s) ({cout:.4f} $)")
        return cout
    except Exception as ex:
        log(f"  ⚠ À venir : traductions ignorées ({ex.__class__.__name__}: {str(ex)[:80]})")
        return (conso["in"] * PRIX[0] + conso["out"] * PRIX[1]) / 1e6
