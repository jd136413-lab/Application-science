// Onglet « Soumettre » (maquette 96, 17/11/2026). Visible seulement en mode administrateur
// pour l'instant (coquille.dart). Trois choix : proposer un sujet (Sciences, Technologies ou
// À venir), proposer un résumé, proposer une amélioration de l'application.
// Les sujets et résumés sont traités par le script agent/soumissions.py (séparé de l'agent) ;
// les améliorations arrivent telles quelles dans la boîte à idées (boite_idees.dart).

import 'package:flutter/material.dart';

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

  Widget _choix(IconData icone, Color c, String titre, String detail, Widget ecran) {
    final p = palette(context);
    return Material(
      color: p.carte,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _ouvrir(ecran),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: c.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
              child: Icon(icone, color: c, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titre, style: police(policeTitres, taille: 17, graisse: FontWeight.w800, couleur: p.texte)),
                const SizedBox(height: 2),
                Text(detail, style: police(policeTexte, taille: 13, couleur: p.texteDiscret)),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: p.texteDiscret),
          ]),
        ),
      ),
    );
  }

  void _detail(Proposition x) {
    final p = palette(context);
    final (nom, c) = _etat(x.statut);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.carte,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Pastille(nom, c),
              const SizedBox(width: 8),
              Text('${_genre(x)} · ${_date(x.cree)}',
                  style: police(policeTexte, taille: 12.5, couleur: p.texteDiscret)),
            ]),
            const SizedBox(height: 12),
            Text(x.texte, style: police(policeTitres, taille: 18, graisse: FontWeight.w700, couleur: p.texte)),
            const SizedBox(height: 10),
            Text(
                (x.message ?? '').isNotEmpty
                    ? x.message!
                    : x.statut == 'nouvelle'
                        ? 'Elle sera examinée au prochain passage.'
                        : '',
                style: police(policeTexte, taille: 14.5, couleur: p.texte, hauteur: 1.45)),
          ]),
        ),
      ),
    );
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
        _choix(Icons.bolt_rounded, logoEncreBleue, 'Proposer un sujet', 'Une phrase : on s’occupe du reste.',
            const EcranProposerSujet()),
        const SizedBox(height: 10),
        _choix(Icons.edit_rounded, _vert, 'Proposer un résumé', 'Ta fiche en 3 parties, vérifiée avant publication.',
            const EcranProposerResume()),
        const SizedBox(height: 10),
        _choix(Icons.lightbulb_outline_rounded, _orange, 'Proposer une amélioration',
            'Une idée, un bug, un souhait pour l’application.', const EcranProposerAmelioration()),
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

