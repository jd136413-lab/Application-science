# NovaSTEM (ex-Novum) — feuille de route (idées retenues par Maxime, 19/10/2026)

Ligne directrice pour la suite du projet, après la publication (phase 9).
Difficulté : ★ facile · ★★ moyen · ★★★ ambitieux. 💶 = coût à surveiller (budget de l'agent < 1 €/mois).
Chaque nouvel écran passe d'abord par une maquette, validée avant d'être codée.

---

## Vue d'ensemble par faisabilité

### Court terme (★ — faisable rapidement, peu ou pas de coût)
| Idée | Catégorie | Note de Maxime |
|---|---|---|
| Fiabilité de l'étude (badge) | Lecture | — |
| À la une | Fil et découverte | « avec une belle image bien choisie » |
| Animations douces | Visuel | « pourquoi pas » |

### Moyen terme (★★)
| Idée | Catégorie | Note de Maxime |
|---|---|---|
| Plus de photos libres | Visuel | « ça c'est sûr que oui » (priorité) |
| Plus de sources (francophones et complémentaires) | Qualité de l'info | « pour ne rien rater, scientifique ou technologique » (priorité) |
| Partager une avancée en image | Visuel / faire connaître | « pour faire de la pub sur les réseaux, c'est vraiment bien » (priorité) |
| Mesurer l'usage sans pister (statistiques) | Faire vivre le projet | « oui je veux des statistiques !!! » (priorité) |
| Glossaire au toucher | Lecture | — |
| Résumé de la semaine | Fil et découverte | « pourquoi pas, à voir » |
| Frise chronologique | Fil et découverte | « pourquoi pas, à voir » |
| Widget d'écran d'accueil | Visuel | « pourquoi pas, à voir » |
| Quiz de la semaine | Apprendre et jouer | — |
| Version iPhone et tablette | Plateformes | « avec peut-être aussi PC » |

### Long terme (★★★)
| Idée | Catégorie | Note de Maxime |
|---|---|---|
| Fils liés (« Sur le même sujet ») | Fil et découverte | « ce serait incroyable », mais ne rater aucune actualité est difficile |
| Collection (cartes à collectionner) | Apprendre et jouer | « vraiment à long terme », style jeu de cartes à collectionner |
| Carte du monde des découvertes | Fil et découverte | « vraiment bien mais long terme » |
| Assistant « Explique-moi » | Lecture | seulement si l'app marche bien, dans un abonnement payant 💶 |
| Modèle économique (don, pubs, abonnement) | Faire vivre le projet | « à voir : don, pubs, abonnement, ou plusieurs » |
| Connexion avec un compte Google (facultative) | Faire vivre le projet | demandée le 20/10, utile pour la monétisation à long terme |

---

## Détail par catégorie

### 1. Lire une avancée
- **Fiabilité de l'étude** ★ — Badge sur la carte et le détail : « essai sur l'humain », « étude sur l'animal », « simulation / modèle », « annonce d'entreprise », « produit sorti ». L'agent évalue déjà la solidité des preuves pour la note : il suffit de l'enregistrer (nouvelle colonne) et de l'afficher. Coût quasi nul.
- **Glossaire au toucher** ★★ — Mots techniques soulignés dans le résumé, définition simple au toucher. Piste : l'agent renvoie 0 à 3 termes avec leur définition (même appel, quelques tokens en plus), stockés avec l'avancée ; traduits sur le téléphone comme le reste.
- **Assistant « Explique-moi »** ★★★ 💶 — Poser une question sur une avancée. Coût par utilisateur : réservé à une éventuelle formule payante, si l'app a du succès.

### 2. Fil et découverte
- **À la une** ★ — L'avancée la plus importante du jour (ou des dernières 48 h) en grande carte en haut du fil, avec une belle image libre bien choisie. Sans image libre : une version graphique soignée (pas d'image générée).
- **Résumé de la semaine** ★★ — Le dimanche, une page « Les 5 avancées de la semaine », et éventuellement une notification. Calculé à partir des notes existantes, sans appel supplémentaire à l'IA.
- **Frise chronologique** ★★ — « Cette année en sciences / en tech » : les avancées majeures mois par mois.
- **Fils liés** ★★★ — Relier une avancée à celles qui la précèdent sur le même sujet (une mission spatiale, un traitement suivi sur des mois). Difficulté principale : ne rien rater. Piste : l'anti-doublons compare déjà les sujets récents, on pourrait réutiliser cette comparaison pour proposer « suite de » au lieu de « doublon ».
- **Carte du monde des découvertes** ★★★ — Où ont eu lieu les avancées (pays, laboratoires). L'agent devrait extraire le lieu.

