// Écran de détail d'une avancée.

import 'package:flutter/material.dart';

import 'carte.dart';
import 'echelle_importance.dart';
import 'etat.dart';
import 'langues.dart';
import 'modele.dart';
import 'reglages.dart';
import 'retours.dart';
import 'stats.dart';
import 'texte_article.dart';
import 'traducteur.dart';
import 'widgets.dart';

/// Détail d'une avancée, en glissant à gauche / à droite pour passer à la
/// suivante / précédente du même fil (dans l'ordre affiché dans la liste).
class EcranDetailFil extends StatefulWidget {
  final List<Avancee> liste;
  final int depart;
  const EcranDetailFil({super.key, required this.liste, required this.depart});

  @override
  State<EcranDetailFil> createState() => _EcranDetailFilState();
}

class _EcranDetailFilState extends State<EcranDetailFil> {
  late final PageController _pages = PageController(initialPage: widget.depart);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => etat.apprendre(widget.liste[widget.depart]));
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _changement(int i) {
    final a = widget.liste[i];
    stat('lecture', a: a, valeur: 'glisse'); // avancée ouverte en glissant depuis la précédente
    etat.marquerLue(a.id);
    etat.apprendre(a);
  }

  @override
  Widget build(BuildContext context) => PageView.builder(
        controller: _pages,
        itemCount: widget.liste.length,
        onPageChanged: _changement,
        itemBuilder: (context, i) => EcranDetail(avancee: widget.liste[i], apprendreAuto: false),
      );
}

class EcranDetail extends StatelessWidget {
  final Avancee avancee;

  /// false quand l'écran est une page de [EcranDetailFil] (qui s'en charge).
  final bool apprendreAuto;
  const EcranDetail({super.key, required this.avancee, this.apprendreAuto = true});

  Future<void> _ouvrir(BuildContext context) async {
    final uri = Uri.tryParse(avancee.lien);
    stat('article', a: avancee);
    if (uri == null || !await ouvrirArticle(uri)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Impossible d’ouvrir l’article'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Les « mots à connaître » de l'avancée ouverte rejoignent l'onglet Vocabulaire.
    if (apprendreAuto) WidgetsBinding.instance.addPostFrameCallback((_) => etat.apprendre(avancee));
    final p = palette(context);
    final f = familleDe(avancee.famille);
    final encre = estSombre(context) ? f.encreSombre : f.encreClaire;
    final aPhoto = avancee.image != null;

    Widget boutonRond(IconData icone, String libelle, VoidCallback action) => Material(
          color: aPhoto ? Colors.white.withValues(alpha: 0.92) : p.fond,
          shape: const CircleBorder(),
          child: IconButton(
            icon: Icon(icone, color: aPhoto ? const Color(0xFF17161F) : p.texte),
            tooltip: libelle,
            onPressed: action,
          ),
        );

    Widget favori() => ListenableBuilder(
          listenable: etat,
          builder: (context, _) {
            final oui = etat.estFavori(avancee.id);
            return boutonRond(oui ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                oui ? tr('Retirer des favoris') : tr('Ajouter aux favoris'), () => etat.basculerFavori(avancee));
          },
        );

    final contenu = Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          TuileFamille(famille: f, taille: 32),
          const SizedBox(width: 10),
          Flexible(
            child: Text(tr(f.nom), style: police(policeTexte, taille: 14, graisse: FontWeight.w700, couleur: encre)),
          ),
          Text('  · ${dateLongue(avancee.publieLe)}', style: police(policeTexte, taille: 14, couleur: p.texteDiscret)),
        ]),
        const SizedBox(height: 16),
        _TitreEtResume(avancee: avancee),
        const SizedBox(height: 18),
        avancee.autresSources.isEmpty
            ? Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: p.fond, borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  _TuileSource(nom: avancee.source, fond: p.carte, taille: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(avancee.source, style: police(policeTexte, taille: 15, graisse: FontWeight.w700, couleur: p.texte)),
                      Text(_domaine(avancee.lien), style: police(policeTexte, taille: 13, couleur: p.texteDiscret)),
                    ]),
                  ),
                ]),
              )
            : _Sources(avancee: avancee),
      ]),
    );

    return Scaffold(
      backgroundColor: p.carte,
      body: SafeArea(
        child: GlisserPourFermer(
          child: Column(children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (aPhoto)
                  SizedBox(
                    height: 270,
                    child: Stack(fit: StackFit.expand, children: [
                      ImageGardee(url: avancee.image!),
                      if ((avancee.creditImage ?? '').isNotEmpty)
                        Positioned(
                          right: 10,
                          bottom: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                            child: Text(avancee.creditImage!,
                                style: police(policeTexte, taille: 11, graisse: FontWeight.w600, couleur: Colors.white)),
                          ),
                        ),
                      Positioned(
                        top: 12,
                        left: 12,
                        child: boutonRond(Icons.arrow_back_rounded, tr('Retour'), () => Navigator.of(context).pop()),
                      ),
                      Positioned(top: 12, right: 12, child: favori()),
                    ]),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      boutonRond(Icons.arrow_back_rounded, tr('Retour'), () => Navigator.of(context).pop()),
                      favori(),
                    ]),
                  ),
                contenu,
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(children: [
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: p.encre,
                    foregroundColor: p.surEncre,
                    shape: const StadiumBorder(),
                    textStyle: police(policeTexte, taille: 16, graisse: FontWeight.w700),
                  ),
                  onPressed: () => _ouvrir(context),
                  icon: const Icon(Icons.north_east_rounded),
                  label: Text(tr(texteLireArticle)),
                ),
              ),
              const SizedBox(height: 6),
              Text(tr(texteMentionResume), textAlign: TextAlign.center, style: police(policeTexte, taille: 12, couleur: p.texteDiscret)),
              TextButton.icon(
                onPressed: () => signalerErreur(context, avancee),
                style: TextButton.styleFrom(
                    foregroundColor: p.texte, visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 10)),
                icon: const Icon(Icons.flag_outlined, size: 16),
                label: Text(tr('Signaler une erreur'),
                    style: police(policeTexte, taille: 13, graisse: FontWeight.w700, couleur: p.texte)),
              ),
            ]),
          ),
        ]),
        ),
      ),
    );
  }
}

