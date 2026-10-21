// Version Android / iPhone des notifications, avec Firebase Cloud Messaging.
//
// Fonctionnement :
// - Le téléphone s'abonne à des « sujets » selon Réglages → Notifications :
//   un sujet par famille et par niveau d'importance (ex. n_space_4).
// - Quand l'agent ajoute une avancée, il envoie un message sur le sujet
//   correspondant. Seuls les téléphones abonnés le reçoivent.
// - Le téléphone affiche lui-même les notifications, au plus UNE par fil
//   (Sciences, Technologies) : l'avancée la plus importante en vedette, avec
//   son « en bref » et sa photo libre s'il y en a une, les autres listées
//   dessous (maquette 28 D). Si la notification du fil est encore affichée
//   à l'arrivée suivante, elle est mise à jour, les nouvelles en tête.
//
// Sans configuration Firebase à la compilation, tout est désactivé.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui show PlatformDispatcher, instantiateImageCodec, ImageByteFormat;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show FlutterError;
import 'package:in_app_review/in_app_review.dart';
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
/// Une notification par fil : ces numéros la remplacent à chaque mise à jour.
const Map<String, int> _idParFil = {'science': 201, 'tech': 202};
final _local = FlutterLocalNotificationsPlugin();

// ------------------------------------------------------------------ démarrage

Future<void> initialiserNotifications() async {
  if (!notificationsPossibles) return;
  try {
    await Firebase.initializeApp();
    // Rapports de plantage (Firebase Crashlytics) : visibles dans la console Firebase.
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    ui.PlatformDispatcher.instance.onError = (erreur, pile) {
      FirebaseCrashlytics.instance.recordError(erreur, pile, fatal: true);
      return true;
    };
    FirebaseMessaging.onBackgroundMessage(_messageEnArrierePlan);
    await _preparerAffichage(onTouche: (r) => _touche(r.payload, r.actionId));
    FirebaseMessaging.onMessage.listen((m) => _afficher(m.data));
    // App lancée en touchant une notification
    final lancement = await _local.getNotificationAppLaunchDetails();
    if (lancement?.didNotificationLaunchApp ?? false) {
      _touche(lancement!.notificationResponse?.payload, lancement.notificationResponse?.actionId);
    }
  } catch (_) {
    // Les notifications ne doivent jamais empêcher l'app de fonctionner.
  }
}

/// Fenêtre officielle Google Play « Noter l'app » (Google décide s'il l'affiche).
Future<bool> demanderAvis() async {
  try {
    final avis = InAppReview.instance;
    if (await avis.isAvailable()) {
      await avis.requestReview();
      return true;
    }
  } catch (_) {}
  return false;
}

/// Notification (ou un de ses boutons) touchée. Contenu « grp|fil|idVedette|nombre » :
/// « Lire » ou une seule avancée → son détail ; sinon → le fil concerné.
void _touche(String? contenu, [String? action]) {
  if (contenu == null || contenu.isEmpty) return;
  if (contenu.startsWith('grp|')) {
    final m = contenu.split('|');
    if (m.length == 4) {
      final seule = (int.tryParse(m[3]) ?? 1) <= 1;
      contenu = (action == 'lire' || ((action == null || action.isEmpty) && seule)) ? m[2] : '$payloadFil:${m[1]}';
    }
  }
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
  for (final l in ui.PlatformDispatcher.instance.locales) {
    if (languesDisponibles.containsKey(l.languageCode)) return l.languageCode;
  }
  return 'en';
}

String _tr(String francais, String langue, {int? n}) {
  final t = langue == 'fr' ? francais : (textesTraduits[langue]?[francais] ?? francais);
  return n == null ? t : t.replaceAll('{n}', '$n');
}


/// Traduit un texte français si le modèle de langue est déjà sur le téléphone
/// (jamais de téléchargement ici). Sinon : le texte français.
Future<String> _traduire(String texte, String langue) async {
  if (langue == 'fr' || texte.trim().isEmpty) return texte;
  try {
    TranslateLanguage? cible;
    for (final l in TranslateLanguage.values) {
      if (l.bcpCode == langue) cible = l;
    }
    if (cible == null) return texte;
    final g = OnDeviceTranslatorModelManager();
    if (!await g.isModelDownloaded(TranslateLanguage.french.bcpCode) ||
        !await g.isModelDownloaded(cible.bcpCode)) {
      return texte;
    }
    final t = OnDeviceTranslator(sourceLanguage: TranslateLanguage.french, targetLanguage: cible);
    final r = await t.translateText(texte).timeout(const Duration(seconds: 5));
    await t.close();
    return r.trim().isEmpty ? texte : r;
  } catch (_) {
    return texte;
  }
}

