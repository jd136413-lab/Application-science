// Accueil « façon magazine » (maquette 64, choix de Maxime du 01/11/2026).
// Version 1.0.44 (01/11/2026) : jamais « Et après ? » au début du 3e paragraphe.
//
// L'onglet Actualités devient une page d'accueil : À la une, Nouveau pour vous,
// Le top de la semaine, Ce mois-ci par domaine (et Mes domaines suivis). Chaque
// rubrique ouvre sa liste : nouveautés, le top (période, domaines, tri), la page
// d'un domaine, toute l'année. En haut à droite : rechercher et personnaliser.
// L'ancien fil (accueil.dart) reste disponible : Réglages → Présentation de l'accueil.

import 'dart:async';

import 'package:flutter/material.dart';

import 'carte.dart';
import 'detail.dart';
import 'etat.dart';
import 'fils.dart';
import 'langues.dart';
import 'modele.dart';
import 'navigation.dart';
import 'proposition_notifs.dart';
import 'reglages.dart';
import 'stats.dart';
import 'texte_article.dart';
import 'widgets.dart';

// ------------------------------------------------------------------ outils

/// Ouvre une avancée (on peut ensuite glisser vers les autres de [liste]).
void ouvrirAvancee(BuildContext context, List<Avancee> liste, Avancee a) {
  stat('lecture', a: a, valeur: 'accueil');
  etat.marquerLue(a.id);
  Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EcranDetailFil(liste: List.of(liste), depart: liste.indexOf(a).clamp(0, liste.length - 1))));
}

void _pousser(BuildContext context, Widget ecran) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ecran));

Color _assombrir(Color c, double f) {
  final h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness * (1 - f)).clamp(0.0, 1.0)).toColor();
}

Color _eclaircir(Color c, double f) {
  final h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness + (1 - h.lightness) * f).clamp(0.0, 1.0)).toColor();
}

/// Étoiles jaunes + mot (« Important »), en blanc sur fond coloré.
Widget _etoilesClaires(int n, {double taille = 13}) => Text.rich(TextSpan(children: [
      TextSpan(text: '★' * n, style: TextStyle(color: couleurEtoiles, fontSize: taille + 1, letterSpacing: 1)),
      TextSpan(text: '★' * (5 - n), style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: taille + 1)),
      TextSpan(
          text: '  ${tr(motsImportance[n])}',
          style: police(policeTexte, taille: taille, graisse: FontWeight.w700, couleur: Colors.white)),
    ]));

const List<(String, int)> _periodesTop = [('Nouveau', 0), ('Semaine', 7), ('Mois', 31), ('Année', 366)];

// ------------------------------------------------------------------ l'accueil

class EcranMagazine extends StatefulWidget {
  const EcranMagazine({super.key});

  @override
  State<EcranMagazine> createState() => _EcranMagazineState();
}

class _EcranMagazineState extends State<EcranMagazine> {
  String _fil = 'science';
  final _defilement = ScrollController();
  Timer? _minuteurNotif;
  bool _carteNotif = false;
  bool _feuilleNotifOuverte = false;

  @override
  void initState() {
    super.initState();
    filsAvancees.demarrer('science');
    filsAvancees.demarrer('tech');
    demandeFilAujourdhui.addListener(_allerNouveautes);
    demandeHautDuFil.addListener(_remonter);
    _minuteurNotif = Timer.periodic(const Duration(seconds: 15), (_) => _verifierPropositionNotif());
  }

  @override
  void dispose() {
    _minuteurNotif?.cancel();
    demandeFilAujourdhui.removeListener(_allerNouveautes);
    demandeHautDuFil.removeListener(_remonter);
    _defilement.dispose();
    super.dispose();
  }

