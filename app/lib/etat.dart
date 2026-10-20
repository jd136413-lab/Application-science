// Mémoire locale de l'app, enregistrée sur le téléphone (aucun compte) :
// premier lancement terminé, domaines choisis, favoris, thème.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'langues.dart';
import 'modele.dart';
import 'notifications.dart';
import 'reglages.dart';

class EtatApp extends ChangeNotifier {
  SharedPreferences? _prefs;

  bool premierLancementFait = false;
  Set<String> domaines = {}; // codes de familles choisis (vide = tout)
  ThemeMode theme = ThemeMode.system;
  String? langueChoisie; // null = suivre la langue du téléphone
  final Map<String, Map<String, dynamic>> _favoris = {}; // id → données

  // Notifications (Réglages → Notifications)
  bool notifActives = false;
  String notifFil = 'both'; // 'science', 'tech' ou 'both'
  int notifMin = 4; // importance minimale (1 à 5)
  int notifLimite = 1; // au plus N par arrivée ; 0 = sans limite (1 = formule « L’essentiel »)
  Set<String> notifFamilles = {...famillesSciences, ...famillesTech};

  Future<void> charger() async {
    try {
      final p = await SharedPreferences.getInstance();
      _prefs = p;
      premierLancementFait = p.getBool('premier_lancement_fait') ?? false;
      domaines = (p.getStringList('domaines') ?? []).toSet();
      theme = ThemeMode.values.firstWhere((t) => t.name == p.getString('theme'), orElse: () => ThemeMode.system);
      final l = p.getString('langue');
      langueChoisie = languesDisponibles.containsKey(l) ? l : null;
      notifActives = p.getBool('notif_actives') ?? false;
      notifFil = p.getString('notif_fil') ?? 'both';
      notifMin = (p.getInt('notif_min') ?? 4).clamp(1, 5);
      notifLimite = p.getInt('notif_limite') ?? 1;
      final nf = p.getStringList('notif_familles');
      if (nf != null) notifFamilles = nf.toSet();
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
    p.setString('favoris', jsonEncode(_favoris.values.toList()));
    p.setBool('notif_actives', notifActives);
    p.setString('notif_fil', notifFil);
    p.setInt('notif_min', notifMin);
    p.setInt('notif_limite', notifLimite);
    p.setStringList('notif_familles', notifFamilles.toList());
  }

  // ---- Premier lancement / domaines ----
  void terminerPremierLancement(Set<String> choix) {
    domaines = {...choix};
    premierLancementFait = true;
    _enregistrer();
    notifyListeners();
  }

  void changerDomaines(Set<String> choix) {
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
  }

  // ---- Notifications ----
  /// Sujets Firebase à suivre : un par famille cochée et par niveau
  /// d'importance accepté (ex. n_space_4 et n_space_5 pour « Majeur et plus »).
  Set<String> get sujetsNotif {
    if (!notifActives) return {};
    final fils = notifFil == 'both' ? ['science', 'tech'] : [notifFil];
    return {
      for (final fil in fils)
        for (final f in famillesDuFil(fil))
          if (notifFamilles.contains(f))
            for (var i = notifMin; i <= 5; i++) 'n_${f}_$i',
    };
  }

  void changerNotifications({bool? actives, String? fil, int? min, int? limite, Set<String>? familles}) {
    if (actives != null) notifActives = actives;
    if (fil != null) notifFil = fil;
    if (min != null) notifMin = min;
    if (limite != null) notifLimite = limite;
    if (familles != null) notifFamilles = {...familles};
    _enregistrer();
    notifyListeners();
    synchroniserSujets(sujetsNotif);
  }

  // ---- Favoris ----
  bool estFavori(String id) => _favoris.containsKey(id);

  void basculerFavori(Avancee a) {
    if (_favoris.containsKey(a.id)) {
      _favoris.remove(a.id);
    } else {
      _favoris[a.id] = {...a.brut, 'id': a.id};
    }
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
