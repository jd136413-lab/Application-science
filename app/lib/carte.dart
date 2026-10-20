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

    final lue = etat.estLue(avancee.id);
    final nouvelle = etat.estNouvelle(avancee);
    final rupture = avancee.importance == 5;
    final sombre = estSombre(context);
    final texte = lue ? p.texteDiscret : p.texte;
    // Carte « Rupture » (5 étoiles) : fond doré léger + lueur (maquette 22, version 2).
    final decoration = rupture
        ? BoxDecoration(
            borderRadius: BorderRadius.circular(arrondiCarte),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0, 0.7],
              colors: [sombre ? const Color(0xFF3A3012) : const Color(0xFFFFF6D6), p.carte],
            ),
            border: Border.all(color: sombre ? const Color(0xFF6B5A1A) : const Color(0xFFF2D27A), width: 1.5),
            boxShadow: [BoxShadow(color: couleurEtoiles.withValues(alpha: 0.30), blurRadius: 22, offset: const Offset(0, 6))],
          )
        : BoxDecoration(
            color: lue ? (sombre ? const Color(0xFF15151B) : const Color(0xFFECEBF1)) : p.carte,
            borderRadius: BorderRadius.circular(arrondiCarte),
          );

    return DecoratedBox(
      decoration: decoration,
      child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(arrondiCarte),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          etat.marquerLue(avancee.id);
          onTap();
        },
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
                      style: police(policeTexte, taille: 13, graisse: FontWeight.w700, couleur: lue ? p.texteDiscret : encre)),
                ),
                if (nouvelle)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: logoEncreRose, borderRadius: BorderRadius.circular(8)),
                    child: Text(tr('NOUVEAU'),
                        style: police(policeTexte, taille: 10.5, graisse: FontWeight.w800, couleur: Colors.white)
                            .copyWith(letterSpacing: 0.5)),
                  )
                else if (lue)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text('✓ ${tr('Lu')}',
                        style: police(policeTexte, taille: 12, graisse: FontWeight.w700, couleur: p.texteDiscret)),
                  ),
                Text(dateCourte(avancee.publieLe), style: police(policeTexte, taille: 13, couleur: p.texteDiscret)),
              ]),
              const SizedBox(height: 12),
              TexteArticle(avancee.titre,
                  style: police(policeTitres,
                      taille: tailleTitreCarte, graisse: FontWeight.w600, couleur: texte, hauteur: 1.22)),
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
              if (uri != null) {
                etat.marquerLue(a.id);
                ouvrirArticle(uri);
              }
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


/// Ouvre l'article dans l'app (onglet Chrome intégré / Safari intégré) ;
/// si ce n'est pas possible, dans le navigateur du téléphone.
Future<bool> ouvrirArticle(Uri uri) async {
  try {
    if (await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) return true;
  } catch (_) {}
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Carte grise qui « respire » pendant le chargement (maquette 22).
class SqueletteCarte extends StatefulWidget {
  final int decalage;
  const SqueletteCarte({super.key, this.decalage = 0});

  @override
  State<SqueletteCarte> createState() => _SqueletteCarteState();
}

class _SqueletteCarteState extends State<SqueletteCarte> with SingleTickerProviderStateMixin {
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _anim.value = (widget.decalage * 0.25) % 1;
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    Widget barre(double largeur, double hauteur) => FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: largeur,
          child: Container(
              height: hauteur,
              decoration: BoxDecoration(color: p.pastille, borderRadius: BorderRadius.circular(6))),
        );
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.45).animate(CurvedAnimation(parent: _anim, curve: Curves.easeInOut)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: p.carte, borderRadius: BorderRadius.circular(arrondiCarte)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: p.pastille, borderRadius: BorderRadius.circular(11))),
            const SizedBox(width: 10),
            Expanded(child: barre(0.5, 12)),
          ]),
          const SizedBox(height: 14),
          barre(0.95, 17),
          const SizedBox(height: 8),
          barre(0.7, 17),
          const SizedBox(height: 14),
          barre(0.55, 12),
        ]),
      ),
    );
  }
}
