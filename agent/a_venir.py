# =====================================================================
# ONGLET « À VENIR » — NovaSTEM (01/11/2026, maquette 70, choix de Maxime)
# ---------------------------------------------------------------------
# Pendant le tri des titres, Claude signale déjà (liste à part) ceux qui
# annoncent un ÉVÉNEMENT DATÉ À VENIR : lancement, sortie d'un produit très
# attendu, résultats attendus, événement dans le ciel, grand sommet.
# Ici, pour quelques-uns de ces titres (MAX_PAR_PASSAGE), on lit le début de
# l'article et un petit appel à Claude rédige la carte (date, ce qui est
# prévu, pourquoi c'est important). Si l'événement est déjà dans la liste,
# on met seulement sa date à jour (retard, avance).
# Depuis le 02/11 (maquettes 78-79) : chaque carte a ses infos pratiques
# (lieu, heure exacte affichée à l'heure du téléphone, lignes « En pratique »,
# lien du direct, régions d'où l'on voit un événement du ciel). Sans « où »,
# pas de carte. Les lancements sont revérifiés à chaque passage (report,
# date enfin précise, heure, lien du direct) ; les autres dès qu'un article
# en reparle. Les téléphones qui suivent l'événement sont prévenus.
# Enfin, quand une avancée publiée raconte un événement de la liste (le jour
# J ou juste après), on relie les deux : la carte devient « C'est arrivé ».
# Coût : quelques centimes par mois au plus.
# Table Supabase : upcoming_events (migrations 009 et 011).
# =====================================================================

MAX_PAR_PASSAGE = 8        # articles examinés au plus par passage de l'agent (cartes nouvelles ou mises à jour)
COMPLETER_PAR_PASSAGE = 6  # anciennes cartes sans infos pratiques complétées par passage
HORIZON_JOURS = 540        # on ignore ce qui est prévu à plus de 18 mois
PART_MAX_FAMILLE = 0.25    # comme les fils : un domaine ≤ 25 % des événements à venir, sauf ★★★ et plus
MIN_PAR_FAMILLE = 2        # au début (peu d'événements), chaque domaine a droit à 2 événements
# Rythme des nouvelles cartes (choix de Maxime, 04/11) : 5 à 8 par semaine. Les événements
# ★★★ et plus passent TOUJOURS, quotas pleins ou non ; les quotas trient les autres.
SEMAINE_MAX = 8            # nouvelles cartes sur 7 jours glissants
PASSAGE_MAX = 2            # nouvelles cartes par passage de l'agent
DOMAINE_SEMAINE_MAX = 2    # nouvelles cartes d'un même domaine sur 7 jours
FIL_SEMAINE_MAX = 5        # nouvelles cartes d'un même fil (Sciences / Technologies) sur 7 jours
LANCEMENTS_MAX = 3         # lancements spatiaux ajoutés au plus par passage
LANCEMENTS_JOURS = 120     # on regarde les lancements des 4 prochains mois
FICHIER_CALENDRIER = "calendrier_a_venir.json"   # événements connus longtemps à l'avance

import json
import os
import re
import sys
from datetime import date, datetime, timedelta, timezone

try:
    from zoneinfo import ZoneInfo
    PARIS = ZoneInfo("Europe/Paris")
except Exception:                      # pragma: no cover
    ZoneInfo = None
    PARIS = timezone(timedelta(hours=1))

import requests

import economie

import notifications

CANDIDATS: list[dict] = []   # rempli par main.py pendant le tri des titres
ATTENDUS: list[str] = []     # événements du moment (veille → lendemain) : leurs articles passent en priorité

# Types (maquette 79, 02/11). « evenement » et « annonce » restent pour les anciennes cartes.
TYPES = ["lancement", "arrivee", "ciel", "sortie", "presentation", "salon", "sommet",
         "resultats", "decision", "prix", "mise_en_service", "essai"]
TYPES_ANCIENS = ["evenement", "annonce"]
# Régions du monde (visibilité des événements du ciel) : l'app compare avec le pays du téléphone.
REGIONS = ["europe", "afrique_nord", "afrique_ouest", "afrique_centre_est", "afrique_australe",
           "moyen_orient", "asie_centrale_sud", "asie_est", "asie_sud_est", "oceanie",
           "amerique_nord", "amerique_centrale", "amerique_sud"]
# Icônes des lignes « En pratique » (dessinées par l'app).
ICONES = ["lieu", "heure", "direction", "voir", "lune", "direct", "duree", "repere", "appareil",
          "qui", "prix", "info"]
COLONNES_PRATIQUES = ("event_utc", "event_end", "lieu", "pratique", "lien_direct", "lien_direct_nom",
                      "visible_regions", "visible_partiel", "visible_texte", "statut", "statut_raison", "verifie_le")
NOUVELLES_COLONNES = True    # passe à False si la migration 011 n'est pas encore faite
AUTRES_SOURCES = True        # passe à False si la migration 012 (autres_sources) n'est pas encore faite
MAX_AUTRES_SOURCES = 6

LIGNES_PAR_TYPE = """Lignes « pratique » à écrire selon le type (2 à 4 lignes, chacune : "k" = icône, "t" = titre court, "v" = texte court) :
- lancement : "repere" À regarder (le moment fort) ; "info" la mission en une ligne si utile.
- arrivee (mise en orbite, survol, atterrissage d'une sonde) : "voir" Ce qu'on verra (images, données, quand) ; "repere" le moment clé.
- ciel : "heure" Quand regarder (en heure LOCALE, valable partout : « après 1 h du matin jusqu'à l'aube », « au coucher du Soleil ») ; "direction" Où regarder ; "voir" Comment (œil nu, jumelles, lunettes d'éclipse OBLIGATOIRES pour le Soleil) ; "lune" Conditions si utile.
- sortie : "appareil" Sur quoi (consoles, systèmes, pays) ; "heure" Heure de sortie si connue ; "prix" Prix annoncé (avec la monnaie et le pays) si connu.
- presentation : "repere" Attendu (ce qui doit être montré) ; "info" en ligne ou sur place.
- salon / sommet : "duree" Durée ; "repere" Moments clés (dates) ; "qui" Qui y participe si utile.
- resultats : "qui" Qui (laboratoire, équipe) ; "voir" Ce qu'on saura ; "info" l'étude (taille, lieu).
- decision : "qui" Qui décide ; "voir" Ce qu'on saura ; "repere" Pour qui ça compte.
- prix : "heure" heure des annonces ; "duree" Programme (jour par jour) ; "info" ce qui est récompensé.
- mise_en_service / essai : "voir" Ce qu'on verra ; "repere" À retenir (un chiffre concret).
N'écris JAMAIS dans ces lignes la date ni le lieu (déjà affichés à part). Rien d'inventé : seulement ce que dit la source (ou une connaissance générale certaine, ex. « lunettes d'éclipse obligatoires »)."""

