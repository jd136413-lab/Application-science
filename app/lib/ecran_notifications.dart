// Réglages → Notifications : interrupteur, fil, importance minimale,
// limite par arrivée et familles (maquette 17).

import 'package:flutter/material.dart';

import 'etat.dart';
import 'langues.dart';
import 'notifications.dart';
import 'reglages.dart';
import 'widgets.dart';

/// Libellés des niveaux d'importance minimale (1 à 5).
const List<String> niveauxNotif = [
  '',
  'Toutes les avancées',
  'Limité et plus',
  'Notable et plus',
  'Majeur et plus',
  'Rupture seulement',
];

/// Résumé court affiché dans Réglages (« Activées · Majeur et plus · … »).
String resumeNotifications() {
  if (!notificationsPossibles) return tr('Les notifications sont disponibles dans l’app Android et iPhone.');
  if (!etat.notifActives) return tr('Désactivées');
  return '${tr('Activées')} · ${tr(niveauxNotif[etat.notifMin])} · ${_nomFil(etat.notifFil)}';
}

String _nomFil(String fil) => switch (fil) {
      'science' => tr(texteSciences),
      'tech' => tr(texteTechnologies),
      _ => tr('Sciences et Technologies'),
    };

class EcranNotifications extends StatefulWidget {
  const EcranNotifications({super.key});

  @override
  State<EcranNotifications> createState() => _EcranNotificationsState();
}

class _EcranNotificationsState extends State<EcranNotifications> {
  bool _refusee = false;

  Future<void> _basculer() async {
    if (etat.notifActives) {
      etat.changerNotifications(actives: false);
      return;
    }
    final ok = await demanderAutorisation();
    if (!mounted) return;
    setState(() => _refusee = !ok);
    if (ok) etat.changerNotifications(actives: true);
  }

