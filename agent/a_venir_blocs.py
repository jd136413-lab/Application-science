"""Résumé « à blocs » des cartes À venir (25/11/2026, demande de Maxime, maquette 112).

Comme les fiches Sciences et Technologies (plan D) : les infos essentielles restent en haut
de la carte (compte à rebours, date, heure, lieu, direct, « En pratique ») ; dessous, l'agent
écrit En bref, En chiffres (si utile), 2 à 4 paragraphes CHOISIS POUR L'ÉVÉNEMENT, chacun avec
sa propre question en intertitre, et ce qu'on ne sait pas encore. Aucun paragraphe imposé.

Fiabilité :
  • l'agent relève d'abord les faits avec une citation copiée de la source ; le programme
    vérifie chaque citation (fait retiré sinon) et les nombres ;
  • intertitres passe-partout refusés, chiffres peu clairs retirés, 3 limites au plus ;
  • un 2e appel relit la carte contre la source et corrige.
Les cartes sans blocs sont traitées quelques-unes par passage (les plus proches d'abord).
Les anciennes colonnes (prevu, pourquoi) ne bougent pas : la liste et les anciennes versions
de l'app continuent de les afficher.
"""

import json
import re

import requests

import economie
import fiche_blocs as fb
import redaction

MAX_PAR_PASSAGE = 15   # 25/11 : rattrapage des 40 cartes (≈ 0,002 $ la carte)

CONSIGNE = """Tu rédiges le résumé d'une carte de l'onglet « À venir » de NovaSTEM : une application gratuite qui présente les avancées scientifiques et technologiques et les grands événements à venir (lancements, sorties de produits, phénomènes dans le ciel, sommets, résultats attendus…) à des lecteurs non spécialistes (lycéens, adultes curieux), en français.

La carte affiche DÉJÀ en haut : le titre, le compte à rebours, la date et l'heure, le lieu et le lien du direct. Ne les répète pas. Ton texte explique l'événement : ce qui va se passer, comment, et pourquoi ça compte.

Tu réécris aussi les lignes « En pratique » (affichées en haut de la carte, juste au-dessus de ton texte). On te donne les lignes actuelles : elles mélangent souvent du pratique et de l'explication, ce qui fait des répétitions avec ton résumé. Règle : « En pratique » = UNIQUEMENT ce qui sert à AGIR (quand regarder à l'heure locale, où et comment regarder ou suivre, sur quel appareil, prix et disponibilité, précautions comme les lunettes d'éclipse). Tout ce qui EXPLIQUE (la mission, ce qui est à bord, l'enjeu, ce qu'on saura, ce qui suit) va dans ton résumé, jamais dans « En pratique ». Chaque information n'apparaît qu'à UN seul endroit de la carte.

Méthode :
1. "releve" : relève d'abord 4 à 12 faits utiles des sources, chacun avec une "citation" de 5 à 15 mots COPIÉE MOT POUR MOT de la source (dans sa langue). Un fait sans citation exacte sera retiré.
2. "chapo" : 1 à 2 phrases, 40 mots au plus : ce qui va se passer, qui le fait, et pourquoi c'est attendu, avec au moins un repère concret. Se comprend seul.
3. "en_chiffres" : 0, ou 2 à 3 lignes comprises d'un coup d'œil. "valeur" = UN seul nombre AVEC son unité ou ce qu'il compte (« 26 caméras », « 1,5 million de km », « 3 h 20 »), 4 mots au plus, jamais deux nombres ni de barre oblique. "sens" = UNIQUEMENT une description de ce que représente la valeur, groupe nominal qui commence par une majuscule (« Nombre de télescopes réunis »), 10 mots au plus. Pas la date ni l'heure de l'événement (déjà en haut).
4. "blocs" : AUCUN paragraphe n'est imposé. Choisis les 2 à 4 angles qui font le mieux comprendre CET événement, dans l'ordre le plus logique. Pistes selon le cas : pour un lancement, la mission, ce qu'il y a à bord, ce qui se passe pendant le vol, les risques ; pour un phénomène dans le ciel, ce qu'on verra, pourquoi il se produit, comment bien l'observer ; pour une sortie de produit, ce qui change, le prix annoncé, pour qui ; pour un sommet ou des résultats attendus, l'enjeu, ce qui sera décidé ou annoncé. Chaque bloc : {"question": l'intertitre écrit pour CE sujet, comme la vraie question du lecteur, 10 mots au plus, jamais passe-partout (« Comment ça marche ? ») ; "texte": 1 à 3 phrases, 60 mots au plus}. Si les sources ne répondent pas PRÉCISÉMENT à un angle, n'écris pas de bloc pour lui.
5. "pratique" : 0 à 3 lignes, souvent 1 ou 2, et AUCUNE si rien de vraiment utile pour agir. Chaque ligne : {"k": icône parmi heure, direction, voir, lune, direct, duree, appareil, prix, lieu ; "t": titre de 1 à 3 mots (« Quand regarder », « Où regarder », « Prix », « Sur quoi ») ; "v": 14 mots au plus, concret}. Jamais la date ni le lieu de l'événement (déjà affichés), jamais une explication.
6. "limites" : 0 à 3 phrases précises, pour le LECTEUR, sur ce qui reste incertain d'après les sources (date susceptible de glisser et pourquoi, conditions météo, détails pas encore annoncés). Jamais une formule générale, jamais une étape déjà passée, jamais une note pour l'équipe (« à vérifier », « avant publication », « la source contredit… »).

Règles :
- N'invente rien : chaque fait, chiffre et nom vient des sources. Garde les nuances (« prévu », « selon l'agence », « si la météo le permet »). Pas de superlatif non attribué.
- Nomme ce qui est connu (fusée, agence, sonde, produit) et explique en quelques mots ce qui ne l'est pas. Phrases de 25 mots au plus, français simple, pas de jargon non expliqué.
- L'événement n'a pas encore eu lieu : écris au futur ou avec « doit », même si une source le décrit déjà comme passé.
- Unités françaises (km, km/h, kg, °C) : convertis miles, pieds, livres, °F. Une date est toujours complète (mois ET année).
- Aucune répétition : chaque fait n'est dit qu'une fois. Une seule monnaie par prix, sans conversion.
- Longueur totale (chapô + blocs + limites) : 120 à 220 mots selon la richesse des sources ; source courte, carte courte.
Réponds uniquement avec le JSON demandé."""

