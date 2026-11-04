"""Test gratuit (sans Claude) de la lecture des articles : pour quelques articles
récents de sources variées, compare la longueur du texte obtenu par l'ancienne
lecture « maison » et par la lecture actuelle (trafilatura). Lancé par « Vérifier le code »."""
import os
import sys

os.environ.setdefault("ANTHROPIC_API_KEY", "test")
import feedparser  # noqa: E402

import main  # noqa: E402

NOMS = ["Phys.org", "ScienceDaily", "Medical Xpress", "Le Monde Sciences", "Universe Today",
        "Techno-Science.net", "ETH Zurich", "TechCrunch", "New Atlas", "Pandaily (Chine)",
        "Space.com", "NASA JPL", "MIT News", "Live Science", "Futura Sciences", "Les Numériques",
        "Journal du Geek", "Nature", "The Quantum Insider", "Wired"]
SOURCES = {s["name"]: s["url"] for s in main.SOURCES if s["name"] in NOMS}

total, gains, lisibles_avant, lisibles = 0, 0, 0, 0
for nom, url in SOURCES.items():
    try:
        flux = feedparser.parse(url, agent=main.USER_AGENT)
    except Exception as ex:
        print(f"::warning::{nom} : flux illisible ({ex})")
        continue
    for e in flux.entries[:2]:
        base = {"url": e.get("link", ""), "source_name": nom, "text": main.nettoyer_texte(e.get("summary", ""))}
        flux_len = len(base["text"])
        # Ancienne lecture : trafilatura désactivé
        ancien = dict(base)
        sys.modules["trafilatura"] = None
        main.lire_page(ancien)
        del sys.modules["trafilatura"]
        nouveau = dict(base)
        main.lire_page(nouveau)
        a = len(ancien["text"]) if ancien.get("page_lue") else 0
        b = len(nouveau["text"]) if nouveau.get("page_lue") else 0
        total += 1
        lisibles_avant += a >= main.TEXTE_MIN
        lisibles += b >= main.TEXTE_MIN
        gains += b > a
        print(f"::notice title={nom}::flux {flux_len} · avant {a} · maintenant {b} ({nouveau.get('lecture')}) ; "
              f"page {nouveau.get('statut_page')} ; {e.get('title', '')[:60]}")
        if b >= 400:
            print(f"   début : {nouveau['text'][:200]}")
print(f"::notice title=Lecture des articles::{total} articles · lisibles (≥ {main.TEXTE_MIN} car.) : "
      f"avant {lisibles_avant}, maintenant {lisibles} · texte plus long pour {gains}")
sys.exit(0)
