// Point d'entrée de l'application Novum.

import 'package:flutter/material.dart';

import 'accueil.dart';
import 'donnees.dart';
import 'reglages.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initialiserSupabase();
  runApp(const AppNovum());
}

class AppNovum extends StatelessWidget {
  const AppNovum({super.key});

  ThemeData _theme(Palette p, Brightness luminosite) => ThemeData(
        useMaterial3: true,
        brightness: luminosite,
        scaffoldBackgroundColor: p.fond,
        colorScheme: ColorScheme.fromSeed(
          seedColor: logoEncreBleue,
          brightness: luminosite,
          surface: p.carte,
        ),
        textTheme: ThemeData(brightness: luminosite).textTheme.apply(
              fontFamily: police(policeTexte).fontFamily,
              bodyColor: p.texte,
              displayColor: p.texte,
            ),
      );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Novum',
      debugShowCheckedModeBanner: false,
      theme: _theme(paletteClaire, Brightness.light),
      darkTheme: _theme(paletteSombre, Brightness.dark),
      themeMode: ThemeMode.system, // le choix manuel arrivera avec les Réglages
      home: configurationPresente ? const EcranAccueil() : const _ConfigurationManquante(),
    );
  }
}

/// Affiché si l'app a été compilée sans l'adresse ou la clé Supabase.
class _ConfigurationManquante extends StatelessWidget {
  const _ConfigurationManquante();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Configuration manquante : les secrets SUPABASE_URL et SUPABASE_PUBLISHABLE_KEY '
              'ne sont pas arrivés jusqu’à la compilation.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
}
