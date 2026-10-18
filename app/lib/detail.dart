// Écran de détail d'une avancée.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'modele.dart';
import 'reglages.dart';
import 'widgets.dart';

class EcranDetail extends StatelessWidget {
  final Avancee avancee;
  const EcranDetail({super.key, required this.avancee});

  Future<void> _ouvrir(BuildContext context) async {
    final uri = Uri.tryParse(avancee.lien);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible d’ouvrir l’article')));
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

    final contenu = Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          TuileFamille(famille: f, taille: 32),
          const SizedBox(width: 10),
          Flexible(
            child: Text(f.nom, style: police(policeTexte, taille: 14, graisse: FontWeight.w700, couleur: encre)),
          ),
          Text('  · ${dateLongue(avancee.publieLe)}', style: police(policeTexte, taille: 14, couleur: p.texteDiscret)),
        ]),
        const SizedBox(height: 16),
        Text(avancee.titre,
            style: police(policeTitres, taille: 27, graisse: FontWeight.w800, couleur: p.texte, hauteur: 1.12)),
        const SizedBox(height: 14),
        Etoiles(note: avancee.importance, couleur: f.couleur, taille: 18),
        const SizedBox(height: 16),
        Text(avancee.resume, style: police(policeTexte, taille: 17, couleur: p.texte, hauteur: 1.6)),
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
        child: Column(children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (aPhoto)
                  SizedBox(
                    height: 270,
                    child: Stack(fit: StackFit.expand, children: [
                      Image.network(avancee.image!,
                          fit: BoxFit.cover,
                          semanticLabel: 'Photo fournie par la source',
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
                        child: boutonRond(Icons.arrow_back_rounded, 'Retour', () => Navigator.of(context).pop()),
                      ),
                    ]),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: boutonRond(Icons.arrow_back_rounded, 'Retour', () => Navigator.of(context).pop()),
                    ),
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
                  label: const Text(texteLireArticle),
                ),
              ),
              const SizedBox(height: 8),
              Text(texteMentionResume, style: police(policeTexte, taille: 12, couleur: p.texteDiscret)),
            ]),
          ),
        ]),
      ),
    );
  }
}
