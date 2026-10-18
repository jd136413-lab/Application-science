// Écran Réglages : thème, domaines, langue, à propos.

import 'package:flutter/material.dart';

import 'etat.dart';
import 'premier_lancement.dart';
import 'reglages.dart';
import 'widgets.dart';

class EcranReglages extends StatelessWidget {
  const EcranReglages({super.key});

  @override
  Widget build(BuildContext context) {
    final p = palette(context);

    Widget titreSection(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
          child: Text(t,
              style: police(policeTexte, taille: 12, graisse: FontWeight.w700, couleur: p.texteDiscret)),
        );

    Widget bloc({required Widget child, VoidCallback? onTap}) => Material(
          color: p.carte,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.all(16), child: child)),
        );

    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) {
        final nbDomaines = etat.domaines.length;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 28),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(texteOngletReglages,
                  style: police(policeTitres, taille: 34, graisse: FontWeight.w800, couleur: p.texte)),
            ),
            titreSection('THÈME'),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: p.pastille, borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                for (final (mode, texte) in [
                  (ThemeMode.system, 'Automatique'),
                  (ThemeMode.light, 'Clair'),
                  (ThemeMode.dark, 'Sombre'),
                ])
                  Expanded(
                    child: Material(
                      color: etat.theme == mode ? p.carte : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => etat.changerTheme(mode),
                        child: SizedBox(
                          height: 42,
                          child: Center(
                            child: Text(texte,
                                style: police(policeTexte,
                                    taille: 14,
                                    graisse: FontWeight.w700,
                                    couleur: etat.theme == mode ? p.texte : p.texteDiscret)),
                          ),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
            titreSection('LANGUE'),
            bloc(
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Langue de l’application',
                        style: police(policeTexte, taille: 16, graisse: FontWeight.w600, couleur: p.texte)),
                    const SizedBox(height: 2),
                    Text('Français · la traduction automatique arrive bientôt',
                        style: police(policeTexte, taille: 13, couleur: p.texteDiscret)),
                  ]),
                ),
              ]),
            ),
            titreSection('CENTRES D’INTÉRÊT'),
            bloc(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EcranDomaines(premierLancement: false)),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Mes domaines',
                        style: police(policeTexte, taille: 16, graisse: FontWeight.w600, couleur: p.texte)),
                    const SizedBox(height: 6),
                    Row(children: [
                      for (final code in etat.domaines.take(6))
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                                color: familleDe(code).couleur, borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                      Text(nbDomaines == 0 ? 'Tout' : '$nbDomaines choisi${nbDomaines > 1 ? 's' : ''}',
                          style: police(policeTexte, taille: 13, couleur: p.texteDiscret)),
                    ]),
                  ]),
                ),
                Icon(Icons.chevron_right_rounded, color: p.texte),
              ]),
            ),
            titreSection('À PROPOS'),
            bloc(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Nos sources',
                    style: police(policeTexte, taille: 16, graisse: FontWeight.w600, couleur: p.texte)),
                const SizedBox(height: 8),
                Text(texteNosSources,
                    style: police(policeTexte, taille: 14, couleur: p.texteDiscret, hauteur: 1.5)),
              ]),
            ),
            const SizedBox(height: 18),
            Center(
              child: Text(texteVersion,
                  textAlign: TextAlign.center, style: police(policeTexte, taille: 12, couleur: p.texteDiscret)),
            ),
          ],
        );
      },
    );
  }
}
