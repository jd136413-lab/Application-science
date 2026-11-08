// Publicités (Google AdMob) et achat « Retirer les annonces » (Google Play), sur Android.
//
// Emplacements (scénario D, planche 80, choix de Maxime du 03/11/2026) :
//   - un bloc sur l'accueil, après « Nouveau pour vous » (BlocPub(accueil: true)) ;
//   - une annonce toutes les 8 avancées dans les listes, jamais en 1re position (BlocPub()) ;
//   - un petit bandeau en bas d'une avancée ouverte (BandeauPub()).
// Jamais : « À la une », notifications, favoris, vocabulaire, réglages, présentation.
//
// Consentement RGPD : formulaire de Google (UMP), réglé dans AdMob →
// « Confidentialité et messages ». Il s'affiche au premier lancement en Europe.

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'etat.dart';
import 'langues.dart';
import 'pubs_commun.dart';
import 'reglages.dart';
import 'widgets.dart';

// Emplacements de TEST de Google : utilisés sur le téléphone de Maxime
// (« hors statistiques »), pour ne jamais toucher à ses propres vraies pubs
// (interdit par AdMob).
const String _testBandeau = 'ca-app-pub-3940256099942544/9214589741';

bool _demarre = false;

/// Appelé une fois l'accueil affiché (après la présentation du premier lancement).
Future<void> demarrerPubs() async {
  if (_demarre || !Platform.isAndroid) return;
  _demarre = true;
  unawaited(_demarrerAchats());
  if (!pubsConfigurees || !etat.pubsVoulues) return;
  // Écran de chargement : jusqu'à ce que les pubs des 2 accueils soient prêtes,
  // 3 s au plus après le démarrage d'AdMob, 6 s au plus en tout.
  ecranChargementPubs.value = true;
  Timer(const Duration(seconds: 6), _finChargement);
  try {
    // 1) Consentement RGPD (formulaire de Google, seulement si nécessaire).
    final fini = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => ConsentForm.loadAndShowConsentFormIfRequired((_) {
        if (!fini.isCompleted) fini.complete();
      }),
      (_) {
        if (!fini.isCompleted) fini.complete();
      },
    );
    await fini.future.timeout(const Duration(minutes: 3), onTimeout: () {});
    if (!await ConsentInformation.instance.canRequestAds()) return;
    // 2) Démarrage d'AdMob. Annonces « tout public » seulement.
    await MobileAds.instance.initialize();
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(maxAdContentRating: MaxAdContentRating.pg),
    );
    pubsPretes.value = true;
    // 3) Préchargement : les annonces sont prêtes AVANT d'arriver à l'écran.
    _reserve.remplir();
    Timer(const Duration(seconds: 3), _finChargement);
    void verifier() {
      // Les 2 pubs d'accueil sont prêtes, ou Google n'en a pas (plus rien en cours) : on ouvre.
      if (_reserve.nbPretes(FormatPub.accueil) >= 2 || !_reserve.chargeEncore(FormatPub.accueil)) {
        _reserve.change.removeListener(verifier);
        _finChargement();
      }
    }
    _reserve.change.addListener(verifier);
    etat.addListener(() => etat.pubsVoulues ? _reserve.remplir() : _reserve.vider());
  } catch (_) {
    // Pas de pub plutôt qu'une app qui plante.
  }
  if (!pubsPretes.value) _finChargement();
}

void _finChargement() => ecranChargementPubs.value = false;

// ---------------------------------------------------------------------------
// Réserve d'annonces préchargées (08/11/2026, demande de Maxime : une annonce ne
// doit jamais « apparaître » sous les yeux de la personne).
//
// Règle d'affichage d'un emplacement :
//   - s'il y a une annonce prête au moment où l'emplacement est construit, il la prend ;
//   - sinon il reste vide (0 pixel) et n'en prend une que lorsqu'il est SOUS le bas
//     de l'écran (jamais visible au moment où elle arrive, aucun saut du contenu lu).
// ---------------------------------------------------------------------------

enum FormatPub {
  /// Accueil (planche 85, format B) : pleine largeur, jusqu'à 250 px de haut.
  accueil,

  /// Listes d'avancées (planche 84 B) : pleine largeur, dans la place d'une avancée sans image.
  liste,

  /// « À venir » (planche 84 B) : pleine largeur, dans la place d'un événement.
  evenement,

  /// Bandeau adaptatif en bas d'une avancée ouverte.
  bandeau,
}

class _Reserve {
  /// Nombre d'annonces gardées prêtes pour chaque format.
  static const Map<FormatPub, int> cible = {
    FormatPub.accueil: 2, // une par accueil (Sciences et Technologies)
    FormatPub.liste: 2,
    FormatPub.evenement: 2,
    FormatPub.bandeau: 2,
  };

