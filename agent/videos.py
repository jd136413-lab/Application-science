"""Vidéos à l'appui (demande de Maxime du 08/11/2026).

Quand l'article lu contient une vidéo (YouTube, Vimeo, Dailymotion) qui MONTRE l'avancée ou
l'événement (exemple : la voiture électrique à 500 km/h), on l'ajoute à la fiche : bouton
« ▶ Voir la vidéo » dans l'app.

1. `candidats(page)` : liens de vidéos trouvés dans le corps de la page (gratuit).
2. `_infos(url)` : titre et chaîne de la vidéo par oEmbed (gratuit, sans clé) ; une vidéo privée
   ou supprimée est écartée.
3. `attacher(...)` : Claude (Haiku, quelques centaines de mots) dit laquelle montre vraiment le
   sujet de la fiche, ou aucune (vidéo de publicité, d'abonnement, sans rapport…). Coût : moins
   de 0,0005 $ par fiche qui a des vidéos ; aucune dépense sans vidéo dans l'article.
"""

import html
import json
import sys
import re

import requests

import economie

MAX_CANDIDATS = 4
_UA = {"User-Agent": "NovaSTEM/1.0 (+https://jd136413-lab.github.io/Application-science/)"}

_MOTIFS = [
    # YouTube : intégrée, page, lien court, Shorts
    (re.compile(r"(?:youtube(?:-nocookie)?\.com/(?:embed/|watch\?(?:[^\"'<>\s]*?&(?:amp;)?)?v=|shorts/|live/|v/)|youtu\.be/)"
                r"([A-Za-z0-9_-]{11})"), "https://www.youtube.com/watch?v={}"),
    (re.compile(r"player\.vimeo\.com/video/(\d{6,12})"), "https://vimeo.com/{}"),
    (re.compile(r"(?<![\w.])vimeo\.com/(\d{6,12})(?!\d)"), "https://vimeo.com/{}"),
    (re.compile(r"dailymotion\.com/(?:embed/)?video/([a-zA-Z0-9]{5,10})"), "https://www.dailymotion.com/video/{}"),
    (re.compile(r"dai\.ly/([a-zA-Z0-9]{5,10})"), "https://www.dailymotion.com/video/{}"),
]

_OEMBED = {
    "youtube.com": "https://www.youtube.com/oembed",
    "vimeo.com": "https://vimeo.com/api/oembed.json",
    "dailymotion.com": "https://www.dailymotion.com/services/oembed",
}


def candidats(page: str) -> list[str]:
    """Vidéos du corps de la page (menus, pied de page, colonnes à côté retirés), dans l'ordre."""
    if not page:
        return []
    corps = re.sub(r"(?is)<(script(?![^>]*ld\+json)|style|nav|header|footer|aside|form)[^>]*>.*?</\1>", " ", page)
    # og:video (vidéo principale déclarée par le site) d'abord
    meta = re.findall(r'<meta[^>]+(?:property|name)=["\'](?:og:video(?::url|:secure_url)?|twitter:player)["\'][^>]+'
                      r'content=["\']([^"\']+)', page, re.I)
    texte = " ".join(meta) + " " + html.unescape(corps)
    vus, res = set(), []
    for pos_motif in sorted(((m.start(), m.group(1), fmt) for motif, fmt in _MOTIFS for m in motif.finditer(texte)),
                            key=lambda x: x[0]):
        _, ident, fmt = pos_motif
        url = fmt.format(ident)
        if url not in vus:
            vus.add(url)
            res.append(url)
        if len(res) >= MAX_CANDIDATS:
            break
    return res


def _infos(url: str) -> dict | None:
    hote = next((h for h in _OEMBED if h in url), None)
    if not hote:
        return None
    try:
        r = requests.get(_OEMBED[hote], params={"url": url, "format": "json"}, headers=_UA, timeout=15)
        if r.status_code != 200:
            return None                       # privée, supprimée ou intégration interdite
        j = r.json()
        titre = " ".join(str(j.get("title", "")).split())
        if not titre:
            return None
        return {"url": url, "titre": titre[:200], "chaine": " ".join(str(j.get("author_name", "")).split())[:80]}
    except Exception:
        return None


DUREE_MAX = 30 * 60     # au-delà (directs, conférences, émissions) : vidéo écartée d'office


