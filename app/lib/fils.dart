// Les deux fils (Sciences, Technologies) pour l'accueil magazine (maquette 64).
// Même fonctionnement que l'accueil classique : le fil gardé sur le téléphone
// s'affiche tout de suite, puis on télécharge les nouveautés ; sans réseau, on
// garde le dernier fil avec un bandeau.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'donnees.dart';
import 'etat.dart';
import 'modele.dart';
import 'stats.dart';
import 'texte_article.dart';

class FilsAvancees extends ChangeNotifier {
  final Map<String, List<Avancee>> fils = {};
  final Set<String> enCours = {};
  final Set<String> horsLigne = {};
  final Map<String, Object> erreurs = {};
  final Set<String> _demarres = {};

  /// Premier affichage : mémoire du téléphone, puis mise à jour.
  void demarrer(String fil) {
    if (!_demarres.add(fil)) return;
    () async {
      final garde = await filEnMemoire(fil);
      if (garde != null && !fils.containsKey(fil)) {
        fils[fil] = garde;
        notifyListeners();
        unawaited(pretraduire(garde));
      }
      await mettreAJour(fil);
    }();
  }

  final Map<String, DateTime> _misAJourLe = {};

  /// Retour dans l'app (elle était en arrière-plan) : fils mis à jour s'ils ont plus de 10 minutes.
  void rafraichirSiAncien() {
    for (final fil in _demarres) {
      final t = _misAJourLe[fil];
      if (t == null || DateTime.now().difference(t) > const Duration(minutes: 10)) unawaited(mettreAJour(fil));
    }
  }

  Future<void> mettreAJour(String fil, {bool complet = false}) async {
    _misAJourLe[fil] = DateTime.now();
    enCours.add(fil);
    erreurs.remove(fil);
    notifyListeners();
    try {
      final l = await mettreAJourFil(fil, complet: complet);
      fils[fil] = l;
      horsLigne.remove(fil);
      unawaited(pretraduire(l));
    } catch (e) {
      if (fils.containsKey(fil)) {
        if (horsLigne.add(fil)) stat('hors_ligne', valeur: fil);
      } else {
        erreurs[fil] = e;
      }
    } finally {
      enCours.remove(fil);
      notifyListeners();
    }
  }

  /// Avancées visibles d'un fil : domaines choisis, sans les avancées ni les sources masquées.
  List<Avancee> visibles(String fil) {
    final l = fils[fil];
    if (l == null) return const [];
    final familles = etat.famillesVisibles(fil);
    return l.where((a) => familles.contains(a.famille) && !etat.estMasquee(a)).toList();
  }
}

final filsAvancees = FilsAvancees();

/// Avancées publiées depuis [jours] jours (0 = « Nouveau » : badge NOUVEAU).
List<Avancee> surPeriode(List<Avancee> l, int jours) {
  if (jours == 0) return l.where(etat.estNouvelle).toList();
  final limite = DateTime.now().subtract(Duration(days: jours));
  return l.where((a) => a.publieLe.isAfter(limite)).toList();
}

/// De la plus importante à la moins importante (à importance égale : la plus récente).
List<Avancee> parImportance(List<Avancee> l) => List.of(l)
  ..sort((a, b) =>
      b.importance != a.importance ? b.importance.compareTo(a.importance) : b.publieLe.compareTo(a.publieLe));

/// Texte « simplifié » pour la recherche : minuscules, sans accents.
String sansAccents(String s) {
  const de = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ';
  const vers = 'aaaaaaceeeeiiiinooooouuuuyyoa';
  final b = StringBuffer();
  for (final c in s.toLowerCase().runes) {
    final ch = String.fromCharCode(c);
    final i = de.indexOf(ch);
    b.write(i >= 0 ? vers[i] : ch);
  }
  return b.toString();
}
