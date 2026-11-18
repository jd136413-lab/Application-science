"""Images des fiches sans photo (18/11/2026, choix de Maxime, maquette 100) :
  B. d'abord, si la fiche a une vidéo YouTube : l'image de la vidéo (miniature officielle de YouTube) ;
  C. sinon, une photo libre de droits de Wikimedia Commons, SEULEMENT si Claude est sûr, en la
     regardant, qu'elle montre exactement le sujet (même appareil, lieu, espèce, objet…) ;
  sinon : pas d'image.
Les photos libres données par la source elle-même (NASA, ESO…) ne sont jamais remplacées.
Aucune image n'est stockée : la base ne garde que l'adresse de l'image (coût nul).
Coût de C : 2 petits appels à Haiku par fiche (≈ 0,0003 $). Jamais bloquant.
"""

import base64
import re

import requests

UA = {"User-Agent": "NovaSTEM/1.0 (https://jd136413-lab.github.io/Application-science/; application d'actualité scientifique)"}
COMMONS = "https://commons.wikimedia.org/w/api.php"
CREDIT_VIDEO = "Image de la vidéo"
MARQUE_COMMONS = "Wikimedia Commons"
JOURS = 30                  # fiches récentes dont on remet les images d'accord avec leur vidéo
MAX_PHOTOS = 10             # recherches de photos (C) au plus par passage
LICENCES_OK = ("cc0", "cc by", "cc-by", "public domain", "domaine public", "pd")


def id_youtube(url: str | None) -> str | None:
    m = re.search(r"(?:youtube\.com/(?:watch\?(?:.*&)?v=|shorts/|live/|embed/)|youtu\.be/)([A-Za-z0-9_-]{11})", url or "")
    return m.group(1) if m else None


def miniature(url_video: str | None) -> str | None:
    i = id_youtube(url_video)
    return f"https://i.ytimg.com/vi/{i}/hqdefault.jpg" if i else None


# ----------------------------------------------------------------------------- B : image de la vidéo

def accorder_videos(table_url: str, headers: dict, log=print) -> int:
    """Fiches récentes : image de la vidéo ajoutée quand il y a une vidéo YouTube et pas de photo de la source ;
    retirée quand la vidéo a été retirée ou changée. Renvoie le nombre de fiches modifiées."""
    from datetime import datetime, timedelta, timezone
    depuis = (datetime.now(timezone.utc) - timedelta(days=JOURS)).isoformat()
    h = dict(headers, Prefer="return=minimal")
    n = 0
    try:
        r = requests.get(table_url, headers=headers, timeout=30, params={
            "select": "id,video_url,image_url,image_credit", "created_at": f"gte.{depuis}",
            "or": "(video_url.not.is.null,image_url.like.*ytimg.com*)", "limit": "1000"})
        r.raise_for_status()
        for f in r.json():
            img, cred = f.get("image_url") or "", f.get("image_credit") or ""
            voulue = miniature(f.get("video_url"))
            est_miniature = "ytimg.com" in img
            if voulue and (not img or MARQUE_COMMONS in cred or (est_miniature and img != voulue)):
                nouveau = {"image_url": voulue, "image_credit": CREDIT_VIDEO}
            elif est_miniature and not voulue:
                nouveau = {"image_url": None, "image_credit": None}
            else:
                continue
            requests.patch(table_url, headers=h, timeout=30, params={"id": f"eq.{f['id']}"}, json=nouveau).raise_for_status()
            n += 1
    except Exception as ex:
        log(f"⚠ Images des vidéos non mises à jour ({ex.__class__.__name__})")
    return n


# ----------------------------------------------------------------------------- C : photo libre vérifiée

CONSIGNE_RECHERCHE = """On illustre une fiche d'actualité scientifique ou technologique avec une PHOTO libre de droits de Wikimedia Commons, seulement si on peut montrer EXACTEMENT la chose dont elle parle.
1. "nom_exact" : le NOM PROPRE de la chose concrète et unique au centre de la fiche, tel qu'on l'écrirait en anglais : un appareil ou véhicule nommé (« Starship », « Ingenuity », « James Webb Space Telescope »), un lieu ou site précis (« Chengjiang », « Mount Etna »), une espèce (nom courant ou scientifique). Laisse "" si la fiche n'a pas de tel nom : des robots, des chercheurs, une étude, une molécule, un logiciel, une méthode, un médicament, un concept, ou une chose seulement décrite (« un nouveau drone », « 20 petits robots »). Jamais une personne ni une entreprise seule.
2. "recherches" : si "nom_exact" n'est pas vide, 1 à 2 recherches (2 à 4 mots, en anglais) qui contiennent ce nom ; sinon, liste vide.
Réponds en JSON."""
SCHEMA_RECHERCHE = {"type": "object", "properties": {"nom_exact": {"type": "string"},
                                                      "recherches": {"type": "array", "items": {"type": "string"}}},
                    "required": ["nom_exact", "recherches"], "additionalProperties": False}

