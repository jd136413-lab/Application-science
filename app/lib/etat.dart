// Mémoire locale de l'app, enregistrée sur le téléphone (aucun compte) :
// premier lancement terminé, domaines choisis, favoris, thème.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'langues.dart';
import 'modele.dart';
import 'notifications.dart';
import 'reglages.dart';
import 'stats.dart';
import 'traducteur.dart';

class EtatApp extends ChangeNotifier {
  SharedPreferences? _prefs;

  bool premierLancementFait = false;
  Set<String> domaines = {}; // codes de familles choisis (vide = tout)
  ThemeMode theme = ThemeMode.system;
  String? langueChoisie; // null = suivre la langue du téléphone
  String? paysChoisi; // null = pays du téléphone (Réglages → Pays, visibilité des événements du ciel)
  final Map<String, Map<String, dynamic>> _favoris = {}; // id → données
  int ouvertures = 0; // nombre de lancements de l'app (pour la demande d'avis)
  int favorisAjoutes = 0;
  bool avisDemande = false;
  /// Appareil exclu des statistiques (téléphone de Maxime) : 7 appuis sur la version dans Réglages.
  bool statsExclues = false;
  /// Niveaux d'importance (1 à 5) déjà expliqués par la bulle de la fiche.
  Set<int> niveauxVus = {};
  List<String> lues = []; // avancées déjà ouvertes (cartes grisées)
  /// Moment de la visite précédente : ce qui a été ajouté depuis est « Nouveau ».
  DateTime? visitePrecedente;
  List<String> masquees = []; // avancées masquées (balayage vers la gauche)
  Set<String> sourcesMasquees = {}; // sources masquées (appui long → « Masquer cette source »)
  /// Onglet Vocabulaire : les « mots à connaître » des avancées ouvertes.
  List<MotAppris> vocabulaire = [];

  // Notifications (Réglages → Notifications)
  bool notifActives = false;
  /// Présentation de l'onglet Actualités : accueil « magazine » (maquette 64, 01/11/2026)
  /// ou liste classique (onglets de période). Réglages → Présentation de l'accueil.
  bool accueilMagazine = true;
  Set<String> rappels = {}; // onglet « À venir » : événements avec « Me le rappeler »
  bool triDomainesImportance = false; // page d'un domaine et « Mes domaines suivis » : false = plus récent
  /// Rubriques de l'accueil magazine, dans l'ordre, avec leur état (affichée ou non).
  List<(String, bool)> rubriques = List.of(rubriquesParDefaut);
  /// Domaines suivis (bouton « Suivre » de la page d'un domaine).
  Set<String> domainesSuivis = {};
  /// Proposition d'activer les notifications (maquette 50) : nombre de « Plus tard »
  /// (3 = on ne propose plus), date avant laquelle on ne repropose pas, et date du
  /// premier lancement (null = app installée avant cette version → carte D).
  int notifPropositions = 0;
  DateTime? notifPropositionApres;
  DateTime? premierLancementLe;
  String notifFil = 'both'; // 'science', 'tech' ou 'both'
  int notifMin = 2; // importance minimale (1 à 5) ; par défaut ★★ Notable (2 à 3 par jour)
  /// « Sur mesure » : réglage propre à une famille. Absente = suit [notifMin] ;
  /// 0 = coupée ; 1 à 5 = son importance minimale.
  Map<String, int> notifParFamille = {};

