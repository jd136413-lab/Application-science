// Onglet « Soumettre » (maquette 96, 17/11/2026). Visible seulement en mode administrateur
// pour l'instant (coquille.dart). Trois choix : proposer un sujet (Sciences, Technologies ou
// À venir), proposer un résumé, proposer une amélioration de l'application.
// Les sujets et résumés sont traités par le script agent/soumissions.py (séparé de l'agent) ;
// les améliorations arrivent telles quelles dans la boîte à idées (boite_idees.dart).

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'detail.dart';
import 'donnees.dart' show chargerAvancee;
import 'etat.dart';
import 'propositions.dart';
import 'reglages.dart';
import 'retours.dart' show descriptionAppareil;
import 'widgets.dart';

const Color _vert = Color(0xFF2FC27B);
const Color _orange = Color(0xFFF5A524);
const Color _rouge = Color(0xFFE5484D);
const int _motsMax = 12; // même limite que les titres de l'agent (redaction.py)

String _date(DateTime d) {
  const mois = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
  return '${d.day} ${mois[d.month - 1]}';
}

(String, Color) _etat(String statut) => switch (statut) {
      'publiee' => ('Publiée', _vert),
      'faite' => ('Fait', _vert),
      'refusee' => ('Non publiée', _rouge),
      'ignoree' => ('Classée', _rouge),
      'en_cours' => ('En vérification', _orange),
      'a_faire' => ('À faire', _orange),
      _ => ('Reçue', logoEncreBleue),
    };

String _genre(Proposition x) => switch (x.genre) {
      'sujet' => x.fil == 'a_venir' ? 'Événement' : 'Sujet',
      'resume' => 'Résumé',
      _ => 'Amélioration',
    };

class Pastille extends StatelessWidget {
  final String texte;
  final Color couleur;
  const Pastille(this.texte, this.couleur, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: couleur.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
        child: Text(texte, style: police(policeTexte, taille: 11, graisse: FontWeight.w800, couleur: couleur)),
      );
}

// ------------------------------------------------------------------ l'onglet

class EcranSoumettre extends StatefulWidget {
  const EcranSoumettre({super.key});
  @override
  State<EcranSoumettre> createState() => _EcranSoumettreState();
}

class _EcranSoumettreState extends State<EcranSoumettre> {
  late Future<List<Proposition>> _liste = mesPropositions();

  @override
  void initState() {
    super.initState();
    // Téléphone administrateur : (ré)enregistré pour ne pas avoir de limite de propositions.
    final code = etat.adminCode;
    if (code != null) verifierCodeAdmin(code).catchError((_) => null);
  }

  Future<void> _recharger() async {
    final f = mesPropositions();
    setState(() => _liste = f);
    try {
      await f;
    } catch (_) {}
  }

