// Réglages → Notifications (maquettes 26 et 27, 21/10) :
// - interrupteur général ;
// - « Quelles avancées ? » : Sciences, Technologies ou les deux ;
// - importance minimale de 1 à 5 étoiles, avec la fréquence approximative ;
// - « Sur mesure » : famille par famille, la recevoir ou non et son minimum.
// Au plus 2 notifications par arrivée : une Sciences, une Technologies
// (le regroupement est fait par le téléphone, voir notifications_mobile.dart).

import 'package:flutter/material.dart';

import 'etat.dart';
import 'langues.dart';
import 'notifications.dart';
import 'reglages.dart';
import 'stats.dart';
import 'widgets.dart';

/// Libellés des niveaux d'importance minimale (1 à 5), barème du 21/10.
const List<String> niveauxNotif = [
  '',
  'Tout',
  'Notable et plus',
  'Important et plus',
  'Majeur et plus',
  'Rupture seulement',
];

/// Ce que chaque niveau laisse passer (phrase sous les étoiles).
const List<String> explicationsNotif = [
  '',
  'Tout ce que NovaSTEM publie, matin et soir : de vraies avancées, même modestes.',
  'Les avancées notables : un vrai pas en avant dans leur domaine.',
  'Les avancées importantes, qui comptent au-delà de leur domaine.',
  'Seulement les avancées majeures : premières mondiales, grands lancements.',
  'Seulement les ruptures exceptionnelles. Très rare, mais immanquable.',
];

/// Fréquence approximative des NOTIFICATIONS pour une importance minimale :
/// au plus 1 par fil et par arrivée, 2 arrivées par jour. Estimations du
/// barème (≈ 10 avancées par jour : 2/3 à ★, ≈ 3 à ★★ et plus…).
String frequenceNotif(int min, {required bool deuxFils, bool courte = false}) {
  // Nombre de notifications (estimations du barème), puis l'unité de temps.
  final n = switch (min) {
    1 => deuxFils ? '= 4' : '= 2',
    2 => deuxFils ? '≈ 2–3' : '≈ 1–2',
    3 => deuxFils ? '≈ 2–4' : '≈ 1–2',
    _ => deuxFils ? '≈ 1–3' : '≈ 1–2',
  };
  final nombre = etat.langue == 'fr' ? n.replaceAll('–', ' à ') : n;
  if (courte) return tr('{n}/jour').replaceAll('{n}', n.replaceAll('≈ ', '').replaceAll('= ', ''));
  final modele = switch (min) {
    1 || 2 => '{n} notifications par jour',
    3 => '{n} notifications par semaine',
    4 => '{n} notifications par mois',
    _ => '{n} notifications par an',
  };
  return tr(modele).replaceAll('{n}', nombre);
}

/// Dernier dimanche d'un mois (pour l'heure d'été européenne).
int _dernierDimanche(int annee, int mois) {
  final dernier = DateTime.utc(annee, mois + 1, 0);
  return dernier.day - (dernier.weekday % 7);
}

/// Convertit une heure de Paris (heuresArriveeParis) en heure du téléphone.
DateTime _parisVersTelephone(int h, int m) {
  final now = DateTime.now();
  final a = now.year;
  final ete = DateTime.utc(a, 3, _dernierDimanche(a, 3), 1);
  final hiver = DateTime.utc(a, 10, _dernierDimanche(a, 10), 1);
  final brut = DateTime.utc(now.year, now.month, now.day, h, m);
  final decalage = (brut.isAfter(ete) && brut.isBefore(hiver)) ? 2 : 1; // Paris : UTC+2 l'été, UTC+1 l'hiver
  return brut.subtract(Duration(hours: decalage)).toLocal();
}

/// Les deux heures d'arrivée des avancées, à l'heure du téléphone, dans l'ordre
/// de la journée (« 8 h 30 » en français, « 8:30 AM » en anglais…).
(String, String) heuresArrivee(BuildContext context) {
  final heures = [for (final (h, m) in heuresArriveeParis) _parisVersTelephone(h, m)]
    ..sort((x, y) => (x.hour * 60 + x.minute).compareTo(y.hour * 60 + y.minute));
  String format(DateTime t) => etat.langue == 'fr'
      ? '${t.hour} h ${t.minute.toString().padLeft(2, '0')}'
      : MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(t),
          alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat);
  return (format(heures.first), format(heures.last));
}

