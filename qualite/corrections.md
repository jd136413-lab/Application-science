# Corrections appliquées (et leur effet)

## 25/11/2026 (faites à la main avec Maxime, avant le suivi automatique)

| Défaut visé | Correction | Effet mesuré |
|---|---|---|
| Notes d'équipe affichées (« à vérifier avant publication ») | Filtre programme `NOTE_REDACTEUR` + règle courte dans les consignes | 26/11 matin : aucune (+) |
| Limites sur une étape passée | Filtre `date_passee` + règle courte | à mesurer |
| Résumés écrits pour des événements déjà passés | Plus de résumé si la date est passée ou si le lancement est parti | à mesurer |
| « En chiffres » absent (1 fiche sur 4) | Alerte au relecteur si les sources ont ≥ 4 chiffres + consigne « 2 à 4 lignes dès que… » | 26/11 matin : 4 fiches sur 4, critère 0,25 → 0,875 (+) |
| Unités anglo-saxonnes, mois sans année | Alerte au relecteur `UNITES_US` + règle UNITÉS | à mesurer |
| Fiche vide renvoyée par le tri (Shenzhou-24 perdu) | Un nouvel essai | pas de fiche vide ce matin (=) |
| Répétitions « En pratique » / « En bref » (À venir) | Le rédacteur réécrit « En pratique » (0 à 3 lignes utiles) | à mesurer |

## 26/11/2026 · matin (suivi automatique)

| Défaut visé | Correction | Effet mesuré |
|---|---|---|
| Fusée dite « en développement » alors qu'elle a déjà volé (Longue Marche 12 le 25/11, Ariane 6 le 26/11) | `a_venir_blocs.py` : la fiche du lancement donne au rédacteur le nombre de vols de la fusée ; si le texte dit « en développement » alors qu'elle a volé, alerte au relecteur. Aucune ligne ajoutée aux consignes. | 26/11 soir : pas encore mesurable (la carte Longue Marche 12 n'a pas été réécrite) |

## 26/11/2026 · soir (suivi automatique)

| Défaut visé | Correction | Effet mesuré |
|---|---|---|
| Limite passe-partout ajoutée par le programme alors que la fiche a déjà de vraies limites (planeur 25/11, scanner IA 26/11 matin, main bionique et rein de porc 26/11 soir) | `fiche_blocs.py` (`pour_la_base`) : avec 2 vraies limites ou plus, plus de phrase « cause ou lien » ni « durée de vie / commercialisation » en plus. Les phrases « effets indésirables », « nombre de personnes », « disponibilité » restent. | 27/11 matin : fiche Lune à 2 limites sans phrase ajoutée (+) ; la phrase reste sur les fiches à 1 limite (corrigé ce jour) |
| Même information dans le chapô et un paragraphe des cartes À venir (Gravity-2, Jupiter, Bourget, KAIROS…) | `a_venir_blocs.py` (`_nettoyer`) : alerte « répétition » au relecteur quand deux textes de la carte partagent 6 mots de suite (même test que pour les fiches). Essai sur les 38 cartes en base : 6 signalées, toutes à raison. Aucune ligne ajoutée aux consignes. | 27/11 matin : 0 répétition de 6 mots dans les 4 cartes réécrites (Économie cartes 0,56, à confirmer) |

## 27/11/2026 · matin (suivi automatique)

| Défaut visé | Correction | Effet mesuré |
|---|---|---|
| Limite « Ni durée de vie ni date de commercialisation » ajoutée alors qu'elle fait double emploi (micropuce UV : « aucun produit n'est annoncé » ; BN-800 : paragraphe « à quoi servirait » déjà écrit) — 4 passages sur 4 | `fiche_blocs.py` (`pour_la_base`) : pas de phrase « non précisé » si la fiche a déjà le paragraphe correspondant, ni de phrase « commercialisation » si une limite parle déjà de produit, de commercialisation ou de durée de vie. Aucune ligne de consigne. | à mesurer (critère Limites) |

## 27/11/2026 (demande de Maxime : corrections de texte en autonomie)

| Défaut visé | Correction | Effet mesuré |
|---|---|---|
| Carte Terran R : « entièrement réutilisable », « imprimée en 3D » (dépassé) | 3 remplacements de texte en base via `corrections_texte.json` | appliqué (3/3) |