  Future<void> _ouvrir(Widget ecran) async {
    final envoye = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => ecran));
    if (envoye == true) {
      await _recharger();
      if (mounted) afficherMessage(context, 'Proposition envoyée, merci !');
    }
  }

  /// « dans 4 j 6 h », « dans 3 h », « dans 12 min ».
  static String _dans(Duration d) {
    if (d.inDays >= 1) return 'dans ${d.inDays} j ${d.inHours % 24} h';
    if (d.inHours >= 1) return 'dans ${d.inHours} h';
    return 'dans ${d.inMinutes.clamp(1, 59)} min';
  }

  /// [prochaine] : moment où cette sorte de proposition redevient possible (null = possible maintenant).
  Widget _choix(IconData icone, Color c, String titre, String detail, Widget ecran, {DateTime? prochaine}) {
    final p = palette(context);
    final reste = prochaine?.difference(DateTime.now());
    final attente = reste != null && !reste.isNegative;
    final fraction = attente ? (1 - reste.inMinutes / const Duration(days: 7).inMinutes).clamp(0.0, 1.0) : 1.0;
    return Material(
      color: p.carte,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: attente
            ? () => afficherMessage(context, '1 par semaine : de nouveau possible ${_dans(reste)} ⏳',
                icone: Icons.hourglass_bottom_rounded)
            : () => _ouvrir(ecran),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Opacity(
              opacity: attente ? 0.5 : 1,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: c.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
                child: Icon(icone, color: c, size: 22),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titre,
                    style: police(policeTitres,
                        taille: 17, graisse: FontWeight.w800, couleur: attente ? p.texteDiscret : p.texte)),
                const SizedBox(height: 2),
                Text(attente ? '⏳ De nouveau possible ${_dans(reste)}' : detail,
                    style: police(policeTexte,
                        taille: 13, graisse: attente ? FontWeight.w700 : FontWeight.w400,
                        couleur: attente ? c : p.texteDiscret)),
              ]),
            ),
            if (attente)
              // L'anneau se remplit jour après jour jusqu'à la prochaine proposition possible.
              SizedBox(
                width: 46,
                height: 46,
                child: Stack(alignment: Alignment.center, children: [
                  SizedBox(
                    width: 42,
                    height: 42,
                    child: CircularProgressIndicator(
                      value: fraction,
                      strokeWidth: 4,
                      strokeCap: StrokeCap.round,
                      backgroundColor: p.pastille,
                      color: c,
                    ),
                  ),
                  Text(reste.inDays >= 1 ? '${reste.inDays} j' : '${reste.inHours} h',
                      style: police(policeTexte, taille: 12, graisse: FontWeight.w800, couleur: p.texte)),
                ]),
              )
            else
              Icon(Icons.chevron_right_rounded, color: p.texteDiscret),
          ]),
        ),
      ),
    );
  }

  Future<void> _detail(Proposition x) async {
    final r = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => EcranMaProposition(proposition: x)));
    if (r == null) return;
    await _recharger();
    if (mounted) {
      afficherMessage(context, r == 'supprimee' ? 'Proposition supprimée' : 'Proposition modifiée',
          icone: r == 'supprimee' ? Icons.delete_outline_rounded : Icons.check_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    return RefreshIndicator(
      onRefresh: _recharger,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 28, 16, 24), children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('Soumettre', style: police(policeTitres, taille: 34, graisse: FontWeight.w800, couleur: p.texte)),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Pastille('🔒 Visible seulement sur ton téléphone', const Color(0xFF8B5CF6)),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('Aide-nous à faire grandir NovaSTEM :',
              style: police(policeTexte, taille: 15, couleur: p.texte)),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<Proposition>>(
          future: _liste,
          builder: (context, snap) {
            final l = snap.data ?? const <Proposition>[];
            // 1 proposition de chaque sorte par semaine (sauf administrateur) : moment où elle redevient possible.
            DateTime? prochaine(String genre) {
              if (etat.admin) return null;
              final dernieres = l.where((x) => x.genre == genre && x.cetteSemaine).map((x) => x.cree).toList()
                ..sort();
              return dernieres.isEmpty ? null : dernieres.last.add(const Duration(days: 7));
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _choix(Icons.bolt_rounded, logoEncreBleue, 'Proposer un sujet', 'Une phrase : on s’occupe du reste.',
                  const EcranProposerSujet(), prochaine: prochaine('sujet')),
              const SizedBox(height: 10),
              _choix(Icons.edit_rounded, _vert, 'Proposer un résumé', 'Ta fiche en 3 parties, vérifiée avant publication.',
                  const EcranProposerResume(), prochaine: prochaine('resume')),
              const SizedBox(height: 10),
              _choix(Icons.lightbulb_outline_rounded, _orange, 'Proposer une amélioration',
                  'Une idée, un bug, un souhait pour l’application.', const EcranProposerAmelioration(),
                  prochaine: prochaine('amelioration')),
            ]);
          },
        ),
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('MES PROPOSITIONS',
              style: police(policeTexte, taille: 12, graisse: FontWeight.w800, couleur: p.texteDiscret)),
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<Proposition>>(
          future: _liste,
          builder: (context, s) {
            if (s.connectionState != ConnectionState.done) {
              return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
            }
            if (s.hasError) {
              return Text('Impossible de charger tes propositions (réseau ?). Tire vers le bas pour réessayer.',
                  style: police(policeTexte, taille: 13.5, couleur: p.texteDiscret));
            }
            final l = s.data ?? [];
            if (l.isEmpty) {
              return Text('Aucune proposition pour l’instant.',
                  style: police(policeTexte, taille: 13.5, couleur: p.texteDiscret));
            }
            return Column(children: [
              for (final x in l)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: p.carte,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _detail(x),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(
                              child: Text(x.texte,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: police(policeTexte, taille: 14, graisse: FontWeight.w700, couleur: p.texte)),
                            ),
                            const SizedBox(width: 8),
                            Pastille(_etat(x.statut).$1, _etat(x.statut).$2),
                          ]),
                          const SizedBox(height: 4),
                          Text('${_genre(x)} · ${_date(x.cree)}',
                              style: police(policeTexte, taille: 12, couleur: p.texteDiscret)),
                        ]),
                      ),
                    ),
                  ),
                ),
            ]);
          },
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ éléments de formulaire

class _Formulaire extends StatelessWidget {
  final String titre;
  final List<Widget> enfants;
  final String bouton;
  final Color couleur;
  final Color couleurTexte;
  final bool pret;
  final bool envoi;
  final VoidCallback onEnvoyer;
  const _Formulaire({
    required this.titre, required this.enfants, required this.bouton, required this.pret, required this.envoi,
    required this.onEnvoyer, this.couleur = logoEncreBleue, this.couleurTexte = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    return Scaffold(
      backgroundColor: p.fond,
      appBar: AppBar(
        backgroundColor: p.fond,
        surfaceTintColor: Colors.transparent,
        foregroundColor: p.texte,
        title: Text(titre, style: police(policeTitres, taille: 22, graisse: FontWeight.w800, couleur: p.texte)),
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 20), children: enfants),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: couleur,
                    foregroundColor: couleurTexte,
                    disabledBackgroundColor: p.pastille,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26))),
                onPressed: pret && !envoi ? onEnvoyer : null,
                child: envoi
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : Text(bouton, style: police(policeTexte, taille: 16, graisse: FontWeight.w800)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

Widget _etiquette(BuildContext context, String t, [String detail = '']) {
  final p = palette(context);
  return Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 7),
    child: Row(children: [
      Expanded(
          child: Text(t, style: police(policeTexte, taille: 12, graisse: FontWeight.w800, couleur: p.texteDiscret))),
      Text(detail, style: police(policeTexte, taille: 11.5, couleur: p.texteDiscret)),
    ]),
  );
}

Widget _aide(BuildContext context, String t, {Color? couleur}) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(t, style: police(policeTexte, taille: 12, couleur: couleur ?? palette(context).texteDiscret)),
    );

Widget _champ(BuildContext context, TextEditingController c,
    {String indice = '', int lignes = 1, int? max, TextInputType? clavier}) {
  final p = palette(context);
  return TextField(
    controller: c,
    minLines: lignes,
    maxLines: lignes == 1 ? 1 : lignes + 4,
    maxLength: max,
    keyboardType: clavier,
    textCapitalization: clavier == TextInputType.url ? TextCapitalization.none : TextCapitalization.sentences,
    style: police(policeTexte, taille: 15, couleur: p.texte),
    decoration: InputDecoration(
      hintText: indice,
      hintStyle: police(policeTexte, taille: 15, couleur: p.texteDiscret),
      counterText: '',
      filled: true,
      fillColor: p.carte,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.bordure)),
      enabledBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.bordure)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: logoEncreBleue, width: 1.6)),
    ),
  );
}

