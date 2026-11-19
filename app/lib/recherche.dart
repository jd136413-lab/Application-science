// Recherche (maquettes 102 A + C et 102 bis, 19/11/2026) : une seule loupe qui cherche dans
// Sciences, Technologies et À venir. Résultats rangés par onglet, triés par date ou par
// importance (choix gardé). Barre vide : recherches récentes, domaines, prochain rendez-vous.
// Cherche dans le fil gardé sur le téléphone ET dans toute la base (fiches plus anciennes).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a_venir.dart';
import 'carte.dart';
import 'detail.dart';
import 'donnees.dart';
import 'etat.dart';
import 'fils.dart';
import 'langues.dart';
import 'modele.dart';
import 'reglages.dart';
import 'texte_article.dart';
import 'widgets.dart';

const _cleRecentes = 'recherches_recentes';
const _cleTri = 'recherche_par_importance';

class EcranRechercheMag extends StatefulWidget {
  const EcranRechercheMag({super.key});

  @override
  State<EcranRechercheMag> createState() => _EcranRechercheMagState();
}

class _EcranRechercheMagState extends State<EcranRechercheMag> {
  final _champ = TextEditingController();
  String _texte = '';
  bool _parImportance = false;
  List<String> _recentes = [];
  List<Avancee> _enLigne = [];
  Timer? _attente;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() {
        _recentes = p.getStringList(_cleRecentes) ?? [];
        _parImportance = p.getBool(_cleTri) ?? false;
      });
    });
  }

  @override
  void dispose() {
    _attente?.cancel();
    _champ.dispose();
    super.dispose();
  }

  List<String> get _mots => sansAccents(_texte).split(RegExp(r'\s+')).where((m) => m.length >= 2).toList();

  void _changer(String t) {
    setState(() => _texte = t);
    _attente?.cancel();
    if (t.trim().length < 3) {
      _enLigne = [];
      return;
    }
    // Dans toute la base, une fois la frappe terminée (hors ligne : on garde les résultats du téléphone).
    _attente = Timer(const Duration(milliseconds: 450), () async {
      try {
        final l = await rechercherEnLigne(t);
        if (mounted && t == _texte) setState(() => _enLigne = l);
      } catch (_) {}
    });
  }

  void _remplir(String t) {
    _champ.text = t;
    _champ.selection = TextSelection.collapsed(offset: t.length);
    _changer(t);
  }

  Future<void> _retenir() async {
    final t = _texte.trim();
    if (t.length < 2) return;
    final l = [t, ..._recentes.where((x) => x.toLowerCase() != t.toLowerCase())].take(6).toList();
    setState(() => _recentes = l);
    (await SharedPreferences.getInstance()).setStringList(_cleRecentes, l);
  }

  Future<void> _oublier(String t) async {
    final l = _recentes.where((x) => x != t).toList();
    setState(() => _recentes = l);
    (await SharedPreferences.getInstance()).setStringList(_cleRecentes, l);
  }

  Future<void> _trier(bool importance) async {
    setState(() => _parImportance = importance);
    (await SharedPreferences.getInstance()).setBool(_cleTri, importance);
  }

  bool _correspond(List<String> textes) {
    final tout = sansAccents(textes.join(' '));
    return _mots.every(tout.contains);
  }

  /// Fiches d'un fil qui contiennent tous les mots (téléphone + base, sans doublon).
  List<Avancee> _fiches(String fil) {
    final vus = <String>{};
    final res = <Avancee>[];
    for (final a in [...(filsAvancees.fils[fil] ?? const <Avancee>[]), ..._enLigne.where((a) => a.fil == fil)]) {
      if (etat.estMasquee(a) || !vus.add(a.id)) continue;
      final textes = [a.titre, a.resume, a.avant, a.decouverte, a.apres, a.source, tr(familleDe(a.famille).nom)];
      final traduit = traductionImmediate(a.titre);
      if (traduit != null) textes.add(traduit);
      if (_correspond(textes)) res.add(a);
    }
    res.sort((a, b) => b.publieLe.compareTo(a.publieLe));
    return _parImportance ? parImportance(res) : res;
  }

  /// Rendez-vous « À venir » qui contiennent tous les mots, du plus proche au plus lointain.
  List<Evenement> _evenements() {
    final l = evenementsAVenir.visibles().where((e) {
      final textes = [e.titre, e.pourquoi ?? '', e.lieu ?? '', tr(nomsTypes[e.type] ?? ''), e.sourceNom];
      final traduit = traductionImmediate(e.titre);
      if (traduit != null) textes.add(traduit);
      return _correspond(textes);
    }).toList();
    final aVenir = l.where((e) => !e.arrive && e.joursFin >= 0).toList()..sort((a, b) => a.date.compareTo(b.date));
    final passes = l.where((e) => !aVenir.contains(e)).toList()..sort((a, b) => b.date.compareTo(a.date));
    return [...aVenir, ...passes];
  }

  void _ouvrir(List<Avancee> l, int i) {
    _retenir();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => EcranDetailFil(liste: List.of(l), depart: i)));
  }

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final cherche = _texte.trim().length >= 2;
    final sciences = cherche ? _fiches('science') : const <Avancee>[];
    final techs = cherche ? _fiches('tech') : const <Avancee>[];
    final evts = cherche ? _evenements() : const <Evenement>[];
    final total = sciences.length + techs.length + evts.length;
    return Scaffold(
      backgroundColor: p.fond,
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 6),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _champ,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: _changer,
                  onSubmitted: (_) => _retenir(),
                  style: police(policeTexte, taille: 16, couleur: p.texte),
                  decoration: InputDecoration(
                    hintText: tr('Rechercher une avancée'),
                    hintStyle: police(policeTexte, taille: 16, couleur: p.texteDiscret),
                    prefixIcon: Icon(Icons.search_rounded, color: p.texte),
                    suffixIcon: _texte.isEmpty
                        ? null
                        : IconButton(
                            icon: Icon(Icons.close_rounded, color: p.texteDiscret),
                            onPressed: () => _remplir(''),
                          ),
                    filled: true,
                    fillColor: p.carte,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: p.bordure)),
                    enabledBorder:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: p.bordure)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: p.texte, width: 1.5)),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(tr(texteAnnuler),
                    style: police(policeTexte, taille: 15, graisse: FontWeight.w700, couleur: p.texteDiscret)),
              ),
            ]),
          ),
          Expanded(
            child: !cherche
                ? _avantDeTaper(p)
                : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                            total == 0 ? tr('Aucune avancée trouvée') : tr('{n} résultats', n: total),
                            style: police(policeTexte, taille: 13, couleur: p.texteDiscret)),
                      ),
                      SelecteurTri(parImportance: _parImportance, onChange: _trier),
                    ]),
                    const SizedBox(height: 6),
                    for (final (titre, liste) in [(texteSciences, sciences), (texteTechnologies, techs)])
                      if (liste.isNotEmpty) ...[
                        _TitrePartie(
                          titre: tr(titre),
                          nombre: liste.length,
                          onToutVoir: liste.length <= 3
                              ? null
                              : () {
                                  _retenir();
                                  Navigator.of(context).push(MaterialPageRoute(
                                      builder: (_) => _EcranResultats(
                                          titre: '« ${_texte.trim()} » · ${tr(titre)}',
                                          liste: liste,
                                          mots: _mots,
                                          parImportance: _parImportance,
                                          onTri: _trier)));
                                },
                        ),
                        for (var i = 0; i < liste.length && i < 3; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: CarteAvancee(avancee: liste[i], surligne: _mots, onTap: () => _ouvrir(liste, i)),
                          ),
                      ],
                    if (evts.isNotEmpty) ...[
                      _TitrePartie(titre: tr('À venir'), nombre: evts.length),
                      for (final e in evts.take(5))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GestureDetector(onTapDown: (_) => _retenir(), child: LigneEvenement(e)),
                        ),
                    ],
                  ]),
          ),
        ]),
      ),
    );
  }

  /// Barre vide (maquette 102 C) : recherches récentes, domaines, prochain rendez-vous.
  Widget _avantDeTaper(Palette p) {
    final familles = <String>{...famillesDuFil('science'), ...famillesDuFil('tech')}.where((f) => f != 'other' && f != 'tech_other').toList();
    final prochain = evenementsAVenir.prochains();
    Widget titre(String t) => Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(t.toUpperCase(),
              style: police(policeTexte, taille: 12, graisse: FontWeight.w800, couleur: p.texteDiscret)),
        );
    return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 28), children: [
      if (_recentes.isNotEmpty) ...[
        titre(tr('Recherches récentes')),
        for (final r in _recentes)
          InkWell(
            onTap: () => _remplir(r),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Icon(Icons.history_rounded, size: 20, color: p.texteDiscret),
                const SizedBox(width: 12),
                Expanded(child: Text(r, style: police(policeTexte, taille: 15, couleur: p.texte))),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close_rounded, size: 18, color: p.texteDiscret),
                  onPressed: () => _oublier(r),
                ),
              ]),
            ),
          ),
      ],
      titre(tr('Par domaine')),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final f in familles)
          ActionChip(
            avatar: Icon(familleDe(f).symbole, size: 16, color: familleDe(f).couleur),
            label: Text(tr(familleDe(f).nom)),
            labelStyle: police(policeTexte, taille: 13, graisse: FontWeight.w700, couleur: p.texte),
            backgroundColor: p.carte,
            side: BorderSide(color: p.bordure),
            onPressed: () => _remplir(tr(familleDe(f).nom)),
          ),
      ]),
      if (prochain.isNotEmpty) ...[
        titre(tr('Bientôt')),
        LigneEvenement(prochain.first),
      ],
    ]);
  }
}