/// Titre, étoiles et résumé, traduits si besoin, avec « Voir l'original ».
class _TitreEtResume extends StatefulWidget {
  final Avancee avancee;
  const _TitreEtResume({required this.avancee});

  @override
  State<_TitreEtResume> createState() => _TitreEtResumeState();
}

class _TitreEtResumeState extends State<_TitreEtResume> {
  bool _original = false;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final a = widget.avancee;
    final traduit = etat.langue != 'fr' && (traductionArticlesPossible || traductionAgent(a.titre) != null);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TexteArticle(a.titre,
          original: _original,
          style: police(policeTitres, taille: 27, graisse: FontWeight.w800, couleur: p.texte, hauteur: 1.12)),
      const SizedBox(height: 14),
      Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        EtoilesExpliquees(note: a.importance, taille: 18),
        if (a.typeEtude != null && badgesEtude.containsKey(a.typeEtude)) BadgeEtude(code: a.typeEtude!),
      ]),
      BulleNiveau(note: a.importance),
      const SizedBox(height: 16),
      if (!a.nouveauResume)
        TexteArticle(a.resume,
            original: _original, style: police(policeTexte, taille: 17, couleur: p.texte, hauteur: 1.6))
      else ...[
        for (final (titre, texte) in [
          (texteAvant, a.avant),
          (a.fil == 'tech' ? texteNouveaute : texteDecouverte, a.decouverte),
          (texteEtApres, a.apres),
        ])
          if (texte.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr(titre).toUpperCase(),
                    style: police(policeTexte, taille: 12, graisse: FontWeight.w800, couleur: p.texteDiscret)),
                const SizedBox(height: 4),
                TexteArticle(texte,
                    original: _original,
                    nettoyer: titre == texteEtApres ? sansEtApres : null,
                    style: police(policeTexte, taille: 16, couleur: p.texte, hauteur: 1.55)),
              ]),
            ),
        if (a.mots.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.bordure, width: 1.5),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr(texteMotsAConnaitre).toUpperCase(),
                  style: police(policeTexte, taille: 12, graisse: FontWeight.w800, couleur: p.texteDiscret)),
              for (final m in a.mots) ...[
                const SizedBox(height: 8),
                TexteArticle('${m.mot} : ${m.definition}',
                    original: _original, style: police(policeTexte, taille: 14, couleur: p.texte, hauteur: 1.45)),
              ],
            ]),
          ),
      ],
      if (traduit) ...[
        const SizedBox(height: 10),
        Row(children: [
          Icon(Icons.translate_rounded, size: 16, color: p.texteDiscret),
          const SizedBox(width: 6),
          Flexible(
            child: Text(_original ? 'Français' : tr('Traduit automatiquement'),
                style: police(policeTexte, taille: 13, couleur: p.texteDiscret)),
          ),
          TextButton(
            onPressed: () => setState(() => _original = !_original),
            child: Text(_original ? tr('Voir la traduction') : tr('Voir l’original'),
                style: police(policeTexte, taille: 13, graisse: FontWeight.w700, couleur: p.texte)),
          ),
        ]),
      ],
    ]);
  }
}

