# agent/ — l'agent de collecte (Python)

Lancé par le workflow « Agent de collecte » (8 h 20 et 18 h 20, via cron-job.org).
Chaque passage : lit les flux RSS, écarte les doublons, fait rédiger et noter les fiches
par Claude, les traduit, cherche une vidéo, met à jour « À venir », envoie les notifications.

👉 **Le seul interrupteur de dépense** : `economie.py`.
👉 **Ajouter ou retirer une source** : `sources.py`.

## Le passage de l'agent (production)

| Fichier | Rôle |
|---|---|
| `main.py` | Chef d'orchestre : lance tout le passage, dans l'ordre |
| `sources.py` | Liste des flux RSS et titres exclus |
| `doublons.py` | Anti-doublons gratuit (avant tout appel à Claude) |
| `prompt.py` + `classification.md` | Consignes de tri données à Claude (qu'est-ce qu'une avancée ?) |
| `consignes_v3.py` | Consigne de tri retenue (`TRI_C`) |
| `redaction.py` | Rédaction des fiches (utilise `consignes_v2.py` et `consignes_v4.py`) |
| `titres.py` | Relecture des titres (+ `titres_a_forcer.txt`) |
| `traduction.py`, `traduction_a_venir.py` | Traductions des fiches et des événements |
| `videos.py` | Vidéos officielles à l'appui d'une fiche |
| `a_venir.py` + `calendrier_a_venir.json` | Onglet « À venir » (événements connus à l'avance) |
| `notifications.py` | Envoi des notifications (Firebase) |
| `bilan_sources.py` → `bilan_sources.md` | Bilan des sources, mis à jour à chaque passage |
| `economie.py` | Interrupteur unique pour tous les appels à Claude |
| `requirements.txt` | Bibliothèques Python à installer |

> ⚠️ Les noms `consignes_v2/v3/v4` viennent des essais de novembre : malgré leur nom,
> ils sont **tous utilisés**. Ne pas les supprimer.

## Les autres programmes (lancés à part)

| Fichier | Workflow | Rôle |
|---|---|---|
| `soumissions.py` | Soumissions | Propositions des lecteurs (onglet Soumettre) |
| `propositions_notif.py` | Propositions : notification | Prévient le téléphone administrateur |
| `controle_semaine.py` | Contrôle de la semaine | Les grands sujets de la semaine sont-ils là ? |
| `video_semaine.py` + `videos_faites.json` | Vidéo de la semaine | Vidéo verticale de la semaine |
| `test_lecture.py` | Vérifier le code | Test gratuit de la lecture des articles |
| `tester_agent.py`, `tester_leviers.py`, `tester_redaction.py` | Essais (anciens) | Essais de consignes, sans rien publier |

## Rapports (écrits par les workflows, à lire seulement)

`bilan_sources.md`, `bilan_qualite_15j.md`, `strategie_sources.md`, `verif_sources.md`,
`decouverte_*.md/.json`, `essai_ab_consignes.md`, `tests_redaction.md`,
`titres_corriges.md`, `titres_forces.md`, `titres_reecrits.md`.
