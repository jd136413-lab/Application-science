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
