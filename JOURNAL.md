# Journal du projet « Application science »

Une ligne par décision ou changement, la plus récente en bas.

## Phase 0 — Comptes et accès (18/10/2026) ✅
- Ménage : ancienne clé Anthropic supprimée, ancien repo `science-app-agent` archivé, ancien projet Supabase supprimé.
- Repo public `Application-science` créé (public pour pouvoir héberger la version web de test sur GitHub Pages).
- Projet Supabase « Application science » (URL : https://seqpmcovknfgppdolhns.supabase.co).
- Console Anthropic : 5 € de crédits + limite de dépense mensuelle.
- Clé API « Agent application science », valable 30 jours → **à remplacer avant le 17/11/2026** (rappel programmé le 12/11).
- Secret GitHub : `ANTHROPIC_API_KEY`.

## Phase 1 — Base de données (18/10/2026) ✅
- Table `advances` créée (`database/schema.sql`), index période / famille / importance, RLS en lecture publique seule.
- La colonne `family` est calculée automatiquement par la base à partir du thème (codes : space, environment, health, technology, physics, life, earth, other).
- Test de lecture publique dans le navigateur : OK. Ligne de test supprimée.
- Secrets GitHub : `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_SECRET_KEY`.

## Phase 2 — Agent (en cours)
- Code dans `agent/` : `main.py` (réglages en haut), `sources.py` (flux RSS), `prompt.py` (consignes et barème).
- Lancement **uniquement à la main** (aucun horaire). Champs au lancement : nombre d'articles (5 par défaut, plafond 30) et modèle.
- Modèles : `haiku` = Claude Haiku 5.5 (0,10 $ / 0,50 $ par million de tokens, par défaut), `sonnet` = Claude Sonnet 5.5 (2 $ / 10 $).
- Garde-fous coût : au plus 3 appels à Claude par article demandé, une seule exécution à la fois, coût estimé affiché à la fin.
- Anti-doublons : (1) lien déjà en base, paramètres de suivi retirés ; (2) titres d'origine quasi identiques entre sources dans le même lot ; (3) Claude compare au titre + début de résumé des sujets des 21 derniers jours, et à ceux ajoutés pendant l'exécution.
- Sources : Phys.org, ScienceDaily, EurekAlert!, NASA, ESA, Nature, Science, CNRS Le journal, Inserm.
- 18/10 — 1er lancement (5 articles, Haiku) : 2 ajoutés (notes 2★), 8 ignorés, 5 erreurs « pas en JSON », 0,0045 $. EurekAlert! injoignable.
- 18/10 — Correctif : Claude répond maintenant dans un format JSON **garanti par l'API** (sorties structurées), marge de réponse portée à 1500 tokens, diagnostic détaillé en cas d'erreur.
- 18/10 — Rubriques écartées gratuitement avant Claude (`TITRES_EXCLUS` dans `sources.py` : APOD, Week in images, Earth from Space…). EurekAlert! mis en pause.
- 18/10 — 2e lancement (5 articles, Sonnet) : 5 ajoutés, 4 ignorés, 1 refus de Claude, 0,057 $ (environ 20 fois Haiku).
- 18/10 — Décision : **Haiku reste le modèle par défaut**. Définition d'une avancée resserrée (`prompt.py`) : seulement découverte, première, amélioration mesurable ou résultat d'étude nouveau ; vidéos d'explication, projets futurs, synthèses, rétrospectives écartés ; en cas de doute, écarter.
- 18/10 — Un refus de Claude (sujet jugé sensible) compte maintenant comme « ignoré » et non comme erreur.
- 18/10 — 3e lancement (5 articles, Haiku, définition stricte) : 2 ajoutés, 13 ignorés, 0 erreur, 0,0056 $. **Tri validé par Maxime.**
- 18/10 — Définition de Maxime ajoutée en tête des consignes : avancée = augmentation des connaissances fondamentales ou nouveaux outils, procédés ou systèmes qui transforment nos capacités d'action.
- 18/10 — Nouvelle table privée `seen_urls` : l'agent mémorise les liens écartés pour ne plus repayer Claude. Marge d'appels portée à 5 par article demandé (tri strict = peu d'élus).
- 18/10 — Vérification de la table : familles, notes et dates correctes, aucun doublon (9 fiches). Ajout de `database/reset.sql` pour vider la base pendant les tests.
- 18/10 — Lancements après remise à zéro (Haiku, 5 articles) : 5 ajoutés à chaque fois, 0 erreur, environ 0,009 $ par lancement. Le tableau de résultat affiche maintenant une ligne « Mémoire » (liens sautés sans appeler Claude).
- 18/10 — Mémoire vérifiée : 18 liens `not_advance` dans `seen_urls`.

## Phase 2 — Agent ✅ (18/10/2026)
Modèle par défaut : Haiku 5.5. Coût mesuré : environ 0,009 $ pour 5 articles. Lancement manuel uniquement.

## Phase 3 — Maquettes (en cours)
- 18/10 — Maquettes v1 publiées sur un canevas claude.ai « Maquettes Application science » : 10 écrans (premier lancement, fil, cette année, filtres, détail, favoris, réglages, aujourd'hui vide, pas de réseau, thème sombre). Choix proposés : polices Sora (titres) et IBM Plex Sans (texte), bleu #1D4ED8, une couleur et une icône par famille, barre de navigation Actualités / Favoris / Réglages. **En attente de validation.**
- 18/10 — Demande de Maxime : style plus original et coloré mais sobre → nouveau style proposé sur l'écran du fil (et sa version sombre) : polices Bricolage Grotesque (titres) et Figtree (texte), « bande spectre » des 8 familles sous le titre, tuiles d'icônes pleines aux couleurs vives, onglets en pastilles. À valider avant de l'appliquer aux autres écrans.
- 18/10 — Questions ouvertes : images par actualité (options proposées), traduction en 10 langues (plan et coût proposés).
- 18/10 — Décisions de Maxime : titre centré sans date ; langue réglée dans Réglages et selon la langue du téléphone ; **images option B** (photo de la source seulement si licence libre — NASA, ESA — avec crédit, sinon illustration par thème) ; note = **mot + étoiles colorées** ; **deux fils séparés : Sciences et Technologies** (produits : smartphones, cartes graphiques, voitures…).
- 18/10 — Langues : piste retenue à valider = traduction **sur le téléphone** (Google ML Kit, gratuite, plus de 50 langues, Android et iOS ; pas sur la version web de test).
- 18/10 — Maquette du fil mise à jour : titre centré « Avancées » + mot qui change (scientifiques / technologiques), sélecteur Sciences / Technologies, étoiles à la couleur de la famille.
- 18/10 — Ruban de couleurs retiré. « Avancées scientifiques » remplacé par un nom d'app non traduit (proposition : Novum + point coloré), 10 noms à tester dans les Tweaks de l'écran du fil.
- 18/10 — Nom retenu : **Novum**. 6 pistes de logo sur le canevas (A Le point, B Nova, C L'orbite, D La flèche, E La mosaïque, F Le prisme) — choix en attente.
- 18/10 — Fil Tech validé : règles proposées + **8 familles** (Smartphones & objets, Informatique & puces, IA & logiciels, Transports, Espace & aéronautique, Énergie & maison, **Jeux vidéo & consoles**, Autre). Traduction sur le téléphone (ML Kit) validée.
- 18/10 — Mentions de l'IA réduites au minimum : une ligne discrète sous « Lire l'article » (« Résumé automatique · l'article source fait foi ») et une phrase dans Réglages → Nos sources.
- 18/10 — Images dans les maquettes : vignette dans chaque carte, grande image en haut du détail. 11 illustrations originales par famille + 1 exemple de photo de source libre, rangées dans `design/illustrations/`.
- 18/10 — Images : **pas d'illustrations générées**. Une photo seulement si la source est libre de droits (NASA, ESA…), avec crédit ; sinon aucune image. Pour que l'alternance soit naturelle : une carte avec photo devient une « carte photo » (bannière large en haut), les autres restent des cartes texte. Écran de détail sans photo = pas d'en-tête image. Illustrations retirées du repo.
- 18/10 — 6 nouvelles pistes de logo plus artistiques (G Constellation, H Galaxie, I Éclipse, J Comète, K Impression, L Croissant), polices à empattements.
- 18/10 — Cartes photo validées. Maxime préfère la piste K (encres superposées) : 6 variantes ajoutées (K1 Trois encres, K2 Décalage, K3 Soleil et lune, K4 Planète, K5 Trame, K6 Pétales).
- 18/10 — 6 logos « symboles de la science » en encres superposées (S1 Cercle chromatique, S2 Atome, S3 Double hélice, S4 Prisme de Newton, S5 Ondes, S6 Case du tableau périodique « No », nobélium n° 102).
- 18/10 — **Logo retenu : S6** (case du tableau périodique « No », nobélium n° 102, encres rose et bleue décalées, police Fraunces). Installé en haut de l'écran du fil.
- 18/10 — Case « No 102 » encadrée dans l'en-tête du fil. 6 façons d'accrocher « vum » à la case (V1 En indice, V2 Case voisine, V3 Échappée, V4 Ligne continue, V5 Étiquette, V6 Encre qui déborde) — choix en attente.
- 18/10 — **Logo final** : case « No 102 » à coins droits (comme le vrai tableau périodique), encres rose et bleue décalées, « vum » en noir collé à la case, sur la même ligne de base. Installé dans l'en-tête du fil.
- 18/10 — **Style validé (GO)**. Couleurs des familles conservées : la case « No » reste le seul élément rose/bleu. Les 10 écrans des maquettes sont au nouveau style : logo, Sciences/Technologies, familles Tech dans le premier lancement et les filtres, choix du thème (Automatique/Clair/Sombre) et de la langue dans Réglages.

## Phase 3 — Maquettes ✅ (18/10/2026)

## Mise à jour agent + base : fil Technologies et photos (18/10/2026)
- `database/migration_002_tech_photos.sql` : colonnes `feed` (science/tech), `image_url`, `image_credit` ; 20 thèmes tech ; familles tech calculées automatiquement (mobile, computing, ai_software, mobility, aerospace, energy_home, gaming, tech_other). Testé sur un Postgres local, relançable sans danger.
- Sources tech (accès automatique autorisé) : TechCrunch, Engadget, IEEE Spectrum, Tom's Hardware, Electrek, GSMArena, Presse-citron, Journal du Geek. Écartées car elles refusent les robots : The Verge, Ars Technica, Numerama, Frandroid, 01net.
- Consignes Claude séparées pour le fil Tech (produits annoncés/sortis, premières, nouveautés mesurables ; rumeurs, promos, tests, finances écartés ; barème 1 à 5 tech).
- Photos : seulement NASA (domaine public, crédit « Photo : NASA »). ESA désactivé tant que ses conditions ne sont pas vérifiées.
- Bouton Run workflow : nouveau choix **Fil** (sciences / technologies / les deux ; « les deux » partage le nombre d'articles).
- 18/10 — **Classification science / technologie** : le document de Maxime est intégré tel quel (`agent/classification.md`) comme consigne principale de Claude, complété par les règles de l'app (`agent/prompt.py`). Pour chaque article, Claude décide : Sciences, Technologies, **les deux** (→ deux fiches, chacune avec un titre et un résumé orientés selon son fil), ni l'un ni l'autre, indéterminé, ou doublon. Si un seul choix : le résultat principal. Une phrase « Pourquoi » apparaît dans le tableau de résultat.
- 18/10 — Le document étant long, il est mis en cache par l'API (payé en entier au 1er appel, ~10× moins cher ensuite).
- 18/10 — Base : un même lien peut exister une fois par fil (contrainte unique `source_url + feed`), ajouté à `migration_002_tech_photos.sql` (pas encore exécutée). Bouton : le choix « Fil » devient « Sources à lire » (par défaut : les deux).
- 18/10 — 1er lancement avec la classification : 5 articles retenus (4 Sciences, 1 Tech), 14 ignorés, 0,011 $. **Tri validé par Maxime.**
- 18/10 — Photos libres élargies : NASA, NASA Science, NASA JPL (« Courtesy NASA/JPL-Caltech »), ESO (CC BY 4.0, crédit exact lu sur la page). Pour un article retenu d'une de ces sources, l'agent ouvre la page pour trouver l'image principale si le flux n'en a pas, et **refuse l'image si elle porte un crédit d'agence** (Getty, Reuters, AFP, AP…). NOIRLab écarté (site fermé aux robots), ESA toujours désactivé (conditions non vérifiées). ESO et JPL : articles acceptés jusqu'à 90 jours (ils publient peu).
- 18/10 — Lancement « sciences » : 5 articles retenus, dont 1 avec photo libre (ESO, étoile S301), 0,006 $.
- 18/10 — Revues en accès libre : **PLOS Biology et PLOS Medicine ajoutées** (tout sous CC BY 4.0, figures comprises). L'agent prend l'« image vedette » de l'article et construit le crédit (« Image : Auteur et al., Revue (année), CC BY 4.0 ») ; image refusée si la page mentionne BioRender (licence contestée). eLife écarté (pages illisibles pour un robot).
- 18/10 — Nouveau workflow « Télécharger des images » (dossier `design/images/`, crédits dans `CREDITS.md`). Maquettes : deux vraies cartes photo dans le fil (ESO et PLOS) et écran de détail avec la vraie image PLOS.

## Phase 4 — Squelette de l'app et compilation automatique (19/10/2026)
- Projet Flutter dans `app/` : fichier de réglages unique `app/lib/reglages.dart` (couleurs, polices, familles, textes, commenté pour modification depuis GitHub), lecture des avancées dans Supabase (clé publique injectée à la compilation), sélecteur Sciences/Technologies, cartes texte et photo, étoiles colorées, logo Novum 102, écran de détail avec « Lire l'article », états chargement / vide / erreur, tirer pour rafraîchir. Thème clair/sombre selon le téléphone (choix manuel en phase 7).
- Workflow `Compiler l'app` : à chaque modification de `app/`, version web sur GitHub Pages et APK publié dans Releases (lien fixe). 1re compilation verte.
- Version web : https://jd136413-lab.github.io/Application-science/
- APK : https://github.com/jd136413-lab/Application-science/releases/download/apercu/novum.apk (72 Mo pour l'instant, sera allégé plus tard).
- 19/10 — APK : écran noir au lancement sur le POCO de Maxime (la version web fonctionne). Correctifs : l'app affiche le logo immédiatement et se connecte à la base ensuite (délai max 15 s) ; toute erreur s'affiche en clair à l'écran ; moteur graphique Impeller désactivé sur Android (écrans noirs connus sur certains Xiaomi/POCO) ; diagnostic de compilation (permission INTERNET présente, Impeller désactivé, Flutter 3.47.7).
- 19/10 — À savoir : chaque compilation signe l'APK avec une nouvelle clé de test → il faut **désinstaller l'ancienne version avant d'installer la nouvelle**. Une clé fixe sera mise en place en phase 8.
- 19/10 — Le correctif fonctionne en partie : l'app démarre (logo affiché) mais signale une erreur `NoSuchMethodError … SharedPreferencesApiRegistrar.getAll`. Cause : le « nettoyeur » de code Android (R8) supprimait une fonction de la bibliothèque shared_preferences utilisée par Supabase. Correctif : fichier `proguard-rules.pro` (règles « keep » pour les bibliothèques Flutter et Kotlin) branché dans la compilation Android, vérifié par le diagnostic.
