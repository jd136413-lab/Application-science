// Petits éléments réutilisés : palette, logo, étoiles, tuile de famille.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'reglages.dart';

bool estSombre(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

Palette palette(BuildContext context) => estSombre(context) ? paletteSombre : paletteClaire;

TextStyle police(String nom, {double? taille, FontWeight? graisse, Color? couleur, double? hauteur}) =>
    GoogleFonts.getFont(nom, fontSize: taille, fontWeight: graisse, color: couleur, height: hauteur);

/// Logo Novum : la case du tableau périodique « No 102 » + « vum ».
class LogoNovum extends StatelessWidget {
  final double taille;
  const LogoNovum({super.key, this.taille = 44});

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final sombre = estSombre(context);
    final bord = taille * 0.068;
    final padBas = taille * 0.11;
    final style = police(policeLogo, taille: taille, graisse: FontWeight.w700, couleur: p.texte, hauteur: 1.0);
    Paint encre(Color c) => Paint()
      ..color = c
      ..blendMode = sombre ? BlendMode.screen : BlendMode.multiply;
    return Semantics(
      label: 'Novum',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(taille * 0.18, taille * 0.27, taille * 0.18, padBas),
              decoration: BoxDecoration(border: Border.all(color: p.texte, width: bord)),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Text(logoSymbole, style: style.copyWith(color: null, foreground: encre(logoEncreRose))),
                  Positioned(
                    left: taille * 0.068,
                    top: taille * 0.045,
                    child: Text(logoSymbole, style: style.copyWith(color: null, foreground: encre(logoEncreBleue))),
                  ),
                  Positioned(
                    left: -taille * 0.05,
                    top: -taille * 0.21,
                    child: Text(logoNumero,
                        style: police(policeTexte, taille: taille * 0.23, graisse: FontWeight.w700, couleur: p.texte, hauteur: 1.0)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: taille * 0.07, bottom: padBas + bord),
              child: Text(logoSuite, style: style),
            ),
          ],
        ),
      ),
    );
  }
}

/// 5 étoiles, colorées selon la famille, + le mot (Notable, Majeur…).
class Etoiles extends StatelessWidget {
  final int note;
  final Color couleur;
  final double taille;
  final bool avecMot;
  const Etoiles({super.key, required this.note, required this.couleur, this.taille = 15, this.avecMot = true});

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    return Semantics(
      label: 'Importance $note sur 5 : ${motsImportance[note]}',
      child: ExcludeSemantics(
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 1; i <= 5; i++)
            Icon(Icons.star_rounded, size: taille + 2, color: i <= note ? couleur : p.bordure),
          if (avecMot) ...[
            const SizedBox(width: 6),
            Text(motsImportance[note],
                style: police(policeTexte, taille: taille - 1, graisse: FontWeight.w700, couleur: p.texte)),
          ],
        ]),
      ),
    );
  }
}

/// Tuile colorée avec l'icône de la famille.
class TuileFamille extends StatelessWidget {
  final Famille famille;
  final double taille;
  const TuileFamille({super.key, required this.famille, this.taille = 34});

  @override
  Widget build(BuildContext context) => Container(
        width: taille,
        height: taille,
        decoration: BoxDecoration(color: famille.couleur, borderRadius: BorderRadius.circular(taille * 0.32)),
        child: Icon(famille.symbole, size: taille * 0.56, color: famille.icone),
      );
}