  void _remonter() {
    if (_defilement.hasClients) {
      _defilement.animateTo(0, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
    }
  }

  /// Notification « Voir les N » touchée : le bon fil, puis la liste des nouveautés.
  void _allerNouveautes() {
    final f = filDemande;
    filDemande = null;
    setState(() {
      if (f == 'science' || f == 'tech') _fil = f!;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pousser(context, EcranNouveautesMag(fil: _fil));
    });
  }

  /// Proposition d'activer les notifications (maquette 50), comme dans l'accueil classique.
  void _verifierPropositionNotif() {
    if (!mounted || _carteNotif || _feuilleNotifOuverte) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    switch (propositionNotifDue()) {
      case FormeProposition.carte:
        setState(() => _carteNotif = true);
      case FormeProposition.feuille:
        _feuilleNotifOuverte = true;
        final l = parImportance(surPeriode(filsAvancees.visibles(_fil), 7));
        montrerFeuilleNotifs(context, l.isEmpty ? null : l.first).whenComplete(() => _feuilleNotifOuverte = false);
      case FormeProposition.aucune:
        break;
    }
  }

  Future<void> _rafraichir() => filsAvancees.mettreAJour(_fil, complet: true);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([etat, filsAvancees]),
      builder: (context, _) {
        final chargee = filsAvancees.fils.containsKey(_fil);
        Widget corps;
        if (!chargee && filsAvancees.erreurs.containsKey(_fil)) {
          corps = MessageCentre(
            icone: Icons.wifi_off_rounded,
            titre: tr(texteErreur),
            detail: tr(texteErreurDetail),
            bouton: tr(texteReessayer),
            action: _rafraichir,
          );
        } else if (!chargee) {
          corps = ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              for (var i = 0; i < 4; i++)
                Padding(padding: const EdgeInsets.only(bottom: 10), child: SqueletteCarte(decalage: i)),
            ],
          );
        } else {
          corps = RefreshIndicator(
            onRefresh: _rafraichir,
            child: ListView(
              controller: _defilement,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              children: [
                if (filsAvancees.horsLigne.contains(_fil)) const _BandeauHorsLigneMag(),
                if (_carteNotif) CarteNotifs(onFermer: () => setState(() => _carteNotif = false)),
                ..._rubriques(context),
              ],
            ),
          );
        }
        return Column(children: [
          _EnTete(
            fil: _fil,
            onFil: (f) => setState(() => _fil = f),
            miseAJour: filsAvancees.enCours.contains(_fil) && chargee,
          ),
          Expanded(child: corps),
        ]);
      },
    );
  }

  List<Widget> _rubriques(BuildContext context) {
    final tout = filsAvancees.visibles(_fil);
    final res = <Widget>[];
    for (final (code, active) in etat.rubriques) {
      if (!active) continue;
      final w = switch (code) {
        'une' => _rubriqueUne(context, tout),
        'nouveau' => _rubriqueNouveau(context, tout),
        'top' => _rubriqueTop(context, tout),
        'domaines' => _rubriqueDomaines(context, tout),
        'suivis' => _rubriqueSuivis(context, tout),
        _ => null,
      };
      if (w != null) res.add(Padding(padding: const EdgeInsets.only(bottom: 22), child: w));
    }
    if (res.isEmpty) {
      res.add(Padding(
        padding: const EdgeInsets.only(top: 60),
        child: MessageCentre(
          icone: Icons.dashboard_customize_outlined,
          titre: tr('Personnaliser l’accueil'),
          detail: tr('Toutes les rubriques sont masquées.'),
          bouton: tr('Personnaliser l’accueil'),
          action: () => ouvrirPersonnalisation(context),
        ),
      ));
    }
    return res;
  }

  Widget? _rubriqueUne(BuildContext context, List<Avancee> tout) {
    // La plus importante des dernières 24 h ; à défaut, des 3 derniers jours.
    var l = parImportance(tout.where((a) => DateTime.now().difference(a.ajouteLe ?? a.publieLe).inHours < 24).toList());
    var libelle = 'À la une · aujourd’hui';
    if (l.isEmpty) {
      l = parImportance(surPeriode(tout, 3));
      libelle = 'À la une · ces derniers jours';
    }
    if (l.isEmpty) return null;
    return _CarteUne(avancee: l.first, libelle: tr(libelle), onTap: () => ouvrirAvancee(context, l, l.first));
  }

  Widget _rubriqueNouveau(BuildContext context, List<Avancee> tout) {
    final p = palette(context);
    final l = tout.where(etat.estNouvelle).toList()..sort((a, b) => b.publieLe.compareTo(a.publieLe));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _TitreRubrique(
        titre: l.isEmpty ? tr('Nouveau pour vous') : '${tr('Nouveau pour vous')} · ${l.length}',
        action: l.isEmpty ? null : tr('Tout voir'),
        onAction: () => _pousser(context, EcranNouveautesMag(fil: _fil)),
      ),
      if (l.isEmpty)
        Row(children: [
          Icon(Icons.check_circle_rounded, color: const Color(0xFF12A37F), size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Text(tr('Vous êtes à jour'),
                  style: police(policeTexte, taille: 15, graisse: FontWeight.w600, couleur: p.texteDiscret))),
        ])
      else
        _Carrousel(liste: l.take(12).toList(), toutes: l),
    ]);
  }

  Widget? _rubriqueTop(BuildContext context, List<Avancee> tout) {
    final l = parImportance(surPeriode(tout, 7));
    if (l.isEmpty) return null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _TitreRubrique(
        titre: tr('Le top de la semaine'),
        action: tr('Tout voir'),
        onAction: () => _pousser(context, EcranTopMag(fil: _fil)),
      ),
      for (var i = 0; i < l.length && i < 3; i++)
        _LigneTop(rang: i + 1, avancee: l[i], onTap: () => ouvrirAvancee(context, l, l[i])),
    ]);
  }

  Widget? _rubriqueDomaines(BuildContext context, List<Avancee> tout) {
    final mois = surPeriode(tout, 31);
    final compte = <String, int>{};
    for (final a in mois) {
      compte[a.famille] = (compte[a.famille] ?? 0) + 1;
    }
    final ordre = compte.keys.toList()..sort((a, b) => compte[b]!.compareTo(compte[a]!));
    final p = palette(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _TitreRubrique(
        titre: tr('Ce mois-ci par domaine'),
        action: tr('Toute l’année'),
        onAction: () => _pousser(context, EcranAnneeMag(fil: _fil)),
      ),
      if (ordre.isEmpty)
        Text(tr('Pas encore d’avancée ce mois-ci.'), style: police(policeTexte, taille: 14, couleur: p.texteDiscret))
      else
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.5,
          children: [
            for (final f in ordre)
              _TuileDomaine(
                famille: f,
                nombre: compte[f]!,
                onTap: () => _pousser(context, EcranDomaineMag(fil: _fil, famille: f)),
              ),
          ],
        ),
    ]);
  }

  Widget _rubriqueSuivis(BuildContext context, List<Avancee> tout) {
    final p = palette(context);
    final suivis = famillesDuFil(_fil).where(etat.domainesSuivis.contains).toList();
    if (suivis.isEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _TitreRubrique(titre: tr('Mes domaines suivis')),
        Text(tr('Touchez « Suivre » sur la page d’un domaine pour le retrouver ici.'),
            style: police(policeTexte, taille: 14, couleur: p.texteDiscret, hauteur: 1.4)),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final f in suivis) ...[
        _TitreRubrique(
          titre: tr(familleDe(f).nom),
          action: tr('Tout voir'),
          onAction: () => _pousser(context, EcranDomaineMag(fil: _fil, famille: f)),
        ),
        Builder(builder: (context) {
          // Même tri que le bouton de la page du domaine (« Tout voir »).
          var l = tout.where((a) => a.famille == f).toList()..sort((a, b) => b.publieLe.compareTo(a.publieLe));
          if (etat.triDomainesImportance) l = parImportance(l);
          l = l.take(10).toList();
          return l.isEmpty
              ? Text(tr('Pas encore d’avancée ce mois-ci.'),
                  style: police(policeTexte, taille: 14, couleur: p.texteDiscret))
              : _Carrousel(liste: l, toutes: l);
        }),
        const SizedBox(height: 14),
      ],
    ]);
  }
}

