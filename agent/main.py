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
from anthropic import Anthropic

from prompt import SYSTEM_PROMPT, THEMES, build_user_message
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

    def sujets_recents(self) -> list[str]:
        depuis = (MAINTENANT - timedelta(days=JOURS_ANTI_DOUBLONS)).isoformat()
        r = requests.get(self.base, headers=self.headers, timeout=30, params={
            "select": "title,summary", "created_at": f"gte.{depuis}",
            "order": "created_at.desc", "limit": "300"})
        r.raise_for_status()
        sujets = []
        for x in r.json():
            debut = " ".join((x.get("summary") or "").split()[:14])
            sujets.append(f"{x['title']} — {debut}…")
        return sujets

    def inserer(self, ligne: dict) -> str:
        """Renvoie 'ok', 'doublon' ou lève une erreur."""
        h = dict(self.headers, Prefer="return=minimal")
        r = requests.post(self.base, headers=h, json=ligne, timeout=30)
        if r.status_code == 409:
            return "doublon"
        if r.status_code >= 300:
            raise RuntimeError(f"Supabase {r.status_code} : {r.text[:200]}")
        return "ok"


# ============================ FLUX RSS ===============================

def lire_sources(urls_connues: set[str]) -> tuple[list[dict], list[str]]:
    """Lit toutes les sources et renvoie les articles candidats,
    en alternant entre les sources pour varier chaque exécution."""
    limite_age = MAINTENANT - timedelta(days=AGE_MAX_JOURS)
    par_source, pannes = [], []

    sources = SOURCES[:]
    random.shuffle(sources)  # ordre différent à chaque exécution

    for src in sources:
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
                articles.append({"source_name": src["name"], "url": lien,
                                 "title": titre, "text": texte or titre,
                                 "published_at": d})
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


# Format de réponse imposé à Claude : l'API garantit un JSON valide.
SCHEMA_REPONSE = {
    "type": "object",
    "properties": {
        "action": {"type": "string", "enum": ["add", "skip"]},
        "reason": {"type": "string", "enum": ["none", "not_advance", "duplicate"]},
        "duplicate_of": {"type": "string"},
        "title": {"type": "string"},
        "summary": {"type": "string"},
        "theme": {"type": "string", "enum": THEMES},
        "importance": {"type": "integer", "enum": [1, 2, 3, 4, 5]},
    },
    "required": ["action", "reason", "duplicate_of", "title", "summary",
                 "theme", "importance"],
    "additionalProperties": False,
}


def demander_a_claude(client, modele_id, article, sujets) -> tuple[dict | None, int, int, str]:
    rep = client.messages.create(
        model=modele_id,
        max_tokens=1500,
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": build_user_message(article, sujets)}],
        output_config={"format": {"type": "json_schema", "schema": SCHEMA_REPONSE}},
    )
    texte = "".join(b.text for b in rep.content if getattr(b, "type", "") == "text")
    if rep.stop_reason == "refusal":
        # Claude a refusé de traiter le sujet : on l'écarte, ce n'est pas une panne.
        return ({"action": "skip", "reason": "refused"},
                rep.usage.input_tokens, rep.usage.output_tokens, "refus")
    fiche = extraire_json(texte)
    diag = f"arrêt={rep.stop_reason}, début=« {texte[:80]} »"
    return fiche, rep.usage.input_tokens, rep.usage.output_tokens, diag


# ============================== MAIN =================================

