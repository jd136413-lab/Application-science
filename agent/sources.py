# =====================================================================
# SOURCES DE L'AGENT
# ---------------------------------------------------------------------
# Liste des flux RSS lus par l'agent, rangés par fil :
#   "science" → fil Sciences      "tech" → fil Technologies
# Pour ajouter une source, copie une ligne, change le nom et l'adresse.
# Pour en retirer une, mets un # devant.
# Une source en panne n'arrête pas l'agent : elle est juste signalée.
#
# "photo" : à remplir UNIQUEMENT pour une source dont les images sont libres
# de droits. C'est le crédit affiché sous la photo. Sans "photo", l'agent
# ne prend jamais d'image.
#
# Sites écartés le 18/10/2026 car ils refusent l'accès automatique :
# The Verge, Ars Technica, Numerama, Frandroid, 01net.
# =====================================================================

SOURCES = [
    # ---------------------------- SCIENCES ----------------------------
    {"feed": "science", "name": "Phys.org",        "url": "https://phys.org/rss-feed/"},
    {"feed": "science", "name": "ScienceDaily",    "url": "https://www.sciencedaily.com/rss/all.xml"},
    {"feed": "science", "name": "NASA",            "url": "https://www.nasa.gov/news-release/feed/",
     "photo": "Photo : NASA"},   # images NASA : libres, mention « NASA » obligatoire
    # ESA : photos désactivées tant que leurs conditions n'ont pas été vérifiées.
    {"feed": "science", "name": "ESA",             "url": "https://www.esa.int/rssfeed/TopNews"},
    {"feed": "science", "name": "Nature",          "url": "https://www.nature.com/nature.rss"},
    {"feed": "science", "name": "Science",         "url": "https://www.science.org/rss/news_current.xml"},
    {"feed": "science", "name": "CNRS Le journal", "url": "https://lejournal.cnrs.fr/rss"},
    {"feed": "science", "name": "Inserm",          "url": "https://presse.inserm.fr/feed/"},
    # EurekAlert! bloque les robots (injoignable au 1er essai du 18/10/2026)
    # {"feed": "science", "name": "EurekAlert!", "url": "https://www.eurekalert.org/rss.xml"},

    # -------------------------- TECHNOLOGIES --------------------------
    {"feed": "tech", "name": "TechCrunch",       "url": "https://techcrunch.com/feed/"},
    {"feed": "tech", "name": "Engadget",         "url": "https://www.engadget.com/rss.xml"},
    {"feed": "tech", "name": "IEEE Spectrum",    "url": "https://spectrum.ieee.org/feeds/feed.rss"},
    {"feed": "tech", "name": "Tom's Hardware",   "url": "https://www.tomshardware.com/feeds/all"},
    {"feed": "tech", "name": "Electrek",         "url": "https://electrek.co/feed/"},
    {"feed": "tech", "name": "GSMArena",         "url": "https://www.gsmarena.com/rss-news-reviews.php3"},
    {"feed": "tech", "name": "Presse-citron",    "url": "https://www.presse-citron.net/feed/"},
    {"feed": "tech", "name": "Journal du Geek",  "url": "https://www.journaldugeek.com/feed/"},
]

# Titres écartés d'office, SANS appeler Claude (donc gratuitement) :
# rubriques qui ne sont jamais des avancées. Majuscules sans importance.
TITRES_EXCLUS = [
    # Sciences
    "APOD:",            # image astronomique du jour (NASA)
    "Week in images",   # ESA
    "Earth from Space", # ESA
    "Briefing Chat",    # Nature
    "Podcast",
    "Author Correction",
    "Publisher Correction",
    "Retraction",
    # Technologies : promos, sondages, tests, tutoriels
    "Deals:", "Deal:", "deal of the day", "all-time low", "% off", "Black Friday",
    "Prime Day", "Weekly poll", "bon plan", "code promo", "Test de ", "Test du ",
    "Test :", "review:", "How to ", "Tuto",
]
