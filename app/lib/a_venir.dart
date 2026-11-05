// Onglet « À venir » (maquette 70, choix de Maxime du 01/11/2026).
//
// Les événements datés repérés par l'agent (lancements, sorties de produits,
// résultats attendus, événements dans le ciel, grands sommets), rangés en
// « Cette semaine », « Ce mois-ci », « Plus tard », avec un compte à rebours.
// « Me le rappeler » programme une notification sur le téléphone le jour J ;
// « Ajouter à mon agenda » ouvre Google Agenda. Quand l'avancée paraît, la
// carte passe dans « C'est arrivé » et mène à la fiche.
// Une rubrique « À venir » existe aussi dans l'accueil (désactivée par défaut,
// Personnaliser l'accueil). Table Supabase : upcoming_events (migration 009).

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'carte.dart' show ouvrirArticle;
import 'detail.dart';
import 'donnees.dart';
import 'etat.dart';
import 'langues.dart';
import 'modele.dart' show enTeteMois, SourceAvancee;
import 'notifications.dart';
import 'regions_monde.dart';
import 'reglages.dart';
import 'retours.dart';
import 'texte_article.dart';
import 'widgets.dart';

// ------------------------------------------------------------------ dates (heure de Paris)

bool _heureEte(DateTime utc) {
  DateTime dernierDimanche(int annee, int mois) {
    var d = DateTime.utc(annee, mois + 1, 1).subtract(const Duration(days: 1));
    while (d.weekday != DateTime.sunday) {
      d = d.subtract(const Duration(days: 1));
    }
    return d;
  }

  final debut = dernierDimanche(utc.year, 3).add(const Duration(hours: 1));
  final fin = dernierDimanche(utc.year, 10).add(const Duration(hours: 1));
  return !utc.isBefore(debut) && utc.isBefore(fin);
}

/// Heure de Paris → instant UTC.
DateTime parisVersUtc(int a, int m, int j, [int h = 0, int min = 0]) {
  final naif = DateTime.utc(a, m, j, h, min);
  return naif.subtract(Duration(hours: _heureEte(naif.subtract(const Duration(hours: 1))) ? 2 : 1));
}

/// Aujourd'hui à Paris (date seule, en UTC pour éviter les surprises).
DateTime aujourdhuiParis() {
  final u = DateTime.now().toUtc();
  final p = u.add(Duration(hours: _heureEte(u) ? 2 : 1));
  return DateTime.utc(p.year, p.month, p.day);
}

// ------------------------------------------------------------------ modèle

/// Une ligne du bloc « En pratique » (écrite par l'agent).
class LignePratique {
  final String icone, titre, texte;
  const LignePratique(this.icone, this.titre, this.texte);
}

class Evenement {
  final String id, titre, type, fil, sourceUrl, sourceNom, precision, statut;
  final String? prevu, pourquoi, famille, heure, avanceeId;
  final String? lieu, lienDirect, lienDirectNom, visibleTexte, statutRaison;
  final DateTime date; // jour seul (UTC)
  final DateTime? datePrecedente, fin, instantExact;
  final List<LignePratique> pratique;
  final List<String> visibleRegions, visiblePartiel;
  /// Autres médias qui parlent du même événement (colonne autres_sources, migration 012).
  final List<SourceAvancee> autresSources;
  final int importance;
  const Evenement({
    required this.id,
    required this.titre,
    required this.type,
    required this.fil,
    required this.sourceUrl,
    required this.sourceNom,
    required this.precision,
    required this.date,
    required this.importance,
    this.prevu,
    this.pourquoi,
    this.famille,
    this.heure,
    this.avanceeId,
    this.datePrecedente,
    this.statut = 'prevu',
    this.statutRaison,
    this.lieu,
    this.lienDirect,
    this.lienDirectNom,
    this.visibleTexte,
    this.fin,
    this.instantExact,
    this.pratique = const [],
    this.visibleRegions = const [],
    this.visiblePartiel = const [],
    this.autresSources = const [],
  });

  static List<String> _liste(Object? v) => v is List ? [for (final x in v) '$x'] : const [];

  static List<LignePratique> _pratique(Object? v) {
    if (v is String) {
      try {
        v = jsonDecode(v);
      } catch (_) {
        return const [];
      }
    }
    if (v is! List) return const [];
    return [
      for (final x in v)
        if (x is Map && '${x['t'] ?? ''}'.isNotEmpty && '${x['v'] ?? ''}'.isNotEmpty)
          LignePratique('${x['k'] ?? 'info'}', '${x['t']}', '${x['v']}'),
    ];
  }

  static DateTime? _jour(Object? v) {
    final d = DateTime.tryParse('${v ?? ''}');
    return d == null ? null : DateTime.utc(d.year, d.month, d.day);
  }

  factory Evenement.depuisJson(Map<String, dynamic> j) => Evenement(
        id: '${j['id']}',
        titre: '${j['title'] ?? ''}',
        prevu: j['prevu'] as String?,
        pourquoi: j['pourquoi'] as String?,
        type: '${j['type'] ?? 'evenement'}',
        famille: j['family'] as String?,
        fil: j['feed'] == 'tech' ? 'tech' : 'science',
        date: _jour(j['event_date']) ?? aujourdhuiParis(),
        heure: j['event_time'] as String?,
        precision: j['precision'] == 'mois' || j['precision'] == 'avant' ? '${j['precision']}' : 'jour',
        importance: (j['importance'] as num?)?.toInt() ?? 2,
        autresSources: [
          for (final x in (j['autres_sources'] is List ? j['autres_sources'] as List : const []))
            if (x is Map && '${x['nom'] ?? ''}'.isNotEmpty && '${x['url'] ?? ''}'.isNotEmpty)
              SourceAvancee('${x['nom']}', '${x['url']}', '${x['langue'] ?? ''}', DateTime.tryParse('${x['date'] ?? ''}')),
        ],
        sourceUrl: '${j['source_url'] ?? ''}',
        sourceNom: '${j['source_name'] ?? ''}',
        datePrecedente: _jour(j['previous_date']),
        avanceeId: j['advance_id'] as String?,
        statut: '${j['statut'] ?? 'prevu'}',
        statutRaison: j['statut_raison'] as String?,
        lieu: j['lieu'] as String?,
        lienDirect: j['lien_direct'] as String?,
        lienDirectNom: j['lien_direct_nom'] as String?,
        visibleTexte: j['visible_texte'] as String?,
        fin: _jour(j['event_end']),
        instantExact: DateTime.tryParse('${j['event_utc'] ?? ''}')?.toUtc(),
        pratique: _pratique(j['pratique']),
        visibleRegions: _liste(j['visible_regions']),
        visiblePartiel: _liste(j['visible_partiel']),
      );

