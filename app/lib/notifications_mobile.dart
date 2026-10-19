// Version Android / iPhone des notifications, avec Firebase Cloud Messaging.
//
// Fonctionnement :
// - Le téléphone s'abonne à des « sujets » selon Réglages → Notifications :
//   un sujet par famille et par niveau d'importance (ex. n_space_4).
// - Quand l'agent ajoute une avancée, il envoie un message sur le sujet
//   correspondant. Seuls les téléphones abonnés le reçoivent.
// - Le téléphone affiche lui-même la notification et applique la limite
//   choisie (« au plus 3 à chaque arrivée ») : au-delà, une seule
//   notification « + N autres avancées » regroupe les suivantes.
//
// Sans configuration Firebase à la compilation, tout est désactivé.

import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'langues.dart' show languesDisponibles;
import 'navigation.dart';
import 'reglages.dart';
import 'textes_traduits.dart';

/// Vrai si la compilation a reçu la configuration Firebase (secret GitHub).
const bool notificationsPossibles = bool.fromEnvironment('NOTIFICATIONS');

const String _canal = 'nouvelles_avancees';
const int _idRegroupement = 102;
final _local = FlutterLocalNotificationsPlugin();

// ------------------------------------------------------------------ démarrage

Future<void> initialiserNotifications() async {
  if (!notificationsPossibles) return;
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_messageEnArrierePlan);
    await _preparerAffichage(onTouche: (r) => _touche(r.payload));
    FirebaseMessaging.onMessage.listen((m) => _afficher(m.data));
    // App lancée en touchant une notification
    final lancement = await _local.getNotificationAppLaunchDetails();
    if (lancement?.didNotificationLaunchApp ?? false) {
      _touche(lancement!.notificationResponse?.payload);
    }
  } catch (_) {
    // Les notifications ne doivent jamais empêcher l'app de fonctionner.
  }
}

void _touche(String? contenu) {
  if (contenu == null || contenu.isEmpty) return;
  demandeOuverture.value = null; // pour qu'une 2e fois le même contenu soit vu
  demandeOuverture.value = contenu;
}

Future<void> _preparerAffichage({void Function(NotificationResponse)? onTouche}) async {
  await _local.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ),
    onDidReceiveNotificationResponse: onTouche,
  );
}

/// Demande l'autorisation d'afficher des notifications. Renvoie vrai si accordée.
Future<bool> demanderAutorisation() async {
  if (!notificationsPossibles) return false;
  try {
    final r = await FirebaseMessaging.instance.requestPermission();
    final android = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final ok = await android?.requestNotificationsPermission();
    if (ok != null) return ok;
    return r.authorizationStatus == AuthorizationStatus.authorized ||
        r.authorizationStatus == AuthorizationStatus.provisional;
  } catch (_) {
    return false;
  }
}

// ------------------------------------------------------------------ abonnements

bool _synchroEnCours = false;
Set<String>? _enAttente;

/// S'abonne / se désabonne pour que le téléphone suive exactement [voulus].
Future<void> synchroniserSujets(Set<String> voulus) async {
  if (!notificationsPossibles) return;
  if (_synchroEnCours) {
    _enAttente = voulus; // on refera la synchro avec le dernier choix
    return;
  }
  _synchroEnCours = true;
  try {
    final prefs = await SharedPreferences.getInstance();
    final actuels = (prefs.getStringList('notif_sujets_abonnes') ?? []).toSet();
    final fm = FirebaseMessaging.instance;
    for (final s in actuels.difference(voulus)) {
      try {
        await fm.unsubscribeFromTopic(s);
        actuels.remove(s);
      } catch (_) {}
    }
    for (final s in voulus.difference(actuels)) {
      try {
        await fm.subscribeToTopic(s);
        actuels.add(s);
      } catch (_) {}
    }
    await prefs.setStringList('notif_sujets_abonnes', actuels.toList());
  } catch (_) {
  } finally {
    _synchroEnCours = false;
    final suite = _enAttente;
    _enAttente = null;
    if (suite != null) await synchroniserSujets(suite);
  }
}