/// Choix exclusif sous forme de boutons (fil, quand…).
Widget _segments(BuildContext context, List<(String, String)> options, String actif, ValueChanged<String> choisir) {
  final p = palette(context);
  return Row(children: [
    for (final (i, (cle, nom)) in options.indexed) ...[
      if (i > 0) const SizedBox(width: 6),
      Expanded(
        child: GestureDetector(
          onTap: () => choisir(cle),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cle == actif ? p.encre : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cle == actif ? p.encre : p.bordure, width: 1.5),
            ),
            child: Text(nom,
                style: police(policeTexte,
                    taille: 13, graisse: FontWeight.w800, couleur: cle == actif ? p.surEncre : p.texteDiscret)),
          ),
        ),
      ),
    ],
  ]);
}

/// Compteur de mots d'un titre ou d'un sujet : de 3 à 12 mots (comme les titres de l'agent).
const int _motsMin = 3;
Widget _compteurMots(BuildContext context, String texte) {
  final n = compterMots(texte);
  if (n == 0) return _aide(context, 'Entre $_motsMin et $_motsMax mots');
  if (n < _motsMin) {
    return _aide(context, '$n mot${n > 1 ? 's' : ''} : trop court ($_motsMin mots au moins)', couleur: _orange);
  }
  if (n > _motsMax) return _aide(context, '$n mots : trop long ($_motsMax mots au plus)', couleur: _orange);
  return _aide(context, '✓ $n mots (entre $_motsMin et $_motsMax)', couleur: _vert);
}

/// Lien de vidéo accepté : YouTube (y compris Shorts), Vimeo ou Dailymotion.
bool _videoValide(String l) =>
    _lienValide(l) &&
    RegExp(r'(youtube\.com/(watch|shorts|live)|youtu\.be/|vimeo\.com/|dailymotion\.com/video/|dai\.ly/)')
        .hasMatch(l.trim());

/// Champ « Lien d'une vidéo » (facultatif), commun aux sujets et aux résumés.
List<Widget> _champVideo(BuildContext context, TextEditingController c) {
  final mauvais = c.text.trim().isNotEmpty && !_videoValide(c.text);
  return [
    _etiquette(context, 'LIEN D’UNE VIDÉO', 'facultatif'),
    _champ(context, c, indice: 'https://youtube.com/…', clavier: TextInputType.url, max: 300),
    _aide(
        context,
        mauvais
            ? 'Lien YouTube, Vimeo ou Dailymotion seulement.'
            : 'Une vidéo courte qui montre l’avancée (essai, démonstration, lancement…).',
        couleur: mauvais ? _orange : null),
  ];
}

bool _lienValide(String l) {
  final u = Uri.tryParse(l.trim());
  return u != null && (u.scheme == 'https' || u.scheme == 'http') && u.host.contains('.');
}

Future<void> _envoyer(BuildContext context, Map<String, dynamic> champs, void Function(bool) attente,
    {Proposition? modifier}) async {
  attente(true);
  try {
    if (modifier != null) {
      if (!await modifierProposition(modifier.id, champs)) {
        attente(false);
        if (context.mounted) {
          afficherMessage(context, 'Elle est déjà en cours d’examen : on ne peut plus la modifier.',
              icone: Icons.lock_clock_outlined);
        }
        return;
      }
    } else {
      await envoyerProposition(champs);
    }
    if (context.mounted) Navigator.of(context).pop(true);
  } catch (e) {
    attente(false);
    if (context.mounted) {
      afficherMessage(
          context,
          e.toString().contains('limite_semaine') || e.toString().contains('trop de propositions')
              ? 'Tu as déjà fait cette sorte de proposition cette semaine (1 par semaine).'
              : 'Envoi impossible. Vérifie ta connexion et réessaie.',
          icone: Icons.error_outline_rounded);
    }
  }
}

// ------------------------------------------------------------------ proposer un sujet

class EcranProposerSujet extends StatefulWidget {
  /// Proposition à modifier (pas encore examinée), ou null pour une nouvelle.
  final Proposition? initiale;
  const EcranProposerSujet({super.key, this.initiale});
  @override
  State<EcranProposerSujet> createState() => _EcranProposerSujetState();
}

class _EcranProposerSujetState extends State<EcranProposerSujet> {
  final _sujet = TextEditingController();
  final _lien = TextEditingController();
  final _video = TextEditingController();
  final _direct = TextEditingController();
  String _fil = 'science';
  String? _type;
  String _quand = 'jour';
  DateTime? _date;
  bool _envoi = false;

  static const _types = [
    ('lancement', '🚀 Lancement'), ('ciel', '🔭 Dans le ciel'), ('sortie', '📦 Sortie'),
    ('presentation', '🎤 Présentation'), ('sommet', '🏛 Sommet'), ('resultats', '📊 Résultats'), ('autre', 'Autre'),
  ];

  @override
  void initState() {
    super.initState();
    final i = widget.initiale;
    if (i != null) {
      _sujet.text = i.sujet ?? '';
      _lien.text = i.lien ?? '';
      _video.text = i.video ?? '';
      _direct.text = i.direct ?? '';
      _fil = i.fil ?? 'science';
      _type = i.typeEvt;
      _quand = i.quandPrecision ?? 'jour';
      _date = DateTime.tryParse(i.quand ?? '');
    }
    for (final c in [_sujet, _lien, _video, _direct]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _sujet.dispose();
    _lien.dispose();
    _video.dispose();
    _direct.dispose();
    super.dispose();
  }

  bool get _pret {
    final n = compterMots(_sujet.text);
    if (n < _motsMin || n > _motsMax) return false;
    if (_lien.text.trim().isNotEmpty && !_lienValide(_lien.text)) return false;
    if (_video.text.trim().isNotEmpty && !_videoValide(_video.text)) return false;
    if (_fil == 'a_venir' && _direct.text.trim().isNotEmpty && !_lienValide(_direct.text)) return false;
    if (_fil == 'a_venir') return _type != null && (_quand == 'inconnue' || _date != null);
    return true;
  }

  Future<void> _choisirDate() async {
    final maintenant = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date ?? maintenant.add(const Duration(days: 7)),
      firstDate: maintenant,
      lastDate: DateTime(maintenant.year + 5),
      initialDatePickerMode: _quand == 'mois' ? DatePickerMode.year : DatePickerMode.day,
    );
    if (d != null) setState(() => _date = d);
  }

