// Version Android / iPhone : traduction hors ligne avec Google ML Kit.
// La première fois qu'une langue est utilisée, son modèle (~30 Mo) est
// téléchargé ; ensuite tout se fait sur le téléphone, sans réseau.

import 'package:google_mlkit_translation/google_mlkit_translation.dart';

const bool traductionArticlesPossible = true;

final _gestionnaire = OnDeviceTranslatorModelManager();
final Map<String, Future<OnDeviceTranslator?>> _traducteurs = {};
final Map<String, String> _cache = {}; // « langue|texte » → traduction

TranslateLanguage? _langueMlKit(String code) {
  for (final l in TranslateLanguage.values) {
    if (l.bcpCode == code) return l;
  }
  return null;
}

/// Prépare (une seule fois par langue) le traducteur français → langue.
Future<OnDeviceTranslator?> _traducteur(String langue) {
  return _traducteurs.putIfAbsent(langue, () async {
    final cible = _langueMlKit(langue);
    if (cible == null) return null;
    try {
      for (final code in [TranslateLanguage.french.bcpCode, cible.bcpCode]) {
        if (!await _gestionnaire.isModelDownloaded(code)) {
          await _gestionnaire.downloadModel(code, isWifiRequired: false);
        }
      }
      return OnDeviceTranslator(sourceLanguage: TranslateLanguage.french, targetLanguage: cible);
    } catch (_) {
      _traducteurs.remove(langue); // on réessaiera plus tard (pas de réseau…)
      return null;
    }
  });
}

/// Traduit un texte français dans [langue]. En cas de souci : le texte d'origine.
Future<String> traduireArticle(String texte, String langue) async {
  if (langue == 'fr' || texte.trim().isEmpty) return texte;
  final cle = '$langue|$texte';
  final deja = _cache[cle];
  if (deja != null) return deja;
  final t = await _traducteur(langue);
  if (t == null) return texte;
  try {
    final resultat = await t.translateText(texte);
    if (resultat.trim().isEmpty) return texte;
    _cache[cle] = resultat;
    return resultat;
  } catch (_) {
    return texte;
  }
}
