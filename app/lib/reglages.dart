// =====================================================================
//  RÉGLAGES VISUELS DE NOVUM
// ---------------------------------------------------------------------
//  C'est LE fichier à modifier pour changer l'apparence de l'app :
//  couleurs, polices, noms et icônes des familles, textes affichés.
//
//  Comment le modifier depuis GitHub (sans rien installer) :
//    1. Ouvre ce fichier sur github.com, clique sur le crayon (Edit).
//    2. Change une valeur, par exemple une couleur 0xFFF0466B.
//    3. Clique sur « Commit changes ». L'app est recompilée toute seule
//       (onglet Actions) et la nouvelle version arrive en quelques minutes.
//
//  Les couleurs s'écrivent 0xFF suivi du code couleur habituel :
//    #F0466B  →  0xFFF0466B
// =====================================================================

import 'package:flutter/material.dart';

// ------------------------------- POLICES -------------------------------
// Noms des polices Google Fonts (https://fonts.google.com).
const String policeLogo = 'Fraunces';             // logo « NovaSTEM »
const String policeTitres = 'Bricolage Grotesque'; // titres des avancées
const String policeTexte = 'Figtree';             // tout le reste

// ------------------------------- LOGO ----------------------------------
const String logoSymbole = 'No';      // dans la case
const String logoSuite = 'va';        // collé à la case, même ligne de base
const String logoExposant = 'STEM';   // en exposant après « va » (Science, Technologie, Ingénierie, Maths)
const String nomApp = 'NovaSTEM';     // nom de l'application
const String logoNumero = '102';      // numéro atomique du nobélium
const Color logoEncreRose = Color(0xFFFF5A8A);
const Color logoEncreBleue = Color(0xFF3D7BFF);

// ---------------------------- COULEURS DU FOND --------------------------
class Palette {
  final Color fond, carte, texte, texteDiscret, bordure, pastille, encre, surEncre;
  const Palette({
    required this.fond, required this.carte, required this.texte,
    required this.texteDiscret, required this.bordure, required this.pastille,
    required this.encre, required this.surEncre,
  });
}

const paletteClaire = Palette(
  fond: Color(0xFFF2F1F6),         // fond de l'écran (gris lavande pâle)
  carte: Color(0xFFFFFFFF),        // cartes
  texte: Color(0xFF17161F),        // texte principal
  texteDiscret: Color(0xFF5E5C6B), // dates, sources…
  bordure: Color(0xFFDDDBE5),
  pastille: Color(0xFFE6E4EE),     // fond du sélecteur Sciences / Technologies
  encre: Color(0xFF17161F),        // onglet de période sélectionné
  surEncre: Color(0xFFFFFFFF),
);

const paletteSombre = Palette(
  fond: Color(0xFF0F0F14),
  carte: Color(0xFF1A1A22),
  texte: Color(0xFFF2F1F6),
  texteDiscret: Color(0xFFA9A8B6),
  bordure: Color(0xFF2C2C36),
  pastille: Color(0xFF2A2A35),
  encre: Color(0xFFF2F1F6),
  surEncre: Color(0xFF0F0F14),
);

// ------------------------------- FAMILLES ------------------------------
// Une famille = un nom, une couleur de tuile, la couleur de l'icône sur la
// tuile, la couleur du texte (thème clair / sombre) et une icône Material
// (liste : https://fonts.google.com/icons).
class Famille {
  final String nom;
  final Color couleur;
  final Color icone;
  final Color encreClaire;
  final Color encreSombre;
  final IconData symbole;
  const Famille(this.nom, this.couleur, this.icone, this.encreClaire, this.encreSombre, this.symbole);
}

