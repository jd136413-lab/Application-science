// Mode administrateur (18/11/2026) : bouton « Supprimer » sur une fiche ou une carte « À venir ».
// Invisible pour tout le monde sauf l'administrateur ; la suppression est de toute façon
// refusée par Supabase sans le code administrateur (migration 021).

import 'package:flutter/material.dart';

import 'etat.dart';
import 'reglages.dart';
import 'widgets.dart';

/// Bouton rouge « Supprimer (admin) » : confirmation, suppression, puis [apres] (recharger, fermer).
class BoutonSuppressionAdmin extends StatefulWidget {
  final String quoi; // « cette fiche », « cette carte »
  final Future<bool> Function() supprimer;
  final Future<void> Function() apres;
  const BoutonSuppressionAdmin({super.key, required this.quoi, required this.supprimer, required this.apres});

  @override
  State<BoutonSuppressionAdmin> createState() => _BoutonSuppressionAdminState();
}

class _BoutonSuppressionAdminState extends State<BoutonSuppressionAdmin> {
  bool _enCours = false;
  static const _rouge = Color(0xFFE5484D);

  Future<void> _go() async {
    final p = palette(context);
    final oui = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.carte,
        title: Text('Supprimer ${widget.quoi} ?',
            style: police(policeTitres, taille: 19, graisse: FontWeight.w700, couleur: p.texte)),
        content: Text(
            'Elle disparaît pour tout le monde (sur les autres téléphones, au plus tard dans 24 h). '
            'Ses articles ne seront pas repris par l’agent. C’est définitif.',
            style: police(policeTexte, taille: 14.5, couleur: p.texteDiscret)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _rouge, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (oui != true || !mounted) return;
    setState(() => _enCours = true);
    try {
      final ok = await widget.supprimer();
      if (!mounted) return;
      if (ok) {
        afficherMessage(context, 'Supprimée', icone: Icons.delete_outline_rounded);
        await widget.apres();
      } else {
        afficherMessage(context, 'Déjà supprimée ou introuvable', icone: Icons.info_outline_rounded);
      }
    } catch (_) {
      if (mounted) {
        afficherMessage(context, 'Suppression refusée (code ou réseau)', icone: Icons.error_outline_rounded);
      }
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!etat.admin) return const SizedBox.shrink();
    return TextButton.icon(
      onPressed: _enCours ? null : _go,
      style: TextButton.styleFrom(
          foregroundColor: _rouge, visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 10)),
      icon: _enCours
          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.delete_outline_rounded, size: 16),
      label: Text('Supprimer (admin)', style: police(policeTexte, taille: 13, graisse: FontWeight.w700, couleur: _rouge)),
    );
  }
}
