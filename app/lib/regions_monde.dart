// Régions du monde utilisées par l'agent pour dire d'où l'on voit un événement du ciel
// (éclipse, pluie d'étoiles filantes…). L'app compare avec le pays du téléphone
// (réglage de langue et région, pas de localisation GPS) : maquette 79, choix de Maxime du 02/11.

import 'dart:ui' show PlatformDispatcher;

import 'etat.dart';
import 'pays_noms.dart';

const Map<String, String> _regionDuPays = {
  // Europe (Russie et Turquie comprises)
  'FR': 'europe', 'BE': 'europe', 'CH': 'europe', 'LU': 'europe', 'MC': 'europe', 'AD': 'europe',
  'DE': 'europe', 'AT': 'europe', 'NL': 'europe', 'GB': 'europe', 'IE': 'europe', 'ES': 'europe',
  'PT': 'europe', 'IT': 'europe', 'SM': 'europe', 'VA': 'europe', 'MT': 'europe', 'GR': 'europe',
  'CY': 'europe', 'DK': 'europe', 'NO': 'europe', 'SE': 'europe', 'FI': 'europe', 'IS': 'europe',
  'EE': 'europe', 'LV': 'europe', 'LT': 'europe', 'PL': 'europe', 'CZ': 'europe', 'SK': 'europe',
  'HU': 'europe', 'SI': 'europe', 'HR': 'europe', 'BA': 'europe', 'RS': 'europe', 'ME': 'europe',
  'MK': 'europe', 'AL': 'europe', 'XK': 'europe', 'RO': 'europe', 'BG': 'europe', 'MD': 'europe',
  'UA': 'europe', 'BY': 'europe', 'RU': 'europe', 'TR': 'europe', 'LI': 'europe', 'GE': 'europe',
  'AM': 'europe', 'AZ': 'europe',
  // Afrique du Nord
  'MA': 'afrique_nord', 'DZ': 'afrique_nord', 'TN': 'afrique_nord', 'LY': 'afrique_nord',
  'EG': 'afrique_nord', 'SD': 'afrique_nord', 'EH': 'afrique_nord',
  // Afrique de l'Ouest
  'SN': 'afrique_ouest', 'MR': 'afrique_ouest', 'ML': 'afrique_ouest', 'NE': 'afrique_ouest',
  'BF': 'afrique_ouest', 'CI': 'afrique_ouest', 'GN': 'afrique_ouest', 'GW': 'afrique_ouest',
  'GM': 'afrique_ouest', 'SL': 'afrique_ouest', 'LR': 'afrique_ouest', 'GH': 'afrique_ouest',
  'TG': 'afrique_ouest', 'BJ': 'afrique_ouest', 'NG': 'afrique_ouest', 'CV': 'afrique_ouest',
  // Afrique centrale et de l'Est
  'CM': 'afrique_centre_est', 'TD': 'afrique_centre_est', 'CF': 'afrique_centre_est',
  'GA': 'afrique_centre_est', 'CG': 'afrique_centre_est', 'CD': 'afrique_centre_est',
  'GQ': 'afrique_centre_est', 'ST': 'afrique_centre_est', 'ET': 'afrique_centre_est',
  'ER': 'afrique_centre_est', 'DJ': 'afrique_centre_est', 'SO': 'afrique_centre_est',
  'KE': 'afrique_centre_est', 'UG': 'afrique_centre_est', 'RW': 'afrique_centre_est',
  'BI': 'afrique_centre_est', 'TZ': 'afrique_centre_est', 'SS': 'afrique_centre_est',
  // Afrique australe et océan Indien
  'ZA': 'afrique_australe', 'NA': 'afrique_australe', 'BW': 'afrique_australe', 'ZW': 'afrique_australe',
  'ZM': 'afrique_australe', 'MW': 'afrique_australe', 'MZ': 'afrique_australe', 'AO': 'afrique_australe',
  'LS': 'afrique_australe', 'SZ': 'afrique_australe', 'MG': 'afrique_australe', 'MU': 'afrique_australe',
  'RE': 'afrique_australe', 'YT': 'afrique_australe', 'KM': 'afrique_australe', 'SC': 'afrique_australe',
  // Moyen-Orient
  'SA': 'moyen_orient', 'AE': 'moyen_orient', 'QA': 'moyen_orient', 'BH': 'moyen_orient',
  'KW': 'moyen_orient', 'OM': 'moyen_orient', 'YE': 'moyen_orient', 'IQ': 'moyen_orient',
  'IR': 'moyen_orient', 'SY': 'moyen_orient', 'LB': 'moyen_orient', 'JO': 'moyen_orient',
  'IL': 'moyen_orient', 'PS': 'moyen_orient',
  // Asie centrale et du Sud
  'IN': 'asie_centrale_sud', 'PK': 'asie_centrale_sud', 'BD': 'asie_centrale_sud', 'LK': 'asie_centrale_sud',
  'NP': 'asie_centrale_sud', 'BT': 'asie_centrale_sud', 'MV': 'asie_centrale_sud', 'AF': 'asie_centrale_sud',
  'KZ': 'asie_centrale_sud', 'UZ': 'asie_centrale_sud', 'TM': 'asie_centrale_sud', 'KG': 'asie_centrale_sud',
  'TJ': 'asie_centrale_sud',
  // Asie de l'Est
  'CN': 'asie_est', 'JP': 'asie_est', 'KR': 'asie_est', 'KP': 'asie_est', 'MN': 'asie_est',
  'TW': 'asie_est', 'HK': 'asie_est', 'MO': 'asie_est',
  // Asie du Sud-Est
  'VN': 'asie_sud_est', 'TH': 'asie_sud_est', 'KH': 'asie_sud_est', 'LA': 'asie_sud_est',
  'MM': 'asie_sud_est', 'MY': 'asie_sud_est', 'SG': 'asie_sud_est', 'ID': 'asie_sud_est',
  'PH': 'asie_sud_est', 'BN': 'asie_sud_est', 'TL': 'asie_sud_est',
  // Océanie
  'AU': 'oceanie', 'NZ': 'oceanie', 'PG': 'oceanie', 'FJ': 'oceanie', 'NC': 'oceanie', 'PF': 'oceanie',
  'WF': 'oceanie', 'VU': 'oceanie', 'SB': 'oceanie', 'WS': 'oceanie', 'TO': 'oceanie',
  // Amérique du Nord
  'US': 'amerique_nord', 'CA': 'amerique_nord', 'PM': 'amerique_nord', 'GL': 'amerique_nord',
  // Amérique centrale et Caraïbes
  'MX': 'amerique_centrale', 'GT': 'amerique_centrale', 'BZ': 'amerique_centrale', 'HN': 'amerique_centrale',
  'SV': 'amerique_centrale', 'NI': 'amerique_centrale', 'CR': 'amerique_centrale', 'PA': 'amerique_centrale',
  'CU': 'amerique_centrale', 'HT': 'amerique_centrale', 'DO': 'amerique_centrale', 'JM': 'amerique_centrale',
  'PR': 'amerique_centrale', 'GP': 'amerique_centrale', 'MQ': 'amerique_centrale', 'BS': 'amerique_centrale',
  'TT': 'amerique_centrale', 'BB': 'amerique_centrale',
  // Amérique du Sud
  'BR': 'amerique_sud', 'AR': 'amerique_sud', 'CL': 'amerique_sud', 'UY': 'amerique_sud', 'PY': 'amerique_sud',
  'BO': 'amerique_sud', 'PE': 'amerique_sud', 'EC': 'amerique_sud', 'CO': 'amerique_sud', 'VE': 'amerique_sud',
  'GY': 'amerique_sud', 'SR': 'amerique_sud', 'GF': 'amerique_sud',
};