  Famille get fam => familleDe(famille ?? (fil == 'tech' ? 'tech_other' : 'other'));
  bool get arrive => avanceeId != null;

  /// Jours avant l'événement (0 = aujourd'hui, négatif = passé).
  int get jours => date.difference(aujourdhuiParis()).inDays;

  /// Jours avant le dernier jour (salon, sommet…) ; = jours pour un événement d'un jour.
  int get joursFin => (fin ?? date).difference(aujourdhuiParis()).inDays;

  bool get annule => statut == 'annule';
  bool get reporte => statut == 'reporte' && datePrecedente != null;
  bool get dateFloue => precision != 'jour';
  bool get enCours => jours < 0 && joursFin >= 0;

  /// Instant de l'événement (début de journée si l'heure n'est pas connue).
  DateTime get instant {
    if (instantExact != null) return instantExact!;
    final hm = (heure ?? '').split(':');
    final h = hm.length == 2 ? int.tryParse(hm[0]) : null;
    final m = hm.length == 2 ? int.tryParse(hm[1]) : null;
    return parisVersUtc(date.year, date.month, date.day, h ?? 0, m ?? 0);
  }
}

const Map<String, String> nomsTypes = {
  'lancement': 'Lancement',
  'arrivee': 'Sonde spatiale',
  'ciel': 'Dans le ciel',
  'sortie': 'Sortie',
  'presentation': 'Présentation',
  'salon': 'Salon',
  'sommet': 'Sommet',
  'resultats': 'Résultats attendus',
  'decision': 'Décision',
  'prix': 'Prix',
  'mise_en_service': 'Mise en service',
  'essai': 'Premier vol, essai',
  'evenement': 'Événement',
  'annonce': 'Annonce',
};

/// Jour de l'événement sur le téléphone (l'heure exacte peut tomber un autre jour qu'à Paris).
DateTime jourLocal(Evenement e) {
  if (e.instantExact != null) {
    final l = e.instantExact!.toLocal();
    return DateTime(l.year, l.month, l.day);
  }
  return DateTime(e.date.year, e.date.month, e.date.day);
}

/// « 14 h 00 » en français, « 2:00 PM » en anglais… à l'heure du téléphone.
String heureLocale(DateTime utc) {
  final l = utc.toLocal();
  if (etat.langue == 'fr') return '${l.hour} h ${l.minute.toString().padLeft(2, '0')}';
  return DateFormat.jm(etat.langue).format(l);
}

String _mois(DateTime d, {bool court = false}) => DateFormat(court ? 'MMM' : 'MMMM', etat.langue).format(d);

String dateEvenement(Evenement e, {bool longue = false}) {
  final d = jourLocal(e);
  if (e.precision == 'mois') return DateFormat('LLLL y', etat.langue).format(d);
  if (e.precision == 'avant') {
    final annee = d.year != DateTime.now().year ? ' ${d.year}' : '';
    return trv('D’ici fin {mois}', {'mois': '${_mois(d)}$annee'});
  }
  if (e.fin != null && e.fin!.isAfter(e.date)) {
    final f = DateTime(e.fin!.year, e.fin!.month, e.fin!.day);
    final debut = d.month == f.month ? DateFormat('d', etat.langue).format(d) : DateFormat('d MMM', etat.langue).format(d);
    return trv('Du {debut} au {fin}', {'debut': debut, 'fin': DateFormat(longue ? 'd MMMM' : 'd MMM', etat.langue).format(f)});
  }
  return DateFormat(longue ? 'EEEE d MMMM' : 'EEE d MMM', etat.langue).format(d);
}

String etiquetteJours(Evenement e) {
  if (e.precision != 'jour' && e.jours > 1) {
    final m = _mois(jourLocal(e), court: true).toUpperCase();
    return e.precision == 'avant' ? '≤ $m' : m;
  }
  final n = e.jours;
  if (e.enCours) return tr('EN COURS');
  if (n <= 0) return tr('AUJ.');
  if (n == 1) return tr('DEMAIN');
  return 'J-$n';
}

// ------------------------------------------------------------------ chargement

class EvenementsAVenir extends ChangeNotifier {
  List<Evenement>? liste;
  bool enCours = false;
  bool horsLigne = false;
  bool _demarre = false;
  static const _cle = 'a_venir_garde';

  void demarrer() {
    if (_demarre) return;
    _demarre = true;
    () async {
      try {
        final p = await SharedPreferences.getInstance();
        final t = p.getString(_cle);
        if (t != null && liste == null) {
          liste = [for (final j in jsonDecode(t) as List) Evenement.depuisJson(Map<String, dynamic>.from(j as Map))];
          notifyListeners();
        }
      } catch (_) {}
      await charger();
    }();
  }

  Future<void> charger() async {
    if (enCours) return;
    enCours = true;
    notifyListeners();
    try {
      final depuis = aujourdhuiParis().subtract(const Duration(days: 7)).toIso8601String().substring(0, 10);
      final lignes = await Supabase.instance.client
          .from('upcoming_events')
          .select()
          .gte('event_date', depuis)
          .order('event_date')
          .limit(200);
      liste = [for (final j in lignes) Evenement.depuisJson(Map<String, dynamic>.from(j))];
      horsLigne = false;
      try {
        final p = await SharedPreferences.getInstance();
        await p.setString(_cle, jsonEncode(lignes));
      } catch (_) {}
      unawaited(reprogrammerRappels());
    } on PostgrestException {
      liste ??= []; // table pas encore créée (migration 009) : onglet vide
    } catch (_) {
      horsLigne = liste != null;
      liste ??= [];
    } finally {
      enCours = false;
      notifyListeners();
    }
  }

  /// Événements à montrer : seulement les domaines choisis au premier lancement / dans les Réglages.
  List<Evenement> visibles({String? fil}) {
    final l = liste ?? const <Evenement>[];
    return l
        .where((e) =>
            (fil == null || e.fil == fil) &&
            // Seulement les domaines choisis (tous si aucun n'a été choisi).
            (etat.domaines.isEmpty || etat.domaines.contains(e.famille)))
        .toList();
  }