_DUREES = {}   # identifiant de vidéo → durée en secondes (lue sur l'onglet « Vidéos » des chaînes)


def _lire_durees_chaine(ident: str) -> None:
    """Durées des dernières vidéos d'une chaîne (badge « 10:12 » des miniatures). Gratuit, jamais bloquant."""
    try:
        r = requests.get(f"https://www.youtube.com/channel/{ident}/videos", timeout=15, cookies={"CONSENT": "YES+1"},
                         headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                                                "(KHTML, like Gecko) Chrome/130.0 Safari/537.36", "Accept-Language": "en"})
        for txt, vid in re.findall(r'"thumbnailBadgeViewModel":\{"text":"(\d+(?::\d\d){1,2})"[^{}]*?'
                                   r'"animationActivationTargetId":"([\w-]{11})"', r.text if r.ok else ""):
            sec = 0
            for morceau in txt.split(":"):
                sec = sec * 60 + int(morceau)
            _DUREES.setdefault(vid, sec)
    except Exception:
        pass


def _duree(url: str) -> int | None:
    """Durée en secondes ; -1 = YouTube Short (moins de 3 minutes) ; None = inconnue."""
    m = re.search(r"[?&]v=([\w-]{11})", url)
    if not m:
        return None
    if m.group(1) in _DUREES:
        return _DUREES[m.group(1)]
    try:   # un Short s'ouvre en /shorts/ (200) ; une vidéo normale y est redirigée (303)
        r = requests.get(f"https://www.youtube.com/shorts/{m.group(1)}", allow_redirects=False, timeout=15,
                         headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/130.0"})
        return -1 if r.status_code == 200 else None
    except Exception:
        return None


def _avec_durees(videos: list[dict]) -> list[dict]:
    """Ajoute la durée (en parallèle) et retire les vidéos trop longues."""
    from concurrent.futures import ThreadPoolExecutor
    with ThreadPoolExecutor(8) as ex:
        for v, d in zip(videos, ex.map(lambda v: _duree(v["url"]), videos)):
            v["duree"] = d
    return [v for v in videos if not v.get("duree") or v["duree"] <= DUREE_MAX]


def _hms(d) -> str:
    if d == -1:
        return "Short (moins de 3 min)"
    return "durée inconnue" if not d else (f"{d // 60} min {d % 60:02d} s" if d >= 60 else f"{d} s")


CONSIGNE = """Tu choisis une vidéo à mettre sous une fiche d'actualité scientifique ou technologique.
Garde une vidéo SEULEMENT si elle montre ou explique directement CE sujet précis (la démonstration, l'essai, l'objet, l'expérience, le lancement, la présentation officielle, ou une explication par les chercheurs ou l'entreprise concernés).
Réponds -1 (aucune) si les vidéos sont : une présentation GÉNÉRALE de plusieurs produits ou annonces (keynote, « launch event », « product launch », conférence, salon, Unpacked, résumé de la semaine…) alors que la fiche parle d'UN seul produit ou résultat, sans rapport ou sur un autre sujet, une publicité, une bande-annonce de la chaîne, une invitation à s'abonner, un podcast ou une émission généraliste, une vidéo sur un sujet voisin mais différent. En cas de doute : -1.
Si plusieurs vidéos conviennent, choisis la plus COURTE et la plus PERCUTANTE : celle qui montre l'événement en images réelles (l'essai, le vol, la démonstration) ou dans laquelle les chercheurs ou l'entreprise en parlent directement. Évite les vidéos longues (plus de 10 minutes) s'il existe une vidéo courte sur le même sujet.
Réponds en JSON : {"i": numéro de la vidéo choisie ou -1}."""

SCHEMA = {"type": "object", "properties": {"i": {"type": "integer"}}, "required": ["i"], "additionalProperties": False}

_COLONNES_ABSENTES = set()

# 19/11 : vérification fiche par fiche, avant d'attacher TOUTE vidéo (Maxime a vu une vidéo du booster
# Super Heavy sous la fiche du VAISSEAU Starship rattrapé par la tour, et une vidéo de Starship sous une
# fiche sur les trous noirs). Un appel court par vidéo retenue (≈ 0,00005 $).
CONSIGNE_VERIF = """Tu vérifies qu'une vidéo correspond EXACTEMENT à une fiche d'actualité scientifique ou technologique.
D'abord, dans "raison", compare en une ou deux phrases ce que montre la vidéo (d'après son titre et sa chaîne) et ce que raconte la fiche. Ensuite "ok".
ok = true SEULEMENT si la vidéo montre ou explique le MÊME événement :
• le même objet ou engin (le vaisseau Starship n'est pas le booster Super Heavy ; un rover n'est pas l'hélicoptère qui l'accompagne) ;
• la même étape (le rattrapage par la tour n'est pas le décollage, ni la séparation, ni l'amerrissage ou l'explosion d'un autre étage) ;
• le même vol, la même mission, le même produit, le même résultat scientifique.
ok = false pour une vidéo sur le même programme, la même entreprise ou le même domaine mais sur un autre moment, un autre engin, un autre vol ou un autre sujet ; pour une vidéo sans rapport ; et dès que le titre ne permet pas d'en être sûr.
Réponds en JSON."""
SCHEMA_VERIF = {"type": "object", "properties": {"raison": {"type": "string"}, "ok": {"type": "boolean"}},
                "required": ["raison", "ok"], "additionalProperties": False}


def verifier(client, modele_id, titre: str, texte: str, video: dict, conso: dict, log=None) -> bool:
    """Vrai si la vidéo montre exactement le sujet de la fiche. Faux en cas de doute ou d'erreur."""
    contenu = (f"FICHE\nTitre : {titre}\nRésumé : {' '.join((texte or '').split())[:700]}\n\n"
               f"VIDÉO\nTitre : « {video.get('titre', '')} »\nChaîne : {video.get('chaine') or 'inconnue'}"
               f"\nDate : {video.get('date') or 'inconnue'} · Durée : {_hms(video.get('duree'))}")
    try:
        rep = client.messages.create(
            model=modele_id, max_tokens=300, system=CONSIGNE_VERIF,
            messages=[{"role": "user", "content": contenu}],
            output_config={"format": {"type": "json_schema", "schema": SCHEMA_VERIF}},
            **economie.PARAMS,
        )
        conso["in"] += rep.usage.input_tokens or 0
        conso["out"] += rep.usage.output_tokens or 0
        t = "".join(b.text for b in rep.content if getattr(b, "type", "") == "text")
        v = json.loads(t[t.find("{"):t.rfind("}") + 1])
        if not v.get("ok") and log:
            log(f"  ✗ vidéo refusée à la vérification : « {str(video.get('titre'))[:55]} » → {titre[:45]} "
                f"({str(v.get('raison', ''))[:90]})")
        return bool(v.get("ok"))
    except Exception:
        return False

# Vidéos « fourre-tout » (17/11, exemple : « Xiaomi New Product Launch November 2026 » sous une fiche
# sur UN téléphone) : écartées d'office, sauf si la fiche parle elle-même de l'événement.
_GENERALES = re.compile(r"(?i)\b(keynote|launch event|product launch|launch (?:of|in) (?:january|february|march|april|may|"
                        r"june|july|august|september|october|november|december)|special event|unpacked|livestream|"
                        r"event highlights|full event|recap|this week in|weekly|news roundup|round-?up|conference|"
                        r"lancement des nouveaut|conférence de presse)\b")
_FICHE_EVENEMENT = re.compile(r"(?i)\b(keynote|conférence|salon|présentation|événement|évènement|ces|mwc|wwdc|unpacked)\b")


def _generale(titre_video: str, titre_fiche: str) -> bool:
    return bool(_GENERALES.search(titre_video)) and not _FICHE_EVENEMENT.search(titre_fiche or "")


def choisir(client, modele_id, titre: str, texte: str, urls: list[str], conso: dict) -> dict | None:
    """La vidéo qui montre le sujet, ou None."""
    infos = [x for x in (_infos(u) for u in urls[:MAX_CANDIDATS]) if x and not _generale(x["titre"], titre)]
    infos = _avec_durees(infos)
    if not infos:
        return None
    contenu = (f"Fiche : {titre}\nRésumé : {' '.join(texte.split())[:600]}\n\nVidéos trouvées dans l'article :\n"
               + "\n".join(f"{k}. « {x['titre']} » — chaîne : {x['chaine'] or 'inconnue'} — {_hms(x.get('duree'))}" for k, x in enumerate(infos)))
    rep = client.messages.create(
        model=modele_id, max_tokens=300, system=CONSIGNE,
        messages=[{"role": "user", "content": contenu}],
        output_config={"format": {"type": "json_schema", "schema": SCHEMA}},
        **economie.PARAMS,
    )
    conso["in"] += rep.usage.input_tokens or 0
    conso["out"] += rep.usage.output_tokens or 0
    t = "".join(b.text for b in rep.content if getattr(b, "type", "") == "text")
    try:
        i = int(json.loads(t[t.find("{"):t.rfind("}") + 1]).get("i", -1))
    except Exception:
        return None
    if not 0 <= i < len(infos):
        return None
    return infos[i] if verifier(client, modele_id, titre, texte, infos[i], conso) else None


def attacher(table_url: str, headers: dict, ligne_id, titre: str, texte: str, urls: list[str],
             client, modele_id, conso: dict, log) -> bool:
    """Choisit la vidéo et l'enregistre sur la ligne (colonnes video_url, video_titre). Jamais bloquant."""
    if not urls or not ligne_id or table_url in _COLONNES_ABSENTES:
        return False
    try:
        v = choisir(client, modele_id, titre, texte, urls, conso)
        if not v:
            return False
        r = requests.patch(table_url, headers=dict(headers, Prefer="return=minimal"), timeout=30,
                           params={"id": f"eq.{ligne_id}"},
                           json={"video_url": v["url"], "video_titre": v["titre"]})
        if r.status_code == 400 and "video" in r.text:
            _COLONNES_ABSENTES.add(table_url)
            log("  ⚠ Vidéos : colonnes absentes (lancer database/migration_013_videos.sql dans Supabase)")
            return False
        r.raise_for_status()
        log(f"  ▶ vidéo ajoutée : « {v['titre'][:60]} » → {titre[:50]}")
        return True
    except Exception as ex:
        log(f"  ⚠ Vidéo non ajoutée ({ex.__class__.__name__}: {str(ex)[:80]})")
        return False


# ---------------------------------------------------------------------------------------------
# Vidéos des chaînes officielles (demande de Maxime du 17/11/2026)
#
# Beaucoup d'articles n'intègrent aucune vidéo, alors que la vidéo existe (exemple : le rattrapage
# du Starship par la tour, filmé par SpaceX). Ici, sans clé ni coût :
#   1. on lit le flux RSS public des chaînes YouTube ci-dessous (15 dernières vidéos de chacune) ;
#   2. on garde les vidéos des 9 derniers jours ;
#   3. on prend les fiches des 7 derniers jours qui n'ont pas encore de vidéo ;
#   4. UN SEUL appel à Claude associe les fiches aux vidéos qui les montrent vraiment.
# Comme les chaînes publient parfois quelques heures après l'événement, chaque passage de
# l'agent (matin et soir) refait la recherche pour les fiches récentes encore sans vidéo.
# Coût : ≈ 0,002 à 0,005 $ par passage (un seul appel), rien si aucune vidéo récente.
# Pour ajouter une chaîne : son @nom tel qu'il apparaît dans l'adresse youtube.com/@nom
# (plusieurs noms possibles séparés par | : le premier qui marche est gardé).
# ---------------------------------------------------------------------------------------------

CHAINES_OFFICIELLES = [
    # Espace : agences, entreprises et chaînes qui filment les lancements de près
    "SpaceX", "NASA", "NASAJPL", "NASAGoddard", "ESA|EuropeanSpaceAgency|ESAOfficial", "CNES|CNESFrance|cnes_france",
    "BlueOrigin", "RocketLab|RocketLabNZ|RocketLabUSA", "ISRO|isroofficial5866|ISROofficial", "NASASpaceflight", "EverydayAstronaut", "ESOobservatory",
    # Sciences : organismes, universités et laboratoires qui filment leurs expériences
    "CERN", "CNRS", "Inserm", "MIT", "ETHZurich|ETHZuerich", "EPFL|epflchannel", "Stanford", "Caltech",
    "harvard", "WyssInstitute", "cambridgeuniversity|CambridgeUniversity",
    # Technologies
    "BostonDynamics", "GoogleDeepMind", "OpenAI", "NVIDIA", "Google", "Apple", "Tesla",
    "Samsung", "Microsoft", "Meta", "BYD|BYDCompany|BYDAutoGlobal", "Airbus", "IEEESpectrum",
    # (Agences de presse Reuters, AFP, CGTN essayées le 17/11 et retirées : leur flux ne garde que
    # les 15 dernières vidéos, soit quelques heures d'actualité surtout politique.)
]
JOURS_VIDEOS = 9          # âge maximal d'une vidéo de chaîne prise en compte
JOURS_FICHES = 7          # fiches récentes encore sans vidéo examinées à chaque passage
MAX_FICHES = 60
MAX_VIDEOS = 220

_CHAINE_ID = {}


def _id_chaine(nom: str) -> str | None:
    """Identifiant UC… d'une chaîne à partir de son @nom (lu sur sa page publique)."""
    if nom in _CHAINE_ID:
        return _CHAINE_ID[nom]
    if "|" in nom:
        ident = next((i for i in (_id_chaine(n) for n in nom.split("|")) if i), None)
        _CHAINE_ID[nom] = ident
        return ident
    ident = None
    try:
        r = requests.get(f"https://www.youtube.com/@{nom}", headers=dict(_UA, **{"Accept-Language": "en"}),
                         cookies={"CONSENT": "YES+1"}, timeout=15)
        if r.ok:
            m = (re.search(r'<link rel="canonical" href="https://www\.youtube\.com/channel/(UC[\w-]{22})"', r.text)
                 or re.search(r'"externalId":"(UC[\w-]{22})"', r.text)
                 or re.search(r'"channelId":"(UC[\w-]{22})"', r.text))
            ident = m.group(1) if m else None
    except Exception:
        ident = None
    _CHAINE_ID[nom] = ident
    return ident


def videos_chaines(log=print) -> list[dict]:
    """Vidéos récentes des chaînes officielles : url, titre, chaîne, date (ISO)."""
    import datetime as dt
    limite = dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=JOURS_VIDEOS)
    res, ko = [], []
    for nom in CHAINES_OFFICIELLES:
        ident = _id_chaine(nom)
        if not ident:
            ko.append(nom.split("|")[0])
            continue
        nom = nom.split("|")[0]
        _lire_durees_chaine(ident)
        try:
            r = requests.get("https://www.youtube.com/feeds/videos.xml", params={"channel_id": ident},
                             headers=_UA, timeout=15)
            if not r.ok:
                ko.append(nom)
                continue
            for e in re.findall(r"(?s)<entry>(.*?)</entry>", r.text):
                vid = re.search(r"<yt:videoId>([\w-]{11})</yt:videoId>", e)
                titre = re.search(r"<title>(.*?)</title>", e, re.S)
                date = re.search(r"<published>(.*?)</published>", e)
                if not (vid and titre and date):
                    continue
                try:
                    d = dt.datetime.fromisoformat(date.group(1).replace("Z", "+00:00"))
                except ValueError:
                    continue
                if d < limite:
                    continue
                res.append({"url": f"https://www.youtube.com/watch?v={vid.group(1)}",
                            "titre": " ".join(html.unescape(titre.group(1)).split())[:200],
                            "chaine": nom, "date": d.strftime("%Y-%m-%d")})
        except Exception:
            ko.append(nom)
    if ko:
        log(f"  · chaînes vidéo non lues : {', '.join(ko)}")
    res.sort(key=lambda v: v["date"], reverse=True)
    return res[:MAX_VIDEOS]


