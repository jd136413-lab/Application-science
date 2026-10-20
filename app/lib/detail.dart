// Écran de détail d'une avancée.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'etat.dart';
import 'langues.dart';
import 'modele.dart';
import 'reglages.dart';
import 'texte_article.dart';
import 'traducteur.dart';
import 'widgets.dart';

class EcranDetail extends StatelessWidget {
  final Avancee avancee;
  const EcranDetail({super.key, required this.avancee});

  Future<void> _ouvrir(BuildContext context) async {
    final uri = Uri.tryParse(avancee.lien);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Impossible d’ouvrir l’article'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: p.fond, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: p.carte, borderRadius: BorderRadius.circular(12)),
              child: Text(avancee.source.isEmpty ? '?' : avancee.source.characters.first.toUpperCase(),
                  style: police(policeTitres, taille: 18, graisse: FontWeight.w800, couleur: p.texte)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(avancee.source, style: police(policeTexte, taille: 15, graisse: FontWeight.w700, couleur: p.texte)),
                Text(Uri.tryParse(avancee.lien)?.host.replaceFirst('www.', '') ?? '',
                    style: police(policeTexte, taille: 13, couleur: p.texteDiscret)),
              ]),
            ),
          ]),
        ),
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
                      Image.network(avancee.image!,
                          fit: BoxFit.cover,
                          semanticLabel: tr('Photo fournie par la source'),
                          errorBuilder: (c, e, s) => Container(color: p.pastille)),
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
              const SizedBox(height: 8),
              Text(tr(texteMentionResume), textAlign: TextAlign.center, style: police(policeTexte, taille: 12, couleur: p.texteDiscret)),
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
    final f = familleDe(a.famille);
    final traduit = etat.langue != 'fr' && traductionArticlesPossible;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TexteArticle(a.titre,
          original: _original,
          style: police(policeTitres, taille: 27, graisse: FontWeight.w800, couleur: p.texte, hauteur: 1.12)),
      const SizedBox(height: 14),
      Etoiles(note: a.importance, taille: 18),
      const SizedBox(height: 16),
      TexteArticle(a.resume,
          original: _original, style: police(policeTexte, taille: 17, couleur: p.texte, hauteur: 1.6)),
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