  List<Evenement> prochains({String? fil}) =>
      visibles(fil: fil).where((e) => !e.arrive && e.joursFin >= 0).toList()..sort((a, b) => a.date.compareTo(b.date));

  int get cetteSemaine => prochains().where((e) => e.jours <= 7).length;
}

final evenementsAVenir = EvenementsAVenir();

// ------------------------------------------------------------------ rappels

int idRappel(Evenement e) => idRappelEvenement(e.id);

String _heureTexte(String hhmm) => '${tr('vers')} ${hhmm.replaceFirst(':', ' h ').replaceAll(' h 00', ' h')}';

/// Quand le téléphone se manifeste lui-même (maquette 72, choix de Maxime) :
/// - « dans le ciel » : le soir même à 21 h 30 (ou une heure avant l'heure connue, ex. éclipse) ;
/// - les autres : PAS de rappel le jour J (rien à lire) ; l'agent prévient quand la fiche
///   est publiée (« C'est arrivé », notification par internet). Ici, seulement le message de
///   secours, le lendemain à midi, si rien n'est paru.
/// Null si le moment est passé.
DateTime? momentRappel(Evenement e) {
  final maintenant = DateTime.now().toUtc().add(const Duration(minutes: 1));
  DateTime quand;
  if (e.annule) return null;
  if (e.type == 'ciel') {
    // À l'heure du téléphone : une heure avant l'heure exacte, sinon le soir même à 21 h 30.
    final j = jourLocal(e);
    quand = e.instantExact != null || e.heure != null
        ? e.instant.subtract(const Duration(hours: 1))
        : DateTime(j.year, j.month, j.day, 21, 30).toUtc();
  } else {
    final dernier = e.fin ?? e.date;
    final lendemain = e.precision == 'mois'
        ? DateTime.utc(e.date.year, e.date.month + 1, 1)
        : dernier.add(const Duration(days: 1));
    quand = DateTime(lendemain.year, lendemain.month, lendemain.day, 12, 0).toUtc();
  }
  return quand.isAfter(maintenant) ? quand : null;
}

Future<bool> _programmer(Evenement e) async {
  final quand = momentRappel(e);
  if (quand == null) return false;
  final titre = texteDansLaLangue(e.titre);
  if (e.type == 'ciel') {
    return programmerRappel(
      id: idRappel(e),
      quandUtc: quand,
      titre: e.instantExact != null
          ? '${tr('C’est aujourd’hui')} · ${heureLocale(e.instantExact!)}'
          : e.heure != null
              ? '${tr('C’est aujourd’hui')} · ${_heureTexte(e.heure!)}'
              : tr('Ce soir'),
      texte: '$titre · ${tr('Regardez le ciel, loin des lumières.')}',
      payload: 'avenir:${e.id}',
    );
  }
  return programmerRappel(
    id: idRappel(e),
    quandUtc: quand,
    titre: tr('Pas encore de nouvelles'),
    texte: '$titre · ${tr('La date a peut-être changé. On vous prévient dès qu’il y a du nouveau.')}',
    payload: 'avenir:${e.id}',
  );
}

Future<void> basculerRappel(BuildContext context, Evenement e) async {
  if (etat.rappels.contains(e.id)) {
    await annulerRappel(idRappel(e));
    await desabonnerEvenement(e.id);
    etat.retirerRappel(e.id);
    if (context.mounted) afficherMessage(context, tr('Rappel annulé'), icone: Icons.notifications_off_outlined);
    return;
  }
  if (!notificationsPossibles) {
    afficherMessage(context, tr('Les rappels marchent dans l’app sur téléphone.'), icone: Icons.info_outline_rounded);
    return;
  }
  if (e.annule) {
    afficherMessage(context, tr('Annulé'), icone: Icons.event_busy_rounded);
    return;
  }
  if (e.type == 'ciel' && momentRappel(e) == null) {
    afficherMessage(context, tr('C’est aujourd’hui !'), icone: Icons.today_rounded);
    return;
  }
  final permis = await demanderAutorisation();
  if (!context.mounted) return;
  if (!permis) {
    afficherMessage(context, tr('Autorisez les notifications pour recevoir le rappel.'),
        icone: Icons.notifications_off_outlined);
    return;
  }
  final programme = await _programmer(e);
  if (e.type == 'ciel' && !programme) {
    if (context.mounted) {
      afficherMessage(context, tr('Impossible de programmer le rappel.'), icone: Icons.error_outline_rounded);
    }
    return;
  }
  await abonnerEvenement(e.id); // reports et annulations (et « C'est arrivé »)
  etat.ajouterRappel(e.id);
  if (!context.mounted) return;
  if (e.type == 'ciel') {
    final h = e.instantExact != null
        ? heureLocale(e.instantExact!)
        : e.heure != null
            ? _heureTexte(e.heure!)
            : '${tr('vers')} 21 h 30';
    afficherMessage(context, '${tr('Rappel prévu')} · ${dateEvenement(e)} $h', icone: Icons.notifications_active_outlined);
  } else {
    afficherMessage(context, tr('Vous serez prévenu dès que l’article sera publié.'),
        icone: Icons.notifications_active_outlined);
  }
}

/// À l'ouverture : dates changées par l'agent (les rappels suivent), événements arrivés
/// (plus rien à attendre) et événements passés (oubliés).
Future<void> reprogrammerRappels() async {
  if (!notificationsPossibles || etat.rappels.isEmpty) return;
  final l = evenementsAVenir.liste ?? const <Evenement>[];
  for (final id in etat.rappels.toList()) {
    final e = l.where((x) => x.id == id).firstOrNull;
    final fini = e == null || e.arrive || e.annule || (e.type == 'ciel' ? e.joursFin < 0 : e.joursFin < -7);
    if (fini) {
      if (e != null) await annulerRappel(idRappel(e));
      await desabonnerEvenement(id);
      etat.retirerRappel(id);
      continue;
    }
    await annulerRappel(idRappel(e));
    await _programmer(e);
    await abonnerEvenement(id);
  }
}

