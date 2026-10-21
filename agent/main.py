# =====================================================================
# AGENT DE COLLECTE — Application science
# ---------------------------------------------------------------------
# Lit les flux RSS, demande à Claude de trier / résumer / classer,
# puis enregistre les avancées dans Supabase.
# Lancé à la main depuis l'onglet « Actions » de GitHub.
# =====================================================================

# ------------------------- RÉGLAGES ----------------------------------
# Nombre d'articles ajoutés par exécution si on ne précise rien.
# (Dans GitHub, le champ « Nombre d'articles » du bouton Run workflow
#  remplace cette valeur.)
NOMBRE_ARTICLES_PAR_DEFAUT = 5

# Plafond de sécurité : même si on tape 500 par erreur, on s'arrête là.
PLAFOND_ARTICLES = 30

# Nombre maximum d'appels à Claude = articles demandés x ce facteur.
# Évite de dépenser trop quand beaucoup d'articles sont ignorés.
FACTEUR_APPELS_MAX = 5

# Âge maximum d'un article pour être pris en compte (en jours).
AGE_MAX_JOURS = 30

# Combien de jours de titres déjà publiés on montre à Claude
# pour détecter les doublons.
JOURS_ANTI_DOUBLONS = 21

# Présélection : avant de résumer, Claude lit en un seul appel (très bon marché)
# les titres de tous les candidats récents et les classe du plus prometteur
# (avancée majeure probable) au moins prometteur. L'agent traite ensuite les
# articles dans cet ordre : plus de chances de trouver les avancées importantes.
PRESELECTION = True
PRESELECTION_JOURS = 7       # âge max des articles présélectionnés (jours)
PRESELECTION_MAX = 250       # nombre max de titres envoyés à Claude

# Modèles Claude disponibles et tarifs en dollars par million de tokens
# (entrée, sortie). Tarifs vérifiés en octobre 2026.
MODELES = {
    "haiku":  {"id": "claude-haiku-5-5",  "prix": (0.10, 0.50)},
    "sonnet": {"id": "claude-sonnet-5-5", "prix": (2.00, 10.00)},
}
MODELE_PAR_DEFAUT = "haiku"
# ---------------------------------------------------------------------

import html
import json
import os
import random
import re
import sys
import time
from datetime import datetime, timedelta, timezone
from urllib.parse import urlsplit, urlunsplit, parse_qsl, urlencode

import feedparser
import requests

import notifications
from anthropic import Anthropic

from prompt import SYSTEM_PROMPT, THEMES, TECH_THEMES, build_user_message
from sources import SOURCES, TITRES_EXCLUS

MAINTENANT = datetime.now(timezone.utc)
USER_AGENT = "Mozilla/5.0 (compatible; ApplicationScienceBot/1.0)"


# ============================ OUTILS =================================

def log(msg: str) -> None:
    print(msg, flush=True)


def lire_entier(nom_env: str, defaut: int) -> int:
    try:
        return int(str(os.environ.get(nom_env, "")).strip() or defaut)
    except ValueError:
        return defaut


def normaliser_url(url: str) -> str:
    """Retire les paramètres de suivi (utm_...) et le # final, pour repérer
    deux fois le même lien écrit différemment."""
    try:
        p = urlsplit(url.strip())
        params = [(k, v) for k, v in parse_qsl(p.query)
                  if not k.lower().startswith(("utm_", "fbclid", "gclid", "rss"))]
        chemin = p.path.rstrip("/") or "/"
        return urlunsplit(("https", p.netloc.lower().removeprefix("www."),
                           chemin, urlencode(params), ""))
    except Exception:
        return url.strip()


def nettoyer_texte(brut: str, max_len: int = 1500) -> str:
    texte = re.sub(r"<[^>]+>", " ", brut or "")
    texte = html.unescape(texte)
    texte = re.sub(r"\s+", " ", texte).strip()
    return texte[:max_len]


def date_article(entree) -> datetime:
    """Date du flux si elle existe et est plausible, sinon maintenant.
    (published_at ne doit jamais être vide.)"""
    for champ in ("published_parsed", "updated_parsed"):
        t = entree.get(champ)
        if t:
            try:
                d = datetime(*t[:6], tzinfo=timezone.utc)
                if d <= MAINTENANT + timedelta(hours=12):
                    return d
            except Exception:
                pass
    return MAINTENANT


def mots_cles(titre: str) -> set[str]:
    return {m for m in re.findall(r"[a-zà-ÿ0-9]+", titre.lower()) if len(m) > 3}


def titres_proches(a: str, b: str) -> bool:
    """Comparaison simple et gratuite de deux titres d'origine."""
    ka, kb = mots_cles(a), mots_cles(b)
    if not ka or not kb:
        return False
    return len(ka & kb) / min(len(ka), len(kb)) >= 0.7


# =========================== SUPABASE ================================

