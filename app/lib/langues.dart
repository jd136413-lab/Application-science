// Langues de l'app et traduction des textes de l'interface.
//
// - Par défaut, l'app suit la langue du téléphone (si elle est dans la liste,
//   sinon l'anglais). On peut la forcer dans Réglages → Langue.
// - Les textes de l'interface sont traduits à l'avance (textes_traduits.dart).
// - Les titres et résumés des articles sont traduits sur le téléphone
//   (voir traducteur.dart).

import 'package:flutter/widgets.dart';

import 'etat.dart';
import 'textes_traduits.dart';

/// Code de langue → nom de la langue écrit dans cette langue.
/// Pour ajouter une langue, il faut aussi ses traductions (traductions/interface.txt).
const Map<String, String> languesDisponibles = {
  'fr': 'Français',
  'en': 'English',
  'es': 'Español',
  'pt': 'Português',
  'de': 'Deutsch',
  'it': 'Italiano',
  'nl': 'Nederlands',
  'pl': 'Polski',
  'ru': 'Русский',
  'uk': 'Українська',
  'tr': 'Türkçe',
  'ar': 'العربية',
  'hi': 'हिन्दी',
  'bn': 'বাংলা',
  'ur': 'اردو',
  'zh': '中文',
  'ja': '日本語',
  'ko': '한국어',
  'id': 'Bahasa Indonesia',
  'vi': 'Tiếng Việt',
};

/// Langue du téléphone si l'app la connaît, sinon l'anglais.
String langueDuTelephone() {
  for (final l in WidgetsBinding.instance.platformDispatcher.locales) {
    if (languesDisponibles.containsKey(l.languageCode)) return l.languageCode;
  }
  return 'en';
}

/// Traduit un texte de l'interface (écrit en français dans le code).
/// {n} est remplacé par [n]. Si une traduction manque : le texte français.
String tr(String francais, {int? n}) {
  final langue = etat.langue;
  final texte = langue == 'fr' ? francais : (textesTraduits[langue]?[francais] ?? francais);
  return n == null ? texte : texte.replaceAll('{n}', '$n');
}