  String _texteDate() {
    if (_date == null) return 'Choisir la date';
    const mois = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre',
      'novembre', 'décembre'];
    return _quand == 'mois' ? '${mois[_date!.month - 1]} ${_date!.year}' : '${_date!.day} ${mois[_date!.month - 1]} ${_date!.year}';
  }

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final evenement = _fil == 'a_venir';
    return _Formulaire(
      titre: widget.initiale != null ? 'Modifier le sujet' : 'Proposer un sujet',
      bouton: widget.initiale != null ? 'Enregistrer' : (evenement ? 'Proposer l’événement' : 'Envoyer le sujet'),
      pret: _pret,
      envoi: _envoi,
      onEnvoyer: () => _envoyer(
          context,
          {
            'genre': 'sujet',
            'sujet': _sujet.text.trim(),
            'fil': _fil,
            if (_lien.text.trim().isNotEmpty) 'lien': _lien.text.trim(),
            if (_video.text.trim().isNotEmpty) 'video': _video.text.trim(),
            if (evenement && _direct.text.trim().isNotEmpty) 'direct': _direct.text.trim(),
            if (evenement) 'type_evt': _type,
            if (evenement) 'quand_precision': _quand,
            if (evenement && _quand != 'inconnue' && _date != null)
              'quand': '${_date!.year}-${_date!.month.toString().padLeft(2, '0')}-'
                  '${(_quand == 'mois' ? 1 : _date!.day).toString().padLeft(2, '0')}',
          },
          (v) => setState(() => _envoi = v),
          modifier: widget.initiale),
      enfants: [
        _etiquette(context, 'C’EST POUR…'),
        _segments(context, const [('science', 'Sciences'), ('tech', 'Technologies'), ('a_venir', 'À venir')], _fil,
            (v) => setState(() => _fil = v)),
        _etiquette(context, evenement ? 'L’ÉVÉNEMENT' : 'LE SUJET'),
        _champ(context, _sujet,
            indice: evenement ? 'Lancement de la mission Artemis III' : 'SpaceX rattrape le Starship avec la tour',
            lignes: 2,
            max: 160),
        _compteurMots(context, _sujet.text),
        if (!evenement) _aide(context, 'Dis ce qui s’est passé, avec un nom si tu l’as (entreprise, labo, mission).'),
        if (evenement) ...[
          _etiquette(context, 'C’EST…'),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final (cle, nom) in _types)
              ChoiceChip(
                label: Text(nom),
                selected: _type == cle,
                onSelected: (_) => setState(() => _type = cle),
                labelStyle: police(policeTexte,
                    taille: 13, graisse: FontWeight.w700, couleur: _type == cle ? Colors.white : p.texteDiscret),
                selectedColor: logoEncreBleue,
                backgroundColor: p.carte,
                showCheckmark: false,
                side: BorderSide(color: _type == cle ? logoEncreBleue : p.bordure),
              ),
          ]),
          _etiquette(context, 'QUAND ?'),
          _segments(context, const [('jour', 'Jour précis'), ('mois', 'Mois'), ('inconnue', 'Je ne sais pas')], _quand,
              (v) => setState(() => _quand = v)),
          if (_quand != 'inconnue') ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _choisirDate,
              icon: const Icon(Icons.event_rounded, size: 18),
              label: Text(_texteDate(), style: police(policeTexte, taille: 14.5, graisse: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                  foregroundColor: p.texte,
                  side: BorderSide(color: p.bordure),
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            ),
          ],
          _etiquette(context, 'LIEN DU DIRECT (LIVE)', 'facultatif'),
          _champ(context, _direct, indice: 'https://youtube.com/live/…', clavier: TextInputType.url, max: 300),
          _aide(
              context,
              _direct.text.trim().isNotEmpty && !_lienValide(_direct.text)
                  ? 'Ce lien ne semble pas valide (il doit commencer par https://).'
                  : 'La page où suivre l’événement en direct (YouTube, Twitch, site officiel…).',
              couleur: _direct.text.trim().isNotEmpty && !_lienValide(_direct.text) ? _orange : null),
        ],
        _etiquette(context, 'LIEN D’UN ARTICLE', 'facultatif'),
        _champ(context, _lien, indice: 'https://…', clavier: TextInputType.url, max: 600),
        _aide(
            context,
            _lien.text.trim().isNotEmpty && !_lienValide(_lien.text)
                ? 'Ce lien ne semble pas valide (il doit commencer par https://).'
                : evenement
                    ? 'La date sera vérifiée, puis le lieu et l’heure complétés.'
                    : 'Sans lien, des articles fiables sur le sujet seront cherchés.',
            couleur: _lien.text.trim().isNotEmpty && !_lienValide(_lien.text) ? _orange : null),
        ..._champVideo(context, _video),
      ],
    );
  }
}

// ------------------------------------------------------------------ proposer un résumé

class EcranProposerResume extends StatefulWidget {
  final Proposition? initiale;
  const EcranProposerResume({super.key, this.initiale});
  @override
  State<EcranProposerResume> createState() => _EcranProposerResumeState();
}