class Supabase:
    def __init__(self, url: str, cle: str):
        self.base = url.rstrip("/") + "/rest/v1/advances"
        self.base_vus = url.rstrip("/") + "/rest/v1/seen_urls"
        self.memoire_ok = True
        self.headers = {"apikey": cle, "Content-Type": "application/json"}
        # Anciennes clés (JWT, commencent par eyJ) : il faut aussi ce champ.
        if cle.startswith("eyJ"):
            self.headers["Authorization"] = f"Bearer {cle}"

    def urls_connues(self) -> set[str]:
        depuis = (MAINTENANT - timedelta(days=AGE_MAX_JOURS + 60)).isoformat()
        r = requests.get(self.base, headers=self.headers, timeout=30, params={
            "select": "source_url", "created_at": f"gte.{depuis}", "limit": "10000"})
        r.raise_for_status()
        return {normaliser_url(x["source_url"]) for x in r.json()}

    def urls_deja_ecartees(self) -> set[str]:
        """Liens déjà jugés « pas une avancée » / doublon / refusés : on ne
        repaie pas Claude pour eux. Si la table n'existe pas, on continue."""
        try:
            r = requests.get(self.base_vus, headers=self.headers, timeout=30,
                             params={"select": "url", "limit": "20000"})
            r.raise_for_status()
            return {x["url"] for x in r.json()}
        except Exception as ex:
            self.memoire_ok = False
            log(f"⚠ Mémoire des articles écartés indisponible ({ex.__class__.__name__}) : "
                f"as-tu créé la table seen_urls ?")
            return set()

    def marquer_ecarte(self, url: str, raison: str) -> None:
        if not self.memoire_ok:
            return
        try:
            h = dict(self.headers, Prefer="resolution=ignore-duplicates,return=minimal")
            requests.post(self.base_vus, headers=h, timeout=30,
                          json={"url": normaliser_url(url), "reason": raison})
        except Exception:
            pass

    def sujets_recents(self, feed: str) -> list[str]:
        depuis = (MAINTENANT - timedelta(days=JOURS_ANTI_DOUBLONS)).isoformat()
        r = requests.get(self.base, headers=self.headers, timeout=30, params={
            "select": "title,summary", "created_at": f"gte.{depuis}", "feed": f"eq.{feed}",
            "order": "created_at.desc", "limit": "300"})
        if r.status_code == 400 and "feed" in r.text:
            raise RuntimeError("colonne « feed » absente : lance d'abord "
                               "database/migration_002_tech_photos.sql dans Supabase")
        r.raise_for_status()
        sujets = []
        for x in r.json():
            debut = " ".join((x.get("summary") or "").split()[:14])
            sujets.append(f"{x['title']} — {debut}…")
        return sujets

    def corriger_credits(self) -> int:
        """Corrige les crédits d'image déjà enregistrés avec une parenthèse orpheline."""
        r = requests.get(self.base, headers=self.headers, timeout=30, params={
            "select": "id,image_credit,published_at", "image_credit": "like.*)", "limit": "500"})
        r.raise_for_status()
        n = 0
        for x in r.json():
            propre = nettoyer_credit(x["image_credit"])
            # Ancien bogue PLOS : « (Oct ) » au lieu de l'année → année de publication
            an = (x.get("published_at") or "")[:4]
            propre = re.sub(r"\((?:[A-Za-zéû]{3,9}\.?\s*)\)", f"({an})" if an.isdigit() else "", propre)
            propre = re.sub(r"\s+,", ",", propre)
            if propre != x["image_credit"]:
                requests.patch(self.base, headers=dict(self.headers, Prefer="return=minimal"),
                               params={"id": f"eq.{x['id']}"}, json={"image_credit": propre}, timeout=30)
                n += 1
        return n

    def inserer(self, ligne: dict) -> str:
        """Renvoie 'ok', 'doublon' ou lève une erreur. En cas de succès, ajoute à
        `ligne` son identifiant et sa famille (calculée par la base), utiles
        pour les notifications."""
        h = dict(self.headers, Prefer="return=representation")
        r = requests.post(self.base, headers=h, json=ligne, timeout=30,
                          params={"select": "id,family"})
        if r.status_code == 400 and "column" in r.text and any(c in r.text for c in COLONNES_005):
            # Migration 005 pas encore lancée : on enregistre sans les nouvelles colonnes.
            print("⚠ Colonnes du nouveau résumé absentes (lancer database/migration_005_resume.sql) : "
                  "fiche enregistrée avec son résumé d'un seul tenant.", flush=True)
            r = requests.post(self.base, headers=h, timeout=30, params={"select": "id,family"},
                              json={k: v for k, v in ligne.items() if k not in COLONNES_005})
        if r.status_code == 409:
            return "doublon"
        if r.status_code >= 300:
            raise RuntimeError(f"Supabase {r.status_code} : {r.text[:200]}")
        try:
            cree = r.json()[0]
            ligne["id"], ligne["family"] = cree.get("id"), cree.get("family")
        except Exception:
            pass
        return "ok"


# ============================ FLUX RSS ===============================

