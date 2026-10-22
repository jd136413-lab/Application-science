// Petits éléments réutilisés : palette, logo, étoiles, tuile de famille.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'langues.dart';
import 'memoire.dart';
import 'reglages.dart';

bool estSombre(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

Palette palette(BuildContext context) => estSombre(context) ? paletteSombre : paletteClaire;

TextStyle police(String nom, {double? taille, FontWeight? graisse, Color? couleur, double? hauteur}) =>
    GoogleFonts.getFont(nom, fontSize: taille, fontWeight: graisse, color: couleur, height: hauteur);

/// Logo NovaSTEM : la case du tableau périodique « No 102 » + « va » + « STEM » en exposant.
/// Avec [anime], le logo se compose la première fois qu'il apparaît (une fois par
/// lancement) : les « No » rose et bleu arrivent des deux côtés, la case se trace,
/// puis « 102 » et « vaSTEM » apparaissent (maquette 22).
class LogoNovaStem extends StatefulWidget {
  final double taille;
  final bool anime;
  const LogoNovaStem({super.key, this.taille = 44, this.anime = false});

  @override
  State<LogoNovaStem> createState() => _LogoNovaStemState();
}

class _LogoNovaStemState extends State<LogoNovaStem> with SingleTickerProviderStateMixin {
  static bool _dejaAnime = false;
  late final AnimationController _t =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100), value: 1);

  @override
  void initState() {
    super.initState();
    if (widget.anime && !_dejaAnime) {
      _dejaAnime = true;
      _t.value = 0;
      _t.forward();
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  /// Avancement (0 à 1) de la partie [debut]–[fin] de l'animation.
  double _phase(double debut, double fin, [Curve courbe = Curves.easeOutCubic]) =>
      courbe.transform(((_t.value - debut) / (fin - debut)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final taille = widget.taille;
    final p = palette(context);
    final sombre = estSombre(context);
    final bord = taille * 0.068;
    final padBas = taille * 0.11;
    final style = police(policeLogo, taille: taille, graisse: FontWeight.w700, couleur: p.texte, hauteur: 1.0);
    Paint encre(Color c, double opacite) => Paint()
      ..color = c.withValues(alpha: opacite)
      ..blendMode = sombre ? BlendMode.screen : BlendMode.multiply;
    return Semantics(
      label: nomApp,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _t,
          builder: (context, _) {
            final arrivee = _phase(0, 0.45);
            final cadre = _phase(0.3, 0.65, Curves.easeInOut);
            final fin = _phase(0.5, 1);
            return Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: EdgeInsets.fromLTRB(taille * 0.18, taille * 0.27, taille * 0.18, padBas),
                  decoration: BoxDecoration(border: Border.all(color: p.texte.withValues(alpha: cadre), width: bord)),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Transform.translate(
                        offset: Offset(-taille * 0.9 * (1 - arrivee), 0),
                        child: Text(logoSymbole,
                            style: style.copyWith(color: null, foreground: encre(logoEncreRose, arrivee))),
                      ),
                      Positioned(
                        left: taille * 0.068,
                        top: taille * 0.045,
                        child: Transform.translate(
                          offset: Offset(taille * 0.9 * (1 - arrivee), 0),
                          child: Text(logoSymbole,
                              style: style.copyWith(color: null, foreground: encre(logoEncreBleue, arrivee))),
                        ),
                      ),
                      Positioned(
                        left: -taille * 0.05,
                        top: -taille * 0.21,
                        child: Opacity(
                          opacity: fin,
                          child: Text(logoNumero,
                              style: police(policeTexte,
                                  taille: taille * 0.23, graisse: FontWeight.w700, couleur: p.texte, hauteur: 1.0)),
                        ),
                      ),
                    ],
                  ),
                ),
                Opacity(
                  opacity: fin,
                  child: Transform.translate(
                    offset: Offset(0, taille * 0.12 * (1 - fin)),
                    child: Padding(
                      padding: EdgeInsets.only(left: taille * 0.07, bottom: padBas + bord),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(logoSuite, style: style),
                          Padding(
                            padding: EdgeInsets.only(left: taille * 0.04, top: taille * 0.04),
                            child: Text(logoExposant,
                                style: police(policeTexte,
                                        taille: taille * 0.36, graisse: FontWeight.w700, couleur: p.texte, hauteur: 1.0)
                                    .copyWith(letterSpacing: taille * 0.36 * 0.08)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 5 étoiles jaunes (couleurEtoiles) + le mot (Notable, Majeur…).
class Etoiles extends StatelessWidget {
  final int note;
  final double taille;
  final bool avecMot;
  const Etoiles({super.key, required this.note, this.taille = 15, this.avecMot = true});

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    return Semantics(
      label: '${tr('Importance {n} sur 5', n: note)} : ${tr(motsImportance[note])}',
      child: ExcludeSemantics(
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 1; i <= 5; i++)
            Icon(Icons.star_rounded, size: taille + 2, color: i <= note ? couleurEtoiles : p.bordure),
          if (avecMot) ...[
            const SizedBox(width: 6),
            Text(tr(motsImportance[note]),
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

/// Message centré (vide, erreur…) avec un bouton facultatif.
class MessageCentre extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String detail;
  final String? bouton;
  final VoidCallback? action;
  const MessageCentre({super.key, required this.icone, required this.titre, required this.detail, this.bouton, this.action});

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(color: p.pastille, shape: BoxShape.circle),
            child: Icon(icone, size: 42, color: p.texteDiscret),
          ),
          const SizedBox(height: 16),
          Text(titre,
              textAlign: TextAlign.center,
              style: police(policeTitres, taille: 24, graisse: FontWeight.w800, couleur: p.texte)),
          const SizedBox(height: 8),
          Text(detail,
              textAlign: TextAlign.center,
              style: police(policeTexte, taille: 15, couleur: p.texteDiscret, hauteur: 1.5)),
          if (bouton != null) ...[
            const SizedBox(height: 18),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: p.encre, foregroundColor: p.surEncre, shape: const StadiumBorder()),
              onPressed: action,
              child: Text(bouton!),
            ),
          ],
        ]),
      ),
    );
  }
}


/// Petit message en bas de l'écran, avec un bouton « Annuler » facultatif.
void afficherMessage(BuildContext context, String texte, {IconData icone = Icons.check_rounded, VoidCallback? annuler}) {
  final p = palette(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.encre,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      duration: const Duration(seconds: 4),
      content: Row(children: [
        Icon(icone, color: couleurEtoiles, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Text(texte, style: police(policeTexte, taille: 14, couleur: p.surEncre, hauteur: 1.4))),
      ]),
      action: annuler == null
          ? null
          : SnackBarAction(label: tr(texteAnnuler), textColor: couleurEtoiles, onPressed: annuler),
    ));
}

/// Ferme l'écran quand on le tire vers le bas depuis le haut (comme une photo).
/// Le contenu suit le doigt ; au-delà de 110 pixels, l'écran se ferme.
class GlisserPourFermer extends StatefulWidget {
  final Widget child;
  const GlisserPourFermer({super.key, required this.child});

  @override
  State<GlisserPourFermer> createState() => _GlisserPourFermerState();
}

class _GlisserPourFermerState extends State<GlisserPourFermer> {
  double _decalage = 0;
  bool _ferme = false;

  bool _suivre(ScrollNotification n) {
    if (n.depth != 0 || _ferme) return false;
    if (n is OverscrollNotification && n.dragDetails != null && n.overscroll < 0) {
      setState(() => _decalage += -n.overscroll);
    } else if (n is ScrollUpdateNotification && _decalage > 0 && n.dragDetails != null && (n.scrollDelta ?? 0) > 0) {
      setState(() => _decalage = (_decalage - n.scrollDelta!).clamp(0, double.infinity));
    } else if (n is ScrollEndNotification && _decalage > 0) {
      if (_decalage > 110) {
        _ferme = true;
        Navigator.of(context).maybePop();
      } else {
        setState(() => _decalage = 0);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _suivre,
      child: AnimatedContainer(
        duration: Duration(milliseconds: _decalage == 0 ? 200 : 0),
        transform: Matrix4.translationValues(0, _decalage * 0.6, 0),
        child: widget.child,
      ),
    );
  }
}


/// Badge « type d'étude » (Étude chez l'animal, Prototype…), maquette 30/33.
class BadgeEtude extends StatelessWidget {
  final String code;
  const BadgeEtude({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    final (libelle, niveau) = badgesEtude[code] ?? ('', 'bleu');
    final (fondClair, texteClair, fondSombre, texteSombre) = couleursBadges[niveau]!;
    final sombre = estSombre(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: sombre ? fondSombre : fondClair, borderRadius: BorderRadius.circular(10)),
      child: Text(tr(libelle),
          style: police(policeTexte, taille: 13, graisse: FontWeight.w700, couleur: sombre ? texteSombre : texteClair)),
    );
  }
}

/// Photo d'une avancée, gardée sur le téléphone (30 jours, 100 Mo au plus :
/// voir memoire.dart). Fond simple pendant le chargement ou en cas d'erreur.
class ImageGardee extends StatelessWidget {
  final String url;
  const ImageGardee({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    return Semantics(
      image: true,
      label: tr('Photo fournie par la source'),
      child: CachedNetworkImage(
        imageUrl: url,
        cacheManager: cacheImages,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (c, u) => Container(color: p.pastille),
        errorWidget: (c, u, e) => Container(color: p.pastille),
      ),
    );
  }
}
