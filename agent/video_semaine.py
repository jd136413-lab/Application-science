# Vidéo de la semaine (09/11/2026)
#
# Fabrique automatiquement une vidéo verticale (format Shorts / Reels / TikTok)
# sur la meilleure avancée des 7 derniers jours :
#   1. choix de l'avancée (note d'importance + lectures/favoris dans l'app) ;
#   2. texte écrit par Haiku : une accroche forte, puis une explication claire ;
#   3. voix : ElevenLabs ou Google si une clé est rangée dans les secrets GitHub,
#      sinon une voix libre (gratuite, mais moins naturelle) ;
#   4. images : photo de la fiche, puis images libres (Wikimedia Commons, NASA),
#      sinon des écrans graphiques ;
#   5. montage : sous-titres mot à mot, musique douce, logo et écran de fin.
# Résultat : sortie/video_semaine.mp4 + sortie/description.txt (à coller en publiant).
# Lancé par le workflow « Vidéo de la semaine » (.github/workflows/video.yml).

import base64, io, json, math, os, random, re, subprocess, sys, textwrap
from datetime import datetime, timedelta, timezone

import numpy as np
import requests
import soundfile as sf
from PIL import Image, ImageDraw, ImageFilter, ImageFont

# ------------------------------------------------------------------ réglages
MODELE = "claude-haiku-5-5"
DUREE_MAX_MOTS = 105          # ≈ 40 secondes de voix
W, H, FPS = 1080, 1920, 30
SORTIE = "sortie"
JAUNE, BLANC, NOIR, BLEU = (255, 212, 59), (255, 255, 255), (0, 0, 0), (61, 123, 255)
UA = {"User-Agent": "NovaSTEM-video/1.0 (application NovaSTEM ; vidéo hebdomadaire)"}
# Couleurs de fond par famille (mêmes teintes que l'app, en plus sombre)
FONDS = {"space": (24, 30, 70), "health": (70, 24, 40), "earth": (70, 52, 26), "life": (24, 64, 40),
         "physics": (40, 30, 80), "environment": (20, 64, 56), "tech": (20, 48, 80)}


COUTS = {"haiku": 0.0, "caracteres_voix": 0}


def log(*a):
    print(*a, flush=True)


# ------------------------------------------------------------------ 1. choix
def choisir_avancees():
    url, cle = os.environ["SUPABASE_URL"].rstrip("/"), os.environ["SUPABASE_SECRET_KEY"]
    h = {"apikey": cle}
    if cle.startswith("eyJ"):
        h["Authorization"] = f"Bearer {cle}"
    depuis = (datetime.now(timezone.utc) - timedelta(days=7)).isoformat()
    r = requests.get(f"{url}/rest/v1/advances", headers=h, timeout=30, params={
        "select": "id,title,summary,avant,decouverte,apres,importance,family,feed,source_name,source_url,image_url,image_credit,created_at",
        "created_at": f"gte.{depuis}", "order": "importance.desc,created_at.desc", "limit": "200"})
    r.raise_for_status()
    fiches = r.json()
    if not fiches:
        raise SystemExit("Aucune fiche publiée ces 7 derniers jours.")
    # Intérêt dans l'app : lectures, favoris, partages, clics vers la source.
    interet = {}
    try:
        s = requests.get(f"{url}/rest/v1/stats", headers=h, timeout=30, params={
            "select": "avancee_id,evenement", "cree_le": f"gte.{depuis}",
            "evenement": "in.(lecture,favori,partage,article)", "limit": "20000"})
        s.raise_for_status()
        poids = {"lecture": 1, "article": 2, "favori": 3, "partage": 4}
        for e in s.json():
            if e.get("avancee_id"):
                interet[e["avancee_id"]] = interet.get(e["avancee_id"], 0) + poids[e["evenement"]]
    except Exception as ex:
        log(f"(statistiques indisponibles : {ex.__class__.__name__}, choix sur la note seule)")
    for f in fiches:
        f["_score"] = (f.get("importance") or 1) * 10 + min(15, interet.get(f["id"], 0))
    fiches.sort(key=lambda f: -f["_score"])
    return fiches[:6]