Future<void> ajouterAgenda(Evenement e) async {
  String f(DateTime d) => DateFormat('yyyyMMdd').format(d);
  String dates;
  if ((e.instantExact != null || e.heure != null) && e.precision == 'jour') {
    final d = e.instant;
    String u(DateTime x) => '${DateFormat('yyyyMMdd').format(x)}T${DateFormat('HHmmss').format(x)}Z';
    dates = '${u(d)}/${u(d.add(const Duration(hours: 1)))}';
  } else {
    dates = '${f(e.date)}/${f((e.fin ?? e.date).add(const Duration(days: 1)))}';
  }
  final details = [
    if ((e.prevu ?? '').isNotEmpty) e.prevu!,
    if ((e.pourquoi ?? '').isNotEmpty) e.pourquoi!,
    if ((e.lienDirect ?? '').isNotEmpty) '${tr('En direct')} : ${e.lienDirect}',
    '${tr('Source')} : ${e.sourceNom} ${e.sourceUrl}',
    'NovaSTEM',
  ].join('\n\n');
  final uri = Uri.https('calendar.google.com', '/calendar/render', {
    'action': 'TEMPLATE',
    'text': e.titre,
    'dates': dates,
    'details': details,
    if ((e.lieu ?? '').isNotEmpty) 'location': e.lieu!,
  });
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

// ------------------------------------------------------------------ ouvrir

void ouvrirEvenement(BuildContext context, Evenement e) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => EcranEvenement(evenement: e)));

Future<void> ouvrirAvanceeArrivee(BuildContext context, Evenement e) async {
  if (e.avanceeId == null) return;
  try {
    final a = await chargerAvancee(e.avanceeId!);
    if (a == null || !context.mounted) return;
    etat.marquerLue(a.id);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => EcranDetail(avancee: a)));
  } catch (_) {
    if (context.mounted) afficherMessage(context, tr(texteErreur), icone: Icons.wifi_off_rounded);
  }
}

// ------------------------------------------------------------------ éléments

class PastilleJours extends StatelessWidget {
  final Evenement e;
  final double taille;
  const PastilleJours(this.e, {super.key, this.taille = 52});

  @override
  Widget build(BuildContext context) {
    final f = e.fam;
    final t = etiquetteJours(e);
    return Container(
      width: taille,
      height: taille,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: f.couleur, borderRadius: BorderRadius.circular(16)),
      child: Text(t,
          textAlign: TextAlign.center,
          style: police(policeTitres, taille: t.length > 4 ? 11 : 15, graisse: FontWeight.w800, couleur: f.icone)),
    );
  }
}

/// Icône de ce qui se passe, devant le type (maquette 83 C).
const Map<String, String> iconesTypes = {
  'lancement': '🚀',
  'arrivee': '🛰️',
  'ciel': '🌠',
  'sortie': '📦',
  'presentation': '🎤',
  'salon': '🏛️',
  'sommet': '🌍',
  'resultats': '📊',
  'decision': '⚖️',
  'prix': '🏆',
  'mise_en_service': '⚡',
  'essai': '✈️',
  'evenement': '📅',
  'annonce': '📣',
};

String iconeEvenement(Evenement e) {
  if (e.type == 'sortie' && e.famille == 'gaming') return '🎮';
  return iconesTypes[e.type] ?? '📅';
}

/// Titre de la liste : sans le thème du début (« Ciel : la pluie… » → « La pluie… »),
/// le type et l'icône le disent déjà (maquette 83 C). Le détail garde le titre complet.
String titreCourt(String titre) {
  final i = titre.indexOf(' : ');
  if (i <= 0 || titre.substring(0, i).split(' ').length > 3) return titre;
  final reste = titre.substring(i + 3).trim();
  if (reste.isEmpty) return titre;
  return reste[0].toUpperCase() + reste.substring(1);
}

/// Vignette « compte à rebours » : gros chiffre + « jours » (maquette 83 C).
class VignetteJours extends StatelessWidget {
  final Evenement e;
  const VignetteJours(this.e, {super.key});

  @override
  Widget build(BuildContext context) {
    final f = e.fam;
    final d = jourLocal(e);
    String grand, petit;
    if (e.precision != 'jour' && e.jours > 1) {
      final m = _mois(d, court: true).replaceAll('.', '');
      if (e.precision == 'avant') {
        grand = '≤';
        petit = m;
      } else {
        grand = m;
        petit = '${d.year}';
      }
    } else if (e.enCours) {
      grand = '●';
      petit = tr('EN COURS');
    } else if (e.jours <= 0) {
      grand = tr('AUJ.');
      petit = '';
    } else if (e.jours == 1) {
      grand = tr('DEMAIN');
      petit = '';
    } else {
      grand = '${e.jours}';
      petit = tr('jours');
    }
    final long = grand.length > 3;
    return Container(
      width: 50,
      height: 54,
      decoration: BoxDecoration(color: f.couleur, borderRadius: BorderRadius.circular(15)),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(grand,
              maxLines: 1,
              style: police(policeTitres, taille: long ? 13 : 22, graisse: FontWeight.w800, couleur: f.icone, hauteur: 1)),
        ),
        if (petit.isNotEmpty) ...[
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(petit,
                maxLines: 1,
                style: police(policeTexte, taille: 10, graisse: FontWeight.w700, couleur: f.icone, hauteur: 1)),
          ),
        ],
      ]),
    );
  }
}

class LigneEvenement extends StatelessWidget {
  final Evenement e;
  const LigneEvenement(this.e, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final rappel = etat.rappels.contains(e.id);
    final encre = estSombre(context) ? e.fam.encreSombre : e.fam.encreClaire;
    return Material(
      color: p.carte,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => ouvrirEvenement(context, e),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          // Maquette 83 C : compte à rebours, icône + type + date, titre court, pourquoi ça compte.
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            VignetteJours(e),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${iconeEvenement(e)} ${tr(nomsTypes[e.type] ?? 'Événement')} · ${dateEvenement(e)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: police(policeTexte, taille: 11.5, graisse: FontWeight.w800, couleur: encre)),
                const SizedBox(height: 3),
                TexteArticle(e.titre,
                    nettoyer: titreCourt,
                    style: police(policeTitres, taille: 15.5, graisse: FontWeight.w700, couleur: p.texte, hauteur: 1.2)
                        .copyWith(decoration: e.annule ? TextDecoration.lineThrough : null)),
                // Annulé, reporté ou visibilité dans le ciel : l'information la plus utile d'abord.
                ...ligneCarte(context, e, statutSeulement: true),
                if (!e.annule && !e.reporte && (e.pourquoi ?? '').isNotEmpty) ...[
                  const SizedBox(height: 3),
                  TexteArticle(e.pourquoi!,
                      maxLines: 2,
                      style: police(policeTexte, taille: 12, couleur: p.texteDiscret, hauteur: 1.3)),
                ] else if (!e.annule && !e.reporte && e.type != 'ciel')
                  ...ligneCarte(context, e),
              ]),
            ),
            IconButton(
              tooltip: tr(rappel ? 'Rappel annulé' : 'Me le rappeler'),
              onPressed: () => basculerRappel(context, e),
              icon: Icon(rappel ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                  color: rappel ? p.texte : p.texteDiscret),
            ),
          ]),
        ),
      ),
    );
  }
}