CONSIGNE = """Tu rédiges les cartes de l'onglet « À venir » de NovaSTEM, une application gratuite qui présente les avancées scientifiques et technologiques au grand public du monde entier (lycéens curieux, adultes sans formation scientifique), en français.

On te donne un article, la date d'aujourd'hui, et la liste des événements DÉJÀ dans l'onglet (numérotés, avec leur date).

1. "garder" : true seulement si l'article parle d'un ÉVÉNEMENT À VENIR parmi les PLUS NOTABLES de son domaine (tous les domaines : espace, ciel, santé, climat, énergie, transports, technologie, IA, jeux vidéo…), d'intérêt général, avec une DATE (un jour, un mois, ou au moins « d'ici fin <mois> ») ET un LIEU connus (pour le ciel : les régions du monde d'où on le voit). Sinon false (date vague comme « bientôt », événement passé, rumeur, sujet commercial sans intérêt technique, ou lieu inconnu).
   EXCEPTION : si l'article annonce le REPORT, l'AVANCE, l'ANNULATION ou la date précise d'un événement DÉJÀ dans la liste, "garder" = true et "meme_que" = son numéro.
2. "meme_que" : si c'est le MÊME événement qu'un de la liste (même formulé autrement), son numéro ; sinon -1. Donne alors les infos de CET article (la date a peut-être changé).
3. "statut" : "annule" si l'article dit que l'événement est annulé ; "reporte" s'il est repoussé ; sinon "prevu". "raison" : la raison du report ou de l'annulation si l'article la donne (« météo », « problème technique »…), sinon "".
4. "date" : AAAA-MM-JJ. "precision" : "jour" si le jour est connu ; "mois" si seul le mois est connu (date = le 1er du mois) ; "avant" si l'article dit seulement « d'ici fin <mois> », « avant la fin de l'année », « au premier trimestre » (date = le DERNIER jour possible). "fin" : AAAA-MM-JJ du dernier jour pour un événement sur plusieurs jours (salon, sommet), sinon "".
5. "heure" : HH:MM de début si l'article la donne, à l'heure LOCALE du lieu ou du fuseau cité ; "fuseau" : le fuseau de cette heure au format IANA (ex. "Europe/Paris", "America/New_York", "UTC") ; sinon "" et "". Pour le ciel (étoiles filantes…), pas d'heure : elle va dans les lignes pratiques, en heure locale.
6. "type" : lancement, arrivee, ciel, sortie, presentation, salon, sommet, resultats, decision, prix, mise_en_service ou essai.
7. "titre" : « Sujet : phrase » (12 mots au plus, verbe au présent ou au futur, sans point final), compréhensible par quelqu'un qui n'a jamais entendu parler du sujet (pas de nom propre inconnu du grand public, pas de jargon). Ex. « Fusées : une fusée européenne tente de revenir se poser ».
8. "lieu" : où ça se passe, court, en français (« Antalya, en Turquie », « Starbase, au Texas (États-Unis) », « En orbite autour de Mercure », « En ligne »). Pour le ciel : "".
9. "pratique" : les lignes pratiques (voir plus bas).
10. "lien_direct" : adresse d'une page officielle où suivre l'événement EN DIRECT, seulement si l'article la donne ; "lien_direct_nom" son nom court (« Chaîne YouTube de SpaceX ») ; sinon "" et "".
11. Pour le ciel seulement : "visible_regions" (régions d'où on le voit en entier), "visible_partiel" (régions d'où on le voit en partie, ex. éclipse partielle), choisies parmi : """ + ", ".join(REGIONS) + """ ; "visible_texte" (« Partout dans l'hémisphère nord », « Chili, Argentine et ouest de l'Afrique »). Pour les autres types : listes vides et "".
12. "prevu" : 1 à 2 phrases simples, ce qui doit se passer. "pourquoi" : 1 phrase, pourquoi c'est important ou attendu. Ne commence jamais par « Et après » ni par une question.
13. "famille" (domaine) et "importance" de 1 à 5 (même barème exigeant que les avancées : la plupart à 2, 3 pour un événement très suivi, 4-5 seulement pour un événement historique).

""" + LIGNES_PAR_TYPE

_LIGNE = {"type": "object", "properties": {"k": {"type": "string", "enum": ICONES}, "t": {"type": "string"},
                                          "v": {"type": "string"}},
          "required": ["k", "t", "v"], "additionalProperties": False}
_REGIONS = {"type": "array", "items": {"type": "string", "enum": REGIONS}}

SCHEMA = {
    "type": "object",
    "properties": {
        "garder": {"type": "boolean"},
        "meme_que": {"type": "integer"},
        "statut": {"type": "string", "enum": ["prevu", "reporte", "annule"]},
        "raison": {"type": "string"},
        "date": {"type": "string"},
        "precision": {"type": "string", "enum": ["jour", "mois", "avant"]},
        "fin": {"type": "string"},
        "heure": {"type": "string"},
        "fuseau": {"type": "string"},
        "type": {"type": "string", "enum": TYPES},
        "titre": {"type": "string"},
        "lieu": {"type": "string"},
        "pratique": {"type": "array", "items": _LIGNE},
        "lien_direct": {"type": "string"},
        "lien_direct_nom": {"type": "string"},
        "visible_regions": _REGIONS,
        "visible_partiel": _REGIONS,
        "visible_texte": {"type": "string"},
        "prevu": {"type": "string"},
        "pourquoi": {"type": "string"},
        "famille": {"type": "string"},
        "importance": {"type": "integer"},
    },
    "required": ["garder", "meme_que", "statut", "raison", "date", "precision", "fin", "heure", "fuseau", "type",
                 "titre", "lieu", "pratique", "lien_direct", "lien_direct_nom", "visible_regions", "visible_partiel",
                 "visible_texte", "prevu", "pourquoi", "famille", "importance"],
    "additionalProperties": False,
}

CONSIGNE_COMPLETER = """Tu complètes une carte de l'onglet « À venir » de NovaSTEM (application gratuite d'avancées scientifiques et technologiques pour le grand public du monde entier, en français). La carte existe déjà (titre, date, type, ce qui est prévu) ; il lui manque les infos pratiques.

On te donne la carte et le texte de sa source. Remplis :
- "lieu" : où ça se passe, court, en français (« Antalya, en Turquie », « Starbase, au Texas (États-Unis) », « En orbite autour de Mercure », « En ligne »). Pour le ciel : "".
- "pratique" : les lignes pratiques (voir plus bas).
- "lien_direct" / "lien_direct_nom" : seulement si la source donne une page officielle pour suivre en direct ; sinon "".
- Pour le ciel : "visible_regions", "visible_partiel" (parmi : """ + ", ".join(REGIONS) + """) et "visible_texte". Sinon listes vides et "".
- "possible" : false si la source ne permet pas de savoir où ça se passe (ou, pour le ciel, d'où on le voit).
Rien d'inventé.

""" + LIGNES_PAR_TYPE