# ------------------------------------------------------------------ 2. texte
CONSIGNE = """Tu écris le texte d'une vidéo courte verticale (YouTube Shorts, Instagram Reels) pour NovaSTEM,
une application gratuite qui résume les avancées scientifiques et technologiques. Public : grand public
francophone de 15 à 60 ans, qui fait défiler son fil et décide en 2 secondes de regarder ou non.

Parmi les avancées proposées, choisis celle qui fera la meilleure vidéo : la plus marquante pour le grand
public, facile à expliquer, avec un chiffre ou une image forte. Puis écris le texte.

RÈGLES (les plus importantes d'abord)
1. ACCROCHE (scène 1) : une phrase choc de 12 mots au plus, qui donne envie de rester ET dit clairement
   de quoi on parle. Un fait surprenant, un chiffre fort ou une question directe. Mots de tous les jours,
   aucune métaphore obscure, aucun mot technique. On doit comprendre le sujet à la première écoute.
   Bon : « Des patients paralysés ont remarché grâce à leurs propres cellules. »
   Mauvais : « Des dents de 400 000 ans viennent de parler. » (on ne comprend pas de quoi il s'agit)
2. EXPLICATION (scènes 2 à 5) : une seule idée par scène, dans l'ordre : le problème avant, ce qui a été
   fait, le résultat (avec le chiffre clé), ce que ça change pour nous. Phrases courtes (15 mots au plus),
   comme si tu expliquais à un ami. Tout mot technique est expliqué en quelques mots ou remplacé.
   Une comparaison concrète vaut mieux qu'un chiffre abstrait.
3. VÉRITÉ : uniquement des faits présents dans la fiche. N'invente rien, n'exagère rien. Si c'est une
   étude préliminaire (animaux, laboratoire), dis-le simplement.
4. Le texte « voix » est lu par une voix de synthèse : écris les nombres en lettres (« vingt et un pour
   cent »), pas de sigle sans l'expliquer, pas de parenthèses. Le texte « ecran » est le même, avec les
   nombres en chiffres (« 21 % »), pour les sous-titres.
5. En tout, 95 mots au plus pour les 5 scènes (environ 35 secondes). Ne mets pas de phrase de fin :
   l'écran de fin NovaSTEM est ajouté automatiquement.

Pour chaque scène, donne aussi 2 ou 3 mots-clés EN ANGLAIS pour chercher une photo libre de droits qui
illustre la phrase (choses concrètes et photographiables : « fossil tooth », « laboratory microscope »,
« Philippines people »), et, si la scène contient le chiffre clé, ce chiffre court (« 21 % ») et une
légende de 6 mots au plus.

Écris enfin la description de la publication : 2 phrases simples + 4 à 6 hashtags en français."""

SCHEMA = {
    "type": "object",
    "properties": {
        "choix": {"type": "integer", "description": "numéro de l'avancée choisie"},
        "sujet": {"type": "string", "description": "2 ou 3 mots en majuscules affichés au début, ex. ÉVOLUTION HUMAINE"},
        "scenes": {"type": "array", "minItems": 5, "maxItems": 5, "items": {
            "type": "object",
            "properties": {
                "voix": {"type": "string"}, "ecran": {"type": "string"},
                "mots_cles_image": {"type": "string"},
                "chiffre": {"type": "string", "description": "chiffre clé court, 6 caractères au plus, ex. 21 %"}, "legende": {"type": "string"}},
            "required": ["voix", "ecran", "mots_cles_image"]}},
        "description": {"type": "string"},
    },
    "required": ["choix", "sujet", "scenes", "description"],
}


def ecrire_texte(fiches):
    import anthropic
    client = anthropic.Anthropic()
    blocs = []
    for i, f in enumerate(fiches):
        corps = "\n".join(x for x in [f.get("avant"), f.get("decouverte"), f.get("apres")] if x) or f.get("summary") or ""
        blocs.append(f"[{i}] {f['title']} (importance {f.get('importance')}/5, source {f.get('source_name')})\n{corps}")
    r = client.messages.create(
        model=MODELE, max_tokens=2000, system=CONSIGNE,
        tools=[{"name": "video", "description": "Texte de la vidéo", "input_schema": SCHEMA}],
        tool_choice={"type": "tool", "name": "video"},
        messages=[{"role": "user", "content": "Avancées de la semaine :\n\n" + "\n\n".join(blocs)}])
    texte = next(b.input for b in r.content if b.type == "tool_use")
    cout = r.usage.input_tokens * 0.10 / 1e6 + r.usage.output_tokens * 0.50 / 1e6
    COUTS["haiku"] = cout
    log(f"Texte écrit par Haiku ({cout:.4f} $).")
    choix = max(0, min(len(fiches) - 1, int(texte.get("choix", 0))))
    return fiches[choix], texte


# ------------------------------------------------------------------ 3. voix
def voix_elevenlabs(phrase):
    cle = os.environ["ELEVENLABS_API_KEY"]
    voix = os.environ.get("ELEVENLABS_VOICE") or "21m00Tcm4TlvDq8ikWAM"
    r = requests.post(f"https://api.elevenlabs.io/v1/text-to-speech/{voix}", timeout=120,
                      headers={"xi-api-key": cle, "Accept": "audio/mpeg"},
                      params={"output_format": "mp3_44100_128"},
                      json={"text": phrase, "model_id": os.environ.get("ELEVENLABS_MODEL") or "eleven_multilingual_v2"})
    r.raise_for_status()
    return mp3_vers_tableau(r.content)