/// Pays choisi dans Réglages → Pays, sinon celui du téléphone.
String? paysActuel() => etat.paysChoisi ?? paysDuTelephone();

/// Tous les pays proposés dans Réglages → Pays.
Iterable<String> get tousLesPays => _regionDuPays.keys;

/// Nom du pays dans la langue de l'app.
String nomPays(String code) => nomsPays[etat.langue]?[code] ?? nomsPays['en']?[code] ?? code;

/// Drapeau (émoji) d'un code pays.
String drapeau(String code) =>
    code.length == 2 ? String.fromCharCodes(code.toUpperCase().codeUnits.map((c) => 0x1F1E6 + c - 65)) : '';

/// Pays du téléphone (code à 2 lettres, ex. « FR »), ou null s'il n'est pas réglé.
String? paysDuTelephone() {
  try {
    for (final l in PlatformDispatcher.instance.locales) {
      final c = l.countryCode;
      if (c != null && c.length == 2) return c.toUpperCase();
    }
  } catch (_) {}
  return null;
}

/// Région du monde du téléphone (null si inconnue).
String? regionDuTelephone() {
  final p = paysActuel();
  return p == null ? null : _regionDuPays[p];
}

enum Visibilite { totale, partielle, aucune, inconnue }

/// Ce que le téléphone peut voir d'un événement du ciel.
Visibilite visibiliteIci(List<String> totale, List<String> partielle) {
  if (totale.isEmpty && partielle.isEmpty) return Visibilite.inconnue;
  // Les listes peuvent contenir des pays (« ES ») pour être plus précises que les régions.
  final pays = paysActuel();
  if (pays != null && totale.contains(pays)) return Visibilite.totale;
  if (pays != null && partielle.contains(pays)) return Visibilite.partielle;
  final r = regionDuTelephone();
  if (r == null) return Visibilite.inconnue;
  if (totale.contains(r)) return Visibilite.totale;
  if (partielle.contains(r)) return Visibilite.partielle;
  return Visibilite.aucune;
}
