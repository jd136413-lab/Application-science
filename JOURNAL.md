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
