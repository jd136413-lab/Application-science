// Point d'entrée de l'application Novum.
//
// L'écran s'affiche IMMÉDIATEMENT (logo), puis la connexion à la base se fait
// en arrière-plan : impossible de rester bloqué sur un écran noir. Toute
// erreur est affichée en clair à l'écran.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'coquille.dart';
import 'detail.dart';
import 'donnees.dart';
import 'etat.dart';
import 'langues.dart';
import 'navigation.dart';
import 'notifications.dart';
import 'premier_lancement.dart';
import 'reglages.dart';
import 'widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Une erreur d'affichage montre un message lisible au lieu d'un écran vide.
  ErrorWidget.builder = (details) => Material(
        color: const Color(0xFFF2F1F6),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Erreur d’affichage :\n${details.exceptionAsString()}',
              style: const TextStyle(color: Color(0xFF17161F), fontSize: 14)),
        ),
      );
  runApp(const AppNovum());
}

class AppNovum extends StatefulWidget {
  const AppNovum({super.key});

  @override
  State<AppNovum> createState() => _AppNovumState();
}

class _AppNovumState extends State<AppNovum> {
  late final Future<void> _demarrage = _demarrer();

  Future<void> _demarrer() async {
    if (!configurationPresente) {
      throw 'Configuration manquante : les secrets SUPABASE_URL et SUPABASE_PUBLISHABLE_KEY '
          'ne sont pas arrivés jusqu’à la compilation.';
    }
    await etat.charger(); // mémoire du téléphone : domaines, favoris, thème, langue
    await initializeDateFormatting(); // dates dans toutes les langues
    await initialiserSupabase().timeout(const Duration(seconds: 15));
    // Notifications : jamais bloquant (Firebase absent, pas de réseau…).
    demandeOuverture.addListener(_ouvrirDepuisNotification);
    unawaited(initialiserNotifications().then((_) => synchroniserSujets(etat.sujetsNotif)));
  }

  /// Une notification a été touchée : ouvre l'avancée, ou le fil « Aujourd'hui ».
  Future<void> _ouvrirDepuisNotification() async {
    final contenu = demandeOuverture.value;
    if (contenu == null) return;
    // Attendre que l'app soit prête (premier écran affiché).
    for (var i = 0; i < 50 && navigateur.currentState == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    final nav = navigateur.currentState;
    if (nav == null || !etat.premierLancementFait) return;
    nav.popUntil((r) => r.isFirst);
    if (contenu == payloadFil) {
      demandeFilAujourdhui.value++;
      return;
    }
    try {
      final a = await chargerAvancee(contenu);
      if (a != null) nav.push(MaterialPageRoute(builder: (_) => EcranDetail(avancee: a)));
    } catch (_) {
      demandeFilAujourdhui.value++; // pas de réseau : au moins le fil
    }
  }

  ThemeData _theme(Palette p, Brightness luminosite) => ThemeData(
        useMaterial3: true,
        brightness: luminosite,
        scaffoldBackgroundColor: p.fond,
        colorScheme: ColorScheme.fromSeed(
          seedColor: logoEncreBleue,
          brightness: luminosite,
          surface: p.carte,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) => MaterialApp(
        navigatorKey: navigateur,
        title: 'Novum',
        debugShowCheckedModeBanner: false,
        theme: _theme(paletteClaire, Brightness.light),
        darkTheme: _theme(paletteSombre, Brightness.dark),
        themeMode: etat.theme,
        // Langue : textes des boutons système, sens de lecture (arabe, ourdou…).
        locale: Locale(etat.langue),
        supportedLocales: [for (final code in languesDisponibles.keys) Locale(code)],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: FutureBuilder<void>(
          future: _demarrage,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const _Demarrage();
            if (snap.hasError) return _Probleme(message: snap.error.toString());
            // La clé reconstruit tous les écrans quand on change de langue.
            return KeyedSubtree(
              key: ValueKey(etat.langue),
              child: etat.premierLancementFait ? const Coquille() : const EcranDomaines(),
            );
          },
        ),
      ),
    );
  }
}

/// Écran de démarrage : le logo, le temps de se connecter.
class _Demarrage extends StatelessWidget {
  const _Demarrage();

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: palette(context).fond,
        body: const Center(child: LogoNovum(taille: 52)),
      );
}

/// Affiché si le démarrage échoue : le message exact, pour pouvoir corriger.
class _Probleme extends StatelessWidget {
  final String message;
  const _Probleme({required this.message});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: palette(context).fond,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const LogoNovum(taille: 40),
              const SizedBox(height: 24),
              Text('Le démarrage a échoué',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: palette(context).texte)),
              const SizedBox(height: 10),
              SelectableText(message,
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: palette(context).texteDiscret)),
            ]),
          ),
        ),
      );
}
