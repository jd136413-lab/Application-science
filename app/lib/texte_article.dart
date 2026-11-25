// Texte d'un article (titre ou résumé), dans la langue de l'app.
// 1. Traduction faite par l'agent (anglais…) : affichée tout de suite.
// 2. Sinon, traduction du téléphone (ML Kit) : le texte français s'affiche,
//    puis est remplacé par sa traduction dès qu'elle est prête. Ces
//    traductions sont gardées sur le téléphone d'une ouverture à l'autre, et
//    les titres du fil sont traduits à l'avance (pretraduire), pour que ce
//    remplacement soit rare.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'etat.dart';
import 'memoire.dart' show cleTraductionsGardees;
import 'modele.dart';
import 'traducteur.dart';

/// Un mot à repérer dans le texte (maquette 101 C, 18/11) : nouveau pour la personne (« + »)
/// ou déjà dans son Vocabulaire (« ✓ »).
class MotMarque {
  final String mot, definition;
  final bool nouveau;
  final DateTime? appris;
  /// Le mot dans la langue de l'app, s'il est connu d'avance (gardé avec le Vocabulaire).
  final String? traduction;
  const MotMarque(
      {required this.mot, required this.definition, required this.nouveau, this.appris, this.traduction});
}

/// Traduit un mot (ou une définition) dans la langue de l'app et garde la traduction sur le téléphone.
Future<String> traduireMot(String texte) async {
  if (etat.langue == 'fr') return texte;
  final deja = traductionImmediate(texte);
  if (deja != null || !traductionArticlesPossible) return deja ?? texte;
  return _traduireEtGarder(texte, etat.langue);
}

/// Minuscules sans accents, de la MÊME longueur que le texte (pour retrouver les positions).
String _plat(String s) {
  const de = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ';
  const vers = 'aaaaaaceeeeiiiinooooouuuuyyoa';
  final b = StringBuffer();
  for (final u in s.codeUnits) {
    var ch = String.fromCharCode(u);
    final bas = ch.toLowerCase();
    if (bas.length == 1) ch = bas;
    final i = de.indexOf(ch);
    b.write(i < 0 ? ch : vers[i]);
  }
  return b.toString();
}

/// Morceaux de texte avec les mots cherchés surlignés, ou null s'il n'y en a aucun.
List<InlineSpan>? spansSurlignes(String t, List<String> mots) {
  final plat = _plat(t);
  final zones = <(int, int)>[];
  for (final m in mots) {
    final mp = _plat(m.trim());
    if (mp.length < 2) continue;
    var i = plat.indexOf(mp);
    while (i >= 0) {
      zones.add((i, i + mp.length));
      i = plat.indexOf(mp, i + mp.length);
    }
  }
  if (zones.isEmpty) return null;
  zones.sort((a, b) => a.$1.compareTo(b.$1));
  final spans = <InlineSpan>[];
  var pos = 0;
  for (final (d, f) in zones) {
    if (d < pos) continue;
    spans
      ..add(TextSpan(text: t.substring(pos, d)))
      ..add(TextSpan(
          text: t.substring(d, f),
          style: const TextStyle(backgroundColor: Color(0x55F5A524))));
    pos = f;
  }
  spans.add(TextSpan(text: t.substring(pos)));
  return spans;
}

/// Écritures sans espaces entre les mots (chinois, japonais) : on cherche le mot tel quel.
final RegExp _sansEspaces = RegExp(r'[\u3040-\u30ff\u3400-\u9fff]');

class TexteArticle extends StatefulWidget {
  final String texte;
  /// Mots à souligner (seulement quand le texte est affiché en français : ce sont des mots français).
  final List<MotMarque> marques;
  final void Function(MotMarque)? surMot;
  /// Mots à surligner (recherche), sans tenir compte des accents ni des majuscules.
  final List<String> surligne;
  final TextStyle style;
  final bool original; // true = toujours le texte français
  final TextAlign? textAlign;
  final int? maxLines; // null = sans limite ; sinon « … » à la fin
  final String Function(String)? nettoyer; // retouche le texte affiché (après traduction)
  const TexteArticle(this.texte,
      {super.key,
      required this.style,
      this.original = false,
      this.textAlign,
      this.maxLines,
      this.nettoyer,
      this.marques = const [],
      this.surMot,
      this.surligne = const []});

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
  final List<TapGestureRecognizer> _touches = [];

  void _liberer() {
    for (final t in _touches) {
      t.dispose();
    }
    _touches.clear();
  }

  @override
  void dispose() {
    _liberer();
    super.dispose();
  }

