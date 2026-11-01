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

MAX_PAR_PASSAGE = 6        # cartes rédigées au plus par passage de l'agent (articles)
HORIZON_JOURS = 540        # on ignore ce qui est prévu à plus de 18 mois
PART_MAX_FAMILLE = 0.25    # comme les fils : un domaine ≤ 25 % des événements à venir, sauf ★★★ et plus
MIN_PAR_FAMILLE = 2        # au début (peu d'événements), chaque domaine a droit à 2 événements
LANCEMENTS_MAX = 3         # lancements spatiaux ajoutés au plus par passage
LANCEMENTS_JOURS = 120     # on regarde les lancements des 4 prochains mois
FICHIER_CALENDRIER = "calendrier_a_venir.json"   # événements connus longtemps à l'avance

import json
import os
import re
from datetime import date, datetime, timedelta, timezone

try:
    from zoneinfo import ZoneInfo
    PARIS = ZoneInfo("Europe/Paris")
except Exception:                      # pragma: no cover
    PARIS = timezone(timedelta(hours=1))

import requests

import notifications

CANDIDATS: list[dict] = []   # rempli par main.py pendant le tri des titres
ATTENDUS: list[str] = []     # événements du moment (veille → lendemain) : leurs articles passent en priorité

TYPES = ["lancement", "sortie", "resultats", "ciel", "evenement", "annonce"]

CONSIGNE = """Tu rédiges les cartes de l'onglet « À venir » de NovaSTEM, une application gratuite qui présente les avancées scientifiques et technologiques au grand public (lycéens curieux, adultes sans formation scientifique), en français.

On te donne un article, la date d'aujourd'hui, et la liste des événements DÉJÀ dans l'onglet (numérotés).

1. "garder" : true seulement si l'article annonce un ÉVÉNEMENT À VENIR parmi les PLUS NOTABLES de son domaine (l'onglet couvre tous les domaines : espace, santé, climat, énergie, transports, technologie, IA, jeux vidéo…), d'intérêt général, avec une DATE PRÉCISE donnée par l'article (un jour, ou au moins un mois et une année) et située dans le futur. Exemples : lancement d'une fusée ou d'une mission marquante, résultats attendus d'un grand essai de vaccin ou de traitement, décision très attendue sur un médicament important, mise en service d'une centrale ou d'un train, premier vol d'un avion, présentation officielle d'un produit phare (console, smartphone phare, voiture), sortie d'une grande IA, sortie des plus gros jeux vidéo, résultats scientifiques attendus à une date, événement dans le ciel (éclipse, pluie d'étoiles filantes, comète visible), grand sommet ou grande conférence scientifique. Sinon false (date vague comme « bientôt » ou « dans les prochaines années », événement passé, sujet commercial sans intérêt technique, rumeur).
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
        "select": "id,title,event_date,source_url,advance_id,feed,family",
        "event_date": f"gte.{depuis.isoformat()}", "order": "event_date.asc", "limit": "300"})
    if r.status_code == 404 or (r.status_code >= 400 and "upcoming_events" in r.text):
        return None
    r.raise_for_status()
    return r.json()


CONSIGNE_LANCEMENTS = """Tu choisis des lancements spatiaux pour l'onglet « À venir » de NovaSTEM (application gratuite d'avancées scientifiques et technologiques pour le grand public, en français).

On te donne les prochains lancements (numérotés) et les événements déjà dans l'onglet. Garde AU PLUS {n} lancements qui intéressent le grand public : vol avec des astronautes, mission vers la Lune, Mars ou une autre planète, grand télescope ou sonde scientifique, premier vol d'une nouvelle fusée, fusée européenne (Ariane 6, Vega), retour ou atterrissage d'une fusée jamais tenté. JAMAIS : lancements de séries de satellites de communication (Starlink, Kuiper, OneWeb, Qianfan…), satellites commerciaux ou militaires ordinaires, vols de routine. Ne reprends pas un lancement déjà dans l'onglet. Liste vide si rien d'intéressant.

