// Texte d'un article (titre ou résumé), traduit dans la langue de l'app.
// Le texte français s'affiche tout de suite, puis est remplacé par sa
// traduction dès qu'elle est prête.

import 'package:flutter/material.dart';

import 'etat.dart';
import 'traducteur.dart';

class TexteArticle extends StatefulWidget {
  final String texte;
  final TextStyle style;
  final bool original; // true = toujours le texte français
  const TexteArticle(this.texte, {super.key, required this.style, this.original = false});

  @override
  State<TexteArticle> createState() => _TexteArticleState();
}

/// Traductions déjà faites (« langue|texte » → traduction), gardées en mémoire
/// pendant que l'app est ouverte. Sans elles, une carte qui revient à l'écran
/// s'affichait d'abord en français puis traduite : sa hauteur changeait et le
/// fil faisait des va-et-vient en remontant.
final Map<String, String> _traductionsPretes = {};

class _TexteArticleState extends State<TexteArticle> {
  late Future<String> _traduction;
  String _cle = '';

  void _preparer() {
    final langue = etat.langue;
    final cle = '$langue|${widget.texte}';
    if (cle == _cle) return;
    _cle = cle;
    _traduction = traduireArticle(widget.texte, langue).then((t) {
      _traductionsPretes[cle] = t;
      return t;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.original || etat.langue == 'fr' || !traductionArticlesPossible) {
      return Text(widget.texte, style: widget.style);
    }
    final deja = _traductionsPretes['${etat.langue}|${widget.texte}'];
    if (deja != null) return Text(deja, style: widget.style); // déjà traduit : tout de suite, sans saut
    _preparer();
    return FutureBuilder<String>(
      future: _traduction,
      builder: (context, snap) => Text(snap.data ?? widget.texte, style: widget.style),
    );
  }
}
