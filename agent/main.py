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

from prompt import FILS, build_user_message
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
    limite_age = MAINTENANT - timedelta(days=AGE_MAX_JOURS)
    par_source, pannes = [], []

    sources = [s for s in SOURCES if s.get("feed", "science") == feed]
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
                image, credit = "", ""
                if src.get("photo"):
                    image = image_libre(e)
                    credit = src["photo"] if image else ""
                articles.append({"source_name": src["name"], "url": lien,
                                 "title": titre, "text": texte or titre,
                                 "published_at": d, "image_url": image,
                                 "image_credit": credit})
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


def schema_reponse(themes: list[str]) -> dict:
    """Format de réponse imposé à Claude : l'API garantit un JSON valide."""
    return {
        "type": "object",
        "properties": {
            "action": {"type": "string", "enum": ["add", "skip"]},
            "reason": {"type": "string", "enum": ["none", "not_advance", "duplicate"]},
            "duplicate_of": {"type": "string"},
            "title": {"type": "string"},
            "summary": {"type": "string"},
            "theme": {"type": "string", "enum": themes},
            "importance": {"type": "integer", "enum": [1, 2, 3, 4, 5]},
        },
        "required": ["action", "reason", "duplicate_of", "title", "summary",
                     "theme", "importance"],
        "additionalProperties": False,
    }


def demander_a_claude(client, modele_id, article, sujets, fil) -> tuple[dict | None, int, int, str]:
    rep = client.messages.create(
        model=modele_id,
        max_tokens=1500,
        system=fil["system"],
        messages=[{"role": "user", "content": build_user_message(article, sujets)}],
        output_config={"format": {"type": "json_schema",
                                  "schema": schema_reponse(fil["themes"])}},
    )
    texte = "".join(b.text for b in rep.content if getattr(b, "type", "") == "text")
    if rep.stop_reason == "refusal":
        # Claude a refusé de traiter le sujet : on l'écarte, ce n'est pas une panne.
        return ({"action": "skip", "reason": "refused"},
                rep.usage.input_tokens, rep.usage.output_tokens, "refus")
    fiche = extraire_json(texte)
    diag = f"arrêt={rep.stop_reason}, début=« {texte[:80]} »"
    return fiche, rep.usage.input_tokens, rep.usage.output_tokens, diag


# ============================ UN FIL =================================

def traiter_fil(feed, nb_voulu, appels_max, db, client, modele, urls) -> dict:
    """Collecte un fil (Sciences ou Technologies) et renvoie son bilan."""
    fil = FILS[feed]
    res = {"nom": fil["nom"], "ajoutes": [], "ignores": [], "doublons": [],
           "erreurs": [], "pannes": [], "appels": 0, "tok_in": 0, "tok_out": 0}
    log(f"\n━━━━━━━━ Fil {fil['nom']} ━━━━━━━━")
    try:
        sujets = db.sujets_recents(feed)
    except Exception as ex:
        res["erreurs"].append(({"title": "Lecture de la base"}, str(ex)[:200]))
        log(f"❌ {ex}")
        return res

    log("Lecture des sources :")
    candidats, res["pannes"] = lire_sources(urls, feed)
    log(f"{len(candidats)} article(s) candidat(s), {len(sujets)} sujets récents.\n")

    for art in candidats:
        if len(res["ajoutes"]) >= nb_voulu or res["appels"] >= appels_max:
            break
        res["appels"] += 1
        try:
            fiche, ti, to, diag = demander_a_claude(client, modele["id"], art, sujets, fil)
            res["tok_in"] += ti
            res["tok_out"] += to
            if fiche is None:
                raise ValueError(f"réponse illisible ({diag})")

            if fiche.get("action") != "add":
                db.marquer_ecarte(art["url"], str(fiche.get("reason", "skip")))
                if fiche.get("reason") == "duplicate":
                    res["doublons"].append((art, fiche.get("duplicate_of", "")))
                    log(f"  ↺ doublon   : {art['title'][:80]}")
                else:
                    if fiche.get("reason") == "refused":
                        art = dict(art, title=art["title"] + " [refusé par Claude]")
                    res["ignores"].append(art)
                    log(f"  – ignoré    : {art['title'][:80]}")
                continue

            titre = str(fiche.get("title", "")).strip().rstrip(".")
            resume = str(fiche.get("summary", "")).strip()
            if not titre or not resume:
                raise ValueError("titre ou résumé vide")
            theme = str(fiche.get("theme", "")).strip().lower()
            if theme not in fil["themes"]:
                theme = fil["theme_defaut"]
            try:
                importance = int(round(float(fiche.get("importance", 2))))
            except (TypeError, ValueError):
                importance = 2
            importance = max(1, min(5, importance))

            ligne = {
                "feed": feed, "title": titre, "summary": resume, "theme": theme,
                "importance": importance, "source_url": art["url"],
                "source_name": art["source_name"],
                "published_at": art["published_at"].isoformat(),
                "image_url": art.get("image_url") or None,
                "image_credit": art.get("image_credit") or None,
            }
            if db.inserer(ligne) == "doublon":
                res["doublons"].append((art, "même lien"))
                continue
            res["ajoutes"].append(ligne)
            sujets.insert(0, f"{titre} — {' '.join(resume.split()[:14])}…")
            log(f"  ✔ ajouté [{importance}★ {theme}{' 📷' if ligne['image_url'] else ''}] : {titre}")
        except Exception as ex:
            msg = (str(ex) or ex.__class__.__name__)[:200]
            res["erreurs"].append((art, msg))
            log(f"  ✖ erreur    : {art['title'][:70]} → {msg}")
            time.sleep(1)
    return res


