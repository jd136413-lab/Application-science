"""Teste des flux RSS candidats pour l'agent (sans appeler Claude, gratuit).

Pour chaque flux : robots.txt autorise-t-il l'accès ? Le flux répond-il ?
Combien d'articles, de quand date le plus récent ? Exemple de titre.
Résultat écrit dans agent/verif_sources.md (commité par le workflow).
"""
import sys
import time
from datetime import datetime, timezone
from urllib.parse import urlsplit
from urllib.robotparser import RobotFileParser

import feedparser
import requests

UA = "Mozilla/5.0 (compatible; ApplicationScienceBot/1.0)"

CANDIDATS = [
    # Série du 19/10/2026 (2) : sources aux IMAGES LIBRES DE DROITS
    ("science", "ESA/Webb", "https://esawebb.org/news/feed/"),
    ("science", "ESA/Hubble", "https://esahubble.org/news/feed/"),
    ("science", "NASA Earth Observatory", "https://earthobservatory.nasa.gov/feeds/earth-observatory.rss"),
    ("science", "PLOS ONE", "https://journals.plos.org/plosone/feed/atom"),
    ("science", "PLOS Climate", "https://journals.plos.org/climate/feed/atom"),
    ("science", "PLOS Computational Biology", "https://journals.plos.org/ploscompbiol/feed/atom"),
    ("science", "PLOS Genetics", "https://journals.plos.org/plosgenetics/feed/atom"),
    ("science", "PLOS Pathogens", "https://journals.plos.org/plospathogens/feed/atom"),
    ("science", "PeerJ", "https://peerj.com/articles/index.rss"),
    ("science", "NASA Goddard", "https://www.nasa.gov/centers-and-facilities/goddard/feed/"),
    ("science", "NASA Webb blog", "https://science.nasa.gov/mission/webb/feed/"),
]


def robots_ok(url: str) -> str:
    p = urlsplit(url)
    rp = RobotFileParser()
    try:
        r = requests.get(f"{p.scheme}://{p.netloc}/robots.txt", timeout=20, headers={"User-Agent": UA})
        if r.status_code >= 400:
            return "oui (pas de robots.txt)"
        rp.parse(r.text.splitlines())
        return "oui" if rp.can_fetch(UA, url) else "NON"
    except Exception as ex:
        return f"? ({ex.__class__.__name__})"


def main() -> int:
    lignes = ["# Vérification des sources candidates",
              "",
              f"Test du {datetime.now(timezone.utc):%d/%m/%Y %H:%M} UTC, depuis GitHub Actions.",
              "",
              "| Fil | Source | robots.txt | Réponse | Articles | Plus récent | Exemple de titre |",
              "|---|---|---|---|---|---|---|"]
    for fil, nom, url in CANDIDATS:
        rob = robots_ok(url)
        try:
            r = requests.get(url, timeout=30, headers={"User-Agent": UA})
            code = str(r.status_code)
            f = feedparser.parse(r.content)
            n = len(f.entries)
            dates = []
            for e in f.entries:
                t = e.get("published_parsed") or e.get("updated_parsed")
                if t:
                    dates.append(datetime(*t[:6]))
            recent = max(dates).strftime("%d/%m/%Y") if dates else "?"
            titre = (f.entries[0].get("title", "") if n else "").replace("|", "/")[:70]
        except Exception as ex:
            code, n, recent, titre = ex.__class__.__name__, 0, "-", ""
        lignes.append(f"| {fil} | {nom} | {rob} | {code} | {n} | {recent} | {titre} |")
        print(lignes[-1], flush=True)
        time.sleep(0.5)
    open(sys.argv[1], "w", encoding="utf-8").write("\n".join(lignes) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
