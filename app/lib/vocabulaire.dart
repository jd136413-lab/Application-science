// Onglet Vocabulaire (planches 35 et 36) : les « mots à connaître » des
// avancées ouvertes, gardés sur le téléphone.
// - Une carte à retourner : le mot d'un côté, la définition de l'autre.
// - « Je savais » range le mot dans les mots connus ; « À revoir » le garde
//   pour plus tard. Un mot qu'on vient d'apprendre est « À revoir » (Nouveau).
// - Menu « Tous les mots » : onglets À revoir / Je savais, recherche, liste A→Z.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'detail.dart';
import 'donnees.dart';
import 'etat.dart';
import 'langues.dart';
import 'reglages.dart';
import 'texte_article.dart';
import 'widgets.dart';

class EcranVocabulaire extends StatefulWidget {
  const EcranVocabulaire({super.key});

  @override
  State<EcranVocabulaire> createState() => _EcranVocabulaireState();
}

class _EcranVocabulaireState extends State<EcranVocabulaire> {
  int _i = 0; // position dans la liste « À revoir »
  bool _verso = false; // carte retournée (définition visible)
  String? _choisi; // mot touché dans la liste
  bool _menu = false;
  String _onglet = 'revoir';
  String _recherche = '';
  bool _tout = false;
  final _defilement = ScrollController();

  static const int _maxLignes = 8;

  @override
  void dispose() {
    _defilement.dispose();
    super.dispose();
  }

  void _classer(MotAppris m, String statut) {
    HapticFeedback.lightImpact();
    etat.classerMot(m.mot, statut);
    setState(() {
      _verso = false;
      if (statut == 'revoir' && _choisi == null) _i++;
      _choisi = null;
    });
  }

