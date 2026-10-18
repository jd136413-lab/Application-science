// Choix des centres d'intérêt : au premier lancement, et depuis les Réglages.

import 'package:flutter/material.dart';

import 'etat.dart';
import 'reglages.dart';
import 'widgets.dart';

class EcranDomaines extends StatefulWidget {
  /// true = premier lancement ; false = modification depuis les Réglages.
  final bool premierLancement;
  const EcranDomaines({super.key, this.premierLancement = true});

  @override
  State<EcranDomaines> createState() => _EcranDomainesState();
}

class _EcranDomainesState extends State<EcranDomaines> {
  late Set<String> _choix = {...etat.domaines};

  void _valider() {
    if (widget.premierLancement) {
      etat.terminerPremierLancement(_choix);
    } else {
      etat.changerDomaines(_choix);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final n = _choix.length;

    Widget groupe(String titre, List<String> codes) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titre,
                style: police(policeTexte, taille: 13, graisse: FontWeight.w700, couleur: p.texteDiscret)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final code in codes) _Puce(
                code: code,
                choisie: _choix.contains(code),
                onTap: () => setState(() => _choix.contains(code) ? _choix.remove(code) : _choix.add(code)),
              ),
            ]),
          ],
        );

    return Scaffold(
      backgroundColor: p.fond,
      appBar: widget.premierLancement
          ? null
          : AppBar(backgroundColor: p.fond, foregroundColor: p.texte, elevation: 0, scrolledUnderElevation: 0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(children: [
            if (widget.premierLancement) ...[const LogoNovum(taille: 34), const SizedBox(height: 18)],
            Text(texteBienvenueTitre,
                textAlign: TextAlign.center,
                style: police(policeTitres, taille: 27, graisse: FontWeight.w800, couleur: p.texte, hauteur: 1.1)),
            const SizedBox(height: 6),
            Text(texteBienvenueDetail,
                textAlign: TextAlign.center,
                style: police(policeTexte, taille: 15, couleur: p.texteDiscret, hauteur: 1.45)),
            const SizedBox(height: 18),
            Expanded(
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  groupe('SCIENCES', famillesSciences),
                  const SizedBox(height: 18),
                  groupe('TECHNOLOGIES', famillesTech),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: p.encre,
                  foregroundColor: p.surEncre,
                  shape: const StadiumBorder(),
                  textStyle: police(policeTexte, taille: 16, graisse: FontWeight.w700),
                ),
                onPressed: _valider,
                child: Text(n == 0 ? 'Tout voir' : (widget.premierLancement ? 'C’est parti ($n)' : 'Enregistrer ($n)')),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _choix = {...famillesSciences, ...famillesTech}),
              child: Text('Tout sélectionner',
                  style: police(policeTexte, taille: 14, graisse: FontWeight.w600, couleur: p.texteDiscret)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Puce extends StatelessWidget {
  final String code;
  final bool choisie;
  final VoidCallback onTap;
  const _Puce({required this.code, required this.choisie, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final f = familleDe(code);
    return Semantics(
      selected: choisie,
      button: true,
      child: Material(
        color: choisie ? p.encre : p.carte,
        shape: StadiumBorder(side: BorderSide(color: choisie ? p.encre : p.bordure, width: 1.5)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: f.couleur, shape: BoxShape.circle),
                child: Icon(f.symbole, size: 18, color: f.icone),
              ),
              const SizedBox(width: 8),
              Text(f.nom,
                  style: police(policeTexte,
                      taille: 14, graisse: FontWeight.w600, couleur: choisie ? p.surEncre : p.texte)),
            ]),
          ),
        ),
      ),
    );
  }
}