def voix_google(phrase):
    cle = os.environ["GOOGLE_TTS_API_KEY"]
    nom = os.environ.get("GOOGLE_TTS_VOICE") or "fr-FR-Chirp3-HD-Charon"
    r = requests.post("https://texttospeech.googleapis.com/v1/text:synthesize", params={"key": cle}, timeout=120,
                      json={"input": {"text": phrase}, "voice": {"languageCode": "fr-FR", "name": nom},
                            "audioConfig": {"audioEncoding": "LINEAR16", "sampleRateHertz": 44100}})
    r.raise_for_status()
    a, sr = sf.read(io.BytesIO(base64.b64decode(r.json()["audioContent"])))
    return a, sr


_kokoro = None
def voix_libre(phrase):
    global _kokoro
    if _kokoro is None:
        from kokoro_onnx import Kokoro
        _kokoro = Kokoro("modeles/kokoro.onnx", "modeles/voices.bin")
    a, sr = _kokoro.create(phrase, voice="ff_siwis", speed=0.98, lang="fr-fr")
    return a, sr


def mp3_vers_tableau(octets):
    p = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", "pipe:0", "-f", "wav", "-ac", "1", "-ar", "44100", "pipe:1"],
                       input=octets, capture_output=True, check=True)
    return sf.read(io.BytesIO(p.stdout))


def fabriquer_voix(phrases):
    if os.environ.get("ELEVENLABS_API_KEY"):
        moteurs = [("ElevenLabs", voix_elevenlabs), ("voix libre", voix_libre)]
    elif os.environ.get("GOOGLE_TTS_API_KEY"):
        moteurs = [("Google", voix_google), ("voix libre", voix_libre)]
    else:
        moteurs = [("voix libre", voix_libre)]
    for nom, f in moteurs:
        try:
            morceaux, segs, t = [], [], 0.0
            for p in phrases:
                a, sr = f(p)
                COUTS["caracteres_voix"] += len(p)
                a = np.asarray(a, dtype=np.float32)
                if a.ndim > 1:
                    a = a.mean(axis=1)
                if sr != 44100:
                    a = np.interp(np.arange(0, len(a) * 44100 / sr) * sr / 44100, np.arange(len(a)), a).astype(np.float32)
                segs.append((t, t + len(a) / 44100))
                morceaux += [a, np.zeros(int(0.22 * 44100), np.float32)]
                t += len(a) / 44100 + 0.22
            if nom == "voix libre":
                COUTS["caracteres_voix"] = 0
            log(f"Voix : {nom}.")
            return np.concatenate(morceaux), segs, nom
        except Exception as ex:
            log(f"⚠ Voix {nom} impossible ({ex.__class__.__name__}: {str(ex)[:150]}) — essai suivant.")
    raise SystemExit("Aucune voix n'a fonctionné.")


# ------------------------------------------------------------------ 4. images
LICENCES_OK = ("cc0", "public domain", "pd", "cc by", "cc-by", "cc by-sa", "cc-by-sa")


def image_wikimedia(mots):
    r = requests.get("https://commons.wikimedia.org/w/api.php", headers=UA, timeout=30, params={
        "action": "query", "format": "json", "generator": "search", "gsrnamespace": "6", "gsrlimit": "12",
        "gsrsearch": f"{mots} filetype:bitmap", "prop": "imageinfo", "iiprop": "url|extmetadata|size",
        "iiurlwidth": "1400"})
    r.raise_for_status()
    pages = sorted((r.json().get("query") or {}).get("pages", {}).values(), key=lambda p: p.get("index", 99))
    for p in pages:
        ii = (p.get("imageinfo") or [{}])[0]
        meta = ii.get("extmetadata") or {}
        lic = (meta.get("LicenseShortName", {}).get("value") or "").lower()
        if not lic.startswith(LICENCES_OK) or ii.get("width", 0) < 700:
            continue
        auteur = re.sub("<[^>]+>", "", meta.get("Artist", {}).get("value") or "").strip()[:40]
        return ii.get("thumburl") or ii["url"], f"Photo : {auteur or 'Wikimedia Commons'} · {meta['LicenseShortName']['value']}"
    return None


def image_nasa(mots):
    r = requests.get("https://images-api.nasa.gov/search", headers=UA, timeout=30,
                     params={"q": mots, "media_type": "image", "page_size": "10"})
    r.raise_for_status()
    for it in r.json()["collection"]["items"]:
        liens = it.get("links") or []
        if liens:
            return liens[0]["href"].replace("~thumb", "~medium"), "Image : NASA (domaine public)"
    return None


def telecharger(url):
    r = requests.get(url, headers=UA, timeout=60)
    r.raise_for_status()
    im = Image.open(io.BytesIO(r.content)).convert("RGB")
    if im.width < 500:
        raise ValueError("image trop petite")
    return im


