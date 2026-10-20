// Écran Actualités : logo, Sciences / Technologies, onglets de période,
// filtres, tri, et le fil des avancées (en-têtes de mois dans « Cette année »).
// Le logo disparaît quand on fait défiler la liste vers le bas et revient
// quand on remonte tout en haut ; les 3 menus restent toujours visibles.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'carte.dart';
import 'detail.dart';
import 'donnees.dart';
import 'etat.dart';
import 'langues.dart';
import 'modele.dart';
import 'navigation.dart';
import 'reglages.dart';
import 'widgets.dart';

class EcranAccueil extends StatefulWidget {
  const EcranAccueil({super.key});

  @override
  State<EcranAccueil> createState() => _EcranAccueilState();
}

class _EcranAccueilState extends State<EcranAccueil> {
  String _fil = 'science';
  int _periode = periodeParDefaut;
  bool _triImportance = false;
  bool _logoVisible = true;
  final Map<String, Future<List<Avancee>>> _chargements = {};
  final _defilement = ScrollController();

  @override
  void initState() {
    super.initState();
    demandeFilAujourdhui.addListener(_allerAujourdhui);
    demandeHautDuFil.addListener(_remonter);
  }

  @override
  void dispose() {
    demandeFilAujourdhui.removeListener(_allerAujourdhui);
    demandeHautDuFil.removeListener(_remonter);
    _defilement.dispose();
    super.dispose();
  }

