# Google Play — toutes les réponses pour Novum

Réponses prêtes à recopier dans la Play Console, dans l'ordre où Google les demande.
Les libellés exacts peuvent légèrement changer : en cas de doute, faire une capture et demander à Claude.

Liens utiles :
- Politique de confidentialité : https://jd136413-lab.github.io/Application-science/confidentialite.html
- Page de contact : https://jd136413-lab.github.io/Application-science/contact.html
- Textes de la fiche : `store/fiche-google-play.md` · Images : `store/icone-512.png`, `store/banniere-1024x500.png`, `store/captures/`

---

## 1. Créer l'application (bouton « Créer une application »)

| Champ | Réponse |
|---|---|
| Nom de l'application | `Novum : sciences et tech` |
| Langue par défaut | Français (France) – fr-FR |
| Application ou jeu | Application |
| Sans frais ou payante | Sans frais (⚠ définitif : une appli gratuite ne peut plus devenir payante ; un abonnement intégré reste possible plus tard) |
| Déclarations | Cocher « Règles du programme pour les développeurs » et « Lois des États-Unis en matière d'exportation » |

---

## 2. Contenu de l'application (menu « Contenu de l'application » / tableau de bord « Configurer votre application »)

### Règles de confidentialité
URL : `https://jd136413-lab.github.io/Application-science/confidentialite.html`

### Accès à l'application
« Toutes les fonctionnalités sont disponibles sans restrictions d'accès » (pas de compte, pas de mot de passe).

### Annonces
« Non, mon application ne contient pas d'annonces ».

### Classification du contenu (questionnaire IARC)
- Adresse e-mail : jd136413@gmail.com
- Catégorie : **Référence, actualités ou éducation**
- Violence, sexualité, langage grossier, substances contrôlées, jeux d'argent, horreur : **Non** partout
- Interaction entre utilisateurs / contenu généré par les utilisateurs : **Non**
- Partage de la position de l'utilisateur : **Non**
- Achats numériques : **Non**
- L'application est-elle un navigateur ou un moteur de recherche web : **Non**
- Résultat attendu : classification « Tout public » (PEGI 3 / 3+)

### Public cible et contenu
- Tranches d'âge : **13-15 ans, 16-17 ans, 18 ans et plus** (ne pas cocher les moins de 13 ans : sinon les règles « Familles », beaucoup plus strictes, s'appliquent)
- L'application peut-elle attirer involontairement les enfants : **Non**

