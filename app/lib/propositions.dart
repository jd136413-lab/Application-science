// Onglet « Soumettre » et boîte à idées (maquette 96, 17/11/2026) : échanges avec Supabase.
//
// Sécurité (migration 018) :
//   • envoyer une proposition : tout le monde (insertion seulement) ;
//   • relire SES propositions : fonction mes_propositions(identifiant aléatoire du téléphone) ;
//   • boîte à idées : fonctions admin_… qui vérifient le code de Maxime DANS la base.
//     Le code n'est écrit nulle part dans l'app : sans lui, aucune donnée n'est renvoyée.

import 'package:supabase_flutter/supabase_flutter.dart';

import 'etat.dart';

SupabaseClient get _db => Supabase.instance.client;

/// Une proposition (la sienne, ou toutes pour l'administrateur).
class Proposition {
  final String id, genre, statut, texte;
  final String? categorie, fil, message, ficheId, resume, lien, infos;
  final DateTime cree;
  const Proposition({
    required this.id, required this.genre, required this.statut, required this.texte, required this.cree,
    this.categorie, this.fil, this.message, this.ficheId, this.resume, this.lien, this.infos,
  });

  factory Proposition.depuisJson(Map<String, dynamic> j) => Proposition(
        id: j['id'].toString(),
        genre: (j['genre'] ?? '').toString(),
        statut: (j['statut'] ?? 'nouvelle').toString(),
        texte: (j['texte'] ?? j['titre'] ?? j['sujet'] ?? '').toString(),
        cree: DateTime.tryParse((j['created_at'] ?? '').toString())?.toLocal() ?? DateTime.now(),
        categorie: j['categorie']?.toString(),
        fil: j['fil']?.toString(),
        message: j['message']?.toString(),
        ficheId: j['fiche_id']?.toString(),
        resume: j['resume']?.toString(),
        lien: j['lien']?.toString(),
        infos: j['infos']?.toString(),
      );
}

/// Envoie une proposition. Lève une erreur si l'envoi échoue (pas de réseau, limite du jour…).
Future<void> envoyerProposition(Map<String, dynamic> champs) async {
  await _db.from('submissions').insert({...champs, 'appareil': etat.appareilId});
}

/// Les propositions envoyées depuis ce téléphone (les plus récentes d'abord).
Future<List<Proposition>> mesPropositions() async {
  final r = await _db.rpc('mes_propositions', params: {'p_appareil': etat.appareilId});
  return [for (final l in r as List) Proposition.depuisJson(Map<String, dynamic>.from(l as Map))];
}

/// Vérifie un code administrateur. Renvoie le sujet de notification réservé, ou null.
Future<String?> verifierCodeAdmin(String code) async {
  final r = await _db.rpc('admin_verifier', params: {'p_code': code});
  final s = r?.toString() ?? '';
  return s.isEmpty || s == 'null' ? null : s;
}

/// Toutes les propositions (boîte à idées). Administrateur seulement.
Future<List<Proposition>> toutesLesPropositions() async {
  final r = await _db.rpc('admin_propositions', params: {'p_code': etat.adminCode ?? ''});
  return [for (final l in r as List) Proposition.depuisJson(Map<String, dynamic>.from(l as Map))];
}

/// Change l'état d'une proposition (à faire, faite, ignorée…). Administrateur seulement.
Future<void> changerStatut(String id, String statut) async {
  await _db.rpc('admin_statut', params: {'p_code': etat.adminCode ?? '', 'p_id': id, 'p_statut': statut});
}

/// Nombre de mots d'un texte (limite des titres : 12 mots, comme l'agent).
int compterMots(String t) => t.trim().split(RegExp(r'\s+')).where((m) => m.isNotEmpty).length;