CONSIGNE_ASSOCIATION = """Tu associes des fiches d'actualité scientifique ou technologique (en français) à des vidéos récentes de chaînes officielles (souvent en anglais).
Associe une vidéo à une fiche SEULEMENT si elle montre ou explique directement CE sujet précis : le lancement, l'essai, le vol, la démonstration, l'objet présenté, l'expérience, la présentation officielle par l'agence, l'entreprise ou les chercheurs concernés.
Exemple : une fiche « SpaceX rattrape le vaisseau Starship avec la tour » ↔ une vidéo qui montre le VAISSEAU (Ship) rattrapé par la tour : oui ; une vidéo du booster Super Heavy, du décollage ou d'un autre vol : non. Une fiche sur un autre sujet (trous noirs, biologie…) ↔ une vidéo de fusée : jamais.
Refuse (n'associe pas) : une présentation générale de plusieurs produits ou annonces (keynote, « launch event », conférence, salon, résumé de la semaine) pour une fiche sur UN seul produit ou résultat, un sujet voisin mais différent (autre mission, autre produit, autre vol), une vidéo générale ou promotionnelle, un direct annoncé pour plus tard, un podcast, un résumé de l'actualité de la semaine. En cas de doute : n'associe pas.
Une vidéo peut servir à une seule fiche. Si plusieurs vidéos conviennent pour une fiche, préfère la plus COURTE et la plus PERCUTANTE : celle qui MONTRE l'événement en images réelles (gros plan, plusieurs angles) ou où l'acteur concerné en parle directement, idéalement moins de 5 minutes. Évite les directs, les émissions et les vidéos de plus de 10 minutes quand une vidéo courte existe.
Réponds en JSON : {"paires": [{"fiche": numéro, "video": numéro}, ...]} (liste vide si aucune)."""