class CarteArrivee extends StatelessWidget {
  final Evenement e;
  const CarteArrivee(this.e, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    return Material(
      color: p.carte,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => ouvrirAvanceeArrivee(context, e),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFF12A37F), borderRadius: BorderRadius.circular(8)),
              child: Text('${tr('C’est arrivé')} · ${dateEvenement(e)}'.toUpperCase(),
                  style: police(policeTexte, taille: 10.5, graisse: FontWeight.w800, couleur: Colors.white)),
            ),
            const SizedBox(height: 8),
            TexteArticle(e.titre,
                style: police(policeTitres, taille: 15.5, graisse: FontWeight.w700, couleur: p.texte, hauteur: 1.2)),
            const SizedBox(height: 6),
            Text('${tr('Lire l’avancée')} →',
                style: police(policeTexte, taille: 13.5, graisse: FontWeight.w700, couleur: const Color(0xFF3D7BFF))),
          ]),
        ),
      ),
    );
  }
}

/// Carte colorée « Demain / Dans 9 jours » (rubrique de l'accueil).
class CarteCompteARebours extends StatelessWidget {
  final Evenement e;
  const CarteCompteARebours(this.e, {super.key});

  @override
  Widget build(BuildContext context) {
    final f = e.fam;
    final n = e.jours;
    final grand = e.precision == 'mois' && n > 1
        ? dateEvenement(e)
        : n <= 0
            ? tr('Aujourd’hui')
            : n == 1
                ? tr('Demain')
                : tr('Dans {n} jours', n: n);
    return SizedBox(
      width: 200,
      child: Material(
        color: f.couleur,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => ouvrirEvenement(context, e),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${tr(nomsTypes[e.type] ?? 'Événement')} · ${dateEvenement(e)}'.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: police(policeTexte, taille: 10.5, graisse: FontWeight.w800, couleur: f.icone.withValues(alpha: 0.9))),
              const SizedBox(height: 4),
              Text(grand,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: police(policeTitres, taille: 24, graisse: FontWeight.w800, couleur: f.icone, hauteur: 1.05)),
              const SizedBox(height: 4),
              Expanded(
                child: TexteArticle(e.titre,
                    maxLines: 3,
                    style: police(policeTitres, taille: 14, graisse: FontWeight.w600, couleur: f.icone, hauteur: 1.2)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Rubrique « À venir » de l'accueil (null s'il n'y a rien à montrer).
Widget? rubriqueAVenir(BuildContext context, String fil, VoidCallback toutVoir, Widget Function(String, String?, VoidCallback?) titre) {
  evenementsAVenir.demarrer();
  final l = evenementsAVenir.prochains(fil: fil).take(10).toList();
  if (l.isEmpty) return null;
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    titre(tr('À venir'), tr('Tout voir'), toutVoir),
    SizedBox(
      height: 156,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: l.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) => CarteCompteARebours(l[i]),
      ),
    ),
  ]);
}

// ------------------------------------------------------------------ infos pratiques (maquettes 78-79)

const Map<String, IconData> iconesPratique = {
  'lieu': Icons.place_outlined,
  'heure': Icons.schedule_rounded,
  'direction': Icons.explore_outlined,
  'voir': Icons.visibility_outlined,
  'lune': Icons.dark_mode_outlined,
  'direct': Icons.live_tv_rounded,
  'duree': Icons.date_range_rounded,
  'repere': Icons.flag_outlined,
  'appareil': Icons.devices_other_rounded,
  'qui': Icons.groups_outlined,
  'prix': Icons.sell_outlined,
  'info': Icons.info_outline_rounded,
};

const _vertFond = Color(0xFFDDF5EA), _vertTexte = Color(0xFF0B6B4F);
const _orangeFond = Color(0xFFFFF1D6), _orangeTexte = Color(0xFF7A4B00);
const _rougeFond = Color(0xFFFDE2E2), _rougeTexte = Color(0xFF8E1F24);
const _bleuFond = Color(0xFFEEF0FA), _bleuTexte = Color(0xFF2F3E66);

/// Couleurs des bandeaux, lisibles en thème clair comme en sombre.
(Color, Color) _couleurs(BuildContext context, Color fond, Color texte) =>
    estSombre(context) ? (Color.lerp(texte, Colors.black, 0.55)!, Color.lerp(fond, Colors.white, 0.3)!) : (fond, texte);

/// Ligne pratique sous le titre d'une carte de la liste : visibilité (ciel), statut, heure ou lieu.
/// [statutSeulement] : seulement annulé, reporté ou visibilité (sinon rien).
List<Widget> ligneCarte(BuildContext context, Evenement e, {bool statutSeulement = false}) {
  if (statutSeulement && !e.annule && !e.reporte && e.type != 'ciel') return const [];
  final p = palette(context);
  String? texte;
  Color couleur = p.texteDiscret;
  var gras = false;
  if (e.annule) {
    texte = tr('Annulé');
    couleur = estSombre(context) ? const Color(0xFFFF8A8F) : _rougeTexte;
    gras = true;
  } else if (e.reporte) {
    texte = '${tr('Reporté')} · ${tr('prévu d’abord le')} ${DateFormat('d MMM', etat.langue).format(e.datePrecedente!)}';
    couleur = estSombre(context) ? const Color(0xFFFFC56B) : _orangeTexte;
    gras = true;
  } else if (e.type == 'ciel') {
    switch (visibiliteIci(e.visibleRegions, e.visiblePartiel)) {
      case Visibilite.totale:
        texte = '✓ ${tr('Visible chez vous')}';
        couleur = estSombre(context) ? const Color(0xFF6EE2BE) : _vertTexte;
        gras = true;
      case Visibilite.partielle:
        texte = '◐ ${tr('En partie visible chez vous')}';
        couleur = estSombre(context) ? const Color(0xFF6EE2BE) : _vertTexte;
        gras = true;
      case Visibilite.aucune:
        texte = '✕ ${tr('Pas visible chez vous')}';
        couleur = estSombre(context) ? const Color(0xFFFFC56B) : _orangeTexte;
        gras = true;
      case Visibilite.inconnue:
        texte = e.visibleTexte;
    }
  } else {
    texte = [
      if (e.instantExact != null) heureLocale(e.instantExact!),
      if ((e.lieu ?? '').isNotEmpty) e.lieu!,
    ].join(' · ');
  }
  if ((texte ?? '').isEmpty) return const [];
  return [
    const SizedBox(height: 3),
    TexteArticle(texte!,
        maxLines: 1,
        style: police(policeTexte, taille: 12, graisse: gras ? FontWeight.w800 : FontWeight.w500, couleur: couleur)),
  ];
}

Widget _bandeau(BuildContext context, Color fond, Color texte, IconData icone, String titre, String? detail) {
  final (f, t) = _couleurs(context, fond, texte);
  return Container(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
    decoration: BoxDecoration(color: f, borderRadius: BorderRadius.circular(16)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icone, color: t, size: 22),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titre, style: police(policeTexte, taille: 14.5, graisse: FontWeight.w800, couleur: t)),
          if ((detail ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            TexteArticle(detail!, style: police(policeTexte, taille: 13, couleur: t, hauteur: 1.4)),
          ],
        ]),
      ),
    ]),
  );
}