// ------------------------------------------------------------------ en-tête

class _EnTete extends StatelessWidget {
  final String fil;
  final ValueChanged<String> onFil;
  final bool miseAJour;
  const _EnTete({required this.fil, required this.onFil, required this.miseAJour});

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    Widget onglet(String code, String texte) {
      final actif = code == fil;
      return InkWell(
        onTap: () => onFil(code),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.only(bottom: 6, top: 4),
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: actif ? p.texte : Colors.transparent, width: 3))),
          child: Text(tr(texte),
              style: police(policeTexte,
                  taille: 17, graisse: FontWeight.w800, couleur: actif ? p.texte : p.texteDiscret)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const LogoNovaStem(taille: 30, anime: true),
          const Spacer(),
          if (miseAJour)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: p.texteDiscret)),
            ),
          IconButton(
            tooltip: tr('Rechercher'),
            icon: Icon(Icons.search_rounded, color: p.texte),
            onPressed: () => _pousser(context, const EcranRechercheMag()),
          ),
          IconButton(
            tooltip: tr('Personnaliser l’accueil'),
            icon: Icon(Icons.tune_rounded, color: p.texte),
            onPressed: () => ouvrirPersonnalisation(context),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          onglet('science', texteSciences),
          const SizedBox(width: 22),
          onglet('tech', texteTechnologies),
        ]),
      ]),
    );
  }
}

class _BandeauHorsLigneMag extends StatelessWidget {
  const _BandeauHorsLigneMag();

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(color: p.encre, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(Icons.cloud_off_rounded, size: 18, color: p.surEncre),
        const SizedBox(width: 10),
        Expanded(
          child: Text(tr('Hors ligne · voici le dernier fil enregistré. Les résumés restent lisibles.'),
              style: police(policeTexte, taille: 13, graisse: FontWeight.w600, couleur: p.surEncre, hauteur: 1.35)),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ éléments

class _TitreRubrique extends StatelessWidget {
  final String titre;
  final String? action;
  final VoidCallback? onAction;
  const _TitreRubrique({required this.titre, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Text(titre, style: police(policeTitres, taille: 21, graisse: FontWeight.w800, couleur: p.texte)),
        ),
        if (action != null)
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text('$action →',
                  style: police(policeTexte, taille: 14, graisse: FontWeight.w700, couleur: const Color(0xFF3D7BFF))),
            ),
          ),
      ]),
    );
  }
}

