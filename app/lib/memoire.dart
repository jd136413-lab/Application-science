// Mémoire sur le téléphone (maquette 42) :
// - le fil de chaque onglet (Sciences, Technologies), pour un affichage
//   instantané à l'ouverture et une lecture hors ligne ;
// - les images, gardées 30 jours au plus et limitées à 100 Mo environ.
// Le bouton « Vider » des Réglages efface les deux.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ----------------------------- Réglages -----------------------------

/// Taille maximale des images gardées (en octets).
const int limiteImages = 100 * 1024 * 1024;

/// Une image pas regardée depuis ce délai est effacée.
const Duration dureeImages = Duration(days: 30);

/// Au-delà de ce délai, le fil est retéléchargé en entier (sinon : seulement les nouveautés).
const Duration dureeFilComplet = Duration(hours: 24);

// ----------------------------- Images -----------------------------

const String _cleImages = 'novastem_images';

/// Gestionnaire des images gardées sur le téléphone.
final CacheManager cacheImages = CacheManager(Config(
  _cleImages,
  stalePeriod: dureeImages,
  maxNrOfCacheObjects: 400, // ≈ 100 Mo avec des photos de 250 Ko en moyenne
));

Future<Directory?> _dossierImages() async {
  if (kIsWeb) return null;
  try {
    final tmp = await getTemporaryDirectory();
    final d = Directory('${tmp.path}/$_cleImages');
    return await d.exists() ? d : null;
  } catch (_) {
    return null;
  }
}

Future<List<File>> _fichiersImages() async {
  final d = await _dossierImages();
  if (d == null) return [];
  final fichiers = <File>[];
  await for (final e in d.list(recursive: true, followLinks: false)) {
    if (e is File) fichiers.add(e);
  }
  return fichiers;
}

/// Place prise par les images (en octets).
Future<int> tailleImages() async {
  var total = 0;
  for (final f in await _fichiersImages()) {
    try {
      total += await f.length();
    } catch (_) {}
  }
  return total;
}

/// Au démarrage : si les images dépassent [limiteImages], on efface les plus
/// anciennes jusqu'à redescendre à 80 % de la limite.
Future<void> limiterImages() async {
  try {
    final fichiers = await _fichiersImages();
    final infos = <(File, int, DateTime)>[];
    var total = 0;
    for (final f in fichiers) {
      final s = await f.stat();
      infos.add((f, s.size, s.modified));
      total += s.size;
    }
    if (total <= limiteImages) return;
    infos.sort((a, b) => a.$3.compareTo(b.$3)); // les plus anciennes d'abord
    for (final (f, taille, _) in infos) {
      if (total <= limiteImages * 0.8) break;
      try {
        await f.delete();
        total -= taille;
      } catch (_) {}
    }
  } catch (_) {}
}

// ----------------------------- Fil -----------------------------

String _cleFil(String fil) => 'fil_memoire_v1_$fil';
String _cleDate(String fil) => 'fil_memoire_complet_v1_$fil';

/// Fil gardé sur le téléphone : les lignes de la base, et la date du dernier
/// téléchargement complet.
class FilGarde {
  final List<Map<String, dynamic>> lignes;
  final DateTime? dateComplet;
  const FilGarde(this.lignes, this.dateComplet);
}

Future<FilGarde?> lireFil(String fil) async {
  try {
    final p = await SharedPreferences.getInstance();
    final texte = p.getString(_cleFil(fil));
    if (texte == null || texte.isEmpty) return null;
    final lignes = (jsonDecode(texte) as List).map((l) => Map<String, dynamic>.from(l as Map)).toList();
    return FilGarde(lignes, DateTime.tryParse(p.getString(_cleDate(fil)) ?? ''));
  } catch (_) {
    return null;
  }
}

Future<void> ecrireFil(String fil, List<Map<String, dynamic>> lignes, {DateTime? dateComplet}) async {
  try {
    final p = await SharedPreferences.getInstance();
    await p.setString(_cleFil(fil), jsonEncode(lignes));
    if (dateComplet != null) await p.setString(_cleDate(fil), dateComplet.toIso8601String());
  } catch (_) {}
}

/// Place prise par les fils gardés (en octets).
Future<int> tailleFils() async {
  try {
    final p = await SharedPreferences.getInstance();
    var total = 0;
    for (final fil in const ['science', 'tech']) {
      total += utf8.encode(p.getString(_cleFil(fil)) ?? '').length;
    }
    return total;
  } catch (_) {
    return 0;
  }
}

/// Bouton « Vider » des Réglages : efface les fils et les images gardés.
Future<void> viderMemoire() async {
  try {
    final p = await SharedPreferences.getInstance();
    for (final fil in const ['science', 'tech']) {
      await p.remove(_cleFil(fil));
      await p.remove(_cleDate(fil));
    }
  } catch (_) {}
  try {
    await cacheImages.emptyCache();
  } catch (_) {}
  PaintingBinding.instance.imageCache.clear();
}