SCHEMA_COMPLETER = {
    "type": "object",
    "properties": {"possible": {"type": "boolean"}, "lieu": {"type": "string"},
                   "pratique": {"type": "array", "items": _LIGNE},
                   "lien_direct": {"type": "string"}, "lien_direct_nom": {"type": "string"},
                   "visible_regions": _REGIONS, "visible_partiel": _REGIONS, "visible_texte": {"type": "string"}},
    "required": ["possible", "lieu", "pratique", "lien_direct", "lien_direct_nom", "visible_regions",
                 "visible_partiel", "visible_texte"],
    "additionalProperties": False,
}

CONSIGNE_LIENS = """On te donne des événements attendus (numérotés E0, E1…) et des avancées qui viennent d'être publiées (A0, A1…).
Renvoie dans "liens" les paires où l'avancée RACONTE ce qui s'est passé lors de l'événement (le lancement a eu lieu, le produit est sorti, les résultats sont tombés…). Seulement si c'est clairement le même événement. Liste vide sinon."""
SCHEMA_LIENS = {
    "type": "object",
    "properties": {"liens": {"type": "array", "items": {
        "type": "object", "properties": {"e": {"type": "integer"}, "a": {"type": "integer"}},
        "required": ["e", "a"], "additionalProperties": False}}},
    "required": ["liens"], "additionalProperties": False,
}


def _appel(client, modele_id, consigne, contenu, schema, conso, max_tokens=2000):
    rep = client.messages.create(
        model=modele_id, max_tokens=max_tokens, system=consigne,
        messages=[{"role": "user", "content": contenu}],
        output_config={"format": {"type": "json_schema", "schema": schema}},
        **economie.PARAMS,
    )
    conso["in"] += rep.usage.input_tokens or 0
    conso["out"] += rep.usage.output_tokens or 0
    texte = "".join(b.text for b in rep.content if getattr(b, "type", "") == "text")
    try:
        return json.loads(texte[texte.find("{"):texte.rfind("}") + 1])
    except Exception:
        return {}


def _url(db) -> str:
    return db.base.rsplit("/", 1)[0] + "/upcoming_events"


_SELECT_BASE = "id,title,prevu,pourquoi,type,event_date,event_time,precision,previous_date,source_url,source_name,advance_id,feed,family,importance"


def _lire(db, depuis: date) -> list[dict] | None:
    """Événements à partir de `depuis`. None si la table n'existe pas encore."""
    global NOUVELLES_COLONNES
    global AUTRES_SOURCES
    essais = []
    if NOUVELLES_COLONNES and AUTRES_SOURCES:
        essais.append(_SELECT_BASE + "," + ",".join(COLONNES_PRATIQUES) + ",autres_sources")
    if NOUVELLES_COLONNES:
        essais.append(_SELECT_BASE + "," + ",".join(COLONNES_PRATIQUES))
    for select in essais + [_SELECT_BASE]:
        r = requests.get(_url(db), headers=db.headers, timeout=30, params={
            "select": select, "event_date": f"gte.{depuis.isoformat()}", "order": "event_date.asc", "limit": "400"})
        if r.status_code == 404 or (r.status_code >= 400 and "upcoming_events" in r.text and "column" not in r.text):
            return None
        if r.status_code >= 400 and "column" in r.text and select != _SELECT_BASE:
            if "autres_sources" in select:
                AUTRES_SOURCES = False      # migration 012 pas encore faite : une seule source par carte
            else:
                NOUVELLES_COLONNES = False  # migration 011 pas encore faite : on continue sans les infos pratiques
            continue
        r.raise_for_status()
        return r.json()
    return None


def _sans_colonnes_nouvelles(ligne: dict) -> dict:
    """Avant la migration 011 : on retire les nouvelles colonnes et on ramène les nouveaux
    types et la précision « avant » à ce que l'ancienne table accepte."""
    l = {k: v for k, v in ligne.items() if k not in COLONNES_PRATIQUES}
    if l.get("type") and l["type"] not in ("lancement", "sortie", "resultats", "ciel", "evenement", "annonce"):
        l["type"] = "evenement"
    if l.get("precision") == "avant":
        l["precision"] = "mois"
    l.pop("event_end", None)
    return l


def _inserer(db, ligne: dict) -> dict | None:
    if not NOUVELLES_COLONNES:
        ligne = _sans_colonnes_nouvelles(ligne)
    p = requests.post(_url(db), headers=dict(db.headers, Prefer="return=representation,resolution=ignore-duplicates"),
                      json=ligne, timeout=30, params={"select": "*", "on_conflict": "source_url"})
    p.raise_for_status()
    return p.json()[0] if p.json() else None


def _ajouter_source(db, e: dict, art: dict, log) -> None:
    """Un autre média parle du même événement : on l'ajoute aux sources de la carte."""
    if not AUTRES_SOURCES:
        return
    nom, url = art.get("source_name") or "", art.get("url") or ""
    deja = e.get("autres_sources") or []
    if not nom or not url or nom == e.get("source_name") or url == e.get("source_url") \
            or any(s.get("nom") == nom or s.get("url") == url for s in deja) or len(deja) >= MAX_AUTRES_SOURCES:
        return
    d = art.get("published_at")
    principal = sys.modules.get("__main__")       # main.py : liste des sources en français / espagnol
    langue = getattr(principal, "langue_source", lambda n: "en")(nom)
    source = {"nom": nom, "url": url, "langue": langue,
              "date": d.date().isoformat() if hasattr(d, "date") else ""}
    try:
        requests.patch(_url(db), headers=dict(db.headers, Prefer="return=minimal"), timeout=30,
                       params={"id": f"eq.{e['id']}"}, json={"autres_sources": deja + [source]}).raise_for_status()
        e["autres_sources"] = deja + [source]
        log(f"  🔗 À venir : + source {nom} pour « {e['title'][:60]} »")
    except Exception as ex:
        log(f"  ⚠ À venir : source non ajoutée ({str(ex)[:80]})")


def _modifier(db, e: dict, champs: dict) -> None:
    """Met à jour une carte (et la copie locale `e`)."""
    if not NOUVELLES_COLONNES:
        champs = _sans_colonnes_nouvelles(champs)
    if not champs:
        return
    champs = dict(champs, updated_at=datetime.now(timezone.utc).isoformat())
    requests.patch(_url(db), headers=dict(db.headers, Prefer="return=minimal"), timeout=30,
                   params={"id": f"eq.{e['id']}"}, json=champs).raise_for_status()
    e.update(champs)


# ------------------------------------------------------------------ dates

def _instant(d: str, heure: str, fuseau: str) -> datetime | None:
    """« 2026-11-30 », « 14:00 », « America/Chicago » → instant UTC."""
    if not re.fullmatch(r"[0-2]\d:[0-5]\d", heure or "") or ZoneInfo is None:
        return None
    try:
        tz = ZoneInfo(fuseau or "Europe/Paris")
        return datetime.fromisoformat(f"{d[:10]}T{heure}").replace(tzinfo=tz).astimezone(timezone.utc)
    except Exception:
        return None


def _fin_valide(texte: str, debut: date) -> str | None:
    try:
        f = date.fromisoformat(texte.strip()[:10])
    except Exception:
        return None
    return f.isoformat() if debut < f <= debut + timedelta(days=60) else None


