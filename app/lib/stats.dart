// Statistiques anonymes (tableau de bord : stats.html).
//
// Chaque action (ouverture de l'app, lecture d'une avancée, favori…) ajoute
// une ligne dans la table « stats » de Supabase, SANS aucun identifiant du
// téléphone ou de la personne. L'app ne peut qu'ajouter des lignes, jamais
// les lire. Les totaux se consultent dans le tableau de bord NovaSTEM.
// Rien n'est bloquant : sans réseau, l'événement est simplement perdu.

import 'package:supabase_flutter/supabase_flutter.dart';

import 'donnees.dart';
import 'modele.dart';

/// Mettre à false pour couper toutes les statistiques.
const bool statistiquesActives = true;

void stat(String evenement, {Avancee? a, String? valeur}) {
  if (!statistiquesActives || !configurationPresente) return;
  try {
    Supabase.instance.client.from('stats').insert({
      'evenement': evenement,
      if (a != null && a.id.isNotEmpty) 'avancee_id': a.id,
      if (a != null) 'fil': a.fil,
      if (a != null) 'famille': a.famille,
      if (a != null) 'theme': a.theme,
      if (a != null) 'importance': a.importance,
      if (valeur != null) 'valeur': valeur.length > 200 ? valeur.substring(0, 200) : valeur,
    }).then((_) {}, onError: (_) {});
  } catch (_) {}
}
