// Traduction des articles (titres et résumés) sur le téléphone.
//
// Sur Android et iPhone : traduction hors ligne par Google ML Kit
// (traducteur_mobile.dart). Sur la version web, ML Kit n'existe pas : les
// articles restent en français (traducteur_web.dart).
export 'traducteur_web.dart' if (dart.library.io) 'traducteur_mobile.dart';