Pour chacun : "i" (son numéro), "titre" (« Sujet : phrase », 12 mots au plus, compréhensible par quelqu'un qui n'y connaît rien, sans nom de code inconnu ; ex. « Fusées : l'Europe lance son télescope chasseur de planètes »), "prevu" (1 à 2 phrases simples : qui lance quoi, d'où, pour faire quoi), "pourquoi" (1 phrase), "famille" ("space" pour une mission scientifique, "aerospace" pour une fusée ou un vol habité), "importance" (1 à 5, exigeant : 2 en général, 3 pour un vol très suivi, 4 pour un moment historique)."""

SCHEMA_LANCEMENTS = {
    "type": "object",
    "properties": {"lancements": {"type": "array", "items": {
        "type": "object",
        "properties": {"i": {"type": "integer"}, "titre": {"type": "string"}, "prevu": {"type": "string"},
                       "pourquoi": {"type": "string"}, "famille": {"type": "string", "enum": ["space", "aerospace"]},
                       "importance": {"type": "integer"}},
        "required": ["i", "titre", "prevu", "pourquoi", "famille", "importance"], "additionalProperties": False}}},
    "required": ["lancements"], "additionalProperties": False,
}


def _inserer(db, ligne: dict) -> dict | None:
    p = requests.post(_url(db), headers=dict(db.headers, Prefer="return=representation,resolution=ignore-duplicates"),
                      json=ligne, timeout=30, params={"select": "id,title,event_date,source_url,advance_id,feed,family",
                                                      "on_conflict": "source_url"})
    p.raise_for_status()
    return p.json()[0] if p.json() else None


def _changer_date(db, e: dict, d: str) -> None:
    requests.patch(_url(db), headers=dict(db.headers, Prefer="return=minimal"), timeout=30,
                   params={"id": f"eq.{e['id']}"},
                   json={"event_date": d, "previous_date": e["event_date"],
                         "updated_at": datetime.now(timezone.utc).isoformat()}).raise_for_status()
    e["event_date"] = d


def place_libre(futurs: list[dict], famille: str | None, importance: int) -> bool:
    """Plafond par domaine (choix de Maxime, 01/11) : un domaine ne dépasse pas 25 % des
    événements à venir, sauf pour les événements ★★★ et plus (toujours acceptés)."""
    if importance >= 3 or not famille:
        return True
    n = sum(1 for e in futurs if e.get("family") == famille) + 1
    return n <= max(MIN_PAR_FAMILLE, PART_MAX_FAMILLE * (len(futurs) + 1))


def calendrier(db, existants: list[dict], futurs: list[dict], aujourd_hui: date, log) -> int:
    """Événements connus longtemps à l'avance (calendrier_a_venir.json) : ajoutés une fois."""
    try:
        chemin = os.path.join(os.path.dirname(os.path.abspath(__file__)), FICHIER_CALENDRIER)
        liste = json.load(open(chemin, encoding="utf-8")).get("evenements", [])
    except Exception as ex:
        log(f"  ⚠ À venir : calendrier illisible ({str(ex)[:80]})")
        return 0
    connus = {e["source_url"] for e in existants}
    n = 0
    for ev in liste:
        if ev.get("source_url") in connus or ev.get("event_date", "") < aujourd_hui.isoformat():
            continue
        if not place_libre(futurs, ev.get("family"), int(ev.get("importance") or 2)):
            continue                       # domaine déjà bien servi : réessayé au prochain passage
        try:
            cree = _inserer(db, {k: v for k, v in ev.items() if not k.startswith("_")})
            if cree:
                futurs.append(cree)
                connus.add(ev["source_url"])
                n += 1
        except Exception as ex:
            log(f"  ⚠ À venir : « {ev.get('title', '?')[:50]} » non ajouté ({str(ex)[:80]})")
    if n:
        log(f"  📅 À venir : {n} événement(s) du calendrier ajouté(s)")
    return n


