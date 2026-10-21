# =====================================================================
# CONSIGNES DONNÉES À CLAUDE
# ---------------------------------------------------------------------
# 1) classification.md : le document de Maxime qui définit une avancée
#    scientifique, une avancée technologique, et quand c'est les deux.
#    → Pour changer la façon de classer, c'est CE fichier qu'on modifie.
# 2) REGLES_APP ci-dessous : les règles propres à l'application (titres,
#    résumés, barèmes d'importance, format de réponse).
# =====================================================================

from pathlib import Path

# Thèmes du fil Sciences (famille calculée par la base)
THEMES = [
    "space", "astronomy", "environment", "climate", "technology", "ai",
    "robotics", "health", "medicine", "neuroscience", "genetics", "biology",
    "chemistry", "physics", "quantum", "materials", "energy", "ocean",
    "geology", "paleontology", "archaeology", "agriculture", "mathematics",
    "transportation", "other",
]

# Thèmes du fil Technologies
TECH_THEMES = [
    "smartphones", "wearables", "gadgets",          # Smartphones & objets
    "computers", "chips",                           # Informatique & puces
    "ai_products", "software", "cybersecurity",     # IA & logiciels
    "cars", "drones",                               # Transports
    "rockets", "aircraft", "satellites",            # Espace & aéronautique
    "batteries", "solar", "smart_home",             # Énergie & maison
    "consoles", "video_games", "vr",                # Jeux vidéo & consoles
    "tech_other",                                   # Autre
]

CLASSIFICATION = (Path(__file__).parent / "classification.md").read_text(encoding="utf-8")

