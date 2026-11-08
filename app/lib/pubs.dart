// Publicités et achat « Retirer les annonces » (07/11/2026, scénario D, planche 80).
// Compilation demandée par Maxime le 08/11/2026 (vidéos).
//
// Sur Android : Google AdMob + achat intégré Google Play (pubs_mobile.dart).
// Sur la version web : rien (pubs_web.dart).
//
// Tant que les identifiants AdMob ne sont pas dans les secrets GitHub
// (ADMOB_APP_ID, ADMOB_ACCUEIL, ADMOB_LISTE, ADMOB_BANDEAU), aucune pub n'apparaît.
export 'pubs_commun.dart';
export 'pubs_web.dart' if (dart.library.io) 'pubs_mobile.dart';
