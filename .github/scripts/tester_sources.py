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
    # (fil, nom, adresse du flux)
    # ---- Sciences : actualités générales (anglais)
    ("science", "Quanta Magazine", "https://www.quantamagazine.org/feed/"),
    ("science", "New Scientist", "https://www.newscientist.com/feed/home/"),
    ("science", "Live Science", "https://www.livescience.com/feeds/all"),
    ("science", "Space.com", "https://www.space.com/feeds/all"),
    ("science", "New Atlas", "https://newatlas.com/index.rss"),
    ("science", "Medical Xpress", "https://medicalxpress.com/rss-feed/"),
    ("science", "MIT News", "https://news.mit.edu/rss/feed"),
    ("science", "CERN", "https://home.cern/api/news/news/feed.rss"),
    ("science", "NIH News", "https://www.nih.gov/news-events/news-releases/feed"),
    ("science", "NOAA", "https://www.noaa.gov/rss.xml"),
    ("science", "Max Planck", "https://www.mpg.de/en/rss"),
    # ---- Sciences : grandes revues (essais cliniques, ruptures)
    ("science", "NEJM", "https://www.nejm.org/action/showFeed?type=etoc&feed=rss&jc=nejm"),
    ("science", "The Lancet", "https://www.thelancet.com/rssfeed/lancet_online.xml"),
    ("science", "Nature Medicine", "https://www.nature.com/nm.rss"),
    ("science", "Science Advances", "https://www.science.org/action/showFeed?type=etoc&feed=rss&jc=sciadv"),
    # ---- Sciences : francophones
    ("science", "Futura Sciences", "https://www.futura-sciences.com/rss/actualites.xml"),
    ("science", "Sciences et Avenir", "https://www.sciencesetavenir.fr/rss.xml"),
    ("science", "Le Monde Sciences", "https://www.lemonde.fr/sciences/rss_full.xml"),
    ("science", "The Conversation FR Sciences", "https://theconversation.com/fr/topics/sciences-1015/articles.atom"),
    ("science", "CEA", "https://www.cea.fr/rss/actualites.xml"),
    ("science", "INRAE", "https://www.inrae.fr/rss.xml"),
    ("science", "Institut Pasteur", "https://www.pasteur.fr/fr/rss.xml"),
    ("science", "Polytechnique Insights", "https://www.polytechnique-insights.com/feed/"),
    # ---- Technologies : actualités (anglais)
    ("tech", "MIT Technology Review", "https://www.technologyreview.com/feed/"),
    ("tech", "Wired", "https://www.wired.com/feed/rss"),
    ("tech", "Tech Xplore", "https://techxplore.com/rss-feed/"),
    ("tech", "9to5Mac", "https://9to5mac.com/feed/"),
    ("tech", "9to5Google", "https://9to5google.com/feed/"),
    ("tech", "VideoCardz", "https://videocardz.com/feed"),
    ("tech", "SpaceNews", "https://spacenews.com/feed/"),
    ("tech", "InsideEVs", "https://insideevs.com/rss/news/all/"),
    ("tech", "The Register", "https://www.theregister.com/headlines.atom"),
    # ---- Technologies : sources officielles (annonces de produits)
    ("tech", "Apple Newsroom", "https://www.apple.com/newsroom/rss-feed.rss"),
    ("tech", "NVIDIA Newsroom", "https://nvidianews.nvidia.com/releases.xml"),
    ("tech", "Google Blog", "https://blog.google/rss/"),
    ("tech", "OpenAI News", "https://openai.com/news/rss.xml"),
    ("tech", "Samsung Newsroom", "https://news.samsung.com/global/feed"),
    ("tech", "Microsoft News", "https://news.microsoft.com/source/feed/"),
    # ---- Technologies : francophones
    ("tech", "Les Numériques", "https://www.lesnumeriques.com/rss.xml"),
    ("tech", "Clubic", "https://www.clubic.com/feed/news.rss"),
    ("tech", "Siècle Digital", "https://siecledigital.fr/feed/"),
    ("tech", "Korben", "https://korben.info/feed"),
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