  Future<void> charger() async {
    try {
      final p = await SharedPreferences.getInstance();
      _prefs = p;
      premierLancementFait = p.getBool('premier_lancement_fait') ?? false;
      domaines = (p.getStringList('domaines') ?? []).toSet();
      theme = ThemeMode.values.firstWhere((t) => t.name == p.getString('theme'), orElse: () => ThemeMode.system);
      final l = p.getString('langue');
      langueChoisie = languesDisponibles.containsKey(l) ? l : null;
      final pc = p.getString('pays') ?? '';
      paysChoisi = pc.length == 2 ? pc : null;
      notifActives = p.getBool('notif_actives') ?? false;
      notifPropositions = p.getInt('notif_propositions') ?? 0;
      accueilMagazine = p.getBool('accueil_magazine') ?? true;
      triDomainesImportance = p.getBool('tri_domaines_importance') ?? false;
      rappels = (p.getStringList('rappels_a_venir') ?? const []).toSet();
      domainesSuivis = (p.getStringList('domaines_suivis') ?? []).toSet();
      final rub = p.getStringList('rubriques_accueil');
      if (rub != null) {
        final lues = <(String, bool)>[
          for (final x in rub)
            if (rubriquesParDefaut.any((r) => r.$1 == x.split(':').first)) (x.split(':').first, x.endsWith(':1')),
        ];
        // Rubrique ajoutée dans une version plus récente : à la fin, avec son état par défaut.
        for (final r in rubriquesParDefaut) {
          if (!lues.any((x) => x.$1 == r.$1)) lues.add(r);
        }
        rubriques = lues;
      }
      // 01/11 (choix de Maxime) : les domaines choisis au premier lancement sont
      // aussi « suivis » et la rubrique « Mes domaines suivis » s'affiche. Fait une fois.
      if (p.getBool('suivis_depuis_choix') != true) {
        domainesSuivis = {...domainesSuivis, ...domaines};
        if (domainesSuivis.isNotEmpty) {
          rubriques = [for (final (c, on) in rubriques) (c, c == 'suivis' ? true : on)];
        }
        p.setBool('suivis_depuis_choix', true);
        p.setStringList('domaines_suivis', domainesSuivis.toList());
        p.setStringList('rubriques_accueil', [for (final (c, on) in rubriques) '$c:${on ? 1 : 0}']);
      }
      notifPropositionApres = DateTime.tryParse(p.getString('notif_proposition_apres') ?? '');
      premierLancementLe = DateTime.tryParse(p.getString('premier_lancement_le') ?? '');
      notifFil = p.getString('notif_fil') ?? 'both';
      if ((p.getInt('notif_version') ?? 1) < 2) {
        // Anciens réglages (formules, barème d'avant le 21/10) → nouveau modèle.
        final ancien = p.getInt('notif_min');
        if (ancien != null) notifMin = const [2, 1, 1, 2, 4, 5][ancien.clamp(1, 5)];
        final nf = p.getStringList('notif_familles');
        if (nf != null) {
          for (final f in [...famillesSciences, ...famillesTech]) {
            if (!nf.contains(f)) notifParFamille[f] = 0;
          }
        }
        p.setInt('notif_version', 2);
        p.setInt('notif_min', notifMin);
        p.setStringList('notif_par_famille', [for (final e in notifParFamille.entries) '${e.key}:${e.value}']);
      } else {
        notifMin = (p.getInt('notif_min') ?? 2).clamp(1, 5);
        for (final x in p.getStringList('notif_par_famille') ?? <String>[]) {
          final morceaux = x.split(':');
          final v = morceaux.length == 2 ? int.tryParse(morceaux[1]) : null;
          if (v != null) notifParFamille[morceaux[0]] = v.clamp(0, 5);
        }
      }
      ouvertures = (p.getInt('ouvertures') ?? 0) + 1;
      favorisAjoutes = p.getInt('favoris_ajoutes') ?? 0;
      avisDemande = p.getBool('avis_demande') ?? false;
      statsExclues = p.getBool('stats_exclues') ?? false;
      niveauxVus = (p.getStringList('niveaux_vus') ?? <String>[]).map(int.tryParse).whereType<int>().toSet();
      p.setInt('ouvertures', ouvertures);
      lues = p.getStringList('lues') ?? [];
      final v = p.getString('derniere_visite');
      visitePrecedente = v == null ? null : DateTime.tryParse(v);
      p.setString('derniere_visite', DateTime.now().toIso8601String());
      masquees = p.getStringList('masquees') ?? [];
      sourcesMasquees = (p.getStringList('sources_masquees') ?? []).toSet();
      final voc = p.getString('vocabulaire');
      if (voc != null) {
        vocabulaire = [
          for (final m in jsonDecode(voc) as List) MotAppris.depuisJson(Map<String, dynamic>.from(m as Map)),
        ];
      }
      final fav = p.getString('favoris');
      if (fav != null) {
        final liste = jsonDecode(fav) as List;
        for (final m in liste) {
          final map = Map<String, dynamic>.from(m as Map);
          _favoris[map['id'].toString()] = map;
        }
      }
    } catch (_) {
      // Mémoire illisible : on repart de zéro plutôt que de bloquer l'app.
    }
  }

