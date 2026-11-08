// Une avancée telle qu'elle est enregistrée dans la base Supabase (table advances).

import 'package:intl/intl.dart';

import 'etat.dart';
import 'langues.dart';

class Avancee {
  final String id;
  final String fil; // 'science' ou 'tech'
  final String titre;
  final String resume;
  final String theme;
  final String famille;
  final int importance;
  final String lien;
  final String source;
  final DateTime publieLe;
  /// Date d'ajout dans la base (sert à la pastille « Nouveau »).
  final DateTime? ajouteLe;
  final String? image;
  final String? creditImage;
  /// Nouveau résumé (maquette 33) : vides pour les fiches d'avant le 21/10.
  final String avant, decouverte, apres;
  final List<MotAConnaitre> mots;
  /// Type d'étude ou stade (badge) : 'animal', 'prototype'… ou null.
  final String? typeEtude;
  /// Autres médias qui parlent de la même avancée (maquette 49 B1).
  final List<SourceAvancee> autresSources;
  /// Vidéo à l'appui trouvée par l'agent dans l'article (migration 013, 08/11/2026).
  final String? video, videoTitre;
  /// Données d'origine, gardées pour enregistrer un favori sur le téléphone.
  final Map<String, dynamic> brut;

  /// Vrai si la fiche a le résumé en trois parties.
  bool get nouveauResume => decouverte.isNotEmpty;

  const Avancee({
    this.brut = const {},
    required this.id,
    required this.fil,
    required this.titre,
    required this.resume,
    required this.theme,
    required this.famille,
    required this.importance,
    required this.lien,
    required this.source,
    required this.publieLe,
    this.ajouteLe,
    this.image,
    this.creditImage,
    this.avant = '',
    this.decouverte = '',
    this.apres = '',
    this.mots = const [],
    this.typeEtude,
    this.autresSources = const [],
    this.video,
    this.videoTitre,
  });

  factory Avancee.depuisJson(Map<String, dynamic> j) {
    _retenirTraductions(j);
    final imp = (j['importance'] as num?)?.toInt() ?? 2;
    final img = (j['image_url'] as String?)?.trim();
    return Avancee(
      brut: j,
      id: j['id']?.toString() ?? '',
      fil: (j['feed'] as String?) ?? 'science',
      titre: (j['title'] as String?) ?? '',
      resume: (j['summary'] as String?) ?? '',
      theme: (j['theme'] as String?) ?? 'other',
      famille: (j['family'] as String?) ?? 'other',
      importance: imp.clamp(1, 5),
      lien: (j['source_url'] as String?) ?? '',
      source: (j['source_name'] as String?) ?? '',
      publieLe: DateTime.tryParse((j['published_at'] as String?) ?? '')?.toLocal() ?? DateTime.now(),
      ajouteLe: DateTime.tryParse((j['created_at'] as String?) ?? '')?.toLocal(),
      image: (img == null || img.isEmpty) ? null : img,
      creditImage: j['image_credit'] as String?,
      avant: (j['avant'] as String?)?.trim() ?? '',
      decouverte: (j['decouverte'] as String?)?.trim() ?? '',
      apres: (j['apres'] as String?)?.trim() ?? '',
      mots: [
        for (final m in (j['mots'] is List ? j['mots'] as List : const []))
          if (m is Map && (m['mot'] ?? '').toString().trim().isNotEmpty)
            MotAConnaitre(m['mot'].toString().trim(), (m['definition'] ?? '').toString().trim()),
      ],
      typeEtude: (j['type_etude'] as String?)?.trim(),
      autresSources: [
        for (final s in (j['autres_sources'] is List ? j['autres_sources'] as List : const []))
          if (s is Map && (s['nom'] ?? '').toString().isNotEmpty && (s['url'] ?? '').toString().isNotEmpty)
            SourceAvancee(s['nom'].toString(), s['url'].toString(), (s['langue'] ?? '').toString(),
                DateTime.tryParse((s['date'] ?? '').toString())),
      ],
      video: (j['video_url'] as String?)?.trim(),
      videoTitre: (j['video_titre'] as String?)?.trim(),
    );
  }
}