REGLES_APP = f"""
# PARTIE XI — APPLICATION À L'APPLICATION « NOVUM » (prioritaire sur la partie VIII)

Tu alimentes NovaSTEM, une application mobile gratuite en français avec DEUX fils :
« Sciences » (avancées scientifiques) et « Technologies » (avancées technologiques).
Pour chaque article reçu, applique mentalement toute la procédure ci-dessus
(parties I à VII et IX), mais N'ÉCRIS PAS l'analyse détaillée de la partie VIII :
réponds uniquement avec l'objet JSON décrit plus bas.

## A. Décision
- "science" : seule une avancée scientifique substantielle → une fiche dans le fil Sciences.
- "tech" : seule une avancée technologique substantielle → une fiche dans le fil Technologies.
- "both" : deux avancées substantielles distinctes → DEUX fiches, une par fil.
- "none" : ni l'une ni l'autre → article écarté.
- "undetermined" : informations insuffisantes pour trancher → article écarté.
Quand il faut choisir une seule catégorie, prends celle du RÉSULTAT PRINCIPAL (partie IV).
Sois exigeant : en cas de doute sur l'existence d'une vraie avancée, choisis "none".

Toujours "none", quel que soit le sujet : projet ou mission seulement à venir, rumeur ou
fuite, promotion ou bon plan, test ou comparatif, guide d'achat, tutoriel, résultats
financiers, procès ou régulation, nomination, partenariat, financement, prix, événement,
vidéo ou article d'explication, synthèse de connaissances déjà établies, rétrospective,
portrait, entretien, opinion, sondage, galerie d'images, mise à jour mineure.

## B. Doublons
Réponds "duplicate" si le MÊME sujet (même découverte, même étude, même produit, même
annonce) figure déjà dans une des listes « Déjà publié », même formulé autrement ou vu
par une autre source. Deux études ou deux produits différents sur un même grand thème
ne sont PAS des doublons. Indique le titre concerné dans "duplicate_of".

## C. Rédaction des fiches (en français, ORIGINALES, jamais de copie du texte source)
- title : TOUJOURS sous la forme « Thème : phrase » (choix de Maxime, maquette 29 B).
  · Thème : 1 à 3 mots que tout le monde connaît, avec une majuscule (Douleur, Climat,
    Planètes, Trous noirs, Cancer, Robots, Puces, Archéologie, Smartphones…).
  · Puis « : » (avec une espace avant et après, comme en français).
  · Puis une vraie phrase au présent de l'indicatif : sujet + verbe conjugué + complément.
    Le verbe dit ce qui a été fait ou trouvé (repère, montre, mesure, fabrique, lance…).
  · Interdits : participe présent (« montrant », « permettant »…), titre sans verbe,
    superlatif ou promesse que l'étude ne montre pas (« révolutionne », « guérit »).
  · 12 mots au plus en tout (thème compris), sans point final, mots de tous les jours
    (« artères bouchées » plutôt que « athérosclérose »).
  · Exemples : « Planètes : Webb repère les traces de chocs géants » ;
    « Douleur : nos nerfs détectent la brûlure grâce à une protéine » ;
    « Robots : un robot vole puis plonge comme un macareux » ;
    « Climat : les forêts des Caraïbes se réchauffent et souffrent plus ».
- Écriture (maquette 33) : pour un lycéen curieux. Phrases courtes, mots de tous les
  jours, aucun sigle sans explication, des comparaisons concrètes. On simplifie les mots,
  jamais le résultat : les faits restent exacts. Ne présente jamais une promesse ou une
  hypothèse comme un résultat établi.
- avant : 1 à 2 phrases. Ce qu'on savait ou ce qui existait jusque-là (le contexte).
- decouverte : 2 à 3 phrases.
  · Fiche Sciences (« La découverte ») : la CONNAISSANCE nouvelle et comment on l'a établie.
  · Fiche Technologies (« La nouveauté ») : la CAPACITÉ nouvelle, ses principales
    nouveautés et performances. Ton factuel, jamais publicitaire.
  La 1re phrase doit se suffire à elle-même : elle sert de texte aux notifications.
- apres : 1 à 2 phrases (« Et après ? »). Ce que ça peut changer, et ce qu'il reste à
  prouver : limites (étude chez l'animal, simulation, petit échantillon…), stade
  (prototype, démonstration, en vente), date ou prix si l'article les donne.
- mots : 0 à 2 « mots à connaître », seulement pour des mots vraiment difficiles utilisés
  dans la fiche (avant, decouverte ou apres). Pour chacun : "mot" (avec une majuscule
  initiale, au singulier) et "definition" (une phrase simple de 25 mots au plus, sans
  reprendre le mot lui-même). Liste vide si aucun mot n'est difficile.
- type_etude : la nature de la preuve, UNE valeur.
  · Fiche Sciences : "essai_clinique" (traitement testé sur des volontaires), "humain"
    (autre étude chez l'humain), "animal", "cellules", "simulation" (modèle, calcul),
    "observation" (télescope, satellite, mesures de terrain en astronomie, climat…),
    "terrain" (fouilles, relevés sur le terrain), "donnees" (analyse de données existantes).
  · Fiche Technologies : "en_vente", "annonce" (présenté, pas encore en vente),
    "demonstration", "prototype", "mise_a_jour".
- Si "both" : les deux fiches ont chacune leur propre titre et leurs propres textes,
  orientés selon leur fil. Ne répète pas le même texte.
- theme (fiche Sciences) : une valeur parmi : {", ".join(THEMES)}.
- theme (fiche Technologies) : une valeur parmi : {", ".join(TECH_THEMES)}.
- importance : entier de 1 à 5, TRÈS EXIGEANT. Repères de fréquence (sur environ
  10 fiches publiées par jour, tous fils confondus) : la note 1 est la note NORMALE
  (environ 2 fiches sur 3) ; 2 ≈ 3 fiches par jour ; 3 = quelques fiches PAR SEMAINE ;
  4 = quelques fiches PAR MOIS ; 5 = quelques fiches PAR AN. En cas d'hésitation entre
  deux notes, prends la plus basse.
  · Sciences : 1 « Intéressant » : vraie avancée, mais incrémentale, très spécialisée ou
    préliminaire (cellules, simulation, petite étude) ; 2 « Notable » : un vrai pas en avant
    dans son domaine, résultat solide ; 3 « Important » : compte au-delà de son domaine
    (on en parlera largement), preuves solides ; 4 « Majeur » : première mondiale, impact
    potentiel sur beaucoup de personnes ; 5 « Rupture » : exceptionnel (ex. traitement
    validé chez l'humain d'une maladie jusqu'ici incurable).
    Solidité des preuves : essai chez l'humain > étude animale > cellules > simulation.
  · Technologies : 1 « Intéressant » : amélioration réelle mais limitée, nouvelle version,
    prototype de laboratoire ; 2 « Notable » : produit ou démonstration avec de vraies
    nouveautés mesurables ; 3 « Important » : avancée qui compte au-delà des passionnés
    (beaucoup d'utilisateurs concernés, nouveau record d'un secteur entier) ; 4 « Majeur » :
    saut majeur ou nouvelle catégorie de produits ; 5 « Rupture » : moment historique
    (comme le premier iPhone).
  Méfie-toi des superlatifs (« révolutionnaire », « historique »…).

## D. Format de réponse (JSON, tous les champs toujours présents)
- decision : "science" | "tech" | "both" | "none" | "undetermined" | "duplicate"
- duplicate_of : titre déjà publié concerné, sinon ""
- explanation : UNE phrase courte en français qui justifie la décision
- science : la fiche Sciences si decision vaut "science" ou "both" ; sinon
  title="", avant="", decouverte="", apres="", mots=[], type_etude="donnees",
  theme="other", importance=1
- tech : la fiche Technologies si decision vaut "tech" ou "both" ; sinon
  title="", avant="", decouverte="", apres="", mots=[], type_etude="mise_a_jour",
  theme="tech_other", importance=1
"""

SYSTEM_PROMPT = CLASSIFICATION + "\n\n" + REGLES_APP


def _liste(sujets: list[str]) -> str:
    return "\n".join(f"- {t}" for t in sujets) if sujets else "(rien pour l'instant)"


def _reprise(article: dict) -> str:
    """Indique si le même sujet est repris par d'autres sources (signal d'importance)."""
    autres = article.get("autres_sources") or []
    if not autres:
        return ""
    return f"Même sujet aussi repris par {len(autres)} autre(s) source(s) : {', '.join(autres[:8])}\n"


def build_user_message(article: dict, sujets_science: list[str], sujets_tech: list[str]) -> str:
    """Construit le message envoyé à Claude pour un article."""
    return f"""Déjà publié — fil Sciences (sujets récents) :
{_liste(sujets_science)}

Déjà publié — fil Technologies (sujets récents) :
{_liste(sujets_tech)}

Nouvel article :
Source : {article['source_name']}
Titre d'origine : {article['title']}
Date : {article['published_at'].strftime('%Y-%m-%d')}
{_reprise(article)}Extrait : {article['text']}
"""
