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