  /// Une annonce préchargée trop ancienne n'est plus servie (Google conseille moins d'une heure).
  static const Duration duree = Duration(minutes: 50);

  final Map<FormatPub, List<(BannerAd, DateTime)>> _pretes = {for (final f in FormatPub.values) f: []};
  final Map<FormatPub, int> _enCours = {for (final f in FormatPub.values) f: 0};
  final Map<FormatPub, int> _echecs = {for (final f in FormatPub.values) f: 0};
  final Map<FormatPub, Timer?> _relances = {};
  final Map<BannerAd, AdSize> _tailles = {};

  /// Taille réelle de l'annonce (sinon celle demandée).
  AdSize taille(BannerAd ad) => _tailles[ad] ?? ad.size;
  void oublier(BannerAd ad) => _tailles.remove(ad);

  /// Prévient les emplacements en attente qu'une annonce est prête.
  final ValueNotifier<int> change = ValueNotifier(0);

  String _id(FormatPub f) {
    final test = etat.statsExclues;
    switch (f) {
      // Test : emplacement de test « bannière ADAPTATIVE » de Google (l'emplacement de test
      // fixe ne renvoie qu'une bande de 50 px, d'où la pub minuscule vue le 08/11).
      case FormatPub.accueil:
        return test ? _testBandeau : idPubAccueil;
      case FormatPub.liste:
      case FormatPub.evenement:
        return test ? _testBandeau : idPubListe;
      case FormatPub.bandeau:
        return test ? _testBandeau : idPubBandeau;
    }
  }

  /// Hauteur maximale de l'annonce (bannière « adaptative intégrée » : Google choisit
  /// une image pleine largeur, au plus aussi haute que ça).
  static const Map<FormatPub, int> hauteurMax = {
    FormatPub.accueil: 250,
    FormatPub.liste: 116, // + la ligne « Publicité » = la place d'une avancée sans image (titre sur 2 lignes)
    FormatPub.evenement: 76, // la place d'un événement (sans ligne « Publicité »)
  };

  Future<AdSize?> _taille(FormatPub f) async {
    final vue = WidgetsBinding.instance.platformDispatcher.views.first;
    final ecran = (vue.physicalSize.width / vue.devicePixelRatio).truncate();
    if (f == FormatPub.bandeau) return AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(ecran);
    // Largeur d'une carte : l'écran moins les marges de 16 px de chaque côté.
    return AdSize.getInlineAdaptiveBannerAdSize(ecran - 32, hauteurMax[f]!);
  }

  int nbPretes(FormatPub f) => _pretes[f]!.length;
  bool chargeEncore(FormatPub f) => _enCours[f]! > 0;

  void remplir() {
    if (!pubsAffichees) return;
    for (final f in FormatPub.values) {
      if (_relances[f]?.isActive ?? false) continue;
      while (_pretes[f]!.length + _enCours[f]! < cible[f]!) {
        _enCours[f] = _enCours[f]! + 1;
        unawaited(_charger(f));
      }
    }
  }

  Future<void> _charger(FormatPub f) async {
    AdSize? taille;
    try {
      taille = await _taille(f);
    } catch (_) {}
    if (taille == null) {
      _enCours[f] = _enCours[f]! - 1;
      return;
    }
    BannerAd(
      adUnitId: _id(f),
      size: taille,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) async {
          _enCours[f] = _enCours[f]! - 1;
          _echecs[f] = 0;
          if (!pubsAffichees) {
            ad.dispose();
            return;
          }
          final banniere = ad as BannerAd;
          // Taille réelle choisie par Google (bannière adaptative).
          try {
            final reelle = await banniere.getPlatformAdSize();
            if (reelle != null) _tailles[banniere] = reelle;
          } catch (_) {}
          _pretes[f]!.add((banniere, DateTime.now()));
          change.value++;
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          _enCours[f] = _enCours[f]! - 1;
          change.value++;
          // Pas d'annonce disponible (fréquent au début) : on réessaie plus tard,
          // de plus en plus espacé (1 min, 2 min, 4 min… 15 min au plus).
          final n = _echecs[f] = _echecs[f]! + 1;
          final attente = Duration(seconds: (60 * (1 << (n - 1).clamp(0, 4))).clamp(60, 900));
          _relances[f]?.cancel();
          _relances[f] = Timer(attente, remplir);
        },
      ),
    ).load();
  }

  /// Une annonce prête, ou null. La réserve se remplit aussitôt derrière.
  BannerAd? prendre(FormatPub f) {
    final l = _pretes[f]!;
    final maintenant = DateTime.now();
    while (l.isNotEmpty && maintenant.difference(l.first.$2) > duree) {
      l.removeAt(0).$1.dispose();
    }
    final ad = l.isEmpty ? null : l.removeAt(0).$1;
    Future.microtask(remplir);
    return ad;
  }

  void vider() {
    for (final l in _pretes.values) {
      for (final (ad, _) in l) {
        ad.dispose();
      }
      l.clear();
    }
    change.value++;
  }
}