  @override
  Widget build(BuildContext context) {
    final p = palette(context);

    Widget titreSection(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
          child: Text(tr(t).toUpperCase(),
              style: police(policeTexte, taille: 12, graisse: FontWeight.w700, couleur: p.texteDiscret)),
        );

    Widget aide(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(t, style: police(policeTexte, taille: 13, couleur: p.texteDiscret, hauteur: 1.45)),
        );

    /// Sélecteur en pastilles (comme le choix du thème).
    Widget pastilles<T>(List<(T, String)> choix, T actuel, void Function(T) choisir) => Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: p.pastille, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            for (final (valeur, texte) in choix)
              Expanded(
                child: Semantics(
                  selected: valeur == actuel,
                  button: true,
                  child: Material(
                    color: valeur == actuel ? p.carte : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => choisir(valeur),
                      child: SizedBox(
                        height: 42,
                        child: Center(
                          child: Text(texte,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: police(policeTexte,
                                  taille: 14,
                                  graisse: FontWeight.w700,
                                  couleur: valeur == actuel ? p.texte : p.texteDiscret)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        );

    Widget caseACocher(bool coche) => Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: coche ? p.encre : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: coche ? p.encre : p.texteDiscret, width: 2),
          ),
          child: coche ? Icon(Icons.check_rounded, size: 16, color: p.surEncre) : null,
        );

    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) {
        final fils = etat.notifFil == 'both' ? ['science', 'tech'] : [etat.notifFil];
        final visibles = [for (final f in fils) ...famillesDuFil(f)];
        final nbFamilles = visibles.where(etat.notifFamilles.contains).length;
        final limite = etat.notifLimite;

        return Scaffold(
          backgroundColor: p.fond,
          appBar: AppBar(
            backgroundColor: p.fond,
            foregroundColor: p.texte,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(tr('Notifications'),
                style: police(policeTitres, taille: 22, graisse: FontWeight.w800, couleur: p.texte)),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              if (!notificationsPossibles)
                aide(tr('Les notifications sont disponibles dans l’app Android et iPhone.'))
              else ...[
                // Interrupteur général
                Material(
                  color: p.carte,
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: SwitchListTile(
                    value: etat.notifActives,
                    onChanged: (_) => _basculer(),
                    activeTrackColor: familleDe('environment').couleur,
                    contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                    title: Text(tr('Recevoir des notifications'),
                        style: police(policeTexte, taille: 16, graisse: FontWeight.w700, couleur: p.texte)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(tr('Quand de nouvelles avancées arrivent, selon vos choix ci-dessous'),
                          style: police(policeTexte, taille: 13, couleur: p.texteDiscret, hauteur: 1.4)),
                    ),
                  ),
                ),
                if (_refusee) aide(tr('Autorisez les notifications de NovaSTEM dans les réglages du téléphone.')),
                if (!etat.notifActives)
                  aide(tr('Les notifications sont coupées. Les avancées restent consultables dans l’onglet Actualités.'))
                else ...[
                  titreSection('Quelles avancées'),
                  pastilles<String>(
                    [('science', tr(texteSciences)), ('tech', tr(texteTechnologies)), ('both', tr('Les deux'))],
                    etat.notifFil,
                    (v) => etat.changerNotifications(fil: v),
                  ),

                  titreSection('Importance minimale'),
                  Material(
                    color: p.carte,
                    borderRadius: BorderRadius.circular(18),
                    clipBehavior: Clip.antiAlias,
                    child: Column(children: [
                      for (var n = 1; n <= 5; n++) ...[
                        if (n > 1) Divider(height: 1, color: p.bordure),
                        Semantics(
                          selected: etat.notifMin == n,
                          inMutuallyExclusiveGroup: true,
                          child: InkWell(
                            onTap: () => etat.changerNotifications(min: n),
                            child: SizedBox(
                              height: 52,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(children: [
                                  Icon(
                                      etat.notifMin == n
                                          ? Icons.radio_button_checked_rounded
                                          : Icons.radio_button_off_rounded,
                                      color: etat.notifMin == n ? p.texte : p.texteDiscret,
                                      size: 22),
                                  const SizedBox(width: 12),
                                  for (var e = 1; e <= 5; e++)
                                    Icon(Icons.star_rounded,
                                        size: 16, color: e <= n ? couleurEtoiles : p.bordure),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(tr(niveauxNotif[n]),
                                        style: police(policeTexte,
                                            taille: 15, graisse: FontWeight.w600, couleur: p.texte)),
                                  ),
                                ]),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ]),
                  ),

                  titreSection('Au plus, à chaque arrivée'),
                  pastilles<int>(
                    [(1, '1'), (3, '3'), (5, '5'), (0, tr('Toutes'))],
                    limite,
                    (v) => etat.changerNotifications(limite: v),
                  ),
                  aide(limite == 0
                      ? tr('Une notification par avancée, sans regroupement.')
                      : limite == 1
                          ? tr('La plus importante arrive seule ; les suivantes sont regroupées en une seule notification.')
                          : tr('Les {n} plus importantes arrivent une par une ; les suivantes sont regroupées en une seule notification.',
                              n: limite)),

                  titreSection('Familles'),
                  for (final fil in fils) ...[
                    Material(
                      color: p.carte,
                      borderRadius: BorderRadius.circular(18),
                      clipBehavior: Clip.antiAlias,
                      child: Column(children: [
                        Builder(builder: (context) {
                          final duFil = famillesDuFil(fil);
                          final tout = duFil.every(etat.notifFamilles.contains);
                          return InkWell(
                            onTap: () {
                              final n = {...etat.notifFamilles};
                              tout ? n.removeAll(duFil) : n.addAll(duFil);
                              etat.changerNotifications(familles: n);
                            },
                            child: SizedBox(
                              height: 52,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(children: [
                                  Expanded(
                                    child: Text(
                                        '${tr(fil == 'tech' ? texteTechnologies : texteSciences)} · ${tr('Tout')}',
                                        style: police(policeTexte,
                                            taille: 15, graisse: FontWeight.w700, couleur: p.texte)),
                                  ),
                                  caseACocher(tout),
                                ]),
                              ),
                            ),
                          );
                        }),
                        for (final code in famillesDuFil(fil)) ...[
                          Divider(height: 1, color: p.bordure),
                          InkWell(
                            onTap: () {
                              final n = {...etat.notifFamilles};
                              n.contains(code) ? n.remove(code) : n.add(code);
                              etat.changerNotifications(familles: n);
                            },
                            child: SizedBox(
                              height: 48,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(children: [
                                  Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                        color: familleDe(code).couleur, borderRadius: BorderRadius.circular(4)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(tr(familleDe(code).nom),
                                        style: police(policeTexte, taille: 15, couleur: p.texte)),
                                  ),
                                  caseACocher(etat.notifFamilles.contains(code)),
                                ]),
                              ),
                            ),
                          ),
                        ],
                      ]),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Résumé en clair
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: p.bordure, width: 1.5),
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.notifications_none_rounded, color: p.texte, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                            nbFamilles == 0
                                ? tr('Aucune famille cochée : vous ne recevrez aucune notification.')
                                : '${tr('Vous recevrez :')} ${tr(niveauxNotif[etat.notifMin])} · '
                                    '${_nomFil(etat.notifFil)} · '
                                    '${nbFamilles == 1 ? tr('1 famille') : tr('{n} familles', n: nbFamilles)} · '
                                    '${limite == 0 ? tr('Sans limite') : tr('{n} au plus à chaque arrivée', n: limite)}',
                            style: police(policeTexte, taille: 14, couleur: p.texte, hauteur: 1.5)),
                      ),
                    ]),
                  ),
                  aide(tr('Sur certains téléphones (Xiaomi, Huawei…), autorisez aussi le démarrage automatique de NovaSTEM pour recevoir les notifications.')),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}