SCHEMA = {
    "type": "object",
    "properties": {
        "releve": {"type": "array", "items": {"type": "object", "properties": {
            "fait": {"type": "string"}, "citation": {"type": "string"}},
            "required": ["fait", "citation"], "additionalProperties": False}},
        "chapo": {"type": "string"},
        "en_chiffres": {"type": "array", "items": {"type": "object", "properties": {
            "valeur": {"type": "string"}, "sens": {"type": "string"}},
            "required": ["valeur", "sens"], "additionalProperties": False}},
        "blocs": {"type": "array", "items": {"type": "object", "properties": {
            "question": {"type": "string"}, "texte": {"type": "string"}},
            "required": ["question", "texte"], "additionalProperties": False}},
        "pratique": {"type": "array", "items": {"type": "object", "properties": {
            "k": {"type": "string"}, "t": {"type": "string"}, "v": {"type": "string"}},
            "required": ["k", "t", "v"], "additionalProperties": False}},
        "limites": {"type": "array", "items": {"type": "string"}},
    },
    "required": ["releve", "chapo", "en_chiffres", "blocs", "pratique", "limites"],
    "additionalProperties": False,
}

CONSIGNE_RELECTURE = """Tu es le relecteur le plus exigeant de NovaSTEM. On te donne le résumé d'une carte « À venir » (un événement attendu) et ses sources, seule base de faits autorisée. Compare-le phrase par phrase aux sources.
Corrige : tout fait, chiffre, nom, date ou bénéfice absent des sources ou déformé ; toute nuance perdue (« prévu », « selon… », « si la météo le permet ») ; tout superlatif non attribué ; toute répétition ; tout jargon non expliqué ; tout intertitre passe-partout ou qui n'annonce pas exactement ce que dit son paragraphe ; toute limite générale, qui est en fait un fait établi, qui parle d'une étape déjà passée ou qui s'adresse à l'équipe (« à vérifier ») ; toute unité anglo-saxonne non convertie ; toute phrase de plus de 25 mots ; toute ligne « pratique » qui explique au lieu de servir à agir, qui répète le résumé, ou qui donne la date ou le lieu (supprime-la) ; toute information présente à deux endroits de la carte. Les "Défauts MESURÉS automatiquement" fournis sont certains : corrige-les tous.
Rends la carte corrigée dans le même format, en ne changeant QUE ce qui doit l'être. Liste chaque défaut corrigé dans "problemes" (liste vide s'il n'y en a pas).
Réponds uniquement avec le JSON demandé."""

SCHEMA_RELECTURE = {
    "type": "object",
    "properties": {**{k: v for k, v in SCHEMA["properties"].items() if k != "releve"},
                   "problemes": {"type": "array", "items": {"type": "string"}}},
    "required": ["chapo", "en_chiffres", "blocs", "pratique", "limites", "problemes"],
    "additionalProperties": False,
}


