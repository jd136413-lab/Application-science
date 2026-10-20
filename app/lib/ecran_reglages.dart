// Écran Réglages : thème, notifications, langue, domaines, à propos.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ecran_notifications.dart';
import 'etat.dart';
import 'langues.dart';
import 'premier_lancement.dart';
import 'reglages.dart';
import 'traducteur.dart';
import 'widgets.dart';

class EcranReglages extends StatelessWidget {
  const EcranReglages({super.key});

  @override
  Widget build(BuildContext context) {
    final p = palette(context);

    Widget titreSection(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
          child: Text(tr(t).toUpperCase(),
              style: police(policeTexte, taille: 12, graisse: FontWeight.w700, couleur: p.texteDiscret)),
        );

    Widget bloc({required Widget child, VoidCallback? onTap}) => Material(
          color: p.carte,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.all(16), child: child)),
        );

    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) {
        final nbDomaines = etat.domaines.length;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 28),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(tr(texteOngletReglages),
                  style: police(policeTitres, taille: 34, graisse: FontWeight.w800, couleur: p.texte)),
            ),
            titreSection('Thème'),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: p.pastille, borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                for (final (mode, texte) in [
                  (ThemeMode.system, 'Automatique'),
                  (ThemeMode.light, 'Clair'),
                  (ThemeMode.dark, 'Sombre'),
                ])
                  Expanded(
                    child: Material(
                      color: etat.theme == mode ? p.carte : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => etat.changerTheme(mode),
                        child: SizedBox(
                          height: 42,
                          child: Center(
                            child: Text(tr(texte),
                                style: police(policeTexte,
                                    taille: 14,
                                    graisse: FontWeight.w700,
                                    couleur: etat.theme == mode ? p.texte : p.texteDiscret)),
                          ),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
            titreSection('Notifications'),
            bloc(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EcranNotifications()),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('Notifications'),
                        style: police(policeTexte, taille: 16, graisse: FontWeight.w600, couleur: p.texte)),
                    const SizedBox(height: 2),
                    Text(resumeNotifications(), style: police(policeTexte, taille: 13, couleur: p.texteDiscret)),
                  ]),
                ),
                Icon(Icons.chevron_right_rounded, color: p.texte),
              ]),
            ),
            titreSection('Langue'),
            bloc(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EcranLangue()),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('Langue de l’application'),
                        style: police(policeTexte, taille: 16, graisse: FontWeight.w600, couleur: p.texte)),
                    const SizedBox(height: 2),
                    Text(
                        etat.langueChoisie == null
                            ? '${tr('Automatique')} · ${languesDisponibles[etat.langue]}'
                            : languesDisponibles[etat.langue]!,
                        style: police(policeTexte, taille: 13, couleur: p.texteDiscret)),
                  ]),
                ),
                Icon(Icons.chevron_right_rounded, color: p.texte),
              ]),
            ),
            titreSection('Centres d’intérêt'),
            bloc(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EcranDomaines(premierLancement: false)),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('Mes domaines'),
                        style: police(policeTexte, taille: 16, graisse: FontWeight.w600, couleur: p.texte)),
                    const SizedBox(height: 6),
                    Row(children: [
                      for (final code in etat.domaines.take(6))
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                                color: familleDe(code).couleur, borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                      Text(
                          nbDomaines == 0
                              ? tr('Tout')
                              : nbDomaines == 1
                                  ? tr('1 domaine choisi')
                                  : tr('{n} domaines choisis', n: nbDomaines),
                          style: police(policeTexte, taille: 13, couleur: p.texteDiscret)),
                    ]),
                  ]),
                ),
                Icon(Icons.chevron_right_rounded, color: p.texte),
              ]),
            ),
            titreSection('À propos'),
            bloc(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('Nos sources'),
                    style: police(policeTexte, taille: 16, graisse: FontWeight.w600, couleur: p.texte)),
                const SizedBox(height: 8),
                Text(tr(texteNosSources),
                    style: police(policeTexte, taille: 14, couleur: p.texteDiscret, hauteur: 1.5)),
              ]),
            ),
            const SizedBox(height: 8),
            bloc(
              onTap: () => launchUrl(
                Uri.parse(etat.langue == 'fr' ? lienConfidentialiteFr : lienConfidentialiteEn),
                mode: LaunchMode.externalApplication,
              ),
              child: Row(children: [
                Expanded(
                  child: Text(tr('Politique de confidentialité'),
                      style: police(policeTexte, taille: 16, graisse: FontWeight.w600, couleur: p.texte)),
                ),
                Icon(Icons.open_in_new_rounded, color: p.texte, size: 20),
              ]),
            ),
            const SizedBox(height: 8),
            bloc(
              onTap: () => launchUrl(Uri.parse(lienContact), mode: LaunchMode.externalApplication),
              child: Row(children: [
                Expanded(
                  child: Text(tr('Nous contacter'),
                      style: police(policeTexte, taille: 16, graisse: FontWeight.w600, couleur: p.texte)),
                ),
                Icon(Icons.mail_outline_rounded, color: p.texte, size: 20),
              ]),
            ),
            const SizedBox(height: 18),
            Center(
              child: Text(tr(texteVersion),
                  textAlign: TextAlign.center, style: police(policeTexte, taille: 12, couleur: p.texteDiscret)),
            ),
          ],
        );
      },
    );
  }
}

/// Choix de la langue : automatique (celle du téléphone) ou une langue précise.
class EcranLangue extends StatelessWidget {
  const EcranLangue({super.key});

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) {
        Widget ligne(String? code, String nom, {String? detail}) {
          final choisie = etat.langueChoisie == code;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: Text(nom, style: police(policeTexte, taille: 16, graisse: FontWeight.w600, couleur: p.texte)),
            subtitle: detail == null
                ? null
                : Text(detail, style: police(policeTexte, taille: 13, couleur: p.texteDiscret)),
            trailing: choisie ? Icon(Icons.check_rounded, color: p.texte) : null,
            onTap: () => etat.changerLangue(code),
          );
        }

        return Scaffold(
          backgroundColor: p.fond,
          appBar: AppBar(
            backgroundColor: p.fond,
            foregroundColor: p.texte,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(tr('Langue de l’application'),
                style: police(policeTitres, taille: 20, graisse: FontWeight.w800, couleur: p.texte)),
          ),
          body: ListView(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                  traductionArticlesPossible
                      ? tr('Les articles sont traduits directement sur votre téléphone. La première fois, la langue est téléchargée (environ 30 Mo), puis tout fonctionne sans réseau.')
                      : tr('Sur la version web, les articles restent en français.'),
                  style: police(policeTexte, taille: 14, couleur: p.texteDiscret, hauteur: 1.45)),
            ),
            ligne(null, tr('Automatique (langue du téléphone)'), detail: languesDisponibles[langueDuTelephone()]),
            Divider(color: p.bordure, height: 1),
            for (final e in languesDisponibles.entries) ligne(e.key, e.value),
          ]),
        );
      },
    );
  }
}