/// Télécharge la photo libre de l'avancée et la réduit (720 px de large) pour
/// la notification. Null en cas de souci : la notification part sans photo.
Future<Uint8List?> _photo(String adresse) async {
  if (!adresse.startsWith('https://')) return null;
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
  try {
    final req = await client.getUrl(Uri.parse(adresse)).timeout(const Duration(seconds: 6));
    final rep = await req.close().timeout(const Duration(seconds: 8));
    if (rep.statusCode != 200 || rep.contentLength > 12 * 1024 * 1024) return null;
    final morceaux = BytesBuilder(copy: false);
    await for (final m in rep.timeout(const Duration(seconds: 10))) {
      morceaux.add(m);
      if (morceaux.length > 12 * 1024 * 1024) return null;
    }
    final codec = await ui.instantiateImageCodec(morceaux.takeBytes(), targetWidth: 720);
    final image = (await codec.getNextFrame()).image;
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    return png?.buffer.asUint8List();
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

/// Les messages arrivent l'un après l'autre (une avancée par message) : on les
/// traite dans l'ordre pour ne jamais perdre une avancée du regroupement.
Future<void> _file = Future.value();

Future<void> _afficher(Map<String, dynamic> data) {
  _file = _file.then((_) => _afficherUne(data)).catchError((_) {});
  return _file;
}

Future<void> _afficherUne(Map<String, dynamic> data) async {
  final id = data['id']?.toString() ?? '';
  final titre = data['titre']?.toString() ?? '';
  final fil = data['fil']?.toString() == 'tech' ? 'tech' : 'science';
  if (id.isEmpty || titre.isEmpty) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload(); // valeurs écrites par l'app pendant qu'elle tournait
  if (!(prefs.getBool('notif_actives') ?? false)) return;
  final langue = _langue(prefs);
  final idNotif = _idParFil[fil]!;
  final cle = 'notif_grp_$fil';

  // La notification de ce fil est-elle encore affichée ? Si oui, on complète
  // sa liste ; sinon, on repart de zéro.
  var encoreLa = false;
  try {
    final actives = await _local.getActiveNotifications();
    encoreLa = actives.any((n) => n.id == idNotif);
  } catch (_) {}
  final liste = <Map<String, dynamic>>[];
  if (encoreLa) {
    try {
      for (final x in jsonDecode(prefs.getString(cle) ?? '[]') as List) {
        liste.add(Map<String, dynamic>.from(x as Map));
      }
    } catch (_) {}
  }
  liste.removeWhere((x) => x['id'] == id);
  liste.add({
    'id': id,
    'titre': titre,
    'imp': (int.tryParse(data['importance']?.toString() ?? '') ?? 1).clamp(1, 5),
    'resume': data['resume']?.toString() ?? '',
    'image': data['image']?.toString() ?? '',
    'lot': data['lot']?.toString() ?? '',
  });
  // Les nouvelles arrivées en tête, puis de la plus importante à la moins importante.
  liste.sort((a, b) {
    final l = (b['lot'] as String).compareTo(a['lot'] as String);
    return l != 0 ? l : (b['imp'] as int).compareTo(a['imp'] as int);
  });
  if (liste.length > 8) liste.removeRange(8, liste.length);
  await prefs.setString(cle, jsonEncode(liste));

  final vedette = liste.first;
  final autres = liste.skip(1).toList();
  final nb = liste.length;
  final imp = vedette['imp'] as int;
  final etoiles = '★' * imp;
  final mot = _tr(motsImportance[imp], langue);
  final nomFil = _tr(fil == 'tech' ? texteTechnologies : texteSciences, langue);
  final titreV = await _traduire(vedette['titre'] as String, langue);
  final resumeV = await _traduire(vedette['resume'] as String, langue);
  final titresAutres = [
    for (final a in autres.take(5)) '${'★' * (a['imp'] as int)} ${await _traduire(a['titre'] as String, langue)}'
  ];
  final plus = autres.isEmpty
      ? ''
      : ' · ${autres.length == 1 ? _tr('+ 1 autre', langue) : _tr('+ {n} autres', langue, n: autres.length)}';

  final photo = await _photo(vedette['image'] as String);
  final StyleInformation style;
  if (photo != null) {
    style = BigPictureStyleInformation(
      ByteArrayAndroidBitmap(photo),
      contentTitle: titreV,
      summaryText: autres.isEmpty
          ? (resumeV.isEmpty ? '$etoiles $mot' : resumeV)
          : '$etoiles $mot · ${_tr('Aussi :', langue)} ${titresAutres.join(' · ')}',
      hideExpandedLargeIcon: true,
    );
  } else {
    final lignes = StringBuffer('$etoiles $mot');
    if (resumeV.isNotEmpty) lignes.write(' — $resumeV');
    if (titresAutres.isNotEmpty) {
      lignes.write('\n\n${_tr('Aussi :', langue)}');
      for (final t in titresAutres) {
        lignes.write('\n$t');
      }
    }
    style = BigTextStyleInformation(lignes.toString(), contentTitle: titreV);
  }

  final details = NotificationDetails(
    android: AndroidNotificationDetails(
      _canal,
      _tr('Nouvelles avancées', langue),
      importance: Importance.high,
      priority: Priority.high,
      color: logoEncreRose,
      subText: nomFil,
      styleInformation: style,
      largeIcon: photo == null ? null : ByteArrayAndroidBitmap(photo),
      onlyAlertOnce: false,
      actions: [
        AndroidNotificationAction('lire', _tr('Lire', langue), showsUserInterface: true),
        if (nb > 1) AndroidNotificationAction('voir', _tr('Voir les {n}', langue, n: nb), showsUserInterface: true),
      ],
    ),
    iOS: DarwinNotificationDetails(threadIdentifier: 'novastem_$fil'),
  );

  await _local.show(
    idNotif,
    titreV,
    autres.isEmpty ? (resumeV.isEmpty ? '$etoiles $mot' : resumeV) : '$etoiles $mot$plus',
    details,
    payload: 'grp|$fil|${vedette['id']}|$nb',
  );
}
