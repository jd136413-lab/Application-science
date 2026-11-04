# =====================================================================
# ESSAI A / B DES CONSIGNES — sans rien publier (04/11/2026)
# ---------------------------------------------------------------------
# A = consignes actuelles de l'agent (tri allégé + rédaction actuelle).
# B = consignes réécrites (agent/essai/consignes_b.py) + anti-doublons renforcé
#     (liste « déjà publié » avec source et résumé, alerte « doublon probable »
#     calculée gratuitement par le programme).
# Jeu d'essai tiré de la base (lecture seule) :
#   - NOUVEAUX : les dernières fiches publiées, retirées de la liste « déjà publié »
#     (attendu : pas un doublon) ; elles servent aussi à comparer la rédaction ;
#   - DOUBLONS CONNUS : les 2 doublons du 04/11 au soir (attendu : doublon) ;
#   - DOUBLONS TIRÉS DES « AUTRES SOURCES » : un autre média qui parle d'une fiche
#     déjà publiée (attendu : doublon) ;
#   - ÉCARTÉS : articles récemment jugés « pas une avancée » (attendu : none).
# Rapport : agent/essai/rapport_ab.md. Coût plafonné (PLAFOND, 0,50 $ par défaut).
# =====================================================================

import json
import os
import re
import sys
import time
import unicodedata
from datetime import datetime, timezone

import requests
from anthropic import Anthropic

import economie
import main as agent
import prompt
import redaction
from essai.consignes_b import REDACTION_B, TRI_B

MODELE, PRIX = "claude-haiku-5-5", (0.10, 0.50)
NB_NOUVEAUX = int(os.environ.get("NB_NOUVEAUX") or 8)
NB_DOUBLONS = int(os.environ.get("NB_DOUBLONS") or 6)
NB_ECARTES = int(os.environ.get("NB_ECARTES") or 4)
PLAFOND = float(os.environ.get("PLAFOND") or 0.5)
DOUBLONS_CONNUS = ["amas d'étoiles ultra-denses", "troisième famille de magnétisme"]
COUT = {"A": 0.0, "B": 0.0}


def cout(u) -> float:
    return ((u.input_tokens or 0) + (getattr(u, "cache_creation_input_tokens", 0) or 0) * 1.25
            + (getattr(u, "cache_read_input_tokens", 0) or 0) * 0.1) * PRIX[0] / 1e6 + (u.output_tokens or 0) * PRIX[1] / 1e6


# ---------------------------------------------------------------- base (lecture seule)

def publiees(db) -> list[dict]:
    depuis = (datetime.now(timezone.utc).timestamp() - 30 * 86400)
    r = requests.get(db.base, headers=db.headers, timeout=30, params={
        "select": "id,title,summary,decouverte,feed,importance,type_etude,source_url,source_name,autres_sources,created_at",
        "created_at": f"gte.{datetime.fromtimestamp(depuis, timezone.utc).isoformat()}",
        "order": "created_at.desc", "limit": "500"})
    r.raise_for_status()
    return r.json()


def ecartes(db, n) -> list[str]:
    r = requests.get(db.base_vus, headers=db.headers, timeout=30, params={
        "select": "url,reason,seen_at", "reason": "eq.none", "order": "seen_at.desc", "limit": str(n * 4)})
    return [x["url"] for x in r.json()] if r.ok else []


def titre_page(url: str) -> str:
    try:
        h = requests.get(url, timeout=20, headers={"User-Agent": agent.USER_AGENT}).text[:300000]
        m = re.search(r'<meta[^>]+property=["\']og:title["\'][^>]+content=["\']([^"\']+)', h) or \
            re.search(r"<title[^>]*>(.*?)</title>", h, re.S)
        return " ".join(m.group(1).split())[:200] if m else ""
    except Exception:
        return ""


def article(url: str, source: str) -> dict:
    a = {"url": url, "source_name": source, "title": titre_page(url) or url, "text": "",
         "published_at": datetime.now(timezone.utc)}
    agent.lire_page(a)
    return a


# ---------------------------------------------------------------- anti-doublon gratuit (version B)

def _norm(t: str) -> str:
    t = unicodedata.normalize("NFD", t or "")
    return "".join(c for c in t if unicodedata.category(c) != "Mn")


_COMMUNS = set("""The This That These Those With From Into About After Before While Where When What Which Their There
Scientists Researchers Study Researchers University Universite Institute Science News Les Des Une Dans Pour Avec Selon
Mais Cette Elle Elles Ils Leur Leurs Sur Par Plus Comme NASA Google Apple Chine China""".split())


def indices(texte: str) -> set[str]:
    """Indices d'identité : noms propres (hors mots courants) et nombres significatifs."""
    t = _norm(texte)
    t = re.sub(r"(?<=\d)[\s  ,.](?=\d{3}\b)", "", t)          # 1 600 / 1,600 → 1600
    mots = {m for m in re.findall(r"\b[A-Z][a-zA-Z\-]{3,}\b", t) if m not in _COMMUNS}
    nombres = {n for n in re.findall(r"\b\d+(?:[.,]\d+)?\b", t) if len(n.replace(",", "").replace(".", "")) >= 3
               and not re.fullmatch(r"20[0-3]\d", n)}                     # années écartées
    return {m.lower() for m in mots} | {n.replace(",", ".") for n in nombres}


