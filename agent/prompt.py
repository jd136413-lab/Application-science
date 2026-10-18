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

Tu alimentes Novum, une application mobile gratuite en français avec DEUX fils :
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
- title : 10 mots maximum, clair, concret, sans point final ni clickbait.
- summary : 2 à 3 phrases en français simple.
  · Fiche Sciences : centrée sur la CONNAISSANCE nouvelle (ce que l'on sait désormais,
    comment on l'a établi, les limites : étude animale, simulation, résultat préliminaire…).
  · Fiche Technologies : centrée sur la CAPACITÉ nouvelle (ce que l'on peut désormais faire,
    les principales nouveautés et performances, le stade : prototype, démonstration,
    commercialisé ; date ou prix si l'article les donne). Ton factuel, jamais publicitaire.
  · Si "both" : les deux fiches ont chacune leur propre titre et leur propre résumé,
    orientés selon leur fil. Ne répète pas le même texte.
  · Ne présente jamais une promesse ou une hypothèse comme un résultat établi.
- theme (fiche Sciences) : une valeur parmi : {", ".join(THEMES)}.
- theme (fiche Technologies) : une valeur parmi : {", ".join(TECH_THEMES)}.
- importance : entier de 1 à 5, EXIGEANT (la plupart des fiches valent 2 ou 3) :
  · Sciences : 1 mineur ou très spécialisé ; 2 incrémental ; 3 solide et notable dans son
    domaine ; 4 majeur (première mondiale, impact potentiel sur beaucoup de personnes) ;
    5 rupture exceptionnelle (ex. traitement validé chez l'humain d'une maladie incurable).
    Solidité des preuves : essai chez l'humain > étude animale > cellules > simulation.
  · Technologies : 1 mise à jour mineure ; 2 simple nouvelle version ; 3 produit notable avec
    de vraies nouveautés ; 4 saut majeur ou nouvelle catégorie ; 5 moment historique
    (comme le premier iPhone).
  Méfie-toi des superlatifs (« révolutionnaire », « historique »…).

## D. Format de réponse (JSON, tous les champs toujours présents)
- decision : "science" | "tech" | "both" | "none" | "undetermined" | "duplicate"
- duplicate_of : titre déjà publié concerné, sinon ""
- explanation : UNE phrase courte en français qui justifie la décision
- science : la fiche Sciences si decision vaut "science" ou "both" ; sinon
  title="", summary="", theme="other", importance=1
- tech : la fiche Technologies si decision vaut "tech" ou "both" ; sinon
  title="", summary="", theme="tech_other", importance=1
"""

SYSTEM_PROMPT = CLASSIFICATION + "\n\n" + REGLES_APP


def _liste(sujets: list[str]) -> str:
    return "\n".join(f"- {t}" for t in sujets) if sujets else "(rien pour l'instant)"


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
Extrait : {article['text']}
"""