/// « Plus récent / Plus important » (même forme que dans les pages de domaine).
class SelecteurTri extends StatelessWidget {
  final bool parImportance;
  final ValueChanged<bool> onChange;
  const SelecteurTri({super.key, required this.parImportance, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    Widget bouton(bool valeur, String texte) => GestureDetector(
          onTap: () => onChange(valeur),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
                color: parImportance == valeur ? p.carte : Colors.transparent, borderRadius: BorderRadius.circular(11)),
            child: Text(texte,
                style: police(policeTexte,
                    taille: 12.5,
                    graisse: FontWeight.w800,
                    couleur: parImportance == valeur ? p.texte : p.texteDiscret)),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: p.pastille, borderRadius: BorderRadius.circular(14)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        bouton(false, tr('Plus récent')),
        bouton(true, tr('Plus important')),
      ]),
    );
  }
}

class _TitrePartie extends StatelessWidget {
  final String titre;
  final int nombre;
  final VoidCallback? onToutVoir;
  const _TitrePartie({required this.titre, required this.nombre, this.onToutVoir});

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Row(children: [
        Expanded(
          child: Text('${titre.toUpperCase()} · $nombre',
              style: police(policeTexte, taille: 12, graisse: FontWeight.w800, couleur: p.texteDiscret)),
        ),
        if (onToutVoir != null)
          GestureDetector(
            onTap: onToutVoir,
            child: Text('${tr('Tout voir')} ›',
                style: police(policeTexte, taille: 13, graisse: FontWeight.w800, couleur: logoEncreBleue)),
          ),
      ]),
    );
  }
}

