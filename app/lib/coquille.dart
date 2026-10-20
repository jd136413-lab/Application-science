// Structure principale : les 3 onglets et la barre du bas
// (Actualités · Favoris · Réglages).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'accueil.dart';
import 'ecran_reglages.dart';
import 'favoris.dart';
import 'langues.dart';
import 'navigation.dart';
import 'reglages.dart';
import 'widgets.dart';

class Coquille extends StatefulWidget {
  const Coquille({super.key});

  @override
  State<Coquille> createState() => _CoquilleState();
}

class _CoquilleState extends State<Coquille> {
  // Gardé en mémoire (static) pour rester sur le même onglet quand on change de langue.
  static int _onglet = 0;

  @override
  void initState() {
    super.initState();
    demandeFilAujourdhui.addListener(_versActualites);
  }

  @override
  void dispose() {
    demandeFilAujourdhui.removeListener(_versActualites);
    super.dispose();
  }

  void _versActualites() => setState(() => _onglet = 0);

  /// Bouton retour du téléphone : depuis Favoris ou Réglages, on revient au fil ;
  /// depuis le fil, on demande confirmation avant de quitter.
  Future<void> _retour() async {
    if (_onglet != 0) {
      setState(() => _onglet = 0);
      return;
    }
    final p = palette(context);
    final quitter = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.carte,
        title: Text(tr(texteQuitterTitre),
            style: police(policeTitres, taille: 20, graisse: FontWeight.w700, couleur: p.texte)),
        content: Text(tr(texteQuitterMessage),
            style: police(policeTexte, taille: 15, couleur: p.texteDiscret)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr(texteAnnuler),
                style: police(policeTexte, taille: 15, graisse: FontWeight.w600, couleur: p.texteDiscret)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: p.texte, foregroundColor: p.fond),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr(texteQuitter), style: police(policeTexte, taille: 15, graisse: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (quitter == true) SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (aQuitte, _) {
        if (!aQuitte) _retour();
      },
      child: Scaffold(
      backgroundColor: p.fond,
      body: SafeArea(
        bottom: false,
        // IndexedStack garde chaque onglet en mémoire (position, filtres…).
        child: IndexedStack(index: _onglet, children: const [
          EcranAccueil(),
          EcranFavoris(),
          EcranReglages(),
        ]),
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: p.carte,
          indicatorColor: p.pastille,
          labelTextStyle: WidgetStateProperty.resolveWith((etats) => police(policeTexte,
              taille: 12,
              graisse: etats.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
              couleur: etats.contains(WidgetState.selected) ? p.texte : p.texteDiscret)),
          iconTheme: WidgetStateProperty.resolveWith((etats) =>
              IconThemeData(color: etats.contains(WidgetState.selected) ? p.texte : p.texteDiscret)),
        ),
        child: NavigationBar(
          height: 68,
          selectedIndex: _onglet,
          onDestinationSelected: (i) {
            if (i == 0 && _onglet == 0) demandeHautDuFil.value++; // déjà sur le fil : retour en haut
            setState(() => _onglet = i);
          },
          destinations: [
            NavigationDestination(
                icon: const Icon(Icons.view_agenda_outlined),
                selectedIcon: const Icon(Icons.view_agenda_rounded),
                label: tr(texteOngletActualites)),
            NavigationDestination(
                icon: const Icon(Icons.bookmark_border_rounded),
                selectedIcon: const Icon(Icons.bookmark_rounded),
                label: tr(texteOngletFavoris)),
            NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings_rounded),
                label: tr(texteOngletReglages)),
          ],
        ),
      ),
    ),
    );
  }
}