// ------------------------------------------------------------------ réception

/// Appelé par Android quand l'app est fermée ou en arrière-plan.
@pragma('vm:entry-point')
Future<void> _messageEnArrierePlan(RemoteMessage m) async {
  await Firebase.initializeApp();
  await _preparerAffichage();
  await _afficher(m.data);
}

String _langue(SharedPreferences prefs) {
  final choisie = prefs.getString('langue') ?? '';
  if (languesDisponibles.containsKey(choisie)) return choisie;
  for (final l in PlatformDispatcher.instance.locales) {
    if (languesDisponibles.containsKey(l.languageCode)) return l.languageCode;
  }
  return 'en';
}

String _tr(String francais, String langue, {int? n}) {
  final t = langue == 'fr' ? francais : (textesTraduits[langue]?[francais] ?? francais);
  return n == null ? t : t.replaceAll('{n}', '$n');
}

/// Traduit le titre si le modèle de langue est déjà sur le téléphone
/// (jamais de téléchargement ici). Sinon : le titre français.
Future<String> _traduireTitre(String titre, String langue) async {
  if (langue == 'fr') return titre;
  try {
    TranslateLanguage? cible;
    for (final l in TranslateLanguage.values) {
      if (l.bcpCode == langue) cible = l;
    }
    if (cible == null) return titre;
    final g = OnDeviceTranslatorModelManager();
    if (!await g.isModelDownloaded(TranslateLanguage.french.bcpCode) ||
        !await g.isModelDownloaded(cible.bcpCode)) {
      return titre;
    }
    final t = OnDeviceTranslator(sourceLanguage: TranslateLanguage.french, targetLanguage: cible);
    final r = await t.translateText(titre).timeout(const Duration(seconds: 5));
    await t.close();
    return r.trim().isEmpty ? titre : r;
  } catch (_) {
    return titre;
  }
}

Future<void> _afficher(Map<String, dynamic> data) async {
  final id = data['id']?.toString() ?? '';
  final titre = data['titre']?.toString() ?? '';
  if (id.isEmpty || titre.isEmpty) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload(); // valeurs écrites par l'app pendant qu'elle tournait
  if (!(prefs.getBool('notif_actives') ?? false)) return;
  final langue = _langue(prefs);
  final limite = prefs.getInt('notif_limite') ?? 3; // 0 = sans limite

  // Compte des avancées reçues pour cette exécution de l'agent (« lot »).
  final lot = data['lot']?.toString() ?? '';
  var nb = prefs.getString('notif_lot') == lot ? (prefs.getInt('notif_lot_nb') ?? 0) : 0;
  nb++;
  await prefs.setString('notif_lot', lot);
  await prefs.setInt('notif_lot_nb', nb);

  final details = NotificationDetails(
    android: AndroidNotificationDetails(
      _canal,
      _tr('Nouvelles avancées', langue),
      importance: Importance.high,
      priority: Priority.high,
      color: logoEncreRose,
    ),
    iOS: const DarwinNotificationDetails(),
  );

  if (limite == 0 || nb <= limite) {
    final imp = int.tryParse(data['importance']?.toString() ?? '') ?? 3;
    final famille = familleDe(data['famille']?.toString() ?? 'other');
    final etoiles = '★' * imp.clamp(1, 5);
    final corps = '$etoiles ${_tr(motsImportance[imp.clamp(1, 5)], langue)} · ${_tr(famille.nom, langue)}';
    await _local.show(
      id.hashCode & 0x7fffffff,
      await _traduireTitre(titre, langue),
      corps,
      details,
      payload: id,
    );
  } else {
    final autres = nb - limite;
    await _local.show(
      _idRegroupement,
      autres == 1 ? _tr('+ 1 autre avancée', langue) : _tr('+ {n} autres avancées', langue, n: autres),
      _tr('Touchez pour les voir dans le fil', langue),
      details,
      payload: payloadFil,
    );
  }
}
