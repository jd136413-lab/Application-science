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
# Enfin, quand une avancée publiée raconte un événement de la liste (le jour
# J ou juste après), on relie les deux : la carte devient « C'est arrivé ».
# Coût : quelques centimes par mois au plus.
# Table Supabase : upcoming_events (database/migration_009_a_venir.sql).
# =====================================================================

MAX_PAR_PASSAGE = 4        # cartes rédigées au plus par passage de l'agent
HORIZON_JOURS = 540        # on ignore ce qui est prévu à plus de 18 mois

import json
import re
from datetime import date, datetime, timedelta, timezone

import requests

CANDIDATS: list[dict] = []   # rempli par main.py pendant le tri des titres

TYPES = ["lancement", "sortie", "resultats", "ciel", "evenement", "annonce"]

CONSIGNE = """Tu rédiges les cartes de l'onglet « À venir » de NovaSTEM, une application gratuite qui présente les avancées scientifiques et technologiques au grand public (lycéens curieux, adultes sans formation scientifique), en français.

On te donne un article, la date d'aujourd'hui, et la liste des événements DÉJÀ dans l'onglet (numérotés).

1. "garder" : true seulement si l'article annonce un ÉVÉNEMENT À VENIR, d'intérêt général, avec une DATE PRÉCISE donnée par l'article (un jour, ou au moins un mois et une année) et située dans le futur. Exemples : lancement d'une fusée ou d'une mission, sortie d'un produit très attendu (console, smartphone phare, voiture, jeu très attendu), résultats scientifiques attendus à une date, événement dans le ciel (éclipse, pluie d'étoiles filantes, comète visible), grand sommet ou grande conférence scientifique. Sinon false (date vague comme « bientôt » ou « dans les prochaines années », événement passé, sujet commercial sans intérêt technique, rumeur).
2. "meme_que" : si c'est le MÊME événement qu'un de la liste (même formulé autrement), son numéro ; sinon -1. Dans ce cas, donne quand même la date annoncée par CET article (elle a peut-être changé).
3. "date" : AAAA-MM-JJ (si seul le mois est connu, mets le 1er du mois et "precision" = "mois", sinon "jour"). "heure" : HH:MM à l'heure de Paris si l'article la donne, sinon "".
4. "type" : lancement, sortie, resultats, ciel, evenement ou annonce (une présentation officielle à une date connue).
5. "titre" : « Sujet : phrase » (12 mots au plus, verbe au présent ou au futur, sans point final), compréhensible par quelqu'un qui n'a jamais entendu parler du sujet (pas de nom propre inconnu du grand public, pas de jargon). Ex. « Fusées : une fusée européenne tente de revenir se poser ».
6. "prevu" : 1 à 2 phrases simples, ce qui doit se passer. "pourquoi" : 1 phrase, pourquoi c'est important ou attendu. Ne commence jamais par « Et après » ni par une question.
7. "famille" (domaine) et "importance" de 1 à 5 (même barème exigeant que les avancées : la plupart à 2, 3 pour un événement très suivi, 4-5 seulement pour un événement historique)."""