def main() -> int:
    # --- Réglages de l'exécution ---
    nb_voulu = lire_entier("NOMBRE_ARTICLES", NOMBRE_ARTICLES_PAR_DEFAUT)
    nb_voulu = max(1, min(nb_voulu, PLAFOND_ARTICLES))
    appels_max = nb_voulu * FACTEUR_APPELS_MAX
    cle_modele = (os.environ.get("MODELE") or MODELE_PAR_DEFAUT).strip().lower()
    if cle_modele not in MODELES:
        cle_modele = MODELE_PAR_DEFAUT
    modele = MODELES[cle_modele]

    for var in ("ANTHROPIC_API_KEY", "SUPABASE_URL", "SUPABASE_SECRET_KEY"):
        if not os.environ.get(var):
            log(f"❌ Secret manquant : {var} (à ajouter dans Settings → Secrets → Actions)")
            return 1

    log(f"▶ Objectif : {nb_voulu} article(s) — modèle : {cle_modele} ({modele['id']})")
    log(f"  Au plus {appels_max} appels à Claude.\n")

    db = Supabase(os.environ["SUPABASE_URL"], os.environ["SUPABASE_SECRET_KEY"])
    client = Anthropic()  # lit ANTHROPIC_API_KEY

    try:
        urls = db.urls_connues()
        nb_base = len(urls)
        urls |= db.urls_deja_ecartees()
        sujets = db.sujets_recents()
    except Exception as ex:
        log(f"❌ Impossible de lire Supabase : {ex}")
        return 1
    log(f"Base : {nb_base} articles publiés, {len(urls) - nb_base} liens déjà écartés, "
        f"{len(sujets)} sujets récents.\n")

    log("Lecture des sources :")
    candidats, pannes = lire_sources(urls)
    log(f"\n{len(candidats)} article(s) candidat(s).\n")

    ajoutes, ignores, doublons, erreurs = [], [], [], []
    tok_in = tok_out = appels = 0

    for art in candidats:
        if len(ajoutes) >= nb_voulu or appels >= appels_max:
            break
        appels += 1
        try:
            fiche, ti, to, diag = demander_a_claude(client, modele["id"], art, sujets)
            tok_in += ti
            tok_out += to
            if fiche is None:
                raise ValueError(f"réponse illisible ({diag})")

            if fiche.get("action") != "add":
                db.marquer_ecarte(art["url"], str(fiche.get("reason", "skip")))
                if fiche.get("reason") == "duplicate":
                    doublons.append((art, fiche.get("duplicate_of", "")))
                    log(f"  ↺ doublon   : {art['title'][:80]}")
                else:
                    if fiche.get("reason") == "refused":
                        art = dict(art, title=art["title"] + " [refusé par Claude]")
                    ignores.append(art)
                    log(f"  – ignoré    : {art['title'][:80]}")
                continue

            titre = str(fiche.get("title", "")).strip().rstrip(".")
            resume = str(fiche.get("summary", "")).strip()
            if not titre or not resume:
                raise ValueError("titre ou résumé vide")
            theme = str(fiche.get("theme", "other")).strip().lower()
            if theme not in THEMES:
                theme = "other"
            try:
                importance = int(round(float(fiche.get("importance", 2))))
            except (TypeError, ValueError):
                importance = 2
            importance = max(1, min(5, importance))

            ligne = {
                "title": titre, "summary": resume, "theme": theme,
                "importance": importance, "source_url": art["url"],
                "source_name": art["source_name"],
                "published_at": art["published_at"].isoformat(),
            }
            if db.inserer(ligne) == "doublon":
                doublons.append((art, "même lien"))
                continue
            ajoutes.append(ligne)
            sujets.insert(0, f"{titre} — {' '.join(resume.split()[:14])}…")
            log(f"  ✔ ajouté [{importance}★ {theme}] : {titre}")
        except Exception as ex:
            msg = (str(ex) or ex.__class__.__name__)[:200]
            erreurs.append((art, msg))
            log(f"  ✖ erreur    : {art['title'][:70]} → {msg}")
            time.sleep(1)

    # --- Coût ---
    p_in, p_out = modele["prix"]
    cout = tok_in / 1e6 * p_in + tok_out / 1e6 * p_out

    # --- Résumé dans les logs ---
    log("\n" + "=" * 60)
    log(f"RÉSUMÉ : {len(ajoutes)} ajouté(s), {len(ignores)} ignoré(s), "
        f"{len(doublons)} doublon(s), {len(erreurs)} erreur(s)")
    log(f"Appels à Claude : {appels} — tokens : {tok_in} entrée / {tok_out} sortie")
    log(f"Coût estimé : {cout:.4f} $")
    if pannes:
        log(f"Sources injoignables : {', '.join(pannes)}")
    log("=" * 60)

    # --- Résumé lisible dans la page GitHub de l'exécution ---
    fichier = os.environ.get("GITHUB_STEP_SUMMARY")
    if fichier:
        with open(fichier, "a", encoding="utf-8") as f:
            f.write(f"## Résultat de l'agent\n\n"
                    f"| Ajoutés | Ignorés | Doublons | Erreurs | Appels Claude | Coût estimé |\n"
                    f"|---|---|---|---|---|---|\n"
                    f"| {len(ajoutes)} | {len(ignores)} | {len(doublons)} | "
                    f"{len(erreurs)} | {appels} | {cout:.4f} $ |\n\n"
                    f"Modèle : `{modele['id']}`\n\n")
            if ajoutes:
                f.write("### Articles ajoutés\n\n| Note | Thème | Titre | Source |\n|---|---|---|---|\n")
                for a in ajoutes:
                    f.write(f"| {'★' * a['importance']} | {a['theme']} | "
                            f"{a['title']} | [{a['source_name']}]({a['source_url']}) |\n")
            if doublons:
                f.write("\n### Doublons écartés\n\n")
                for art, raison in doublons:
                    f.write(f"- {art['title']} → *{raison}*\n")
            if ignores:
                f.write("\n### Ignorés (pas une avancée)\n\n")
                for art in ignores:
                    f.write(f"- {art['title']} ({art['source_name']})\n")
            if erreurs:
                f.write("\n### Erreurs\n\n")
                for art, msg in erreurs:
                    f.write(f"- {art['title']} → `{msg}`\n")
            if pannes:
                f.write(f"\n**Sources injoignables :** {', '.join(pannes)}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
