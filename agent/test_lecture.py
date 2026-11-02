"""Test gratuit (sans Claude) de la lecture des articles (02/11) : lit quelques
articles récents de sources variées et affiche, pour chacun, la longueur du texte
obtenu. Lancé par « Vérifier le code »."""
import os
import sys

os.environ.setdefault("ANTHROPIC_API_KEY", "test")
import feedparser  # noqa: E402

import main  # noqa: E402

FLUX = {
    "Phys.org": "https://phys.org/rss-feed/",
    "ScienceDaily": "https://www.sciencedaily.com/rss/all.xml",
    "Medical Xpress": "https://medicalxpress.com/rss-feed/",
    "Tech Xplore": "https://techxplore.com/rss-feed/",
    "MIT News": "https://news.mit.edu/rss/research",
    "Live Science": "https://www.livescience.com/feeds/all",
}

total = 0
for nom, url in FLUX.items():
    try:
        flux = feedparser.parse(url, agent=main.USER_AGENT)
    except Exception as ex:
        print(f"::warning::{nom} : flux illisible ({ex})")
        continue
    for e in flux.entries[:3]:
        art = {"url": e.get("link", ""), "source_name": nom,
               "text": main.nettoyer_texte(e.get("summary", ""))}
        avant = len(art["text"])
        main.lire_page(art)
        total += 1
        print(f"::notice title={nom}::{avant} → {len(art['text'])} caractères ; "
              f"page : {art.get('statut_page')} ; "
              f"{e.get('title', '')[:70]}")
print(f"::notice title=Lecture des articles::{total} articles")
sys.exit(0)