def alertes_doublon(art: dict, deja: list[dict]) -> list[str]:
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


# ---------------------------------------------------------------- décision A / B

def message_b(art: dict, deja_b: str, alertes: list[str]) -> list[dict]:
    nouvel = (f"Nouvel article :\nSource (média) : {art['source_name']}\nTitre d'origine : {art['title']}\n"
              f"Date : {art['published_at'].strftime('%Y-%m-%d')}\n")
    if alertes:
        nouvel += "⚠ DOUBLON PROBABLE signalé par le programme (indices d'identité communs) avec :\n- " + "\n- ".join(alertes) + "\n"
    nouvel += f"Texte de l'article (page lue) :\n{art['text']}\n"
    return [{"type": "text", "text": deja_b, "cache_control": {"type": "ephemeral"}}, {"type": "text", "text": nouvel}]


def juger(client, version: str, art: dict, ctx: dict) -> dict:
    if version == "A":
        systeme = prompt.SYSTEM_PROMPT_TRI
        contenu = prompt.build_user_message(art, ctx["sujA"]["science"], ctx["sujA"]["tech"]) + \
            [{"type": "text", "text": agent.CONSIGNE_TRI_SEUL}]
    else:
        systeme = TRI_B
        contenu = message_b(art, ctx["dejaB"], ctx["alertes"].get(art["url"], []))
    for essai in range(3):
        try:
            rep = client.messages.create(
                model=MODELE, max_tokens=8000,
                system=[{"type": "text", "text": systeme, "cache_control": {"type": "ephemeral"}}],
                messages=[{"role": "user", "content": contenu}],
                output_config={"format": {"type": "json_schema", "schema": agent.SCHEMA_REPONSE},
                               "effort": economie.EFFORT_TRI},
                **economie.PARAMS_TRI)
            COUT[version] += cout(rep.usage)
            return agent.extraire_json("".join(b.text for b in rep.content if getattr(b, "type", "") == "text")) or {}
        except Exception as ex:
            time.sleep(10 * (essai + 1))
            err = str(ex)[:120]
    return {"decision": "erreur", "explanation": err}


def resume_decision(d: dict) -> str:
    dec = d.get("decision", "?")
    if dec == "duplicate":
        return f"**doublon** de « {str(d.get('duplicate_of', ''))[:70]} »"
    if dec in ("science", "tech", "both"):
        fs = [d.get(f) or {} for f in (["science", "tech"] if dec == "both" else [dec])]
        return f"**{dec}** {', '.join(str(f.get('importance', '?')) + '★ ' + str(f.get('theme', '')) for f in fs)} — « {fs[0].get('title', '')} »"
    return f"**{dec}**"


def bloc(nom: str, f: dict | None) -> str:
    if not f:
        return f"**{nom}** : (échec)\n"
    mots = " ; ".join(f"**{m.get('mot')}** → {m.get('definition')}" for m in f.get("mots") or []) or "(aucun)"
    return (f"**{nom}**\n\n- **Titre** : {f.get('title')}\n- **Avant** : {f.get('avant')}\n"
            f"- **Découverte** : {f.get('decouverte')}\n- **Et après** : {f.get('apres')}\n"
            f"- **Mots** : {mots}\n- **Type** : {f.get('type_etude')}\n")


