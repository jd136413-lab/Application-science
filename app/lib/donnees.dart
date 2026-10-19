// Lecture des avancées dans Supabase (lecture seule, avec la clé publique).

import 'package:supabase_flutter/supabase_flutter.dart';

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

/// Avancées d'un fil, les plus récentes d'abord (12 derniers mois).
Future<List<Avancee>> chargerAvancees(String fil) async {
  final depuis = DateTime.now().toUtc().subtract(const Duration(days: 366)).toIso8601String();
  final lignes = await Supabase.instance.client
      .from('advances')
      .select()
      .eq('feed', fil)
      .gte('published_at', depuis)
      .order('published_at', ascending: false)
      .limit(500);
  return (lignes as List)
      .map((l) => Avancee.depuisJson(Map<String, dynamic>.from(l as Map)))
      .toList();
}

/// Une seule avancée, par son identifiant (ouverte depuis une notification).
Future<Avancee?> chargerAvancee(String id) async {
  final ligne = await Supabase.instance.client.from('advances').select().eq('id', id).maybeSingle();
  return ligne == null ? null : Avancee.depuisJson(Map<String, dynamic>.from(ligne));
}