def image_libre(entree) -> str:
    """Adresse de l'image d'un article (seulement appelée pour les sources
    dont les images sont libres de droits). Chaîne vide si aucune."""
    candidats = []
    for m in entree.get("media_content", []) or []:
        if (m.get("medium") == "image" or str(m.get("type", "")).startswith("image/")
                or re.search(r"\.(jpe?g|png|webp)(\?|$)", m.get("url", ""), re.I)):
            candidats.append(m.get("url", ""))
    for m in entree.get("media_thumbnail", []) or []:
        candidats.append(m.get("url", ""))
    for l in entree.get("links", []) or []:
        if l.get("rel") == "enclosure" and str(l.get("type", "")).startswith("image/"):
            candidats.append(l.get("href", ""))
    contenu = " ".join(c.get("value", "") for c in entree.get("content", []) or [])
    contenu += " " + (entree.get("summary") or "")
    m = re.search(r'<img[^>]+src="([^"]+)"', contenu)
    if m:
        candidats.append(html.unescape(m.group(1)))
    for url in candidats:
        if url and url.startswith("https://"):
            return url
    return ""


def lire_sources(urls_connues: set[str], feed: str) -> tuple[list[dict], list[str]]:
    """Lit les sources d'un fil et renvoie les articles candidats,
    en alternant entre les sources pour varier chaque exécution."""
    par_source, pannes = [], []

    sources = [s for s in SOURCES if s.get("feed", "science") == feed]
    random.shuffle(sources)  # ordre différent à chaque exécution

    for src in sources:
        # Âge maximum : réglage général, ou « age_max » pour une source qui publie peu
        limite_age = MAINTENANT - timedelta(days=src.get("age_max", AGE_MAX_JOURS))
        try:
            r = requests.get(src["url"], timeout=30,
                             headers={"User-Agent": USER_AGENT})
            r.raise_for_status()
            flux = feedparser.parse(r.content)
            articles = []
            for e in flux.entries:
                lien = (e.get("link") or "").strip()
                titre = nettoyer_texte(e.get("title", ""), 300)
                if not lien or not titre:
                    continue
                if normaliser_url(lien) in urls_connues:
                    continue
                if any(x.lower() in titre.lower() for x in TITRES_EXCLUS):
                    continue
                d = date_article(e)
                if d < limite_age:
                    continue
                texte = nettoyer_texte(e.get("summary") or e.get("description") or "")
                image, credit = "", ""
                if src.get("photo"):
                    image = image_libre(e)
                    credit = src["photo"] if image else ""
                articles.append({"source_name": src["name"], "url": lien,
                                 "title": titre, "text": texte or titre,
                                 "published_at": d, "image_url": image,
                                 "image_credit": credit, "photo": src.get("photo"),
                                 "credit_page": bool(src.get("credit_page")),
                                 "credit_mode": src.get("credit_mode", ""),
                                 "image_motif": src.get("image_motif", ""),
                                 "credit_requis": src.get("credit_requis", "")})
            articles.sort(key=lambda a: a["published_at"], reverse=True)
            log(f"  • {src['name']} : {len(flux.entries)} dans le flux, "
                f"{len(articles)} nouveaux")
            par_source.append(articles)
        except Exception as ex:
            log(f"  ⚠ {src['name']} : source injoignable ({ex.__class__.__name__})")
            pannes.append(src["name"])

    # Alternance : 1er de chaque source, puis 2e de chaque source, etc.
    candidats, vus = [], []
    for i in range(max((len(a) for a in par_source), default=0)):
        for articles in par_source:
            if i < len(articles):
                a = articles[i]
                # Doublon évident entre deux sources dans ce même lot : gratuit à repérer
                if any(titres_proches(a["title"], t) for t in vus):
                    continue
                vus.append(a["title"])
                candidats.append(a)
    return candidats, pannes


# Crédits d'agences photo : ces images ne sont jamais libres, même sur un site libre.
AGENCES = re.compile(r"Getty|Shutterstock|iStock|AP Photo|Associated Press|Reuters|AFP|Alamy",
                     re.I)


def nettoyer_credit(c: str) -> str:
    """Retire les parenthèses orphelines lues sur la page (ex. « ESO/GRAVITY collaboration) »)."""
    c = re.sub(r"\s+", " ", c or "").strip(" ,;")
    while c.endswith(")") and c.count(")") > c.count("("):
        c = c[:-1].rstrip(" ,;")
    while c.startswith("(") and c.count("(") > c.count(")"):
        c = c[1:].lstrip()
    return c


