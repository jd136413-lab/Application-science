// Écran de présentation : montré au premier lancement, avant le choix des
// domaines (maquette 39 · C1, fond sombre « couverture »).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'langues.dart';
import 'premier_lancement.dart';
import 'reglages.dart';
import 'widgets.dart';

/// Premier lancement : présentation, puis choix des domaines.
class PremierLancement extends StatefulWidget {
  const PremierLancement({super.key});

  @override
  State<PremierLancement> createState() => _PremierLancementState();
}

class _PremierLancementState extends State<PremierLancement> {
  bool _presentationVue = false;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: _presentationVue
            ? const EcranDomaines()
            : EcranPresentation(onSuivant: () => setState(() => _presentationVue = true)),
      );
}

class EcranPresentation extends StatelessWidget {
  final VoidCallback onSuivant;
  const EcranPresentation({super.key, required this.onSuivant});

  // Couleurs de la maquette (fond sombre, quel que soit le thème choisi).
  static const _fond = Color(0xFF17161F);
  static const _gris = Color(0xFFB9B7C6);
  static const _discret = Color(0xFF8A8899);
  static const _ligne = Color(0xFF2A2935);
  static const _etoileVide = Color(0xFF45434F);

  // Les 5 niveaux, du plus rare au plus courant.
  static const _niveaux = [
    (5, 'historique, quelques fois par an'),
    (4, 'une première, qui touchera beaucoup de monde'),
    (3, 'change la donne dans son domaine'),
    (2, 'solide et remarqué par les spécialistes'),
    (1, 'un pas de plus, utile à connaître'),
  ];

  @override
  Widget build(BuildContext context) {
    Widget ligneNiveau(int note, String detail) => Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _ligne))),
          child: Row(children: [
            SizedBox(
              width: 82,
              child: Row(children: [
                for (var i = 1; i <= 5; i++)
                  Icon(Icons.star_rounded, size: 16, color: i <= note ? couleurEtoiles : _etoileVide),
              ]),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 92,
              child: Text(tr(motsImportance[note]),
                  style: police(policeTexte, taille: 14, graisse: FontWeight.w700, couleur: Colors.white)),
            ),
            Expanded(
              child: Text(tr(detail), style: police(policeTexte, taille: 12.5, couleur: _gris, hauteur: 1.3)),
            ),
          ]),
        );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _fond,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Logo en version claire, sur le fond sombre
              Theme(data: ThemeData(brightness: Brightness.dark), child: const LogoNovaStem(taille: 30, anime: true)),
              Expanded(
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height * 0.62),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        Text(tr('Le monde avance.'),
                            style: police(policeTitres,
                                taille: 42, graisse: FontWeight.w800, couleur: Colors.white, hauteur: 1.02)),
                        Text(tr('Suivez-le.'),
                            style: police(policeTitres,
                                taille: 42, graisse: FontWeight.w800, couleur: couleurEtoiles, hauteur: 1.02)),
                        const SizedBox(height: 16),
                        Text(
                            tr('Les vraies découvertes scientifiques et technologiques, expliquées simplement et notées selon leur importance.'),
                            style: police(policeTexte, taille: 15.5, couleur: _gris, hauteur: 1.5)),
                        const SizedBox(height: 16),
                        Container(
                          decoration: const BoxDecoration(border: Border(top: BorderSide(color: _ligne))),
                          child: Column(children: [for (final (n, d) in _niveaux) ligneNiveau(n, d)]),
                        ),
                        const SizedBox(height: 16),
                        Text('●  ${tr('Des nouvelles avancées sont ajoutées 2 fois par jour')}',
                            style: police(policeTexte, taille: 14, graisse: FontWeight.w600, couleur: _gris)),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
              Text(tr('Sélection et résumés automatisés · l’article source fait foi.'),
                  style: police(policeTexte, taille: 11.5, couleur: _discret)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _fond,
                    shape: const StadiumBorder(),
                    textStyle: police(policeTexte, taille: 16, graisse: FontWeight.w700),
                  ),
                  onPressed: onSuivant,
                  child: Text(tr('Choisir mes domaines')),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