### 3. Visuel
- **Plus de photos libres** ★★ (priorité, entamé le 19/10 : 14 sources à images libres) — Ajouter des sources d'images sous licence libre avec crédit exact (Wikimedia Commons, autres revues en accès libre, agences publiques). Vérifier chaque licence. Toujours aucune image générée.
- **Partager une avancée en image** ★★ (priorité) — Bouton « Partager » qui crée une jolie carte (titre, étoiles, famille, logo NovaSTEM, lien vers l'app) à envoyer sur les réseaux. Sert aussi de publicité.
- **Widget d'écran d'accueil** ★★ — L'avancée du jour sur le bureau du téléphone (Android, puis iPhone).
- **Animations douces** ★ — Apparition des cartes, étoiles qui se remplissent, transitions.

### 4. Apprendre et jouer
- **Quiz de la semaine** ★★ — 5 questions sur les avancées de la semaine, score gardé sur le téléphone. Questions générées une fois par semaine par l'agent (coût très faible).
- **Collection** ★★★ — Long terme : cartes à collectionner débloquées en lisant des avancées de chaque famille, façon jeu (thème « éléments du tableau périodique », clin d'œil au logo No 102).

### 5. Qualité de l'information
- **Plus de sources, complémentaires** ★★ (priorité, entamé le 19/10 : 55 sources + présélection) — Objectif : ne rater aucune avancée importante, en sciences comme en tech. Ajouter des sources francophones (CNRS, Inserm, CEA, Inrae, universités…) et des sources qui couvrent les angles morts actuels. Vérifier pour chacune que l'accès automatique est autorisé. Attention au budget : plus de sources ne veut pas dire plus d'articles par passage, l'agent garde 5 articles mais choisit dans un plus grand panier.

### 6. Plateformes
- **iPhone et tablette** ★★ — Déjà prévu en phase 9 (Codemagic, compte Apple). Mise en page adaptée aux grands écrans pour les tablettes.
- **PC** ★★ — La version web existe déjà ; Flutter peut aussi produire une app Windows/Mac si besoin.

- **Notifications la nuit hors d'Europe** ★★ — L'agent tourne à 8 h 20 et 18 h 20 heure de Paris : au Québec ou au Japon, une arrivée tombe en pleine nuit. Piste : garder la notification sur le téléphone jusqu'au matin (heure locale). L'écran Notifications affiche déjà les heures converties dans le fuseau du téléphone (21/10).

### 7. Faire vivre le projet
- **Statistiques sans pister** ★★ (priorité) — Compteurs anonymes : ouvertures de l'app, avancées lues, partages, langues, réglages de notifications les plus choisis. Aucune donnée personnelle, aucun identifiant publicitaire. À annoncer dans la politique de confidentialité. Piste : un simple compteur dans Supabase, ou Firebase Analytics avec les options de confidentialité.
- **Modèle économique** — Plan retenu par Maxime le 23/10 (maquettes 44-45) :
  1. **Pas de pub pendant le test fermé ni au tout début** (notes et bouche-à-oreille d'abord) ; ne plus promettre « sans pub » (retiré de la fiche Google Play le 23/10).
  2. **Pubs natives dans le fil** (une annonce bien signalée toutes les ~8 cartes, style des cartes) vers **~1 000 utilisateurs réguliers**, avec l'option **« Retirer les annonces » (achat unique, ~3,99 €, montant à fixer)**. Bloquer les catégories jeux d'argent, rencontres, politique, santé « miracle ». Consentement RGPD (UMP d'AdMob), « Contient des annonces » et Sécurité des données dans Play Console, politique de confidentialité, statut micro-entreprise.
  3. Piste « membres fondateurs » : version sans pub offerte à ceux qui avaient l'app avant l'arrivée des pubs.
  4. **Plus tard : abonnement** avec de vrais services en plus (archives, audio, recherche, « Explique-moi »…), qui inclut l'absence de pub. Les acheteurs de « Retirer les annonces » gardent ce droit à vie.
  - Pas besoin de compte NovaSTEM pour retrouver l'achat sur un autre téléphone Android : il est lié au compte Google (bouton « Restaurer mes achats »). Un compte ne servira que pour Android ↔ iPhone ↔ web, ou pour synchroniser favoris et réglages.
  - Ordres de grandeur (prudents) : ≈ 0,12 € par utilisateur régulier et par mois avec les pubs (≈ 120 €/mois pour 1 000 utilisateurs réguliers).
- **Connexion avec un compte Google (facultative)** ★★★ — Idée de Maxime (20/10). Rester utilisable **sans compte** ; la connexion servirait à retrouver favoris et réglages sur un autre téléphone, et à partager un abonnement entre Android, iPhone et web. Piste : Supabase Auth avec « Se connecter avec Google » (et « Se connecter avec Apple », exigé par Apple si une connexion Google est proposée sur iPhone). Un abonnement Google Play n'a pas besoin de compte dans l'app. À faire en même temps que la monétisation. Impose de mettre à jour : Play Console « Accès à l'application » (expliquer aux examinateurs comment se connecter), « Sécurité des données » (e-mail, identifiant), politique de confidentialité, et une option « Supprimer mon compte » dans l'app (obligatoire pour Google et Apple).

---

## Ordre proposé après la publication
1. Plus de sources + plus de photos libres (meilleur contenu)
2. Statistiques sans pister (savoir ce qui marche)
3. Partager en image (faire connaître l'app)
4. Badge de fiabilité + À la une
5. Glossaire, résumé de la semaine, quiz, widget, animations, frise
6. Long terme : fils liés, carte du monde, collection, iPhone/tablette/PC, modèle économique