final _Reserve _reserve = _Reserve();

/// Petite mention « Publicité » au-dessus de chaque pub (bien la distinguer du contenu).
Widget _mention(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(tr('Publicité').toUpperCase(),
          style: police(policeTexte, taille: 10.5, graisse: FontWeight.w800, couleur: palette(context).texteDiscret)
              .copyWith(letterSpacing: 0.8)),
    );

/// Un emplacement d'annonce. [gabarit] : carte invisible qui donne sa taille exacte à
/// l'emplacement (une avancée sans image, un événement).
class _Emplacement extends StatefulWidget {
  final FormatPub format;
  final Widget? gabarit;
  final EdgeInsets marge;
  final double arrondi;
  const _Emplacement({required this.format, this.gabarit, this.marge = EdgeInsets.zero, this.arrondi = 20});

  @override
  State<_Emplacement> createState() => _EmplacementState();
}

class _EmplacementState extends State<_Emplacement> {
  BannerAd? _pub;
  ScrollPosition? _defilement;
  bool _premiere = true;

  @override
  void initState() {
    super.initState();
    _reserve.change.addListener(_essayer);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pos = Scrollable.maybeOf(context)?.position;
    if (pos != _defilement) {
      _defilement?.removeListener(_essayer);
      _defilement = pos;
      _defilement?.addListener(_essayer);
    }
    if (_premiere) {
      _premiere = false;
      _prendre(); // construit pour la 1re fois : une annonce déjà prête est bienvenue
    }
  }

  bool _assezLarge() => true; // bannières adaptatives : toujours à la largeur de l'écran

  void _prendre() {
    if (_pub != null || !pubsAffichees || !_assezLarge()) return;
    final ad = _reserve.prendre(widget.format);
    if (ad == null) return;
    _pub = ad;
    _reserve.change.removeListener(_essayer);
    _defilement?.removeListener(_essayer);
    _defilement = null;
    if (mounted) setState(() {});
  }

  /// Plus tard : seulement si l'emplacement est sous le bas de l'écran (invisible).
  void _essayer() {
    if (_pub != null || !mounted || widget.format == FormatPub.bandeau) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final y = box.localToGlobal(Offset.zero).dy;
    if (y > MediaQuery.sizeOf(context).height) _prendre();
  }

  @override
  void dispose() {
    _reserve.change.removeListener(_essayer);
    _defilement?.removeListener(_essayer);
    final pub = _pub;
    if (pub != null) {
      _reserve.oublier(pub);
      pub.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([pubsPretes, etat]),
        builder: (context, _) {
          final pub = _pub;
          if (!pubsAffichees || pub == null) return const SizedBox.shrink();
          final t = _reserve.taille(pub);
          final annonce = SizedBox(width: t.width.toDouble(), height: t.height.toDouble(), child: AdWidget(ad: pub));
          if (widget.format == FormatPub.bandeau) {
            return SizedBox(width: double.infinity, height: t.height.toDouble(), child: Center(child: annonce));
          }
          final p = palette(context);
          // Format B (planches 84-85) : l'annonce fait toute la largeur de la case.
          // La mention « Publicité » est posée juste AU-DESSUS de l'annonce, jamais dessus
          // (AdMob interdit de recouvrir une annonce).
          final avecMention = widget.format != FormatPub.evenement;
          final contenu = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (avecMention)
              Padding(padding: const EdgeInsets.fromLTRB(12, 0, 0, 0), child: _mention(context)),
            Center(child: annonce),
          ]);
          final gabarit = widget.gabarit;
          if (gabarit == null) {
            // Accueil : la case prend la hauteur de l'annonce (jusqu'à 250 px).
            return Padding(
              padding: widget.marge,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.arrondi),
                child: ColoredBox(
                  color: p.carte,
                  child: Padding(padding: const EdgeInsets.only(top: 8), child: contenu),
                ),
              ),
            );
          }
          // Listes et « À venir » : exactement la taille de la carte voisine (invisible dessous).
          return Padding(
            padding: widget.marge,
            child: Stack(children: [
              IgnorePointer(
                child: ExcludeSemantics(
                  child: Visibility(
                    visible: false,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: gabarit,
                  ),
                ),
              ),
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.arrondi),
                  child: ColoredBox(color: p.carte, child: Center(child: contenu)),
                ),
              ),
            ]),
          );
        },
      );
}