def _champs_quand(d: date, precision: str, utc: datetime | None) -> dict:
    """Champs de date communs. `event_time` (heure de Paris) reste rempli pour les anciennes versions de l'app."""
    if utc is not None:
        p = utc.astimezone(PARIS)
        return {"event_date": p.date().isoformat(), "precision": "jour", "event_utc": utc.isoformat(),
                "event_time": f"{p:%H:%M}"}
    return {"event_date": d.isoformat(), "precision": precision if precision in ("jour", "mois", "avant") else "jour",
            "event_utc": None, "event_time": None}


# ------------------------------------------------------------------ infos pratiques

def _pratique(lignes) -> list[dict] | None:
    out = []
    for x in lignes or []:
        if not isinstance(x, dict):
            continue
        k, t, v = x.get("k"), " ".join(str(x.get("t", "")).split()), " ".join(str(x.get("v", "")).split())
        if k in ICONES and t and v:
            out.append({"k": k, "t": t[:40], "v": v[:180]})
    return out[:4] or None


def _lien(url: str) -> str | None:
    url = (url or "").strip()
    return url if re.match(r"https?://[^\s]+$", url) else None


def _champs_pratiques(r: dict, type_: str) -> dict:
    ciel = type_ == "ciel"
    return {
        "lieu": None if ciel else (" ".join(str(r.get("lieu", "")).split())[:120] or None),
        "pratique": _pratique(r.get("pratique")),
        "lien_direct": _lien(r.get("lien_direct", "")),
        "lien_direct_nom": (" ".join(str(r.get("lien_direct_nom", "")).split())[:80] or None) if _lien(r.get("lien_direct", "")) else None,
        "visible_regions": [x for x in r.get("visible_regions") or [] if x in REGIONS] or None if ciel else None,
        "visible_partiel": [x for x in r.get("visible_partiel") or [] if x in REGIONS] or None if ciel else None,
        "visible_texte": (" ".join(str(r.get("visible_texte", "")).split())[:160] or None) if ciel else None,
    }


def _complet(ch: dict, type_: str) -> bool:
    """Règle de Maxime (02/11) : sans « où » (ou, pour le ciel, sans « d'où on le voit »), pas de carte."""
    return bool(ch.get("visible_regions") or ch.get("visible_partiel")) if type_ == "ciel" else bool(ch.get("lieu"))


def _changement(db, e: dict, nouveau: dict, statut: str, raison: str, log) -> bool:
    """Applique une nouvelle date / un nouveau statut à une carte existante. Prévient les téléphones
    qui suivent l'événement (« Me le rappeler ») en cas de report, d'avance ou d'annulation."""
    ancienne = e.get("event_date")
    ancien_utc = e.get("event_utc")
    champs: dict = {"verifie_le": datetime.now(timezone.utc).isoformat()}
    if statut == "annule":
        if e.get("statut") == "annule":
            _modifier(db, e, champs)
            return False
        champs.update(statut="annule", statut_raison=raison or None)
        _modifier(db, e, champs)
        log(f"  ✕ À venir : annulé « {e['title'][:60]} »")
        notifications.envoyer_changement(e, "annule", log)
        return True
    date_change = nouveau["event_date"] != ancienne
    # Une date plus précise (mois → jour, « d'ici fin … » → jour) remplace toujours l'ancienne.
    plus_precis = (e.get("precision") or "jour") != "jour" and nouveau["precision"] == "jour"
    heure_change = bool(nouveau.get("event_utc")) and ancien_utc and \
        abs((datetime.fromisoformat(str(nouveau["event_utc"]).replace("Z", "+00:00"))
             - datetime.fromisoformat(str(ancien_utc).replace("Z", "+00:00"))).total_seconds()) >= 1800
    if not (date_change or heure_change or plus_precis or (nouveau.get("event_utc") and not ancien_utc)):
        _modifier(db, e, champs)
        return False
    precision_avant = e.get("precision") or "jour"
    champs.update(nouveau)
    report = False
    if date_change and precision_avant == "jour" and nouveau["precision"] == "jour":
        champs["previous_date"] = ancienne            # vrai changement de jour
        report = nouveau["event_date"] > ancienne
        champs["statut"] = "reporte" if report else "prevu"
        champs["statut_raison"] = raison or None
    elif heure_change and not date_change:
        report = True                                  # même jour, autre heure
    _modifier(db, e, champs)
    log(f"  ⏱ À venir : « {e['title'][:60]} » {ancienne} → {nouveau['event_date']}"
        f"{' ' + str(nouveau.get('event_time')) if nouveau.get('event_time') else ''} ({nouveau['precision']})")
    if precision_avant == "jour" and nouveau["precision"] != "jour":
        pass                                                      # date moins précise (correction) : pas d'alerte
    elif precision_avant != "jour" and plus_precis and not report:
        notifications.envoyer_changement(e, "precise", log)       # « d'ici fin … » → date exacte
    elif date_change or heure_change:
        notifications.envoyer_changement(e, "reporte" if report else "avance", log)
    return True


# ------------------------------------------------------------------ calendrier (rempli à la main)

def calendrier(db, existants: list[dict], futurs: list[dict], aujourd_hui: date, log) -> int:
    """Événements connus longtemps à l'avance (calendrier_a_venir.json) : ajoutés une fois,
    puis mis à jour quand le fichier change (date, heure, infos pratiques, report)."""
    try:
        chemin = os.path.join(os.path.dirname(os.path.abspath(__file__)), FICHIER_CALENDRIER)
        liste = json.load(open(chemin, encoding="utf-8")).get("evenements", [])
    except Exception as ex:
        log(f"  ⚠ À venir : calendrier illisible ({str(ex)[:80]})")
        return 0
    par_url = {e["source_url"]: e for e in existants}
    n = maj = 0
    for ev in liste:
        ev = {k: v for k, v in ev.items() if not k.startswith("_")}
        e = par_url.get(ev.get("source_url"))
        if e is not None:                              # déjà en base : le fichier a-t-il changé ?
            try:
                diff = {k: v for k, v in ev.items()
                        if k not in ("source_url",) and k in e and e.get(k) != v
                        and not (k == "event_utc" and v and e.get(k)
                                 and datetime.fromisoformat(str(v).replace("Z", "+00:00"))
                                 == datetime.fromisoformat(str(e[k]).replace("Z", "+00:00")))}
                diff.update({k: v for k, v in ev.items() if k not in e and k in COLONNES_PRATIQUES})
                if not diff:
                    continue
                quand = {k: diff.pop(k) for k in ("event_date", "precision", "event_utc", "event_time") if k in diff}
                if diff:
                    _modifier(db, e, diff)
                if quand:
                    nouveau = {"event_date": ev["event_date"], "precision": ev.get("precision", "jour"),
                               "event_utc": ev.get("event_utc"), "event_time": ev.get("event_time")}
                    _changement(db, e, nouveau, ev.get("statut", "prevu"), ev.get("statut_raison", ""), log)
                maj += 1
            except Exception as ex:
                log(f"  ⚠ À venir : « {ev.get('title', '?')[:50]} » non mis à jour ({str(ex)[:80]})")
            continue
        if ev.get("event_end", ev.get("event_date", "")) < aujourd_hui.isoformat():
            continue
        # Pas de plafond par domaine ici : ce fichier est choisi à la main, déjà varié.
        try:
            cree = _inserer(db, ev)
            if cree:
                futurs.append(cree)
                par_url[ev["source_url"]] = cree
                n += 1
        except Exception as ex:
            log(f"  ⚠ À venir : « {ev.get('title', '?')[:50]} » non ajouté ({str(ex)[:80]})")
    if n or maj:
        log(f"  📅 À venir : calendrier, {n} ajouté(s), {maj} mis à jour")
    return n