/// « À la une » : grande carte dans la couleur du domaine (ou avec sa photo libre).
class _CarteUne extends StatelessWidget {
  final Avancee avancee;
  final String libelle;
  final VoidCallback onTap;
  const _CarteUne({required this.avancee, required this.libelle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final a = avancee;
    final f = familleDe(a.famille);
    final n = a.autresSources.length;
    final contenu = Padding(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(10)),
          child: Text(libelle.toUpperCase(),
              style: police(policeTexte, taille: 11, graisse: FontWeight.w800, couleur: Colors.white)
                  .copyWith(letterSpacing: 1.2)),
        ),
        const SizedBox(height: 10),
        TexteArticle(a.titre,
            maxLines: 4,
            style: police(policeTitres, taille: 23, graisse: FontWeight.w800, couleur: Colors.white, hauteur: 1.12)),
        const SizedBox(height: 10),
        Row(children: [
          Flexible(child: _etoilesClaires(a.importance)),
          Flexible(
            child: Text(' · ${a.source}${n > 0 ? ' ${n == 1 ? tr('+ 1 autre') : tr('+ {n} autres', n: n)}' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: police(policeTexte, taille: 13, couleur: Colors.white.withValues(alpha: 0.9))),
          ),
        ]),
      ]),
    );
    return Material(
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      color: f.couleur,
      child: InkWell(
        onTap: onTap,
        onLongPress: () => ouvrirMenuCarte(context, a),
        child: SizedBox(
          height: 250,
          child: Stack(fit: StackFit.expand, children: [
            if (a.image != null) ...[
              ImageGardee(url: a.image!),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x10000000), Color(0xCC000000)],
                  ),
                ),
              ),
            ] else
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.7, -0.7),
                    radius: 1.3,
                    colors: [_eclaircir(f.couleur, 0.35), f.couleur, _assombrir(f.couleur, 0.45)],
                    stops: const [0, 0.45, 1],
                  ),
                ),
                child: Align(
                  alignment: const Alignment(1.25, -1.35),
                  child: Icon(f.symbole, size: 190, color: Colors.white.withValues(alpha: 0.13)),
                ),
              ),
            contenu,
          ]),
        ),
      ),
    );
  }
}

/// Petites cartes à faire glisser (Nouveau pour vous, domaines suivis).
class _Carrousel extends StatelessWidget {
  final List<Avancee> liste;
  final List<Avancee> toutes;
  const _Carrousel({required this.liste, required this.toutes});

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: liste.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final a = liste[i];
          final nouvelle = etat.estNouvelle(a);
          return SizedBox(
            width: 172,
            child: Material(
              color: p.carte,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => ouvrirAvancee(context, toutes, a),
                onLongPress: () => ouvrirMenuCarte(context, a),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      TuileFamille(famille: familleDe(a.famille), taille: 22),
                      const SizedBox(width: 6),
                      if (nouvelle)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFFF5A8A), borderRadius: BorderRadius.circular(6)),
                          child: Text(tr('NOUVEAU'),
                              style: police(policeTexte, taille: 10, graisse: FontWeight.w800, couleur: Colors.white)),
                        ),
                    ]),
                    const SizedBox(height: 8),
                    Expanded(
                      child: TexteArticle(a.titre,
                          maxLines: 4,
                          style: police(policeTitres, taille: 14, graisse: FontWeight.w600, couleur: p.texte, hauteur: 1.2)),
                    ),
                    Etoiles(note: a.importance, taille: 12, avecMot: false),
                  ]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LigneTop extends StatelessWidget {
  final int rang;
  final Avancee avancee;
  final VoidCallback onTap;
  const _LigneTop({required this.rang, required this.avancee, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final f = familleDe(avancee.famille);
    return InkWell(
      onTap: onTap,
      onLongPress: () => ouvrirMenuCarte(context, avancee),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.bordure))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 34,
            child: Text('$rang',
                style: police(policeTitres, taille: 34, graisse: FontWeight.w800, couleur: p.bordure, hauteur: 0.95)),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr(f.nom),
                  style: police(policeTexte,
                      taille: 12, graisse: FontWeight.w700, couleur: estSombre(context) ? f.encreSombre : f.encreClaire)),
              const SizedBox(height: 3),
              TexteArticle(avancee.titre,
                  style: police(policeTitres, taille: 15, graisse: FontWeight.w600, couleur: p.texte, hauteur: 1.2)),
              const SizedBox(height: 4),
              Etoiles(note: avancee.importance, taille: 12),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _TuileDomaine extends StatelessWidget {
  final String famille;
  final int nombre;
  final VoidCallback onTap;
  const _TuileDomaine({required this.famille, required this.nombre, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final f = familleDe(famille);
    return Material(
      color: f.couleur,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(tr(f.nom),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: police(policeTexte, taille: 13, graisse: FontWeight.w800, couleur: f.icone, hauteur: 1.1)),
                Text(nombre == 1 ? tr('1 avancée') : tr('{n} avancées', n: nombre),
                    style: police(policeTexte, taille: 12, graisse: FontWeight.w700, couleur: f.icone.withValues(alpha: 0.85))),
              ]),
            ),
            Icon(f.symbole, color: f.icone.withValues(alpha: 0.5), size: 22),
          ]),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ listes