  /// Texte avec les mots repérés : pointillés + petit « + » (nouveau) ou « ✓ » (déjà appris).
  /// [francais] : vrai si t est le texte français, sinon on cherche le mot traduit.
  Widget _avecMots(String t, {required bool francais}) {
    _liberer();
    // Formes cherchées : le mot français, et sa traduction quand le texte est traduit.
    final formes = <(String, MotMarque)>[];
    for (final m in widget.marques) {
      final f = francais ? m.mot : (m.traduction ?? traductionImmediate(m.mot));
      if (f != null && f.trim().length >= 2) formes.add((f.trim(), m));
    }
    if (formes.isEmpty) return Text(t, style: widget.style, textAlign: widget.textAlign, maxLines: widget.maxLines);
    formes.sort((a, b) => b.$1.length.compareTo(a.$1.length));
    String motifDe(String f) => _sansEspaces.hasMatch(f)
        ? RegExp.escape(f)
        : '(?<![\\p{L}\\p{N}])${RegExp.escape(f)}(?:s|x|es)?(?![\\p{L}\\p{N}])';
    final motif = RegExp(formes.map((f) => motifDe(f.$1)).join('|'), caseSensitive: false, unicode: true);
    final vus = <String>{};
    final morceaux = <InlineSpan>[];
    var pos = 0;
    final nouveauC = const Color(0xFF2FC27B), connuC = const Color(0xFF8E8C9C);
    for (final m in motif.allMatches(t)) {
      final trouve = m.group(0)!.toLowerCase();
      final forme = formes.where((f) => trouve.startsWith(f.$1.toLowerCase())).firstOrNull;
      if (forme == null) continue;
      final mm = forme.$2;
      final cle = mm.mot.toLowerCase();
      if (vus.contains(cle)) continue; // seulement la 1re fois dans le paragraphe
      vus.add(cle);
      final c = mm.nouveau ? nouveauC : connuC;
      final touche = TapGestureRecognizer()..onTap = () => widget.surMot?.call(mm);
      _touches.add(touche);
      morceaux
        ..add(TextSpan(text: t.substring(pos, m.start)))
        ..add(TextSpan(
            text: m.group(0),
            recognizer: touche,
            style: TextStyle(
                decoration: TextDecoration.underline,
                decorationStyle: TextDecorationStyle.dotted,
                decorationColor: c,
                decorationThickness: 2)))
        ..add(WidgetSpan(
            alignment: PlaceholderAlignment.top,
            child: GestureDetector(
              onTap: () => widget.surMot?.call(mm),
              child: Text(mm.nouveau ? '+' : '✓',
                  style: TextStyle(
                      fontSize: (widget.style.fontSize ?? 16) * 0.62, fontWeight: FontWeight.w800, color: c, height: 1)),
            )));
      pos = m.end;
    }
    morceaux.add(TextSpan(text: t.substring(pos)));
    return Text.rich(TextSpan(style: widget.style, children: morceaux),
        textAlign: widget.textAlign, maxLines: widget.maxLines);
  }

  void _preparer() {
    final langue = etat.langue;
    final cle = '$langue|${widget.texte}';
    if (cle == _cle) return;
    _cle = cle;
    _traduction = _traduireEtGarder(widget.texte, langue);
  }

  /// Retouche du texte affiché, puis espaces insécables de la typographie française.
  String _net(String t) => insecables(widget.nettoyer == null ? t : widget.nettoyer!(t));

  @override
  Widget build(BuildContext context) {
    Text texte(String t) {
      final propre = _net(t);
      if (widget.surligne.isNotEmpty) {
        final spans = spansSurlignes(propre, widget.surligne);
        if (spans != null) {
          return Text.rich(TextSpan(style: widget.style, children: spans),
              textAlign: widget.textAlign,
              maxLines: widget.maxLines,
              overflow: widget.maxLines == null ? null : TextOverflow.ellipsis);
        }
      }
      return Text(propre,
          style: widget.style,
          textAlign: widget.textAlign,
          maxLines: widget.maxLines,
          overflow: widget.maxLines == null ? null : TextOverflow.ellipsis);
    }
    if (widget.original || etat.langue == 'fr') {
      final t = _net(widget.texte);
      if (widget.marques.isEmpty) return texte(widget.texte);
      try {
        return _avecMots(t, francais: true);
      } catch (_) {
        return texte(widget.texte); // par sécurité : texte normal si un mot pose problème
      }
    }
    // Texte traduit : les mots sont cherchés sous leur forme traduite (toutes les langues).
    Widget rendu(String traduit, {required bool francais}) {
      if (widget.marques.isEmpty) return texte(traduit);
      try {
        return _avecMots(_net(traduit), francais: francais);
      } catch (_) {
        return texte(traduit);
      }
    }
    final deja = traductionImmediate(widget.texte);
    if (deja != null) return rendu(deja, francais: false); // déjà traduit : tout de suite, sans saut
    if (!traductionArticlesPossible) return rendu(widget.texte, francais: true);
    _preparer();
    return FutureBuilder<String>(
      future: _traduction,
      builder: (context, snap) => snap.data == null
          ? rendu(widget.texte, francais: true)
          : rendu(snap.data!, francais: snap.data == widget.texte),
    );
  }
}

/// « Et après ? » est déjà le titre du paragraphe : on retire ces mots s'ils
/// ouvrent aussi le texte (« Et après ? Les chercheurs… » → « Les chercheurs… »),
/// en français comme dans les traductions.
final RegExp _debutEtApres = RegExp(
    r'^[\s«»"“”]*(et\s+apr[eè]s|and\s+next|and\s+after(?:wards)?|what\W?s\s+next|y\s+despu[eé]s|e\s+depois|und\s+danach|e\s+poi|en\s+daarna|a\s+potem|и\s+что\s+дальше|а\s+що\s+далі)[\s«»"“”?？!:：.…,;—–-]*',
    caseSensitive: false,
    unicode: true);

String sansEtApres(String t) {
  final m = _debutEtApres.firstMatch(t);
  if (m == null || m.end >= t.length) return t;
  final reste = t.substring(m.end);
  return reste[0].toUpperCase() + reste.substring(1);
}


/// 25/11 (Maxime : « les questions ne doivent pas revenir à la ligne pour un simple point
/// d'interrogation ») : l'espace avant ? ! : ; » et après « devient insécable. Même longueur de
/// texte, donc les mots soulignés gardent leur place.
String insecables(String t) => t
    .replaceAllMapped(RegExp(r' ([?!:;»])'), (m) => '\u00A0${m[1]}')
    .replaceAll('« ', '«\u00A0');
