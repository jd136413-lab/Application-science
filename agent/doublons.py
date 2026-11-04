# =====================================================================
# ANTI-DOUBLONS GRATUIT (04/11/2026, retenu après l'essai A/B)
# ---------------------------------------------------------------------
# Repère, sans appel à Claude, les fiches déjà publiées qui partagent avec un
# nouvel article des « indices d'identité » rares (noms propres, chiffres) :
# « Sapienza », « Bêta Pictoris », « 1 600 »… Le juge reçoit alors un
# avertissement « DOUBLON PROBABLE » et vérifie en priorité.
# =====================================================================

import re
import unicodedata


def _norm(t: str) -> str:
    t = unicodedata.normalize("NFD", t or "")
    return "".join(c for c in t if unicodedata.category(c) != "Mn")


_COMMUNS = set("""The This That These Those With From Into About After Before While Where When What Which Their There
Scientists Researchers Study Researchers University Universite Institute Science News Les Des Une Dans Pour Avec Selon
Mais Cette Elle Elles Ils Leur Leurs Sur Par Plus Comme NASA Google Apple Chine China""".split())


# Version C : noms trop courants pour identifier une étude (instruments, lieux, agences)
_TROP_COURANTS = set("""webb james-webb james hubble nasa esa spacex mars lune moon terre earth soleil sun
chine china europe japon japan inde india amerique america etats-unis france allemagne germany
rubin vera tesla apple google microsoft openai samsung huawei meta amazon nvidia intel""".split())
STRICT = False   # True = filtre version C (essai du 04/11 au soir)


def indices(texte: str) -> set[str]:
    """Indices d'identité : noms propres (hors mots courants) et nombres significatifs."""
    t = _norm(texte)
    if STRICT:   # un mot à majuscule qui apparaît aussi en minuscule est un mot ordinaire (début de phrase)
        bas = set(re.findall(r"\b[a-z][a-z\-]{3,}\b", t))
    t = re.sub(r"(?<=\d)[\s  ,.](?=\d{3}\b)", "", t)          # 1 600 / 1,600 → 1600
    mots = {m for m in re.findall(r"\b[A-Z][a-zA-Z\-]{3,}\b", t) if m not in _COMMUNS}
    if STRICT:
        mots = {m for m in mots if m.lower() not in bas and m.lower() not in _TROP_COURANTS}
    nombres = {n for n in re.findall(r"\b\d+(?:[.,]\d+)?\b", t) if len(n.replace(",", "").replace(".", "")) >= 3
               and not re.fullmatch(r"20[0-3]\d", n)}                     # années écartées
    return {m.lower() for m in mots} | {n.replace(",", ".") for n in nombres}


def alertes_doublon(art: dict, deja: list[dict]) -> list[str]:
    """deja : fiches publiées {title, summary, decouverte}. Renvoie au plus 3 alertes lisibles."""
    a = indices(art["title"] + " " + art.get("text", "")[:3000])
    df = {}
    pubs = [(f, indices(" ".join(str(f.get(k) or "") for k in ("title", "summary", "decouverte")))) for f in deja]
    for _, s in pubs:
        for x in s:
            df[x] = df.get(x, 0) + 1
    res = []
    for f, s in pubs:
        communs = sorted(x for x in a & s if df.get(x, 0) <= 3)
        if len(communs) >= 2:
            res.append((len(communs), f["title"], communs[:6]))
    res.sort(reverse=True)
    return [f"« {t} » (indices communs : {', '.join(c)})" for _, t, c in res[:3]]


