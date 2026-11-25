// Boîte à idées (maquette 96.6) : toutes les propositions reçues. Mode administrateur seulement
// (Réglages → Administration). Les données ne sont renvoyées par Supabase qu'avec le bon code
// (fonction admin_propositions), donc même un écran affiché par erreur resterait vide.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'detail.dart';
import 'propositions.dart';
import 'reglages.dart';
import 'soumettre.dart' show Pastille;
import 'widgets.dart';

const Color _vert = Color(0xFF2FC27B);
const Color _orange = Color(0xFFF5A524);
const Color _rouge = Color(0xFFE5484D);

class EcranBoiteIdees extends StatefulWidget {
  const EcranBoiteIdees({super.key});
  @override
  State<EcranBoiteIdees> createState() => _EcranBoiteIdeesState();
}

class _EcranBoiteIdeesState extends State<EcranBoiteIdees> {
  late Future<List<Proposition>> _liste = toutesLesPropositions();
  String? _filtre; // a_valider · nouvelles · ameliorations · toutes (null : « À valider » s'il y en a)

  Future<void> _recharger() async {
    final f = toutesLesPropositions();
    setState(() => _liste = f);
    try {
      await f;
    } catch (_) {}
  }

  static (String, Color) _categorie(Proposition x) => switch (x.genre) {
        'sujet' => (x.fil == 'a_venir' ? '📅 ÉVÉNEMENT' : '⚡ SUJET', logoEncreBleue),
        'resume' => ('✎ RÉSUMÉ', _vert),
        _ => switch (x.categorie) {
            'bug' => ('🐞 BUG', _rouge),
            'design' => ('🎨 DESIGN', const Color(0xFFB49BFF)),
            'idee' => ('💡 IDÉE', _orange),
            _ => ('💡 AMÉLIORATION', _orange),
          },
      };

  static (String, Color) _etat(String s) => switch (s) {
        'a_faire' => ('À faire', _orange),
        'faite' => ('Fait', _vert),
        'ignoree' => ('Ignorée', _rouge),
        'publiee' => ('Publiée', _vert),
        'refusee' => ('Refusée', _rouge),
        'en_cours' => ('En cours', _orange),
        'a_valider' => ('À valider', _orange),
        _ => ('Nouvelle', logoEncreBleue),
      };

  String _quand(DateTime d) {
    final j = DateTime.now().difference(d).inDays;
    final h = '${d.hour.toString().padLeft(2, '0')} h ${d.minute.toString().padLeft(2, '0')}';
    if (j == 0 && d.day == DateTime.now().day) return 'aujourd’hui $h';
    if (j <= 1) return 'hier $h';
    return '${d.day}/${d.month.toString().padLeft(2, '0')} $h';
  }