class Quota:
    """Rythme des nouvelles cartes : compte ce qui a été ajouté ces 7 derniers jours."""

    def __init__(self, db, log):
        self.passage, self.semaine, self.familles, self.fils, self.ok = 0, 0, {}, {}, True
        try:
            depuis = (datetime.now(timezone.utc) - timedelta(days=7)).isoformat()
            r = requests.get(_url(db), headers=db.headers, timeout=30, params={
                "select": "family,feed", "created_at": f"gte.{depuis}", "limit": "200"})
            r.raise_for_status()
            for e in r.json():
                self.compter(e.get("family"), e.get("feed"), passage=False)
            log(f"À venir : {self.semaine} nouvelle(s) carte(s) sur 7 jours (rythme visé 5 à {SEMAINE_MAX})")
        except Exception as ex:
            self.ok = False
            log(f"  ⚠ À venir : rythme de la semaine inconnu ({str(ex)[:60]}) : {PASSAGE_MAX} carte(s) au plus")

    def compter(self, famille, fil, passage=True):
        self.semaine += 1
        self.passage += passage
        self.familles[famille] = self.familles.get(famille, 0) + 1
        self.fils[fil] = self.fils.get(fil, 0) + 1

    def plein(self) -> bool:
        """Plus de place pour les cartes ordinaires (★★ et moins) à ce passage."""
        return self.passage >= PASSAGE_MAX or (self.ok and self.semaine >= SEMAINE_MAX)

    def accepte(self, famille, fil, importance: int) -> str:
        """Renvoie "" si la carte peut entrer, sinon la raison du refus."""
        if importance >= 3:
            return ""
        if self.passage >= PASSAGE_MAX:
            return f"déjà {PASSAGE_MAX} nouvelles cartes à ce passage"
        if not self.ok:
            return ""
        if self.semaine >= SEMAINE_MAX:
            return f"déjà {SEMAINE_MAX} nouvelles cartes cette semaine"
        if self.familles.get(famille, 0) >= DOMAINE_SEMAINE_MAX:
            return f"déjà {DOMAINE_SEMAINE_MAX} cartes de ce domaine cette semaine"
        if self.fils.get(fil, 0) >= FIL_SEMAINE_MAX:
            return f"fil déjà à {FIL_SEMAINE_MAX} cartes cette semaine"
        return ""


QUOTA: Quota | None = None


def place_libre(futurs: list[dict], famille: str | None, importance: int) -> bool:
    """Plafond par domaine (choix de Maxime, 01/11) : un domaine ne dépasse pas 25 % des
    événements à venir, sauf pour les événements ★★★ et plus (toujours acceptés)."""
    if importance >= 3 or not famille:
        return True
    n = sum(1 for e in futurs if e.get("family") == famille) + 1
    return n <= max(MIN_PAR_FAMILLE, PART_MAX_FAMILLE * (len(futurs) + 1))


# ------------------------------------------------------------------ lancements (Launch Library 2)

LL2 = "https://ll.thespacedevs.com/2.2.0/launch/"
_LL2_CACHE: dict[str, dict] = {}   # lancements déjà reçus pendant ce passage (la base limite à 15 demandes par heure)

CONSIGNE_LANCEMENTS = """Tu choisis des lancements spatiaux pour l'onglet « À venir » de NovaSTEM (application gratuite d'avancées scientifiques et technologiques pour le grand public du monde entier, en français).

On te donne les prochains lancements (numérotés) et les événements déjà dans l'onglet. Garde AU PLUS {n} lancements qui intéressent le grand public : vol avec des astronautes, mission vers la Lune, Mars ou une autre planète, grand télescope ou sonde scientifique, premier vol d'une nouvelle fusée, fusée européenne (Ariane 6, Vega), retour ou atterrissage d'une fusée jamais tenté. JAMAIS : lancements de séries de satellites de communication (Starlink, Kuiper, OneWeb, Qianfan…), satellites commerciaux ou militaires ordinaires, vols de routine. Ne reprends pas un lancement déjà dans l'onglet. Liste vide si rien d'intéressant.

Pour chacun : "i" (son numéro), "titre" (« Sujet : phrase », 12 mots au plus, compréhensible par quelqu'un qui n'y connaît rien, sans nom de code inconnu ; ex. « Fusées : l'Europe lance son télescope chasseur de planètes »), "prevu" (1 à 2 phrases simples : qui lance quoi, pour faire quoi), "pourquoi" (1 phrase), "lieu" (le pas de tir donné, en français : « Kourou, en Guyane française », « Cap Canaveral, en Floride (États-Unis) »), "pratique" (1 à 2 lignes : "repere" À regarder = le moment fort du vol ; "info" la mission si utile ; jamais la date ni le lieu), "famille" ("space" pour une mission scientifique, "aerospace" pour une fusée ou un vol habité), "importance" (1 à 5, exigeant : 2 en général, 3 pour un vol très suivi, 4 pour un moment historique)."""

SCHEMA_LANCEMENTS = {
    "type": "object",
    "properties": {"lancements": {"type": "array", "items": {
        "type": "object",
        "properties": {"i": {"type": "integer"}, "titre": {"type": "string"}, "prevu": {"type": "string"},
                       "pourquoi": {"type": "string"}, "lieu": {"type": "string"},
                       "pratique": {"type": "array", "items": _LIGNE},
                       "famille": {"type": "string", "enum": ["space", "aerospace"]},
                       "importance": {"type": "integer"}},
        "required": ["i", "titre", "prevu", "pourquoi", "lieu", "pratique", "famille", "importance"],
        "additionalProperties": False}}},
    "required": ["lancements"], "additionalProperties": False,
}

_FIN_PERIODE = {"Q1": (3, 31), "Q2": (6, 30), "Q3": (9, 30), "Q4": (12, 31), "H1": (6, 30), "H2": (12, 31)}