/// Bandeaux en haut de la fiche : annulé, reporté, date floue, visibilité (ciel).
List<Widget> bandeauxEvenement(BuildContext context, Evenement e) {
  final l = <Widget>[];
  final raison = (e.statutRaison ?? '').isNotEmpty ? '${tr('Raison')} : ${e.statutRaison}. ' : '';
  if (e.annule) {
    l.add(_bandeau(context, _rougeFond, _rougeTexte, Icons.event_busy_rounded, tr('Annulé'),
        '$raison${tr('L’organisateur a annulé l’événement.')}'));
  } else if (e.reporte) {
    l.add(_bandeau(
        context,
        _orangeFond,
        _orangeTexte,
        Icons.update_rounded,
        trv('Reporté au {date}', {'date': dateEvenement(e, longue: true)}),
        '${tr('prévu d’abord le')} ${DateFormat('d MMMM', etat.langue).format(e.datePrecedente!)}. $raison'
            '${etat.rappels.contains(e.id) ? tr('Votre rappel a été déplacé.') : ''}'.trim()));
  } else if (e.precision == 'avant') {
    l.add(_bandeau(context, _bleuFond, _bleuTexte, Icons.event_note_rounded, dateEvenement(e),
        tr('Date précise pas encore annoncée. On la met dès qu’elle paraît.')));
  }
  if (e.type == 'ciel' && !e.annule) {
    final zone = e.visibleTexte;
    switch (visibiliteIci(e.visibleRegions, e.visiblePartiel)) {
      case Visibilite.totale:
        l.add(_bandeau(context, _vertFond, _vertTexte, Icons.check_circle_rounded, tr('Visible chez vous'), zone));
      case Visibilite.partielle:
        l.add(_bandeau(context, _vertFond, _vertTexte, Icons.contrast_rounded, tr('En partie visible chez vous'), zone));
      case Visibilite.aucune:
        l.add(_bandeau(context, _orangeFond, _orangeTexte, Icons.cancel_rounded, tr('Pas visible chez vous'),
            '${zone ?? ''}${(e.lienDirect ?? '').isNotEmpty ? ' · ${tr('À suivre en direct sur Internet.')}' : ''}'));
      case Visibilite.inconnue:
        if ((zone ?? '').isNotEmpty) {
          l.add(_bandeau(context, _bleuFond, _bleuTexte, Icons.public_rounded, tr('Où le voir'), zone));
        }
    }
  }
  return l;
}

/// Bloc « En pratique » : lieu et heure (calculés ici, à l'heure du téléphone) puis les lignes de l'agent.
Widget? blocPratique(BuildContext context, Evenement e) {
  final p = palette(context);
  final lignes = <(String, String, String)>[
    if ((e.lieu ?? '').isNotEmpty) ('lieu', tr(e.type == 'lancement' ? 'D’où' : 'Où'), e.lieu!),
    if (e.instantExact != null)
      ('heure', tr('Heure de chez vous'), '${DateFormat('EEEE d MMMM', etat.langue).format(e.instantExact!.toLocal())} · ${heureLocale(e.instantExact!)}'),
    if (e.fin != null && e.fin!.isAfter(e.date))
      ('duree', tr('Durée'), '${dateEvenement(e, longue: true)} · ${tr('{n} jours', n: e.fin!.difference(e.date).inDays + 1)}'),
    for (final x in e.pratique) (x.icone, x.titre, x.texte),
  ];
  if (lignes.isEmpty) return null;
  return Container(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
    decoration: BoxDecoration(color: p.carte, borderRadius: BorderRadius.circular(18)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tr('En pratique').toUpperCase(),
          style: police(policeTexte, taille: 12, graisse: FontWeight.w800, couleur: p.texteDiscret)),
      for (var i = 0; i < lignes.length; i++)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: p.bordure))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: p.pastille, borderRadius: BorderRadius.circular(11)),
              child: Icon(iconesPratique[lignes[i].$1] ?? Icons.info_outline_rounded, size: 19, color: p.texte),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TexteArticle(lignes[i].$2,
                    style: police(policeTexte, taille: 12, graisse: FontWeight.w700, couleur: p.texteDiscret)),
                const SizedBox(height: 2),
                TexteArticle(lignes[i].$3,
                    style: police(policeTexte, taille: 15, graisse: FontWeight.w600, couleur: p.texte, hauteur: 1.35)),
              ]),
            ),
          ]),
        ),
    ]),
  );
}

/// Bouton rouge « Regarder en direct » (seulement si l'agent a un lien officiel).
Widget? boutonDirect(BuildContext context, Evenement e) {
  final lien = Uri.tryParse(e.lienDirect ?? '');
  if (lien == null || !lien.hasScheme || e.annule || e.arrive) return null;
  return SizedBox(
    height: 48,
    child: FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFE5484D),
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
        textStyle: police(policeTexte, taille: 15, graisse: FontWeight.w800),
      ),
      onPressed: () => launchUrl(lien, mode: LaunchMode.externalApplication),
      icon: const Icon(Icons.live_tv_rounded),
      label: Text((e.lienDirectNom ?? '').isNotEmpty ? '${tr('En direct')} · ${e.lienDirectNom} ↗' : '${tr('Regarder en direct')} ↗',
          maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
  );
}

