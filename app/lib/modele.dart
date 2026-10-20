// Une avancée telle qu'elle est enregistrée dans la base Supabase (table advances).

import 'package:intl/intl.dart';

import 'etat.dart';

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
  /// Données d'origine, gardées pour enregistrer un favori sur le téléphone.
  final Map<String, dynamic> brut;

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
  });

  factory Avancee.depuisJson(Map<String, dynamic> j) {
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
    );
  }
}

// Dates écrites dans la langue de l'app (format propre à chaque langue).

/// « 18 oct. »
String dateCourte(DateTime d) => DateFormat.MMMd(etat.langue).format(d);

/// « 18 octobre 2026 »
String dateLongue(DateTime d) => DateFormat.yMMMMd(etat.langue).format(d);

/// « Octobre » (et l'année si ce n'est pas l'année en cours) : en-têtes de mois.
String enTeteMois(DateTime d) {
  final format = d.year == DateTime.now().year ? DateFormat('LLLL', etat.langue) : DateFormat('LLLL y', etat.langue);
  final texte = format.format(d);
  return texte.isEmpty ? texte : texte[0].toUpperCase() + texte.substring(1);
}