def main() -> int:
    client = Anthropic()
    db = agent.Supabase(os.environ["SUPABASE_URL"], os.environ["SUPABASE_SECRET_KEY"])
    toutes = publiees(db)
    print(f"{len(toutes)} fiches publiées sur 30 jours", flush=True)
    connus = [f for f in toutes if any(k.lower() in f["title"].lower() for k in DOUBLONS_CONNUS)]
    nouveaux = [f for f in toutes if f not in connus][:NB_NOUVEAUX]
    exclus = {f["id"] for f in nouveaux + connus}
    deja = [f for f in toutes if f["id"] not in exclus]
    limite_a = datetime.now(timezone.utc).timestamp() - agent.JOURS_ANTI_DOUBLONS * 86400
    sujA = {"science": [], "tech": []}
    for f in deja:
        if datetime.fromisoformat(f["created_at"]).timestamp() >= limite_a:
            sujA[f["feed"]].append(f"{f['title']} — {' '.join((f.get('summary') or '').split()[:14])}…")
    lignes_b = {"science": [], "tech": []}
    for f in deja:
        ident = " ".join((f.get("decouverte") or f.get("summary") or "").split()[:30])
        lignes_b[f["feed"]].append(f"- {f['title']} — source : {f['source_name']} — {ident}…")
    deja_b = ("Déjà publié (30 derniers jours) — fil Sciences :\n" + "\n".join(lignes_b["science"])
              + "\n\nDéjà publié (30 derniers jours) — fil Technologies :\n" + "\n".join(lignes_b["tech"]) + "\n")

    # Jeu d'essai : (catégorie, attendu, article, fiche liée)
    cas = []
    for f in nouveaux:
        cas.append(("nouveau", "pas un doublon", article(f["source_url"], f["source_name"]), f))
    for f in connus:
        cas.append(("doublon connu (04/11)", "doublon", article(f["source_url"], f["source_name"]), f))
    vus = set()
    for f in deja[len(deja) // 6:]:            # fiches pas trop récentes
        if len([c for c in cas if c[0] == "doublon (autre média)"]) >= NB_DOUBLONS:
            break
        for s in f.get("autres_sources") or []:
            if s.get("url") and s.get("nom") != f["source_name"] and s["url"] not in vus:
                a = article(s["url"], s.get("nom") or "?")
                vus.add(s["url"])
                if len(a.get("text", "")) >= agent.TEXTE_MIN and a.get("page_lue"):
                    cas.append(("doublon (autre média)", f"doublon de « {f['title']} »", a, f))
                    break
    for u in ecartes(db, NB_ECARTES):
        if len([c for c in cas if c[0] == "écarté avant"]) >= NB_ECARTES:
            break
        a = article(u, re.sub(r"^https?://(www\.)?([^/]+).*", r"\2", u))
        if len(a.get("text", "")) >= agent.TEXTE_MIN and a.get("page_lue"):
            cas.append(("écarté avant", "none", a, None))
    cas = [c for c in cas if len(c[2].get("text", "")) >= agent.TEXTE_MIN and c[2].get("page_lue")]
    print(f"{len(cas)} articles lisibles dans le jeu d'essai", flush=True)
    ctx = {"sujA": sujA, "dejaB": deja_b, "alertes": {c[2]["url"]: alertes_doublon(c[2], deja) for c in cas}}

    # 1) Décisions
    out = [f"# Essai A / B des consignes — {time.strftime('%d/%m/%Y %H:%M')} UTC\n",
           "A = consignes actuelles · B = consignes réécrites + anti-doublons renforcé. Rien n'est publié.\n",
           "## 1. Décisions (tri et doublons)\n",
           "| # | Catégorie | Article | Attendu | A | B | Alerte du programme (B) |", "|---|---|---|---|---|---|---|"]
    decisions = {}
    for i, (cat, attendu, a, f) in enumerate(cas, 1):
        if COUT["A"] + COUT["B"] > PLAFOND:
            out.append(f"\n_Plafond de coût atteint ({PLAFOND} $)._")
            break
        da, db_ = juger(client, "A", a, ctx), juger(client, "B", a, ctx)
        decisions[i] = (da, db_)
        al = ctx["alertes"].get(a["url"]) or []
        out.append(f"| {i} | {cat} | {a['source_name']} : {a['title'][:70]} | {attendu} | {resume_decision(da)} | "
                   f"{resume_decision(db_)} | {('; '.join(al))[:160] or '—'} |")
        print(f"  {i}/{len(cas)} · A={da.get('decision')} B={db_.get('decision')} · {COUT}", flush=True)
    out.append("\n**Explications** :\n")
    for i, (da, db_) in decisions.items():
        out.append(f"- {i}. A : {da.get('explanation', '')} — B : {db_.get('explanation', '')}")

    # 2) Rédaction des nouveaux (mêmes articles, même titre provisoire, consigne A puis B)
    out.append("\n## 2. Rédaction (mêmes articles, consigne A puis B)\n")
    items = [(f"n{i}", a, f["feed"], {"title": f["title"], "importance": f["importance"], "type_etude": f.get("type_etude")})
             for i, (cat, _, a, f) in enumerate(cas, 1) if cat == "nouveau"]
    res = {}
    for version, consigne in (("A", redaction.CONSIGNE), ("B", REDACTION_B)):
        if COUT["A"] + COUT["B"] > PLAFOND or not items:
            break
        redaction.CONSIGNE = consigne
        r, c = redaction.rediger_lot(client, MODELE, PRIX, items, par_lot=False, log=lambda m: print(m, flush=True))
        COUT[version] += c
        res[version] = r
    for cid, a, fil, br in items:
        out.append(f"\n---\n\n### {cid[1:]}. {br['title']}\n\nSource : {a['source_name']} · {len(a['text'])} caractères · {a['url']}\n")
        for v in ("A", "B"):
            x = res.get(v, {}).get(cid) or {}
            out.append(bloc(f"Version {v} ({x.get('relectures', 0)} relecture(s), {x.get('cout', 0):.4f} $)", x.get("finale")))
            out.append(f"- _Défauts mesurés restants_ : {' ; '.join(x.get('restants') or []) or 'aucun'}\n")
    out.append(f"\n---\n\n## Coût\n\nA : {COUT['A']:.4f} $ · B : {COUT['B']:.4f} $ · total : {COUT['A'] + COUT['B']:.4f} $\n")
    os.makedirs("essai", exist_ok=True)
    with open("essai/rapport_ab.md", "w", encoding="utf-8") as fh:
        fh.write("\n".join(out))
    print(f"Coût : {COUT}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
