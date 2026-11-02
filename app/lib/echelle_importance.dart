// Réexpliquer l'échelle d'importance après le premier lancement (maquettes 76 et 77,
// validées par Maxime le 02/11) :
// - A : toucher les étoiles dans la fiche d'une avancée → feuille sombre avec la
//   légende de la présentation, le niveau de l'avancée encadré ;
// - C : Réglages → « Comprendre NovaSTEM » → « Comment on note les avancées » ;
// - E : une bulle la première fois qu'on ouvre une avancée d'un niveau jamais vu
//   (5 fois au plus, une par niveau).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'etat.dart';
import 'langues.dart';
import 'reglages.dart';
import 'widgets.dart';

// Couleurs de l'écran de présentation (fond sombre, quel que soit le thème).
const Color _fond = Color(0xFF17161F);
const Color _gris = Color(0xFFB9B7C6);
const Color _discret = Color(0xFF8A8899);
const Color _ligne = Color(0xFF2A2935);
const Color _etoileVide = Color(0xFF45434F);

/// Les 5 niveaux, du plus rare au plus courant (mêmes mots que la présentation).
const List<(int, String)> niveauxImportance = [
  (5, 'historique, quelques fois par an'),
  (4, 'une première, qui touchera beaucoup de monde'),
  (3, 'change la donne dans son domaine'),
  (2, 'solide et remarqué par les spécialistes'),
  (1, 'un pas de plus, utile à connaître'),
];

/// Fréquence de chaque niveau (barème du 21/10).
const List<String> frequencesImportance = [
  '',
  'C’est la note la plus courante : environ 2 avancées sur 3.',
  'Environ 3 avancées par jour atteignent ce niveau.',
  'Quelques avancées par semaine atteignent ce niveau.',
  'Quelques avancées par mois atteignent ce niveau.',
  'Quelques avancées par an seulement atteignent ce niveau.',
];

String _phraseNiveau(int n) {
  for (final (k, d) in niveauxImportance) {
    if (k == n) {
      final t = tr(d);
      return t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
    }
  }
  return '';
}

/// La légende de la présentation ; [surligne] encadre un niveau en jaune.
class LegendeImportance extends StatelessWidget {
  final int? surligne;
  const LegendeImportance({super.key, this.surligne});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: _ligne))),
      child: Column(children: [
        for (final (n, d) in niveauxImportance)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            decoration: n == surligne
                ? BoxDecoration(
                    color: const Color(0xFF2E2B1C),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: couleurEtoiles, width: 1.5),
                  )
                : const BoxDecoration(border: Border(bottom: BorderSide(color: _ligne))),
            child: Row(children: [
              SizedBox(
                width: 82,
                child: Row(children: [
                  for (var i = 1; i <= 5; i++)
                    Icon(Icons.star_rounded, size: 16, color: i <= n ? couleurEtoiles : _etoileVide),
                ]),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 92,
                child: Text(tr(motsImportance[n]),
                    style: police(policeTexte, taille: 14, graisse: FontWeight.w700, couleur: Colors.white)),
              ),
              Expanded(
                child: Text(tr(d), style: police(policeTexte, taille: 12.5, couleur: _gris, hauteur: 1.3)),
              ),
            ]),
          ),
      ]),
    );
  }
}

/// A : feuille du bas ouverte en touchant les étoiles dans la fiche.
Future<void> ouvrirEchelleImportance(BuildContext context, int note) {
  note = note.clamp(1, 5);
  HapticFeedback.selectionClick();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _fond,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Center(
            child: Container(
                width: 40, height: 4, decoration: BoxDecoration(color: _etoileVide, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 14),
          Text(tr('Ce que veulent dire les étoiles'),
              style: police(policeTitres, taille: 21, graisse: FontWeight.w800, couleur: Colors.white)),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: '${tr('Cette avancée :')} '),
              TextSpan(
                  text: tr(motsImportance[note]),
                  style: police(policeTexte, taille: 13.5, graisse: FontWeight.w800, couleur: couleurEtoiles)),
              TextSpan(text: '. ${tr(frequencesImportance[note])}'),
            ]),
            style: police(policeTexte, taille: 13.5, couleur: _gris, hauteur: 1.4),
          ),
          const SizedBox(height: 12),
          LegendeImportance(surligne: note),
          const SizedBox(height: 12),
          Text(tr('Sélection et résumés automatisés · l’article source fait foi.'),
              style: police(policeTexte, taille: 11.5, couleur: _discret)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _fond,
                shape: const StadiumBorder(),
                textStyle: police(policeTexte, taille: 15, graisse: FontWeight.w700),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(tr('Fermer')),
            ),
          ),
        ]),
      ),
    ),
  );
}

/// A : les étoiles de la fiche. Les toucher ouvre l'échelle (pas sur les cartes du fil).
class EtoilesExpliquees extends StatelessWidget {
  final int note;
  final double taille;
  const EtoilesExpliquees({super.key, required this.note, this.taille = 18});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      hint: tr('Ce que veulent dire les étoiles'),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => ouvrirEchelleImportance(context, note),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Etoiles(note: note, taille: taille),
        ),
      ),
    );
  }
}