def _quand_lancement(l: dict) -> dict | None:
    """Date d'un lancement selon sa précision : heure exacte, jour, mois, ou « d'ici fin … »."""
    try:
        net = datetime.fromisoformat(str(l.get("net", "")).replace("Z", "+00:00")).astimezone(timezone.utc)
    except Exception:
        return None
    ab = str((l.get("net_precision") or {}).get("abbrev", "") or "").upper()
    if ab in ("SEC", "MIN", "HR", ""):
        return _champs_quand(net.astimezone(PARIS).date(), "jour", net)
    if ab == "DAY":
        return _champs_quand(net.date(), "jour", None)
    if ab == "MON":
        return _champs_quand(date(net.year, net.month, 1), "mois", None)
    m, j = _FIN_PERIODE.get(ab, (12, 31))               # trimestre, semestre, année…
    return _champs_quand(date(net.year, m, j), "avant", None)


def _video(l: dict) -> tuple[str | None, str | None]:
    for v in l.get("vidURLs") or []:
        u = _lien(str(v.get("url", "")))
        if u:
            nom = v.get("publisher") or v.get("title") or ""
            return u, (f"Direct : {nom}"[:80] if nom else "Direct vidéo")
    return None, None


def _statut_ll2(l: dict) -> str:
    ab = str((l.get("status") or {}).get("abbrev", "") or "")
    return "annule" if ab.lower() in ("cancelled", "canceled") else "prevu"


def lancements(db, client, modele_id, existants: list[dict], futurs: list[dict], aujourd_hui: date,
               conso: dict, log) -> tuple[int, int]:
    """Prochains lancements spatiaux (Launch Library 2, gratuit, sans clé, 15 requêtes par heure) :
    Claude garde les plus intéressants. Les lancements déjà dans l'onglet sont REVÉRIFIÉS à chaque
    passage : nouvelle date, date enfin précise, nouvelle heure, lien du direct (choix de Maxime, 02/11)."""
    try:
        r = requests.get(LL2 + "upcoming/", timeout=40,
                         params={"limit": "100", "mode": "detailed"}, headers={"User-Agent": "NovaSTEM/1.0"})
        if r.status_code == 429:
            log("  ℹ À venir : liste des lancements momentanément limitée (réessai au prochain passage)")
            return 0, 0
        r.raise_for_status()
        res = r.json().get("results", [])
    except Exception as ex:
        log(f"  ⚠ À venir : lancements illisibles ({str(ex)[:80]})")
        return 0, 0
    par_id = {f"{LL2}{l.get('id')}/": l for l in res}
    _LL2_CACHE.update(par_id)
    # --- 1) Revérifier les lancements suivis (pas encore arrivés) ---
    maj = 0
    suivis = [e for e in existants if str(e.get("source_url", "")).startswith(LL2) and not e.get("advance_id")
              and e.get("statut") != "annule" and e["event_date"] >= (aujourd_hui - timedelta(days=3)).isoformat()]
    hors_liste = 0
    for e in suivis:
        l = par_id.get(e["source_url"])
        if l is None and hors_liste < 3:               # repoussé loin, ou déjà parti : on le lit seul
            hors_liste += 1
            try:
                rr = requests.get(e["source_url"], timeout=30, params={"mode": "detailed"},
                                  headers={"User-Agent": "NovaSTEM/1.0"})
                if rr.status_code == 200:
                    l = rr.json()
                    _LL2_CACHE[e["source_url"]] = l
            except Exception:
                l = None
        if l is None:
            continue
        try:
            st = str((l.get("status") or {}).get("abbrev", "") or "")
            if st in ("Success", "Failure", "Partial Failure", "In Flight"):
                _modifier(db, e, {"verifie_le": datetime.now(timezone.utc).isoformat()})
                continue                                # parti : la fiche « C'est arrivé » suivra
            nouveau = _quand_lancement(l)
            if nouveau is None:
                continue
            video, video_nom = _video(l)
            if video and video != e.get("lien_direct"):
                _modifier(db, e, {"lien_direct": video, "lien_direct_nom": video_nom})
            if _changement(db, e, nouveau, _statut_ll2(l), "", log):
                maj += 1
        except Exception as ex:
            log(f"  ⚠ À venir : lancement non revérifié ({str(ex)[:80]})")
    # --- 2) Nouveaux lancements ---
    limite = aujourd_hui + timedelta(days=LANCEMENTS_JOURS)
    candidats = []
    for l in res:
        url = f"{LL2}{l.get('id')}/"
        if url in {e["source_url"] for e in existants}:
            continue
        q = _quand_lancement(l)
        if q is None or not (aujourd_hui.isoformat() <= q["event_date"] <= limite.isoformat()):
            continue
        candidats.append((l, q, url))
    if not candidats:
        return 0, maj
    lignes = []
    for k, (l, q, _) in enumerate(candidats):
        m = l.get("mission") or {}
        lieu = ((l.get("pad") or {}).get("location") or {}).get("name", "")
        lignes.append(f"{k}. {l.get('name', '')} — {q['event_date']} ({q['precision']}) — "
                      f"{(l.get('launch_service_provider') or {}).get('name', '')} — pas de tir : {lieu}"
                      f" — {(m.get('description') or '')[:220]}")
    deja = "\n".join(f"- {e['title']} ({e['event_date']})" for e in futurs) or "(aucun)"
    rep = _appel(client, modele_id, CONSIGNE_LANCEMENTS.replace("{n}", str(LANCEMENTS_MAX)),
                 f"Déjà dans l'onglet :\n{deja}\n\nProchains lancements :\n" + "\n".join(lignes),
                 SCHEMA_LANCEMENTS, conso, 3000)
    n = 0
    for x in (rep.get("lancements") or [])[:LANCEMENTS_MAX]:
        k = x.get("i")
        if not isinstance(k, int) or not 0 <= k < len(candidats):
            continue
        l, q, url = candidats[k]
        video, video_nom = _video(l)
        ligne = {
            "title": str(x.get("titre", "")).strip().rstrip(".")[:200],
            "prevu": " ".join(str(x.get("prevu", "")).split()) or None,
            "pourquoi": " ".join(str(x.get("pourquoi", "")).split()) or None,
            "type": "lancement", "family": x.get("famille") if x.get("famille") in ("space", "aerospace") else "aerospace",
            "feed": "science" if x.get("famille") == "space" else "tech",
            **q, "importance": max(1, min(5, int(x.get("importance") or 2))),
            "source_url": url, "source_name": (l.get("launch_service_provider") or {}).get("name") or "The Space Devs",
            "lieu": " ".join(str(x.get("lieu", "")).split())[:120] or ((l.get("pad") or {}).get("location") or {}).get("name"),
            "pratique": _pratique(x.get("pratique")), "lien_direct": video, "lien_direct_nom": video_nom,
            "statut": "prevu", "verifie_le": datetime.now(timezone.utc).isoformat(),
        }
        if not ligne["title"] or not place_libre(futurs, ligne["family"], ligne["importance"]):
            continue
        refus = QUOTA.accepte(ligne["family"], ligne["feed"], ligne["importance"]) if QUOTA else ""
        if refus:
            log(f"  · À venir : lancement « {ligne['title'][:50]} » pas ajouté ({refus})")
            continue
        try:
            cree = _inserer(db, ligne)
            if cree:
                futurs.append(cree)
                existants.append(cree)
                n += 1
                if QUOTA:
                    QUOTA.compter(ligne["family"], ligne["feed"])
                log(f"  🚀 À venir : {q['event_date']} ({q['precision']}) — {ligne['title']}")
        except Exception as ex:
            log(f"  ⚠ À venir : lancement non ajouté ({str(ex)[:80]})")
    return n, maj