  void _enregistrer() {
    final p = _prefs;
    if (p == null) return;
    p.setBool('premier_lancement_fait', premierLancementFait);
    p.setStringList('domaines', domaines.toList());
    p.setString('theme', theme.name);
    p.setString('langue', langueChoisie ?? '');
    p.setString('pays', paysChoisi ?? '');
    p.setString('favoris', jsonEncode(_favoris.values.toList()));
    p.setStringList('masquees', masquees);
    p.setStringList('lues', lues);
    p.setInt('favoris_ajoutes', favorisAjoutes);
    p.setBool('avis_demande', avisDemande);
    p.setBool('stats_exclues', statsExclues);
    p.setStringList('niveaux_vus', [for (final n in niveauxVus) '$n']);
    p.setStringList('sources_masquees', sourcesMasquees.toList());
    p.setString('vocabulaire', jsonEncode([for (final m in vocabulaire) m.versJson()]));
    p.setBool('notif_actives', notifActives);
    p.setInt('notif_propositions', notifPropositions);
    p.setBool('accueil_magazine', accueilMagazine);
    p.setBool('tri_domaines_importance', triDomainesImportance);
    p.setStringList('rappels_a_venir', rappels.toList());
    p.setStringList('domaines_suivis', domainesSuivis.toList());
    p.setStringList('rubriques_accueil', [for (final (c, on) in rubriques) '$c:${on ? 1 : 0}']);
    if (notifPropositionApres != null) p.setString('notif_proposition_apres', notifPropositionApres!.toIso8601String());
    if (premierLancementLe != null) p.setString('premier_lancement_le', premierLancementLe!.toIso8601String());
    p.setString('notif_fil', notifFil);
    p.setInt('notif_min', notifMin);
    p.setStringList('notif_par_famille', [for (final e in notifParFamille.entries) '${e.key}:${e.value}']);
  }

  /// Réglages → Pays (null = automatique).
  void changerPays(String? code) {
    paysChoisi = code;
    _enregistrer();
    notifyListeners();
  }

  /// Retient qu'un niveau d'importance a été expliqué (bulle de la fiche).
  void marquerNiveauVu(int n) {
    if (niveauxVus.add(n)) _enregistrer();
  }

  /// Exclut (ou réintègre) ce téléphone dans les statistiques.
  void basculerStatsExclues() {
    statsExclues = !statsExclues;
    _enregistrer();
    notifyListeners();
  }

  // ---- Premier lancement / domaines ----
  void terminerPremierLancement(Set<String> choix) {
    domaines = {...choix};
    // Les domaines choisis sont aussi « suivis » : rubrique « Mes domaines suivis » affichée.
    domainesSuivis = {...choix};
    if (choix.isNotEmpty) rubriques = [for (final (c, on) in rubriques) (c, c == 'suivis' ? true : on)];
    premierLancementFait = true;
    premierLancementLe = DateTime.now();
    stat('installation', valeur: choix.isEmpty ? 'tout' : (choix.toList()..sort()).join(','));
    _enregistrer();
    notifyListeners();
  }

  void changerDomaines(Set<String> choix) {
    // Domaines suivis : un domaine retiré n'est plus suivi, un domaine ajouté l'est.
    domainesSuivis = {...domainesSuivis.intersection(choix), ...choix.difference(domaines)};
    domaines = {...choix};
    _enregistrer();
    notifyListeners();
  }

  /// Familles à afficher pour un fil. Si aucune famille de ce fil n'est
  /// choisie, on montre tout le fil (pour ne jamais avoir un fil vide).
  Set<String> famillesVisibles(String fil) {
    final duFil = famillesDuFil(fil).toSet();
    final choisies = domaines.intersection(duFil);
    return choisies.isEmpty ? duFil : choisies;
  }

  // ---- Thème ----
  void changerTheme(ThemeMode t) {
    theme = t;
    _enregistrer();
    notifyListeners();
  }

  // ---- Langue ----
  /// Langue utilisée par l'app : le choix des Réglages, sinon celle du téléphone.
  String get langue => langueChoisie ?? langueDuTelephone();

  void changerLangue(String? code) {
    langueChoisie = code;
    _enregistrer();
    notifyListeners();
    if (!languesTraduitesParAgent.contains(langue)) preparerTraduction(langue);
  }

  // ---- Notifications ----
  /// Importance minimale d'une famille (0 = coupée).
  int minDeFamille(String code) => notifParFamille[code] ?? notifMin;

