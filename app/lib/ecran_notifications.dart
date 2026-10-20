// Réglages → Notifications : formules toutes prêtes (Aucune, Seulement
// l'exceptionnel, L'essentiel, Rester au courant) ou « Sur mesure » (fil,
// importance minimale, limite par arrivée, familles). Maquettes 20 (B) et 21 (B5).

import 'package:flutter/material.dart';

import 'etat.dart';
import 'langues.dart';
import 'notifications.dart';
import 'reglages.dart';
import 'stats.dart';
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

/// Une formule toute prête : importance minimale et nombre au plus par arrivée
/// (fil « les deux » et toutes les familles).
class Formule {
  final String code, titre, sousTitre;
  final int min, limite;
  const Formule(this.code, this.titre, this.sousTitre, this.min, this.limite);
}

const List<Formule> formules = [
  Formule('exceptionnel', 'Seulement l’exceptionnel', 'Les ruptures : très rare', 5, 1),
  Formule('essentiel', 'L’essentiel', 'Les avancées majeures, 1 à la fois', 4, 1),
  Formule('courant', 'Rester au courant', 'Notables et plus, 3 à la fois', 3, 3),
];

/// 'aucune', le code d'une formule, ou 'mesure' si les réglages ne
/// correspondent à aucune formule.
String formuleActuelle() {
  if (!etat.notifActives) return 'aucune';
  final toutes = [...famillesSciences, ...famillesTech].every(etat.notifFamilles.contains);
  if (etat.notifFil == 'both' && toutes) {
    for (final f in formules) {
      if (f.min == etat.notifMin && f.limite == etat.notifLimite) return f.code;
    }
  }
  return 'mesure';
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

/// Résumé court affiché dans Réglages (« Activées · L’essentiel »).
String resumeNotifications() {
  if (!notificationsPossibles) return tr('Les notifications sont disponibles dans l’app Android et iPhone.');
  if (!etat.notifActives) return tr('Désactivées');
  final code = formuleActuelle();
  for (final f in formules) {
    if (f.code == code) return '${tr('Activées')} · ${tr(f.titre)}';
  }
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
  bool _mesure = false; // « Sur mesure » ouvert même si les réglages correspondent à une formule

  /// Message de confirmation en bas de l'écran (maquette 21, B5).
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

  Future<void> _choisir(String code) async {
    stat('notif_formule', valeur: code);
    if (code == 'aucune') {
      etat.changerNotifications(actives: false);
      setState(() => _mesure = false);
      _confirmer(tr('C’est noté : plus de notifications.'));
      return;
    }
    if (!etat.notifActives) {
      final ok = await demanderAutorisation();
      if (!mounted) return;
      setState(() => _refusee = !ok);
      if (!ok) return;
    }
    if (!mounted) return;
    final (a, b) = heuresArrivee(context);
    if (code == 'mesure') {
      etat.changerNotifications(actives: true);
      setState(() => _mesure = true);
      _confirmer(tr('C’est noté : vous serez prévenu vers {a} et {b}.').replaceAll('{a}', a).replaceAll('{b}', b));
      return;
    }
    final f = formules.firstWhere((x) => x.code == code);
    etat.changerNotifications(
        actives: true, fil: 'both', min: f.min, limite: f.limite, familles: {...famillesSciences, ...famillesTech});
    setState(() => _mesure = false);
    _confirmer(tr('C’est noté : vous recevrez « {f} » vers {a} et {b}.')
        .replaceAll('{f}', tr(f.titre))
        .replaceAll('{a}', a)
        .replaceAll('{b}', b));
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
        final formule = formuleActuelle();

        /// Une carte de formule (maquette 20, B) : coche noire si choisie.
        Widget carteFormule(String code, Widget icone, String titre, String sousTitre) {
          final affichee = (_mesure && etat.notifActives) ? code == 'mesure' : code == formule;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Semantics(
              selected: affichee,
              inMutuallyExclusiveGroup: true,
              child: Material(
                color: p.carte,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: affichee ? p.texte : p.bordure, width: affichee ? 2.5 : 1.5),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _choisir(code),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                    child: Row(children: [
                      SizedBox(width: 32, child: Center(child: icone)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(tr(titre),
                              style: police(policeTexte, taille: 16, graisse: FontWeight.w700, couleur: p.texte)),
                          const SizedBox(height: 2),
                          Text(tr(sousTitre),
                              style: police(policeTexte, taille: 13, couleur: p.texteDiscret, hauteur: 1.35)),
                        ]),
                      ),
                      if (affichee)
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(color: p.encre, shape: BoxShape.circle),
                          child: Icon(Icons.check_rounded, size: 16, color: p.surEncre),
                        )
                      else if (code == 'mesure')
                        Icon(Icons.chevron_right_rounded, color: p.texteDiscret),
                    ]),
                  ),
                ),
              ),
            ),
          );
        }

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
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: Text(tr('Choisissez à quelle fréquence être prévenu :'),
                      style: police(policeTexte, taille: 15, couleur: p.texteDiscret, hauteur: 1.4)),
                ),
                carteFormule('aucune', Icon(Icons.notifications_off_outlined, color: p.texteDiscret, size: 24),
                    'Aucune', 'Je regarde l’app quand je veux'),
                for (final f in formules)
                  carteFormule(
                      f.code,
                      Text('★${f.min}',
                          style: police(policeTexte, taille: 14, graisse: FontWeight.w800, couleur: couleurEtoiles)),
                      f.titre,
                      f.sousTitre),
                carteFormule('mesure', Icon(Icons.tune_rounded, color: p.texteDiscret, size: 24), 'Sur mesure',
                    'Fil, importance, nombre et domaines'),
                if (_refusee) aide(tr('Autorisez les notifications de NovaSTEM dans les réglages du téléphone.')),
                if (etat.notifActives && (formule == 'mesure' || _mesure)) ...[
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
                ] else if (etat.notifActives)
                  aide(tr('Sur certains téléphones (Xiaomi, Huawei…), autorisez aussi le démarrage automatique de NovaSTEM pour recevoir les notifications.')),
              ],
            ],
          ),
        );
      },
    );
  }
}