def preparer_attendus(db, log) -> None:
    """Au début du passage : les événements d'avant-hier à demain, pas encore arrivés.
    main.py les montre au tri et au regroupement pour que leurs articles soient écrits vite."""
    try:
        aujourd_hui = datetime.now(PARIS).date()
        l = _lire(db, aujourd_hui - timedelta(days=2)) or []
        ATTENDUS[:] = [e["title"] for e in l if not e.get("advance_id")
                       and e["event_date"] <= (aujourd_hui + timedelta(days=1)).isoformat()]
        if ATTENDUS:
            log(f"À venir : {len(ATTENDUS)} événement(s) attendu(s) en ce moment, leurs articles passent en priorité.")
    except Exception:
        ATTENDUS[:] = []


def texte_attendus() -> str:
    if not ATTENDUS:
        return ""
    return ("ÉVÉNEMENTS ATTENDUS EN CE MOMENT (onglet « À venir ») : un article qui raconte que l'un d'eux "
            "a eu lieu (sortie effective, lancement réalisé, résultats publiés…) est PRIORITAIRE : garde-le, "
            "en tête, avec au moins sa note réelle.\n" + "\n".join(f"- {t}" for t in ATTENDUS) + "\n\n")


def completer(db, client, modele_id, futurs: list[dict], lire_debut_page, conso: dict, log) -> int:
    """Cartes publiées avant le 02/11 (ou sans lieu) : Claude lit leur source et ajoute le lieu,
    les lignes « En pratique », la visibilité et le lien du direct. Les événements du calendrier
    sont complétés à la main dans calendrier_a_venir.json."""
    if not NOUVELLES_COLONNES:
        return 0
    try:
        chemin = os.path.join(os.path.dirname(os.path.abspath(__file__)), FICHIER_CALENDRIER)
        du_calendrier = {ev.get("source_url") for ev in json.load(open(chemin, encoding="utf-8")).get("evenements", [])}
    except Exception:
        du_calendrier = set()
    # Sans lignes « En pratique » (le lieu seul ne suffit pas : il peut être brut, en anglais).
    a_faire = [e for e in futurs if e.get("source_url") not in du_calendrier and e.get("statut") != "annule"
               and not e.get("pratique")]
    n = 0
    demandes_ll2 = 0
    for e in a_faire[:COMPLETER_PAR_PASSAGE]:
        try:
            source = ""
            if str(e["source_url"]).startswith(LL2):
                l = _LL2_CACHE.get(e["source_url"])     # déjà reçu : aucune nouvelle demande
                if l is None and demandes_ll2 < 2:
                    demandes_ll2 += 1
                    rr = requests.get(e["source_url"], timeout=30, params={"mode": "detailed"},
                                      headers={"User-Agent": "NovaSTEM/1.0"})
                    l = rr.json() if rr.status_code == 200 else None
                if l:
                    source = (f"Lancement : {l.get('name', '')}\nPas de tir : {((l.get('pad') or {}).get('location') or {}).get('name', '')}"
                              f" ({(l.get('pad') or {}).get('name', '')})\nMission : {((l.get('mission') or {}).get('description') or '')[:600]}")
                    video, nom = _video(l)
                    if video:
                        source += f"\nDirect : {video} ({nom})"
            else:
                art = {"url": e["source_url"], "title": e["title"], "text": ""}
                lire_debut_page(art)
                source = art.get("text", "")[:3500]
            if len(source) < 80:
                log(f"  · À venir : « {e['title'][:50]} » pas complété (source illisible pour l'instant)")
                continue
            carte = (f"Titre : {e['title']}\nType : {e.get('type')}\nDate : {e['event_date']}\n"
                     f"Ce qui est prévu : {e.get('prevu') or ''}\n\nSource ({e.get('source_name') or ''}) :\n{source}")
            r = _appel(client, modele_id, CONSIGNE_COMPLETER, carte, SCHEMA_COMPLETER, conso, 1500)
            if not r.get("possible"):
                continue
            ch = {c: v for c, v in _champs_pratiques(r, e.get("type") or "").items() if v}
            if ch:
                _modifier(db, e, dict(ch, verifie_le=datetime.now(timezone.utc).isoformat()))
                n += 1
                log(f"  ✎ À venir : infos pratiques ajoutées à « {e['title'][:60]} »")
        except Exception as ex:
            log(f"  ⚠ À venir : « {e.get('title', '?')[:40]} » non complété ({str(ex)[:60]})")
    return n