  /// Sujets Firebase à suivre : un par famille gardée et par niveau
  /// d'importance accepté (ex. n_space_4 et n_space_5 pour « Majeur et plus »).
  Set<String> get sujetsNotif {
    if (!notifActives) return {};
    final fils = notifFil == 'both' ? ['science', 'tech'] : [notifFil];
    return {
      for (final fil in fils)
        for (final f in famillesDuFil(fil))
          if (minDeFamille(f) > 0)
            for (var i = minDeFamille(f); i <= 5; i++) 'n_${f}_$i',
    };
  }

  void changerNotifications({bool? actives, String? fil, int? min}) {
    if (actives != null) notifActives = actives;
    if (fil != null) notifFil = fil;
    if (min != null) notifMin = min;
    _enregistrer();
    notifyListeners();
    synchroniserSujets(sujetsNotif);
  }

  // ---- Accueil magazine ----
  void ajouterRappel(String id) {
    if (rappels.add(id)) {
      _enregistrer();
      notifyListeners();
    }
  }

  void retirerRappel(String id) {
    if (rappels.remove(id)) {
      _enregistrer();
      notifyListeners();
    }
  }

  /// Bouton « Plus récent / Plus important » de la page d'un domaine (gardé sur le téléphone).
  void basculerTriDomaines() {
    triDomainesImportance = !triDomainesImportance;
    _enregistrer();
    notifyListeners();
  }

  void changerAccueil(bool magazine) {
    accueilMagazine = magazine;
    _enregistrer();
    notifyListeners();
  }

  void changerRubriques(List<(String, bool)> nouvelles) {
    rubriques = List.of(nouvelles);
    _enregistrer();
    notifyListeners();
  }

  bool rubriqueActive(String code) => rubriques.any((r) => r.$1 == code && r.$2);

  void basculerSuivi(String famille) {
    domainesSuivis.contains(famille) ? domainesSuivis.remove(famille) : domainesSuivis.add(famille);
    domainesSuivis = {...domainesSuivis};
    _enregistrer();
    notifyListeners();
  }

  /// Proposition de notifications : « Plus tard » → reproposée dans 7 jours, puis
  /// 30 jours, puis plus jamais (3 propositions au plus). [definitif] : on arrête.
  void reporterPropositionNotif({bool definitif = false}) {
    notifPropositions = definitif ? 3 : notifPropositions + 1;
    notifPropositionApres = DateTime.now().add(Duration(days: notifPropositions <= 1 ? 7 : 30));
    _enregistrer();
    notifyListeners();
  }

  /// Notifications acceptées depuis la proposition : réglage par défaut (★★ Notable
  /// et plus, les deux fils), limité aux domaines choisis au premier lancement.
  void activerNotifsDepuisProposition() {
    if (domaines.isNotEmpty) {
      for (final f in [...famillesSciences, ...famillesTech]) {
        if (!domaines.contains(f)) notifParFamille[f] = 0;
      }
    }
    notifPropositions = 3;
    changerNotifications(actives: true);
  }

  /// « Sur mesure » : [valeur] null = suivre le réglage général, 0 = couper, 1 à 5 = minimum propre.
  void changerFamilleNotif(String code, int? valeur) {
    if (valeur == null) {
      notifParFamille.remove(code);
    } else {
      notifParFamille[code] = valeur;
    }
    _enregistrer();
    notifyListeners();
    synchroniserSujets(sujetsNotif);
  }

  // ---- Favoris ----
  bool estFavori(String id) => _favoris.containsKey(id);

  void basculerFavori(Avancee a) {
    HapticFeedback.lightImpact(); // petite vibration
    stat(_favoris.containsKey(a.id) ? 'favori_retire' : 'favori', a: a);
    if (_favoris.containsKey(a.id)) {
      _favoris.remove(a.id);
    } else {
      _favoris[a.id] = {...a.brut, 'id': a.id};
      favorisAjoutes++;
      verifierDemandeAvis();
    }
    _enregistrer();
    notifyListeners();
  }

  // ---- Demande d'avis Google Play (une seule fois) ----
  /// Après la 10e ouverture de l'app ou le 5e favori : fenêtre officielle « Noter l'app ».
  Future<void> verifierDemandeAvis() async {
    if (avisDemande || (ouvertures < 10 && favorisAjoutes < 5)) return;
    avisDemande = true;
    _enregistrer();
    await Future<void>.delayed(const Duration(seconds: 4)); // laisser l'écran s'afficher
    if (await demanderAvis()) stat('avis_demande');
  }

  // ---- Lu / nouveau ----
  bool estLue(String id) => lues.contains(id);