def _url(db) -> str:
    return db.base.rsplit("/", 1)[0] + "/upcoming_events"


def _propre(x) -> str:
    return " ".join(str(x or "").split())


def _texte_ll2(l: dict) -> str:
    """Texte lisible d'un lancement de The Space Devs (Launch Library 2)."""
    m = l.get("mission") or {}
    fusee = ((l.get("rocket") or {}).get("configuration") or {})
    pad = l.get("pad") or {}
    morceaux = [
        f"Launch: {l.get('name', '')}.",
        f"Provider: {(l.get('launch_service_provider') or {}).get('name', '')}.",
        f"Rocket: {fusee.get('full_name') or fusee.get('name', '')}. {fusee.get('description') or ''}",
        f"Mission: {m.get('name', '')} ({m.get('type', '')}). {m.get('description') or ''}",
        f"Orbit: {(m.get('orbit') or {}).get('name', '')}.",
        f"Pad: {pad.get('name', '')}, {(pad.get('location') or {}).get('name', '')}.",
        f"Window: {l.get('window_start', '')} to {l.get('window_end', '')}.",
        f"Status: {(l.get('status') or {}).get('description') or (l.get('status') or {}).get('name', '')}.",
    ]
    return " ".join(_propre(x) for x in morceaux if _propre(x))


def _texte_carte(e: dict) -> str:
    """Ce que la carte sait déjà (écrit par l'agent à partir de la source) : base minimale."""
    pratique = e.get("pratique") or []
    lignes = " ".join(f"{p.get('t', '')} : {p.get('v', '')}." for p in pratique if isinstance(p, dict))
    return _propre(f"{e.get('title', '')}. {e.get('prevu') or ''} {e.get('pourquoi') or ''} "
                   f"Lieu : {e.get('lieu') or ''}. {lignes}")


def sources_de(e: dict, lire_page) -> list[str]:
    """Sources de la carte : article (lu par l'agent), ou fiche du lancement (LL2), ou à défaut
    le texte de la carte elle-même (écrit plus tôt à partir de la source)."""
    url = str(e.get("source_url") or "")
    srcs = []
    try:
        if "thespacedevs.com" in url:
            r = requests.get(url, timeout=30, params={"mode": "detailed"}, headers={"User-Agent": "NovaSTEM/1.0"})
            if r.status_code == 200:
                l = r.json()
                if str((l.get("status") or {}).get("abbrev", "")) in ("Success", "Failure", "Partial Failure", "In Flight"):
                    return None                     # déjà parti : pas de résumé « à venir »
                srcs.append(_texte_ll2(l))
        else:
            art = {"url": url, "title": e.get("title", ""), "text": "", "source_name": e.get("source_name", ""), "videos": []}
            lire_page(art)
            t = art.get("texte_long") or art.get("text") or ""
            if len(t) >= 600:
                srcs.append(t)
    except Exception:
        pass
    srcs.append(_texte_carte(e))
    return srcs


def _nettoyer(d: dict, sources: list[str]) -> list[str]:
    al = []
    garde = []
    for x in d.get("releve") or []:
        if fb.citation_ok(x.get("citation", ""), sources):
            garde.append(x)
        else:
            al.append(f"citation introuvable, fait retiré : {x.get('citation', '')}")
    d["releve"] = garde
    blocs, vues = [], set()
    for b in d.get("blocs") or []:
        q, t = _propre(b.get("question")), _propre(b.get("texte"))
        if not t:
            continue
        if not fb.question_ok(q) or q.lower() in vues:
            al.append(f"intertitre passe-partout ou répété : « {q} »")
            continue
        vues.add(q.lower())
        blocs.append({"question": q, "texte": t})
    d["blocs"] = blocs[:4]
    d["en_chiffres"] = fb.chiffres_clairs(d.get("en_chiffres"), al)
    if len(d["en_chiffres"]) < 2:
        d["en_chiffres"] = []
    lim = [_propre(x) for x in d.get("limites") or [] if _propre(x)]
    fb.alertes_limites(lim, al)
    if len(lim) > 3:
        al.append(f"{len(lim)} limites : 3 au plus")
    d["limites"] = lim[:3]
    textes = [d.get("chapo", "")] + [b["texte"] for b in d["blocs"]] + d["limites"]
    fb.alertes_unites([("texte", t) for t in textes], al)
    for t in textes:
        if fb.NOTE_REDACTEUR.search(t):
            al.append(f"phrase qui s'adresse à l'équipe, pas au lecteur (à supprimer) : {fb.NOTE_REDACTEUR.search(t).group(0)}")
    connus = set(fb.nombres(" ".join(sources)))
    inconnus = sorted({n for t in textes for n in fb.nombres(t)} - connus - {str(i) for i in range(11)})
    if inconnus:
        al.append(f"nombres absents des sources : {inconnus}")
    for t in textes:
        if fb.FORMULES_CREUSES.search(t):
            al.append(f"formule creuse : {fb.FORMULES_CREUSES.search(t).group(0)}")
        for ph in re.split(r"(?<=[.!?])\s+", t):
            if len(ph.split()) > 28:
                al.append(f"phrase de {len(ph.split())} mots")
    n = sum(len(t.split()) for t in textes)
    if n > 260:
        al.append(f"{n} mots : 220 visés, 260 au plus")
    return al