def passage_agent(db, client, modele_id: str, ajoutes: list[dict], log, sans_et_apres, prix,
                  familles_science: set[str], familles_tech: set[str], lire_debut_page) -> float:
    """Appelé par main.py à la fin du passage. Jamais bloquant. Renvoie le coût ($)."""
    conso = {"in": 0, "out": 0}
    aujourd_hui = datetime.now(PARIS).date()
    try:
        existants = _lire(db, aujourd_hui - timedelta(days=5))
    except Exception as ex:
        log(f"⚠ À venir : lecture impossible ({str(ex)[:100]})")
        return 0.0
    if existants is None:
        log("ℹ À venir : table absente (lancer database/migration_009_a_venir.sql).")
        return 0.0
    if not NOUVELLES_COLONNES:
        log("ℹ À venir : infos pratiques en attente (lancer database/migration_011_a_venir_pratique.sql).")
    nouveaux = maj = arrives = 0
    global QUOTA
    QUOTA = Quota(db, log)
    urls = {e["source_url"] for e in existants}
    futurs = [e for e in existants if e["event_date"] >= aujourd_hui.isoformat()]
    # --- 0) Événements connus à l'avance + prochains lancements spatiaux ---
    nouveaux += calendrier(db, existants, futurs, aujourd_hui, log)
    try:
        n, m = lancements(db, client, modele_id, existants, futurs, aujourd_hui, conso, log)
        nouveaux += n
        maj += m
    except Exception as ex:
        log(f"  ⚠ À venir : lancements ignorés ({ex.__class__.__name__})")
    urls |= {e["source_url"] for e in futurs}
    # --- 1) Nouvelles cartes (ou date mise à jour) ---
    familles = sorted(familles_science | familles_tech)
    # Variété (choix de Maxime) : d'abord les domaines qui ont le moins d'événements à venir ;
    # plafond de 25 % par domaine, sauf ★★★ et plus (place_libre).
    def nb_famille(f):
        horizon = (aujourd_hui + timedelta(days=90)).isoformat()
        return sum(1 for e in futurs if e.get("family") == f and e["event_date"] <= horizon)
    choix = sorted((a for a in CANDIDATS if a["url"] not in urls), key=lambda a: nb_famille(a.get("_famille_avenir")))

    def quand_txt(e):
        p = e.get("precision") or "jour"
        t = {"mois": "dans le mois", "avant": "au plus tard"}.get(p, "")
        st = {"reporte": ", reporté", "annule": ", annulé"}.get(e.get("statut") or "", "")
        return f"{e['event_date']}{' ' + t if t else ''}{' ' + str(e.get('event_time')) + ' heure de Paris' if e.get('event_time') else ''}{st}"

    # Quotas pleins : on n'examine que quelques articles, pour ne pas rater un grand événement (★★★)
    for art in choix[:3 if QUOTA.plein() else MAX_PAR_PASSAGE]:
        try:
            lire_debut_page(art)
            liste = "\n".join(f"{k}. {e['title']} ({quand_txt(e)})" for k, e in enumerate(futurs)) or "(aucun)"
            contenu = (f"Aujourd'hui : {aujourd_hui.isoformat()}\nFamilles possibles : {', '.join(familles)}\n\n"
                       f"Événements déjà dans l'onglet :\n{liste}\n\nArticle ({art['source_name']}) :\n"
                       f"{art['title']}\n{art.get('text', '')[:3500]}")
            r = _appel(client, modele_id, CONSIGNE, contenu, SCHEMA, conso, 2500)
            if not r.get("garder"):
                continue
            d = _date_valide(str(r.get("date", "")), aujourd_hui)
            statut = r.get("statut") if r.get("statut") in ("prevu", "reporte", "annule") else "prevu"
            raison = " ".join(str(r.get("raison", "")).split())[:80]
            type_ = r.get("type") if r.get("type") in TYPES else "evenement"
            utc = _instant(d.isoformat(), str(r.get("heure", "")).strip(), str(r.get("fuseau", "")).strip()) if d else None
            k = r.get("meme_que", -1)
            if isinstance(k, int) and 0 <= k < len(futurs):
                e = futurs[k]
                _ajouter_source(db, e, art, log)    # même événement, autre média (planche 82)
                # Report, avance, annulation ou date enfin précise (choix de Maxime, 02/11).
                if d is None and statut != "annule":
                    continue
                nouveau = _champs_quand(d, r.get("precision", "jour"), utc) if d else {}
                if d and (r.get("precision") or "jour") != "jour" and (e.get("precision") or "jour") == "jour":
                    continue                    # article moins précis que la carte : on garde la date précise
                if _changement(db, e, nouveau or {"event_date": e["event_date"], "precision": e.get("precision") or "jour"},
                               statut, raison, log):
                    maj += 1
                # Infos pratiques manquantes : on profite de l'article
                ch = _champs_pratiques(r, e.get("type") or type_)
                manque = {c: v for c, v in ch.items() if v and not e.get(c)}
                if manque and NOUVELLES_COLONNES:
                    _modifier(db, e, manque)
                continue
            if d is None or statut == "annule":
                continue
            fam = r.get("famille") if r.get("famille") in familles else None
            feed = "tech" if fam in familles_tech else "science"
            ch = _champs_pratiques(r, type_)
            if not _complet(ch, type_):
                log(f"  · À venir : « {str(r.get('titre', ''))[:60]} » écarté (lieu ou visibilité inconnus)")
                continue
            ligne = {
                "title": str(r.get("titre", "")).strip().rstrip(".")[:200],
                "prevu": sans_et_apres(" ".join(str(r.get("prevu", "")).split())) or None,
                "pourquoi": sans_et_apres(" ".join(str(r.get("pourquoi", "")).split())) or None,
                "type": type_, "family": fam, "feed": feed,
                **_champs_quand(d, r.get("precision", "jour"), utc),
                "event_end": _fin_valide(str(r.get("fin", "")), d),
                "importance": max(1, min(5, int(r.get("importance") or 2))),
                "source_url": art["url"], "source_name": art["source_name"],
                **ch, "statut": "prevu", "verifie_le": datetime.now(timezone.utc).isoformat(),
            }
            if not ligne["title"]:
                continue
            if not place_libre(futurs, fam, ligne["importance"]):
                log(f"  · À venir : « {ligne['title'][:60]} » écarté (domaine déjà à 25 %)")
                continue
            refus = QUOTA.accepte(fam, feed, ligne["importance"])
            if refus:
                log(f"  · À venir : « {ligne['title'][:60]} » pas ajouté ({refus})")
                continue
            cree = _inserer(db, ligne)
            if cree:
                futurs.append(cree)
                QUOTA.compter(fam, feed)
            urls.add(art["url"])
            nouveaux += 1
            log(f"  📅 À venir : {d} {ligne['type']} — {ligne['title']}")
        except Exception as ex:
            log(f"  ⚠ À venir : article ignoré ({ex.__class__.__name__}: {str(ex)[:80]})")
    # --- 1 bis) Anciennes cartes sans infos pratiques : on les complète avec leur source ---
    try:
        maj += completer(db, client, modele_id, futurs, lire_debut_page, conso, log)
    except Exception as ex:
        log(f"  ⚠ À venir : complément ignoré ({ex.__class__.__name__})")
    # --- 2) « C'est arrivé » : relier les avancées du jour aux événements attendus ---
    attendus = [e for e in existants if not e.get("advance_id")
                and (aujourd_hui - timedelta(days=7)).isoformat() <= e["event_date"] <= (aujourd_hui + timedelta(days=1)).isoformat()]
    publies = [a for a in ajoutes if a.get("id")]
    if attendus and publies:
        try:
            contenu = ("Événements attendus :\n" + "\n".join(f"E{k}. {e['title']} ({e['event_date']})" for k, e in enumerate(attendus))
                       + "\n\nAvancées publiées :\n" + "\n".join(f"A{k}. {a['title']}" for k, a in enumerate(publies)))
            r = _appel(client, modele_id, CONSIGNE_LIENS, contenu, SCHEMA_LIENS, conso, 600)
            for x in r.get("liens", []):
                e, a = x.get("e"), x.get("a")
                if isinstance(e, int) and isinstance(a, int) and 0 <= e < len(attendus) and 0 <= a < len(publies):
                    requests.patch(_url(db), headers=dict(db.headers, Prefer="return=minimal"), timeout=30,
                                   params={"id": f"eq.{attendus[e]['id']}"},
                                   json={"advance_id": publies[a]["id"]}).raise_for_status()
                    arrives += 1
                    notifications.envoyer_arrive(attendus[e], publies[a], log)
                    log(f"  ✅ C'est arrivé : « {attendus[e]['title'][:60]} » → « {publies[a]['title'][:60]} »")
        except Exception as ex:
            log(f"  ⚠ À venir : liens impossibles ({str(ex)[:80]})")
    cout = (conso["in"] * prix[0] + conso["out"] * prix[1]) / 1e6
    log(f"À venir : {nouveaux} nouvelle(s) carte(s), {maj} carte(s) mise(s) à jour (dates, reports, infos pratiques), {arrives} « C'est arrivé » "
        f"({len(CANDIDATS)} titre(s) signalé(s)), {cout:.4f} $")
    return cout
