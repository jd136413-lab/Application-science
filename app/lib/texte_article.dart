// Texte d'un article (titre ou résumé), dans la langue de l'app.
// 1. Traduction faite par l'agent (anglais…) : affichée tout de suite.
// 2. Sinon, traduction du téléphone (ML Kit) : le texte français s'affiche,
//    puis est remplacé par sa traduction dès qu'elle est prête. Ces
//    traductions sont gardées sur le téléphone d'une ouverture à l'autre, et
//    les titres du fil sont traduits à l'avance (pretraduire), pour que ce
//    remplacement soit rare.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'etat.dart';
import 'memoire.dart' show cleTraductionsGardees;
import 'modele.dart';
import 'traducteur.dart';

class TexteArticle extends StatefulWidget {
  final String texte;
  final TextStyle style;
  final bool original; // true = toujours le texte français
  final TextAlign? textAlign;
  const TexteArticle(this.texte, {super.key, required this.style, this.original = false, this.textAlign});

  @override
  State<TexteArticle> createState() => _TexteArticleState();
}

/// Traductions déjà faites par le téléphone (« langue|texte » → traduction).
/// Sans elles, une carte qui revient à l'écran s'affichait d'abord en français
/// puis traduite : sa hauteur changeait et le fil faisait des va-et-vient.
final Map<String, String> _traductionsPretes = {};

/// Nombre maximum de traductions gardées sur le téléphone (les plus anciennes partent).
const int _maxGardees = 4000;

/// Au démarrage : relit les traductions gardées sur le téléphone.
Future<void> chargerTraductionsGardees() async {
  try {
    final p = await SharedPreferences.getInstance();
    final texte = p.getString(cleTraductionsGardees);
    if (texte == null || texte.isEmpty) return;
    final m = jsonDecode(texte) as Map;
    m.forEach((k, v) => _traductionsPretes.putIfAbsent(k.toString(), () => v.toString()));
  } catch (_) {}
}

Timer? _sauvegarde;

/// Enregistre les traductions quelques secondes après la dernière (pas à chaque fois).
void _garderPlusTard() {
  _sauvegarde?.cancel();
  _sauvegarde = Timer(const Duration(seconds: 3), () async {
    try {
      while (_traductionsPretes.length > _maxGardees) {
        _traductionsPretes.remove(_traductionsPretes.keys.first);
      }
      final p = await SharedPreferences.getInstance();
      await p.setString(cleTraductionsGardees, jsonEncode(_traductionsPretes));
    } catch (_) {}
  });
}

/// Texte à afficher tout de suite (sans attendre) : traduction de l'agent, ou
/// traduction déjà faite par le téléphone, sinon null.
String? traductionImmediate(String texte, [String? langue]) {
  final l = langue ?? etat.langue;
  if (l == 'fr') return texte;
  return traductionAgent(texte, l) ?? _traductionsPretes['$l|$texte'];
}

/// Texte dans la langue de l'app s'il est déjà traduit, sinon en français (partage…).
String texteDansLaLangue(String texte) => traductionImmediate(texte) ?? texte;

Future<String> _traduireEtGarder(String texte, String langue) async {
  final cle = '$langue|$texte';
  final deja = _traductionsPretes[cle];
  if (deja != null) return deja;
  final t = await traduireArticle(texte, langue);
  if (t != texte) {
    _traductionsPretes[cle] = t;
    _garderPlusTard();
  }
  return t;
}

/// Traduit à l'avance, en arrière-plan, les titres du haut du fil qui n'ont
/// pas de traduction de l'agent : ils s'afficheront directement traduits.
Future<void> pretraduire(List<Avancee> avancees) async {
  final langue = etat.langue;
  if (langue == 'fr' || !traductionArticlesPossible) return;
  final textes = [
    for (final a in avancees.take(60))
      if (traductionImmediate(a.titre, langue) == null) a.titre,
  ];
  for (final t in textes) {
    if (etat.langue != langue) return; // langue changée entre-temps
    await _traduireEtGarder(t, langue);
  }
}

class _TexteArticleState extends State<TexteArticle> {
  late Future<String> _traduction;
  String _cle = '';

  void _preparer() {
    final langue = etat.langue;
    final cle = '$langue|${widget.texte}';
    if (cle == _cle) return;
    _cle = cle;
    _traduction = _traduireEtGarder(widget.texte, langue);
  }

  @override
  Widget build(BuildContext context) {
    Text texte(String t) => Text(t, style: widget.style, textAlign: widget.textAlign);
    if (widget.original || etat.langue == 'fr') return texte(widget.texte);
    final deja = traductionImmediate(widget.texte);
    if (deja != null) return texte(deja); // déjà traduit : tout de suite, sans saut
    if (!traductionArticlesPossible) return texte(widget.texte);
    _preparer();
    return FutureBuilder<String>(
      future: _traduction,
      builder: (context, snap) => texte(snap.data ?? widget.texte),
    );
  }
}
