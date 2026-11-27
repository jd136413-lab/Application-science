# Suivi qualité des fiches NovaSTEM — protocole

Demandé par Maxime le 25/11/2026. Lancé automatiquement par une tâche programmée après chaque
passage de l'agent (8h20 et 18h20, heure de Paris). **Aucun coût API** : c'est Claude, dans la tâche
programmée, qui lit et note les fiches. Aucun workflow payant n'est lancé.

## 1. Récupérer le passage

1. Le dernier run du workflow « agent » : `gh run list -R jd136413-lab/Application-science --workflow agent.yml --limit 1`.
   S'il tourne encore, attendre (jusqu'à 30 min). S'il n'existe pas ou a échoué : le noter dans le journal et s'arrêter.
2. Le journal : `gh run view <id> --log` → nombre de fiches, ignorées, erreurs, coût, alertes du relecteur.
3. Les fiches ajoutées par ce passage (lecture publique, clé publishable lue dans
   `https://jd136413-lab.github.io/Application-science/main.dart.js`, motif `sb_publishable_…`) :
   `https://seqpmcovknfgppdolhns.supabase.co/rest/v1/advances?select=*&created_at=gte.<début du run>&order=created_at.asc`
4. Les cartes À venir réécrites ou créées : `upcoming_events?select=*&updated_at=gte.<début du run>` (si la colonne
   n'existe pas : `blocs=neq.[]&event_date=gte.<aujourd'hui>`).
5. Textes sources et lectures (depuis le 27/11) : repo PRIVÉ `jd136413-lab/novastem-suivi`, dossier
   `passages/<date>-<heure>-<run>/` : `sources/<id>.json` (`titre`, `source_url`, `texte` lu par l'agent) = référence pour
   « Exactitude » ; `lectures.json` = lectures, articles ouverts, favoris, partages, masquages par fiche sur 7 jours
   (anonyme). Lecture : `gh api repos/jd136413-lab/novastem-suivi/contents/passages` puis `.../contents/<chemin>`
   (champ `content` en base64). Ne JAMAIS recopier ces textes dans le repo public. WebFetch sur `source_url`
   seulement si le fichier manque. Les lectures servent aux idées pour l'app (ce qui intéresse vraiment les lecteurs),
   pas à la note de rédaction.

## 1 bis. Décisions de Maxime à respecter (ne pas reproposer)

- 26/11 : « première » et « record » s'entendent au sens MONDIAL. Une première seulement nationale (premier astronaute
  ou premier lancement d'un pays, nouvelle nationalité) n'est pas une avancée : son absence n'est PAS un sujet manqué.
- 26/11 : images des communiqués (universités, instituts, entreprises : `sources.COMMUNIQUES`) acceptées si la
  vérification visuelle confirme qu'elles montrent le sujet. Suivre : part de fiches avec image, et toute image hors
  sujet (défaut grave : prévenir Maxime).
- 26/11 : 8 résumés À venir par passage (budget).
- 27/11 : la diversité des domaines prime : NE PAS laisser un 2★ dépasser le plafond de sa famille (sujet clos).
- 27/11 : corrections de TEXTE autorisées en autonomie (fiches et cartes déjà publiées, erreur de fond ou de
  formulation) : ajouter une entrée à `qualite/corrections_texte.json` (`table`, `avant` = texte exact, `apres`,
  `raison`, `fait`: false), pousser sur main avec [skip ci], lancer le workflow gratuit
  `gh workflow run corriger-cartes.yml -R jd136413-lab/Application-science --ref main -f refaire=non`, lire son
  journal et passer `fait` à true pour les corrections appliquées. Les noter dans corrections.md.

## 2. Noter (même grille à chaque fois, pour pouvoir comparer)

Chaque fiche reçoit une note sur 10 = somme des critères :

| Critère | Points | Ce qu'on regarde |
|---|---|---|
| Exactitude | 3 | Tout est conforme à la source ; aucune erreur de chiffre, de nom, de date. Une erreur de fond = 0. |
| Clarté | 2 | Compris d'un coup par un non-spécialiste ; jargon expliqué ; phrases courtes. |
| Questions et angles | 1,5 | Questions propres au sujet, utiles, dans un ordre logique ; aucune question passe-partout. |
| Chiffres | 1 | « En chiffres » présent quand utile ; valeur + unité claire, description claire ; unités françaises. |
| Limites | 1 | Vraies inconnues propres à l'étude ; aucune note d'équipe, aucune étape passée, aucun avantage déguisé. |
| Économie | 1 | Pas de répétition, longueur justifiée. |
| Titre et ★ | 0,5 | Titre clair et non ambigu ; étoiles cohérentes avec le barème (la plupart à 2 ou 3). |

Cartes À venir : même grille, sauf « Exactitude » vérifiée sur la source de la carte et « Titre et ★ »
remplacé par « En pratique utile et sans répétition » (0,5).

Noter aussi, pour le passage entier : équilibre des domaines, part de fiches avec image, sujets majeurs
manqués (repérés dans le journal : ignorés à 3★ ou plus, erreurs), doublons, coût.

Écrire une ligne JSON par fiche dans `qualite/notes.jsonl` :
`{"date","passage":"matin|soir","type":"fiche|a_venir","titre","domaine","etoiles","note","detail":{critère:points},"defauts":[...],"version_agent":"<sha court de main>"}`

## 3. Tirer des conclusions

- Comparer avec les passages précédents (`notes.jsonl`) : moyenne glissante sur 6 passages, par critère.
- Un défaut compte comme **récurrent** s'il revient dans au moins 2 passages sur les 4 derniers.
- Après chaque correction, mesurer son effet sur les 4 passages suivants (critère visé et note globale),
  et l'écrire dans `corrections.md` (« effet : + / = / − »). Une correction qui fait baisser la note est annulée.

## 4. Corriger — l'équilibre avant tout

Principe de Maxime : **ni prompt trop long, ni barrières trop exigeantes**. Concrètement :
- Une règle mécanique (unité, mot interdit, longueur) se corrige **dans le programme** (filtre ou alerte au
  relecteur), pas en allongeant la consigne.
- Une consigne qui grossit doit maigrir ailleurs : la taille des consignes (`CONSIGNE`, `CONSIGNE_RELECTURE`
  de `redaction_blocs.py` et `a_venir_blocs.py`) est notée dans le journal à chaque passage ; **croissance
  nette ≤ 0** sur une semaine. Préférer reformuler ou remplacer une règle plutôt qu'en ajouter une.
- Un filtre qui supprime trop (ex. il retire de bonnes limites ou de bons paragraphes) est assoupli.
- Corriger un défaut récurrent, pas un cas isolé.

**Corrections mineures — appliquées en autonomie** (au plus 2 par passage) :
- reformuler, remplacer ou supprimer quelques lignes d'une consigne existante ;
- ajuster un filtre, un seuil, une liste de mots, une expression régulière ;
- corriger un bug dans le nettoyage des fiches ou des cartes (sans changer le format).

**Corrections majeures — jamais en autonomie, à proposer dans `propositions.md`** :
- changement de modèle, d'appel API, de nombre de fiches, de budget, tout ce qui coûte plus ;
- changement du format des fiches ou des cartes, migration de base, suppression de fiches ;
- toute modification de l'application (dossier `app/`) ;
- toute modification qui ajouterait plus de ~10 lignes nettes aux consignes.

Méthode pour une correction mineure : branche `verif/qualite-<date>`, commit **sans** [skip ci], attendre que
la vérification passe (« 2 issues found » est la référence), fusion en squash dans `main` avec [skip ci],
supprimer la branche (`gh api -X DELETE repos/jd136413-lab/Application-science/git/refs/heads/<branche>`).
Ne **jamais** compiler l'app, ne **jamais** lancer le workflow de l'agent, ne **jamais** lancer de workflow payant.

## 5. Écrire

- `qualite/journal.md` : une section par passage (date, run, chiffres, moyenne, meilleure et pire fiche,
  défauts, taille des consignes, ce qui a été fait).
- `qualite/corrections.md` : chaque correction appliquée (date, défaut visé, fichier, avant/après en une phrase,
  effet mesuré ensuite).
- `qualite/propositions.md` : corrections majeures à demander + idées d'amélioration de l'application (tout sujet :
  sources, équilibre des domaines, images, étoiles, À venir, accueil, notifications…), chacune avec la donnée
  qui la justifie. Mettre à jour (pas de doublon), marquer « nouveau » ce qui vient d'être ajouté.
- Commit des fichiers `qualite/` directement sur `main` avec [skip ci].

## 6. Prévenir Maxime

Seulement si une correction **majeure** devient nécessaire, ou si un défaut grave apparaît (erreur de fond
publiée, passage en échec, coût anormal) : un court message en français, simple. Sinon, rien : Maxime demande
le récapitulatif quand il veut.