def completer_image(art: dict) -> None:
    """Pour un article retenu d'une source aux images libres : ouvre la page
    de l'article pour trouver l'image principale (si le flux n'en donne pas),
    lire le crédit exact (ESO), et renoncer à l'image si elle vient d'une agence."""
    if not art.get("photo"):
        return
    try:
        r = requests.get(art["url"], timeout=20, headers={"User-Agent": USER_AGENT})
        page = r.text[:600000] if r.ok else ""
    except Exception:
        page = ""
    if not art.get("image_url") and page:
        m = (re.search(r'<meta[^>]+property=["\']og:image["\'][^>]+content=["\']([^"\']+)', page)
             or re.search(r'<meta[^>]+content=["\']([^"\']+)["\'][^>]+property=["\']og:image', page))
        if m and html.unescape(m.group(1)).startswith("https://"):
            art["image_url"] = html.unescape(m.group(1))
    if not art.get("image_url"):
        art["image_credit"] = ""
        return
    credit = art["photo"]
    if art.get("credit_mode") in ("plos", "citation"):
        # Figures dessinées avec BioRender : licence contestée → pas d'image.
        if not page or re.search(r"biorender", page, re.I):
            log("    (image ignorée : page illisible ou figure BioRender)")
            art["image_url"], art["image_credit"] = "", ""
            return
        def meta(nom):
            m = re.search(r'<meta[^>]+name=["\']' + nom + r'["\'][^>]+content=["\']([^"\']+)', page)
            return html.unescape(m.group(1)).strip() if m else ""
        auteur = meta("citation_author")
        nom_famille = auteur.split(",")[0].split()[-1] if auteur else ""
        revue = meta("citation_journal_title") or art["source_name"]
        # La date peut être « 2026/10/16 » ou « Oct 16, 2026 » : on cherche l'année (4 chiffres).
        m_an = re.search(r"\b(19|20)\d{2}\b", meta("citation_date") or meta("citation_publication_date"))
        annee = m_an.group(0) if m_an else ""
        credit = (f"Image : {nom_famille + ' et al., ' if nom_famille else ''}{revue}"
                  f"{' (' + annee + ')' if annee else ''}, CC BY 4.0")
    elif art.get("credit_page") and page:
        m = re.search(r"Credit:\s*(?:<[^>]+>\s*)*([^<]{2,150})", page)
        if m:
            credit = "Image : " + nettoyer_credit(html.unescape(m.group(1)))
        else:
            credit = "Image : " + credit
    # L'image doit avoir la forme attendue (ex. une figure de l'article, pas un logo)
    if art.get("image_motif") and not re.search(art["image_motif"], art.get("image_url", "")):
        log("    (image ignorée : ce n'est pas une figure de l'article)")
        art["image_url"], art["image_credit"] = "", ""
        return
    # Le crédit doit nommer l'institution dont la licence est vérifiée (ex. NRAO) ;
    # sinon l'image peut appartenir à quelqu'un d'autre.
    if art.get("credit_requis") and art["credit_requis"].lower() not in credit.lower():
        log(f"    (image ignorée : crédit sans « {art['credit_requis']} »)")
        art["image_url"], art["image_credit"] = "", ""
        return
    # Contrôle agence photo autour de l'image dans la page, et dans le crédit
    fichier = art["image_url"].split("/")[-1].split("?")[0]
    i = page.find(fichier) if fichier else -1
    voisinage = page[max(0, i - 400): i + 800] if i >= 0 else ""
    if AGENCES.search(credit) or AGENCES.search(voisinage):
        log(f"    (image ignorée : crédit d'agence photo)")
        art["image_url"], art["image_credit"] = "", ""
        return
    art["image_credit"] = credit


# ============================= CLAUDE ================================

def extraire_json(texte: str) -> dict | None:
    if not texte:
        return None
    texte = texte.strip().removeprefix("```json").removeprefix("```").removesuffix("```")
    debut, fin = texte.find("{"), texte.rfind("}")
    if debut == -1 or fin <= debut:
        return None
    try:
        return json.loads(texte[debut:fin + 1])
    except json.JSONDecodeError:
        return None


TYPES_ETUDE = {
    "science": ["essai_clinique", "humain", "animal", "cellules", "simulation",
                "observation", "terrain", "donnees"],
    "tech": ["en_vente", "annonce", "demonstration", "prototype", "mise_a_jour"],
}


def _fiche(themes: list[str]) -> dict:
    return {
        "type": "object",
        "properties": {
            "title": {"type": "string"},
            "avant": {"type": "string"},
            "decouverte": {"type": "string"},
            "apres": {"type": "string"},
            "mots": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {"mot": {"type": "string"}, "definition": {"type": "string"}},
                    "required": ["mot", "definition"],
                    "additionalProperties": False,
                },
            },
            "type_etude": {"type": "string", "enum": TYPES_ETUDE["science"] + TYPES_ETUDE["tech"]},
            "theme": {"type": "string", "enum": themes},
            "importance": {"type": "integer", "enum": [1, 2, 3, 4, 5]},
        },
        "required": ["title", "avant", "decouverte", "apres", "mots", "type_etude", "theme", "importance"],
        "additionalProperties": False,
    }


# Format de réponse imposé à Claude : l'API garantit un JSON valide.
SCHEMA_REPONSE = {
    "type": "object",
    "properties": {
        "decision": {"type": "string", "enum": ["science", "tech", "both", "none",
                                                "undetermined", "duplicate"]},
        "duplicate_of": {"type": "string"},
        "explanation": {"type": "string"},
        "science": _fiche(THEMES),
        "tech": _fiche(TECH_THEMES),
    },
    "required": ["decision", "duplicate_of", "explanation", "science", "tech"],
    "additionalProperties": False,
}