/// Résumé court affiché dans Réglages (« Activées · Notable et plus · Sciences et Technologies »).
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
  late bool _surMesure = etat.notifParFamille.isNotEmpty; // ouvert d'emblée s'il est utilisé

  /// Message de confirmation en bas de l'écran.
  void _confirmer(String texte) {
    final p = palette(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.encre,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 4),
        content: Row(children: [
          const Icon(Icons.schedule_rounded, color: couleurEtoiles, size: 22),
          const SizedBox(width: 12),
          Expanded(
              child: Text(texte, style: police(policeTexte, taille: 14, couleur: p.surEncre, hauteur: 1.4))),
        ]),
      ));
  }

  void _stat() => stat('notif_formule',
      valeur: etat.notifActives
          ? 'min${etat.notifMin}_${etat.notifFil}${etat.notifParFamille.isEmpty ? '' : '_mesure'}'
          : 'aucune');

  Future<void> _basculerActives(bool oui) async {
    if (!oui) {
      etat.changerNotifications(actives: false);
      _stat();
      _confirmer(tr('C’est noté : plus de notifications.'));
      return;
    }
    final ok = await demanderAutorisation();
    if (!mounted) return;
    setState(() => _refusee = !ok);
    if (!ok) return;
    etat.changerNotifications(actives: true);
    _stat();
    final (a, b) = heuresArrivee(context);
    _confirmer(tr('C’est noté : vous serez prévenu vers {a} et {b}.').replaceAll('{a}', a).replaceAll('{b}', b));
  }

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    
    Widget aide(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(t, style: police(policeTexte, taille: 13, couleur: p.texteDiscret, hauteur: 1.45)),
        );

    Widget bloc(List<Widget> enfants, {EdgeInsets padding = const EdgeInsets.all(16)}) => Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: padding,
          decoration: BoxDecoration(color: p.carte, borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: enfants),
        );

    Widget titreBloc(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(tr(t), style: police(policeTexte, taille: 15, graisse: FontWeight.w800, couleur: p.texte)),
        );

    /// Sélecteur en pastilles (Sciences / Technologies / Les deux).
    Widget pastilles(List<(String, String)> choix, String actuel, void Function(String) choisir) => Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: p.pastille, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            for (final (valeur, texte) in choix)
              Expanded(
                child: Semantics(
                  selected: valeur == actuel,
                  button: true,
                  child: Material(
                    color: valeur == actuel ? p.encre : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(11),
                      onTap: () => choisir(valeur),
                      child: SizedBox(
                        height: 44,
                        child: Center(
                          child: Text(texte,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: police(policeTexte,
                                  taille: 14,
                                  graisse: FontWeight.w700,
                                  couleur: valeur == actuel ? p.surEncre : p.texte)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        );

    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) {
        final deux = etat.notifFil == 'both';
        final fils = deux ? ['science', 'tech'] : [etat.notifFil];
        final min = etat.notifMin;

        /// Les 5 niveaux en liste (comme la planche 17) : bouton radio, petites
        /// étoiles, niveau, fréquence ; l'explication sous le niveau choisi.
        Widget listeNiveaux() => Material(
              color: Colors.transparent,
              child: Column(children: [
                for (var k = 1; k <= 5; k++) ...[
                  if (k > 1) Divider(height: 1, color: p.bordure),
                  Semantics(
                    selected: k == min,
                    inMutuallyExclusiveGroup: true,
                    child: InkWell(
                      onTap: () {
                        etat.changerNotifications(min: k);
                        _stat();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(k == min ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                              color: k == min ? p.texte : p.texteDiscret, size: 22),
                          const SizedBox(width: 12),
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              for (var e = 1; e <= 5; e++)
                                Icon(Icons.star_rounded, size: 16, color: e <= k ? couleurEtoiles : p.bordure),
                            ]),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(tr(niveauxNotif[k]),
                                  style: police(policeTexte, taille: 15, graisse: FontWeight.w600, couleur: p.texte)),
                              const SizedBox(height: 2),
                              Text(frequenceNotif(k, deuxFils: deux),
                                  style: police(policeTexte, taille: 13, couleur: p.texteDiscret)),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ],
              ]),
            );

        /// Une famille dans « Sur mesure » : interrupteur + 5 petites étoiles.
        Widget ligneFamille(String code) {
          final f = familleDe(code);
          final m = etat.minDeFamille(code);
          final active = m > 0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                      color: active ? f.couleur : p.bordure, borderRadius: BorderRadius.circular(9)),
                  child: Icon(f.symbole, size: 18, color: active ? f.icone : p.texteDiscret),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(tr(f.nom),
                      style: police(policeTexte,
                          taille: 15, graisse: FontWeight.w600, couleur: active ? p.texte : p.texteDiscret)),
                ),
                Switch(
                  value: active,
                  activeTrackColor: p.encre,
                  onChanged: (oui) {
                    etat.changerFamilleNotif(code, oui ? null : 0);
                    _stat();
                  },
                ),
              ]),
              if (active)
                Padding(
                  padding: const EdgeInsets.only(left: 38),
                  child: Row(children: [
                    for (var k = 1; k <= 5; k++)
                      Semantics(
                        button: true,
                        label: '${tr(f.nom)} : ${tr(niveauxNotif[k])}',
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            etat.changerFamilleNotif(code, k == etat.notifMin ? null : k);
                            _stat();
                          },
                          child: SizedBox(
                            width: 34,
                            height: 34,
                            child: Icon(Icons.star_rounded, size: 24, color: k <= m ? couleurEtoiles : p.bordure),
                          ),
                        ),
                      ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                          tr(niveauxNotif[m]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: police(policeTexte, taille: 12, graisse: FontWeight.w700, couleur: p.texteDiscret)),
                    ),
                  ]),
                ),
            ]),
          );
        }

        final coupees = [for (final fil in fils) ...famillesDuFil(fil)].where((c) => etat.minDeFamille(c) == 0);
        final toutCoupe = coupees.length == [for (final fil in fils) ...famillesDuFil(fil)].length;

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
                bloc([
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(tr('Recevoir des notifications'),
                            style: police(policeTexte, taille: 16, graisse: FontWeight.w700, couleur: p.texte)),
                        const SizedBox(height: 2),
                        Builder(builder: (context) {
                          final (a, b) = heuresArrivee(context);
                          return Text(
                              tr('Vers {a} et {b}')
                                  .replaceAll('{a}', a)
                                  .replaceAll('{b}', b),
                              style: police(policeTexte, taille: 13, couleur: p.texteDiscret, hauteur: 1.4));
                        }),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Switch(value: etat.notifActives, activeTrackColor: p.encre, onChanged: _basculerActives),
                  ]),
                ], padding: const EdgeInsets.fromLTRB(16, 12, 10, 12)),
                if (_refusee) aide(tr('Autorisez les notifications de NovaSTEM dans les réglages du téléphone.')),

                if (etat.notifActives) ...[
                  // 1. Quel fil
                  bloc([
                    pastilles(
                      [('science', tr(texteSciences)), ('tech', tr(texteTechnologies)), ('both', tr('Les deux'))],
                      etat.notifFil,
                      (v) {
                        etat.changerNotifications(fil: v);
                        _stat();
                      },
                    ),
                  ]),

                  // 2. Importance minimale
                  bloc([
                    listeNiveaux(),
                  ]),

                  // 3. Sur mesure
                  bloc([
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _surMesure = !_surMesure),
                      child: SizedBox(
                        height: 56,
                        child: Row(children: [
                          Expanded(
                            child: Text(tr('Sur mesure'),
                                style: police(policeTexte, taille: 15, graisse: FontWeight.w800, couleur: p.texte)),
                          ),
                          AnimatedRotation(
                            turns: _surMesure ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(Icons.expand_more_rounded, color: p.texte),
                          ),
                        ]),
                      ),
                    ),
                    if (_surMesure) ...[
                      for (final fil in fils) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 16, 0, 2),
                          child: Text(tr(fil == 'tech' ? texteTechnologies : texteSciences).toUpperCase(),
                              style: police(policeTexte,
                                  taille: 12, graisse: FontWeight.w800, couleur: p.texteDiscret)),
                        ),
                        for (final code in famillesDuFil(fil)) ...[
                          Divider(height: 1, color: p.bordure),
                          ligneFamille(code),
                        ],
                      ],
                    ],
                  ], padding: const EdgeInsets.fromLTRB(16, 4, 12, 8)),

                  if (toutCoupe) aide(tr('Aucune famille gardée : vous ne recevrez aucune notification.')),
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