/// « Tout voir » : toute une partie des résultats, avec le même sélecteur de tri.
class _EcranResultats extends StatefulWidget {
  final String titre;
  final List<Avancee> liste;
  final List<String> mots;
  final bool parImportance;
  final ValueChanged<bool> onTri;
  const _EcranResultats(
      {required this.titre, required this.liste, required this.mots, required this.parImportance, required this.onTri});

  @override
  State<_EcranResultats> createState() => _EcranResultatsState();
}

class _EcranResultatsState extends State<_EcranResultats> {
  late bool _parImportance = widget.parImportance;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final l = List.of(widget.liste)..sort((a, b) => b.publieLe.compareTo(a.publieLe));
    final liste = _parImportance ? parImportance(l) : l;
    return Scaffold(
      backgroundColor: p.fond,
      appBar: AppBar(
        backgroundColor: p.fond,
        foregroundColor: p.texte,
        elevation: 0,
        title: Text(widget.titre, style: police(policeTitres, taille: 18, graisse: FontWeight.w800, couleur: p.texte)),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
        Row(children: [
          Expanded(
            child: Text(tr('{n} résultats', n: liste.length),
                style: police(policeTexte, taille: 13, couleur: p.texteDiscret)),
          ),
          SelecteurTri(
            parImportance: _parImportance,
            onChange: (v) {
              setState(() => _parImportance = v);
              widget.onTri(v);
            },
          ),
        ]),
        const SizedBox(height: 10),
        for (var i = 0; i < liste.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CarteAvancee(
              avancee: liste[i],
              surligne: widget.mots,
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => EcranDetailFil(liste: List.of(liste), depart: i))),
            ),
          ),
      ]),
    );
  }
}