### Applis d'actualités
Novum rassemble et résume des actualités scientifiques et technologiques (agrégateur d'actualités utilisant l'IA) : elle entre dans le champ des « applis d'actualités » de Google. Répondre **Oui** et remplir la déclaration :
- Nom de l'éditeur : Jupiter Dynamics (Maxime Faucogney)
- URL de contact (doit être la même que dans l'app : Réglages → Nous contacter) : `https://jd136413-lab.github.io/Application-science/contact.html`
- E-mail : jd136413@gmail.com
- Sources : chaque fiche indique sa source (nom du site ou de la revue) et sa date, avec un lien vers l'article d'origine.
- Contenu récent : oui (avancées de moins de 30 jours dans le fil, mises à jour 2 fois par jour).
- Contenu généré par IA : oui, résumés automatiques ; mention dans l'app et dans la fiche.
- Si une question ne correspond pas : faire une capture et demander à Claude.

### Sécurité des données
Question générale :
- « Votre application collecte-t-elle ou partage-t-elle des types de données utilisateur obligatoires ? » → **Oui** (des identifiants techniques, via Firebase et ML Kit de Google)
- « Toutes les données collectées sont-elles chiffrées en transit ? » → **Oui**
- « Proposez-vous aux utilisateurs un moyen de demander la suppression de leurs données ? » → **Non** (aucun compte ; les données techniques disparaissent à la désinstallation). Si Google l'impose, répondre Oui avec l'e-mail de contact.

Types de données à cocher (rien d'autre) :

| Catégorie Google | Type | Collecté | Partagé | Traitement éphémère | Obligatoire ou facultatif | Finalités |
|---|---|---|---|---|---|---|
| Identifiants de l'appareil ou autres | Identifiants de l'appareil ou autres | Oui | Non | Non | Obligatoire | Fonctionnement de l'application, Analyse (diagnostic technique) |
| Infos et performances de l'application | Diagnostics | Oui | Non | Non | Obligatoire | Analyse (diagnostic technique) |

Pourquoi : Firebase Cloud Messaging (notifications) utilise un identifiant d'installation qui ne permet pas d'identifier la personne ; ML Kit (traduction sur le téléphone) envoie à Google des informations techniques anonymes (modèle du téléphone, version, temps de traitement, erreurs) pour le diagnostic. Ces données vont à Google en tant que prestataire de service, ce qui ne compte pas comme un « partage » au sens de Google Play.
Non collectés : nom, e-mail, position, contacts, photos, historique de navigation, données de santé, données financières, messages.

### Applis gouvernementales
Non.

### Fonctionnalités financières
« Mon application ne propose aucune fonctionnalité financière ».

### Santé
« Mon application n'a pas de fonctionnalités liées à la santé » (elle relaie des actualités médicales, mais ne propose ni suivi ni conseil de santé).

### Identifiant publicitaire
« Non, mon application n'utilise pas l'identifiant publicitaire ».

---

## 3. Fiche principale du Play Store

- Nom, description courte, description complète : `store/fiche-google-play.md` (FR, puis ajouter la traduction anglaise : « Gérer les traductions » → Anglais)
- Icône 512 × 512 : `store/icone-512.png`
- Image de présentation 1024 × 500 : `store/banniere-1024x500.png`
- Captures d'écran du téléphone : les 6 fichiers de `store/captures/` (refaire les 1 et 2 si l'ancienne parenthèse du crédit apparaît encore)
- Catégorie : **Actualités et magazines** · Tags : Science, Technologie
- E-mail : jd136413@gmail.com · Site web : https://jd136413-lab.github.io/Application-science/ · Téléphone : laisser vide

---

## 4. Test fermé (obligatoire : 12 testeurs inscrits pendant 14 jours d'affilée)

1. Menu **Tester et publier** (ou « Tests ») → **Test fermé** → créer un canal (ou utiliser « Alpha »), nom : `Test fermé`.
2. **Pays/régions** : France (+ les pays de tes testeurs).
3. **Testeurs** : « Créer une liste d'adresses e-mail », nom `Testeurs Novum`, ajouter les adresses Gmail de **15 à 20 personnes** (marge si certains abandonnent). Ce doivent être les comptes Google utilisés sur leur téléphone Android.
4. **Créer une version** :
   - « Signature d'application par Google Play » : accepter **la clé générée par Google** (notre clé actuelle devient la « clé d'importation »).
   - Importer le fichier `.aab` : GitHub → Actions → « Compiler l'app » → l'exécution avec Google Play → en bas, « Artifacts » → `novum-google-play` (fichier zip à extraire : clic droit → « Extraire tout »).
   - Nom de la version : laisser celui proposé. Notes de version : « Première version de test de Novum. »
5. **Envoyer pour examen**. Google vérifie (quelques heures à quelques jours). Ensuite, copier le **lien d'inscription** (« Rejoindre sur le Web ») et l'envoyer aux testeurs.
6. Après 14 jours avec au moins 12 testeurs inscrits : tableau de bord → **Demander l'accès à la production** (questionnaire sur le test : Claude préparera les réponses).

---

## 5. Message pour les testeurs (à copier)

> Salut ! J'ai créé une application, **Novum**, qui rassemble chaque jour les avancées scientifiques et technologiques importantes (résumés courts, note d'importance, notifications sur mesure). Avant de la publier, Google m'oblige à la faire tester par au moins 12 personnes pendant 14 jours. Tu veux bien m'aider ? Il te faut un téléphone **Android**.
>
> 1. Ouvre ce lien avec le compte Google de ton téléphone : **[LIEN D'INSCRIPTION]**
> 2. Clique sur « Devenir testeur », puis sur le lien pour l'installer depuis le Play Store.
> 3. **Garde l'appli installée pendant au moins 14 jours** et ouvre-la de temps en temps (Google vérifie que les testeurs l'utilisent vraiment).
> 4. Ne quitte pas le programme de test, même si tu trouves un bug : écris-moi plutôt (jd136413@gmail.com ou ici).
>
> Merci beaucoup, ça m'aide énormément !
