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
const String _testBloc = 'ca-app-pub-3940256099942544/6300978111';
const String _testBandeau = 'ca-app-pub-3940256099942544/9214589741';

String _id(String vrai, String test) => etat.statsExclues ? test : vrai;

bool _demarre = false;

/// Appelé une fois l'accueil affiché (après la présentation du premier lancement).
Future<void> demarrerPubs() async {
  if (_demarre || !Platform.isAndroid) return;
  _demarre = true;
  unawaited(_demarrerAchats());
  if (!pubsConfigurees || !etat.pubsVoulues) return;
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
  } catch (_) {
    // Pas de pub plutôt qu'une app qui plante.
  }
}

/// Petite mention « Publicité » au-dessus de chaque pub (obligatoire : bien la distinguer du contenu).
Widget _mention(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(tr('Publicité').toUpperCase(),
          style: police(policeTexte, taille: 10.5, graisse: FontWeight.w800, couleur: palette(context).texteDiscret)
              .copyWith(letterSpacing: 0.8)),
    );

/// Bloc d'annonce 300 × 250 (accueil et listes). N'occupe aucune place tant
/// que l'annonce n'est pas chargée, ou si les pubs sont coupées.
class BlocPub extends StatefulWidget {
  final bool accueil;
  const BlocPub({super.key, this.accueil = false});

  @override
  State<BlocPub> createState() => _BlocPubState();
}

class _BlocPubState extends State<BlocPub> {
  BannerAd? _pub;
  bool _chargee = false;

  void _charger() {
    if (_pub != null || !pubsAffichees) return;
    _pub = BannerAd(
      adUnitId: _id(widget.accueil ? idPubAccueil : idPubListe, _testBloc),
      size: AdSize.mediumRectangle,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _chargee = true);
        },
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    )..load();
  }

  @override
  void dispose() {
    _pub?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([pubsPretes, etat]),
        builder: (context, _) {
          if (!pubsAffichees) return const SizedBox.shrink();
          if (_pub == null) WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
          if (!_chargee || _pub == null) return const SizedBox.shrink();
          final p = palette(context);
          return Padding(
            padding: EdgeInsets.only(bottom: widget.accueil ? 22 : 10),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(color: p.carte, borderRadius: BorderRadius.circular(20)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _mention(context),
                Center(child: SizedBox(width: 300, height: 250, child: AdWidget(ad: _pub!))),
              ]),
            ),
          );
        },
      );
}

/// Petit bandeau en bas d'une avancée ouverte (largeur de l'écran, hauteur adaptée).
class BandeauPub extends StatefulWidget {
  const BandeauPub({super.key});

  @override
  State<BandeauPub> createState() => _BandeauPubState();
}

class _BandeauPubState extends State<BandeauPub> {
  BannerAd? _pub;
  bool _chargee = false;
  bool _enCours = false;

  Future<void> _charger(int largeur) async {
    if (_enCours || !pubsAffichees) return;
    _enCours = true;
    final taille = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(largeur);
    if (!mounted || taille == null) return;
    _pub = BannerAd(
      adUnitId: _id(idPubBandeau, _testBandeau),
      size: taille,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _chargee = true);
        },
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    )..load();
  }

  @override
  void dispose() {
    _pub?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([pubsPretes, etat]),
        builder: (context, _) {
          if (!pubsAffichees) return const SizedBox.shrink();
          final largeur = MediaQuery.sizeOf(context).width.truncate();
          if (!_enCours) WidgetsBinding.instance.addPostFrameCallback((_) => _charger(largeur));
          final pub = _pub;
          if (!_chargee || pub == null) return const SizedBox.shrink();
          return SizedBox(
            width: double.infinity,
            height: pub.size.height.toDouble(),
            child: Center(
              child: SizedBox(
                  width: pub.size.width.toDouble(), height: pub.size.height.toDouble(), child: AdWidget(ad: pub)),
            ),
          );
        },
      );
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
    if (!etat.sansPubAchete) await iap.restorePurchases();
  } catch (_) {}
}

void _traiter(List<PurchaseDetails> achats) {
  for (final a in achats) {
    if (a.productID == idProduitSansPub &&
        (a.status == PurchaseStatus.purchased || a.status == PurchaseStatus.restored)) {
      etat.marquerSansPub();
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