/// Langues traduites à l'avance par l'agent (agent/traduction.py, LANGUES) :
/// pour elles, le téléphone ne télécharge pas son modèle de traduction au démarrage.
const Set<String> languesTraduitesParAgent = {'en'};

/// Traductions faites par l'agent (colonne « traductions », migration 006) :
/// langue → texte français → traduction. Remplies à la lecture des fiches.
final Map<String, Map<String, String>> traductionsAgent = {};

/// Traduction faite par l'agent de ce texte français (titre, partie du résumé,
/// mot à connaître…) dans la langue de l'app, ou null s'il n'y en a pas.
String? traductionAgent(String francais, [String? langue]) => traductionsAgent[langue ?? etat.langue]?[francais];

void _retenirTraductions(Map<String, dynamic> j) {
  final t = j['traductions'];
  if (t is! Map) return;
  t.forEach((langue, v) {
    if (v is! Map) return;
    final d = traductionsAgent.putIfAbsent(langue.toString(), () => {});
    void paire(Object? fr, Object? trad) {
      final a = (fr ?? '').toString(), b = (trad ?? '').toString().trim();
      if (a.trim().isEmpty || b.isEmpty) return;
      d[a] = b;
      d[a.trim()] = b;
    }

    for (final c in const ['title', 'summary', 'avant', 'decouverte', 'apres']) {
      paire(j[c], v[c]);
    }
    final mf = j['mots'] is List ? j['mots'] as List : const [];
    final mt = v['mots'] is List ? v['mots'] as List : const [];
    if (mf.length != mt.length) return;
    for (var i = 0; i < mf.length; i++) {
      final f = mf[i], g = mt[i];
      if (f is! Map || g is! Map) continue;
      final mot = (f['mot'] ?? '').toString().trim(), def = (f['definition'] ?? '').toString().trim();
      final tmot = (g['mot'] ?? '').toString().trim(), tdef = (g['definition'] ?? '').toString().trim();
      paire(mot, tmot);
      paire(def, tdef);
      // Forme affichée dans le détail : « mot : définition »
      if (tmot.isNotEmpty && tdef.isNotEmpty) d['$mot : $def'] = '$tmot: $tdef';
    }
  });
}

/// Un « mot à connaître » et sa définition (en français, traduits à l'affichage).
/// Un média qui parle d'une avancée : nom, lien, langue (fr, en…), date.
class SourceAvancee {
  final String nom, url, langue;
  final DateTime? date;
  const SourceAvancee(this.nom, this.url, this.langue, this.date);
}

class MotAConnaitre {
  final String mot, definition;
  const MotAConnaitre(this.mot, this.definition);
}

// Dates écrites dans la langue de l'app (format propre à chaque langue).

/// « 18 oct. »
String dateCourte(DateTime d) => DateFormat.MMMd(etat.langue).format(d);

/// « 18 octobre 2026 »
String dateLongue(DateTime d) => DateFormat.yMMMMd(etat.langue).format(d);

/// « Octobre » (et l'année si ce n'est pas l'année en cours) : en-têtes de mois.
/// Titre de jour dans « Cette semaine » : (« Aujourd’hui » | « Hier » | « Mardi », « 21 octobre »).
(String, String) enTeteJour(DateTime d) {
  final l = d.toLocal();
  final maintenant = DateTime.now();
  final jour = DateTime(l.year, l.month, l.day);
  final ecart = DateTime(maintenant.year, maintenant.month, maintenant.day).difference(jour).inDays;
  final date = DateFormat('d MMMM', etat.langue).format(l);
  if (ecart <= 0) return (tr('Aujourd’hui'), date);
  if (ecart == 1) return (tr('Hier'), date);
  final nom = DateFormat('EEEE', etat.langue).format(l);
  return (nom.isEmpty ? nom : nom[0].toUpperCase() + nom.substring(1), date);
}

String enTeteMois(DateTime d) {
  final format = d.year == DateTime.now().year ? DateFormat('LLLL', etat.langue) : DateFormat('LLLL y', etat.langue);
  final texte = format.format(d);
  return texte.isEmpty ? texte : texte[0].toUpperCase() + texte.substring(1);
}
