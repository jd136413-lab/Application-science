// Proposer d'activer les notifications (maquette 50, choix de Maxime du 31/10/2026).
//
// Android (13 et plus) demande toujours l'accord de la personne, et seulement deux
// fois. On ne montre donc la fenêtre d'Android QUE si la personne a touché
// « Activer » dans notre propre proposition :
//  - A (nouvelle installation) : une feuille qui monte du bas, une fois que la
//    personne a compris l'app : au moins 1 minute d'utilisation ET une avancée
//    déjà ouverte (ou 3 minutes sans en ouvrir) ;
//  - D (app installée avant cette version, ou après un premier « Plus tard ») :
//    une carte en haut du fil, après 1 minute dans l'app.
// « Plus tard » → reproposé dans 7 jours, puis 30 jours, puis plus jamais.
// Acceptées : ★★ Notable et plus, les deux fils, seulement les domaines choisis.

import 'dart:async';

import 'package:flutter/material.dart';

import 'ecran_notifications.dart' show heuresArrivee;
import 'etat.dart';
import 'langues.dart';
import 'modele.dart';
import 'notifications.dart';
import 'reglages.dart';
import 'stats.dart';
import 'widgets.dart';

/// Début de cette utilisation de l'app (pour « après 1 minute »).
final DateTime _debutSession = DateTime.now();

enum FormeProposition { aucune, feuille, carte }

/// Faut-il proposer maintenant, et sous quelle forme ?
FormeProposition propositionNotifDue() {
  if (!notificationsPossibles || !etat.premierLancementFait || etat.notifActives) return FormeProposition.aucune;
  if (etat.notifPropositions >= 3) return FormeProposition.aucune;
  final apres = etat.notifPropositionApres;
  if (apres != null && DateTime.now().isBefore(apres)) return FormeProposition.aucune;
  final secondes = DateTime.now().difference(_debutSession).inSeconds;
  if (secondes < 60) return FormeProposition.aucune;
  final nouvelle = etat.premierLancementLe != null && etat.notifPropositions == 0;
  if (!nouvelle) return FormeProposition.carte;
  // Nouvelle installation : seulement quand la personne a compris le principe.
  return (etat.lues.isNotEmpty || secondes >= 180) ? FormeProposition.feuille : FormeProposition.aucune;
}

/// « Activer » touché : fenêtre d'Android, puis réglage par défaut.
Future<void> accepterNotifs(BuildContext context) async {
  final ok = await demanderAutorisation();
  if (!context.mounted) return;
  if (ok) {
    etat.activerNotifsDepuisProposition();
    stat('notif_formule', valeur: 'proposition');
    final (a, b) = heuresArrivee(context);
    afficherMessage(context, tr('C’est noté : vous serez prévenu vers {a} et {b}.').replaceAll('{a}', a).replaceAll('{b}', b),
        icone: Icons.notifications_active_rounded);
  } else {
    // Refus dans la fenêtre d'Android : on ne repropose plus.
    etat.reporterPropositionNotif(definitif: true);
    afficherMessage(context, tr('Vous pourrez les activer à tout moment dans Réglages → Notifications.'),
        icone: Icons.notifications_off_outlined);
  }
}

/// A : feuille qui monte du bas. [exemple] : une vraie avancée du fil pour l'aperçu.
Future<void> montrerFeuilleNotifs(BuildContext context, Avancee? exemple) async {
  final accepte = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: palette(context).carte,
    builder: (context) => _FeuilleNotifs(exemple: exemple),
  );
  if (!context.mounted) return;
  if (accepte == true) {
    await accepterNotifs(context);
  } else {
    etat.reporterPropositionNotif();
  }
}

class _FeuilleNotifs extends StatelessWidget {
  final Avancee? exemple;
  const _FeuilleNotifs({this.exemple});

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final (a, b) = heuresArrivee(context);
    final e = exemple;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tr('Ne ratez pas les grandes avancées'),
              style: police(policeTitres, taille: 24, graisse: FontWeight.w800, couleur: p.texte, hauteur: 1.15)),
          const SizedBox(height: 8),
          Text(
              tr('Une notification vers {a} et {b}, seulement quand il y a du nouveau dans vos domaines.')
                  .replaceAll('{a}', a)
                  .replaceAll('{b}', b),
              style: police(policeTexte, taille: 15, couleur: p.texteDiscret, hauteur: 1.45)),
          if (e != null) ...[
            const SizedBox(height: 16),
            // Aperçu d'une notification, avec une vraie avancée du fil
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.fond,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TuileFamille(famille: familleDe(e.famille), taille: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('$nomApp · ${tr(e.fil == 'tech' ? texteTechnologies : texteSciences)} · $a',
                        style: police(policeTexte, taille: 12, couleur: p.texteDiscret)),
                    const SizedBox(height: 2),
                    Text(e.titre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: police(policeTexte, taille: 14, graisse: FontWeight.w700, couleur: p.texte, hauteur: 1.3)),
                    const SizedBox(height: 4),
                    Etoiles(note: e.importance, taille: 13),
                  ]),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 14),
          Text(tr('Réglable à tout moment dans Réglages → Notifications.'),
              style: police(policeTexte, taille: 13, couleur: p.texteDiscret)),
          const SizedBox(height: 16),
          SizedBox(
            height: 54,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: p.encre,
                foregroundColor: p.surEncre,
                shape: const StadiumBorder(),
                textStyle: police(policeTexte, taille: 16, graisse: FontWeight.w700),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(tr('Activer les notifications')),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('Plus tard'),
                style: police(policeTexte, taille: 15, graisse: FontWeight.w600, couleur: p.texteDiscret)),
          ),
        ]),
      ),
    );
  }
}

/// D : carte en haut du fil.
class CarteNotifs extends StatelessWidget {
  final VoidCallback onFermer;
  const CarteNotifs({super.key, required this.onFermer});

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final (a, b) = heuresArrivee(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 16),
      decoration: BoxDecoration(color: p.encre, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.notifications_none_rounded, color: p.surEncre, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(tr('Nouveau : les notifications'),
                style: police(policeTexte, taille: 16, graisse: FontWeight.w800, couleur: p.surEncre)),
          ),
          IconButton(
            tooltip: tr('Plus tard'),
            icon: Icon(Icons.close_rounded, color: p.surEncre.withValues(alpha: 0.75)),
            onPressed: () {
              etat.reporterPropositionNotif();
              onFermer();
            },
          ),
        ]),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Text(
              tr('Soyez prévenu des avancées de vos domaines, vers {a} et {b}.').replaceAll('{a}', a).replaceAll('{b}', b),
              style: police(policeTexte, taille: 14, couleur: p.surEncre.withValues(alpha: 0.85), hauteur: 1.45)),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Row(children: [
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: p.surEncre,
                  foregroundColor: p.encre,
                  minimumSize: const Size.fromHeight(44),
                  shape: const StadiumBorder(),
                  textStyle: police(policeTexte, taille: 14, graisse: FontWeight.w700),
                ),
                onPressed: () async {
                  await accepterNotifs(context);
                  onFermer();
                },
                child: Text(tr('Activer')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: p.surEncre,
                  minimumSize: const Size.fromHeight(44),
                  side: BorderSide(color: p.surEncre.withValues(alpha: 0.4), width: 1.5),
                  shape: const StadiumBorder(),
                  textStyle: police(policeTexte, taille: 14, graisse: FontWeight.w700),
                ),
                onPressed: () {
                  etat.reporterPropositionNotif();
                  onFermer();
                },
                child: Text(tr('Plus tard')),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
