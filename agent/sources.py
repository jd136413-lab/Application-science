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

    # =================================================================
    # AJOUTS DU 21/10/2026 — stratégie « sources complémentaires »
    # (testées le 21/10 : agent/decouverte_CANDIDATS.md et _CANDIDATS2.md)
    # 1. Sources PRIMAIRES : l'institution annonce SES propres résultats →
    #    beaucoup de vraies avancées et presque pas de doublons entre elles.
    # 2. Couverture par RÉGION (Europe, Amérique, Asie, Océanie, Moyen-Orient)
    #    et par DOMAINE (océans, climat, chimie, neurosciences, archéologie…).
    # 3. Revues en accès libre CC BY 4.0 : images autorisées (figure de
    #    l'article, crédit auteurs + revue + année, refus si BioRender).
    # =================================================================
    # --- Instituts et universités : France et Europe ---
    {"feed": "science", "name": "Observatoire de Paris", "url": "https://www.observatoiredeparis.psl.eu/spip.php?page=backend", "age_max": 45},
    {"feed": "science", "name": "Max Planck", "url": "https://www.mpg.de/en/research.rss"},
    {"feed": "science", "name": "ETH Zurich", "url": "https://ethz.ch/en/news-and-events/eth-news/news/_jcr_content.feed"},
    {"feed": "science", "name": "EPFL", "url": "https://actu.epfl.ch/feeds/rss/mediacom/en/"},
    {"feed": "science", "name": "Institut Paul Scherrer (PSI)", "url": "https://www.psi.ch/rss.xml", "age_max": 45},
    {"feed": "science", "name": "EMBL", "url": "https://www.embl.org/news/feed/", "age_max": 45},
    {"feed": "science", "name": "Fraunhofer", "url": "https://www.fraunhofer.de/en/rss/press.rss", "age_max": 45},
    {"feed": "science", "name": "Université de Copenhague", "url": "https://news.ku.dk/all_news/?get_rss=1"},
    {"feed": "science", "name": "Université de Lund", "url": "https://www.lunduniversity.lu.se/news/rss"},
    {"feed": "science", "name": "CNIO (cancer, Espagne)", "url": "https://www.cnio.es/en/feed/", "age_max": 45},
    {"feed": "science", "name": "Université de Cambridge", "url": "https://www.cam.ac.uk/news/feed"},
    {"feed": "science", "name": "Francis Crick Institute", "url": "https://www.crick.ac.uk/rss.xml", "age_max": 45},
    # --- Amérique du Nord : agences fédérales, laboratoires nationaux, universités ---
    {"feed": "science", "name": "NSF", "url": "https://www.nsf.gov/rss/rss_www_news.xml"},
    {"feed": "science", "name": "NIST", "url": "https://www.nist.gov/news-events/news/rss.xml"},
    {"feed": "science", "name": "USGS", "url": "https://www.usgs.gov/news/national-news-release/feed", "age_max": 45},
    {"feed": "science", "name": "Berkeley Lab", "url": "https://newscenter.lbl.gov/feed/"},
    {"feed": "science", "name": "Argonne", "url": "https://www.anl.gov/rss.xml", "age_max": 45},
    {"feed": "science", "name": "Oak Ridge (ORNL)", "url": "https://www.ornl.gov/news/feed/"},
    {"feed": "science", "name": "SLAC", "url": "https://www6.slac.stanford.edu/rss.xml"},
    {"feed": "science", "name": "Harvard Gazette", "url": "https://news.harvard.edu/gazette/feed/"},
    {"feed": "science", "name": "Caltech", "url": "https://www.caltech.edu/about/news/rss"},
    {"feed": "science", "name": "University of Washington", "url": "https://www.washington.edu/news/feed/"},
    {"feed": "science", "name": "University of Michigan", "url": "https://news.umich.edu/feed/"},
    {"feed": "science", "name": "Broad Institute", "url": "https://www.broadinstitute.org/rss.xml", "age_max": 45},
    {"feed": "science", "name": "MBARI (océans)", "url": "https://www.mbari.org/feed/", "age_max": 45},
    {"feed": "science", "name": "Carnegie Science", "url": "https://carnegiescience.edu/rss.xml"},
    # NRAO : images CC BY 4.0 (vérifié le 21/10), seulement si le crédit nomme le NRAO.
    {"feed": "science", "name": "NRAO (radioastronomie)", "url": "https://public.nrao.edu/feed/", "photo": "NRAO/AUI/NSF", "credit_page": True, "credit_requis": "NRAO", "age_max": 60},
    {"feed": "science", "name": "ALMA", "url": "https://www.almaobservatory.org/en/feed/", "age_max": 60},
    {"feed": "science", "name": "Observatoire Keck", "url": "https://keckobservatory.org/feed/", "age_max": 60},
    {"feed": "science", "name": "SETI Institute", "url": "https://www.seti.org/rss.xml"},
    {"feed": "science", "name": "UBC (Canada)", "url": "https://news.ubc.ca/feed/"},
    # --- Asie, Moyen-Orient ---
    {"feed": "science", "name": "RIKEN (Japon)", "url": "https://www.riken.jp/feed/news_feed/"},
    {"feed": "science", "name": "Université de Kyoto", "url": "https://www.kyoto-u.ac.jp/en/rss.xml"},
    {"feed": "science", "name": "A*STAR (Singapour)", "url": "https://research.a-star.edu.sg/feed/", "age_max": 45},
    {"feed": "science", "name": "NUS (Singapour)", "url": "https://news.nus.edu.sg/feed/"},
    {"feed": "science", "name": "KAUST Discovery (Arabie saoudite)", "url": "https://discovery.kaust.edu.sa/feed/", "age_max": 45},
    # --- Médias spécialisés par domaine ---
    {"feed": "science", "name": "Physics (APS)", "url": "https://feeds.aps.org/rss/recent/physics.xml"},
    {"feed": "science", "name": "Chemistry World", "url": "https://www.chemistryworld.com/409.rss"},
    {"feed": "science", "name": "Eos (sciences de la Terre)", "url": "https://eos.org/feed"},
    {"feed": "science", "name": "Carbon Brief (climat)", "url": "https://www.carbonbrief.org/feed/"},
    {"feed": "science", "name": "Yale Environment 360", "url": "https://e360.yale.edu/feed.xml"},
    {"feed": "science", "name": "Mongabay (biodiversité)", "url": "https://news.mongabay.com/feed/"},
    {"feed": "science", "name": "The Transmitter (neurosciences)", "url": "https://www.thetransmitter.org/feed/"},
    {"feed": "science", "name": "STAT News (santé)", "url": "https://www.statnews.com/feed/"},
    {"feed": "science", "name": "Science News", "url": "https://www.sciencenews.org/feed"},
    {"feed": "science", "name": "Universe Today", "url": "https://www.universetoday.com/feed/"},
    {"feed": "science", "name": "Archaeology Magazine", "url": "https://archaeology.org/feed/"},
    {"feed": "science", "name": "BBC Science", "url": "https://feeds.bbci.co.uk/news/science_and_environment/rss.xml"},
    {"feed": "science", "name": "The Guardian Science", "url": "https://www.theguardian.com/science/rss"},
    {"feed": "science", "name": "Pour la Science", "url": "https://www.pourlascience.fr/rss.xml"},
    {"feed": "science", "name": "Techno-Science.net", "url": "https://www.techno-science.net/fr/actualites/rss.xml"},
    {"feed": "science", "name": "Ciel & Espace", "url": "https://www.cieletespace.fr/rss"},
    # --- Revues : accès libre CC BY 4.0 (images autorisées : figure de l'article) ---
    {"feed": "science", "name": "Nature Communications", "url": "https://www.nature.com/ncomms.rss", "photo": "Nature Portfolio", "credit_mode": "citation", "image_motif": "springer-static/image/art"},
    {"feed": "science", "name": "Communications Biology", "url": "https://www.nature.com/commsbio.rss", "photo": "Nature Portfolio", "credit_mode": "citation", "image_motif": "springer-static/image/art"},
    {"feed": "science", "name": "Communications Earth & Environment", "url": "https://www.nature.com/commsenv.rss", "photo": "Nature Portfolio", "credit_mode": "citation", "image_motif": "springer-static/image/art"},
    {"feed": "science", "name": "Communications Physics", "url": "https://www.nature.com/commsphys.rss", "photo": "Nature Portfolio", "credit_mode": "citation", "image_motif": "springer-static/image/art"},
    {"feed": "science", "name": "Communications Medicine", "url": "https://www.nature.com/commsmed.rss", "photo": "Nature Portfolio", "credit_mode": "citation", "image_motif": "springer-static/image/art"},
    {"feed": "science", "name": "Scientific Reports", "url": "https://www.nature.com/srep.rss", "photo": "Nature Portfolio", "credit_mode": "citation", "image_motif": "springer-static/image/art"},
    # --- Revues de référence par domaine (pas d'image : articles pas tous en accès libre) ---
    {"feed": "science", "name": "Nature Astronomy", "url": "https://www.nature.com/natastron.rss"},
    {"feed": "science", "name": "Nature Climate Change", "url": "https://www.nature.com/nclimate.rss"},
    {"feed": "science", "name": "Nature Ecology & Evolution", "url": "https://www.nature.com/natecolevol.rss"},
    {"feed": "science", "name": "Nature Physics", "url": "https://www.nature.com/nphys.rss"},
    {"feed": "science", "name": "Nature Geoscience", "url": "https://www.nature.com/ngeo.rss"},
    {"feed": "science", "name": "Nature Neuroscience", "url": "https://www.nature.com/neuro.rss"},
    {"feed": "science", "name": "Nature Biotechnology", "url": "https://www.nature.com/nbt.rss"},
    {"feed": "science", "name": "Cell", "url": "https://www.cell.com/cell/inpress.rss"},
    {"feed": "science", "name": "BMJ", "url": "https://www.bmj.com/rss/recent.xml"},
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
    # =================================================================
    # AJOUTS DU 21/10/2026 — sources complémentaires (voir plus haut)
    # =================================================================
    # --- Laboratoires de recherche et entreprises (annoncent leurs propres nouveautés) ---
    {"feed": "tech", "name": "Google Research", "url": "https://research.google/blog/rss/"},
    {"feed": "tech", "name": "Google DeepMind", "url": "https://deepmind.google/blog/rss.xml"},
    {"feed": "tech", "name": "Microsoft Research", "url": "https://www.microsoft.com/en-us/research/feed/"},
    {"feed": "tech", "name": "IBM Research", "url": "https://research.ibm.com/rss"},
    {"feed": "tech", "name": "Hugging Face", "url": "https://huggingface.co/blog/feed.xml"},
    {"feed": "tech", "name": "Arm", "url": "https://newsroom.arm.com/rss", "age_max": 45},
    {"feed": "tech", "name": "Samsung Semiconductor", "url": "https://news.samsungsemiconductor.com/global/feed/"},
    {"feed": "tech", "name": "Siemens", "url": "https://press.siemens.com/global/en/rss.xml"},
    {"feed": "tech", "name": "Airbus", "url": "https://www.airbus.com/rss.xml", "age_max": 45},
    {"feed": "tech", "name": "Rocket Lab", "url": "https://www.rocketlabusa.com/updates/rss/", "age_max": 45},
    {"feed": "tech", "name": "ESA (technologie spatiale)", "url": "https://www.esa.int/rssfeed/Our_Activities/Space_Engineering_Technology", "age_max": 45},
    {"feed": "tech", "name": "PlayStation Blog", "url": "https://blog.playstation.com/feed/"},
    # --- Médias spécialisés par domaine ---
    {"feed": "tech", "name": "ServeTheHome (serveurs, puces)", "url": "https://www.servethehome.com/feed/"},
    {"feed": "tech", "name": "EE Times (électronique)", "url": "https://www.eetimes.com/feed/"},
    {"feed": "tech", "name": "Semiconductor Engineering", "url": "https://semiengineering.com/feed/"},
    {"feed": "tech", "name": "The Decoder (IA)", "url": "https://the-decoder.com/feed/"},
    {"feed": "tech", "name": "The Robot Report", "url": "https://www.therobotreport.com/feed/"},
    {"feed": "tech", "name": "Robohub", "url": "https://robohub.org/feed/"},
    {"feed": "tech", "name": "The Quantum Insider", "url": "https://thequantuminsider.com/feed/"},
    {"feed": "tech", "name": "pv magazine (solaire)", "url": "https://www.pv-magazine.com/feed/"},
    {"feed": "tech", "name": "Energy-Storage.news (batteries)", "url": "https://www.energy-storage.news/feed/"},
    {"feed": "tech", "name": "electrive (véhicules électriques, Europe)", "url": "https://www.electrive.com/feed/"},
    {"feed": "tech", "name": "CnEVPost (véhicules électriques, Chine)", "url": "https://cnevpost.com/feed/"},
    {"feed": "tech", "name": "Spaceflight Now", "url": "https://spaceflightnow.com/feed/"},
    {"feed": "tech", "name": "NASASpaceflight", "url": "https://www.nasaspaceflight.com/feed/"},
    {"feed": "tech", "name": "Payload (industrie spatiale)", "url": "https://payloadspace.com/feed/"},
    {"feed": "tech", "name": "European Spaceflight", "url": "https://europeanspaceflight.com/feed/"},
    {"feed": "tech", "name": "MedTech Dive (technologies médicales)", "url": "https://www.medtechdive.com/feeds/news/"},
    {"feed": "tech", "name": "DroneDJ (drones)", "url": "https://dronedj.com/feed/"},
    {"feed": "tech", "name": "Nintendo Life", "url": "https://www.nintendolife.com/feeds/latest"},
    {"feed": "tech", "name": "Gematsu (jeux vidéo, Japon)", "url": "https://www.gematsu.com/feed"},
    # --- Par région ---
    {"feed": "tech", "name": "Rest of World (tech hors Occident)", "url": "https://restofworld.org/feed/latest/"},
    {"feed": "tech", "name": "TechNode (Chine)", "url": "https://technode.com/feed/"},
    {"feed": "tech", "name": "Pandaily (Chine)", "url": "https://pandaily.com/feed/"},
    {"feed": "tech", "name": "SCMP Tech (Asie)", "url": "https://www.scmp.com/rss/36/feed"},
    {"feed": "tech", "name": "TechCabal (Afrique)", "url": "https://techcabal.com/feed/"},
    {"feed": "tech", "name": "L'Usine Nouvelle", "url": "https://www.usinenouvelle.com/rss/"},
    {"feed": "tech", "name": "L'Usine Digitale", "url": "https://www.usine-digitale.fr/rss"},
    # Testés le 21/10 et NON retenus : robots.txt refuse (Smithsonian, PNAS),
    # dates absentes dans le flux (DESY, Karolinska, ISTA, NIH, FAPESP, Fierce
    # Biotech, KED Global), flux abandonné (CNRS, Sorbonne, KU Leuven, Salk,
    # Sanger, Toronto, McGill), trop de rumeurs, promos ou actualités d'affaires
    # (TechPowerUp, Android Authority, MacRumors, Gizmochina, CleanTechnica,
    # Canary Media, Light Reading, Sifted, Inc42, Journal du Net, ZDNet, heise,
    # AWS, The Conversation, Knowable). Introuvables : CERN, Stanford, Oxford,
    # Imperial, JAXA, CSIRO, Meta AI, Anthropic, Intel, AMD, Qualcomm, TSMC,
    # CEA, INRAE, Inria, Institut Pasteur (liste complète : agent/decouverte_*.md).
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
