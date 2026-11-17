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


CONSIGNE = """Tu choisis une vidéo à mettre sous une fiche d'actualité scientifique ou technologique.
Garde une vidéo SEULEMENT si elle montre ou explique directement CE sujet précis (la démonstration, l'essai, l'objet, l'expérience, le lancement, la présentation officielle, ou une explication par les chercheurs ou l'entreprise concernés).
Réponds -1 (aucune) si les vidéos sont : sans rapport ou sur un autre sujet, une publicité, une bande-annonce de la chaîne, une invitation à s'abonner, un podcast ou une émission généraliste, une vidéo sur un sujet voisin mais différent. En cas de doute : -1.
Réponds en JSON : {"i": numéro de la vidéo choisie ou -1}."""

SCHEMA = {"type": "object", "properties": {"i": {"type": "integer"}}, "required": ["i"], "additionalProperties": False}

_COLONNES_ABSENTES = set()


def choisir(client, modele_id, titre: str, texte: str, urls: list[str], conso: dict) -> dict | None:
    """La vidéo qui montre le sujet, ou None."""
    infos = [x for x in (_infos(u) for u in urls[:MAX_CANDIDATS]) if x]
    if not infos:
        return None
    contenu = (f"Fiche : {titre}\nRésumé : {' '.join(texte.split())[:600]}\n\nVidéos trouvées dans l'article :\n"
               + "\n".join(f"{k}. « {x['titre']} » — chaîne : {x['chaine'] or 'inconnue'}" for k, x in enumerate(infos)))
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
    return infos[i] if 0 <= i < len(infos) else None


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
Exemple : une fiche « SpaceX rattrape le Starship avec la tour » ↔ une vidéo « Starship Flight 12 … catch » de SpaceX ou NASASpaceflight : oui.
Refuse (n'associe pas) : un sujet voisin mais différent (autre mission, autre produit, autre vol), une vidéo générale ou promotionnelle, un direct annoncé pour plus tard, un podcast, un résumé de l'actualité de la semaine. En cas de doute : n'associe pas.
Une vidéo peut servir à une seule fiche. Si plusieurs vidéos conviennent pour une fiche, préfère celle qui MONTRE l'événement (images réelles) et la chaîne de l'acteur concerné.
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
        if not fiches:
            return 0
        vids = videos_chaines(log)
        log(f"▶ Vidéos officielles : {len(vids)} vidéo(s) récente(s) sur {len(CHAINES_OFFICIELLES)} chaînes, "
            f"{len(fiches)} fiche(s) récente(s) sans vidéo")
        if not vids:
            return 0
        contenu = ("FICHES :\n" + "\n".join(
            f"{k}. [{str(f.get('published_at', ''))[:10]}] {f.get('title', '')} — {' '.join(str(f.get('summary') or '').split())[:180]}"
            for k, f in enumerate(fiches))
            + "\n\nVIDÉOS :\n" + "\n".join(
            f"{k}. [{v['date']}] « {v['titre']} » — chaîne : {v['chaine']}" for k, v in enumerate(vids)))
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


if __name__ == "__main__":
    # Test gratuit (aucun appel à Claude) : liste les vidéos récentes des chaînes officielles.
    for v in videos_chaines():
        print(f"{v['date']}  {v['chaine']:<18} {v['titre'][:90]}  {v['url']}")
