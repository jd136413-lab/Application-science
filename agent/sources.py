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
    # --- Sources aux images LIBRES DE DROITS (vérifié le 18/10/2026) ---
    # NASA : domaine public, mention « NASA ».
    {"feed": "science", "name": "NASA",            "url": "https://www.nasa.gov/news-release/feed/",
     "photo": "Photo : NASA"},
    {"feed": "science", "name": "NASA Science",    "url": "https://science.nasa.gov/feed/",
     "photo": "Photo : NASA"},
    # JPL : libre avec la mention exacte « Courtesy NASA/JPL-Caltech ».
    {"feed": "science", "name": "NASA JPL",        "url": "https://www.jpl.nasa.gov/feeds/news",
     "photo": "Courtesy NASA/JPL-Caltech", "age_max": 90},
    # ESO : licence CC BY 4.0, le crédit exact de chaque image est lu sur la page.
    {"feed": "science", "name": "ESO",             "url": "https://www.eso.org/public/news/feed/",
     "photo": "ESO", "credit_page": True, "age_max": 90},   # publie peu : 90 jours
    # PLOS : revues en accès libre, tout sous CC BY 4.0 (figures comprises).
    # L'image est l'« image vedette » de l'article ; le crédit (auteurs, revue,
    # année) est lu sur la page. Image refusée si la page mentionne BioRender.
    {"feed": "science", "name": "PLOS Biology",   "url": "https://journals.plos.org/plosbiology/feed/atom",
     "photo": "PLOS", "credit_mode": "plos", "age_max": 45},
    {"feed": "science", "name": "PLOS Medicine",  "url": "https://journals.plos.org/plosmedicine/feed/atom",
     "photo": "PLOS", "credit_mode": "plos", "age_max": 45},
    # Ajouts du 19/10/2026 (licences vérifiées, flux testés : agent/verif_sources.md)
    # ESA/Webb et ESA/Hubble : CC BY 4.0, crédit exact lu sous chaque image (comme l'ESO).
    {"feed": "science", "name": "ESA/Webb",       "url": "https://esawebb.org/news/feed/",
     "photo": "ESA/Webb", "credit_page": True, "age_max": 90},
    {"feed": "science", "name": "ESA/Hubble",     "url": "https://esahubble.org/news/feed/",
     "photo": "ESA/Hubble", "credit_page": True, "age_max": 90},
    # NASA Goddard : domaine public, mention « NASA ».
    {"feed": "science", "name": "NASA Goddard",   "url": "https://www.nasa.gov/centers-and-facilities/goddard/feed/",
     "photo": "Photo : NASA"},
    # Autres revues PLOS : CC BY 4.0, même traitement que PLOS Biology.
    {"feed": "science", "name": "PLOS ONE",       "url": "https://journals.plos.org/plosone/feed/atom",
     "photo": "PLOS", "credit_mode": "plos"},
    {"feed": "science", "name": "PLOS Climate",   "url": "https://journals.plos.org/climate/feed/atom",
     "photo": "PLOS", "credit_mode": "plos", "age_max": 45},
    {"feed": "science", "name": "PLOS Computational Biology", "url": "https://journals.plos.org/ploscompbiol/feed/atom",
     "photo": "PLOS", "credit_mode": "plos", "age_max": 45},
    {"feed": "science", "name": "PLOS Genetics",  "url": "https://journals.plos.org/plosgenetics/feed/atom",
     "photo": "PLOS", "credit_mode": "plos", "age_max": 45},
    {"feed": "science", "name": "PLOS Pathogens", "url": "https://journals.plos.org/plospathogens/feed/atom",
     "photo": "PLOS", "credit_mode": "plos", "age_max": 45},
    # Testés sans succès : PeerJ (accès refusé), NASA Earth Observatory (flux vide).
    # NOIRLab (CC BY 4.0) : site fermé aux robots, non utilisé.
    # eLife (CC BY 4.0) : pages illisibles sans navigateur complet, non utilisé.
    # ESA : photos désactivées tant que leurs conditions n'ont pas été vérifiées.
    {"feed": "science", "name": "ESA",             "url": "https://www.esa.int/rssfeed/TopNews"},
    {"feed": "science", "name": "Nature",          "url": "https://www.nature.com/nature.rss"},
    {"feed": "science", "name": "Science",         "url": "https://www.science.org/rss/news_current.xml"},
    {"feed": "science", "name": "CNRS Le journal", "url": "https://lejournal.cnrs.fr/rss"},
    {"feed": "science", "name": "Inserm",          "url": "https://presse.inserm.fr/feed/"},
    # Ajouts du 19/10/2026 (robots.txt et flux vérifiés : agent/verif_sources.md)
    {"feed": "science", "name": "Quanta Magazine", "url": "https://www.quantamagazine.org/feed/"},
    {"feed": "science", "name": "Live Science",    "url": "https://www.livescience.com/feeds/all"},
    {"feed": "science", "name": "Space.com",       "url": "https://www.space.com/feeds/all"},
    {"feed": "science", "name": "Medical Xpress",  "url": "https://medicalxpress.com/rss-feed/"},
    {"feed": "science", "name": "MIT News",        "url": "https://news.mit.edu/rss/feed"},
    {"feed": "science", "name": "NOAA",            "url": "https://www.noaa.gov/rss.xml"},
    {"feed": "science", "name": "Nature Medicine", "url": "https://www.nature.com/nm.rss"},
    {"feed": "science", "name": "Futura Sciences", "url": "https://www.futura-sciences.com/rss/actualites.xml"},
    {"feed": "science", "name": "Sciences et Avenir", "url": "https://www.sciencesetavenir.fr/rss.xml"},
    {"feed": "science", "name": "Le Monde Sciences", "url": "https://www.lemonde.fr/sciences/rss_full.xml"},
    # Écartés le 19/10/2026 : robots.txt refuse (New Scientist, NEJM, The Lancet,
    # Science Advances, The Register) ; flux introuvable (CERN, NIH, Max Planck,
    # CEA, INRAE, Institut Pasteur, Polytechnique Insights).
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
    # Ajouts du 19/10/2026 (robots.txt et flux vérifiés : agent/verif_sources.md)
    {"feed": "tech", "name": "MIT Technology Review", "url": "https://www.technologyreview.com/feed/"},
    {"feed": "tech", "name": "Wired",            "url": "https://www.wired.com/feed/rss"},
    {"feed": "tech", "name": "Tech Xplore",      "url": "https://techxplore.com/rss-feed/"},
    {"feed": "tech", "name": "New Atlas",        "url": "https://newatlas.com/index.rss"},
    {"feed": "tech", "name": "9to5Mac",          "url": "https://9to5mac.com/feed/"},
    {"feed": "tech", "name": "9to5Google",       "url": "https://9to5google.com/feed/"},
    {"feed": "tech", "name": "SpaceNews",        "url": "https://spacenews.com/feed/"},
    {"feed": "tech", "name": "InsideEVs",        "url": "https://insideevs.com/rss/news/all/"},
    {"feed": "tech", "name": "Les Numériques",   "url": "https://www.lesnumeriques.com/rss.xml"},
    {"feed": "tech", "name": "Clubic",           "url": "https://www.clubic.com/feed/news.rss"},
    {"feed": "tech", "name": "Siècle Digital",   "url": "https://siecledigital.fr/feed/"},
    # Sources officielles : annonces de produits à la source
    {"feed": "tech", "name": "Apple Newsroom",   "url": "https://www.apple.com/newsroom/rss-feed.rss"},
    {"feed": "tech", "name": "NVIDIA Newsroom",  "url": "https://nvidianews.nvidia.com/releases.xml"},
    {"feed": "tech", "name": "Google Blog",      "url": "https://blog.google/rss/"},
    {"feed": "tech", "name": "OpenAI News",      "url": "https://openai.com/news/rss.xml"},
    {"feed": "tech", "name": "Microsoft News",   "url": "https://news.microsoft.com/source/feed/"},
    # Écartés le 19/10/2026 : VideoCardz (accès refusé), Samsung Newsroom
    # (robots.txt illisible), Korben (surtout des outils et tutoriels).
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
    "The Download:", "Actualité : Bon plan", "Sponsored", "Partner content",
]