  /// « Actualités » touché alors qu'on y est déjà : retour en haut du fil.
  void _remonter() {
    if (_defilement.hasClients) {
      _defilement.animateTo(0, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
    }
  }

  /// Notification « + N autres avancées » touchée : période « Aujourd'hui », à jour.
  void _allerAujourdhui() {
    setState(() {
      _periode = 0;
      _logoVisible = true;
    });
    _rafraichir();
  }

  /// Suit la position de la liste : logo visible seulement tout en haut.
  bool _suivreDefilement(Notification n) {
    ScrollMetrics? m;
    if (n is ScrollNotification && n.depth == 0) m = n.metrics;
    if (n is ScrollMetricsNotification && n.depth == 0) m = n.metrics;
    if (m == null || m.axis != Axis.vertical) return false;
    final enHaut = m.pixels <= 0;
    if (enHaut != _logoVisible) setState(() => _logoVisible = enHaut);
    return false;
  }

  Future<List<Avancee>> _charger({bool forcer = false}) {
    if (forcer || !_chargements.containsKey(_fil)) {
      _chargements[_fil] = chargerAvancees(_fil);
    }
    return _chargements[_fil]!;
  }

  Future<void> _rafraichir() async {
    final f = _charger(forcer: true);
    setState(() {});
    try {
      await f;
    } catch (_) {}
  }

  /// Applique période, filtres et tri.
  List<Avancee> _trier(List<Avancee> toutes) {
    final jours = periodes[_periode].$2;
    final limite = DateTime.now().subtract(Duration(days: jours));
    final visibles = etat.famillesVisibles(_fil);
    final l = toutes
        .where((a) => a.publieLe.isAfter(limite) && visibles.contains(a.famille) && !etat.estMasquee(a))
        .toList();
    if (_triImportance) {
      l.sort((a, b) => b.importance != a.importance
          ? b.importance.compareTo(a.importance)
          : b.publieLe.compareTo(a.publieLe));
    }
    return l;
  }

  void _ouvrirFiltres() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette(context).carte,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _FeuilleFiltres(fil: _fil),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) => Column(children: [
        AnimatedPadding(
          duration: const Duration(milliseconds: 220),
          padding: EdgeInsets.fromLTRB(20, _logoVisible ? 22 : 12, 20, 10),
          child: Column(children: [
            // Logo repliable : glisse et disparaît pendant le défilement.
            ClipRect(
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                alignment: Alignment.bottomCenter,
                heightFactor: _logoVisible ? 1 : 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _logoVisible ? 1 : 0,
                  child: const Padding(
                    padding: EdgeInsets.only(bottom: 14),
                    child: LogoNovaStem(),
                  ),
                ),
              ),
            ),
            _SelecteurFil(fil: _fil, onChange: (f) => setState(() => _fil = f)),
          ]),
        ),
        // Onglets de période
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (var i = 0; i < periodes.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _Pastille(
                    texte: tr(periodes[i].$1),
                    active: i == _periode,
                    onTap: () => setState(() => _periode = i),
                  ),
                ),
            ],
          ),
        ),
        // Filtres + tri
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Row(children: [
            _BoutonFiltres(fil: _fil, onTap: _ouvrirFiltres),
            const Spacer(),
            _Tri(importance: _triImportance, onChange: (v) => setState(() => _triImportance = v)),
          ]),
        ),
        Expanded(
          child: NotificationListener<Notification>(
            onNotification: _suivreDefilement,
            child: FutureBuilder<List<Avancee>>(
            future: _charger(),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return MessageCentre(
                  icone: Icons.wifi_off_rounded,
                  titre: tr(texteErreur),
                  detail: tr(texteErreurDetail),
                  bouton: tr(texteReessayer),
                  action: _rafraichir,
                );
              }
              final liste = _trier(snap.data ?? []);
              if (liste.isEmpty) {
                final aujourdhui = _periode == 0;
                return RefreshIndicator(
                  onRefresh: _rafraichir,
                  child: ListView(children: [
                    const SizedBox(height: 70),
                    MessageCentre(
                      icone: Icons.auto_awesome,
                      titre: tr(aujourdhui ? texteAujourdhuiVide : texteVide),
                      detail: tr(aujourdhui ? texteAujourdhuiVideDetail : texteVideDetail),
                      bouton: aujourdhui ? tr(texteVoirSemaine) : null,
                      action: aujourdhui ? () => setState(() => _periode = 1) : null,
                    ),
                  ]),
                );
              }
              // En-têtes de mois dans « Cette année » (tri par date)
              final avecMois = _periode == periodes.length - 1 && !_triImportance;
              final elements = <Object>[];
              String? moisCourant;
              for (final a in liste) {
                if (avecMois) {
                  final m = enTeteMois(a.publieLe);
                  if (m != moisCourant) {
                    elements.add(m);
                    moisCourant = m;
                  }
                }
                elements.add(a);
              }
              return RefreshIndicator(
                onRefresh: _rafraichir,
                child: ListView.builder(
                  controller: _defilement,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: elements.length,
                  itemBuilder: (context, i) {
                    final e = elements[i];
                    if (e is String) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
                        child: Text(e,
                            style: police(policeTitres, taille: 24, graisse: FontWeight.w800, couleur: p.texte)),
                      );
                    }
                    final a = e as Avancee;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: CarteBalayable(
                        avancee: a,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => EcranDetail(avancee: a)),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          ),
        ),
      ]),
    );
  }
}

// ----------------------------- Éléments -----------------------------

class _SelecteurFil extends StatelessWidget {
  final String fil;
  final ValueChanged<String> onChange;
  const _SelecteurFil({required this.fil, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    Widget bouton(String code, String texte, IconData icone) {
      final actif = code == fil;
      return Expanded(
        child: Semantics(
          selected: actif,
          button: true,
          child: Material(
            color: actif ? p.carte : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onChange(code),
              child: SizedBox(
                height: 42,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(icone, size: 18, color: actif ? p.texte : p.texteDiscret),
                  const SizedBox(width: 8),
                  Text(tr(texte),
                      style: police(policeTexte,
                          taille: 15, graisse: FontWeight.w700, couleur: actif ? p.texte : p.texteDiscret)),
                ]),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: p.pastille, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        bouton('science', texteSciences, Icons.science_outlined),
        const SizedBox(width: 4),
        bouton('tech', texteTechnologies, Icons.memory_outlined),
      ]),
    );
  }
}

class _Pastille extends StatelessWidget {
  final String texte;
  final bool active;
  final VoidCallback onTap;
  const _Pastille({required this.texte, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    return Semantics(
      selected: active,
      button: true,
      child: Material(
        color: active ? p.encre : Colors.transparent,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              child: Text(texte,
                  style: police(policeTexte,
                      taille: 14, graisse: FontWeight.w600, couleur: active ? p.surEncre : p.texteDiscret)),
            ),
          ),
        ),
      ),
    );
  }
}