/// Page avec un titre, un bouton retour, des réglages éventuels et une liste de cartes.
class _PageListe extends StatelessWidget {
  final String titre;
  final Widget? droite;
  final List<Widget> enTete;
  final List<Avancee> liste;
  final String? vide;
  const _PageListe({required this.titre, this.droite, this.enTete = const [], required this.liste, this.vide});

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    return Scaffold(
      backgroundColor: p.fond,
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 12, 4),
            child: Row(children: [
              IconButton(
                  tooltip: tr('Retour'),
                  icon: Icon(Icons.arrow_back_rounded, color: p.texte),
                  onPressed: () => Navigator.of(context).pop()),
              Expanded(
                child: Text(titre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: police(policeTitres, taille: 22, graisse: FontWeight.w800, couleur: p.texte)),
              ),
              if (droite != null) droite!,
            ]),
          ),
          for (final w in enTete) Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 6), child: w),
          Expanded(
            child: liste.isEmpty
                ? MessageCentre(icone: Icons.inbox_outlined, titre: vide ?? tr('Rien à afficher'), detail: '')
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                    itemCount: liste.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: CarteBalayable(
                        avancee: liste[i],
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => EcranDetailFil(liste: List.of(liste), depart: i))),
                      ),
                    ),
                  ),
          ),
        ]),
      ),
    );
  }
}

/// Barre de choix compacte (période…).
class _Segments<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T valeur;
  final ValueChanged<T> onChange;
  final bool surCouleur;
  const _Segments({required this.options, required this.valeur, required this.onChange, this.surCouleur = false});

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: surCouleur ? Colors.white.withValues(alpha: 0.2) : p.pastille, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        for (final (v, t) in options)
          Expanded(
            child: GestureDetector(
              onTap: () => onChange(v),
              child: Container(
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: v == valeur ? (surCouleur ? Colors.white : p.carte) : Colors.transparent,
                    borderRadius: BorderRadius.circular(11)),
                child: Text(t,
                    style: police(policeTexte,
                        taille: 13,
                        graisse: FontWeight.w800,
                        couleur: surCouleur ? (v == valeur ? const Color(0xFF17161F) : Colors.white) : (v == valeur ? p.texte : p.texteDiscret))),
              ),
            ),
          ),
      ]),
    );
  }
}

class EcranNouveautesMag extends StatelessWidget {
  final String fil;
  const EcranNouveautesMag({super.key, required this.fil});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([etat, filsAvancees]),
        builder: (context, _) {
          final p = palette(context);
          final l = filsAvancees.visibles(fil).where(etat.estNouvelle).toList()
            ..sort((a, b) => b.publieLe.compareTo(a.publieLe));
          return _PageListe(
            titre: tr('Nouveau pour vous'),
            droite: l.isEmpty
                ? null
                : TextButton(
                    onPressed: () {
                      for (final a in l) {
                        etat.marquerLue(a.id);
                      }
                    },
                    child: Text(tr('Tout marquer lu'),
                        style: police(policeTexte, taille: 14, graisse: FontWeight.w700, couleur: const Color(0xFF3D7BFF))),
                  ),
            enTete: [
              if (l.isNotEmpty)
                Text(l.length == 1 ? tr('1 avancée') : tr('{n} avancées', n: l.length),
                    style: police(policeTexte, taille: 13, couleur: p.texteDiscret)),
            ],
            liste: l,
            vide: tr('Vous êtes à jour'),
          );
        },
      );
}

class EcranTopMag extends StatefulWidget {
  final String fil;
  const EcranTopMag({super.key, required this.fil});

  @override
  State<EcranTopMag> createState() => _EcranTopMagState();
}

