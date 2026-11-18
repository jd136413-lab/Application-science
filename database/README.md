# database/ — la base Supabase

Tous ces fichiers se lancent **à la main**, une seule fois, dans Supabase :
SQL Editor → New query → New blank query → coller → Run.
Ils sont tous déjà passés sur la base actuelle (projet `seqpmcovknfgppdolhns`).
Une nouvelle migration prend le numéro suivant (prochaine : **022**).

| Fichier | Date | Ce qu'il fait |
|---|---|---|
| `schema.sql` | 18/10 | Création de la base : table `advances`, index, lecture publique |
| `migration_002_tech_photos.sql` | 18/10 | Fil Technologies, photos libres |
| `migration_003_stats.sql` | 21/10 | Statistiques anonymes |
| `migration_004_nouveau_bareme.sql` | 21/10 | Nouveau barème d'importance |
| `migration_004_stats_v2.sql` | 22/10 | Statistiques, version 2 |
| `migration_005_resume.sql` | 21/10 | Nouveau résumé en 3 parties |
| `migration_005_stats_reinitialiser.sql` | 22/10 | Bouton « Réinitialiser les statistiques » |
| `migration_006_traductions_langues.sql` | 31/10 | Traductions des fiches faites par l'agent |
| `migration_007_familles_elargies.sql` | 31/10 | Familles élargies, plusieurs sources par avancée |
| `migration_008_stats_jour_par_jour.sql` | 01/11 | Statistiques jour par jour |
| `migration_009_a_venir.sql` | 01/11 | Onglet « À venir » |
| `migration_011_a_venir_pratique.sql` | 02/11 | « À venir » : infos pratiques |
| `migration_012_a_venir_sources.sql` | 03/11 | « À venir » : plusieurs sources |
| `migration_013_videos.sql` | 08/11 | Vidéo à l'appui d'une fiche ou d'un événement |
| `migration_014_stats_sans_robots.sql` | 09/11 | Statistiques sans les robots de Google |
| `migration_015_a_venir_traductions.sql` | 10/11 | Traductions des événements « À venir » |
| `migration_016_a_venir_refus.sql` | 10/11 | Mémoire des cartes « À venir » retirées |
| `migration_017_stats_robots_24h.sql` | 10/11 | Robots exclus pour toutes les versions |
| `migration_018_soumissions.sql` | 17/11 | Onglet Soumettre, boîte à idées |
| `migration_019_soumissions_limites.sql` | 17/11 | Limite par semaine, détail d'une proposition |
| `migration_020_soumissions_liens.sql` | 18/11 | Jusqu'à 5 liens par proposition |
| `migration_021_admin_suppression.sql` | 18/11 | Suppression d'une fiche par l'administrateur |
| `reset.sql` | — | ⚠️ **Remise à zéro irréversible** (phase de test seulement) : ne pas lancer |

Il n'y a pas de 010 (numéro sauté), et deux 004 / deux 005 (créées le même jour) : c'est normal.
