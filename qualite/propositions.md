# Propositions

## Corrections majeures à demander à Maxime

- **Cartes de lancement parties sans « C'est arrivé »** : une carte ne devient « C'est arrivé » que si une
  fiche est publiée. Shenzhou-24 (25/11) est partie, mais aucune fiche n'a suivi (l'article sur l'astronaute pakistanais
  a été jugé « none », c'est une visite) : la carte reste affichée « prévue », au futur, pendant 7 jours. Proposition :
  quand la fiche du lancement (Launch Library) dit « Success », marquer la carte « Lancé » (statut nouveau, donc
  modification de l'app) avec une phrase courte. Coût : nul (pas d'appel à Claude).

- **nouveau** — **Budget du mois au-dessus de la cible** : 2,57 $ dépensés le 26/11 pour 2,30 $ visés sur le mois
  (≈ 0,075 $ par passage, 2 passages par jour : ≈ 3,2 $ attendus fin novembre, sous l'arrêt de sécurité de 3,50 $).
  Rien d'anormal par passage. À décider par Maxime : relever la cible à ≈ 3 $, ou réduire les résumés À venir
  (15 par passage, ≈ 0,022 $, soit 30 % du coût) maintenant que le rattrapage des anciennes cartes est presque fini
  (3 cartes futures sans résumé).

## Idées d'amélioration de l'application (justifiées par les données)

- **Images** (mis à jour 26/11 soir) : 0 fiche sur 4 avec photo le 25/11 au soir, 0 sur 4 le 26/11 au matin, 0 photo
  le 26/11 au soir (1 image tirée d'une vidéo ESA) (« pas de chose
  précise et nommée à montrer » pour chaque fiche). Récurrent : piste à étudier, par exemple accepter l'image fournie
  par l'organisme de recherche (communiqué, revue en accès libre) quand sa licence le permet, ou une illustration par
  famille dans l'app quand il n'y a pas d'image.
- **Premières de vols habités** (mis à jour 26/11 soir) : trois passages de suite sans fiche sur Shenzhou-24 / premier astronaute
  pakistanais (pré-noté 3★). La règle « événement → none » l'écarte. À discuter avec Maxime : faut-il une fiche
  Technologies (1 ou 2★) pour une « vraie première » de vol habité (nouveau pays, record de durée) ? Ce serait une
  phrase à remplacer dans l'exception « engins », pas une règle en plus. Ce soir, le sujet est pré-noté 4★ (3 sources) mais
  reste « en attente d'une version lisible » (article BBC de 680 caractères) : il risque de ne jamais passer.
- **nouveau** — **Deux cartes à corriger** : la carte Ariane 64 (24/11, passée) annonce des « satellites Internet européens »
  alors que ce sont des satellites Amazon Leo (américains) ; la carte Dream Chaser dit l'Atlas V « retirée » (elle vole
  encore). Correction ponctuelle des deux textes en base (petite tâche de `corriger_cartes.py`, sans appel payant).
- **nouveau** — **Intertitre passe-partout** : 2 fiches sur 4 ce soir affichent « Comment le sait-on ? » (le rédacteur
  n'a pas écrit de question). Si cela revient, le programme pourrait retirer le bloc ou reprendre la question du profil
  adaptée au sujet ; à surveiller avant d'agir (1 seul passage).