class _EcranProposerResumeState extends State<EcranProposerResume> {
  final _titre = TextEditingController();
  final _avant = TextEditingController();
  final _decouverte = TextEditingController();
  final _apres = TextEditingController();
  final _lien = TextEditingController();
  final _video = TextEditingController();
  String _fil = 'science';
  // Langue du texte : celle de l'app par défaut (traduit ensuite en français et en anglais).
  String _langue = etat.langue == 'fr' ? 'fr' : (etat.langue == 'en' ? 'en' : 'autre');
  bool _envoi = false;

  // Mêmes longueurs que les fiches de l'agent (redaction.py), en mots : (minimum, maximum).
  static const _bornesAvant = (8, 45), _bornesDecouverte = (15, 85), _bornesApres = (8, 50);

  List<TextEditingController> get _tous => [_titre, _avant, _decouverte, _apres, _lien, _video];

  @override
  void initState() {
    super.initState();
    final i = widget.initiale;
    if (i != null) {
      _titre.text = i.titre ?? '';
      _avant.text = i.avant ?? '';
      _decouverte.text = i.decouverte ?? '';
      _apres.text = i.apres ?? '';
      _lien.text = i.lien ?? '';
      _video.text = i.video ?? '';
      _fil = i.fil == 'tech' ? 'tech' : 'science';
      if (i.langue != null) _langue = i.langue!;
    }
    for (final c in _tous) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in _tous) {
      c.dispose();
    }
    super.dispose();
  }

  static bool _dans(TextEditingController c, (int, int) b) {
    final n = compterMots(c.text);
    return n >= b.$1 && n <= b.$2;
  }

  bool get _pret {
    final n = compterMots(_titre.text);
    return n >= _motsMin && n <= _motsMax && _dans(_avant, _bornesAvant) && _dans(_decouverte, _bornesDecouverte) &&
        _dans(_apres, _bornesApres) && _lienValide(_lien.text) &&
        (_video.text.trim().isEmpty || _videoValide(_video.text));
  }

  /// Jauge « pas trop court, pas trop long » sous chaque partie.
  Widget _jauge(TextEditingController c, (int, int) b, String conseilCourt) {
    final p = palette(context);
    final n = compterMots(c.text);
    final ok = n >= b.$1 && n <= b.$2;
    final couleur = n == 0 ? p.texteDiscret : (ok ? _vert : _orange);
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (n / b.$2).clamp(0, 1).toDouble(),
                minHeight: 4,
                backgroundColor: p.pastille,
                color: couleur,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('$n / ${b.$1}–${b.$2} mots',
              style: police(policeTexte, taille: 11.5, graisse: FontWeight.w700, couleur: couleur)),
        ]),
        if (n > 0 && n < b.$1) _aide(context, 'Trop court (${b.$1} mots au moins). $conseilCourt', couleur: _orange),
        if (n > b.$2) _aide(context, 'Trop long (${b.$2} mots au plus) : garde l’essentiel.', couleur: _orange),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tech = _fil == 'tech';
    return _Formulaire(
      titre: widget.initiale != null ? 'Modifier le résumé' : 'Proposer un résumé',
      bouton: widget.initiale != null ? 'Enregistrer' : 'Envoyer',
      couleur: _vert,
      pret: _pret,
      envoi: _envoi,
      onEnvoyer: () => _envoyer(
          context,
          {
            'genre': 'resume',
            'fil': _fil,
            'langue': _langue,
            'titre': _titre.text.trim(),
            'avant': _avant.text.trim(),
            'decouverte': _decouverte.text.trim(),
            'apres': _apres.text.trim(),
            'lien': _lien.text.trim(),
            if (_video.text.trim().isNotEmpty) 'video': _video.text.trim(),
          },
          (v) => setState(() => _envoi = v),
          modifier: widget.initiale),
      enfants: [
        _aide(context, 'Ton texte est publié tel quel : seuls les faits sont vérifiés avec l’article, '
            'et seul ce qui est faux ou exagéré est corrigé.'),
        _etiquette(context, 'J’ÉCRIS EN…'),
        _segments(context, const [('fr', 'Français'), ('en', 'English'), ('autre', 'Autre langue')], _langue,
            (v) => setState(() => _langue = v)),
        _aide(context, 'Ta fiche sera publiée en français et en anglais.'),
        _etiquette(context, 'C’EST POUR…'),
        _segments(context, const [('science', 'Sciences'), ('tech', 'Technologies')], _fil,
            (v) => setState(() => _fil = v)),
        _etiquette(context, 'TITRE'),
        _champ(context, _titre, indice: 'Batteries : une cellule au sodium se recharge en 6 minutes', lignes: 2, max: 160),
        _compteurMots(context, _titre.text),
        _aide(context, 'Thème, deux-points, puis ce qui a été trouvé.'),
        _etiquette(context, 'AVANT'),
        _champ(context, _avant, indice: 'Ce qu’on savait, et ce qui manquait encore…', lignes: 3, max: 600),
        _jauge(_avant, _bornesAvant, 'Dis ce qui posait problème.'),
        _etiquette(context, tech ? 'LA NOUVEAUTÉ' : 'LA DÉCOUVERTE'),
        _champ(context, _decouverte, indice: 'Qui, quoi, comment, avec un ou deux chiffres clés…', lignes: 4, max: 900),
        _jauge(_decouverte, _bornesDecouverte, 'Dis qui, quoi, et un chiffre clé.'),
        _etiquette(context, 'ET APRÈS ?'),
        _champ(context, _apres, indice: 'Ce que ça peut changer, et la limite principale…', lignes: 3, max: 600),
        _jauge(_apres, _bornesApres, 'Dis ce que ça change, et la limite.'),
        _etiquette(context, 'LIEN DE L’ARTICLE SOURCE', 'obligatoire'),
        _champ(context, _lien, indice: 'https://…', clavier: TextInputType.url, max: 600),
        _aide(context, 'C’est lui qui permet de vérifier chaque fait.'),
        ..._champVideo(context, _video),
      ],
    );
  }
}

