// Carte d'une avancée dans le fil : carte texte, ou carte photo si une
// image libre de droits existe.

import 'package:flutter/material.dart';

import 'langues.dart';
import 'modele.dart';
import 'reglages.dart';
import 'texte_article.dart';
import 'widgets.dart';

class CarteAvancee extends StatelessWidget {
  final Avancee avancee;
  final VoidCallback onTap;
  const CarteAvancee({super.key, required this.avancee, required this.onTap});

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
