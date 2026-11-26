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
| Fusée dite « en développement » alors qu'elle a déjà volé (Longue Marche 12 le 25/11, Ariane 6 le 26/11) | `a_venir_blocs.py` : la fiche du lancement donne au rédacteur le nombre de vols de la fusée ; si le texte dit « en développement » alors qu'elle a volé, alerte au relecteur. Aucune ligne ajoutée aux consignes. | à mesurer sur les 4 prochains passages |