# ============================== MAIN =================================

CHOIX_FIL = {
    "sciences": ["science"], "science": ["science"],
    "technologies": ["tech"], "tech": ["tech"],
    "les deux": ["science", "tech"], "les-deux": ["science", "tech"], "both": ["science", "tech"],
}


def main() -> int:
    # --- Réglages de l'exécution ---
    nb_voulu = lire_entier("NOMBRE_ARTICLES", NOMBRE_ARTICLES_PAR_DEFAUT)
    nb_voulu = max(1, min(nb_voulu, PLAFOND_ARTICLES))
    fils = CHOIX_FIL.get((os.environ.get("FIL") or "sciences").strip().lower(), ["science"])
    if len(fils) == 2:
        # Les deux fils se partagent le nombre demandé (et donc le plafond).
        nb_par_fil = [max(1, (nb_voulu + 1) // 2), max(1, nb_voulu // 2)]
    else:
        nb_par_fil = [nb_voulu]
    cle_modele = (os.environ.get("MODELE") or MODELE_PAR_DEFAUT).strip().lower()
    if cle_modele not in MODELES:
        cle_modele = MODELE_PAR_DEFAUT
    modele = MODELES[cle_modele]

    for var in ("ANTHROPIC_API_KEY", "SUPABASE_URL", "SUPABASE_SECRET_KEY"):
        if not os.environ.get(var):
            log(f"❌ Secret manquant : {var} (à ajouter dans Settings → Secrets → Actions)")
            return 1

    noms = " + ".join(FILS[f]["nom"] for f in fils)
    log(f"▶ Objectif : {nb_voulu} article(s) — fil : {noms} — modèle : {cle_modele} ({modele['id']})")
    log(f"  Au plus {nb_voulu * FACTEUR_APPELS_MAX} appels à Claude au total.")

    db = Supabase(os.environ["SUPABASE_URL"], os.environ["SUPABASE_SECRET_KEY"])
    client = Anthropic()  # lit ANTHROPIC_API_KEY

    try:
        urls = db.urls_connues()
        nb_base = len(urls)
        urls |= db.urls_deja_ecartees()
        nb_ecartes = len(urls) - nb_base
    except Exception as ex:
        log(f"❌ Impossible de lire Supabase : {ex}")
        return 1
    log(f"Base : {nb_base} articles publiés, {nb_ecartes} liens déjà écartés.")

    bilans = [traiter_fil(f, n, n * FACTEUR_APPELS_MAX, db, client, modele, urls)
              for f, n in zip(fils, nb_par_fil)]

    # --- Totaux et coût ---
    def total(cle):
        return sum(len(b[cle]) if isinstance(b[cle], list) else b[cle] for b in bilans)
    appels, tok_in, tok_out = total("appels"), total("tok_in"), total("tok_out")
    p_in, p_out = modele["prix"]
    cout = tok_in / 1e6 * p_in + tok_out / 1e6 * p_out

    log("\n" + "=" * 60)
    log(f"RÉSUMÉ : {total('ajoutes')} ajouté(s), {total('ignores')} ignoré(s), "
        f"{total('doublons')} doublon(s), {total('erreurs')} erreur(s)")
    log(f"Appels à Claude : {appels} — tokens : {tok_in} entrée / {tok_out} sortie")
    log(f"Coût estimé : {cout:.4f} $")
    log("=" * 60)

    # --- Résumé lisible dans la page GitHub de l'exécution ---
    fichier = os.environ.get("GITHUB_STEP_SUMMARY")
    if fichier:
        with open(fichier, "a", encoding="utf-8") as f:
            f.write(f"## Résultat de l'agent\n\n"
                    f"| Fil | Ajoutés | Ignorés | Doublons | Erreurs | Appels Claude |\n"
                    f"|---|---|---|---|---|---|\n")
            for b in bilans:
                f.write(f"| {b['nom']} | {len(b['ajoutes'])} | {len(b['ignores'])} | "
                        f"{len(b['doublons'])} | {len(b['erreurs'])} | {b['appels']} |\n")
            f.write(f"\n**Coût estimé : {cout:.4f} $** · modèle `{modele['id']}`\n\n"
                    f"Mémoire : {nb_base} articles déjà publiés et "
                    f"{nb_ecartes} liens déjà écartés ont été sautés sans appeler Claude"
                    f"{'' if db.memoire_ok else ' ⚠ (table seen_urls introuvable)'}.\n\n")
            for b in bilans:
                f.write(f"---\n## Fil {b['nom']}\n\n")
                if b["ajoutes"]:
                    f.write("### Articles ajoutés\n\n| Note | Thème | Titre | Photo | Source |\n"
                            "|---|---|---|---|---|\n")
                    for a in b["ajoutes"]:
                        f.write(f"| {'★' * a['importance']} | {a['theme']} | {a['title']} | "
                                f"{'📷' if a['image_url'] else ''} | "
                                f"[{a['source_name']}]({a['source_url']}) |\n")
                if b["doublons"]:
                    f.write("\n### Doublons écartés\n\n")
                    for art, raison in b["doublons"]:
                        f.write(f"- {art['title']} → *{raison}*\n")
                if b["ignores"]:
                    f.write("\n### Ignorés\n\n")
                    for art in b["ignores"]:
                        f.write(f"- {art['title']} ({art['source_name']})\n")
                if b["erreurs"]:
                    f.write("\n### Erreurs\n\n")
                    for art, msg in b["erreurs"]:
                        f.write(f"- {art['title']} → `{msg}`\n")
                if b["pannes"]:
                    f.write(f"\n**Sources injoignables :** {', '.join(b['pannes'])}\n")
                f.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
