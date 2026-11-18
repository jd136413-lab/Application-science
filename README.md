# NovaSTEM (dépôt « Application science »)

> 📲 **App Android (dernière version de test)** : https://github.com/jd136413-lab/Application-science/releases/download/apercu/novum.apk
> 🛒 **Google Play** : `fr.novum.novum`
> 🌐 **Version web** : https://jd136413-lab.github.io/Application-science/
> 📊 **Statistiques** : https://jd136413-lab.github.io/Application-science/stats.html

Application mobile (Android, iOS plus tard) qui recense les avancées scientifiques et
technologiques du moment. Un agent IA les trouve, les résume en français, les note
et les traduit.

## Comment tout s'enchaîne

```
Flux RSS de sources fiables
        │
        ▼
agent/  (Python, GitHub Actions, 2 fois par jour)
  └─ Claude : titre, résumé, thème, note, traductions, vidéo, événements « À venir »
        │  clé secrète Supabase (écriture)
        ▼
Supabase (base Postgres) : advances, upcoming, stats, submissions…
        │  clé publique (lecture seule)
        ▼
app/  (Flutter) → APK de test, version web, Google Play
```

## Où trouver quoi

| Dossier | Contenu | Détails |
|---|---|---|
| `agent/` | L'agent de collecte et ses outils (Python) | [agent/README.md](agent/README.md) |
| `app/` | L'application Flutter | [app/README.md](app/README.md) |
| `database/` | Le schéma de la base et toutes les migrations, dans l'ordre | [database/README.md](database/README.md) |
| `design/` | Générateur de maquettes et images libres | — |
| `store/` | Textes, captures, bannière et polices des fiches Google Play et Product Hunt | [store/fiche-google-play.md](store/fiche-google-play.md) |
| `docs/` | Journal du projet et feuille de route | [docs/README.md](docs/README.md) |
| `.github/workflows/` | Les « boutons » de l'onglet Actions | tableau ci-dessous |

## Les workflows (onglet « Actions »)

**Automatiques**

| Workflow | Quand | Coût |
|---|---|---|
| Agent de collecte | 8 h 20 et 18 h 20 (déclenché par cron-job.org) | ≈ 0,01 $ par passage |
| Propositions : notification | toutes les heures | gratuit |
| Vérifier le code | à chaque envoi sur une branche `verif/…` | gratuit |

**À la main** (Actions → nom du workflow → « Run workflow »)

| Workflow | À quoi il sert | Coût |
|---|---|---|
| Compiler l'app | APK de test + version web ; case « Google Play » pour le test interne | gratuit |
| Envoyer une version sur Google Play | envoie un fichier déjà compilé | gratuit |
| Soumissions | traite les propositions des lecteurs (onglet Soumettre) | quelques centimes |
| Contrôle de la semaine | vérifie que les grands sujets de la semaine sont dans l'app | quelques centimes |
| Vidéo de la semaine | fabrique la vidéo verticale de la semaine | quelques centimes |
| Traduire les fiches | rattrape les traductions manquantes | quelques centimes |
| Réécrire les titres | relit et corrige des titres | quelques centimes |
| Tester les vidéos officielles | teste les chaînes YouTube officielles | gratuit |
| Découvrir des sources / Tester des sources | cherche et teste de nouveaux flux RSS | gratuit |
| Télécharger des images | images libres pour les maquettes | gratuit |
| Essai des consignes A/B · Essai des leviers · Tester la rédaction | anciens essais de consignes (novembre), sans rien publier | payant |

## Règles du projet

- Aucun secret dans le code : les clés sont dans **Settings → Secrets and variables → Actions**.
- Une modification de `app/` envoyée sur `main` lance la compilation : les envois de Claude
  portent `[skip ci]` tant que Maxime n'a pas dit « compile ».
- Avant d'être fusionné, le code passe par une branche `verif/…` (analyse gratuite).
