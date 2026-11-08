// Écran de chargement du démarrage (planche 84, validée par Maxime le 08/11/2026) :
// le logo se compose puis « respire », avec une petite barre qui glisse, le temps
// que les pubs des 2 accueils (Sciences et Technologies) se préchargent.
// Seulement si des pubs sont prévues sur ce téléphone ; 6 secondes au plus.

import 'package:flutter/material.dart';

import 'reglages.dart';
import 'widgets.dart';

class EcranChargementPubs extends StatefulWidget {
  const EcranChargementPubs({super.key});

  @override
  State<EcranChargementPubs> createState() => _EcranChargementPubsState();
}

class _EcranChargementPubsState extends State<EcranChargementPubs> with TickerProviderStateMixin {
  late final AnimationController _respire =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
  late final AnimationController _barre =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _respire.dispose();
    _barre.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    // Material : sans lui, Flutter souligne les textes en jaune (bug vu le 08/11).
    return Material(
      color: p.fond,
      child: SizedBox.expand(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          ScaleTransition(
            scale: Tween(begin: 1.0, end: 1.04).animate(CurvedAnimation(parent: _respire, curve: Curves.easeInOut)),
            child: const LogoNovaStem(taille: 56, boucle: true),
          ),
          const SizedBox(height: 30),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              width: 120,
              height: 4,
              child: ColoredBox(
                color: p.pastille,
                child: AnimatedBuilder(
                  animation: _barre,
                  builder: (context, _) => Stack(children: [
                    Positioned(
                      left: -40 + 160 * Curves.easeInOut.transform(_barre.value),
                      top: 0,
                      bottom: 0,
                      width: 40,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [logoEncreRose, logoEncreBleue]),
                          borderRadius: BorderRadius.all(Radius.circular(2)),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
