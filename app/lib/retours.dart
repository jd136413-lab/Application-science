// Retours des utilisateurs (maquette 42) : « Signaler une erreur » sur une
// avancée et « Donner mon avis » dans les Réglages. Les deux ouvrent
// l'application e-mail du téléphone avec un message déjà rempli.

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'etat.dart';
import 'langues.dart';
import 'modele.dart';
import 'reglages.dart';
import 'widgets.dart';

/// Adresse qui reçoit les signalements et les avis.
const String adresseRetours = 'jd136413@gmail.com';

/// Motifs de signalement : (titre, précision). Le titre français part dans l'e-mail.
const List<(String, String)> motifsSignalement = [
  ('Résumé inexact', 'Un fait, un chiffre ou une exagération'),
  ('Mauvaise note', 'Trop ou pas assez d’étoiles'),
  ('Pas une vraie avancée', 'Annonce, opinion, publicité…'),
  ('Doublon', 'Déjà présent dans le fil'),
  ('Lien cassé ou image', 'L’article ou la photo ne s’ouvre pas'),
  ('Autre', ''),
];

/// Modèle du téléphone et système (ex. « Xiaomi POCO X7 Pro · Android 15 »).
Future<String> _appareil() async {
  try {
    final info = DeviceInfoPlugin();
    if (kIsWeb) {
      final w = await info.webBrowserInfo;
      return 'Web · ${w.browserName.name}';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      final a = await info.androidInfo;
      return '${a.manufacturer} ${a.model} · Android ${a.version.release}';
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final i = await info.iosInfo;
      return '${i.utsname.machine} · iOS ${i.systemVersion}';
    }
  } catch (_) {}
  return '?';
}

Future<void> _envoyer(BuildContext context, String sujet, String corps) async {
  // Espaces encodés en %20 (et non « + ») pour un affichage correct dans toutes les applis e-mail.
  final uri = Uri.parse('mailto:$adresseRetours'
      '?subject=${Uri.encodeComponent(sujet)}&body=${Uri.encodeComponent(corps)}');
  var ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${tr('Aucune application e-mail trouvée. Écrivez-nous à :')} $adresseRetours')),
    );
  }
}

Future<String> _pied() async => '———\n'
    'Version : NovaSTEM $versionApp\n'
    'Téléphone : ${await _appareil()}\n'
    'Langue : ${etat.langue}';

/// « Signaler une erreur » : choix du motif, puis e-mail prérempli.
Future<void> signalerErreur(BuildContext context, Avancee a) async {
  final motif = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: palette(context).carte,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (context) {
      final p = palette(context);
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: p.bordure, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Text(tr('Signaler une erreur'),
                style: police(policeTitres, taille: 22, graisse: FontWeight.w800, couleur: p.texte)),
            const SizedBox(height: 4),
            Text(tr('Qu’est-ce qui ne va pas avec cette avancée ?'),
                style: police(policeTexte, taille: 14, couleur: p.texteDiscret)),
            const SizedBox(height: 8),
            for (final (titre, precision) in motifsSignalement)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(context).pop(titre),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: p.bordure.withValues(alpha: 0.6)))),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(tr(titre),
                            style: police(policeTexte, taille: 15, graisse: FontWeight.w700, couleur: p.texte)),
                        if (precision.isNotEmpty)
                          Text(tr(precision), style: police(policeTexte, taille: 12.5, couleur: p.texteDiscret)),
                      ]),
                    ),
                    Icon(Icons.chevron_right_rounded, color: p.texteDiscret),
                  ]),
                ),
              ),
            const SizedBox(height: 6),
            Text(tr('Votre application e-mail s’ouvre avec un message déjà rempli : il ne reste qu’à l’envoyer.'),
                style: police(policeTexte, taille: 12, couleur: p.texteDiscret, hauteur: 1.4)),
          ]),
        ),
      );
    },
  );
  if (motif == null || !context.mounted) return;
  final corps = '${tr('Votre remarque (facultatif) :')}\n\n\n\n'
      '———\n'
      'Motif : $motif\n'
      'Avancée : ${a.titre}\n'
      'Source : ${a.source} · ${a.lien}\n'
      'Identifiant : ${a.id}\n'
      '${(await _pied()).replaceFirst('———\n', '')}';
  if (!context.mounted) return;
  await _envoyer(context, '[NovaSTEM] Signalement : $motif', corps);
}

/// « Donner mon avis » (Réglages) : trois questions déjà écrites.
Future<void> donnerAvis(BuildContext context) async {
  final corps = '${tr('Ce que j’aime :')}\n\n\n'
      '${tr('Ce qui me gêne :')}\n\n\n'
      '${tr('Ce qui me manque :')}\n\n\n'
      '${await _pied()}';
  if (!context.mounted) return;
  await _envoyer(context, '[NovaSTEM] ${tr('Mon avis')}', corps);
}