ICONES_PRATIQUES = {"heure", "direction", "voir", "lune", "direct", "duree", "appareil", "prix", "lieu"}


def pratique_de(d: dict) -> list[dict]:
    """25/11 (Maxime : trop de répétitions entre « En pratique » et « En bref ») : 3 lignes au plus,
    seulement pour agir. Aucune ligne = rien d'affiché."""
    out = []
    for x in d.get("pratique") or []:
        if not isinstance(x, dict):
            continue
        k, t, v = x.get("k"), _propre(x.get("t")), _propre(x.get("v"))
        if k in ICONES_PRATIQUES and t and v and len(v.split()) <= 20 and not fb.NOTE_REDACTEUR.search(v):
            out.append({"k": k, "t": t[:40], "v": v[:180]})
    return out[:3]          # [] (et non None) : sinon a_venir.py recompléterait la carte


def blocs_de(d: dict) -> list[dict]:
    """Même format que les fiches (colonne blocs) : lu par l'app (modele.dart, lireBlocs)."""
    # 25/11 : règles sûres, les notes pour l'équipe et les étapes passées ne s'affichent jamais
    res = [{"cle": "chapo", "texte": redaction.euros(fb.sans_note_redacteur(_propre(d.get("chapo"))))}]
    if d.get("en_chiffres"):
        res.append({"cle": "en_chiffres", "items": d["en_chiffres"]})
    for b in d["blocs"]:
        t = fb.sans_note_redacteur(b["texte"])
        if t:
            res.append({"cle": "autre", "question": b["question"], "texte": redaction.euros(t)})
    limites = fb.limites_finales(d.get("limites"))
    if limites:
        res.append({"cle": "limites", "puces": limites})
    return res


def _lignes(e: dict) -> str:
    l = e.get("pratique") or []
    if isinstance(l, str):
        try:
            l = json.loads(l)
        except Exception:
            l = []
    return "\n".join(f"- {x.get('t', '')} : {x.get('v', '')}" for x in l if isinstance(x, dict)) or "(aucune)"


def _cout(usage, prix, par_lot) -> float:
    if not usage:
        return 0.0
    entree = (usage.input_tokens or 0) + 1.25 * (getattr(usage, "cache_creation_input_tokens", 0) or 0) \
        + 0.1 * (getattr(usage, "cache_read_input_tokens", 0) or 0)
    return (0.5 if par_lot else 1.0) * (entree * prix[0] + (usage.output_tokens or 0) * prix[1]) / 1e6


def _demande(modele_id, consigne, contenu, schema) -> dict:
    return dict(model=modele_id, max_tokens=12000,
                system=[{"type": "text", "text": consigne, "cache_control": {"type": "ephemeral"}}],
                messages=[{"role": "user", "content": contenu}],
                output_config={"format": {"type": "json_schema", "schema": schema}, "effort": redaction.EFFORT},
                **economie.PARAMS_REDACTION)


