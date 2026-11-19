// « Mes domaines suivis » en bulles (maquette 105 bis, 19/11/2026) : toucher une bulle ouvre les
// nouveautés du domaine en plein écran, une par une (comme des « stories »), à son rythme.
// Ici seulement (avec « À la une »), une fiche sans image a le visuel de son domaine
// (dégradé + symbole), comme sur la maquette : choix de Maxime du 19/11.

import 'package:flutter/material.dart';

import 'detail.dart';
import 'etat.dart';
import 'langues.dart';
import 'modele.dart';
import 'reglages.dart';
import 'stats.dart';
import 'texte_article.dart';
import 'widgets.dart';

/// Un domaine suivi et les fiches à montrer dans ses « stories ».
class GroupeDomaine {
  final String famille;
  final List<Avancee> fiches; // les plus récentes d'abord
  const GroupeDomaine(this.famille, this.fiches);

  /// Nouveautés : ajoutées il y a moins de 3 jours et pas encore ouvertes. Ce sont les seules
  /// fiches montrées ; un domaine sans nouveauté n'a pas de bulle (20/11).
  List<Avancee> get nouvelles => fiches.where(etat.estNouvelle).toList();

  /// Image de la bulle : celle d'une des nouveautés montrées (jamais d'une autre fiche).
  String? get image => nouvelles.map((a) => a.image).firstWhere((i) => (i ?? '').isNotEmpty, orElse: () => null);
}

/// Visuel d'un domaine : dégradé de sa couleur et son symbole en grand, très pâle.
class VisuelDomaine extends StatelessWidget {
  final Famille famille;
  const VisuelDomaine({super.key, required this.famille});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final h = c.maxHeight.isFinite ? c.maxHeight : 200.0;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [famille.couleur, Color.lerp(famille.couleur, const Color(0xFF15151C), 0.72)!],
            ),
          ),
          child: Align(
            alignment: const Alignment(0.8, -0.35),
            child: Icon(famille.symbole, size: h * 0.5, color: Colors.white.withValues(alpha: 0.18)),
          ),
        );
      });
}

/// Bulle ronde d'un domaine : anneau de couleur et nombre si des nouveautés n'ont pas été vues.
class BulleDomaine extends StatelessWidget {
  final GroupeDomaine groupe;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const BulleDomaine({super.key, required this.groupe, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final f = familleDe(groupe.famille);
    final n = groupe.nouvelles.length;
    final image = groupe.image;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        width: 76,
        child: Column(children: [
          Stack(clipBehavior: Clip.none, children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: n > 0 ? SweepGradient(colors: [f.couleur, f.encreSombre, f.couleur]) : null,
                color: n > 0 ? null : p.bordure,
              ),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(shape: BoxShape.circle, color: p.fond),
                child: ClipOval(
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: image != null
                        ? ImageGardee(url: image)
                        : VisuelDomaine(famille: f),
                  ),
                ),
              ),
            ),
            if (n > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 20),
                  height: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5A8A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: p.fond, width: 2),
                  ),
                  child: Text('$n', style: police(policeTexte, taille: 10.5, graisse: FontWeight.w800, couleur: Colors.white)),
                ),
              ),
          ]),
          const SizedBox(height: 5),
          Text(tr(f.nom),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: police(policeTexte,
                  taille: 11.5, graisse: n > 0 ? FontWeight.w800 : FontWeight.w500, couleur: n > 0 ? p.texte : p.texteDiscret)),
        ]),
      ),
    );
  }
}

/// Les « stories » : une fiche par écran ; toucher à droite = suivante, à gauche = précédente.
class EcranStories extends StatefulWidget {
  final List<GroupeDomaine> groupes;
  final int depart;
  const EcranStories({super.key, required this.groupes, required this.depart});

  @override
  State<EcranStories> createState() => _EcranStoriesState();
}

class _EcranStoriesState extends State<EcranStories> {
  late int _g = widget.depart;
  int _k = 0;
  late List<Avancee> _fiches = widget.groupes[_g].nouvelles;

  @override
  void initState() {
    super.initState();
    _vue();
  }

  void _vue() {
    if (_k >= _fiches.length) return;
    final a = _fiches[_k];
    if (!etat.estLue(a.id)) stat('lecture', a: a, valeur: 'stories');
    etat.marquerLue(a.id);
  }

  /// Après la dernière fiche d'un domaine : domaine suivant, ou fermeture s'il n'y en a plus.
  void _suivante() {
    if (_k + 1 < _fiches.length) {
      setState(() => _k++);
      _vue();
    } else {
      _domaineSuivant();
    }
  }

  void _precedente() {
    if (_k > 0) setState(() => _k--);
  }

  void _domaineSuivant() {
    if (_g + 1 >= widget.groupes.length) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _g++;
      _k = 0;
      _fiches = widget.groupes[_g].fiches.where((a) => !etat.estLue(a.id) && etat.estNouvelle(a)).toList();
    });
    if (_fiches.isEmpty) return _domaineSuivant();
    _vue();
  }

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final f = familleDe(widget.groupes[_g].famille);
    if (_fiches.isEmpty) return Scaffold(backgroundColor: p.fond); // le temps de se fermer
    final a = _fiches[_k];
    final image = (a.image ?? '').isNotEmpty ? a.image : null;
    // Une fiche a toujours un fond : son image, sinon le visuel de son domaine ; texte en blanc.
    const texte = Colors.white;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => d.localPosition.dx < MediaQuery.of(context).size.width / 3 ? _precedente() : _suivante(),
        child: Stack(fit: StackFit.expand, children: [
          ...[
            if (image != null)
              ImageAvancee(image: image, video: a.video, tailleBouton: 60)
            else
              VisuelDomaine(famille: familleDe(a.famille)),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.22, 0.4, 0.72],
                  colors: [Color(0x99000000), Color(0x00000000), Color(0x00000000), Color(0xEB000000)],
                ),
              ),
            ),
          ],
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // Barres de progression
                Row(children: [
                  for (var i = 0; i < _fiches.length; i++)
                    Expanded(
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: i <= _k ? texte : texte.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  TuileFamille(famille: f, taille: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        '${tr(f.nom)}  ·  ${_k + 1} / ${_fiches.length}',
                        style: police(policeTexte, taille: 14, graisse: FontWeight.w800, couleur: texte)),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: texte),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ]),
                const Spacer(),
                _fiche(a, texte, true),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _fiche(Avancee a, Color texte, bool surImage) {
    final favori = etat.estFavori(a.id);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Etoiles(note: a.importance, taille: 14, avecMot: false),
      const SizedBox(height: 8),
      TexteArticle(a.titre,
          style: police(policeTitres, taille: 24, graisse: FontWeight.w700, couleur: texte, hauteur: 1.2)),
      const SizedBox(height: 10),
      TexteArticle(a.decouverte,
          maxLines: surImage ? 4 : 8,
          style: police(policeTexte, taille: 15, couleur: texte.withValues(alpha: 0.88), hauteur: 1.45)),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: surImage ? Colors.white : logoEncreBleue,
              foregroundColor: surImage ? Colors.black : Colors.white,
              minimumSize: const Size.fromHeight(46),
            ),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => EcranDetailFil(liste: List.of(_fiches), depart: _k))),
            child: Text(tr('Lire la fiche'), style: police(policeTexte, taille: 15, graisse: FontWeight.w800)),
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filledTonal(
          onPressed: () => setState(() => etat.basculerFavori(a)),
          icon: Icon(favori ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
        ),
      ]),
    ]);
  }
}
