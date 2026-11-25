// Écran de détail d'une avancée.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'admin_suppression.dart';
import 'carte.dart';
import 'echelle_importance.dart';
import 'etat.dart';
import 'fils.dart' show filsAvancees;
import 'langues.dart';
import 'modele.dart';
import 'propositions.dart' show adminSupprimerFiche;
import 'pubs.dart';
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
    statArticle(avancee);
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
        // Vidéo à l'appui (08/11), seulement si l'agent en a trouvé une qui montre l'avancée.
        if ((avancee.video ?? '').isNotEmpty) ...[
          const SizedBox(height: 18),
          BoutonVideo(lien: avancee.video!, titre: avancee.videoTitre),
        ],
        const SizedBox(height: 18),
        BlocSources(source: avancee.source, lien: avancee.lien, autres: avancee.autresSources, avancee: avancee),
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
                      if (estImageVideo(avancee.image)) BoutonLecture(video: avancee.video, taille: 60),
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
                // Mention IA (obligatoire) et « Signaler une erreur » : à la fin du résumé.
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: Column(children: [
                    Text(tr(texteMentionResume),
                        textAlign: TextAlign.center, style: police(policeTexte, taille: 12, couleur: p.texteDiscret)),
                    TextButton.icon(
                      onPressed: () => signalerErreur(context, avancee),
                      style: TextButton.styleFrom(
                          foregroundColor: p.texte,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10)),
                      icon: const Icon(Icons.flag_outlined, size: 16),
                      label: Text(tr('Signaler une erreur'),
                          style: police(policeTexte, taille: 13, graisse: FontWeight.w700, couleur: p.texte)),
                    ),
                    BoutonSuppressionAdmin(
                      quoi: 'cette fiche',
                      supprimer: () => adminSupprimerFiche(avancee.id),
                      apres: () async {
                        await filsAvancees.mettreAJour(avancee.fil, complet: true);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                  ]),
                ),
              ]),
            ),
          ),
          // Barre collée compacte (maquette 81 · C) : seulement « ↗ Lire l'article »,
          // pour laisser la place au futur bandeau publicitaire.
          Container(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: p.bordure.withValues(alpha: 0.5)))),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: p.encre,
                  foregroundColor: p.surEncre,
                  shape: const StadiumBorder(),
                  textStyle: police(policeTexte, taille: 15, graisse: FontWeight.w700),
                ),
                onPressed: () => _ouvrir(context),
                icon: const Icon(Icons.north_east_rounded, size: 20),
                label: Text(tr(texteLireArticle)),
              ),
            ),
          ),
          // Petit bandeau publicitaire (scénario D), sous « Lire l'article ».
          const BandeauPub(),
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
  /// Mots déjà dans le Vocabulaire AVANT l'ouverture de la fiche (les siens y sont ajoutés juste après).
  late final Set<String> _connusAvant = {for (final v in etat.vocabulaire) v.mot.toLowerCase()};
  /// Bulle ouverte : (n° du paragraphe, mot touché).
  (int, MotMarque)? _bulle;

  @override
  void initState() {
    super.initState();
    _traduireMots();
  }

  /// App dans une autre langue : traduit à l'avance les mots repérés (gardés sur le téléphone),
  /// pour les retrouver dans le texte traduit. Les mots traduits par l'agent sont déjà prêts.
  Future<void> _traduireMots() async {
    if (etat.langue == 'fr') return;
    final a = widget.avancee;
    final langue = etat.langue;
    var nouveau = false;
    for (final m in _marques(a.texteResume)) {
      if ((m.traduction ?? traductionImmediate(m.mot)) != null) continue;
      try {
        final t = await traduireMot(m.mot);
        if (t.trim().isNotEmpty && t != m.mot) {
          etat.garderTraductionMot(m.mot, langue, t.trim());
          nouveau = true;
        }
      } catch (_) {}
    }
    if (nouveau && mounted) setState(() {});
  }

  /// Mots à repérer dans ce texte : ceux de la fiche (nouveaux ou non) et ceux du Vocabulaire qu'il contient.
  List<MotMarque> _marques(String texte) {
    final bas = texte.toLowerCase();
    final res = <String, MotMarque>{};
    for (final m in widget.avancee.mots) {
      final cle = m.mot.toLowerCase();
      if (!bas.contains(cle)) continue;
      final appris = etat.vocabulaire.where((v) => v.mot.toLowerCase() == cle).firstOrNull;
      res[cle] = MotMarque(
          mot: m.mot,
          definition: m.definition,
          nouveau: !_connusAvant.contains(cle),
          appris: appris?.appris,
          traduction: appris?.traductions[etat.langue]);
    }
    for (final v in etat.vocabulaire) {
      final cle = v.mot.toLowerCase();
      if (res.containsKey(cle) || !_connusAvant.contains(cle) || cle.length < 3 || !bas.contains(cle)) continue;
      res[cle] = MotMarque(
          mot: v.mot, definition: v.definition, nouveau: false, appris: v.appris, traduction: v.traductions[etat.langue]);
    }
    return res.values.toList();
  }

  Widget _bulleMot(MotMarque m) {
    final p = palette(context);
    final c = m.nouveau ? const Color(0xFF2FC27B) : p.texteDiscret;
    final d = m.appris;
    final quand = d == null
        ? ''
        : trv('Appris le {date}', {'date': '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}'});
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
        color: p.carte,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withValues(alpha: 0.45), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          TexteArticle(m.mot,
              original: _original,
              style: police(policeTexte, taille: 14.5, graisse: FontWeight.w800, couleur: p.texte)),
          Text(m.nouveau ? '+ ${tr('nouveau mot')}' : '✓ ${tr('déjà dans ton Vocabulaire')}',
              style: police(policeTexte, taille: 12, graisse: FontWeight.w700, couleur: c)),
        ]),
        const SizedBox(height: 4),
        TexteArticle(m.definition,
            original: _original, style: police(policeTexte, taille: 14, couleur: p.texte, hauteur: 1.45)),
        Row(children: [
          Expanded(
              child: Text(m.nouveau ? tr('Ajouté à ton Vocabulaire') : quand,
                  style: police(policeTexte, taille: 12, couleur: p.texteDiscret))),
          TextButton(onPressed: () => setState(() => _bulle = null), child: Text(tr('Fermer'))),
        ]),
      ]),
    );
  }

  /// Paragraphe du résumé, avec ses mots à connaître soulignés et sa bulle (n° k).
  Widget _paragraphe(int k, String texte, double taille, Color couleur, {FontWeight? graisse}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TexteArticle(texte,
          original: _original,
          marques: _marques(texte),
          surMot: (m) => setState(() => _bulle = _bulle?.$1 == k && _bulle?.$2.mot == m.mot ? null : (k, m)),
          style: police(policeTexte, taille: taille, graisse: graisse, couleur: couleur, hauteur: 1.55)),
      if (_bulle != null && _bulle!.$1 == k) _bulleMot(_bulle!.$2),
    ]);
  }

  Widget _intertitre(String t, Palette p) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(tr(t).toUpperCase(),
            style: police(policeTexte, taille: 12, graisse: FontWeight.w800, couleur: p.texteDiscret)),
      );

  /// Résumé « à blocs » (plan D, maquette 109) : En bref, En chiffres, blocs-questions,
  /// Ce qu'on ne sait pas encore.
  List<Widget> _resumeABlocs(Palette p, Avancee a) {
    final res = <Widget>[];
    var k = 0;
    for (final b in a.blocs) {
      k++;
      switch (b.cle) {
        case 'chapo':
          res.add(Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            // 25/11 : l'écran de détail a déjà le fond des cartes ; l'encadré prend un gris visible (maquette 109)
            decoration: BoxDecoration(color: estSombre(context) ? p.pastille : p.fond, borderRadius: BorderRadius.circular(14)),
            child: _paragraphe(k, b.texte, 16.5, p.texte, graisse: FontWeight.w600),
          ));
        case 'en_chiffres':
          res.add(Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _intertitre(texteEnChiffres, p),
              Container(
                padding: const EdgeInsets.only(left: 12, top: 2, bottom: 2),
                decoration: BoxDecoration(border: Border(left: BorderSide(color: couleurEtoiles, width: 3))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final (v, sens) in b.chiffres)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 86, maxWidth: 130),
                          child: TexteArticle(v,
                              original: _original,
                              style: police(policeTitres, taille: 17, graisse: FontWeight.w800, couleur: couleurEtoiles, hauteur: 1.25)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TexteArticle(sens,
                              original: _original,
                              style: police(policeTexte, taille: 14, couleur: p.texteDiscret, hauteur: 1.4)),
                        ),
                      ]),
                    ),
                ]),
              ),
            ]),
          ));
        case 'limites':
          res.add(Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _intertitre(texteInconnu, p),
              for (final (j, x) in b.puces.indexed)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1, right: 8),
                      child: Text('•', style: police(policeTexte, taille: 16, couleur: p.texte)),
                    ),
                    Expanded(child: _paragraphe(100 * k + j, x, 15.5, p.texte)),
                  ]),
                ),
            ]),
          ));
        default:
          final fixe = libellesBlocs[b.cle];
          res.add(Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (b.question != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: TexteArticle(b.question!,
                      original: _original,
                      style: police(policeTitres,
                          taille: 17,
                          graisse: FontWeight.w700,
                          couleur: estSombre(context) ? familleDe(a.famille).encreSombre : familleDe(a.famille).encreClaire,
                          hauteur: 1.25)),
                )
              else if (fixe != null)
                _intertitre(a.fil == 'tech' ? fixe.$2 : fixe.$1, p),
              _paragraphe(k, b.texte, 16, p.texte),
            ]),
          ));
      }
    }
    return res;
  }

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
        if (a.blocs.isNotEmpty)
          ..._resumeABlocs(p, a)
        else
        for (final (i, (titre, texte)) in [
          (texteAvant, a.avant),
          (a.fil == 'tech' ? texteNouveaute : texteDecouverte, a.decouverte),
          (texteEtApres, a.apres),
        ].indexed)
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
                    marques: _marques(texte),
                    surMot: (m) => setState(() => _bulle = _bulle?.$1 == i && _bulle?.$2.mot == m.mot ? null : (i, m)),
                    style: police(policeTexte, taille: 16, couleur: p.texte, hauteur: 1.55)),
                if (_bulle != null && _bulle!.$1 == i) _bulleMot(_bulle!.$2),
              ]),
            ),
        // Encadré du bas : seulement les mots NOUVEAUX pour cette personne (maquette 101 C)
        if (a.mots.any((m) => !_connusAvant.contains(m.mot.toLowerCase())))
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
              for (final m in a.mots.where((m) => !_connusAvant.contains(m.mot.toLowerCase()))) ...[
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

/// Sources d'une avancée ou d'un événement À venir (planche 49 · B1) :
/// une seule source = une tuile ; plusieurs = « X + N autres », dépliable.
class BlocSources extends StatefulWidget {
  final String source, lien;
  final List<SourceAvancee> autres;
  final Avancee? avancee; // pour les statistiques (null pour un événement À venir)
  const BlocSources({super.key, required this.source, required this.lien, this.autres = const [], this.avancee});

  @override
  State<BlocSources> createState() => _BlocSourcesState();
}

class _BlocSourcesState extends State<BlocSources> {
  bool _ouvert = false;

  Future<void> _ouvrirSource(String nom, String lien) async {
    final uri = Uri.tryParse(lien);
    if (widget.avancee != null) statArticle(widget.avancee!, valeur: nom == widget.source ? null : 'autre_source');
    if (uri == null || !await ouvrirArticle(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Impossible d’ouvrir l’article'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final w = widget;
    final n = w.autres.length;
    final noms = [w.source, for (final s in w.autres) s.nom];
    final sombre = estSombre(context);

    if (n == 0) {
      return Material(
        color: p.fond,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _ouvrirSource(w.source, w.lien),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              _TuileSource(nom: w.source, fond: p.carte, taille: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(w.source, style: police(policeTexte, taille: 15, graisse: FontWeight.w700, couleur: p.texte)),
                  Text(_domaine(w.lien), style: police(policeTexte, taille: 13, couleur: p.texteDiscret)),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: p.texteDiscret, size: 20),
            ]),
          ),
        ),
      );
    }

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
                  Text('${w.source} ${n == 1 ? tr('+ 1 autre') : tr('+ {n} autres', n: n)}',
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
                ligne(w.source, w.lien, '', principale: true, rang: 0),
                for (var i = 0; i < n; i++) ligne(w.autres[i].nom, w.autres[i].url, w.autres[i].langue, rang: i + 1),
              ]),
      ),
    ]);
  }
}


/// Bouton « ▶ Voir la vidéo » (avancée ou événement) : ouvre la vidéo (YouTube, Vimeo,
/// Dailymotion) dans l'application concernée. Le titre de la vidéo s'affiche dessous.
class BoutonVideo extends StatelessWidget {
  final String lien;
  final String? titre;
  const BoutonVideo({super.key, required this.lien, this.titre});

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final uri = Uri.tryParse(lien);
    return Material(
      color: p.carte,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: uri == null ? null : () => launchUrl(uri, mode: LaunchMode.externalApplication),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: const Color(0xFFE5484D), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('Voir la vidéo'), style: police(policeTexte, taille: 15, graisse: FontWeight.w800, couleur: p.texte)),
                if ((titre ?? '').isNotEmpty)
                  Text(titre!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: police(policeTexte, taille: 12.5, couleur: p.texteDiscret, hauteur: 1.3)),
              ]),
            ),
            Icon(Icons.open_in_new_rounded, size: 18, color: p.texteDiscret),
          ]),
        ),
      ),
    );
  }
}
