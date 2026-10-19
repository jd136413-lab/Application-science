# Novum — feuille de route (idées retenues par Maxime, 19/10/2026)

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
- **Plus de photos libres** ★★ (priorité) — Ajouter des sources d'images sous licence libre avec crédit exact (Wikimedia Commons, autres revues en accès libre, agences publiques). Vérifier chaque licence. Toujours aucune image générée.
- **Partager une avancée en image** ★★ (priorité) — Bouton « Partager » qui crée une jolie carte (titre, étoiles, famille, logo Novum, lien vers l'app) à envoyer sur les réseaux. Sert aussi de publicité.
- **Widget d'écran d'accueil** ★★ — L'avancée du jour sur le bureau du téléphone (Android, puis iPhone).
- **Animations douces** ★ — Apparition des cartes, étoiles qui se remplissent, transitions.

### 4. Apprendre et jouer
- **Quiz de la semaine** ★★ — 5 questions sur les avancées de la semaine, score gardé sur le téléphone. Questions générées une fois par semaine par l'agent (coût très faible).
- **Collection** ★★★ — Long terme : cartes à collectionner débloquées en lisant des avancées de chaque famille, façon jeu (thème « éléments du tableau périodique », clin d'œil au logo No 102).

### 5. Qualité de l'information
- **Plus de sources, complémentaires** ★★ (priorité) — Objectif : ne rater aucune avancée importante, en sciences comme en tech. Ajouter des sources francophones (CNRS, Inserm, CEA, Inrae, universités…) et des sources qui couvrent les angles morts actuels. Vérifier pour chacune que l'accès automatique est autorisé. Attention au budget : plus de sources ne veut pas dire plus d'articles par passage, l'agent garde 5 articles mais choisit dans un plus grand panier.

### 6. Plateformes
- **iPhone et tablette** ★★ — Déjà prévu en phase 9 (Codemagic, compte Apple). Mise en page adaptée aux grands écrans pour les tablettes.
- **PC** ★★ — La version web existe déjà ; Flutter peut aussi produire une app Windows/Mac si besoin.

### 7. Faire vivre le projet
- **Statistiques sans pister** ★★ (priorité) — Compteurs anonymes : ouvertures de l'app, avancées lues, partages, langues, réglages de notifications les plus choisis. Aucune donnée personnelle, aucun identifiant publicitaire. À annoncer dans la politique de confidentialité. Piste : un simple compteur dans Supabase, ou Firebase Analytics avec les options de confidentialité.
- **Modèle économique** — À décider plus tard : don volontaire, publicité, abonnement (par exemple avec « Explique-moi »), ou une combinaison. Des pubs imposeraient de mettre à jour la politique de confidentialité et les déclarations Google Play.

---

## Ordre proposé après la publication
1. Plus de sources + plus de photos libres (meilleur contenu)
2. Statistiques sans pister (savoir ce qui marche)
3. Partager en image (faire connaître l'app)
4. Badge de fiabilité + À la une
5. Glossaire, résumé de la semaine, quiz, widget, animations, frise
6. Long terme : fils liés, carte du monde, collection, iPhone/tablette/PC, modèle économique
