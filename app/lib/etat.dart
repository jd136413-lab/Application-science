// Mémoire locale de l'app, enregistrée sur le téléphone (aucun compte) :
// premier lancement terminé, domaines choisis, favoris, thème.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'modele.dart';
import 'reglages.dart';

class EtatApp extends ChangeNotifier {
  SharedPreferences? _prefs;

  bool premierLancementFait = false;
  Set<String> domaines = {}; // codes de familles choisis (vide = tout)
  ThemeMode theme = ThemeMode.system;
  final Map<String, Map<String, dynamic>> _favoris = {}; // id → données

  Future<void> charger() async {
    try {
      final p = await SharedPreferences.getInstance();
      _prefs = p;
      premierLancementFait = p.getBool('premier_lancement_fait') ?? false;
      domaines = (p.getStringList('domaines') ?? []).toSet();
      theme = ThemeMode.values.firstWhere((t) => t.name == p.getString('theme'), orElse: () => ThemeMode.system);
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
    p.setString('favoris', jsonEncode(_favoris.values.toList()));
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
