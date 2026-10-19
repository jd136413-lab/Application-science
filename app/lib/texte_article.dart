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

class _TexteArticleState extends State<TexteArticle> {
  late Future<String> _traduction;
  String _cle = '';

  void _preparer() {
    final langue = etat.langue;
    final cle = '$langue|${widget.texte}';
    if (cle == _cle) return;
    _cle = cle;
    _traduction = traduireArticle(widget.texte, langue);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.original || etat.langue == 'fr' || !traductionArticlesPossible) {
      return Text(widget.texte, style: widget.style);
    }
    _preparer();
    return FutureBuilder<String>(
      future: _traduction,
      builder: (context, snap) => Text(snap.data ?? widget.texte, style: widget.style),
    );
  }
}