def chercher_images(fiche, scenes):
    images, deja = [], set()
    for i, s in enumerate(scenes):
        trouve = None
        if i == 0 and fiche.get("image_url"):
            try:
                trouve = (telecharger(fiche["image_url"]), fiche.get("image_credit") or "Photo : source de l'article")
            except Exception:
                pass
        mots = (s.get("mots_cles_image") or "").strip()
        for chercheur in ([image_nasa, image_wikimedia] if fiche.get("family") == "space" else [image_wikimedia, image_nasa]):
            if trouve or not mots:
                break
            try:
                res = chercheur(mots)
                if res and res[0] not in deja:
                    trouve = (telecharger(res[0]), res[1])
                    deja.add(res[0])
            except Exception as ex:
                log(f"  (image « {mots} » : {ex.__class__.__name__})")
        images.append(trouve)
        log(f"  Scène {i + 1} : {'image trouvée — ' + trouve[1] if trouve else 'écran graphique'}")
    return images


# ------------------------------------------------------------------ 4 bis. calage des sous-titres
def _norm(m):
    m = m.lower().replace("’", "'")
    m = re.sub(r"[^\w'%]", "", m)
    return m.split("'")[-1] if "'" in m else m


def caler_mots(voix, segs, scenes):
    """Moment exact où chaque mot est prononcé : la voix est réécoutée par Whisper
    (reconnaissance vocale gratuite), puis ses mots sont alignés sur le texte affiché.
    Retourne, pour chaque scène, la liste (début, fin) de chacun de ses mots, ou None."""
    try:
        from faster_whisper import WhisperModel
        idx = np.arange(0, len(voix) * 16000 / 44100) * 44100 / 16000
        wav16 = np.interp(idx, np.arange(len(voix)), voix).astype(np.float32)  # tableau 16 kHz, sans décodeur audio
        modele = WhisperModel(os.environ.get("WHISPER_MODELE") or "small", device="cpu", compute_type="int8")
        morceaux, _ = modele.transcribe(wav16, language="fr", word_timestamps=True, beam_size=1)
        entendus = [(w.start, w.end, _norm(w.word)) for m in morceaux for w in (m.words or [])]
    except Exception as ex:
        log(f"⚠ Calage précis des sous-titres impossible ({ex.__class__.__name__}: {str(ex)[:120]}) : calage approximatif.")
        print(f"::warning title=Sous-titres::{ex.__class__.__name__}: {str(ex)[:300]}", flush=True)
        return None
    import difflib
    resultat = []
    for s, (t0, t1) in zip(scenes, segs):
        affiches = [w for w in s["ecran"].replace(" %", "\u00a0%").replace(" :", "\u00a0:").split(" ") if w]
        ent = [e for e in entendus if t0 - 0.3 <= (e[0] + e[1]) / 2 <= t1 + 0.3]
        temps = [None] * len(affiches)
        sm = difflib.SequenceMatcher(None, [_norm(w) for w in affiches], [e[2] for e in ent], autojunk=False)
        for a, b, n in sm.get_matching_blocks():
            for k in range(n):
                temps[a + k] = (ent[b + k][0], ent[b + k][1])
        # mots non reconnus (nombres écrits en chiffres…) : placés entre leurs voisins
        connus = [k for k, x in enumerate(temps) if x]
        for k in range(len(temps)):
            if temps[k]:
                continue
            avant = max([j for j in connus if j < k], default=None)
            apres = min([j for j in connus if j > k], default=None)
            ta = temps[avant][1] if avant is not None else t0
            tb = temps[apres][0] if apres is not None else t1
            j0 = (avant if avant is not None else -1)
            j1 = (apres if apres is not None else len(temps))
            pas = (tb - ta) / (j1 - j0)
            temps[k] = (ta + pas * (k - j0 - 1), ta + pas * (k - j0))
        resultat.append(temps)
    n_ok = sum(1 for e in entendus)
    log(f"Sous-titres calés sur la voix ({n_ok} mots reconnus).")
    return resultat


# ------------------------------------------------------------------ 4 ter. musique libre de droits
AMBIANCES = {  # mots cherchés dans l'ambiance (« feel ») des musiques de Kevin MacLeod (incompetech, CC BY 4.0)
    "space": ["mysterious", "epic", "calming"], "physics": ["mysterious", "driving", "bright"],
    "health": ["hopeful", "uplifting", "calming"], "life": ["bright", "uplifting", "calming"],
    "earth": ["mysterious", "epic", "uplifting"], "environment": ["calming", "hopeful", "uplifting"],
    "tech": ["driving", "bright", "uplifting"]}
GENRES_EXCLUS = ("holiday", "horror", "silent film", "comedy", "polka", "children", "funk")