/// Compteur de mots d'un titre (12 au plus, comme l'agent).
Widget _compteurMots(BuildContext context, String texte) {
  final n = compterMots(texte);
  if (n == 0) return _aide(context, '$_motsMax mots au plus');
  return _aide(context, n <= _motsMax ? '✓ $n / $_motsMax mots' : '$n / $_motsMax mots : trop long',
      couleur: n <= _motsMax ? _vert : _orange);
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

Future<void> _envoyer(BuildContext context, Map<String, dynamic> champs, void Function(bool) attente) async {
  attente(true);
  try {
    await envoyerProposition(champs);
    if (context.mounted) Navigator.of(context).pop(true);
  } catch (e) {
    attente(false);
    if (context.mounted) {
      afficherMessage(
          context,
          e.toString().contains('trop de propositions')
              ? 'Limite atteinte : 15 propositions par jour.'
              : 'Envoi impossible. Vérifie ta connexion et réessaie.',
          icone: Icons.error_outline_rounded);
    }
  }
}

// ------------------------------------------------------------------ proposer un sujet

class EcranProposerSujet extends StatefulWidget {
  const EcranProposerSujet({super.key});
  @override
  State<EcranProposerSujet> createState() => _EcranProposerSujetState();
}

class _EcranProposerSujetState extends State<EcranProposerSujet> {
  final _sujet = TextEditingController();
  final _lien = TextEditingController();
  final _video = TextEditingController();
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
    _sujet.addListener(() => setState(() {}));
    _lien.addListener(() => setState(() {}));
    _video.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _sujet.dispose();
    _lien.dispose();
    _video.dispose();
    super.dispose();
  }

  bool get _pret {
    final n = compterMots(_sujet.text);
    if (n < 3 || n > _motsMax) return false;
    if (_lien.text.trim().isNotEmpty && !_lienValide(_lien.text)) return false;
    if (_video.text.trim().isNotEmpty && !_videoValide(_video.text)) return false;
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
      titre: 'Proposer un sujet',
      bouton: evenement ? 'Proposer l’événement' : 'Envoyer le sujet',
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
            if (evenement) 'type_evt': _type,
            if (evenement) 'quand_precision': _quand,
            if (evenement && _quand != 'inconnue' && _date != null)
              'quand': '${_date!.year}-${_date!.month.toString().padLeft(2, '0')}-'
                  '${(_quand == 'mois' ? 1 : _date!.day).toString().padLeft(2, '0')}',
          },
          (v) => setState(() => _envoi = v)),
      enfants: [
        _etiquette(context, 'C’EST POUR…'),
        _segments(context, const [('science', 'Sciences'), ('tech', 'Technologies'), ('a_venir', 'À venir')], _fil,
            (v) => setState(() => _fil = v)),
        _etiquette(context, evenement ? 'L’ÉVÉNEMENT' : 'LE SUJET', '12 mots au plus, comme un titre'),
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
  const EcranProposerResume({super.key});
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
    return n >= 3 && n <= _motsMax && _dans(_avant, _bornesAvant) && _dans(_decouverte, _bornesDecouverte) &&
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
        if (n > 0 && n < b.$1) _aide(context, conseilCourt, couleur: _orange),
        if (n > b.$2) _aide(context, 'Un peu long : garde l’essentiel.', couleur: _orange),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tech = _fil == 'tech';
    return _Formulaire(
      titre: 'Proposer un résumé',
      bouton: 'Envoyer',
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
          (v) => setState(() => _envoi = v)),
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
        _etiquette(context, 'TITRE', '12 mots au plus'),
        _champ(context, _titre, indice: 'Batteries : une cellule au sodium se recharge en 6 minutes', lignes: 2, max: 160),
        _compteurMots(context, _titre.text),
        _aide(context, 'Thème, deux-points, puis ce qui a été trouvé.'),
        _etiquette(context, 'AVANT', '1 à 2 phrases'),
        _champ(context, _avant, indice: 'Ce qu’on savait, et ce qui manquait encore…', lignes: 3, max: 600),
        _jauge(_avant, _bornesAvant, 'Encore un peu court : dis ce qui posait problème.'),
        _etiquette(context, tech ? 'LA NOUVEAUTÉ' : 'LA DÉCOUVERTE', '2 à 3 phrases'),
        _champ(context, _decouverte, indice: 'Qui, quoi, comment, avec un ou deux chiffres clés…', lignes: 4, max: 900),
        _jauge(_decouverte, _bornesDecouverte, 'Encore un peu court : dis qui, quoi, et un chiffre clé.'),
        _etiquette(context, 'ET APRÈS ?', '1 à 2 phrases'),
        _champ(context, _apres, indice: 'Ce que ça peut changer, et la limite principale…', lignes: 3, max: 600),
        _jauge(_apres, _bornesApres, 'Encore un peu court : ce que ça change, et la limite.'),
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
  const EcranProposerAmelioration({super.key});
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
        (v) => setState(() => _envoi = v));
  }

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    return _Formulaire(
      titre: 'Une amélioration',
      bouton: 'Envoyer',
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
        _aide(context, 'Ta proposition arrive telle quelle à l’équipe.'),
      ],
    );
  }
}
