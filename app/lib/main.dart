// Point d'entrée de l'application Novum.
//
// L'écran s'affiche IMMÉDIATEMENT (logo), puis la connexion à la base se fait
// en arrière-plan : impossible de rester bloqué sur un écran noir. Toute
// erreur est affichée en clair à l'écran.

import 'dart:async';

import 'package:flutter/material.dart';

import 'coquille.dart';
import 'donnees.dart';
import 'etat.dart';
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
    await etat.charger(); // mémoire du téléphone : domaines, favoris, thème
    await initialiserSupabase().timeout(const Duration(seconds: 15));
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
        title: 'Novum',
        debugShowCheckedModeBanner: false,
        theme: _theme(paletteClaire, Brightness.light),
        darkTheme: _theme(paletteSombre, Brightness.dark),
        themeMode: etat.theme,
        home: FutureBuilder<void>(
          future: _demarrage,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const _Demarrage();
            if (snap.hasError) return _Probleme(message: snap.error.toString());
            return etat.premierLancementFait ? const Coquille() : const EcranDomaines();
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
