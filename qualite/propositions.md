# Propositions

## Corrections majeures à demander à Maxime

> 26/11, réponses de Maxime : statut « Lancé » → OUI (agent prêt, migration 026 à lancer par Maxime, app après validation de la maquette 113) ; budget → 8 résumés À venir par passage (fait) ;
> premières de vols habités → seulement les records MONDIAUX (fait, sujet clos) ; deux cartes → corrigées ;
> images des communiqués → acceptées si cohérentes (fait).

- **Cartes de lancement parties sans « C'est arrivé »** : une carte ne devient « C'est arrivé » que si une
  fiche est publiée. Shenzhou-24 (25/11) est partie, mais aucune fiche n'a suivi (l'article sur l'astronaute pakistanais
  a été jugé « none », c'est une visite) : la carte reste affichée « prévue », au futur, pendant 7 jours. Proposition :
  quand la fiche du lancement (Launch Library) dit « Success », marquer la carte « Lancé » (statut nouveau, donc
  modification de l'app) avec une phrase courte. Coût : nul (pas d'appel à Claude).

- **Budget du mois au-dessus de la cible** : 2,57 $ dépensés le 26/11 pour 2,30 $ visés sur le mois
  (≈ 0,075 $ par passage, 2 passages par jour : ≈ 3,2 $ attendus fin novembre, sous l'arrêt de sécurité de 3,50 $).
  Rien d'anormal par passage. À décider par Maxime : relever la cible à ≈ 3 $, ou réduire les résumés À venir
  (15 par passage, ≈ 0,022 $, soit 30 % du coût) maintenant que le rattrapage des anciennes cartes est presque fini
  (3 cartes futures sans résumé).

- **CLOS (27/11, Maxime : « je préfère la diversité »)** — **Le plafond par famille préfère un 1★ à un 2★** : le 27/11 matin, 5 articles à 2★ (implants cérébraux
  dans Nature Medicine, lacs sous la mer Rouge, jet de trou noir vu par l'EHT, disque de roche vaporisée, maladie du sang)
  ont été écartés car leur famille était au plafond, et 2 articles à 1★ (micropuce UV, orques) ont été publiés. Idée :
  laisser un 2★ dépasser le plafond quand le seul autre candidat est à 1★ (aujourd'hui l'exception commence à 3★).
  Modifie la sélection (équilibre des domaines) : à décider par Maxime. Coût : nul.

- **Secret `SUIVI_TOKEN` à ajouter (toujours absent le 28/11 matin)  — action de Maxime, 2 min, gratuit** : le journal du 27/11 soir dit
  « secret SUIVI_TOKEN absent, aucune copie privée ». Sans lui, les textes sources et les lectures ne sont pas copiés
  dans `novastem-suivi`, et l'exactitude des fiches ne peut pas être vérifiée sur la source (pages bloquées ici).
  À faire : créer un jeton GitHub (accès en écriture au seul repo `novastem-suivi`), puis l'ajouter dans
  Settings → Secrets and variables → Actions → New repository secret, nom exact `SUIVI_TOKEN`.

## Idées d'amélioration de l'application (justifiées par les données)

- **nouveau** — **Missions spatiales scientifiques classées en Technologies** : le 28/11 matin, BepiColombo (sonde
  scientifique ESA-JAXA, 3★) a été publiée dans le fil Technologies (« satellites ») alors que la famille Espace était au
  plafond en Sciences. Ce n'est pas faux (fil « aérospatial »), mais l'utilisateur qui suit l'Espace ne la verra pas
  dans Sciences. Idée : dans l'app, montrer aussi les fiches « satellites / aerospace » du fil Technologies dans le
  filtre Espace (modification de l'app : à décider par Maxime). 1 seul cas : à surveiller.

- **nouveau** — **Chiffre répété entre l'encadré « En chiffres » et le texte** (6 passages de suite : 29 %, 4 îles,
  3 synchrotrons, 21 novembre ce matin) : le relecteur est déjà alerté mais corrige rarement. Une correction
  « programme » possible serait de retirer de l'encadré une ligne dont la valeur est déjà dans le chapô ; mais cela
  viderait souvent l'encadré, qui a fait gagner beaucoup de points depuis le 25/11. À discuter : on peut aussi accepter
  la répétition (l'encadré sert de résumé visuel) et ne plus la compter comme défaut.

- **Expliquer le jargon des fiches IA** : la fiche cyclones (27/11 soir) laisse « prédicteurs physiques »,
  « deep learning brut », « mécanisme d'attention » sans explication (Clarté 1/2). Le fil Technologies a déjà une
  liste « mots » vide sur cette fiche : l'app pourrait afficher les définitions au toucher si l'agent les remplit
  (idée à surveiller sur d'autres fiches IA avant d'agir).

- **Images** (mis à jour 28/11 matin : 1 sur 4, image du communiqué ESA/Webb, la première depuis 6 passages ; avant : 0 sur 2 le 27/11 soir, 5e passage de suite) : 0 fiche sur 4 avec photo le 25/11 au soir, 0 sur 4 le 26/11 au matin, 0 photo
  le 26/11 au soir (1 image tirée d'une vidéo ESA) (« pas de chose
  précise et nommée à montrer » pour chaque fiche). Récurrent : piste à étudier, par exemple accepter l'image fournie
  par l'organisme de recherche (communiqué, revue en accès libre) quand sa licence le permet, ou une illustration par
  famille dans l'app quand il n'y a pas d'image.
- **Premières de vols habités** (mis à jour 26/11 soir) : trois passages de suite sans fiche sur Shenzhou-24 / premier astronaute
  pakistanais (pré-noté 3★). La règle « événement → none » l'écarte. À discuter avec Maxime : faut-il une fiche
  Technologies (1 ou 2★) pour une « vraie première » de vol habité (nouveau pays, record de durée) ? Ce serait une
  phrase à remplacer dans l'exception « engins », pas une règle en plus. Ce soir, le sujet est pré-noté 4★ (3 sources) mais
  reste « en attente d'une version lisible » (article BBC de 680 caractères) : il risque de ne jamais passer.
- **Deux cartes à corriger** (Dream Chaser corrigée le 26/11 ; reste Ariane 64, passée) : la carte Ariane 64 (24/11, passée) annonce des « satellites Internet européens »
  alors que ce sont des satellites Amazon Leo (américains) ; la carte Dream Chaser dit l'Atlas V « retirée » (elle vole
  encore). Correction ponctuelle des deux textes en base (petite tâche de `corriger_cartes.py`, sans appel payant).
- **Intertitre passe-partout** (absent le 27/11 matin) : 2 fiches sur 4 ce soir affichent « Comment le sait-on ? » (le rédacteur
  n'a pas écrit de question). Si cela revient, le programme pourrait retirer le bloc ou reprendre la question du profil
  adaptée au sujet ; à surveiller avant d'agir (1 seul passage).
- **FAIT (27/11)** — Carte Terran R corrigée en base (3 remplacements, toujours en place le 27/11 soir).
- **Ligne « En pratique » pour les directs** : la carte Gaia DR4 vient d'une page ESA « Watch live », mais
  n'a aucune ligne « En pratique » (où et à quelle heure regarder). À surveiller sur d'autres cartes avant d'agir.