CONSIGNE_CHOIX = """Tu choisis la photo d'une fiche d'actualité scientifique ou technologique, parmi des photos libres de droits numérotées. Garde UNE photo seulement si tu es SÛR, en la regardant, qu'elle montre exactement le sujet de la fiche : le même appareil, véhicule, lieu, site, espèce ou objet (pas un modèle semblable, pas une illustration générale du domaine). Elle doit être une vraie photo nette : jamais un schéma, un logo, une carte, un graphique, une capture d'écran, un texte, un dessin. Jamais une photo dont le sujet principal est une personne. Dans le moindre doute, réponds -1 (pas d'image) : une fiche sans image vaut mieux qu'une image fausse. Réponds en JSON."""
SCHEMA_CHOIX = {"type": "object", "properties": {"choix": {"type": "integer"}, "raison": {"type": "string"}},
                "required": ["choix", "raison"], "additionalProperties": False}


def _json_appel(client, modele_id: str, systeme: str, contenu, schema: dict, conso: dict, max_tokens: int = 300) -> dict:
    import json
    rep = client.messages.create(model=modele_id, max_tokens=max_tokens, system=systeme,
                                 messages=[{"role": "user", "content": contenu}],
                                 output_config={"format": {"type": "json_schema", "schema": schema}})
    conso["in"] += rep.usage.input_tokens or 0
    conso["out"] += rep.usage.output_tokens or 0
    t = "".join(b.text for b in rep.content if getattr(b, "type", "") == "text")
    try:
        return json.loads(t[t.find("{"):t.rfind("}") + 1])
    except ValueError:
        return {}


def _sans_html(t: str) -> str:
    return " ".join(re.sub(r"<[^>]+>", " ", t or "").split())


def candidats_commons(recherche: str, n: int = 6) -> list[dict]:
    """Photos (JPEG/PNG, 800 px de large au moins, licence libre) trouvées pour une recherche."""
    r = requests.get(COMMONS, headers=UA, timeout=20, params={
        "action": "query", "format": "json", "generator": "search", "gsrsearch": f"{recherche} filetype:bitmap",
        "gsrnamespace": "6", "gsrlimit": "12", "prop": "imageinfo", "iiprop": "url|size|mime|extmetadata",
        "iiurlwidth": "1280"})
    if not r.ok or "json" not in r.headers.get("content-type", ""):
        return []
    pages = sorted((r.json().get("query") or {}).get("pages", {}).values(), key=lambda p: p.get("index", 99))
    res = []
    for p in pages:
        ii = (p.get("imageinfo") or [{}])[0]
        meta = ii.get("extmetadata") or {}
        licence = _sans_html((meta.get("LicenseShortName") or {}).get("value", ""))
        auteur = _sans_html((meta.get("Artist") or {}).get("value", ""))[:50]
        if ii.get("mime") not in ("image/jpeg", "image/png") or (ii.get("width") or 0) < 800:
            continue
        if not any(licence.lower().startswith(x) for x in LICENCES_OK):
            continue
        grande = ii.get("thumburl") or ii.get("url")
        if not grande or not grande.startswith("https://upload.wikimedia.org/"):
            continue
        desc = _sans_html((meta.get("ImageDescription") or {}).get("value", ""))[:300]
        res.append({"url": grande.split("?")[0], "petite": grande.split("?")[0].replace("/1280px-", "/400px-"),
                    "licence": licence, "auteur": auteur, "titre": p.get("title", ""), "description": desc})
        if len(res) >= n:
            break
    return res


def _image_b64(url: str) -> dict | None:
    try:
        r = requests.get(url, headers=UA, timeout=20)
        if not r.ok or len(r.content) > 1_500_000:
            return None
        type_ = "image/png" if r.headers.get("content-type", "").startswith("image/png") else "image/jpeg"
        return {"type": "image", "source": {"type": "base64", "media_type": type_,
                                            "data": base64.b64encode(r.content).decode()}}
    except Exception:
        return None