SCHEMA_ASSOCIATION = {
    "type": "object",
    "properties": {"paires": {"type": "array", "items": {
        "type": "object",
        "properties": {"fiche": {"type": "integer"}, "video": {"type": "integer"}},
        "required": ["fiche", "video"], "additionalProperties": False}}},
    "required": ["paires"], "additionalProperties": False,
}


def passage_chaines(table_url: str, headers: dict, client, modele_id, conso: dict, log=print) -> int:
    """Ajoute des vidéos officielles aux fiches récentes qui n'en ont pas. Jamais bloquant.
    Renvoie le nombre de vidéos ajoutées."""
    if table_url in _COLONNES_ABSENTES:
        return 0
    try:
        import datetime as dt
        depuis = (dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=JOURS_FICHES)).isoformat()
        r = requests.get(table_url, headers=headers, timeout=30, params={
            "select": "id,title,summary,published_at",
            "video_url": "is.null", "published_at": f"gte.{depuis}",
            "order": "importance.desc,published_at.desc", "limit": str(MAX_FICHES)})
        if r.status_code == 400 and "video" in r.text:
            _COLONNES_ABSENTES.add(table_url)
            return 0
        r.raise_for_status()
        fiches = r.json()
        # Ménage (17/11) : retire les vidéos « fourre-tout » déjà posées sur des fiches récentes (gratuit)
        try:
            rv = requests.get(table_url, headers=headers, timeout=30, params={
                "select": "id,title,video_titre", "video_url": "not.is.null", "published_at": f"gte.{depuis}"})
            for f in (rv.json() if rv.ok else []):
                if _generale(f.get("video_titre") or "", f.get("title") or ""):
                    requests.patch(table_url, headers=dict(headers, Prefer="return=minimal"), timeout=30,
                                   params={"id": f"eq.{f['id']}"}, json={"video_url": None, "video_titre": None})
                    log(f"  ✖ vidéo générale retirée : « {str(f.get('video_titre'))[:60]} » ← {str(f.get('title'))[:50]}")
        except Exception:
            pass
        if not fiches:
            return 0
        vids = [v for v in videos_chaines(log) if not _GENERALES.search(v["titre"])
                and not re.search(r"(?i)\blive\b|\bdirect\b|stream", v["titre"])]
        vids = _avec_durees(vids)
        log(f"▶ Vidéos officielles : {len(vids)} vidéo(s) récente(s) sur {len(CHAINES_OFFICIELLES)} chaînes, "
            f"{len(fiches)} fiche(s) récente(s) sans vidéo")
        if not vids:
            return 0
        contenu = ("FICHES :\n" + "\n".join(
            f"{k}. [{str(f.get('published_at', ''))[:10]}] {f.get('title', '')} — {' '.join(str(f.get('summary') or '').split())[:180]}"
            for k, f in enumerate(fiches))
            + "\n\nVIDÉOS :\n" + "\n".join(
            f"{k}. [{v['date']}] « {v['titre']} » — chaîne : {v['chaine']} — {_hms(v.get('duree'))}" for k, v in enumerate(vids)))
        rep = client.messages.create(
            model=modele_id, max_tokens=800, system=CONSIGNE_ASSOCIATION,
            messages=[{"role": "user", "content": contenu}],
            output_config={"format": {"type": "json_schema", "schema": SCHEMA_ASSOCIATION}},
            **economie.PARAMS,
        )
        conso["in"] += rep.usage.input_tokens or 0
        conso["out"] += rep.usage.output_tokens or 0
        t = "".join(b.text for b in rep.content if getattr(b, "type", "") == "text")
        paires = json.loads(t[t.find("{"):t.rfind("}") + 1]).get("paires") or []
        ajout, prises_f, prises_v = 0, set(), set()
        for p in paires:
            i, j = p.get("fiche", -1), p.get("video", -1)
            if not (0 <= i < len(fiches) and 0 <= j < len(vids)) or i in prises_f or j in prises_v:
                continue
            prises_f.add(i)
            prises_v.add(j)
            f, v = fiches[i], vids[j]
            if not verifier(client, modele_id, str(f.get("title") or ""), str(f.get("summary") or ""), v, conso, log):
                prises_v.discard(j)       # la vidéo reste libre pour une autre fiche… mais pas au même passage
                continue
            rr = requests.patch(table_url, headers=dict(headers, Prefer="return=minimal"), timeout=30,
                                params={"id": f"eq.{f['id']}", "video_url": "is.null"},
                                json={"video_url": v["url"], "video_titre": v["titre"]})
            if rr.ok:
                ajout += 1
                log(f"  ▶ vidéo officielle ({v['chaine']}) : « {v['titre'][:60]} » → {str(f.get('title'))[:50]}")
        return ajout
    except Exception as ex:
        log(f"  ⚠ Vidéos officielles non traitées ({ex.__class__.__name__}: {str(ex)[:80]})")
        return 0