# Le long document de classification est mis en cache par l'API :
# payé en entier au 1er appel, puis environ 10 fois moins cher ensuite.
SYSTEME = [{"type": "text", "text": SYSTEM_PROMPT, "cache_control": {"type": "ephemeral"}}]


SCHEMA_PRESELECTION = {
    "type": "object",
    "properties": {"ordre": {"type": "array", "items": {"type": "integer"}}},
    "required": ["ordre"],
    "additionalProperties": False,
}

CONSIGNE_PRESELECTION = """Tu tries des titres d'articles pour une application qui présente les avancées scientifiques et technologiques les plus importantes du moment.

On te donne une liste numérotée (titre, source, début du texte). Renvoie dans "ordre" les numéros des articles qui ont une chance réelle d'être une VRAIE avancée, du plus important au moins important, en mettant en tête ceux qui pourraient valoir 4 ou 5 sur 5 :
- première mondiale, découverte majeure, résultat qui change la compréhension d'un domaine ;
- traitement ou vaccin validé chez l'humain, essai clinique de phase avancée réussi ;
- produit technologique majeur réellement annoncé ou sorti (nouvelle génération de puce, de téléphone, de modèle d'IA, de lanceur, de véhicule…) avec des nouveautés mesurables ;
- record mesurable, mission spatiale réussie, percée en énergie ou en informatique quantique.
Mets plus bas les études incrémentales, très spécialisées ou seulement chez l'animal/en simulation.
DOUBLONS : n'inclus PAS un article dont le sujet est déjà dans la liste « Déjà publié » (même découverte ou même produit, même formulé autrement), et si plusieurs articles de la liste parlent du même sujet, garde seulement le plus complet (de préférence la source d'origine : l'université, le laboratoire, l'agence ou l'entreprise qui annonce son propre résultat). N'inclus PAS : actualités sans avancée (politique, finances, procès, nominations, rumeurs, promos, tests de produits, tutoriels, opinions, rubriques récurrentes). Sois exigeant face aux titres racoleurs. Garde au maximum {k} numéros."""


STATS: dict = {}   # chiffres du passage, pour les annotations


def preselectionner(client, modele_id, candidats: list[dict], k: int,
                    deja: list[str] | None = None) -> tuple[list[dict], dict]:
    """Classe les candidats récents par importance probable (un seul appel bon marché).
    En cas de souci, renvoie la liste d'origine : la présélection n'est jamais bloquante."""
    conso = {"in": 0, "out": 0, "cache_w": 0, "cache_r": 0}
    limite = MAINTENANT - timedelta(days=PRESELECTION_JOURS)
    # (les sources aux photos libres, qui publient peu, gardent leur propre limite d'âge)
    pool = [a for a in candidats
            if a["published_at"] >= limite or a.get("photo")][:PRESELECTION_MAX]
    if len(pool) <= 3:
        return candidats, conso
    lignes = []
    for i, a in enumerate(pool):
        debut = " ".join(a["text"].split()[:30])
        lignes.append(f"{i}. {a['title'][:160]} [{a['source_name']}] — {debut}")
    try:
        rep = client.messages.create(
            model=modele_id,
            max_tokens=1500,
            system=CONSIGNE_PRESELECTION.replace("{k}", str(k)),
            messages=[{"role": "user", "content":
                       "Déjà publié ces derniers jours (titres) :\n"
                       + ("\n".join(f"- {t.split(' — ')[0]}" for t in (deja or [])[:150]) or "(rien)")
                       + "\n\nArticles à trier :\n" + "\n".join(lignes)}],
            output_config={"format": {"type": "json_schema", "schema": SCHEMA_PRESELECTION}},
        )
        u = rep.usage
        conso["in"], conso["out"] = u.input_tokens or 0, u.output_tokens or 0
        texte = "".join(b.text for b in rep.content if getattr(b, "type", "") == "text")
        ordre = (extraire_json(texte) or {}).get("ordre", [])
    except Exception as ex:
        log(f"⚠ Présélection impossible ({ex.__class__.__name__}) : ordre habituel.")
        return candidats, conso
    choisis, vus = [], set()
    for i in ordre:
        if isinstance(i, int) and 0 <= i < len(pool) and i not in vus:
            vus.add(i)
            choisis.append(pool[i])
    if not choisis:
        return candidats, conso
    STATS["pool"], STATS["choisis"] = len(pool), len(choisis)
    STATS["top"] = [f"{a['title'][:70]} [{a['source_name']}]" for a in choisis[:15]]
    log(f"Présélection : {len(pool)} titres récents lus, {len(choisis)} retenus, "
        f"traités du plus prometteur au moins prometteur :")
    for a in choisis[:k]:
        log(f"  ↑ {a['title'][:90]} [{a['source_name']}]")
    log("")
    return choisis, conso