  Future<void> _ouvrirAvancee(MotAppris m) async {
    try {
      final a = await chargerAvancee(m.idAvancee);
      if (a != null && mounted) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => EcranDetail(avancee: a)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Pas de connexion'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) {
        final mots = etat.vocabulaire;
        final revoir = mots.where((m) => m.aRevoir).toList();
        final su = mots.where((m) => !m.aRevoir).toList();
        MotAppris? carte;
        if (_choisi != null) {
          for (final m in mots) {
            if (m.mot == _choisi) carte = m;
          }
        }
        carte ??= revoir.isEmpty ? null : revoir[_i % revoir.length];
        final position = carte == null ? -1 : revoir.indexOf(carte);

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 10),
            child: Text(tr(texteOngletVocabulaire),
                style: police(policeTitres, taille: 34, graisse: FontWeight.w800, couleur: p.texte)),
          ),
          Expanded(
            child: mots.isEmpty
                ? MessageCentre(
                    icone: Icons.menu_book_outlined,
                    titre: tr('Pas encore de mots'),
                    detail: tr('Les mots à connaître des avancées que vous ouvrez apparaîtront ici.'),
                  )
                : ListView(controller: _defilement, padding: const EdgeInsets.fromLTRB(16, 0, 16, 28), children: [
                    if (carte != null) ...[
                      if (position >= 0)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                          child: Text(
                              tr('À revoir · carte {a} sur {b}')
                                  .replaceAll('{a}', '${position + 1}')
                                  .replaceAll('{b}', '${revoir.length}'),
                              style: police(policeTexte, taille: 13, couleur: p.texteDiscret)),
                        ),
                      _carte(context, carte),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: p.carte,
                                foregroundColor: p.texte,
                                shape: const StadiumBorder(),
                                textStyle: police(policeTexte, taille: 15, graisse: FontWeight.w700),
                              ),
                              onPressed: () => _classer(carte!, 'revoir'),
                              child: Text(tr('À revoir')),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: p.encre,
                                foregroundColor: p.surEncre,
                                shape: const StadiumBorder(),
                                textStyle: police(policeTexte, taille: 15, graisse: FontWeight.w700),
                              ),
                              onPressed: () => _classer(carte!, 'su'),
                              child: Text(tr('Je savais')),
                            ),
                          ),
                        ),
                      ]),
                    ] else
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: p.carte, borderRadius: BorderRadius.circular(24)),
                        child: Column(children: [
                          const Icon(Icons.emoji_events_outlined, color: couleurEtoiles, size: 36),
                          const SizedBox(height: 8),
                          Text(tr('Tous vos mots sont connus. Bravo !'),
                              textAlign: TextAlign.center,
                              style: police(policeTexte, taille: 16, graisse: FontWeight.w700, couleur: p.texte)),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () {
                              for (final m in su) {
                                etat.classerMot(m.mot, 'revoir');
                              }
                            },
                            child: Text(tr('Tout réviser à nouveau'),
                                style: police(policeTexte, taille: 14, graisse: FontWeight.w700, couleur: p.texte)),
                          ),
                        ]),
                      ),
                    const SizedBox(height: 14),
                    _menuTousLesMots(context, mots, revoir, su),
                  ]),
          ),
        ]);
      },
    );
  }

  /// La carte : le mot (recto, fond foncé) ou sa définition (verso, fond clair).
  Widget _carte(BuildContext context, MotAppris m) {
    final p = palette(context);
    final f = familleDe(m.famille);
    Widget etiquette(String t, Color couleur) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: f.couleur, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(tr(t).toUpperCase(),
              style: police(policeTexte, taille: 12, graisse: FontWeight.w800, couleur: couleur.withValues(alpha: 0.75))),
        ]);

    final recto = Container(
      key: const ValueKey('recto'),
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 260),
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      decoration: BoxDecoration(
        color: p.encre,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x1A17161F), blurRadius: 20, offset: Offset(0, 6))],
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        etiquette('Le mot', p.surEncre),
        const SizedBox(height: 14),
        TexteArticle(m.mot,
            textAlign: TextAlign.center,
            style: police(policeTitres, taille: 30, graisse: FontWeight.w800, couleur: p.surEncre, hauteur: 1.15)),
        const SizedBox(height: 14),
        Text(tr('Touchez la carte pour voir la définition'),
            textAlign: TextAlign.center,
            style: police(policeTexte, taille: 12, couleur: p.surEncre.withValues(alpha: 0.7))),
      ]),
    );

    final verso = Container(
      key: const ValueKey('verso'),
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 260),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      decoration: BoxDecoration(
        color: p.carte,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.bordure, width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x1A17161F), blurRadius: 20, offset: Offset(0, 6))],
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        etiquette('La définition', p.texte),
        const SizedBox(height: 10),
        TexteArticle(m.mot, textAlign: TextAlign.center, style: police(policeTitres, taille: 18, graisse: FontWeight.w800, couleur: p.texte)),
        const SizedBox(height: 10),
        TexteArticle(m.definition, textAlign: TextAlign.center, style: police(policeTexte, taille: 17, couleur: p.texte, hauteur: 1.5)),
        const SizedBox(height: 12),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _ouvrirAvancee(m),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Wrap(alignment: WrapAlignment.center, children: [
              Text('${tr('Vu dans :')} ', style: police(policeTexte, taille: 12, couleur: p.texteDiscret)),
              TexteArticle(m.titreAvancee,
                  style: police(policeTexte, taille: 12, couleur: p.texteDiscret)
                      .copyWith(decoration: TextDecoration.underline)),
            ]),
          ),
        ),
      ]),
    );

    return Semantics(
      button: true,
      label: _verso ? tr('Retourner la carte') : tr('Touchez la carte pour voir la définition'),
      child: GestureDetector(
        onTap: () => setState(() => _verso = !_verso),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (enfant, anim) => AnimatedBuilder(
            animation: anim,
            child: enfant,
            builder: (_, c) => Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY((1 - anim.value) * math.pi / 2),
              child: c,
            ),
          ),
          child: _verso ? verso : recto,
        ),
      ),
    );
  }

  /// Menu replié « Tous les mots » : onglets, recherche et liste de A à Z.
  Widget _menuTousLesMots(BuildContext context, List<MotAppris> mots, List<MotAppris> revoir, List<MotAppris> su) {
    final p = palette(context);
    final vue = _onglet == 'su' ? su : revoir;
    final q = _recherche.trim().toLowerCase();
    final filtres = vue.where((m) => q.isEmpty || m.mot.toLowerCase().contains(q)).toList()
      ..sort((x, y) => x.mot.toLowerCase().compareTo(y.mot.toLowerCase()));
    final affiches = (_tout || q.isNotEmpty) ? filtres : filtres.take(_maxLignes).toList();

    Widget ongletMots(String code, String texte) => Expanded(
          child: Semantics(
            selected: _onglet == code,
            button: true,
            child: Material(
              color: _onglet == code ? p.carte : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
              child: InkWell(
                borderRadius: BorderRadius.circular(11),
                onTap: () => setState(() {
                  _onglet = code;
                  _tout = false;
                }),
                child: SizedBox(
                  height: 42,
                  child: Center(
                    child: Text(texte,
                        style: police(policeTexte,
                            taille: 14,
                            graisse: FontWeight.w800,
                            couleur: _onglet == code ? p.texte : p.texteDiscret)),
                  ),
                ),
              ),
            ),
          ),
        );

    return Container(
      decoration: BoxDecoration(color: p.carte, borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          onTap: () => setState(() => _menu = !_menu),
          child: SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Icon(Icons.menu_book_rounded, color: p.texte, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(tr('Tous les mots · {n}', n: mots.length),
                      style: police(policeTexte, taille: 15, graisse: FontWeight.w800, couleur: p.texte)),
                ),
                AnimatedRotation(
                  turns: _menu ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.expand_more_rounded, color: p.texte),
                ),
              ]),
            ),
          ),
        ),
        if (_menu)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: p.pastille, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  ongletMots('revoir', tr('À revoir · {n}', n: revoir.length)),
                  const SizedBox(width: 4),
                  ongletMots('su', tr('Je savais · {n}', n: su.length)),
                ]),
              ),
              const SizedBox(height: 10),
              TextField(
                onChanged: (t) => setState(() => _recherche = t),
                style: police(policeTexte, taille: 14, couleur: p.texte),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: p.fond,
                  hintText: tr('Chercher un mot'),
                  hintStyle: police(policeTexte, taille: 14, couleur: p.texteDiscret),
                  prefixIcon: Icon(Icons.search_rounded, color: p.texteDiscret, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: p.bordure),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (filtres.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(tr('Aucun mot ne correspond.'),
                          style: police(policeTexte, taille: 14, couleur: p.texteDiscret)),
                    ),
                  for (var k = 0; k < affiches.length; k++) ...[
                    if (k > 0) Divider(height: 1, color: p.bordure),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _choisi = affiches[k].mot;
                          _verso = false;
                        });
                        if (_defilement.hasClients) {
                          _defilement.animateTo(0,
                              duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        child: Row(children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration:
                                BoxDecoration(color: familleDe(affiches[k].famille).couleur, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TexteArticle(affiches[k].mot,
                                style: police(policeTexte, taille: 15, graisse: FontWeight.w600, couleur: p.texte)),
                          ),
                          if (affiches[k].statut == 'nouveau')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: p.encre, borderRadius: BorderRadius.circular(8)),
                              child: Text(tr('NOUVEAU'),
                                  style: police(policeTexte, taille: 11, graisse: FontWeight.w800, couleur: p.surEncre)),
                            ),
                        ]),
                      ),
                    ),
                  ],
                  if (!_tout && q.isEmpty && filtres.length > _maxLignes) ...[
                    Divider(height: 1, color: p.bordure),
                    TextButton(
                      onPressed: () => setState(() => _tout = true),
                      child: Text(tr('Afficher les {n} autres', n: filtres.length - _maxLignes),
                          style: police(policeTexte, taille: 14, graisse: FontWeight.w800, couleur: p.texte)),
                    ),
                  ],
                ]),
              ),
            ]),
          ),
      ]),
    );
  }
}
