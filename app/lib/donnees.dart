// Lecture des avancées dans Supabase (lecture seule, avec la clé publique).

import 'package:supabase_flutter/supabase_flutter.dart';

import 'memoire.dart';
import 'modele.dart';

// Adresse et clé publique injectées à la compilation par GitHub Actions
// (--dart-define), jamais écrites dans le code.
const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String supabaseCle = String.fromEnvironment('SUPABASE_KEY');

bool get configurationPresente => supabaseUrl.isNotEmpty && supabaseCle.isNotEmpty;

Future<void> initialiserSupabase() async {
  if (!configurationPresente) return;
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseCle);
}

/// Lignes d'un fil, les plus récentes d'abord (12 derniers mois, 500 au plus).
/// Avec [ajouteesApres] : seulement les fiches ajoutées en base après cette date.
Future<List<Map<String, dynamic>>> _lignes(String fil, {String? ajouteesApres}) async {
  final depuis = DateTime.now().toUtc().subtract(const Duration(days: 366)).toIso8601String();
  var requete = Supabase.instance.client.from('advances').select().eq('feed', fil).gte('published_at', depuis);
  if (ajouteesApres != null) requete = requete.gt('created_at', ajouteesApres);
  final lignes = await requete.order('published_at', ascending: false).limit(500);
  return (lignes as List).map((l) => Map<String, dynamic>.from(l as Map)).toList();
}

List<Avancee> _versAvancees(List<Map<String, dynamic>> lignes) => lignes.map(Avancee.depuisJson).toList();

/// Fil gardé sur le téléphone (affichage instantané à l'ouverture), ou null.
Future<List<Avancee>?> filEnMemoire(String fil) async {
  final m = await lireFil(fil);
  if (m == null || m.lignes.isEmpty) return null;
  try {
    return _versAvancees(m.lignes);
  } catch (_) {
    return null;
  }
}

/// Met le fil à jour depuis la base et le garde sur le téléphone.
/// Si le dernier téléchargement complet a moins de 24 h : seules les fiches
/// ajoutées depuis sont téléchargées. Sinon (ou avec [complet]) : tout le fil,
/// ce qui retire aussi les fiches supprimées ou corrigées entre-temps.
Future<List<Avancee>> mettreAJourFil(String fil, {bool complet = false}) async {
  final memoire = complet ? null : await lireFil(fil);
  final recent = memoire != null &&
      memoire.lignes.isNotEmpty &&
      memoire.dateComplet != null &&
      DateTime.now().difference(memoire.dateComplet!) < dureeFilComplet;
  List<Map<String, dynamic>> lignes;
  DateTime? dateComplet;
  if (recent) {
    final m = memoire!;
    var dernier = '';
    for (final l in m.lignes) {
      final c = (l['created_at'] as String?) ?? '';
      if (c.compareTo(dernier) > 0) dernier = c;
    }
    final nouvelles = await _lignes(fil, ajouteesApres: dernier.isEmpty ? null : dernier);
    final ids = nouvelles.map((l) => l['id']).toSet();
    lignes = [...nouvelles, ...m.lignes.where((l) => !ids.contains(l['id']))];
    final limite = DateTime.now().toUtc().subtract(const Duration(days: 366)).toIso8601String();
    lignes = lignes.where((l) => ((l['published_at'] as String?) ?? '').compareTo(limite) >= 0).toList()
      ..sort((a, b) => ((b['published_at'] as String?) ?? '').compareTo((a['published_at'] as String?) ?? ''));
    if (lignes.length > 500) lignes = lignes.sublist(0, 500);
  } else {
    lignes = await _lignes(fil);
    dateComplet = DateTime.now();
  }
  await ecrireFil(fil, lignes, dateComplet: dateComplet);
  return _versAvancees(lignes);
}

/// Avancées d'un fil, directement depuis la base (sans mémoire).
Future<List<Avancee>> chargerAvancees(String fil) async => _versAvancees(await _lignes(fil));

/// Une seule avancée, par son identifiant (ouverte depuis une notification).
Future<Avancee?> chargerAvancee(String id) async {
  final ligne = await Supabase.instance.client.from('advances').select().eq('id', id).maybeSingle();
  return ligne == null ? null : Avancee.depuisJson(Map<String, dynamic>.from(ligne));
}
