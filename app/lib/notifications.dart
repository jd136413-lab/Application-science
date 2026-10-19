// Notifications des nouvelles avancées (Réglages → Notifications).
//
// Sur Android et iPhone : Firebase Cloud Messaging (notifications_mobile.dart).
// Sur la version web : pas de notifications (notifications_web.dart).
export 'notifications_web.dart' if (dart.library.io) 'notifications_mobile.dart';