def reverifier(table_url: str, headers: dict, client, modele_id, conso: dict, appliquer: bool, log=print) -> int:
    """Revérifie les vidéos des fiches des 30 derniers jours ; retire celles qui ne correspondent pas
    (seulement si appliquer). Renvoie le nombre de vidéos refusées."""
    from datetime import datetime, timedelta, timezone
    depuis = (datetime.now(timezone.utc) - timedelta(days=30)).isoformat()
    r = requests.get(table_url, headers=headers, timeout=30, params={
        "select": "id,title,summary,video_url,video_titre", "video_url": "not.is.null",
        "created_at": f"gte.{depuis}", "order": "created_at.desc", "limit": "200"})
    r.raise_for_status()
    refus = 0
    for f in r.json():
        v = {"titre": f.get("video_titre") or "", "chaine": None, "url": f["video_url"]}
        info = _infos(f["video_url"]) or {}
        v["chaine"] = info.get("chaine")
        ok = verifier(client, modele_id, f.get("title") or "", f.get("summary") or "", v, conso, log)
        print(f"{'✔' if ok else '✗'} {str(f.get('title'))[:60]}  ←  « {v['titre'][:60]} » ({v['chaine'] or '?'})")
        if not ok:
            refus += 1
            if appliquer:
                requests.patch(table_url, headers=dict(headers, Prefer="return=minimal"), timeout=30,
                               params={"id": f"eq.{f['id']}"},
                               json={"video_url": None, "video_titre": None}).raise_for_status()
    return refus