class _EcranTopMagState extends State<EcranTopMag> {
  int _jours = 7;
  String? _famille; // null = tout
  bool _importance = true;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([etat, filsAvancees]),
        builder: (context, _) {
          final p = palette(context);
          var l = surPeriode(filsAvancees.visibles(widget.fil), _jours);
          if (_famille != null) l = l.where((a) => a.famille == _famille).toList();
          l = _importance ? parImportance(l) : (l..sort((a, b) => b.publieLe.compareTo(a.publieLe)));
          final visibles = famillesDuFil(widget.fil).where(etat.famillesVisibles(widget.fil).contains).toList();
          Widget puce(String? code) {
            final actif = code == _famille;
            final f = code == null ? null : familleDe(code);
            return Padding(
              padding: const EdgeInsets.only(right: 7),
              child: GestureDetector(
                onTap: () => setState(() => _famille = code),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: actif ? (f?.couleur ?? p.encre) : p.carte,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: actif ? Colors.transparent : p.bordure),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (f != null && !actif) ...[
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: f.couleur, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                    ],
                    Text(f == null ? tr('Tout') : tr(f.nom),
                        style: police(policeTexte,
                            taille: 13, graisse: FontWeight.w700, couleur: actif ? (f?.icone ?? p.surEncre) : p.texte)),
                  ]),
                ),
              ),
            );
          }

          return _PageListe(
            titre: tr('Le top'),
            droite: TextButton.icon(
              onPressed: () => setState(() => _importance = !_importance),
              icon: Icon(Icons.swap_vert_rounded, color: p.texte, size: 18),
              label: Text(tr(_importance ? texteTriImportant : texteTriRecent),
                  style: police(policeTexte, taille: 13, graisse: FontWeight.w700, couleur: p.texte)),
            ),
            enTete: [
              _Segments<int>(
                options: [for (final (t, j) in _periodesTop) (j, tr(t))],
                valeur: _jours,
                onChange: (j) => setState(() => _jours = j),
              ),
              SizedBox(
                height: 36,
                child: ListView(scrollDirection: Axis.horizontal, children: [puce(null), for (final f in visibles) puce(f)]),
              ),
            ],
            liste: l,
            vide: tr('Pas encore d’avancée ici'),
          );
        },
      );
}

class EcranDomaineMag extends StatefulWidget {
  final String fil;
  final String famille;
  const EcranDomaineMag({super.key, required this.fil, required this.famille});

  @override
  State<EcranDomaineMag> createState() => _EcranDomaineMagState();
}

class _EcranDomaineMagState extends State<EcranDomaineMag> {
  int _jours = 31;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([etat, filsAvancees]),
        builder: (context, _) {
          final p = palette(context);
          final f = familleDe(widget.famille);
          final toutes = (filsAvancees.fils[widget.fil] ?? const <Avancee>[])
              .where((a) => a.famille == widget.famille && !etat.estMasquee(a))
              .toList();
          var l = surPeriode(toutes, _jours)..sort((a, b) => b.publieLe.compareTo(a.publieLe));
          if (etat.triDomainesImportance) l = parImportance(l);
          final importantes = l.where((a) => a.importance >= 3).length;
          final suivi = etat.domainesSuivis.contains(widget.famille);
          return Scaffold(
            backgroundColor: p.fond,
            body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [_eclaircir(f.couleur, 0.2), _assombrir(f.couleur, 0.25)],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 16, 16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        IconButton(
                            tooltip: tr('Retour'),
                            icon: Icon(Icons.arrow_back_rounded, color: f.icone),
                            onPressed: () => Navigator.of(context).pop()),
                        Expanded(
                          child: Text(tr(f.nom),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: police(policeTitres, taille: 26, graisse: FontWeight.w800, couleur: f.icone)),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            backgroundColor: suivi ? f.icone : f.icone.withValues(alpha: 0.2),
                            shape: const StadiumBorder(),
                          ),
                          onPressed: () {
                            etat.basculerSuivi(widget.famille);
                            if (!suivi) {
                              afficherMessage(context, tr('Ce domaine apparaîtra dans « Mes domaines suivis ».'),
                                  icone: Icons.check_rounded);
                            }
                          },
                          icon: Icon(suivi ? Icons.check_rounded : Icons.add_rounded,
                              size: 18, color: suivi ? f.couleur : f.icone),
                          label: Text(tr(suivi ? 'Suivi' : 'Suivre'),
                              style: police(policeTexte,
                                  taille: 13, graisse: FontWeight.w800, couleur: suivi ? f.couleur : f.icone)),
                        ),
                      ]),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 0, 10),
                        child: Row(children: [
                          Expanded(
                            child: Text(
                                '${l.length == 1 ? tr('1 avancée') : tr('{n} avancées', n: l.length)} · ★★★+ $importantes',
                                style: police(policeTexte, taille: 14, couleur: f.icone.withValues(alpha: 0.9))),
                          ),
                          // Tri : même style de bouton que « Suivre ».
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              backgroundColor: f.icone.withValues(alpha: 0.2),
                              shape: const StadiumBorder(),
                            ),
                            onPressed: etat.basculerTriDomaines,
                            icon: Icon(etat.triDomainesImportance ? Icons.star_rounded : Icons.schedule_rounded, size: 18, color: f.icone),
                            label: Text(tr(etat.triDomainesImportance ? texteTriImportant : texteTriRecent),
                                style: police(policeTexte, taille: 13, graisse: FontWeight.w800, couleur: f.icone)),
                          ),
                        ]),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: _Segments<int>(
                          surCouleur: true,
                          options: [(7, tr('Semaine')), (31, tr('Mois')), (366, tr('Année'))],
                          valeur: _jours,
                          onChange: (j) => setState(() => _jours = j),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
              Expanded(
                child: l.isEmpty
                    ? MessageCentre(icone: Icons.inbox_outlined, titre: tr('Pas encore d’avancée ici'), detail: '')
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                        itemCount: l.length,
                        itemBuilder: (context, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: CarteBalayable(
                            avancee: l[i],
                            onTap: () => Navigator.of(context)
                                .push(MaterialPageRoute(builder: (_) => EcranDetailFil(liste: List.of(l), depart: i))),
                          ),
                        ),
                      ),
              ),
            ]),
          );
        },
      );
}

