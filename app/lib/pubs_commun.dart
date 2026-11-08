// Partie commune (web et téléphone) des publicités.

import 'package:flutter/foundation.dart';

import 'etat.dart';

/// Identifiants des emplacements AdMob, injectés à la compilation (secrets GitHub).
const String idPubAccueil = String.fromEnvironment('ADMOB_ACCUEIL');
const String idPubListe = String.fromEnvironment('ADMOB_LISTE');
const String idPubBandeau = String.fromEnvironment('ADMOB_BANDEAU');

/// Les pubs sont-elles branchées dans cette compilation ?
const bool pubsConfigurees = idPubAccueil != '' && idPubListe != '' && idPubBandeau != '';

/// Identifiant de l'achat « Retirer les annonces » dans la Play Console
/// (Monétiser → Produits → Produits intégrés). Doit être EXACTEMENT celui-ci.
const String idProduitSansPub = 'retirer_annonces';

/// Vrai quand AdMob est prêt (consentement RGPD demandé, SDK démarré).
final ValueNotifier<bool> pubsPretes = ValueNotifier(false);

/// Vrai pendant l'écran de chargement du démarrage (le temps de précharger les pubs
/// des 2 accueils, 3 secondes au plus après le démarrage d'AdMob, 6 au total).
final ValueNotifier<bool> ecranChargementPubs = ValueNotifier(false);

/// Pubs à afficher maintenant sur ce téléphone ?
bool get pubsAffichees => !kIsWeb && pubsConfigurees && pubsPretes.value && etat.pubsVoulues;

/// Une annonce toutes les [pubToutesLes] avancées dans les listes, jamais en 1re position.
const int pubToutesLes = 8;

/// Nombre d'éléments d'une liste de [n] avancées, annonces comprises.
int nbAvecPubs(int n) => pubsAffichees ? n + n ~/ pubToutesLes : n;

/// L'élément n° [i] de la liste est-il une annonce ?
bool estPub(int i) => pubsAffichees && (i + 1) % (pubToutesLes + 1) == 0;

/// Numéro de l'avancée affichée à la position [i] (annonces sautées).
int indexAvancee(int i) => pubsAffichees ? i - (i + 1) ~/ (pubToutesLes + 1) : i;
