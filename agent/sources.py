# =====================================================================
# SOURCES DE L'AGENT
# ---------------------------------------------------------------------
# Liste des flux RSS lus par l'agent. Pour ajouter une source, copie une
# ligne, change le nom et l'adresse. Pour en retirer une, mets un # devant.
# Une source en panne n'arrête pas l'agent : elle est juste signalée
# dans le résumé de fin.
# =====================================================================

SOURCES = [
    # --- En anglais ---
    {"name": "Phys.org",      "url": "https://phys.org/rss-feed/"},
    {"name": "ScienceDaily",  "url": "https://www.sciencedaily.com/rss/all.xml"},
    {"name": "EurekAlert!",   "url": "https://www.eurekalert.org/rss.xml"},
    {"name": "NASA",          "url": "https://www.nasa.gov/news-release/feed/"},
    {"name": "ESA",           "url": "https://www.esa.int/rssfeed/TopNews"},
    {"name": "Nature",        "url": "https://www.nature.com/nature.rss"},
    {"name": "Science",       "url": "https://www.science.org/rss/news_current.xml"},

    # --- En français ---
    {"name": "CNRS Le journal", "url": "https://lejournal.cnrs.fr/rss"},
    {"name": "Inserm",          "url": "https://presse.inserm.fr/feed/"},
]
