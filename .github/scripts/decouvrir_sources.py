"""Cherche et teste des flux RSS candidats pour l'agent (sans appeler Claude, gratuit).

Pour chaque candidat, on essaie les adresses données ; si une adresse est une
page web (et pas un flux), on cherche les flux qu'elle annonce (balises
<link rel="alternate" type="application/rss+xml">) et quelques adresses
habituelles (/feed/, /rss.xml…). On garde le meilleur flux : autorisé par
robots.txt, qui répond, avec le plus d'articles récents.

Résultat : agent/decouverte_sources.md (tableau) et agent/decouverte_sources.json.
"""
import json
import re
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from urllib.parse import urljoin, urlsplit
from urllib.robotparser import RobotFileParser

import feedparser
import requests

UA = "Mozilla/5.0 (compatible; ApplicationScienceBot/1.0)"
MAINTENANT = datetime.now(timezone.utc).replace(tzinfo=None)
SUFFIXES = ["feed/", "rss.xml", "rss", "feed.xml", "atom.xml", "index.xml", "news/rss.xml", "news/feed/"]

from candidats_sources import CANDIDATS  # noqa: E402  (liste dans le même dossier)

_robots = {}


def robots_ok(url: str) -> str:
    p = urlsplit(url)
    base = f"{p.scheme}://{p.netloc}"
    if base not in _robots:
        rp = RobotFileParser()
        try:
            r = requests.get(base + "/robots.txt", timeout=15, headers={"User-Agent": UA})
            if r.status_code >= 400:
                _robots[base] = None
            else:
                rp.parse(r.text.splitlines())
                _robots[base] = rp
        except Exception:
            _robots[base] = "?"
    rp = _robots[base]
    if rp is None:
        return "oui"
    if rp == "?":
        return "?"
    return "oui" if rp.can_fetch(UA, url) else "NON"


def lire_flux(url: str):
    """Renvoie (code, flux feedparser ou None, texte html)."""
    try:
        r = requests.get(url, timeout=20, headers={"User-Agent": UA}, allow_redirects=True)
    except Exception as ex:
        return ex.__class__.__name__, None, ""
    if r.status_code >= 400:
        return str(r.status_code), None, ""
    f = feedparser.parse(r.content)
    if f.entries:
        return str(r.status_code), f, ""
    return str(r.status_code), None, r.text[:400000] if "html" in r.headers.get("content-type", "") else ""


def bilan(url: str, f) -> dict:
    dates = []
    for e in f.entries:
        t = e.get("published_parsed") or e.get("updated_parsed")
        if t:
            dates.append(datetime(*t[:6]))
    recent = max(dates) if dates else None
    d14 = sum(1 for d in dates if d > MAINTENANT - timedelta(days=14))
    img = 0
    for e in f.entries[:10]:
        if e.get("media_content") or e.get("media_thumbnail") or re.search(
                r"<img", " ".join(c.get("value", "") for c in e.get("content", []) or []) + (e.get("summary") or "")):
            img += 1
    return {"url": url, "n": len(f.entries), "recent": recent.strftime("%d/%m/%Y") if recent else "?",
            "jours": (MAINTENANT - recent).days if recent else 999, "d14": d14, "img": img,
            "titre": (f.entries[0].get("title", "") or "").replace("|", "/").replace("\n", " ")[:80]}


def tester(c):
    fil, nom, adresses = c[0], c[1], c[2]
    essais, vus, html_pages = [], set(), []
    for a in adresses:
        if a in vus:
            continue
        vus.add(a)
        code, f, page = lire_flux(a)
        if f is not None:
            essais.append((code, bilan(a, f)))
        elif page:
            html_pages.append((a, page))
        else:
            essais.append((code, None))
    if not any(b for _, b in essais):
        # Découverte : liens annoncés par la page, puis adresses habituelles
        trouves = []
        for a, page in html_pages:
            for m in re.finditer(r"<link[^>]+>", page, re.I):
                t = m.group(0)
                if re.search(r"application/(rss|atom)\+xml", t, re.I):
                    h = re.search(r'href=["\']([^"\']+)', t)
                    if h:
                        trouves.append(urljoin(a, h.group(1)))
            base = a if a.endswith("/") else a + "/"
            trouves += [urljoin(base, s) for s in SUFFIXES]
            p = urlsplit(a)
            trouves += [f"{p.scheme}://{p.netloc}/{s}" for s in SUFFIXES[:4]]
        for t in trouves[:14]:
            if t in vus:
                continue
            vus.add(t)
            code, f, _ = lire_flux(t)
            if f is not None:
                essais.append((code, bilan(t, f)))
                if essais[-1][1]["d14"] >= 3:
                    break
    bons = [b for _, b in essais if b]
    if not bons:
        codes = ",".join(sorted({c for c, _ in essais})) or "page sans flux"
        return {"fil": fil, "nom": nom, "statut": "introuvable", "code": codes, "robots": "-"}
    meilleur = max(bons, key=lambda b: (b["d14"], -b["jours"], b["n"]))
    meilleur.update({"fil": fil, "nom": nom, "statut": "ok", "robots": robots_ok(meilleur["url"])})
    return meilleur


def main() -> int:
    debut = time.time()
    with ThreadPoolExecutor(max_workers=12) as ex:
        res = list(ex.map(tester, CANDIDATS))
    lignes = ["# Découverte de sources candidates", "",
              f"Test du {datetime.now(timezone.utc):%d/%m/%Y %H:%M} UTC depuis GitHub Actions "
              f"({len(CANDIDATS)} candidats, {time.time() - debut:.0f} s).", "",
              "« 14 j » = articles publiés ces 14 derniers jours ; « img » = images dans les 10 premiers articles.", "",
              "| Fil | Source | Statut | robots | Flux | Articles | 14 j | Plus récent | img | Exemple |",
              "|---|---|---|---|---|---|---|---|---|---|"]
    for r in res:
        if r["statut"] == "ok":
            lignes.append(f"| {r['fil']} | {r['nom']} | ok | {r['robots']} | {r['url']} | {r['n']} | {r['d14']} | "
                          f"{r['recent']} | {r['img']} | {r['titre']} |")
        else:
            lignes.append(f"| {r['fil']} | {r['nom']} | introuvable ({r['code']}) | - | - | - | - | - | - | |")
    open(sys.argv[1], "w", encoding="utf-8").write("\n".join(lignes) + "\n")
    open(sys.argv[2], "w", encoding="utf-8").write(json.dumps(res, ensure_ascii=False, indent=1))
    print("\n".join(lignes))
    return 0


if __name__ == "__main__":
    sys.exit(main())