SCHEMA = {
    "type": "object",
    "properties": {
        "garder": {"type": "boolean"},
        "meme_que": {"type": "integer"},
        "date": {"type": "string"},
        "heure": {"type": "string"},
        "precision": {"type": "string", "enum": ["jour", "mois"]},
        "type": {"type": "string", "enum": TYPES},
        "titre": {"type": "string"},
        "prevu": {"type": "string"},
        "pourquoi": {"type": "string"},
        "famille": {"type": "string"},
        "importance": {"type": "integer"},
    },
    "required": ["garder", "meme_que", "date", "heure", "precision", "type", "titre", "prevu",
                 "pourquoi", "famille", "importance"],
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


def _appel(client, modele_id, consigne, contenu, schema, conso, max_tokens=1500):
    rep = client.messages.create(
        model=modele_id, max_tokens=max_tokens, system=consigne,
        messages=[{"role": "user", "content": contenu}],
        output_config={"format": {"type": "json_schema", "schema": schema}},
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


def _lire(db, depuis: date) -> list[dict] | None:
    """Événements à partir de `depuis`. None si la table n'existe pas encore."""
    r = requests.get(_url(db), headers=db.headers, timeout=30, params={
        "select": "id,title,event_date,source_url,advance_id,feed",
        "event_date": f"gte.{depuis.isoformat()}", "order": "event_date.asc", "limit": "300"})
    if r.status_code == 404 or (r.status_code >= 400 and "upcoming_events" in r.text):
        return None
    r.raise_for_status()
    return r.json()


def _date_valide(texte: str, aujourd_hui: date) -> date | None:
    try:
        d = date.fromisoformat(texte.strip()[:10])
    except Exception:
        return None
    if d < aujourd_hui or d > aujourd_hui + timedelta(days=HORIZON_JOURS):
        return None
    return d


def passage_agent(db, client, modele_id: str, ajoutes: list[dict], log, sans_et_apres, prix,
                  familles_science: set[str], familles_tech: set[str], lire_debut_page) -> float:
    """Appelé par main.py à la fin du passage. Jamais bloquant. Renvoie le coût ($)."""
    conso = {"in": 0, "out": 0}
    aujourd_hui = datetime.now(timezone(timedelta(hours=1))).date()
    try:
        existants = _lire(db, aujourd_hui - timedelta(days=5))
    except Exception as ex:
        log(f"⚠ À venir : lecture impossible ({str(ex)[:100]})")
        return 0.0
    if existants is None:
        log("ℹ À venir : table absente (lancer database/migration_009_a_venir.sql).")
        return 0.0
    nouveaux = maj = arrives = 0
    urls = {e["source_url"] for e in existants}
    futurs = [e for e in existants if e["event_date"] >= aujourd_hui.isoformat()]
    # --- 1) Nouvelles cartes (ou date mise à jour) ---
    familles = sorted(familles_science | familles_tech)
    for art in [a for a in CANDIDATS if a["url"] not in urls][:MAX_PAR_PASSAGE]:
        try:
            lire_debut_page(art)
            liste = "\n".join(f"{k}. {e['title']} ({e['event_date']})" for k, e in enumerate(futurs)) or "(aucun)"
            contenu = (f"Aujourd'hui : {aujourd_hui.isoformat()}\nFamilles possibles : {', '.join(familles)}\n\n"
                       f"Événements déjà dans l'onglet :\n{liste}\n\nArticle ({art['source_name']}) :\n"
                       f"{art['title']}\n{art.get('text', '')[:1800]}")
            r = _appel(client, modele_id, CONSIGNE, contenu, SCHEMA, conso)
            if not r.get("garder"):
                continue
            d = _date_valide(str(r.get("date", "")), aujourd_hui)
            if d is None:
                continue
            k = r.get("meme_que", -1)
            if isinstance(k, int) and 0 <= k < len(futurs):
                e = futurs[k]
                if e["event_date"] != d.isoformat():
                    requests.patch(_url(db), headers=dict(db.headers, Prefer="return=minimal"), timeout=30,
                                   params={"id": f"eq.{e['id']}"},
                                   json={"event_date": d.isoformat(), "previous_date": e["event_date"],
                                         "updated_at": datetime.now(timezone.utc).isoformat()}).raise_for_status()
                    log(f"  ⏱ À venir : date changée « {e['title'][:60]} » {e['event_date']} → {d}")
                    e["event_date"] = d.isoformat()
                    maj += 1
                continue
            fam = r.get("famille") if r.get("famille") in familles else None
            feed = "tech" if fam in familles_tech else "science"
            heure = str(r.get("heure", "")).strip()
            ligne = {
                "title": str(r.get("titre", "")).strip().rstrip(".")[:200],
                "prevu": sans_et_apres(" ".join(str(r.get("prevu", "")).split())) or None,
                "pourquoi": sans_et_apres(" ".join(str(r.get("pourquoi", "")).split())) or None,
                "type": r.get("type") if r.get("type") in TYPES else "evenement",
                "family": fam, "feed": feed, "event_date": d.isoformat(),
                "event_time": heure if re.fullmatch(r"[0-2]\d:[0-5]\d", heure) else None,
                "precision": r.get("precision") if r.get("precision") in ("jour", "mois") else "jour",
                "importance": max(1, min(5, int(r.get("importance") or 2))),
                "source_url": art["url"], "source_name": art["source_name"],
            }
            if not ligne["title"]:
                continue
            p = requests.post(_url(db), headers=dict(db.headers, Prefer="return=representation,resolution=ignore-duplicates"),
                              json=ligne, timeout=30, params={"select": "id,title,event_date,source_url,advance_id,feed",
                                                               "on_conflict": "source_url"})
            p.raise_for_status()
            if p.json():
                futurs.append(p.json()[0])
            urls.add(art["url"])
            nouveaux += 1
            log(f"  📅 À venir : {d} {ligne['type']} — {ligne['title']}")
        except Exception as ex:
            log(f"  ⚠ À venir : article ignoré ({ex.__class__.__name__}: {str(ex)[:80]})")
    # --- 2) « C'est arrivé » : relier les avancées du jour aux événements attendus ---
    attendus = [e for e in existants if not e.get("advance_id")
                and (aujourd_hui - timedelta(days=4)).isoformat() <= e["event_date"] <= (aujourd_hui + timedelta(days=1)).isoformat()]
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
                    log(f"  ✅ C'est arrivé : « {attendus[e]['title'][:60]} » → « {publies[a]['title'][:60]} »")
        except Exception as ex:
            log(f"  ⚠ À venir : liens impossibles ({str(ex)[:80]})")
    cout = (conso["in"] * prix[0] + conso["out"] * prix[1]) / 1e6
    log(f"À venir : {nouveaux} nouvelle(s) carte(s), {maj} date(s) changée(s), {arrives} « C'est arrivé » "
        f"({len(CANDIDATS)} titre(s) signalé(s)), {cout:.4f} $")
    return cout