// ------------------------------------------------------------------ l'onglet

class VueAVenir extends StatefulWidget {
  const VueAVenir({super.key});

  @override
  State<VueAVenir> createState() => _VueAVenirState();
}

class _VueAVenirState extends State<VueAVenir> {
  String? _fil; // null = tout

  @override
  void initState() {
    super.initState();
    evenementsAVenir.demarrer();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([etat, evenementsAVenir]),
      builder: (context, _) {
        final p = palette(context);
        if (evenementsAVenir.liste == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final prochains = evenementsAVenir.prochains(fil: _fil);
        final arrives = evenementsAVenir
            .visibles(fil: _fil)
            .where((e) => e.arrive)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        Widget section(String t) => Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 8),
              child: Text(tr(t).toUpperCase(),
                  style: police(policeTexte, taille: 12, graisse: FontWeight.w800, couleur: p.texteDiscret)
                      .copyWith(letterSpacing: 0.8)),
            );
        // Plus loin qu'un mois : un en-tête par mois (« Janvier », « Août 2027 »…).
        final plusTard = <String, List<Evenement>>{};
        for (final e in prochains.where((e) => e.jours > 31)) {
          plusTard.putIfAbsent(enTeteMois(DateTime(e.date.year, e.date.month)), () => []).add(e);
        }
        final groupes = <(String, List<Evenement>)>[
          ('Cette semaine', prochains.where((e) => e.jours <= 7).toList()),
          ('Ce mois-ci', prochains.where((e) => e.jours > 7 && e.jours <= 31).toList()),
          for (final m in plusTard.entries) (m.key, m.value),
        ];
        Widget choix(String? fil, String texte) {
          final actif = fil == _fil;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _fil = fil),
              child: Container(
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: actif ? p.carte : Colors.transparent, borderRadius: BorderRadius.circular(11)),
                child: Text(tr(texte),
                    style: police(policeTexte, taille: 13, graisse: FontWeight.w800, couleur: actif ? p.texte : p.texteDiscret)),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: evenementsAVenir.charger,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(color: p.pastille, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [choix(null, 'Tout'), choix('science', texteSciences), choix('tech', texteTechnologies)]),
              ),
              if (evenementsAVenir.horsLigne)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(tr(texteErreur), style: police(policeTexte, taille: 13, couleur: p.texteDiscret)),
                ),
              if (prochains.isEmpty && arrives.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 50),
                  child: MessageCentre(
                    icone: Icons.event_outlined,
                    titre: tr('Rien d’annoncé pour l’instant'),
                    detail: tr('Les lancements, sorties et grands rendez-vous apparaîtront ici dès qu’une source les annonce.'),
                  ),
                ),
              for (final (t, l) in groupes)
                if (l.isNotEmpty) ...[
                  section(t),
                  for (final e in l) Padding(padding: const EdgeInsets.only(bottom: 9), child: LigneEvenement(e)),
                ],
              if (arrives.isNotEmpty) ...[
                section('C’est arrivé'),
                for (final e in arrives.take(10)) Padding(padding: const EdgeInsets.only(bottom: 9), child: CarteArrivee(e)),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------------ le détail

class EcranEvenement extends StatefulWidget {
  final Evenement evenement;
  const EcranEvenement({super.key, required this.evenement});

  @override
  State<EcranEvenement> createState() => _EcranEvenementState();
}

class _EcranEvenementState extends State<EcranEvenement> {
  Timer? _minuteur;

  @override
  void initState() {
    super.initState();
    _minuteur = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.evenement;
    final p = palette(context);
    final f = e.fam;
    final reste = e.instant.difference(DateTime.now().toUtc());
    Widget chiffre(String n, String u) => Padding(
          padding: const EdgeInsets.only(right: 26),
          child: Column(children: [
            Text(n, style: police(policeTitres, taille: 40, graisse: FontWeight.w800, couleur: f.icone, hauteur: 1)),
            const SizedBox(height: 2),
            Text(tr(u).toUpperCase(),
                style: police(policeTexte, taille: 11, graisse: FontWeight.w700, couleur: f.icone.withValues(alpha: 0.85))),
          ]),
        );
    final Widget compteur;
    if (e.precision == 'mois' && e.jours > 1) {
      compteur = Text(dateEvenement(e),
          style: police(policeTitres, taille: 32, graisse: FontWeight.w800, couleur: f.icone));
    } else if (e.annule) {
      compteur = Text(tr('Annulé'), style: police(policeTitres, taille: 32, graisse: FontWeight.w800, couleur: f.icone));
    } else if (e.precision == 'avant' && e.jours > 1) {
      compteur = Text(dateEvenement(e), style: police(policeTitres, taille: 30, graisse: FontWeight.w800, couleur: f.icone));
    } else if (e.enCours) {
      compteur = Text(tr('En ce moment'), style: police(policeTitres, taille: 32, graisse: FontWeight.w800, couleur: f.icone));
    } else if (reste.isNegative || e.jours <= 0) {
      compteur = Text(tr(e.arrive ? 'C’est arrivé' : (e.jours < 0 ? 'Pas encore de nouvelles' : 'C’est aujourd’hui !')),
          style: police(policeTitres, taille: 32, graisse: FontWeight.w800, couleur: f.icone));
    } else {
      compteur = Row(children: [
        chiffre('${reste.inDays}', 'Jours'),
        chiffre((reste.inHours % 24).toString().padLeft(2, '0'), 'Heures'),
        chiffre((reste.inMinutes % 60).toString().padLeft(2, '0'), 'Min'),
      ]);
    }
    final heure = e.instantExact != null
        ? ', ${heureLocale(e.instantExact!)} (${tr('heure de chez vous')})'
        : e.heure == null
            ? ''
            : ', ${tr('vers')} ${e.heure!.replaceFirst(':', ' h ').replaceAll(' h 00', ' h')} (${tr('heure de Paris')})';
    final dateTexte = e.precision != 'jour' ? dateEvenement(e) : dateEvenement(e, longue: true);
    Widget bloc(String titre, String? texte) => (texte ?? '').isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr(titre).toUpperCase(),
                  style: police(policeTexte, taille: 12, graisse: FontWeight.w800, couleur: p.texteDiscret)),
              const SizedBox(height: 4),
              TexteArticle(texte!, style: police(policeTexte, taille: 16, couleur: p.texte, hauteur: 1.55)),
            ]),
          );
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) {
        final rappel = etat.rappels.contains(e.id);
        final avecRappel = !e.arrive && !e.annule && (e.joursFin >= 0 || (rappel && e.type != 'ciel'));
        final boutonSource = OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: p.texte,
            side: BorderSide(color: p.bordure, width: 1.5),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            textStyle: police(policeTexte, taille: 14, graisse: FontWeight.w800),
          ),
          onPressed: () => ouvrirArticle(Uri.parse(e.sourceUrl)),
          icon: const Icon(Icons.north_east_rounded, size: 18),
          label: Text(tr('Source')),
        );
        return Scaffold(
          backgroundColor: p.fond,
          body: Column(children: [
          Expanded(
          child: ListView(padding: EdgeInsets.zero, children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Color.lerp(f.couleur, Colors.white, 0.18)!, Color.lerp(f.couleur, Colors.black, 0.3)!],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 18, 22),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      IconButton(
                          tooltip: tr('Retour'),
                          icon: Icon(Icons.arrow_back_rounded, color: f.icone),
                          onPressed: () => Navigator.of(context).pop()),
                      Expanded(
                        child: Text('${tr(nomsTypes[e.type] ?? 'Événement')} · ${tr(f.nom)}'.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: police(policeTexte, taille: 12, graisse: FontWeight.w800, couleur: f.icone)),
                      ),
                    ]),
                    Padding(
                      padding: const EdgeInsets.only(left: 14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        TexteArticle(e.titre,
                            style: police(policeTitres, taille: 24, graisse: FontWeight.w800, couleur: f.icone, hauteur: 1.12)),
                        const SizedBox(height: 16),
                        compteur,
                        const SizedBox(height: 12),
                        Text('${dateTexte[0].toUpperCase()}${dateTexte.substring(1)}$heure · ${tr('date donnée par la source')}',
                            style: police(policeTexte, taille: 13.5, couleur: f.icone.withValues(alpha: 0.92), hauteur: 1.4)),
                        if (e.datePrecedente != null && !e.reporte)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                                '${tr('Date changée')} : ${tr('prévu d’abord le')} ${DateFormat('d MMMM', etat.langue).format(DateTime(e.datePrecedente!.year, e.datePrecedente!.month, e.datePrecedente!.day))}',
                                style: police(policeTexte, taille: 13, graisse: FontWeight.w700, couleur: f.icone)),
                          ),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (e.arrive)
                  Padding(padding: const EdgeInsets.only(bottom: 16), child: CarteArrivee(e)),
                for (final b in bandeauxEvenement(context, e)) Padding(padding: const EdgeInsets.only(bottom: 10), child: b),
                if (boutonDirect(context, e) case final b?) Padding(padding: const EdgeInsets.only(bottom: 10), child: b),
                if (blocPratique(context, e) case final b?) Padding(padding: const EdgeInsets.only(bottom: 16), child: b),
                if (!e.arrive && !e.annule && e.joursFin < 0 && e.type != 'ciel')
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: estSombre(context) ? const Color(0xFF3A2E12) : const Color(0xFFFFF1D6),
                        borderRadius: BorderRadius.circular(18)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tr('Pas encore de nouvelles'),
                          style: police(policeTexte, taille: 14, graisse: FontWeight.w800, couleur: p.texte)),
                      const SizedBox(height: 4),
                      Text(tr('Aucun article ne l’a encore annoncé. La date a peut-être changé : on vous prévient dès qu’il y a du nouveau.'),
                          style: police(policeTexte, taille: 13.5, couleur: p.texte, hauteur: 1.45)),
                    ]),
                  ),
                bloc('Ce qui est prévu', e.prevu),
                bloc('Pourquoi c’est important', e.pourquoi),
                // Sources, comme dans une avancée (planche 49 · B1).
                BlocSources(source: e.sourceNom, lien: e.sourceUrl, autres: e.autresSources),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_majuscule(tr('la date peut changer (météo, retard)')),
                      textAlign: TextAlign.center,
                      style: police(policeTexte, taille: 12, couleur: p.texteDiscret, hauteur: 1.4)),
                ),
                const SizedBox(height: 4),
                Text(tr(texteMentionResume),
                    textAlign: TextAlign.center, style: police(policeTexte, taille: 12, couleur: p.texteDiscret)),
                Center(
                  child: TextButton.icon(
                    onPressed: () => signalerErreurEvenement(context,
                        id: e.id, titre: e.titre, date: dateTexte, source: e.sourceNom, lien: e.sourceUrl),
                    style: TextButton.styleFrom(
                        foregroundColor: p.texte,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10)),
                    icon: const Icon(Icons.flag_outlined, size: 16),
                    label: Text(tr('Signaler une erreur'),
                        style: police(policeTexte, taille: 13, graisse: FontWeight.w700, couleur: p.texte)),
                  ),
                ),
              ]),
            ),
          ]),
          ),
          // Barre collée compacte (maquette 81 · C) : rappel, agenda et source,
          // pour laisser la place au futur bandeau publicitaire.
          SafeArea(
            top: false,
            child: Container(
              decoration: BoxDecoration(border: Border(top: BorderSide(color: p.bordure.withValues(alpha: 0.5)))),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: SizedBox(
                height: 46,
                child: Row(children: [
                  if (avecRappel) ...[
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: rappel ? p.pastille : p.encre,
                          foregroundColor: rappel ? p.texte : p.surEncre,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          textStyle: police(policeTexte, taille: 14, graisse: FontWeight.w800),
                        ),
                        onPressed: () => basculerRappel(context, e),
                        icon: Icon(rappel ? Icons.notifications_active_rounded : Icons.notifications_none_rounded, size: 20),
                        label: Text(tr(rappel ? 'Rappel activé' : 'Me le rappeler'), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 46,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: p.texte,
                          side: BorderSide(color: p.bordure, width: 1.5),
                          shape: const StadiumBorder(),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: () => ajouterAgenda(e),
                        child: Tooltip(message: tr('Ajouter à mon agenda'), child: const Icon(Icons.event_available_rounded, size: 20)),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (avecRappel) boutonSource else Expanded(child: boutonSource),
                ]),
              ),
            ),
          ),
          ]),
        );
      },
    );
  }
}

String _majuscule(String t) => t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
