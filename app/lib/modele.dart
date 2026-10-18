// Une avancée telle qu'elle est enregistrée dans la base Supabase (table advances).

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
      image: (img == null || img.isEmpty) ? null : img,
      creditImage: j['image_credit'] as String?,
    );
  }
}

const _mois = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
const _moisLongs = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];

/// « 18 oct. »
String dateCourte(DateTime d) => '${d.day} ${_mois[d.month - 1]}';

/// « 18 octobre 2026 »
String dateLongue(DateTime d) => '${d.day} ${_moisLongs[d.month - 1]} ${d.year}';

/// « Octobre » (et l'année si ce n'est pas l'année en cours) : en-têtes de mois.
String enTeteMois(DateTime d) {
  final m = _moisLongs[d.month - 1];
  final nom = m[0].toUpperCase() + m.substring(1);
  return d.year == DateTime.now().year ? nom : '$nom ${d.year}';
}