def _texte(x):
    if isinstance(x, list):
        return " ".join(map(str, x)).lower()
    return str(x or "").lower()


def choisir_musique(famille):
    """Musique de Kevin MacLeod (incompetech.com, licence CC BY 4.0, crédit obligatoire),
    choisie au hasard parmi celles dont l'ambiance correspond au domaine."""
    try:
        r = requests.get("https://incompetech.com/music/royalty-free/pieces.json", headers=UA, timeout=60)
        r.raise_for_status()
        pieces = r.json()
        if isinstance(pieces, dict):
            pieces = next((v for v in pieces.values() if isinstance(v, list)), [])
        voulus = AMBIANCES.get(famille, ["uplifting", "bright", "mysterious"])
        candidats = []
        for p in pieces:
            feel, genre = _texte(p.get("feel")), _texte(p.get("genre"))
            if not p.get("filename") or any(g in genre for g in GENRES_EXCLUS):
                continue
            score = sum(1 for v in voulus if v in feel)
            if score:
                candidats.append((score, p))
        if not candidats:
            raise ValueError("aucune musique adaptée")
        meilleur = max(c[0] for c in candidats)
        pool = [p for sc, p in candidats if sc == meilleur]
        random.shuffle(pool)
        for p in pool[:5]:
            try:
                url = "https://incompetech.com/music/royalty-free/mp3-royaltyfree/" + requests.utils.quote(p["filename"])
                m = requests.get(url, headers=UA, timeout=120)
                m.raise_for_status()
                a, sr = mp3_vers_tableau(m.content)
                if len(a) / sr < 45:
                    continue
                credit = f"Musique : « {p.get('title')} » Kevin MacLeod (incompetech.com), licence CC BY 4.0"
                log(credit)
                return np.asarray(a, dtype=np.float32), credit
            except Exception as ex:
                log(f"  (musique {p.get('title')} : {ex.__class__.__name__})")
    except Exception as ex:
        log(f"⚠ Musique libre indisponible ({ex.__class__.__name__}: {str(ex)[:100]}) : fond musical de secours.")
    return None, None


# ------------------------------------------------------------------ 5. montage
def police(taille, style="ExtraBold", f="polices/bric.ttf"):
    p = ImageFont.truetype(f, taille)
    try:
        p.set_variation_by_name(style)
    except Exception:
        pass
    return p


def ease(x):
    x = min(max(x, 0), 1)
    return x * x * (3 - 2 * x)


def degrade(c1, c2):
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    d = np.clip(np.hypot(x / W - .5, (y / H - .42) * .6) / .75, 0, 1)
    img = np.array(c1, np.float32) * (1 - d[..., None]) + np.array(c2, np.float32) * d[..., None]
    img += np.random.default_rng(3).normal(0, 3, img.shape)
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))


def preparer_photo(im):
    """Photo recadrée en 9:16 (un peu plus grande pour le zoom lent), assombrie en bas pour les sous-titres."""
    cible = (int(W * 1.15), int(H * 1.15))
    r = max(cible[0] / im.width, cible[1] / im.height)
    im = im.resize((int(im.width * r) + 1, int(im.height * r) + 1), Image.LANCZOS)
    g, h = (im.width - cible[0]) // 2, (im.height - cible[1]) // 3
    im = im.crop((g, h, g + cible[0], h + cible[1]))
    a = np.asarray(im).astype(np.float32)
    y = np.linspace(0, 1, a.shape[0])[:, None, None]
    voile = 0.25 + 0.55 * np.clip((y - 0.45) / 0.4, 0, 1) + 0.25 * np.clip((0.15 - y) / 0.15, 0, 1)
    return Image.fromarray(np.clip(a * (1 - voile), 0, 255).astype(np.uint8))


def couper_lignes(d, mots, f, largeur_max=W - 140):
    lignes, cur = [], []
    for m in mots:
        if cur and d.textlength(" ".join(cur + [m]), font=f) > largeur_max:
            lignes.append(cur)
            cur = []
        cur.append(m)
    if cur:
        lignes.append(cur)
    return lignes


