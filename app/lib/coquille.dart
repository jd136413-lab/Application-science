// Structure principale : les 3 onglets et la barre du bas
// (Actualités · Favoris · Réglages).

import 'package:flutter/material.dart';

import 'accueil.dart';
import 'ecran_reglages.dart';
import 'favoris.dart';
import 'reglages.dart';
import 'widgets.dart';

class Coquille extends StatefulWidget {
  const Coquille({super.key});

  @override
  State<Coquille> createState() => _CoquilleState();
}

class _CoquilleState extends State<Coquille> {
  int _onglet = 0;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    return Scaffold(
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
          onDestinationSelected: (i) => setState(() => _onglet = i),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.view_agenda_outlined),
                selectedIcon: Icon(Icons.view_agenda_rounded),
                label: texteOngletActualites),
            NavigationDestination(
                icon: Icon(Icons.bookmark_border_rounded),
                selectedIcon: Icon(Icons.bookmark_rounded),
                label: texteOngletFavoris),
            NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: texteOngletReglages),
          ],
        ),
      ),
    );
  }
}