if __name__ == "__main__" and len(sys.argv) > 1 and sys.argv[1] == "reverifier":
    # Workflow « Revérifier les vidéos » : à blanc, ou en retirant les vidéos refusées (case cochée).
    import os
    from anthropic import Anthropic
    url = os.environ["SUPABASE_URL"].rstrip("/") + "/rest/v1/advances"
    cle = os.environ["SUPABASE_SECRET_KEY"]
    h = {"apikey": cle, "Authorization": f"Bearer {cle}"}
    appliquer = os.environ.get("APPLIQUER", "false") == "true"
    conso = {"in": 0, "out": 0}
    import main as agent
    n = reverifier(url, h, Anthropic(), agent.MODELES["haiku"]["id"], conso, appliquer)
    if appliquer:
        import images
        images.accorder_videos(url, h)   # retire aussi l'image tirée d'une vidéo retirée
    p = agent.MODELES["haiku"]["prix"]
    print(f"\n{n} vidéo(s) refusée(s){' et retirée(s)' if appliquer else ' (essai à blanc : rien n’est retiré)'} · "
          f"coût {(conso['in'] * p[0] + conso['out'] * p[1]) / 1e6:.4f} $")
elif __name__ == "__main__":
    # Test gratuit (aucun appel à Claude) : liste les vidéos récentes des chaînes officielles.
    vs = _avec_durees([v for v in videos_chaines() if not _GENERALES.search(v["titre"])])
    for v in vs:
        print(f"{v['date']}  {v['chaine']:<18} {_hms(v.get('duree')):<14} {v['titre'][:80]}  {v['url']}")
