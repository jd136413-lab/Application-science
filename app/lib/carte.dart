// Carte d'une avancée dans le fil : carte texte, ou carte photo si une
// image libre de droits existe.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'etat.dart';

import 'langues.dart';
import 'modele.dart';
import 'reglages.dart';
import 'texte_article.dart';
import 'widgets.dart';

class CarteAvancee extends StatelessWidget {
  final Avancee avancee;
  final VoidCallback onTap;
  const CarteAvancee({super.key, required this.avancee, required this.onTap});

  void _menu(BuildContext context) => ouvrirMenuCarte(context, avancee);

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final f = familleDe(avancee.famille);
    final encre = estSombre(context) ? f.encreSombre : f.encreClaire;

    return Material(
      color: p.carte,
      borderRadius: BorderRadius.circular(arrondiCarte),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _menu(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (avancee.image != null) ...[
                _Photo(url: avancee.image!, credit: avancee.creditImage),
                const SizedBox(height: 14),
              ],
              Row(children: [
                TuileFamille(famille: f),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(tr(f.nom),
                      overflow: TextOverflow.ellipsis,
                      style: police(policeTexte, taille: 13, graisse: FontWeight.w700, couleur: encre)),
                ),
                Text(dateCourte(avancee.publieLe), style: police(policeTexte, taille: 13, couleur: p.texteDiscret)),
              ]),
              const SizedBox(height: 12),
              TexteArticle(avancee.titre,
                  style: police(policeTitres,
                      taille: tailleTitreCarte, graisse: FontWeight.w600, couleur: p.texte, hauteur: 1.22)),
              const SizedBox(height: 12),
              Row(children: [
                Etoiles(note: avancee.importance),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('· ${avancee.source}',
                      overflow: TextOverflow.ellipsis,
                      style: police(policeTexte, taille: 13, couleur: p.texteDiscret)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  final String url;
  final String? credit;
  const _Photo({required this.url, this.credit});

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 176,
        width: double.infinity,
        child: Stack(fit: StackFit.expand, children: [
          Image.network(
            url,
            fit: BoxFit.cover,
            semanticLabel: tr('Photo fournie par la source'),
            loadingBuilder: (c, child, prog) => prog == null ? child : Container(color: p.pastille),
            // Si l'image ne charge pas, on affiche un simple fond (pas de trou).
            errorBuilder: (c, e, s) => Container(color: p.pastille),
          ),
          if (credit != null && credit!.isNotEmpty)
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                child: Text(credit!, style: police(policeTexte, taille: 11, graisse: FontWeight.w600, couleur: Colors.white)),
              ),
            ),
        ]),
      ),
    );
  }
}


/// Carte du fil qu'on peut balayer : vers la droite = favori (la carte reste),
/// vers la gauche = masquer (avec « Annuler »).
class CarteBalayable extends StatelessWidget {
  final Avancee avancee;
  final VoidCallback onTap;
  const CarteBalayable({super.key, required this.avancee, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    Widget fond(Alignment cote, Color couleur, IconData icone, String texte, Color encre) => Container(
          alignment: cote,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(color: couleur, borderRadius: BorderRadius.circular(arrondiCarte)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icone, color: encre, size: 28),
            const SizedBox(height: 4),
            Text(texte, style: police(policeTexte, taille: 13, graisse: FontWeight.w700, couleur: encre)),
          ]),
        );
    final favori = etat.estFavori(avancee.id);
    return Dismissible(
      key: ValueKey('carte-${avancee.id}'),
      background: fond(Alignment.centerLeft, couleurEtoiles,
          favori ? Icons.bookmark_remove_rounded : Icons.bookmark_add_rounded,
          tr(favori ? 'Retirer des favoris' : 'Ajouter aux favoris'), const Color(0xFF2B2000)),
      secondaryBackground:
          fond(Alignment.centerRight, p.pastille, Icons.visibility_off_rounded, tr('Masquer'), p.texte),
      dismissThresholds: const {DismissDirection.startToEnd: 0.3, DismissDirection.endToStart: 0.4},
      confirmDismiss: (sens) async {
        if (sens == DismissDirection.startToEnd) {
          etat.basculerFavori(avancee);
          afficherMessage(context, tr(etat.estFavori(avancee.id) ? 'Ajouté aux favoris' : 'Retiré des favoris'),
              icone: Icons.bookmark_rounded);
          return false; // la carte reste à sa place
        }
        return true;
      },
      onDismissed: (_) {
        HapticFeedback.lightImpact();
        etat.masquer(avancee.id);
        afficherMessage(context, tr('Avancée masquée'),
            icone: Icons.visibility_off_rounded, annuler: () => etat.demasquer(avancee.id));
      },
      child: CarteAvancee(avancee: avancee, onTap: onTap),
    );
  }
}

/// Menu de l'appui long : favori, partager, lire l'article, masquer la source.
void ouvrirMenuCarte(BuildContext context, Avancee a) {
  HapticFeedback.mediumImpact();
  final p = palette(context);
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: p.carte,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (feuille) {
      Widget ligne(IconData icone, String texte, VoidCallback action) => ListTile(
            leading: Icon(icone, color: p.texte),
            title: Text(texte, style: police(policeTexte, taille: 16, graisse: FontWeight.w600, couleur: p.texte)),
            onTap: () {
              Navigator.of(feuille).pop();
              action();
            },
          );
      final favori = etat.estFavori(a.id);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: p.bordure, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: TexteArticle(a.titre,
                  style: police(policeTitres, taille: 17, graisse: FontWeight.w700, couleur: p.texte, hauteur: 1.25)),
            ),
            ligne(favori ? Icons.bookmark_remove_rounded : Icons.bookmark_add_outlined,
                tr(favori ? 'Retirer des favoris' : 'Ajouter aux favoris'), () {
              etat.basculerFavori(a);
              afficherMessage(context, tr(etat.estFavori(a.id) ? 'Ajouté aux favoris' : 'Retiré des favoris'),
                  icone: Icons.bookmark_rounded);
            }),
            ligne(Icons.share_outlined, tr('Partager'), () {
              SharePlus.instance.share(ShareParams(text: '${a.titre}\n${a.lien}\n\n${tr('Découvert sur NovaSTEM')}'));
            }),
            ligne(Icons.north_east_rounded, tr(texteLireArticle), () {
              final uri = Uri.tryParse(a.lien);
              if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
            }),
            if (a.source.isNotEmpty)
              ligne(Icons.block_rounded, tr('Masquer cette source'), () {
                etat.masquerSource(a.source);
                afficherMessage(context, tr('Les avancées de {s} sont masquées').replaceAll('{s}', a.source),
                    icone: Icons.visibility_off_rounded,
                    annuler: () => etat.masquerSource(a.source, visible: true));
              }),
          ]),
        ),
      );
    },
  );
}
