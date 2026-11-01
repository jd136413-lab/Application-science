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
import 'modele.dart' show enTeteMois;
import 'notifications.dart';
import 'reglages.dart';
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

class Evenement {
  final String id, titre, type, fil, sourceUrl, sourceNom, precision;
  final String? prevu, pourquoi, famille, heure, avanceeId;
  final DateTime date; // jour seul (UTC)
  final DateTime? datePrecedente;
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
  });

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
        precision: j['precision'] == 'mois' ? 'mois' : 'jour',
        importance: (j['importance'] as num?)?.toInt() ?? 2,
        sourceUrl: '${j['source_url'] ?? ''}',
        sourceNom: '${j['source_name'] ?? ''}',
        datePrecedente: _jour(j['previous_date']),
        avanceeId: j['advance_id'] as String?,
      );

  Famille get fam => familleDe(famille ?? (fil == 'tech' ? 'tech_other' : 'other'));
  bool get arrive => avanceeId != null;

  /// Jours avant l'événement (0 = aujourd'hui, négatif = passé).
  int get jours => date.difference(aujourdhuiParis()).inDays;

  /// Instant de l'événement (début de journée si l'heure n'est pas connue).
  DateTime get instant {
    final hm = (heure ?? '').split(':');
    final h = hm.length == 2 ? int.tryParse(hm[0]) : null;
    final m = hm.length == 2 ? int.tryParse(hm[1]) : null;
    return parisVersUtc(date.year, date.month, date.day, h ?? 0, m ?? 0);
  }
}

const Map<String, String> nomsTypes = {
  'lancement': 'Lancement',
  'sortie': 'Sortie',
  'resultats': 'Résultats',
  'ciel': 'Dans le ciel',
  'evenement': 'Événement',
  'annonce': 'Annonce',
};

String dateEvenement(Evenement e, {bool longue = false}) {
  final d = DateTime(e.date.year, e.date.month, e.date.day);
  if (e.precision == 'mois') return DateFormat('LLLL y', etat.langue).format(d);
  return DateFormat(longue ? 'EEEE d MMMM' : 'EEE d MMM', etat.langue).format(d);
}