  /// Ouvre la fiche en attente telle qu'elle apparaîtra dans le fil.
  Future<void> _voirFiche(Proposition x) async {
    try {
      final a = await adminFiche(x.ficheId ?? '');
      if (!mounted) return;
      if (a == null) {
        afficherMessage(context, 'Fiche introuvable', icone: Icons.error_outline_rounded);
        return;
      }
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => EcranDetailFil(liste: [a], depart: 0)));
    } catch (_) {
      if (mounted) afficherMessage(context, 'Impossible d’ouvrir la fiche (réseau ?)', icone: Icons.error_outline_rounded);
    }
  }

  /// Supprimer la fiche publiée à partir d'une proposition (après confirmation).
  Future<void> _supprimerFiche(Proposition x) async {
    final p = palette(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.carte,
        title: Text('Supprimer cette fiche ?',
            style: police(policeTitres, taille: 19, graisse: FontWeight.w700, couleur: p.texte)),
        content: Text('Elle disparaîtra de l’application pour tout le monde.',
            style: police(policeTexte, taille: 15, couleur: p.texteDiscret)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _rouge, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final fait = await adminSupprimerFiche(x.ficheId ?? '');
      if (!mounted) return;
      afficherMessage(context, fait ? 'Fiche supprimée ✓' : 'Déjà supprimée, ou code refusé.',
          icone: fait ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded);
      await _recharger();
    } catch (_) {
      if (mounted) afficherMessage(context, 'Suppression impossible (réseau ?)', icone: Icons.error_outline_rounded);
    }
  }

  Future<void> _actions(Proposition x) async {
    final p = palette(context);
    final choix = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: p.carte,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_categorie(x).$1,
                style: police(policeTexte, taille: 12, graisse: FontWeight.w800, couleur: _categorie(x).$2)),
            const SizedBox(height: 8),
            SelectableText(x.resume ?? x.texte,
                style: police(policeTexte, taille: 15.5, couleur: p.texte, hauteur: 1.45)),
            if ((x.lien ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () { final l = Uri.tryParse(x.lien!); if (l != null) launchUrl(l, mode: LaunchMode.externalApplication); },
                child: Text(x.lien!,
                    style: police(policeTexte, taille: 13, couleur: logoEncreBleue), maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ],
            const SizedBox(height: 8),
            Text([_quand(x.cree), if ((x.infos ?? '').isNotEmpty) x.infos!].join(' · '),
                style: police(policeTexte, taille: 12, couleur: p.texteDiscret)),
            if ((x.message ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(x.message!, style: police(policeTexte, taille: 13, couleur: p.texteDiscret)),
            ],
            // 25/11 (Maxime) : l'administrateur ne valide plus ; il voit les propositions et peut
            // supprimer une fiche publiée à partir d'une proposition.
            if ((x.ficheId ?? '').isNotEmpty) ...[
              const SizedBox(height: 16),
              for (final (cle, nom, icone) in const [
                ('voir', 'Voir la fiche publiée', Icons.visibility_outlined),
                ('supprimer_fiche', 'Supprimer la fiche publiée', Icons.delete_outline_rounded),
              ])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(icone, color: cle == 'supprimer_fiche' ? _rouge : p.texte),
                  title: Text(nom, style: police(policeTexte, taille: 15, graisse: FontWeight.w700, couleur: p.texte)),
                  onTap: () => Navigator.pop(ctx, cle),
                ),
            ],
            if (x.genre == 'amelioration') ...[
              const SizedBox(height: 16),
              for (final (cle, nom, icone) in const [
                ('a_faire', 'À faire', Icons.flag_outlined),
                ('faite', 'Fait', Icons.check_circle_outline_rounded),
                ('ignoree', 'Ignorer', Icons.block_rounded),
                ('nouvelle', 'Remettre en « Nouvelle »', Icons.fiber_new_outlined),
              ])
                if (cle != x.statut)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(icone, color: p.texte),
                    title: Text(nom, style: police(policeTexte, taille: 15, graisse: FontWeight.w700, couleur: p.texte)),
                    onTap: () => Navigator.pop(ctx, cle),
                  ),
            ],
          ]),
        ),
      ),
    );
    if (choix == null) return;
    if (choix == 'voir') return _voirFiche(x);
    if (choix == 'supprimer_fiche') return _supprimerFiche(x);
    try {
      await changerStatut(x.id, choix);
      await _recharger();
    } catch (_) {
      if (mounted) afficherMessage(context, 'Changement impossible (réseau ?)', icone: Icons.error_outline_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    return Scaffold(
      backgroundColor: p.fond,
      appBar: AppBar(
        backgroundColor: p.fond,
        surfaceTintColor: Colors.transparent,
        foregroundColor: p.texte,
        title: Text('Boîte à idées', style: police(policeTitres, taille: 22, graisse: FontWeight.w800, couleur: p.texte)),
      ),
      body: FutureBuilder<List<Proposition>>(
        future: _liste,
        builder: (context, s) {
          if (s.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.hasError) {
            return MessageCentre(
              icone: Icons.lock_outline_rounded,
              titre: 'Accès refusé ou pas de réseau',
              detail: 'Vérifie ta connexion. Si le problème continue, ressaisis ton code administrateur.',
            );
          }
          final toutes = s.data ?? [];
          final nouvelles = toutes.where((x) => x.statut == 'nouvelle' && x.genre == 'amelioration').toList();
          final aValider = toutes.where((x) => x.statut == 'a_valider').toList();
          final filtre = _filtre ?? (aValider.isNotEmpty ? 'a_valider' : 'toutes');
          final amelio = toutes.where((x) => x.genre == 'amelioration').toList();
          final liste = switch (filtre) {
            'a_valider' => aValider,
            'nouvelles' => nouvelles,
            'ameliorations' => amelio,
            _ => toutes,
          };
          return RefreshIndicator(
            onRefresh: _recharger,
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
              Text('Toutes les propositions envoyées par les lecteurs. Visible seulement par toi.',
                  style: police(policeTexte, taille: 13.5, couleur: p.texteDiscret)),
              const SizedBox(height: 12),
              Wrap(spacing: 6, children: [
                for (final (cle, nom) in [
                  if (aValider.isNotEmpty) ('a_valider', 'Anciennes en attente · ${aValider.length}'),
                  ('nouvelles', 'Nouvelles · ${nouvelles.length}'),
                  ('ameliorations', 'Améliorations · ${amelio.length}'),
                  ('toutes', 'Tout · ${toutes.length}'),
                ])
                  ChoiceChip(
                    label: Text(nom),
                    selected: filtre == cle,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _filtre = cle),
                    labelStyle: police(policeTexte,
                        taille: 13, graisse: FontWeight.w800, couleur: filtre == cle ? p.surEncre : p.texteDiscret),
                    selectedColor: p.encre,
                    backgroundColor: p.carte,
                    side: BorderSide(color: filtre == cle ? p.encre : p.bordure),
                  ),
              ]),
              const SizedBox(height: 12),
              if (liste.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Center(
                      child: Text('Rien ici pour l’instant.',
                          style: police(policeTexte, taille: 14, couleur: p.texteDiscret))),
                ),
              for (final x in liste)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: p.carte,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _actions(x),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(
                                child: Text(_categorie(x).$1,
                                    style: police(policeTexte,
                                        taille: 11.5, graisse: FontWeight.w800, couleur: _categorie(x).$2))),
                            Pastille(_etat(x.statut).$1, _etat(x.statut).$2),
                          ]),
                          const SizedBox(height: 6),
                          Text(x.texte, style: police(policeTexte, taille: 14.5, couleur: p.texte, hauteur: 1.35)),
                          const SizedBox(height: 4),
                          Text([_quand(x.cree), if ((x.infos ?? '').isNotEmpty) x.infos!].join(' · '),
                              style: police(policeTexte, taille: 11.5, couleur: p.texteDiscret)),
                        ]),
                      ),
                    ),
                  ),
                ),
            ]),
          );
        },
      ),
    );
  }
}
