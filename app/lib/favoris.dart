// Écran Favoris : les avancées gardées sur le téléphone (lisibles hors ligne).

import 'package:flutter/material.dart';

import 'carte.dart';
import 'detail.dart';
import 'etat.dart';
import 'reglages.dart';
import 'widgets.dart';

class EcranFavoris extends StatelessWidget {
  const EcranFavoris({super.key});

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) {
        final liste = etat.favoris;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(texteOngletFavoris,
                  style: police(policeTitres, taille: 34, graisse: FontWeight.w800, couleur: p.texte)),
              const SizedBox(height: 4),
              Text(
                  liste.isEmpty
                      ? 'Aucune avancée gardée pour l’instant'
                      : '${liste.length} avancée${liste.length > 1 ? 's' : ''} gardée${liste.length > 1 ? 's' : ''} sur ce téléphone',
                  style: police(policeTexte, taille: 14, couleur: p.texteDiscret)),
            ]),
          ),
          Expanded(
            child: liste.isEmpty
                ? const MessageCentre(
                    icone: Icons.bookmark_border_rounded,
                    titre: 'Pas encore de favori',
                    detail: 'Touchez le marque-page sur une avancée pour la retrouver ici, même sans réseau.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: liste.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => CarteAvancee(
                      avancee: liste[i],
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => EcranDetail(avancee: liste[i])),
                      ),
                    ),
                  ),
          ),
        ]);
      },
    );
  }
}
