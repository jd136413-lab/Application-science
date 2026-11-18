# app/ — l'application NovaSTEM (Flutter)

Un seul code pour Android, iPhone et le web. Compilée dans le cloud par le workflow
« Compiler l'app » (Flutter 3.47.9). Aucun compte utilisateur : tout ce qui est personnel
(favoris, langue, thème, domaines) reste sur le téléphone.

👉 **Pour changer l'apparence** (couleurs, polices, familles, textes) : `lib/reglages.dart`.

## Les fichiers de `lib/`, par rôle

**Démarrage et structure**
- `main.dart` — point d'entrée (Supabase, Firebase, pubs préchargées).
- `coquille.dart` — les onglets et la barre du bas.
- `chargement_pubs.dart` — écran de chargement du démarrage.
- `presentation.dart`, `premier_lancement.dart`, `echelle_importance.dart` — premier lancement.
- `navigation.dart` — ouvrir le bon écran depuis une notification.

**Écrans**
- `accueil_magazine.dart` + `fils.dart` — l'accueil actuel (Sciences / Technologies).
- `accueil.dart` — l'ancien fil, toujours proposé dans Réglages → Présentation de l'accueil.
- `carte.dart`, `detail.dart` — carte d'une avancée et son écran de détail.
- `a_venir.dart` — onglet « À venir ».
- `vocabulaire.dart` — onglet Vocabulaire.
- `favoris.dart` — favoris (lisibles hors ligne).
- `ecran_reglages.dart`, `ecran_notifications.dart` — Réglages.
- `soumettre.dart`, `boite_idees.dart`, `admin_suppression.dart` — mode administrateur
  (onglet Soumettre, boîte à idées, suppression d'une fiche).

**Données et mémoire**
- `modele.dart` — une avancée telle qu'elle est dans la base.
- `donnees.dart` — lecture des avancées dans Supabase.
- `propositions.dart` — propositions des lecteurs (Soumettre).
- `etat.dart` — réglages gardés sur le téléphone.
- `memoire.dart` — fil gardé hors ligne, images en cache.
- `retours.dart` — « Signaler une erreur ».
- `stats.dart` — statistiques anonymes.

**Langues**
- `langues.dart`, `texte_article.dart` — langue de l'app et du contenu.
- `textes_traduits.dart` — ⚠️ fichier généré par `traductions/generer.py` à partir de
  `traductions/interface.txt` : ne pas le modifier à la main.
- `pays_noms.dart`, `regions_monde.dart` — noms de pays et régions (générés).
- `traducteur*.dart` — traduction hors ligne sur le téléphone (ML Kit).

**Notifications et publicités**
- `notifications*.dart`, `proposition_notifs.dart` — notifications (Firebase).
- `pubs*.dart` — AdMob et achat « Retirer les annonces ».

**Petits éléments partagés** : `widgets.dart`, `reglages.dart`.

> Les fichiers `…_mobile.dart` / `…_web.dart` sont deux versions d'une même fonction :
> l'app choisit automatiquement la bonne selon qu'elle tourne sur téléphone ou sur le web.

## Autres dossiers

- `assets/icone/` — icône et écran de démarrage (garder exactement les mêmes noms de fichiers).
- `web_extra/` — pages ajoutées au site web : statistiques, confidentialité (FR/EN), contact, partage d'une avancée.
- `traductions/` — textes de l'interface dans les 20 langues et leur générateur.