class EcranAnneeMag extends StatelessWidget {
  final String fil;
  const EcranAnneeMag({super.key, required this.fil});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([etat, filsAvancees]),
        builder: (context, _) {
          final p = palette(context);
          final l = surPeriode(filsAvancees.visibles(fil), 366);
          final mois = <DateTime, List<Avancee>>{};
          for (final a in l) {
            mois.putIfAbsent(DateTime(a.publieLe.year, a.publieLe.month), () => []).add(a);
          }
          final cles = mois.keys.toList()..sort((a, b) => b.compareTo(a));
          return Scaffold(
            backgroundColor: p.fond,
            body: SafeArea(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 12, 4),
                  child: Row(children: [
                    IconButton(
                        tooltip: tr('Retour'),
                        icon: Icon(Icons.arrow_back_rounded, color: p.texte),
                        onPressed: () => Navigator.of(context).pop()),
                    Expanded(
                      child: Text(tr('Toute l’année'),
                          style: police(policeTitres, taille: 22, graisse: FontWeight.w800, couleur: p.texte)),
                    ),
                  ]),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                    children: [
                      for (final m in cles)
                        Builder(builder: (context) {
                          final duMois = mois[m]!..sort((a, b) => b.publieLe.compareTo(a.publieLe));
                          final meilleure = parImportance(duMois).first;
                          final importantes = duMois.where((a) => a.importance >= 3).length;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: p.carte, borderRadius: BorderRadius.circular(20)),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Expanded(
                                  child: Text(enTeteMois(m),
                                      style: police(policeTitres, taille: 21, graisse: FontWeight.w800, couleur: p.texte)),
                                ),
                                Text(
                                    '${duMois.length == 1 ? tr('1 avancée') : tr('{n} avancées', n: duMois.length)} · ★★★+ $importantes',
                                    style: police(policeTexte, taille: 12.5, couleur: p.texteDiscret)),
                              ]),
                              const SizedBox(height: 10),
                              Text(tr('L’avancée du mois').toUpperCase(),
                                  style: police(policeTexte, taille: 11.5, graisse: FontWeight.w800, couleur: p.texteDiscret)
                                      .copyWith(letterSpacing: 0.8)),
                              const SizedBox(height: 4),
                              InkWell(
                                onTap: () => ouvrirAvancee(context, duMois, meilleure),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  TexteArticle(meilleure.titre,
                                      style: police(policeTitres,
                                          taille: 15, graisse: FontWeight.w600, couleur: p.texte, hauteur: 1.2)),
                                  const SizedBox(height: 4),
                                  Etoiles(note: meilleure.importance, taille: 12),
                                ]),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () => _pousser(
                                    context,
                                    _PageListe(
                                      titre: enTeteMois(m),
                                      liste: duMois,
                                    )),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Text('${tr('Voir le mois')} →',
                                      style: police(policeTexte,
                                          taille: 14, graisse: FontWeight.w700, couleur: const Color(0xFF3D7BFF))),
                                ),
                              ),
                            ]),
                          );
                        }),
                    ],
                  ),
                ),
              ]),
            ),
          );
        },
      );
}

// ------------------------------------------------------------------ recherche

class EcranRechercheMag extends StatefulWidget {
  const EcranRechercheMag({super.key});

  @override
  State<EcranRechercheMag> createState() => _EcranRechercheMagState();
}

class _EcranRechercheMagState extends State<EcranRechercheMag> {
  final _champ = TextEditingController();
  String _texte = '';