/// Bloc d'annonce de l'accueil (300 × 250), après « Nouveau pour vous ».
class BlocPub extends StatelessWidget {
  final bool accueil;
  const BlocPub({super.key, this.accueil = false});

  @override
  Widget build(BuildContext context) =>
      const _Emplacement(format: FormatPub.accueil, marge: EdgeInsets.only(bottom: 22));
}

/// Annonce dans une liste d'avancées : même taille que [carte] (une avancée sans image).
class PubListe extends StatelessWidget {
  final Widget carte;
  const PubListe({super.key, required this.carte});

  @override
  Widget build(BuildContext context) => _Emplacement(
      format: FormatPub.liste, gabarit: carte, marge: const EdgeInsets.only(bottom: 10), arrondi: arrondiCarte);
}

/// Annonce dans « À venir » : même taille que [carte] (un événement).
class PubEvenement extends StatelessWidget {
  final Widget carte;
  const PubEvenement({super.key, required this.carte});

  @override
  Widget build(BuildContext context) =>
      _Emplacement(format: FormatPub.evenement, gabarit: carte, marge: const EdgeInsets.only(bottom: 9), arrondi: 18);
}

/// Petit bandeau en bas d'une avancée ouverte (préchargé, largeur de l'écran).
class BandeauPub extends StatelessWidget {
  const BandeauPub({super.key});

  @override
  Widget build(BuildContext context) => const _Emplacement(format: FormatPub.bandeau);
}

// ---------------------------------------------------------------------------
// Achat « Retirer les annonces » (produit intégré Google Play, non consommable)
// ---------------------------------------------------------------------------

/// Prix affiché par Google Play (ex. « 3,99 € »), null tant qu'il n'est pas connu.
final ValueNotifier<String?> prixSansPub = ValueNotifier(null);
ProductDetails? _produit;
StreamSubscription<List<PurchaseDetails>>? _abonnement;

/// L'achat peut-il être proposé (Google Play joignable, produit créé dans la Play Console) ?
bool get achatsDisponibles => _produit != null;

Future<void> _demarrerAchats() async {
  try {
    final iap = InAppPurchase.instance;
    if (!await iap.isAvailable()) return;
    _abonnement ??= iap.purchaseStream.listen(_traiter, onError: (_) {});
    final r = await iap.queryProductDetails({idProduitSansPub});
    if (r.productDetails.isNotEmpty) {
      _produit = r.productDetails.first;
      prixSansPub.value = _produit!.price;
    }
    // App réinstallée ou nouveau téléphone : l'achat revient tout seul (lié au compte Google).
    if (!etat.sansPubAchete && !etat.achatTestIgnore) await iap.restorePurchases();
  } catch (_) {}
}

bool _restaurationManuelle = false;

void _traiter(List<PurchaseDetails> achats) {
  for (final a in achats) {
    if (a.productID == idProduitSansPub) {
      if (a.status == PurchaseStatus.purchased) etat.marquerSansPub();
      if (a.status == PurchaseStatus.restored) etat.marquerSansPub(automatique: !_restaurationManuelle);
    }
    // Confirmer l'achat à Google (sinon il est remboursé automatiquement au bout de 3 jours).
    if (a.pendingCompletePurchase) InAppPurchase.instance.completePurchase(a);
  }
}

/// Ouvre la fenêtre de paiement de Google Play. Faux si l'achat est impossible.
Future<bool> acheterSansPub() async {
  final produit = _produit;
  if (produit == null) return false;
  try {
    return await InAppPurchase.instance.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: produit));
  } catch (_) {
    return false;
  }
}

/// Bouton « Restaurer mes achats ».
Future<void> restaurerAchats() async {
  _restaurationManuelle = true;
  try {
    await InAppPurchase.instance.restorePurchases();
  } catch (_) {}
}

// ---------------------------------------------------------------------------
// Choix de confidentialité des annonces (RGPD : pouvoir changer d'avis à tout moment)
// ---------------------------------------------------------------------------

Future<bool> choixConfidentialiteDisponible() async {
  if (!pubsConfigurees) return false;
  try {
    return await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
        PrivacyOptionsRequirementStatus.required;
  } catch (_) {
    return false;
  }
}

Future<void> ouvrirChoixConfidentialite() async {
  try {
    await ConsentForm.showPrivacyOptionsForm((_) {});
  } catch (_) {}
}