String etiquetteJours(Evenement e) {
  if (e.precision == 'mois' && e.jours > 1) {
    return DateFormat('MMM', etat.langue).format(DateTime(e.date.year, e.date.month)).toUpperCase();
  }
  final n = e.jours;
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

  /// Événements à montrer : domaines choisis, à venir (ou aujourd'hui).
  List<Evenement> visibles({String? fil}) {
    final l = liste ?? const <Evenement>[];
    return l
        .where((e) =>
            (fil == null || e.fil == fil) &&
            (e.famille == null || etat.famillesVisibles(e.fil).contains(e.famille)))
        .toList();
  }

  List<Evenement> prochains({String? fil}) =>
      visibles(fil: fil).where((e) => !e.arrive && e.jours >= 0).toList()..sort((a, b) => a.date.compareTo(b.date));

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
  if (e.type == 'ciel') {
    quand = e.heure != null
        ? e.instant.subtract(const Duration(hours: 1))
        : parisVersUtc(e.date.year, e.date.month, e.date.day, 21, 30);
  } else {
    final lendemain = e.precision == 'mois'
        ? DateTime.utc(e.date.year, e.date.month + 1, 1)
        : e.date.add(const Duration(days: 1));
    quand = parisVersUtc(lendemain.year, lendemain.month, lendemain.day, 12, 0);
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
      titre: e.heure != null ? '${tr('C’est aujourd’hui')} · ${_heureTexte(e.heure!)}' : tr('Ce soir'),
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
  if (e.type != 'ciel') await abonnerEvenement(e.id);
  etat.ajouterRappel(e.id);
  if (!context.mounted) return;
  if (e.type == 'ciel') {
    final h = e.heure != null ? _heureTexte(e.heure!) : '${tr('vers')} 21 h 30';
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
    final fini = e == null || e.arrive || (e.type == 'ciel' ? e.jours < 0 : e.jours < -7);
    if (fini) {
      if (e != null) await annulerRappel(idRappel(e));
      await desabonnerEvenement(id);
      etat.retirerRappel(id);
      continue;
    }
    await annulerRappel(idRappel(e));
    await _programmer(e);
    if (e.type != 'ciel') await abonnerEvenement(id);
  }
}

Future<void> ajouterAgenda(Evenement e) async {
  String f(DateTime d) => DateFormat('yyyyMMdd').format(d);
  String dates;
  if (e.heure != null && e.precision == 'jour') {
    final d = e.instant;
    String u(DateTime x) => '${DateFormat('yyyyMMdd').format(x)}T${DateFormat('HHmmss').format(x)}Z';
    dates = '${u(d)}/${u(d.add(const Duration(hours: 1)))}';
  } else {
    dates = '${f(e.date)}/${f(e.date.add(const Duration(days: 1)))}';
  }
  final details = [
    if ((e.prevu ?? '').isNotEmpty) e.prevu!,
    if ((e.pourquoi ?? '').isNotEmpty) e.pourquoi!,
    '${tr('Source')} : ${e.sourceNom} ${e.sourceUrl}',
    'NovaSTEM',
  ].join('\n\n');
  final uri = Uri.https('calendar.google.com', '/calendar/render', {
    'action': 'TEMPLATE',
    'text': e.titre,
    'dates': dates,
    'details': details,
    'ctz': 'Europe/Paris',
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
          child: Row(children: [
            PastilleJours(e),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${tr(nomsTypes[e.type] ?? 'Événement').toUpperCase()} · ${dateEvenement(e)}',
                    style: police(policeTexte, taille: 11.5, graisse: FontWeight.w800, couleur: encre)),
                const SizedBox(height: 3),
                TexteArticle(e.titre,
                    style: police(policeTitres, taille: 15, graisse: FontWeight.w600, couleur: p.texte, hauteur: 1.2)),
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
    final heure = e.heure == null ? '' : ', ${tr('vers')} ${e.heure!.replaceFirst(':', ' h ').replaceAll(' h 00', ' h')} (${tr('heure de Paris')})';
    final dateTexte = e.precision == 'mois' ? dateEvenement(e) : dateEvenement(e, longue: true);
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
        return Scaffold(
          backgroundColor: p.fond,
          body: ListView(padding: EdgeInsets.zero, children: [
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
                        if (e.datePrecedente != null)
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
                if (!e.arrive && e.jours < 0 && e.type != 'ciel')
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
                InkWell(
                  onTap: () => ouvrirArticle(Uri.parse(e.sourceUrl)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text('${tr('Source')} : ${e.sourceNom} ↗ · ${tr('la date peut changer (météo, retard)')}',
                        style: police(policeTexte, taille: 12.5, couleur: p.texteDiscret, hauteur: 1.4)),
                  ),
                ),
                const SizedBox(height: 16),
                if (!e.arrive && (e.jours >= 0 || (rappel && e.type != 'ciel'))) ...[
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: rappel ? p.pastille : p.encre,
                        foregroundColor: rappel ? p.texte : p.surEncre,
                        shape: const StadiumBorder(),
                        textStyle: police(policeTexte, taille: 15, graisse: FontWeight.w800),
                      ),
                      onPressed: () => basculerRappel(context, e),
                      icon: Icon(rappel ? Icons.notifications_active_rounded : Icons.notifications_none_rounded),
                      label: Text(tr(rappel ? 'Rappel activé' : 'Me le rappeler')),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: p.texte,
                        side: BorderSide(color: p.bordure, width: 1.5),
                        shape: const StadiumBorder(),
                        textStyle: police(policeTexte, taille: 15, graisse: FontWeight.w800),
                      ),
                      onPressed: () => ajouterAgenda(e),
                      icon: const Icon(Icons.event_available_rounded),
                      label: Text(tr('Ajouter à mon agenda')),
                    ),
                  ),
                ],
              ]),
            ),
          ]),
        );
      },
    );
  }
}
