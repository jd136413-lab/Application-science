// Version web : pas de notifications (elles n'existent que dans l'app mobile).

const bool notificationsPossibles = false;

Future<void> initialiserNotifications() async {}

Future<bool> demanderAvis() async => false;

Future<bool> demanderAutorisation() async => false;

Future<void> synchroniserSujets(Set<String> voulus) async {}

Future<bool> programmerRappel({
  required int id,
  required DateTime quandUtc,
  required String titre,
  required String texte,
  required String payload,
}) async =>
    false;

Future<void> annulerRappel(int id) async {}
