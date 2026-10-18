// Écran principal : logo, sélecteur Sciences / Technologies, fil des avancées.

import 'package:flutter/material.dart';

import 'carte.dart';
import 'detail.dart';
import 'donnees.dart';
import 'modele.dart';
import 'reglages.dart';
import 'widgets.dart';

class EcranAccueil extends StatefulWidget {
  const EcranAccueil({super.key});

  @override
  State<EcranAccueil> createState() => _EcranAccueilState();
}

class _EcranAccueilState extends State<EcranAccueil> {
  String _fil = 'science';
  final Map<String, Future<List<Avancee>>> _chargements = {};

  Future<List<Avancee>> _charger({bool forcer = false}) {
    if (forcer || !_chargements.containsKey(_fil)) {
      _chargements[_fil] = chargerAvancees(_fil);
    }
    return _chargements[_fil]!;
  }

  Future<void> _rafraichir() async {
    final f = _charger(forcer: true);
    setState(() {});
    try {
      await f;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    return Scaffold(
      backgroundColor: p.fond,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
            child: Column(children: [
              const LogoNovum(),
              const SizedBox(height: 14),
              _SelecteurFil(fil: _fil, onChange: (f) => setState(() => _fil = f)),
            ]),
          ),
          Expanded(
            child: FutureBuilder<List<Avancee>>(
              future: _charger(),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return _Message(
                    icone: Icons.wifi_off_rounded,
                    titre: texteErreur,
                    detail: texteErreurDetail,
                    bouton: texteReessayer,
                    action: _rafraichir,
                  );
                }
                final liste = snap.data ?? [];
                return RefreshIndicator(
                  onRefresh: _rafraichir,
                  child: liste.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 120),
                          _Message(icone: Icons.auto_awesome, titre: texteVide, detail: texteVideDetail),
                        ])
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: liste.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) => CarteAvancee(
                            avancee: liste[i],
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => EcranDetail(avancee: liste[i])),
                            ),
                          ),
                        ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _SelecteurFil extends StatelessWidget {
  final String fil;
  final ValueChanged<String> onChange;
  const _SelecteurFil({required this.fil, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    Widget bouton(String code, String texte, IconData icone) {
      final actif = code == fil;
      return Expanded(
        child: Semantics(
          selected: actif,
          button: true,
          child: Material(
            color: actif ? p.carte : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onChange(code),
              child: SizedBox(
                height: 42,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(icone, size: 18, color: actif ? p.texte : p.texteDiscret),
                  const SizedBox(width: 8),
                  Text(texte,
                      style: police(policeTexte,
                          taille: 15, graisse: FontWeight.w700, couleur: actif ? p.texte : p.texteDiscret)),
                ]),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: p.pastille, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        bouton('science', texteSciences, Icons.science_outlined),
        const SizedBox(width: 4),
        bouton('tech', texteTechnologies, Icons.memory_outlined),
      ]),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String detail;
  final String? bouton;
  final VoidCallback? action;
  const _Message({required this.icone, required this.titre, required this.detail, this.bouton, this.action});

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(color: p.pastille, shape: BoxShape.circle),
            child: Icon(icone, size: 42, color: p.texteDiscret),
          ),
          const SizedBox(height: 16),
          Text(titre,
              textAlign: TextAlign.center,
              style: police(policeTitres, taille: 24, graisse: FontWeight.w800, couleur: p.texte)),
          const SizedBox(height: 8),
          Text(detail,
              textAlign: TextAlign.center,
              style: police(policeTexte, taille: 15, couleur: p.texteDiscret, hauteur: 1.5)),
          if (bouton != null) ...[
            const SizedBox(height: 18),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: p.encre, foregroundColor: p.surEncre, shape: const StadiumBorder()),
              onPressed: action,
              child: Text(bouton!),
            ),
          ],
        ]),
      ),
    );
  }
}