def photo_libre(client, modele_id: str, fiche: dict, conso: dict, log=print) -> dict | None:
    """Une photo Commons sûre pour cette fiche, ou None."""
    sujet = f"Titre : {fiche.get('title', '')}\nDécouverte : {fiche.get('decouverte') or fiche.get('summary') or ''}"
    rech = _json_appel(client, modele_id, CONSIGNE_RECHERCHE, sujet, SCHEMA_RECHERCHE, conso)
    nom = " ".join(str(rech.get("nom_exact", "")).split())
    recherches = [str(x).strip() for x in rech.get("recherches", []) if str(x).strip()][:2]
    if len(nom) < 3 or not recherches:
        log("  · pas de chose précise et nommée à montrer : pas d'image")
        return None
    # Le nom doit figurer dans le titre ou la description du fichier (sinon : photo d'une chose « semblable »)
    mots_nom = [m for m in re.findall(r"[a-z0-9]+", nom.lower()) if len(m) >= 3] or [nom.lower()]
    def parle_du_nom(c):
        t = (c["titre"] + " " + c["description"]).lower()
        return all(m in t for m in mots_nom)
    vus, cands = set(), []
    for q in recherches:
        try:
            trouves = candidats_commons(q)
        except Exception:
            trouves = []
        for c in trouves:
            if c["url"] not in vus and parle_du_nom(c):
                vus.add(c["url"])
                cands.append(c)
    blocs, gardes = [], []
    for c in cands[:6]:
        img = _image_b64(c["petite"]) or _image_b64(c["url"])
        if img:
            blocs += [{"type": "text", "text": f"Photo {len(gardes)} — fichier « {c['titre']} » : {c['description'][:150]}"}, img]
            gardes.append(c)
    if not gardes:
        return None
    rep = _json_appel(client, modele_id, CONSIGNE_CHOIX,
                      [{"type": "text", "text": f"{sujet}\nChose à montrer : {nom}"}] + blocs, SCHEMA_CHOIX, conso)
    k = rep.get("choix", -1)
    if not isinstance(k, int) or not 0 <= k < len(gardes):
        log(f"  · pas de photo sûre ({str(rep.get('raison', ''))[:70]})")
        return None
    c = gardes[k]
    credit = " · ".join(x for x in (c["auteur"], c["licence"], MARQUE_COMMONS) if x)
    return {"image_url": c["url"], "image_credit": credit[:120]}


def passage(table_url: str, headers: dict, client, modele_id: str, ajoutes: list, conso: dict, log=print) -> None:
    """À la fin d'un passage : B pour toutes les fiches récentes, puis C pour les nouvelles fiches restées sans image."""
    n_b = accorder_videos(table_url, headers, log)
    ids = [l.get("id") for l in ajoutes if l.get("id")]
    n_c = 0
    if ids:
        try:
            r = requests.get(table_url, headers=headers, timeout=30, params={
                "select": "id,title,decouverte,summary,image_url,video_url", "id": f"in.({','.join(ids)})"})
            r.raise_for_status()
            for f in r.json()[:MAX_PHOTOS]:
                if f.get("image_url") or miniature(f.get("video_url")):
                    continue
                try:
                    ph = photo_libre(client, modele_id, f, conso, log)
                except Exception as ex:
                    log(f"  · photo libre : erreur ({ex.__class__.__name__})")
                    ph = None
                if ph:
                    requests.patch(table_url, headers=dict(headers, Prefer="return=minimal"), timeout=30,
                                   params={"id": f"eq.{f['id']}", "image_url": "is.null"}, json=ph).raise_for_status()
                    n_c += 1
                    log(f"  🖼 photo libre : {str(f.get('title'))[:60]} ← {ph['image_credit']}")
        except Exception as ex:
            log(f"⚠ Photos libres non cherchées ({ex.__class__.__name__})")
    log(f"Images : {n_b} image(s) de vidéo mises à jour, {n_c} photo(s) libre(s) ajoutée(s).")


if __name__ == "__main__":
    # Essai à blanc (workflow « Tester les images ») : rien n'est écrit dans la base.
    import os
    from anthropic import Anthropic
    import main as agent
    url = os.environ["SUPABASE_URL"].rstrip("/") + "/rest/v1/advances"
    cle = os.environ["SUPABASE_SECRET_KEY"]
    h = {"apikey": cle, "Authorization": f"Bearer {cle}"}
    fiches = requests.get(url, headers=h, timeout=30, params={
        "select": "id,title,decouverte,summary,image_url,video_url,image_credit", "order": "created_at.desc",
        "limit": "60"}).json()
    avec_video = [f for f in fiches if miniature(f.get("video_url"))]
    print(f"B — {len(avec_video)} fiche(s) récente(s) avec une vidéo YouTube :")
    for f in avec_video[:8]:
        print(f"  {f['title'][:70]}\n    → {miniature(f['video_url'])}  (image actuelle : {f.get('image_url') or 'aucune'})")
    client, conso = Anthropic(), {"in": 0, "out": 0}
    sans = [f for f in fiches if not f.get("image_url") and not miniature(f.get("video_url"))][:8]
    print(f"\nC — photo libre pour {len(sans)} fiche(s) sans image :")
    for f in sans:
        print(f"\n▶ {f['title']}")
        try:
            ph = photo_libre(client, agent.MODELES["haiku"]["id"], f, conso, log=print)
        except Exception as ex:
            ph = None
            print(f"  erreur : {ex.__class__.__name__}: {str(ex)[:120]}")
        print(f"  {'✔ ' + ph['image_url'] + '  [' + ph['image_credit'] + ']' if ph else '— pas d’image'}")
    p = agent.MODELES["haiku"]["prix"]
    print(f"\nCoût de l'essai : {(conso['in'] * p[0] + conso['out'] * p[1]) / 1e6:.4f} $")