// ------------------------------------------------------------------ proposer une amélioration

class EcranProposerAmelioration extends StatefulWidget {
  final Proposition? initiale;
  const EcranProposerAmelioration({super.key, this.initiale});
  @override
  State<EcranProposerAmelioration> createState() => _EcranProposerAmeliorationState();
}

class _EcranProposerAmeliorationState extends State<EcranProposerAmelioration> {
  final _texte = TextEditingController();
  String _categorie = 'idee';
  bool _infos = true;
  bool _envoi = false;

  @override
  void initState() {
    super.initState();
    final i = widget.initiale;
    if (i != null) {
      _texte.text = i.resume ?? i.sujet ?? '';
      _categorie = i.categorie ?? 'idee';
    }
    _texte.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _texte.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    String? infos;
    if (_infos) {
      try {
        infos = 'v$versionApp · ${await descriptionAppareil()}';
      } catch (_) {}
    }
    if (!mounted) return;
    final t = _texte.text.trim();
    await _envoyer(
        context,
        {
          'genre': 'amelioration',
          'categorie': _categorie,
          'sujet': t.length > 400 ? '${t.substring(0, 397)}…' : t,
          if (t.length > 400) 'resume': t,
          if (infos != null) 'infos': infos.length > 200 ? infos.substring(0, 200) : infos,
        },
        (v) => setState(() => _envoi = v),
        modifier: widget.initiale);
  }

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    return _Formulaire(
      titre: widget.initiale != null ? 'Modifier' : 'Une amélioration',
      bouton: widget.initiale != null ? 'Enregistrer' : 'Envoyer',
      couleur: _orange,
      couleurTexte: const Color(0xFF17161F),
      pret: _texte.text.trim().length >= 10,
      envoi: _envoi,
      onEnvoyer: _go,
      enfants: [
        _etiquette(context, 'C’EST…'),
        _segments(context, const [('idee', '💡 Une idée'), ('bug', '🐞 Un bug'), ('design', '🎨 Le design')], _categorie,
            (v) => setState(() => _categorie = v)),
        _etiquette(context, 'TA PROPOSITION'),
        _champ(context, _texte,
            indice: _categorie == 'bug'
                ? 'Ce qui ne marche pas, et ce que tu faisais à ce moment-là…'
                : 'Ce serait bien de pouvoir…',
            lignes: 5,
            max: 1500),
        const SizedBox(height: 10),
        CheckboxListTile(
          value: _infos,
          onChanged: (v) => setState(() => _infos = v ?? false),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: logoEncreBleue,
          title: Text('Joindre la version de l’app et le modèle du téléphone (aide pour les bugs)',
              style: police(policeTexte, taille: 13.5, couleur: p.texte)),
        ),
        _aide(context, 'Ta proposition arrive telle quelle à l’équipe (10 caractères au moins).'),
      ],
    );
  }
}


// ------------------------------------------------------------------ détail d'une proposition

/// Ce qui se passe après l'envoi : les étapes, ce qui a été envoyé, et le résultat.
class EcranMaProposition extends StatefulWidget {
  final Proposition proposition;
  const EcranMaProposition({super.key, required this.proposition});
  @override
  State<EcranMaProposition> createState() => _EcranMaPropositionState();
}

class _EcranMaPropositionState extends State<EcranMaProposition> {
  bool _ouverture = false;

  Future<void> _supprimer() async {
    final p = palette(context);
    if (x.statut == 'en_cours') {
      afficherMessage(context, 'Elle est en cours de vérification : réessaie dans quelques minutes.',
          icone: Icons.hourglass_bottom_rounded);
      return;
    }
    final oui = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.carte,
        title: Text('Supprimer cette proposition ?',
            style: police(policeTitres, taille: 19, graisse: FontWeight.w700, couleur: p.texte)),
        content: Text(
            x.statut == 'publiee'
                ? 'Elle disparaîtra de « Mes propositions ». La fiche publiée reste en ligne.'
                : x.statut == 'nouvelle'
                    ? 'Elle ne sera pas examinée.'
                    : 'Elle disparaîtra de « Mes propositions ».',
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
    if (oui != true) return;
    try {
      final ok = await supprimerProposition(x.id);
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop('supprimee');
      } else {
        afficherMessage(context, 'Suppression impossible pour l’instant.', icone: Icons.error_outline_rounded);
      }
    } catch (_) {
      if (mounted) afficherMessage(context, 'Suppression impossible (réseau ?)', icone: Icons.error_outline_rounded);
    }
  }

  Proposition get x => widget.proposition;