def lancements(db, client, modele_id, existants: list[dict], futurs: list[dict], aujourd_hui: date,
               conso: dict, log) -> tuple[int, int]:
    """Prochains lancements spatiaux (Launch Library 2, gratuit, sans clé) : Claude garde
    les plus intéressants ; les dates des lancements déjà dans l'onglet sont mises à jour."""
    try:
        r = requests.get("https://ll.thespacedevs.com/2.2.0/launch/upcoming/", timeout=30,
                         params={"limit": "60", "mode": "normal"}, headers={"User-Agent": "NovaSTEM/1.0"})
        if r.status_code == 429:
            log("  ℹ À venir : liste des lancements momentanément limitée (réessai au prochain passage)")
            return 0, 0
        r.raise_for_status()
        res = r.json().get("results", [])
    except Exception as ex:
        log(f"  ⚠ À venir : lancements illisibles ({str(ex)[:80]})")
        return 0, 0
    limite = aujourd_hui + timedelta(days=LANCEMENTS_JOURS)
    par_url = {e["source_url"]: e for e in existants}
    candidats, maj = [], 0
    for l in res:
        try:
            net = datetime.fromisoformat(str(l.get("net", "")).replace("Z", "+00:00")).astimezone(PARIS)
        except Exception:
            continue
        if not (aujourd_hui <= net.date() <= limite):
            continue
        url = f"https://ll.thespacedevs.com/2.2.0/launch/{l.get('id')}/"
        if url in par_url:                      # déjà dans l'onglet : la date a-t-elle bougé ?
            e = par_url[url]
            if e["event_date"] != net.date().isoformat() and e["event_date"] >= aujourd_hui.isoformat():
                try:
                    _changer_date(db, e, net.date().isoformat())
                    maj += 1
                    log(f"  ⏱ À venir : lancement décalé « {e['title'][:60]} » → {net.date()}")
                except Exception:
                    pass
            continue
        candidats.append((l, net, url))
    if not candidats:
        return 0, maj
    lignes = []
    for k, (l, net, _) in enumerate(candidats):
        m = l.get("mission") or {}
        lignes.append(f"{k}. {l.get('name', '')} — {net:%Y-%m-%d} — {(l.get('launch_service_provider') or {}).get('name', '')}"
                      f" — {(m.get('description') or '')[:220]}")
    deja = "\n".join(f"- {e['title']} ({e['event_date']})" for e in futurs) or "(aucun)"
    rep = _appel(client, modele_id, CONSIGNE_LANCEMENTS.replace("{n}", str(LANCEMENTS_MAX)),
                 f"Déjà dans l'onglet :\n{deja}\n\nProchains lancements :\n" + "\n".join(lignes),
                 SCHEMA_LANCEMENTS, conso, 2500)
    n = 0
    for x in (rep.get("lancements") or [])[:LANCEMENTS_MAX]:
        k = x.get("i")
        if not isinstance(k, int) or not 0 <= k < len(candidats):
            continue
        l, net, url = candidats[k]
        precis = (l.get("net_precision") or {}).get("abbrev", "") in ("SEC", "MIN", "HR", "")
        ligne = {
            "title": str(x.get("titre", "")).strip().rstrip(".")[:200],
            "prevu": " ".join(str(x.get("prevu", "")).split()) or None,
            "pourquoi": " ".join(str(x.get("pourquoi", "")).split()) or None,
            "type": "lancement", "family": x.get("famille") if x.get("famille") in ("space", "aerospace") else "aerospace",
            "feed": "science" if x.get("famille") == "space" else "tech",
            "event_date": net.date().isoformat(), "event_time": f"{net:%H:%M}" if precis else None,
            "precision": "jour", "importance": max(1, min(5, int(x.get("importance") or 2))),
            "source_url": url, "source_name": (l.get("launch_service_provider") or {}).get("name") or "The Space Devs",
        }
        if not ligne["title"] or not place_libre(futurs, ligne["family"], ligne["importance"]):
            continue
        try:
            cree = _inserer(db, ligne)
            if cree:
                futurs.append(cree)
                n += 1
                log(f"  🚀 À venir : {net.date()} — {ligne['title']}")
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
    aujourd_hui = datetime.now(PARIS).date()
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
    for art in choix[:MAX_PAR_PASSAGE]:
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
                    ancienne = e["event_date"]
                    _changer_date(db, e, d.isoformat())
                    log(f"  ⏱ À venir : date changée « {e['title'][:60]} » {ancienne} → {d}")
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
            if not place_libre(futurs, fam, ligne["importance"]):
                log(f"  · À venir : « {ligne['title'][:60]} » écarté (domaine déjà à 25 %)")
                continue
            cree = _inserer(db, ligne)
            if cree:
                futurs.append(cree)
            urls.add(art["url"])
            nouveaux += 1
            log(f"  📅 À venir : {d} {ligne['type']} — {ligne['title']}")
        except Exception as ex:
            log(f"  ⚠ À venir : article ignoré ({ex.__class__.__name__}: {str(ex)[:80]})")
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
    log(f"À venir : {nouveaux} nouvelle(s) carte(s), {maj} date(s) changée(s), {arrives} « C'est arrivé » "
        f"({len(CANDIDATS)} titre(s) signalé(s)), {cout:.4f} $")
    return cout