def demander_a_claude(client, modele_id, article, sujets) -> tuple[dict | None, dict, str]:
    rep = client.messages.create(
        model=modele_id,
        max_tokens=3000,
        system=SYSTEME,
        messages=[{"role": "user", "content": build_user_message(
            article, sujets["science"], sujets["tech"])}],
        output_config={"format": {"type": "json_schema", "schema": SCHEMA_REPONSE}},
    )
    u = rep.usage
    conso = {"in": u.input_tokens or 0, "out": u.output_tokens or 0,
             "cache_w": getattr(u, "cache_creation_input_tokens", 0) or 0,
             "cache_r": getattr(u, "cache_read_input_tokens", 0) or 0}
    texte = "".join(b.text for b in rep.content if getattr(b, "type", "") == "text")
    if rep.stop_reason == "refusal":
        # Claude a refusé de traiter le sujet : on l'écarte, ce n'est pas une panne.
        return {"decision": "refused", "explanation": "refus de Claude"}, conso, "refus"
    diag = f"arrêt={rep.stop_reason}, début=« {texte[:80]} »"
    return extraire_json(texte), conso, diag


# ========================== TRAITEMENT ===============================

FIL_NOM = {"science": "Sciences", "tech": "Technologies"}
THEMES_PAR_FIL = {"science": (THEMES, "other"), "tech": (TECH_THEMES, "tech_other")}


def preparer_ligne(feed: str, fiche: dict, art: dict) -> dict:
    """Vérifie et nettoie une fiche renvoyée par Claude pour un fil."""
    titre = str(fiche.get("title", "")).strip().rstrip(".")
    avant = " ".join(str(fiche.get("avant", "")).split())
    decouverte = " ".join(str(fiche.get("decouverte", "")).split())
    apres = " ".join(str(fiche.get("apres", "")).split())
    # Résumé d'un seul tenant, gardé pour les anciennes versions de l'app et la page de partage.
    resume = " ".join(x for x in (avant, decouverte, apres) if x) or str(fiche.get("summary", "")).strip()
    if not titre or not resume:
        raise ValueError(f"fiche {FIL_NOM[feed]} sans titre ou sans résumé")
    mots = []
    for m in fiche.get("mots") or []:
        if isinstance(m, dict):
            mot, definition = str(m.get("mot", "")).strip(), str(m.get("definition", "")).strip()
            if mot and definition and len(mots) < 2:
                mots.append({"mot": mot[:60], "definition": definition[:300]})
    type_etude = str(fiche.get("type_etude", "")).strip()
    if type_etude not in TYPES_ETUDE[feed]:
        type_etude = None
    themes, defaut = THEMES_PAR_FIL[feed]
    theme = str(fiche.get("theme", "")).strip().lower()
    if theme not in themes:
        theme = defaut
    try:
        importance = int(round(float(fiche.get("importance", 1))))
    except (TypeError, ValueError):
        importance = 1
    return {
        "feed": feed, "title": titre, "summary": resume, "theme": theme,
        "importance": max(1, min(5, importance)), "source_url": art["url"],
        "source_name": art["source_name"],
        "published_at": art["published_at"].isoformat(),
        "image_url": art.get("image_url") or None,
        "image_credit": art.get("image_credit") or None,
        # Nouveau résumé (maquette 33) : colonnes de la migration 005.
        "avant": avant or None, "decouverte": decouverte or None, "apres": apres or None,
        "mots": mots, "type_etude": type_etude,
    }


COLONNES_005 = ("avant", "decouverte", "apres", "mots", "type_etude")


def melanger(listes: list[list[dict]]) -> list[dict]:
    """Alterne entre plusieurs listes de candidats (1er de chaque, 2e de chaque…)."""
    out = []
    for i in range(max((len(l) for l in listes), default=0)):
        for l in listes:
            if i < len(l):
                out.append(l[i])
    return out


# ============================== MAIN =================================

CHOIX_SOURCES = {
    "sciences": ["science"], "science": ["science"],
    "technologies": ["tech"], "tech": ["tech"],
    "les deux": ["science", "tech"], "les-deux": ["science", "tech"], "both": ["science", "tech"],
}