def monter(fiche, texte, voix, segs, nom_voix, images, cales=None):
    os.makedirs(SORTIE, exist_ok=True)
    scenes = texte["scenes"]
    FIN = segs[-1][1]
    TOTAL = FIN + 3.0
    P_SUB, P_SUJET, P_BIG = police(72), police(88), police(250)
    P_BADGE, P_SM, P_XS = police(34, "ExtraBold", "polices/figtree.ttf"), police(42, "Bold", "polices/figtree.ttf"), police(28, "SemiBold", "polices/figtree.ttf")
    fond = degrade(FONDS.get(fiche.get("family"), (30, 30, 60)), (8, 8, 14))
    photos = [preparer_photo(i[0]) if i else None for i in images]
    credits = [i[1] if i else "Illustration NovaSTEM" for i in images]

    # Mots des sous-titres et leur moment (proportionnel à la longueur prononcée)
    mots = []
    for k, (s, (t0, t1)) in enumerate(zip(scenes, segs)):
        ws = [w for w in s["ecran"].replace(" %", " %").replace(" :", " :").split(" ") if w]
        poids = [len(w) + 2 for w in ws]
        tot, t = sum(poids), t0 + 0.05
        groupes, g, n = [], [], 0
        for w in ws:
            if g and n + len(w) > 48:
                groupes.append(g); g, n = [], 0
            g.append(w); n += len(w) + 1
            if w.endswith((".", "?", "!")) and n > 10:
                groupes.append(g); g, n = [], 0
        if g:
            groupes.append(g)
        gi = k_in = 0
        for j, (w, p) in enumerate(zip(ws, poids)):
            d = (t1 - t0 - 0.1) * p / tot
            if cales and k < len(cales) and len(cales[k]) == len(ws):
                deb, fin_mot = cales[k][j]
            else:
                deb, fin_mot = t, t + d
            mots.append((deb, fin_mot, w, (k, gi)))
            t += d; k_in += 1
            if k_in == len(groupes[gi]):
                gi += 1; k_in = 0

    def logo(d, x, y, s=1.0):
        f, f2 = police(int(44 * s)), police(int(26 * s), "ExtraBold", "polices/figtree.ttf")
        d.rounded_rectangle((x, y + int(6 * s), x + int(58 * s), y + int(52 * s)), radius=int(6 * s), outline=BLANC, width=max(2, int(4 * s)))
        d.text((x + int(9 * s), y + int(13 * s)), "No", font=f2, fill=BLANC)
        d.text((x + int(66 * s), y), "vaSTEM", font=f, fill=BLANC)

    def badge(d, txt, x, y, c=BLEU):
        w = d.textlength(txt, font=P_BADGE)
        d.rounded_rectangle((x, y, x + w + 36, y + 62), radius=14, fill=c)
        d.text((x + 18, y + 11), txt, font=P_BADGE, fill=BLANC)

    def centre(d, txt, y, f, c=BLANC, contour=6):
        for ligne in couper_lignes(d, txt.split(" "), f):
            l = " ".join(ligne)
            d.text(((W - d.textlength(l, font=f)) / 2, y), l, font=f, fill=c, stroke_width=contour, stroke_fill=NOIR)
            y += int(f.size * 1.12)
        return y

    def sous_titres(d, t):
        cur = [m for m in mots if m[0] - 0.04 <= t]
        cur = cur[-1:] if cur and t < cur[-1][1] + 0.6 else []
        if not cur or t > FIN + 0.2:
            return
        m = cur[-1]
        grp = [x for x in mots if x[3] == m[3]]
        actif = grp.index(m)
        lignes = couper_lignes(d, [x[2].upper() for x in grp], P_SUB)
        y, idx = 1290 - (len(lignes) - 2) * 44, 0
        for ligne in lignes:
            larg = d.textlength(" ".join(ligne), font=P_SUB)
            x = (W - larg) / 2
            for w in ligne:
                d.text((x, y), w, font=P_SUB, fill=JAUNE if idx == actif else BLANC, stroke_width=7, stroke_fill=NOIR)
                x += d.textlength(w + " ", font=P_SUB); idx += 1
            y += 86

    debuts = [s[0] for s in segs] + [FIN + 0.2, TOTAL]
    sortie_mp4 = os.path.join(SORTIE, "video_semaine.mp4")
    ff = subprocess.Popen(["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}",
                           "-r", str(FPS), "-i", "-", "-i", os.path.join(SORTIE, "audio.wav"), "-c:v", "libx264",
                           "-preset", "veryfast", "-crf", "20", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "160k",
                           "-shortest", "-movflags", "+faststart", sortie_mp4], stdin=subprocess.PIPE)
    for f in range(int(TOTAL * FPS)):
        t = f / FPS
        i = max(k for k in range(len(debuts) - 1) if debuts[k] <= t)
        tl, dur = t - debuts[i], debuts[i + 1] - debuts[i]
        if i < len(scenes):
            s = scenes[i]
            if photos[i] is not None:
                z = 1 + 0.08 * tl / max(dur, 0.1)
                p = photos[i]
                pw, ph = int(W * 1.15 / z), int(H * 1.15 / z)
                dx = int((p.width - pw) * (0.5 + 0.2 * math.sin(i)))
                img = p.crop((dx, (p.height - ph) // 2, dx + pw, (p.height - ph) // 2 + ph)).resize((W, H), Image.BILINEAR)
            else:
                img = fond.copy()
            d = ImageDraw.Draw(img)
            if i == 0:
                a = ease(tl / 0.4)
                badge(d, "LA DÉCOUVERTE DE LA SEMAINE", 60, int(150 - 30 * (1 - a)))
                centre(d, texte["sujet"].upper(), 250, P_SUJET)
            else:
                logo(d, 60, 70)
            if s.get("chiffre"):
                a = ease((tl - 0.2) / 0.5)
                base = 230 if len(s['chiffre']) <= 6 else 130
                f_big = police(int(base + 30 * (1 - a)))
                y = centre(d, s["chiffre"], 330 if i else 520, f_big, JAUNE, 8)
                if s.get("legende"):
                    centre(d, s["legende"], y + 10, P_SM)
            elif photos[i] is None and i > 0:
                # écran graphique : le mot-clé de la scène en grand
                centre(d, (s.get("legende") or texte["sujet"]).upper(), 520, police(96))
            sous_titres(d, t)
            d.text((60, H - 90), credits[i][:70], font=P_XS, fill=(230, 230, 240))
        else:  # écran de fin
            img = degrade((26, 26, 46), (10, 10, 16))
            d = ImageDraw.Draw(img)
            a = ease(tl / 0.6)
            logo(d, int(W / 2 - 330), int(560 - 40 * (1 - a)), 3.0)
            for k, l in enumerate(["Chaque semaine, la plus grande", "avancée scientifique en 40 s"]):
                d.text(((W - d.textlength(l, font=P_SM)) / 2, 820 + k * 58), l, font=P_SM, fill=(220, 220, 235))
            b = "Disponible sur Google Play"
            w = d.textlength(b, font=P_BADGE) + 50
            x0 = (W - w) / 2
            d.rounded_rectangle((x0 - 30, 1010, x0 + w + 30, 1090), radius=20, fill=BLANC)
            d.polygon([(x0, 1032), (x0, 1068), (x0 + 30, 1050)], fill=NOIR)
            d.text((x0 + 50, 1028), b, font=P_BADGE, fill=NOIR)
            d.text((60, H - 90), f"Source : {fiche.get('source_name') or ''}"[:70], font=P_XS, fill=(230, 230, 240))
        if 0 < i < len(debuts) - 1 and tl < 0.12:
            img = Image.blend(img, Image.new("RGB", (W, H), BLANC), 0.22 * (1 - tl / 0.12))
            d = ImageDraw.Draw(img)
        d.rounded_rectangle((40, 30, W - 40, 40), radius=5, fill=(90, 90, 100))
        d.rounded_rectangle((40, 30, 40 + (W - 80) * t / TOTAL, 40), radius=5, fill=BLANC)
        ff.stdin.write(img.tobytes())
    ff.stdin.close()
    ff.wait()
    return sortie_mp4, TOTAL


def fabriquer_audio(voix, segs, total, chiffre_scene, vraie_musique=None):
    os.makedirs(SORTIE, exist_ok=True)
    SR = 44100
    n = int(total * SR)
    t = np.arange(n) / SR
    notes = {"A": 220.0, "F": 174.61, "C": 261.63, "G": 196.0}
    acc = ["A", "F", "C", "G"]
    pad = np.zeros(n)
    for k in range(int(total / 2.4) + 1):
        a, b = int(k * 2.4 * SR), min(n, int((k + 1) * 2.4 * SR) + SR // 2)
        tt = np.arange(b - a) / SR
        env = np.minimum(1, tt / 0.6) * np.exp(-np.maximum(0, tt - 2.4) * 6)
        for m in (1, 1.25, 1.5):
            f = notes[acc[k % 4]] * m / 2
            pad[a:b] += env * (np.sin(2 * np.pi * f * tt) + 0.3 * np.sin(2 * np.pi * 2 * f * tt + 1)) / 3
    for k in range(int(total / 0.6)):
        a = int(k * 0.6 * SR); tt = np.arange(int(0.25 * SR)) / SR; b = min(n, a + len(tt))
        pad[a:b] += (0.5 * np.sin(2 * np.pi * (60 * np.exp(-tt * 12) + 42) * tt) * np.exp(-tt * 14))[:b - a]
    pad = np.convolve(pad, np.ones(30) / 30, mode="same")
    rng = np.random.default_rng(1)
    for (t0, _) in segs[1:] + [(segs[-1][1] + 0.2, 0)]:
        a = int(max(0, t0 - 0.25) * SR); L = min(int(0.5 * SR), n - a)
        if L > 0:
            pad[a:a + L] += 0.9 * np.convolve(rng.normal(0, 1, L), np.ones(40) / 40, mode="same") * np.sin(np.linspace(0, np.pi, L)) ** 2
    if chiffre_scene is not None:
        a = int((segs[chiffre_scene][0] + 0.3) * SR); tt = np.arange(min(int(1.2 * SR), n - a)) / SR
        pad[a:a + len(tt)] += 1.4 * np.sin(2 * np.pi * 48 * tt) * np.exp(-tt * 4)
    pad /= np.max(np.abs(pad)) or 1
    if vraie_musique is not None:
        # vraie musique : début pris à 5 s (souvent plus vivant), bruitages gardés très bas
        m = vraie_musique[int(5 * SR):][:n] if len(vraie_musique) > n + 5 * SR else vraie_musique[:n]
        m = np.pad(m, (0, max(0, n - len(m))))
        m = m / (np.max(np.abs(m)) or 1)
        effets = pad - np.convolve(pad, np.ones(400) / 400, mode="same")
        pad = m + 0.35 * effets
        pad /= np.max(np.abs(pad)) or 1
    musique = pad * 10 ** (-19 / 20)
    fin = int(segs[-1][1] * SR)
    musique[fin:] *= np.linspace(1, 2.5, n - fin)
    musique *= np.minimum(1, np.minimum(t / 0.3, (total - t) / 1.0))
    v = np.zeros(n)
    v[:min(n, len(voix))] = voix[:n] / (np.max(np.abs(voix)) or 1) * 0.9
    mix = np.clip(v + musique, -1, 1)
    sf.write(os.path.join(SORTIE, "audio.wav"), np.stack([mix, mix], 1), SR)


# ------------------------------------------------------------------ programme
def main():
    os.makedirs(SORTIE, exist_ok=True)
    fiches = choisir_avancees()
    log("Candidates :", *[f"\n  ★{f.get('importance')} {f['title']}" for f in fiches])
    fiche, texte = ecrire_texte(fiches)
    log(f"\nAvancée choisie : {fiche['title']}\nSujet : {texte['sujet']}")
    for k, s in enumerate(texte["scenes"], 1):
        log(f"  {k}. {s['voix']}")
    voix, segs, nom_voix = fabriquer_voix([s["voix"] for s in texte["scenes"]])
    cales = caler_mots(voix, segs, texte["scenes"])
    images = chercher_images(fiche, texte["scenes"])
    musique, credit_musique = choisir_musique(fiche.get("family"))
    total = segs[-1][1] + 3.0
    chiffre = next((k for k, s in enumerate(texte["scenes"]) if s.get("chiffre")), None)
    fabriquer_audio(voix, segs, total, chiffre, musique)
    chemin, total = monter(fiche, texte, voix, segs, nom_voix, images, cales)
    desc = (texte["description"].strip() + f"\n\nSource : {fiche.get('source_name') or ''} — {fiche.get('source_url') or ''}"
            + (f"\n{credit_musique}" if credit_musique else "") +
            "\nToutes les avancées de la semaine dans l'app NovaSTEM (Google Play)."
            "\nTexte et voix générés avec l'aide de l'IA.")
    open(os.path.join(SORTIE, "description.txt"), "w", encoding="utf-8").write(desc)
    json.dump({"fiche": {k: fiche.get(k) for k in ("id", "title", "source_url")}, "texte": texte, "voix": nom_voix,
               "credits": [i[1] if i else None for i in images]},
              open(os.path.join(SORTIE, "script.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    car = COUTS["caracteres_voix"]
    prix_voix = car * 30 / 1e6 if nom_voix == "Google" else (car * 0.0002 if nom_voix == "ElevenLabs" else 0)
    cout_txt = (f"Coût de cette vidéo : texte (Haiku) {COUTS['haiku']:.4f} $ + voix {nom_voix} "
                + (f"{car} caractères ({prix_voix:.4f} $ au tarif, mais gratuit sous 1 million de caractères par mois)"
                   if nom_voix == "Google" else ("gratuite" if nom_voix == "voix libre" else f"{car} caractères ≈ {prix_voix:.4f} $"))
                + f" = {COUTS['haiku']:.4f} $ payés réellement. Calcul GitHub : gratuit (repo public).")
    print(f"::notice title=Coût::{cout_txt}", flush=True)
    print(f"::notice title=Vidéo::{fiche['title']} — {total:.0f} s, voix {nom_voix}, musique {'libre' if credit_musique else 'de secours'}, sous-titres {'calés' if cales else 'approximatifs'}", flush=True)
    log(f"\n✅ Vidéo prête : {chemin} ({total:.0f} s, voix : {nom_voix}).")
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as r:
            r.write(f"## 🎬 Vidéo de la semaine\n\n**{fiche['title']}**\n\nVoix : {nom_voix} · durée {total:.0f} s\n\n💶 {cout_txt}\n\n"
                    "Télécharge la vidéo et la description en bas de cette page (« Artifacts » → **video-de-la-semaine**).\n\n"
                    "### Texte\n" + "\n".join(f"{k}. {s['voix']}" for k, s in enumerate(texte['scenes'], 1)) +
                    "\n\n### Description à coller\n```\n" + desc + "\n```\n")


if __name__ == "__main__":
    main()