  void marquerLue(String id) {
    if (lues.contains(id)) return;
    lues = [...lues, id];
    if (lues.length > 1000) lues = lues.sublist(lues.length - 1000);
    _enregistrer();
    notifyListeners();
  }

  /// « Nouveau » : ajoutée il y a moins de 3 jours et pas encore ouverte.
  bool estNouvelle(Avancee a) {
    final d = a.ajouteLe;
    return d != null && DateTime.now().difference(d) < dureeNouveaute && !estLue(a.id);
  }

  // ---- Avancées et sources masquées ----
  bool estMasquee(Avancee a) => masquees.contains(a.id) || sourcesMasquees.contains(a.source);

  void masquer(String id) {
    masquees = [...masquees.where((x) => x != id), id];
    if (masquees.length > 500) masquees = masquees.sublist(masquees.length - 500); // on garde les 500 dernières
    _enregistrer();
    notifyListeners();
  }

  void demasquer(String id) {
    masquees = masquees.where((x) => x != id).toList();
    _enregistrer();
    notifyListeners();
  }

  void reafficherAvancees() {
    masquees = [];
    _enregistrer();
    notifyListeners();
  }

  void masquerSource(String source, {bool visible = false}) {
    visible ? sourcesMasquees.remove(source) : sourcesMasquees.add(source);
    _enregistrer();
    notifyListeners();
  }

  // ---- Vocabulaire (planches 35-36) ----
  /// Ajoute les « mots à connaître » d'une avancée ouverte (sans doublon).
  /// Un mot nouveau arrive dans « À revoir », avec la mention « Nouveau ».
  void apprendre(Avancee a) {
    var ajout = false;
    for (final m in a.mots) {
      final cle = m.mot.toLowerCase();
      if (vocabulaire.any((v) => v.mot.toLowerCase() == cle)) continue;
      vocabulaire = [
        ...vocabulaire,
        MotAppris(
            mot: m.mot,
            definition: m.definition,
            idAvancee: a.id,
            titreAvancee: a.titre,
            famille: a.famille,
            appris: DateTime.now(),
            statut: 'nouveau'),
      ];
      ajout = true;
    }
    if (!ajout) return;
    if (vocabulaire.length > 2000) vocabulaire = vocabulaire.sublist(vocabulaire.length - 2000);
    _enregistrer();
    notifyListeners();
  }

  /// Range un mot dans « Je savais » ('su') ou « À revoir » ('revoir').
  void classerMot(String mot, String statut) {
    vocabulaire = [for (final v in vocabulaire) v.mot == mot ? v.avecStatut(statut) : v];
    _enregistrer();
    notifyListeners();
  }

  List<Avancee> get favoris {
    final l = _favoris.values.map(Avancee.depuisJson).toList();
    l.sort((a, b) => b.publieLe.compareTo(a.publieLe));
    return l;
  }
}

/// L'état unique de l'app, accessible partout.
final etat = EtatApp();

/// Un mot de l'onglet Vocabulaire, gardé sur le téléphone.
class MotAppris {
  final String mot, definition, idAvancee, titreAvancee, famille;
  final DateTime appris;
  /// 'nouveau' (jamais révisé, compté dans « À revoir »), 'revoir' ou 'su'.
  final String statut;
  const MotAppris({
    required this.mot,
    required this.definition,
    required this.idAvancee,
    required this.titreAvancee,
    required this.famille,
    required this.appris,
    required this.statut,
  });

  bool get aRevoir => statut != 'su';

  MotAppris avecStatut(String s) => MotAppris(
      mot: mot,
      definition: definition,
      idAvancee: idAvancee,
      titreAvancee: titreAvancee,
      famille: famille,
      appris: appris,
      statut: s);

  Map<String, dynamic> versJson() => {
        'mot': mot,
        'def': definition,
        'id': idAvancee,
        'titre': titreAvancee,
        'famille': famille,
        'appris': appris.toIso8601String(),
        'statut': statut,
      };

  factory MotAppris.depuisJson(Map<String, dynamic> j) => MotAppris(
        mot: (j['mot'] ?? '').toString(),
        definition: (j['def'] ?? '').toString(),
        idAvancee: (j['id'] ?? '').toString(),
        titreAvancee: (j['titre'] ?? '').toString(),
        famille: (j['famille'] ?? 'other').toString(),
        appris: DateTime.tryParse((j['appris'] ?? '').toString()) ?? DateTime.now(),
        statut: (j['statut'] ?? 'nouveau').toString(),
      );
}
