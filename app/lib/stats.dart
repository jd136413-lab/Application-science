// Statistiques anonymes (tableau de bord : stats.html). Robots et téléphone de Maxime exclus.
//
// Chaque action (ouverture de l'app, lecture d'une avancée, favori…) ajoute
// une ligne dans la table « stats » de Supabase, SANS aucun identifiant du
// téléphone ou de la personne. L'app ne peut qu'ajouter des lignes, jamais
// les lire. Les totaux se consultent dans le tableau de bord NovaSTEM.
// Rien n'est bloquant : sans réseau, l'événement est simplement perdu.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'donnees.dart';
import 'etat.dart';
import 'modele.dart';
import 'reglages.dart';

/// Mettre à false pour couper toutes les statistiques.
const bool statistiquesActives = true;

/// Téléphone-robot de Google (« rapport de pré-lancement » de la Play Console) :
/// à chaque envoi d'une version, Google installe l'app sur des téléphones de test
/// qui passent le premier lancement tout seuls. Ils ne doivent pas compter.
bool appareilDeTest = false;

Future<void> detecterAppareilDeTest() async {
  if (kIsWeb) return;
  try {
    appareilDeTest = await const MethodChannel('novastem/appareil').invokeMethod<bool>('estAppareilDeTest') ?? false;
  } catch (_) {}
}

void stat(String evenement, {Avancee? a, String? valeur}) {
  // Pas de statistiques depuis la version web (aperçu GitHub Pages) :
  // seuls les vrais téléphones sont comptés.
  if (!statistiquesActives || !configurationPresente || kIsWeb || etat.statsExclues || appareilDeTest) return;
  try {
    Supabase.instance.client.from('stats').insert({
      'evenement': evenement,
      'version': versionApp, // ex. 1.0.38 : pour comparer les mises à jour
      if (a != null && a.id.isNotEmpty) 'avancee_id': a.id,
      if (a != null) 'fil': a.fil,
      if (a != null) 'famille': a.famille,
      if (a != null) 'theme': a.theme,
      if (a != null) 'importance': a.importance,
      if (valeur != null) 'valeur': valeur.length > 200 ? valeur.substring(0, 200) : valeur,
    }).then((_) {}, onError: (_) {});
  } catch (_) {}
}

/// Clic vers l'article source : compté UNE fois par fiche et par téléphone
/// (plusieurs sources, ou le même article rouvert, ne recomptent pas). Le tableau
/// de bord peut ainsi dire quelle part des avancées lues mène jusqu'à la source.
void statArticle(Avancee a, {String? valeur}) => _statArticle(a, valeur: valeur).ignore();

Future<void> _statArticle(Avancee a, {String? valeur}) async {
  if (!statistiquesActives || !configurationPresente || kIsWeb || etat.statsExclues || appareilDeTest) return;
  try {
    final p = await SharedPreferences.getInstance();
    final deja = p.getStringList('stat_articles') ?? <String>[];
    final cle = a.id.isNotEmpty ? a.id : a.lien;
    if (deja.contains(cle)) return;
    deja.add(cle);
    await p.setStringList('stat_articles', deja.length > 500 ? deja.sublist(deja.length - 500) : deja);
  } catch (_) {}
  stat('article', a: a, valeur: valeur);
}

/// Utilisateurs par langue (tableau de bord) : chaque téléphone envoie
/// « actif_jour » une fois par jour et « actif_mois » une fois par mois, avec la
/// langue de l'app. En les comptant, on connaît le nombre de téléphones actifs
/// par langue, toujours sans aucun identifiant. Si l'envoi échoue (pas de
/// réseau), on réessaiera à la prochaine ouverture.
Future<void> statsActivite() async {
  if (!statistiquesActives || !configurationPresente || kIsWeb || etat.statsExclues || appareilDeTest) return;
  try {
    final p = await SharedPreferences.getInstance();
    final langue = etat.langue;
    final n = DateTime.now();
    final mois = '${n.year}-${n.month.toString().padLeft(2, '0')}';
    final jour = '$mois-${n.day.toString().padLeft(2, '0')}';
    for (final (evenement, cle, valeur) in [
      ('actif_jour', 'stat_actif_jour', '$jour|$langue'),
      ('actif_mois', 'stat_actif_mois', '$mois|$langue'),
    ]) {
      if (p.getString(cle) == valeur) continue; // déjà compté
      await Supabase.instance.client.from('stats').insert({
        'evenement': evenement,
        'version': versionApp,
        'valeur': langue,
      });
      await p.setString(cle, valeur);
    }
  } catch (_) {}
}