// Le code à gauche (ex. 'space') vient de la base : ne pas le modifier.
const Map<String, Famille> familles = {
  // ------ Fil Sciences ------
  'space':       Famille('Espace', Color(0xFF5B4CF0), Colors.white, Color(0xFF4A3BD6), Color(0xFFB3AAFF), Icons.public),
  'environment': Famille('Environnement & climat', Color(0xFF12A37F), Colors.white, Color(0xFF0B7D61), Color(0xFF6EE2BE), Icons.eco),
  'health':      Famille('Santé & médecine', Color(0xFFF0466B), Colors.white, Color(0xFFC8264B), Color(0xFFFF9BB1), Icons.favorite),
  'technology':  Famille('Technologie & IA', Color(0xFF1E8FE0), Colors.white, Color(0xFF0F6FB3), Color(0xFF8CCBFF), Icons.memory),
  'physics':     Famille('Physique & chimie', Color(0xFFFF7A1A), Color(0xFF2A1300), Color(0xFFB85000), Color(0xFFFFB27A), Icons.science),
  'life':        Famille('Vivant', Color(0xFFF2C230), Color(0xFF2B2000), Color(0xFF8A6A00), Color(0xFFF7D86A), Icons.biotech),
  'earth':       Famille('Terre & histoire', Color(0xFFB5653A), Colors.white, Color(0xFF8E4E2B), Color(0xFFE8A57E), Icons.terrain),
  'other':       Famille('Autre', Color(0xFF6B6A7A), Colors.white, Color(0xFF4B4A58), Color(0xFFC9C8D4), Icons.more_horiz),
  // ------ Fil Technologies ------
  'mobile':      Famille('Smartphones & objets', Color(0xFF5B4CF0), Colors.white, Color(0xFF4A3BD6), Color(0xFFB3AAFF), Icons.smartphone),
  'computing':   Famille('Informatique & puces', Color(0xFF1E8FE0), Colors.white, Color(0xFF0F6FB3), Color(0xFF8CCBFF), Icons.memory),
  'ai_software': Famille('IA & logiciels', Color(0xFFF0466B), Colors.white, Color(0xFFC8264B), Color(0xFFFF9BB1), Icons.auto_awesome),
  'mobility':    Famille('Transports', Color(0xFFFF7A1A), Color(0xFF2A1300), Color(0xFFB85000), Color(0xFFFFB27A), Icons.directions_car),
  'aerospace':   Famille('Espace & aéronautique', Color(0xFF12A37F), Colors.white, Color(0xFF0B7D61), Color(0xFF6EE2BE), Icons.rocket_launch),
  'energy_home': Famille('Énergie & maison', Color(0xFFF2C230), Color(0xFF2B2000), Color(0xFF8A6A00), Color(0xFFF7D86A), Icons.bolt),
  'gaming':      Famille('Jeux vidéo & consoles', Color(0xFFC24CF0), Colors.white, Color(0xFF9A2BC4), Color(0xFFE2A8FF), Icons.sports_esports),
  'tech_other':  Famille('Autre', Color(0xFF6B6A7A), Colors.white, Color(0xFF4B4A58), Color(0xFFC9C8D4), Icons.more_horiz),
};

Famille familleDe(String code) => familles[code] ?? familles['other']!;

// Ordre d'affichage des familles de chaque fil (filtres, premier lancement).
const List<String> famillesSciences = [
  'space', 'environment', 'health', 'technology', 'physics', 'life', 'earth', 'other',
];
const List<String> famillesTech = [
  'mobile', 'computing', 'ai_software', 'mobility', 'aerospace', 'energy_home', 'gaming', 'tech_other',
];
List<String> famillesDuFil(String fil) => fil == 'tech' ? famillesTech : famillesSciences;

// ------------------------------- TEXTES --------------------------------
const String texteSciences = 'Sciences';
const String texteTechnologies = 'Technologies';
const List<String> motsImportance = ['', 'Mineur', 'Limité', 'Notable', 'Majeur', 'Rupture'];
const String texteLireArticle = 'Lire l’article';
const String texteMentionResume = 'Résumé généré par IA · l’article source fait foi'; // obligatoire (AI Act, art. 50)
const String texteVide = 'Pas encore d’avancée ici';
const String texteVideDetail = 'L’agent n’a encore rien publié dans ce fil.';
const String texteErreur = 'Pas de connexion';
const String texteErreurDetail = 'Impossible de charger les avancées. Vérifiez votre connexion, puis réessayez.';
const String texteReessayer = 'Réessayer';

// Onglets de période (cumulatifs) : libellé et nombre de jours couverts.
const List<(String, int)> periodes = [
  ('Aujourd’hui', 1),
  ('Cette semaine', 7),
  ('Ce mois-ci', 31),
  ('Cette année', 366),
];
const int periodeParDefaut = 1; // 0 = Aujourd'hui, 1 = Cette semaine…
const String texteTriRecent = 'Plus récent';
const String texteTriImportant = 'Plus important';
const String texteFiltres = 'Filtres';
const String texteAujourdhuiVide = 'Pas encore de découverte aujourd’hui';
const String texteAujourdhuiVideDetail =
    'Les chercheurs sont sans doute encore au labo. En attendant, les avancées de la semaine vous attendent.';
const String texteVoirSemaine = 'Voir cette semaine';

// Premier lancement
const String texteBienvenueTitre = 'Qu’est-ce qui vous passionne ?';
const String texteBienvenueDetail = 'Choisissez vos domaines. Vous pourrez les changer à tout moment.';

// Barre du bas
const String texteOngletActualites = 'Actualités';
const String texteOngletFavoris = 'Favoris';
const String texteOngletReglages = 'Réglages';

// Réglages
const String texteNosSources =
    'Les avancées viennent de sources scientifiques et technologiques reconnues. '
    'Elles sont sélectionnées et résumées par une intelligence artificielle ; l’article source fait foi.';
// Politique de confidentialité (pages publiées avec la version web)
const String lienConfidentialiteFr = 'https://jd136413-lab.github.io/Application-science/confidentialite.html';
const String lienConfidentialiteEn = 'https://jd136413-lab.github.io/Application-science/privacy.html';
const String lienContact = 'https://jd136413-lab.github.io/Application-science/contact.html';
const String texteVersion = 'NovaSTEM 1.0 · sans compte, vos choix restent sur ce téléphone';

// --------------------------- MISE EN PAGE ------------------------------
const double tailleTitreCarte = 19;   // taille des titres dans les cartes
const double arrondiCarte = 20;       // arrondi des cartes
