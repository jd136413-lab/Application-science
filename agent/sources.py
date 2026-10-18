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
    # EurekAlert! bloque les robots (injoignable au 1er essai du 18/10/2026)
    # {"name": "EurekAlert!",   "url": "https://www.eurekalert.org/rss.xml"},
    {"name": "NASA",          "url": "https://www.nasa.gov/news-release/feed/"},
    {"name": "ESA",           "url": "https://www.esa.int/rssfeed/TopNews"},
    {"name": "Nature",        "url": "https://www.nature.com/nature.rss"},
    {"name": "Science",       "url": "https://www.science.org/rss/news_current.xml"},

    # --- En français ---
    {"name": "CNRS Le journal", "url": "https://lejournal.cnrs.fr/rss"},
    {"name": "Inserm",          "url": "https://presse.inserm.fr/feed/"},
]

# Titres écartés d'office, SANS appeler Claude (donc gratuitement) :
# rubriques qui ne sont jamais des avancées. Majuscules sans importance.
TITRES_EXCLUS = [
    "APOD:",            # image astronomique du jour (NASA)
    "Week in images",   # ESA
    "Earth from Space", # ESA
    "Briefing Chat",    # Nature
    "Podcast",
    "Author Correction",
    "Publisher Correction",
    "Retraction",
]