  void _voirMaFiche() =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => EcranApercuProposition(proposition: x)));

  Future<void> _modifier() async {
    final ecran = switch (x.genre) {
      'resume' => EcranProposerResume(initiale: x) as Widget,
      'amelioration' => EcranProposerAmelioration(initiale: x),
      _ => EcranProposerSujet(initiale: x),
    };
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => ecran));
    if (ok == true && mounted) Navigator.of(context).pop('modifiee');
  }
  bool get _amelioration => x.genre == 'amelioration';
  bool get _evenement => x.fil == 'a_venir';

  Future<void> _voirFiche() async {
    final id = x.ficheId;
    if (id == null) return;
    setState(() => _ouverture = true);
    try {
      final a = await chargerAvancee(id);
      if (!mounted) return;
      if (a == null) {
        afficherMessage(context, 'Fiche introuvable', icone: Icons.error_outline_rounded);
      } else {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => EcranDetailFil(liste: [a], depart: 0)));
      }
    } catch (_) {
      if (mounted) afficherMessage(context, 'Impossible d’ouvrir la fiche (réseau ?)', icone: Icons.error_outline_rounded);
    } finally {
      if (mounted) setState(() => _ouverture = false);
    }
  }

  /// Étapes : (titre, explication, état) avec état 0 = à venir, 1 = en cours, 2 = fait, 3 = refus.
  List<(String, String, int)> _etapes() {
    final s = x.statut;
    if (_amelioration) {
      return [
        ('Envoyée', 'Le ${_date(x.cree)}. Elle arrive telle quelle dans la boîte à idées de l’équipe.', 2),
        ('Lue par l’équipe', s == 'nouvelle' ? 'Pas encore lue.' : 'Ta proposition a été lue.', s == 'nouvelle' ? 1 : 2),
        (
          switch (s) { 'faite' => 'Faite', 'ignoree' => 'Pas retenue', 'a_faire' => 'Prévue', _ => 'Décision' },
          switch (s) {
            'faite' => 'C’est fait ! Elle sera dans une prochaine version de l’app.',
            'a_faire' => 'Elle est dans la liste des choses à faire.',
            'ignoree' => 'Elle n’est pas retenue pour l’instant. Merci quand même !',
            _ => 'À faire, faite ou pas retenue : tu le verras ici.',
          },
          switch (s) { 'faite' => 2, 'ignoree' => 3, 'a_faire' => 1, _ => 0 },
        ),
      ];
    }
    final verif = _evenement
        ? 'L’article est lu, la date est vérifiée, et l’événement ne doit pas déjà être dans « À venir ».'
        : x.genre == 'resume'
            ? 'Chaque fait de ton texte est comparé à l’article. Seul ce qui est faux ou exagéré est corrigé.'
            : 'Des articles fiables sont lus, on vérifie que c’est une vraie avancée et pas un doublon, puis la fiche est rédigée.';
    return [
      ('Envoyée', 'Le ${_date(x.cree)}.', 2),
      (
        'Vérification',
        s == 'nouvelle' ? 'En attente : elle sera examinée au prochain passage. $verif' : verif,
        s == 'nouvelle' || s == 'en_cours' ? 1 : 2,
      ),
      (
        s == 'refusee' ? 'Non publiée' : 'Publication',
        switch (s) {
          'publiee' => _evenement ? 'Ajoutée à l’onglet « À venir ».' : 'Publiée dans le fil, en français et en anglais.',
          'refusee' => 'Elle n’a pas été publiée. La raison est juste en dessous.',
          _ => 'Publiée dans le fil, ou une explication si elle ne peut pas l’être.',
        },
        switch (s) { 'publiee' => 2, 'refusee' => 3, _ => 0 },
      ),
    ];
  }

  Widget _etape(String titre, String detail, int e, bool derniere) {
    final p = palette(context);
    final c = switch (e) { 2 => _vert, 1 => _orange, 3 => _rouge, _ => p.bordure };
    final icone = switch (e) { 2 => Icons.check_rounded, 3 => Icons.close_rounded, 1 => Icons.more_horiz_rounded, _ => null };
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: e == 0 ? Colors.transparent : c.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: c, width: 2),
            ),
            child: icone == null ? null : Icon(icone, size: 15, color: c),
          ),
          if (!derniere) Expanded(child: Container(width: 2, color: p.bordure)),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 18, top: 2),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titre,
                  style: police(policeTexte,
                      taille: 15.5, graisse: FontWeight.w800, couleur: e == 0 ? p.texteDiscret : p.texte)),
              const SizedBox(height: 3),
              Text(detail, style: police(policeTexte, taille: 13.5, couleur: p.texteDiscret, hauteur: 1.4)),
            ]),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final (nom, couleur) = _etat(x.statut);
    final etapes = _etapes();
    final message = (x.message ?? '').trim();
    return Scaffold(
      backgroundColor: p.fond,
      appBar: AppBar(
        backgroundColor: p.fond,
        surfaceTintColor: Colors.transparent,
        foregroundColor: p.texte,
        title: Text('Ma proposition', style: police(policeTitres, taille: 22, graisse: FontWeight.w800, couleur: p.texte)),
        actions: [
          IconButton(
            tooltip: 'Supprimer',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _supprimer,
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 28), children: [
        Row(children: [
          Pastille(nom, couleur),
          const SizedBox(width: 8),
          Text(_genre(x), style: police(policeTexte, taille: 13, couleur: p.texteDiscret)),
        ]),
        const SizedBox(height: 10),
        Text(x.texte, style: police(policeTitres, taille: 20, graisse: FontWeight.w800, couleur: p.texte, hauteur: 1.25)),
        const SizedBox(height: 20),
        for (final (i, (t, d, e)) in etapes.indexed) _etape(t, d, e, i == etapes.length - 1),
        if (message.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (x.statut == 'refusee' ? _rouge : _vert).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(x.statut == 'refusee' ? 'POURQUOI ?' : 'DÉTAIL',
                  style: police(policeTexte,
                      taille: 11.5, graisse: FontWeight.w800, couleur: x.statut == 'refusee' ? _rouge : _vert)),
              const SizedBox(height: 4),
              Text(message, style: police(policeTexte, taille: 14.5, couleur: p.texte, hauteur: 1.45)),
            ]),
          ),
          const SizedBox(height: 14),
        ],
        if (x.statut == 'publiee' && x.ficheId != null && !_evenement)
          SizedBox(
            height: 50,
            child: FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: p.encre,
                  foregroundColor: p.surEncre,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
              onPressed: _ouverture ? null : _voirFiche,
              child: Text('Voir la fiche publiée', style: police(policeTexte, taille: 15.5, graisse: FontWeight.w800)),
            ),
          ),
        const SizedBox(height: 22),
        OutlinedButton.icon(
          onPressed: _voirMaFiche,
          icon: const Icon(Icons.article_outlined, size: 20),
          label: Text(_amelioration ? 'Voir ma proposition' : 'Voir ma fiche',
              style: police(policeTexte, taille: 15, graisse: FontWeight.w800)),
          style: OutlinedButton.styleFrom(
              foregroundColor: p.texte,
              side: BorderSide(color: p.bordure, width: 1.5),
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
        ),
        if (x.statut == 'nouvelle') ...[
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _modifier,
            icon: const Icon(Icons.edit_outlined, size: 20),
            label: Text('Modifier', style: police(policeTexte, taille: 15, graisse: FontWeight.w800)),
            style: FilledButton.styleFrom(
                backgroundColor: logoEncreBleue,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
          ),
          _aide(context, 'Tu peux la modifier tant qu’elle n’a pas été examinée.'),
        ],
        const SizedBox(height: 18),
        Center(
          child: TextButton.icon(
            onPressed: _supprimer,
            icon: const Icon(Icons.delete_outline_rounded, color: _rouge, size: 20),
            label: Text('Supprimer cette proposition',
                style: police(policeTexte, taille: 14.5, graisse: FontWeight.w700, couleur: _rouge)),
          ),
        ),
      ]),
    );
  }
}