// ---------------------------------------------------------------------------
// Plusieurs sources pour une même avancée (maquette 49, disposition B1) :
// une ligne repliée « Source + N autres » avec les initiales empilées ; un
// toucher la déplie en liste (source principale en premier). Chaque source
// s'ouvre dans l'app.

String _domaine(String lien) => Uri.tryParse(lien)?.host.replaceFirst('www.', '') ?? '';

/// Fonds des initiales empilées (bleu, rose, vert, jaune pâles), en boucle.
const List<Color> _fondsSources = [Color(0xFFE3EDFF), Color(0xFFFFE3EA), Color(0xFFE5F6EC), Color(0xFFFFF1D6)];

class _TuileSource extends StatelessWidget {
  final String nom;
  final Color fond;
  final double taille;
  const _TuileSource({required this.nom, required this.fond, this.taille = 34});

  @override
  Widget build(BuildContext context) => Container(
        width: taille,
        height: taille,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: fond, borderRadius: BorderRadius.circular(taille / 3)),
        child: Text(nom.isEmpty ? '?' : nom.characters.first.toUpperCase(),
            style: police(policeTitres, taille: taille * 0.45, graisse: FontWeight.w800, couleur: const Color(0xFF17161F))),
      );
}

class _Sources extends StatefulWidget {
  final Avancee avancee;
  const _Sources({required this.avancee});

  @override
  State<_Sources> createState() => _SourcesState();
}

class _SourcesState extends State<_Sources> {
  bool _ouvert = false;

  Future<void> _ouvrirSource(String nom, String lien) async {
    final uri = Uri.tryParse(lien);
    stat('article', a: widget.avancee, valeur: nom == widget.avancee.source ? null : 'autre_source');
    if (uri == null || !await ouvrirArticle(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Impossible d’ouvrir l’article'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final a = widget.avancee;
    final n = a.autresSources.length;
    final noms = [a.source, for (final s in a.autresSources) s.nom];
    final sombre = estSombre(context);

    Widget pile() => SizedBox(
          width: 30.0 + 20.0 * (noms.take(4).length - 1),
          height: 34,
          child: Stack(children: [
            for (var i = 0; i < noms.take(4).length; i++)
              Positioned(
                left: 20.0 * i,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(color: p.carte, borderRadius: BorderRadius.circular(12)),
                  child: _TuileSource(nom: noms[i], fond: _fondsSources[i % 4], taille: 30),
                ),
              ),
          ]),
        );

    Widget ligne(String nom, String lien, String langue, {bool principale = false, required int rang}) {
      final nomLangue = languesDisponibles[langue];
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Material(
          color: p.fond,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _ouvrirSource(nom, lien),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(children: [
                _TuileSource(nom: nom, fond: _fondsSources[rang % 4]),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(nom, style: police(policeTexte, taille: 14, graisse: FontWeight.w700, couleur: p.texte)),
                    Text(nomLangue == null ? _domaine(lien) : '${_domaine(lien)} · $nomLangue',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: police(policeTexte, taille: 12, couleur: p.texteDiscret)),
                  ]),
                ),
                if (principale)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: sombre ? const Color(0xFF233A66) : const Color(0xFFE3EDFF),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(tr('Source principale'),
                        style: police(policeTexte, taille: 11, graisse: FontWeight.w700,
                            couleur: sombre ? const Color(0xFFBBD0FF) : const Color(0xFF1F4FB8))),
                  ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: p.texteDiscret, size: 20),
              ]),
            ),
          ),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _ouvert = !_ouvert),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.bordure, width: 1.5),
            ),
            child: Row(children: [
              pile(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${a.source} ${n == 1 ? tr('+ 1 autre') : tr('+ {n} autres', n: n)}',
                      style: police(policeTexte, taille: 14, graisse: FontWeight.w700, couleur: p.texte)),
                  Text(_ouvert ? tr('Toucher pour replier') : tr('Voir toutes les sources'),
                      style: police(policeTexte, taille: 12, couleur: p.texteDiscret)),
                ]),
              ),
              AnimatedRotation(
                turns: _ouvert ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.expand_more_rounded, color: p.texteDiscret),
              ),
            ]),
          ),
        ),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: !_ouvert
            ? const SizedBox(width: double.infinity)
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SizedBox(height: 2),
                ligne(a.source, a.lien, '', principale: true, rang: 0),
                for (var i = 0; i < n; i++)
                  ligne(a.autresSources[i].nom, a.autresSources[i].url, a.autresSources[i].langue, rang: i + 1),
              ]),
      ),
    ]);
  }
}