class _BoutonFiltres extends StatelessWidget {
  final String fil;
  final VoidCallback onTap;
  const _BoutonFiltres({required this.fil, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final total = famillesDuFil(fil).length;
    final visibles = etat.famillesVisibles(fil).length;
    final resume = visibles == total ? tr('Tout') : '$visibles';
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
          side: BorderSide(color: p.bordure, width: 1.5), borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          height: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.tune_rounded, size: 18, color: p.texte),
              const SizedBox(width: 8),
              Text('${tr(texteFiltres)} · $resume',
                  style: police(policeTexte, taille: 14, graisse: FontWeight.w600, couleur: p.texte)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Tri extends StatelessWidget {
  final bool importance;
  final ValueChanged<bool> onChange;
  const _Tri({required this.importance, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    Widget option(String texte, bool valeur) {
      final actif = importance == valeur;
      return Material(
        color: actif ? p.pastille : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: () => onChange(valeur),
          child: SizedBox(
            height: 32,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Center(
                child: Text(texte,
                    style: police(policeTexte,
                        taille: 13, graisse: FontWeight.w600, couleur: actif ? p.texte : p.texteDiscret)),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          border: Border.all(color: p.bordure, width: 1.5), borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        option(tr(texteTriRecent), false),
        const SizedBox(width: 2),
        option(tr(texteTriImportant), true),
      ]),
    );
  }
}

/// Menu Filtres : une case par famille du fil, plus « Tout ».
class _FeuilleFiltres extends StatelessWidget {
  final String fil;
  const _FeuilleFiltres({required this.fil});

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final codes = famillesDuFil(fil);
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) {
        final visibles = etat.famillesVisibles(fil);
        final tout = visibles.length == codes.length;
        void basculer(String code) {
          final choix = {...etat.domaines};
          // Si « tout » était affiché sans choix explicite, on part de toutes les familles du fil.
          if (choix.intersection(codes.toSet()).isEmpty) choix.addAll(codes);
          choix.contains(code) ? choix.remove(code) : choix.add(code);
          HapticFeedback.selectionClick(); // petite vibration
          etat.changerDomaines(choix);
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: p.bordure, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 14),
              Row(children: [
                Text(tr(texteFiltres),
                    style: police(policeTitres, taille: 24, graisse: FontWeight.w800, couleur: p.texte)),
                const Spacer(),
                Text(tr(fil == 'tech' ? texteTechnologies : texteSciences),
                    style: police(policeTexte, taille: 14, graisse: FontWeight.w600, couleur: p.texteDiscret)),
              ]),
              const SizedBox(height: 6),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: tout,
                activeColor: p.encre,
                checkColor: p.surEncre,
                title: Text(tr('Tout'), style: police(policeTexte, taille: 15, graisse: FontWeight.w700, couleur: p.texte)),
                onChanged: (_) {
                  final choix = {...etat.domaines}..addAll(codes);
                  HapticFeedback.selectionClick();
                  etat.changerDomaines(choix);
                },
              ),
              Divider(color: p.bordure, height: 1),
              for (final code in codes)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: visibles.contains(code),
                  activeColor: p.encre,
                  checkColor: p.surEncre,
                  secondary: TuileFamille(famille: familleDe(code), taille: 30),
                  title: Text(tr(familleDe(code).nom), style: police(policeTexte, taille: 15, couleur: p.texte)),
                  onChanged: (_) => basculer(code),
                ),
                  ]),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: p.encre, foregroundColor: p.surEncre, shape: const StadiumBorder()),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(tr('Afficher'), style: police(policeTexte, taille: 15, graisse: FontWeight.w700)),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}
