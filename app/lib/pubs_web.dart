// Version web : pas de publicités ni d'achats.

import 'package:flutter/material.dart';

Future<void> demarrerPubs() async {}

class BlocPub extends StatelessWidget {
  final bool accueil;
  const BlocPub({super.key, this.accueil = false});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class PubListe extends StatelessWidget {
  final Widget carte;
  const PubListe({super.key, required this.carte});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class PubEvenement extends StatelessWidget {
  final Widget carte;
  const PubEvenement({super.key, required this.carte});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class BandeauPub extends StatelessWidget {
  const BandeauPub({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

final ValueNotifier<String?> prixSansPub = ValueNotifier(null);
bool get achatsDisponibles => false;
Future<bool> acheterSansPub() async => false;
Future<void> restaurerAchats() async {}
Future<bool> choixConfidentialiteDisponible() async => false;
Future<void> ouvrirChoixConfidentialite() async {}
