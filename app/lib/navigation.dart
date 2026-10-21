// Liens entre les notifications et les écrans de l'app.

import 'package:flutter/widgets.dart';

/// Navigateur principal (pour ouvrir un écran depuis une notification).
final navigateur = GlobalKey<NavigatorState>();

/// Contenu de la notification touchée : l'identifiant d'une avancée,
/// ou « [payloadFil]:science » / « [payloadFil]:tech » pour ouvrir un fil.
final demandeOuverture = ValueNotifier<String?>(null);
const String payloadFil = 'fil';

/// Fil à montrer (« science » ou « tech ») lors de la prochaine [demandeFilAujourdhui].
String? filDemande;

/// Incrémenté pour demander : onglet Actualités, période « Aujourd'hui ».
final demandeFilAujourdhui = ValueNotifier<int>(0);

/// Incrémenté quand on touche « Actualités » alors qu'on y est déjà : retour en haut du fil.
final demandeHautDuFil = ValueNotifier<int>(0);