/// E : bulle affichée sous les étoiles la première fois qu'on ouvre une avancée
/// d'un niveau jamais vu (5 fois au plus en tout, une par niveau).
class BulleNiveau extends StatefulWidget {
  final int note;
  const BulleNiveau({super.key, required this.note});

  @override
  State<BulleNiveau> createState() => _BulleNiveauState();
}

class _BulleNiveauState extends State<BulleNiveau> {
  late bool _visible = widget.note >= 1 && widget.note <= 5 && !etat.niveauxVus.contains(widget.note);

  @override
  void initState() {
    super.initState();
    // Compté comme vu dès qu'il s'affiche : la bulle ne revient pas pour ce niveau.
    if (_visible) WidgetsBinding.instance.addPostFrameCallback((_) => etat.marquerNiveauVu(widget.note));
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: _Bulle(
        note: widget.note,
        onFermer: () => setState(() => _visible = false),
        onEchelle: () {
          setState(() => _visible = false);
          ouvrirEchelleImportance(context, widget.note);
        },
      ),
    );
  }
}

class _Bulle extends StatelessWidget {
  final int note;
  final VoidCallback onFermer, onEchelle;
  const _Bulle({required this.note, required this.onFermer, required this.onEchelle});

  @override
  Widget build(BuildContext context) {
    // Thème clair : bulle sombre. Thème sombre : bulle claire, sinon elle se fond dans la page.
    final sombre = estSombre(context);
    final fond = sombre ? const Color(0xFFF2F1F6) : _fond;
    final texte = sombre ? _fond : Colors.white;
    final detail = sombre ? const Color(0xFF3B3A47) : const Color(0xFFDDDBE5);
    final lien = sombre ? const Color(0xFF5E5C6B) : _gris;
    final vide = sombre ? const Color(0xFFC9C7D3) : _etoileVide;
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        decoration: BoxDecoration(
          color: fond,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: sombre ? const Color(0x66000000) : const Color(0x4717161F), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            for (var i = 1; i <= 5; i++)
              Icon(Icons.star_rounded, size: 16, color: i <= note ? couleurEtoiles : vide),
            const SizedBox(width: 8),
            Text(tr(motsImportance[note]),
                style: police(policeTexte, taille: 15, graisse: FontWeight.w800, couleur: texte)),
          ]),
          const SizedBox(height: 6),
          Text('${_phraseNiveau(note)}. ${tr(frequencesImportance[note])}',
              style: police(policeTexte, taille: 13, couleur: detail, hauteur: 1.45)),
          const SizedBox(height: 4),
          Row(children: [
            TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 40)),
              onPressed: onEchelle,
              child: Text(tr('Voir les 5 niveaux'),
                  style: police(policeTexte, taille: 12.5, graisse: FontWeight.w700, couleur: lien)
                      .copyWith(decoration: TextDecoration.underline, decorationColor: lien)),
            ),
            const Spacer(),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: texte,
                foregroundColor: fond,
                shape: const StadiumBorder(),
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                textStyle: police(policeTexte, taille: 13, graisse: FontWeight.w800),
              ),
              onPressed: onFermer,
              child: Text(tr('Compris')),
            ),
          ]),
        ]),
      ),
      Positioned(
        top: -6,
        left: 26,
        child: Transform.rotate(angle: 0.785398, child: Container(width: 13, height: 13, color: fond)),
      ),
    ]);
  }
}

/// C : Réglages → « Comment on note les avancées ».
class EcranCommentOnNote extends StatelessWidget {
  const EcranCommentOnNote({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _fond,
        appBar: AppBar(backgroundColor: _fond, foregroundColor: Colors.white, elevation: 0, scrolledUnderElevation: 0),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(22, 4, 22, 24), children: [
            Text(tr('Comment on note les avancées'),
                style: police(policeTitres, taille: 28, graisse: FontWeight.w800, couleur: Colors.white, hauteur: 1.1)),
            const SizedBox(height: 12),
            Text(
                tr('Chaque avancée reçoit de 1 à 5 étoiles selon son importance. Le barème est exigeant : la plupart des avancées ont 1 ou 2 étoiles.'),
                style: police(policeTexte, taille: 15, couleur: _gris, hauteur: 1.5)),
            const SizedBox(height: 16),
            const LegendeImportance(),
            const SizedBox(height: 16),
            Text(
                tr('On regarde la nouveauté réelle, le nombre de personnes concernées et la solidité des preuves : un essai chez l’humain compte plus qu’une étude chez l’animal.'),
                style: police(policeTexte, taille: 14, couleur: _gris, hauteur: 1.5)),
            const SizedBox(height: 16),
            Text(tr('Sélection et résumés automatisés · l’article source fait foi.'),
                style: police(policeTexte, taille: 11.5, couleur: _discret)),
          ]),
        ),
      ),
    );
  }
}