  @override
  void dispose() {
    _champ.dispose();
    super.dispose();
  }

  List<Avancee> _resultats() {
    final mots = sansAccents(_texte).split(RegExp(r'\s+')).where((m) => m.length >= 2).toList();
    if (mots.isEmpty) return const [];
    final res = <Avancee>[];
    for (final fil in const ['science', 'tech']) {
      for (final a in filsAvancees.fils[fil] ?? const <Avancee>[]) {
        if (etat.estMasquee(a)) continue;
        final textes = [a.titre, a.resume, a.avant, a.decouverte, a.apres, a.source, tr(familleDe(a.famille).nom)];
        final traduit = traductionImmediate(a.titre);
        if (traduit != null) textes.add(traduit);
        final tout = sansAccents(textes.join(' '));
        if (mots.every(tout.contains)) res.add(a);
      }
    }
    res.sort((a, b) => b.publieLe.compareTo(a.publieLe));
    return res.take(100).toList();
  }

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final l = _resultats();
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
                  onChanged: (t) => setState(() => _texte = t),
                  style: police(policeTexte, taille: 16, couleur: p.texte),
                  decoration: InputDecoration(
                    hintText: tr('Rechercher une avancée'),
                    hintStyle: police(policeTexte, taille: 16, couleur: p.texteDiscret),
                    prefixIcon: Icon(Icons.search_rounded, color: p.texte),
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
          if (_texte.trim().length >= 2)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
              child: Text(
                  l.isEmpty
                      ? tr('Aucune avancée trouvée')
                      : (l.length == 1 ? tr('1 avancée') : tr('{n} avancées', n: l.length)),
                  style: police(policeTexte, taille: 13, couleur: p.texteDiscret)),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
              itemCount: l.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CarteAvancee(
                  avancee: l[i],
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => EcranDetailFil(liste: List.of(l), depart: i))),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------------ personnaliser

const Map<String, (String, String)> _nomsRubriques = {
  'une': ('À la une', 'La plus grande avancée du jour'),
  'nouveau': ('Nouveau pour vous', 'Ce que vous n’avez pas encore lu'),
  'top': ('Le top de la semaine', 'Les 3 plus importantes'),
  'domaines': ('Ce mois-ci par domaine', 'Les tuiles de couleur'),
  'suivis': ('Mes domaines suivis', 'Une rubrique par domaine suivi'),
};

/// « Personnaliser l'accueil » : afficher ou masquer chaque rubrique, et changer leur ordre.
void ouvrirPersonnalisation(BuildContext context) {
  final p = palette(context);
  var liste = List.of(etat.rubriques);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: p.carte,
    builder: (context) => StatefulBuilder(
      builder: (context, majFeuille) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(tr('Personnaliser l’accueil'),
                style: police(policeTitres, taille: 23, graisse: FontWeight.w800, couleur: p.texte)),
            const SizedBox(height: 4),
            Text(tr('Glisser ≡ pour changer l’ordre des rubriques.'),
                style: police(policeTexte, taille: 13, couleur: p.texteDiscret)),
            const SizedBox(height: 8),
            SizedBox(
              height: 72.0 * liste.length,
              child: ReorderableListView(
                buildDefaultDragHandles: false,
                physics: const NeverScrollableScrollPhysics(),
                onReorder: (de, vers) => majFeuille(() {
                  if (vers > de) vers -= 1;
                  final x = liste.removeAt(de);
                  liste.insert(vers, x);
                  etat.changerRubriques(liste);
                }),
                children: [
                  for (var i = 0; i < liste.length; i++)
                    SizedBox(
                      key: ValueKey(liste[i].$1),
                      height: 72,
                      child: Row(children: [
                        ReorderableDragStartListener(
                          index: i,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Icon(Icons.drag_handle_rounded, color: p.texteDiscret),
                          ),
                        ),
                        Expanded(
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(tr(_nomsRubriques[liste[i].$1]!.$1),
                                style: police(policeTexte, taille: 15, graisse: FontWeight.w700, couleur: p.texte)),
                            Text(tr(_nomsRubriques[liste[i].$1]!.$2),
                                style: police(policeTexte, taille: 12.5, couleur: p.texteDiscret)),
                          ]),
                        ),
                        Switch(
                          value: liste[i].$2,
                          activeTrackColor: p.encre,
                          onChanged: (v) => majFeuille(() {
                            liste[i] = (liste[i].$1, v);
                            etat.changerRubriques(liste);
                          }),
                        ),
                      ]),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: p.encre,
                  foregroundColor: p.surEncre,
                  shape: const StadiumBorder(),
                  textStyle: police(policeTexte, taille: 16, graisse: FontWeight.w700),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(tr('Terminé')),
              ),
            ),
          ]),
        ),
      ),
    ),
  );
}