// ------------------------------------------------------------------ « Voir ma fiche »

/// La proposition présentée comme une fiche (résumé, sujet, événement ou amélioration).
class EcranApercuProposition extends StatelessWidget {
  final Proposition proposition;
  const EcranApercuProposition({super.key, required this.proposition});

  static const _typesEvt = {
    'lancement': '🚀 Lancement', 'ciel': '🔭 Dans le ciel', 'sortie': '📦 Sortie', 'presentation': '🎤 Présentation',
    'sommet': '🏛 Sommet', 'resultats': '📊 Résultats', 'autre': '📅 Événement',
  };

  String _dateEvt(Proposition x) {
    final d = DateTime.tryParse(x.quand ?? '');
    if (x.quandPrecision == 'inconnue' || d == null) return 'Date à confirmer';
    const mois = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre',
      'novembre', 'décembre'];
    return x.quandPrecision == 'mois' ? '${mois[d.month - 1]} ${d.year}' : '${d.day} ${mois[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final x = proposition;
    final evenement = x.genre == 'sujet' && x.fil == 'a_venir';
    final amelio = x.genre == 'amelioration';
    final fil = switch (x.fil) { 'tech' => 'Technologies', 'a_venir' => 'À venir', 'science' => 'Sciences', _ => '' };

    Widget section(String titre, String? texte) => (texte ?? '').trim().isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titre, style: police(policeTitres, taille: 17, graisse: FontWeight.w800, couleur: p.texte)),
              const SizedBox(height: 6),
              Text(texte!.trim(), style: police(policeTexte, taille: 16, couleur: p.texte, hauteur: 1.55)),
            ]),
          );

    Widget lien(IconData icone, String nom, String? url) {
      final u = (url ?? '').trim();
      if (u.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: p.carte,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Icon(icone, color: p.texte),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(nom, style: police(policeTexte, taille: 15, graisse: FontWeight.w700, couleur: p.texte)),
                    Text(Uri.tryParse(u)?.host.replaceFirst('www.', '') ?? u,
                        style: police(policeTexte, taille: 12.5, couleur: p.texteDiscret)),
                  ]),
                ),
                Icon(Icons.open_in_new_rounded, size: 18, color: p.texteDiscret),
              ]),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: p.fond,
      appBar: AppBar(backgroundColor: p.fond, surfaceTintColor: Colors.transparent, foregroundColor: p.texte),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 30), children: [
        Wrap(spacing: 8, runSpacing: 6, children: [
          if (fil.isNotEmpty) Pastille(fil, logoEncreBleue),
          if (evenement) Pastille(_typesEvt[x.typeEvt] ?? '📅 Événement', _orange),
          if (amelio)
            Pastille(switch (x.categorie) { 'bug' => '🐞 Bug', 'design' => '🎨 Design', _ => '💡 Idée' }, _orange),
          Pastille(_genre(x), p.texteDiscret),
        ]),
        const SizedBox(height: 14),
        Text(
            amelio ? 'Ma proposition' : (x.titre ?? x.sujet ?? x.texte),
            style: police(policeTitres, taille: 26, graisse: FontWeight.w800, couleur: p.texte, hauteur: 1.2)),
        const SizedBox(height: 8),
        Text(
            evenement ? _dateEvt(x) : 'Proposée le ${_date(x.cree)}',
            style: police(policeTexte, taille: 14, graisse: evenement ? FontWeight.w800 : FontWeight.w500,
                couleur: evenement ? _orange : p.texteDiscret)),
        const SizedBox(height: 22),
        if (x.genre == 'resume') ...[
          section('Avant', x.avant),
          section(x.fil == 'tech' ? 'La nouveauté' : 'La découverte', x.decouverte),
          section('Et après ?', x.apres),
        ],
        if (amelio) section('Ce que je propose', x.resume ?? x.sujet),
        if (x.genre == 'sujet')
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(color: p.carte, borderRadius: BorderRadius.circular(16)),
            child: Text(
                evenement
                    ? 'Ce qui est prévu, pourquoi c’est important, le lieu et l’heure seront complétés à partir des articles.'
                    : 'Le résumé complet (avant, découverte, et après), le thème et la note d’importance seront rédigés à partir des articles.',
                style: police(policeTexte, taille: 14, couleur: p.texteDiscret, hauteur: 1.45)),
          ),
        lien(Icons.sensors_rounded, 'Suivre en direct', x.direct),
        lien(Icons.play_circle_outline_rounded, 'Voir la vidéo', x.video),
        lien(Icons.article_outlined, 'Lire l’article', x.lien),
      ]),
    );
  }
}