def passage(db, client, modele_id: str, prix: tuple, lire_page, log, par_lot: bool = True,
            attente_lot: float = 900) -> float:
    """Écrit le résumé à blocs des prochaines cartes qui n'en ont pas. Jamais bloquant. Renvoie le coût."""
    from datetime import datetime, timedelta, timezone
    cout = 0.0
    try:
        # 25/11 : plus de résumé pour un événement passé (Ariane 64 du 24/11, Shenzhou-24 parti le matin)
        from zoneinfo import ZoneInfo
        depuis = datetime.now(ZoneInfo("Europe/Paris")).date().isoformat()
        r = requests.get(_url(db), headers=db.headers, timeout=30, params={
            "select": "id,title,type,event_date,lieu,prevu,pourquoi,pratique,source_url,source_name,statut,feed,blocs,event_utc",
            "event_date": f"gte.{depuis}", "blocs": "eq.[]", "statut": "neq.annule",
            "order": "event_date.asc", "limit": str(MAX_PAR_PASSAGE)})
        if r.status_code >= 400:
            if "blocs" in r.text:
                log("ℹ À venir : résumés à blocs en attente (lancer database/migration_025_a_venir_blocs.sql).")
            else:
                log(f"  ⚠ À venir (blocs) : lecture impossible ({r.status_code})")
            return 0.0
        cartes = r.json()
        if not cartes:
            return 0.0
        log(f"\n✎ À venir : résumé à blocs de {len(cartes)} carte(s)…")
        srcs = {e["id"]: sources_de(e, lire_page) for e in cartes}
        for e in [e for e in cartes if srcs[e["id"]] is None]:
            log(f"  · À venir : « {e.get('title', '')[:50]} » déjà parti, pas de résumé (la fiche « C'est arrivé » suivra)")
        cartes = [e for e in cartes if srcs[e["id"]] is not None]
        if not cartes:
            return 0.0
        demandes = {}
        for e in cartes:
            contenu = (f"Carte : {e.get('title', '')} · type : {e.get('type', '')} · date : {e.get('event_date', '')} · "
                       f"lieu : {e.get('lieu') or 'non précisé'}\n"
                       f"Heure exacte déjà affichée par l'app (à l'heure du lecteur) : {'oui, ne la répète pas' if e.get('event_utc') else 'non'}\n"
                       f"Lignes « En pratique » actuelles (à réécrire) :\n{_lignes(e)}\n\n"
                       + "\n\n".join(f"[SOURCE {i + 1}]\n{t}" for i, t in enumerate(srcs[e["id"]])))
            demandes[e["id"]] = _demande(modele_id, CONSIGNE, contenu, SCHEMA)
        rep, _ = redaction._appeler(client, demandes, par_lot, attente_lot, log)
        jets = {}
        for e in cartes:
            texte, usage, lot, arret = rep.get(e["id"], ("", None, False, "absent"))
            cout += _cout(usage, prix, lot)
            d = redaction._json(texte)
            if not _propre(d.get("chapo")):
                log(f"  ✗ « {e.get('title', '')[:50]} » : résumé vide ({arret})")
                continue
            jets[e["id"]] = (d, _nettoyer(d, srcs[e["id"]]))
        # Relecture contre les sources
        demandes = {}
        for e in cartes:
            if e["id"] not in jets:
                continue
            d, al = jets[e["id"]]
            mesures = ("Défauts MESURÉS automatiquement :\n- " + "\n- ".join(al) + "\n\n") if al else ""
            a_relire = {k: d.get(k) for k in ("chapo", "en_chiffres", "blocs", "pratique", "limites")}
            contenu = (f"Résumé à relire :\n{json.dumps(a_relire, ensure_ascii=False)}\n\n{mesures}"
                       + "\n\n".join(f"[SOURCE {i + 1}]\n{t}" for i, t in enumerate(srcs[e["id"]])))
            demandes[e["id"]] = _demande(modele_id, CONSIGNE_RELECTURE, contenu, SCHEMA_RELECTURE)
        rep, _ = redaction._appeler(client, demandes, par_lot, attente_lot, log)
        faits = 0
        for e in cartes:
            if e["id"] not in jets:
                continue
            d, al = jets[e["id"]]
            texte, usage, lot, arret = rep.get(e["id"], ("", None, False, "absent"))
            cout += _cout(usage, prix, lot)
            rr = redaction._json(texte)
            if _propre(rr.get("chapo")):
                rr["releve"] = d.get("releve")
                al2 = _nettoyer(rr, srcs[e["id"]])
                d = rr
            else:
                al2 = al
            if not d.get("blocs"):
                log(f"  ✗ « {e.get('title', '')[:50]} » : aucun paragraphe solide, carte laissée telle quelle")
                continue
            p = requests.patch(_url(db), headers=dict(db.headers, Prefer="return=minimal"), timeout=30,
                               params={"id": f"eq.{e['id']}"}, json={"blocs": blocs_de(d), "pratique": pratique_de(d)})
            if p.status_code < 300:
                faits += 1
                log(f"  ✎ À venir : « {e.get('title', '')[:60]} » — {len(d['blocs'])} paragraphe(s)"
                    f"{', reste : ' + ' ; '.join(al2)[:120] if al2 else ''}")
        log(f"À venir : {faits} résumé(s) à blocs écrit(s), {cout:.4f} $")
        return cout
    except Exception as ex:
        log(f"  ⚠ À venir : résumés à blocs ignorés ({ex.__class__.__name__}: {str(ex)[:100]})")
        return cout