def main() -> int:
    # --- Réglages de l'exécution ---
    nb_voulu = lire_entier("NOMBRE_ARTICLES", NOMBRE_ARTICLES_PAR_DEFAUT)
    nb_voulu = max(1, min(nb_voulu, PLAFOND_ARTICLES))
    appels_max = nb_voulu * FACTEUR_APPELS_MAX
    groupes = CHOIX_SOURCES.get((os.environ.get("FIL") or "les deux").strip().lower(),
                                ["science", "tech"])
    cle_modele = (os.environ.get("MODELE") or MODELE_PAR_DEFAUT).strip().lower()
    if cle_modele not in MODELES:
        cle_modele = MODELE_PAR_DEFAUT
    modele = MODELES[cle_modele]

    for var in ("ANTHROPIC_API_KEY", "SUPABASE_URL", "SUPABASE_SECRET_KEY"):
        if not os.environ.get(var):
            log(f"❌ Secret manquant : {var} (à ajouter dans Settings → Secrets → Actions)")
            return 1

    log(f"▶ Objectif : {nb_voulu} article(s) — sources : "
        f"{' + '.join(FIL_NOM[g] for g in groupes)} — modèle : {cle_modele} ({modele['id']})")
    log(f"  Au plus {appels_max} appels à Claude.\n")

    db = Supabase(os.environ["SUPABASE_URL"], os.environ["SUPABASE_SECRET_KEY"])
    client = Anthropic()  # lit ANTHROPIC_API_KEY

    try:
        urls = db.urls_connues()
        nb_base = len(urls)
        urls |= db.urls_deja_ecartees()
        nb_ecartes = len(urls) - nb_base
        sujets = {"science": db.sujets_recents("science"), "tech": db.sujets_recents("tech")}
    except Exception as ex:
        log(f"❌ Impossible de lire Supabase : {ex}")
        return 1
    try:
        n = db.corriger_credits()
        if n:
            log(f"Crédits d'image corrigés : {n}")
    except Exception:
        pass
    log(f"Base : {nb_base} articles publiés, {nb_ecartes} liens déjà écartés, "
        f"{len(sujets['science'])} + {len(sujets['tech'])} sujets récents.\n")

    listes, pannes = [], []
    for g in groupes:
        log(f"Lecture des sources {FIL_NOM[g]} :")
        cands, p = lire_sources(urls, g)
        listes.append(cands)
        pannes += p
    candidats = melanger(listes)
    log(f"\n{len(candidats)} article(s) candidat(s).\n")
    STATS["candidats"] = len(candidats)

    ajoutes = []                       # fiches enregistrées (1 ou 2 par article)
    nb_articles = 0                    # articles retenus (un « les deux » compte pour 1)
    ignores, doublons, erreurs = [], [], []
    conso = {"in": 0, "out": 0, "cache_w": 0, "cache_r": 0}
    appels = 0
    if PRESELECTION:
        candidats, c = preselectionner(client, modele["id"], candidats, max(3 * nb_voulu, 15),
                                       sujets["science"] + sujets["tech"])
        for k in conso:
            conso[k] += c[k]
    decisions = {"science": 0, "tech": 0, "both": 0}

    for art in candidats:
        if nb_articles >= nb_voulu or appels >= appels_max:
            break
        appels += 1
        try:
            rep, c, diag = demander_a_claude(client, modele["id"], art, sujets)
            for k in conso:
                conso[k] += c[k]
            if rep is None:
                raise ValueError(f"réponse illisible ({diag})")
            decision = rep.get("decision")
            explication = str(rep.get("explanation", "")).strip()

            if decision == "duplicate":
                db.marquer_ecarte(art["url"], "duplicate")
                doublons.append((art, rep.get("duplicate_of", "")))
                log(f"  ↺ doublon   : {art['title'][:80]}")
                continue
            if decision not in ("science", "tech", "both"):
                db.marquer_ecarte(art["url"], str(decision or "skip"))
                ignores.append((art, decision, explication))
                log(f"  – ignoré ({decision}) : {art['title'][:70]}")
                continue

            completer_image(art)
            fils = ["science", "tech"] if decision == "both" else [decision]
            lignes = [preparer_ligne(f, rep.get(f) or {}, art) for f in fils]
            enregistrees = []
            for ligne in lignes:
                if db.inserer(ligne) == "doublon":
                    doublons.append((art, f"même lien déjà dans {FIL_NOM[ligne['feed']]}"))
                    continue
                enregistrees.append(ligne)
                sujets[ligne["feed"]].insert(
                    0, f"{ligne['title']} — {' '.join(ligne['summary'].split()[:14])}…")
            if enregistrees:
                nb_articles += 1
                decisions[decision] += 1
                for ligne in enregistrees:
                    ligne["explication"] = explication
                    ajoutes.append(ligne)
                    log(f"  ✔ {FIL_NOM[ligne['feed']]:<12} [{ligne['importance']}★ {ligne['theme']}"
                        f"{' 📷' if ligne['image_url'] else ''}] : {ligne['title']}")
        except Exception as ex:
            msg = (str(ex) or ex.__class__.__name__)[:200]
            erreurs.append((art, msg))
            log(f"  ✖ erreur    : {art['title'][:70]} → {msg}")
            time.sleep(1)

    # --- Coût (cache : écriture = 1,25 × le prix d'entrée, lecture = 0,1 ×) ---
    p_in, p_out = modele["prix"]
    cout = (conso["in"] * p_in + conso["cache_w"] * p_in * 1.25
            + conso["cache_r"] * p_in * 0.1 + conso["out"] * p_out) / 1e6

    log("\n" + "=" * 60)
    log(f"RÉSUMÉ : {nb_articles} article(s) retenu(s) → {len(ajoutes)} fiche(s) "
        f"(sciences {decisions['science']}, tech {decisions['tech']}, les deux {decisions['both']}) ; "
        f"{len(ignores)} ignoré(s), {len(doublons)} doublon(s), {len(erreurs)} erreur(s)")
    log(f"Appels à Claude : {appels} — tokens : {conso['in']} entrée, {conso['cache_w']} mis en cache, "
        f"{conso['cache_r']} lus en cache, {conso['out']} sortie")
    log(f"Coût estimé : {cout:.4f} $")
    if pannes:
        log(f"Sources injoignables : {', '.join(pannes)}")
    log("=" * 60)

    # --- Notifications sur les téléphones (si Firebase est configuré) ---
    notif_ok, notif_ko = notifications.envoyer(ajoutes, log)

    # --- Résumé en annotations GitHub (lisibles par Claude sans ouvrir les journaux) ---
    if os.environ.get("GITHUB_ACTIONS"):
        notes = [a["importance"] for a in ajoutes]
        print(f"::notice title=Résultat::{nb_articles} article(s) retenu(s), {len(ajoutes)} fiche(s), "
              f"{len(ignores)} ignoré(s), {len(doublons)} doublon(s), {len(erreurs)} erreur(s), "
              f"coût {cout:.4f} $, notifications {notif_ok} envoyée(s)", flush=True)
        print(f"::notice title=Notes::{', '.join('★' * n for n in sorted(notes, reverse=True)) or 'aucune'} ; "
              f"avec image : {sum(1 for a in ajoutes if a.get('image_url'))}", flush=True)
        for a in ajoutes[:8]:
            print(f"::notice title={a['importance']}★ {FIL_NOM[a['feed']]}::{a['title']} ({a['source_name']})", flush=True)
        # Pourquoi des articles ont été écartés (pour régler l'agent sans ouvrir les journaux)
        if ignores:
            from collections import Counter
            motifs = Counter(str(d or "skip") for _, d, _ in ignores)
            # (« warning » : GitHub n'affiche que 10 annotations de chaque niveau par étape)
            print(f"::warning title=Écartés::{', '.join(f'{m} × {n}' for m, n in motifs.most_common())}"
                  f" ; appels à Claude : {appels}/{appels_max}", flush=True)
            lignes_ec = [f"[{d}] {art['title'][:80]} ({art['source_name']}) — {expl[:150]}".replace("\n", " ")
                         for art, d, expl in ignores]
            for i in range(0, min(len(lignes_ec), 40), 8):
                print(f"::warning title=Écartés {i + 1}-{min(i + 8, len(lignes_ec))}::"
                      + "  ||  ".join(lignes_ec[i:i + 8]), flush=True)
        print(f"::warning title=Présélection::{STATS.get('candidats', '?')} candidats lus, "
              f"{STATS.get('pool', '?')} envoyés à la présélection, {STATS.get('choisis', '?')} choisis", flush=True)
        if STATS.get("top"):
            print("::warning title=Choix de la présélection (dans l'ordre)::" + "  ||  ".join(STATS["top"]), flush=True)

    # --- Résumé lisible dans la page GitHub de l'exécution ---
    fichier = os.environ.get("GITHUB_STEP_SUMMARY")
    if fichier:
        with open(fichier, "a", encoding="utf-8") as f:
            f.write("## Résultat de l'agent\n\n"
                    "| Articles retenus | Sciences seules | Tech seules | Les deux | "
                    "Ignorés | Doublons | Erreurs | Appels Claude | Coût estimé |\n"
                    "|---|---|---|---|---|---|---|---|---|\n"
                    f"| {nb_articles} | {decisions['science']} | {decisions['tech']} | "
                    f"{decisions['both']} | {len(ignores)} | {len(doublons)} | {len(erreurs)} | "
                    f"{appels} | {cout:.4f} $ |\n\n"
                    f"Modèle : `{modele['id']}` · Mémoire : {nb_base} articles déjà publiés et "
                    f"{nb_ecartes} liens déjà écartés ont été sautés sans appeler Claude"
                    f"{'' if db.memoire_ok else ' ⚠ (table seen_urls introuvable)'}.\n\n"
                    f"Notifications : {notif_ok} envoyée(s)"
                    f"{f', {notif_ko} échec(s)' if notif_ko else ''}"
                    f"{'' if os.environ.get('FIREBASE_SERVICE_ACCOUNT') else ' (Firebase pas encore configuré)'}.\n\n")
            for feed in ("science", "tech"):
                fiches = [a for a in ajoutes if a["feed"] == feed]
                if fiches:
                    f.write(f"### Fil {FIL_NOM[feed]}\n\n| Note | Thème | Titre | Photo | Source | Pourquoi |\n"
                            "|---|---|---|---|---|---|\n")
                    for a in fiches:
                        f.write(f"| {'★' * a['importance']} | {a['theme']} | {a['title']} | "
                                f"{'📷' if a['image_url'] else ''} | "
                                f"[{a['source_name']}]({a['source_url']}) | {a['explication']} |\n")
                    f.write("\n")
            if doublons:
                f.write("### Doublons écartés\n\n")
                for art, raison in doublons:
                    f.write(f"- {art['title']} → *{raison}*\n")
            if ignores:
                f.write("\n### Ignorés\n\n")
                for art, decision, explication in ignores:
                    f.write(f"- {art['title']} ({art['source_name']}) — *{decision}* : {explication}\n")
            if erreurs:
                f.write("\n### Erreurs\n\n")
                for art, msg in erreurs:
                    f.write(f"- {art['title']} → `{msg}`\n")
            if pannes:
                f.write(f"\n**Sources injoignables :** {', '.join(pannes)}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
