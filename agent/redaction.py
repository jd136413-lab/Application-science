# =====================================================================
# RÉDACTION DES FICHES — NovaSTEM (03/11/2026, demande de Maxime)
# ---------------------------------------------------------------------
# Le premier appel (main.py) DÉCIDE : avancée ou non, quel fil, quel
# thème, quelle importance, et écrit un premier jet. Ce second appel,
# seulement pour les fiches retenues (≈ 10 par jour), RÉÉCRIT le titre et
# les trois paragraphes avec une consigne courte et entièrement consacrée
# à la qualité d'écriture : une IA applique bien mieux des règles de
# rédaction quand elle n'a que ça à faire.
#
# Méthode imposée à Claude (dans l'ordre du JSON) : 1) relever les faits
# de l'article, 2) repérer ce qui est vraiment nouveau D'APRÈS l'article,
# 3) lister le jargon et décider comment le traiter, 4) écrire, 5) relire
# avec une liste de contrôle. Les étapes 1 à 3 et 5 ne sont pas publiées.
#
# Testé avec agent/tester_redaction.py (workflow « Tester la rédaction »).
# =====================================================================

import json
import os
import re

# Réflexion interne de Haiku avant d'écrire : « low » la limite (c'est elle qui coûte le
# plus : ~9 000 tokens de sortie par fiche en « medium », le réglage par défaut).
EFFORT = os.environ.get("REDACTION_EFFORT", "low")

TYPES_SCIENCE = ["essai_clinique", "humain", "animal", "cellules", "laboratoire", "simulation",
                 "observation", "terrain", "donnees"]
TYPES_TECH = ["en_vente", "annonce", "demonstration", "prototype", "mise_a_jour"]

CONSIGNE = """Tu es le rédacteur en chef de NovaSTEM, une application gratuite qui explique chaque jour les avancées scientifiques et technologiques à des lecteurs curieux mais non spécialistes (lycéens, adultes sans formation scientifique). Ta fiche doit être EXACTE, CLAIRE et UTILE. Un expert du domaine qui la lit ne doit trouver aucune erreur ; un lycéen doit tout comprendre du premier coup.

On te donne l'article source (seule base de faits autorisée), le fil (Sciences ou Technologies) et un premier jet écrit par un collègue. Le premier jet contient souvent des défauts : exagérations, jargon, titre vague. Ne le recopie pas : réécris la fiche à partir de l'ARTICLE.

# Méthode (remplis les champs du JSON dans cet ordre)

1. "faits" : 4 à 8 faits précis tirés de l'article (qui, quoi, combien, où, comment, limites), chacun en une ligne courte. Seulement ce que l'article dit.
2. "nouveaute" : en une phrase, ce qui est VRAIMENT nouveau selon l'article, et ce qui existait déjà avant. Si l'article dit « premier », « jamais », « record », note-le ici avec ses mots exacts ; sinon écris « l'article ne revendique pas de première ».
3. "jargon" : les mots techniques que tu risques d'employer, et pour chacun ce que tu en fais : « remplacé par … », « expliqué en quelques mots » ou « mot à connaître ».
4. "titres_candidats" : 3 titres différents qui respectent la formule du titre ; puis la fiche : "title" (le MEILLEUR des trois : le plus concret, le plus clair pour un passant, le plus exact), "avant", "decouverte", "apres", "mots", "type_etude".
5. "controle" : relis ta fiche avec la liste de contrôle ci-dessous et réponds honnêtement à chaque question. Si une réponse est mauvaise, CORRIGE la fiche avant de répondre (le contrôle décrit la fiche finale).

# Règles d'exactitude (les plus importantes)

- Chaque fait, chiffre, nom ou date vient de l'article. Rien d'inventé, rien de « connu par ailleurs ».
- JAMAIS d'affirmation absolue sur le passé que l'article ne fait pas lui-même : « personne n'avait jamais », « aucun … ne pouvait », « on ignorait », « pour la première fois », « une première mondiale », « jusqu'ici impossible ». Ces phrases sont souvent fausses (une étude plus ancienne avait déjà trouvé la même chose, un autre produit existait déjà). Si l'article ne le dit pas clairement, décris plutôt la limite connue : « on cherchait encore à confirmer… », « ces carburants restaient peu utilisés… », « les preuves étaient encore rares… ». Si l'article le dit, attribue-le : « selon les chercheurs, c'est la première fois… », « selon le constructeur… ».
- Les promesses d'une entreprise restent des promesses : « annoncé », « selon le constructeur ».
- Les bénéfices et les usages futurs (« pourrait permettre de… », « éviterait… ») viennent eux aussi de l'article. N'en déduis pas de nouveaux : un avantage que l'article ne cite pas est une invention.
- Toute comparaison dit par rapport à quoi : « 4 fois plus net que le signal de 2024 », jamais « 90 fois plus abondante » tout seul.
- Deux chiffres sur la même chose doivent être expliqués l'un par rapport à l'autre (« 37 patients en tout, dont 15 à la dose retenue »).
- Garde les mots EXACTS des catégories : « grand singe » n'est pas « singe », « bactérie » n'est pas « virus », « prototype » n'est pas « produit en vente », « simulation » n'est pas « expérience ».
- Les nuances restent : « chez la souris », « sur 15 patients », « en laboratoire », « pas encore relu par d'autres chercheurs ».
- Prix et sommes : donne aussi l'équivalent approximatif en euros, arrondi (1 $ ≈ 0,85 € ; 1 £ ≈ 1,15 € ; 1 yuan ≈ 0,12 € ; 100 yens ≈ 0,60 € ; 1 000 wons ≈ 0,60 € ; 1 franc suisse ≈ 1,05 €), par exemple « 76 800 yuans (environ 9 000 €) ».

# Règles de clarté

- Phrases courtes (25 mots au plus), une idée par phrase, mots de tous les jours.
- Chaque mot technique est soit REMPLACÉ par des mots simples, soit EXPLIQUÉ tout de suite en quelques mots (« un isolant topologique, un matériau isolant à l'intérieur mais conducteur en surface »), soit donné en « mot à connaître ». Au plus deux mots techniques dans toute la fiche. Si le sujet est très technique (physique quantique, chimie…), décris CE QU'ON A VU et À QUOI ÇA SERT plutôt que l'appareillage : un lecteur n'a pas besoin du nom de chaque composant.
- Les sigles sont écrits en entier ou expliqués à la première apparition. Mieux encore, supprime le nom d'une expérience, d'un instrument, d'un navire, d'une station ou d'un appareil inconnu du public (STAR, RHIC, LHC, RV Merlin, station Qomolangma) et dis ce que c'est : « un accélérateur de particules américain », « un navire de la marine », « une station de recherche à 4 300 mètres ».
- « avant » se comprend SEUL, sans avoir lu le titre : jamais « cette matière », « ce signal », « le même effet », « cette version » pour désigner une chose pas encore présentée. Nomme-la.
- Logique : n'écris « car », « donc », « ce qui » que si l'article établit ce lien de cause. « Elles pourraient être menacées, car elles n'avaient pas été décrites » est absurde.
- Pas de formule chimique (La3Ni2O7, CO2 est permis), pas de nom latin d'espèce ou de genre (Plasmodium malariae, Acropora, Porites) sauf s'il est indispensable, pas d'unité savante ou étrangère : convertis (80 K → -193 °C ; 491 mph → 790 km/h ; 5 GW → 5 milliards de watts, la consommation de plusieurs millions de foyers seulement si l'article le dit). Dis plutôt ce que c'est : « un matériau à base de nickel », « des coraux à croissance lente ».
- Le nom d'un chercheur n'est utile que s'il dirige l'équipe dont on parle ; pour une autre équipe, dis ce qu'elle est (« une équipe de la NASA »), pas « Steve Howell ».
- Noms communs en minuscule au milieu d'une phrase (« les nucléobases », jamais « les Nucléobases »), même si c'est un mot à connaître.
- Ne parle jamais de la publication ni de l'article (« publié dans… », « selon la revue… », « l'article ne précise pas… ») : parle des chercheurs et de ce qu'ils ont fait. Ne nomme ni le média ni la revue.
- Formules creuses interdites : « ouvre la voie », « ouvre de nouvelles perspectives », « pourrait révolutionner », « avancée majeure », « pas important », « change la donne », « nouvelle ère », « reste à confirmer » sans dire quoi.
- Ne répète pas le même chiffre ou la même idée dans deux paragraphes. Au plus 3 chiffres dans « decouverte » : garde les plus parlants.
- Pas de date relative (« mardi », « hier », « cette semaine », « récemment ») : la fiche sera lue plus tard. Donne la date (« le 3 novembre ») ou rien.
- Un français naturel, comme dans un bon journal : relis chaque phrase et corrige les tournures maladroites ou les traductions mot à mot de l'anglais.
- RESPECTE les longueurs : « avant » 2 phrases au plus, « decouverte » 3 phrases au plus, « apres » 2 phrases au plus. Si c'est trop long, coupe le détail le moins utile.

# Le titre

- Forme : « Thème : phrase ». Thème = 1 à 3 mots que tout le monde connaît, avec majuscule (Cancer, Espace, Climat, Voitures, Smartphones, Ordinateurs quantiques…). Puis « : » avec une espace avant et après. Puis une vraie phrase au présent : sujet + verbe conjugué + complément. 12 mots au plus en tout, sans point final.
- Il dit CONCRÈTEMENT ce qui a été vu, fait ou lancé, et si possible à quoi ça sert. Interdits car vides : « un phénomène », « une découverte », « une avancée », « un résultat », « quelque chose », « prévu par la théorie », « une nouvelle méthode » sans dire laquelle, et les adjectifs creux « prometteur », « innovant », « étonnant », « inédit ».
- Formule qui marche : « Thème : QUI ou QUOI + VERBE D'ACTION + RÉSULTAT CONCRET (chiffre, chose vue, record) ou À QUOI ÇA SERT ». Bons titres : « Cancer : des cellules modifiées font reculer la tumeur chez 10 malades sur 15 » ; « Archéologie : un bâtiment de 2 600 ans repéré sous terre sans creuser » ; « Cellules : comprimer le noyau aide à fabriquer des neurones » ; « Espace : un astéroïde contient les cinq "lettres" du code génétique » ; « Centres de calcul : la Chine alimente des serveurs d'IA sans étapes de conversion ».
- Le thème est le domaine que le lecteur reconnaît (Cancer, Espace, Voitures, Électricité…), pas « IA » quand le sujet est l'électricité d'un bâtiment.
- Quand le sujet est très technique, le titre dit à quoi sert la recherche plutôt que le nom de l'objet étudié. Exemple : « Ordinateurs quantiques : des physiciens observent un phénomène prévu par la théorie » (vide) → « Ordinateurs quantiques : une piste vers des calculs sans erreurs se confirme en laboratoire ».
- Test du passant : quelqu'un qui n'a jamais entendu parler du sujet comprend. Pas de nom propre inconnu du grand public (dis ce que c'est : « un nouveau médicament », « une IA de Google », « un constructeur chinois »), pas de jargon ni de sigle. Connus de tous et permis : Apple, Google, NASA, SpaceX, Mars, la Lune, Alzheimer, Covid, ordinateur quantique, IA, ADN, ARN, gène, vaccin, virus, robot, satellite, astéroïde, trou noir…
- Exact : pas de « guérit » pour un traitement qui fait reculer une tumeur, pas de « révolutionne ».

# Les trois paragraphes

- "avant" (1 à 2 phrases, 45 mots au plus) : le contexte et le PROBLÈME qui restait, vu du domaine : jamais l'historique ou les intentions d'une entreprise, jamais un détail qui contredit la nouveauté (« 6 000 exemplaires déjà en circulation » dans une fiche sur un lancement). Ce qu'on savait déjà ou ce qui existait, puis ce qui manquait.
  · Si l'article cite des résultats ou des produits antérieurs (autre étude, autre mission, autre météorite, modèle précédent), l'« avant » mentionne en quelques mots le plus utile d'entre eux pour situer EXACTEMENT ce qui est nouveau (un ou deux, pas une liste). Exemple : « Des météorites et des échantillons de l'astéroïde Bennu en contenaient déjà ; dans Ryugu, on n'en avait trouvé qu'une sur cinq. » Ne jamais écrire « on cherchait encore à savoir si… » quand l'article montre que c'était déjà connu ailleurs.
  · Pas d'affirmation absolue non soutenue par l'article (voir exactitude).
- "decouverte" (2 à 3 phrases, 85 mots au plus) — « La découverte » (Sciences) ou « La nouveauté » (Technologies) : QUI (« des chercheurs de l'université de Kyoto », « Samsung »), QUOI exactement, COMMENT, avec les 2 ou 3 chiffres clés. La 1re phrase se suffit à elle-même (elle sert aux notifications). Ton factuel, jamais publicitaire.
- "apres" (1 à 2 phrases, 50 mots au plus) — titre « Et après ? » déjà affiché, donc ne commence ni par « Et après » ni par une question. Il dit (a) CE QUE ÇA PEUT CHANGER concrètement et pour qui, et (b) la LIMITE principale ou la prochaine étape (petit essai, chez l'animal, prototype, prix, date de sortie, résultat pas encore relu). Une liste de prix seule n'est PAS un « Et après ».

# Les mots à connaître ("mots", 0 à 2)

- Le terme CLÉ du sujet qu'un lycéen ne connaît pas mais recroisera ailleurs (Supraconducteur, Exoplanète, Essai clinique, Mélanome, Immunothérapie, Nucléobase, Méthanol…). Écrit dans le texte (à l'accord près, en minuscule dans les phrases) ; ici avec une majuscule initiale et au singulier.
- Jamais un mot courant (cellule, gène, virus, planète, cancer, robot, batterie, cerveau…), un nom propre ou un sigle seul, ni un mot déjà expliqué dans le texte.
- "definition" : 12 à 25 mots, sans reprendre le mot : ce que c'est, puis à quoi ça sert ou une image concrète.
- Si le sujet contient du jargon que tu n'as ni remplacé ni expliqué, il DOIT être ici. Sinon, mieux vaut 0 mot que 1 mauvais.

# Le type d'étude ("type_etude", la nature de la preuve)

- Sciences : "essai_clinique" (traitement testé sur des volontaires) ; "humain" (autre étude chez l'humain) ; "animal" ; "cellules" ; "laboratoire" (expérience ou mesure en laboratoire sur des matériaux, des échantillons, des appareils : physique, chimie, analyse d'échantillons rapportés de l'espace…) ; "simulation" (modèle, calcul) ; "observation" (télescope, satellite, mesures dans la nature) ; "terrain" (fouilles, relevés sur le terrain) ; "donnees" (analyse statistique de données ou de dossiers existants).
- Technologies : "en_vente", "annonce" (présenté, pas encore en vente), "demonstration", "prototype", "mise_a_jour".

# Liste de contrôle ("controle", une réponse honnête par point)

- "faits_tous_dans_article" : chaque fait de la fiche est-il dans l'article ? (true/false)
- "affirmation_absolue_non_soutenue" : reste-t-il une affirmation absolue sur le passé que l'article ne fait pas ? (doit être false)
- "titre_concret" : le titre dit-il concrètement ce qui a été vu, fait ou lancé ? (doit être true)
- "jargon_non_explique" : liste des mots techniques ni remplacés, ni expliqués, ni en mot à connaître (doit être vide)
- "apres_dit_ce_que_ca_change_et_la_limite" : (doit être true)
- "chiffres_coherents" : (doit être true)
- "longueurs_respectees" : avant ≤ 2 phrases, decouverte ≤ 3, apres ≤ 2, titre ≤ 12 mots (doit être true)
- "avant_situe_les_resultats_anterieurs" : si l'article cite des résultats ou produits antérieurs, l'« avant » les mentionne-t-il ? (true s'il n'y en a pas)
- "note" : ta note sincère de la fiche de 1 à 10, avec la grille : 10 = parfaite pour le public ; 8 = très bonne, un détail ; 6 = correcte mais un vrai défaut ; 4 = défaut grave (erreur, titre vide ou jargon). Si ta note est sous 8, corrige d'abord la fiche.

# Exemples

BON (Sciences, essai clinique)
title : « Cancer de la peau : des cellules du patient font reculer la tumeur chez 10 malades sur 15 »
avant : « Quand un mélanome résiste à l'immunothérapie, il reste peu de solutions. La thérapie cellulaire existante impose une opération et de fortes doses d'un stimulant aux effets secondaires lourds. »
decouverte : « Des chercheurs ont modifié les cellules de défense prélevées dans la tumeur de chaque patient pour qu'elles fabriquent elles-mêmes un stimulant, activé seulement par un médicament à avaler. Sur les 15 patients traités à la bonne dose, la tumeur a reculé chez 10, et disparu chez 2. Aucun des 37 patients de l'essai n'est mort à cause du traitement. »
apres : « Cette méthode pourrait éviter les traitements les plus toxiques aux malades en échec. Mais les essais restent petits et un patient a eu un gonflement du cerveau : un essai plus large est en cours pour confirmer. »
mots : Mélanome → « Cancer qui naît dans les cellules qui colorent la peau ; c'est le cancer de la peau le plus dangereux. » ; Immunothérapie → « Traitement qui aide le système de défense du corps à reconnaître et détruire les cellules cancéreuses. »
type_etude : essai_clinique

BON (Sciences, sujet très technique : on décrit ce qu'on a vu et à quoi ça sert, pas l'appareillage)
title : « Ordinateurs quantiques : une piste pour des calculs sans erreurs passe un premier test »
avant : « Les ordinateurs quantiques se trompent souvent, car leurs données sont très fragiles. Depuis 2008, des théoriciens proposent de les protéger grâce à des états particuliers de la matière, encore mal observés dans un vrai circuit. »
decouverte : « Des physiciens de l'université de Cologne ont fabriqué un petit circuit où le courant passe sans perte à travers un matériau qui ne conduit l'électricité qu'en surface. En le mesurant, ils ont vu apparaître les états prévus par la théorie, au bon endroit et de la bonne manière, y compris sous l'effet d'un aimant. »
apres : « Si ces états protègent vraiment l'information, ils pourraient servir à construire des ordinateurs quantiques plus fiables. Il manque encore la preuve décisive, un changement d'énergie précis que l'équipe veut mesurer avec des instruments plus fins. »
mots : Supraconducteur → « Matériau qui conduit l'électricité sans aucune perte, en général seulement s'il est refroidi très fort. »
type_etude : laboratoire

BON (Technologies, produit mis en vente : faits du constructeur attribués, limite concrète, prix en euros)
title : « Voitures : une berline chinoise roule avec n'importe quel mélange de méthanol et d'essence »
avant : « Le méthanol, un alcool qui peut servir de carburant, reste rare dans les voitures des particuliers : il faut un moteur adapté et des stations pour faire le plein. »
decouverte : « Le constructeur chinois Geely a mis en vente la Xingyao 6 EF, une berline hybride qui roule au méthanol, à l'essence ou à l'électricité, avec n'importe quel mélange des deux carburants dans le même réservoir. Un capteur mesure ce mélange en temps réel pour régler le moteur. Selon Geely, ce moteur transforme 48 % de l'énergie du carburant en mouvement, un record pour un moteur au méthanol de série. »
apres : « Elle vise surtout les régions froides et les longs trajets, où les voitures électriques sont moins pratiques. Mais il faut trouver du méthanol : la Chine compte un peu plus de 1 400 stations, et le prix de départ, 76 800 yuans (environ 9 200 €), n'est qu'une promotion. »
mots : Méthanol → « Alcool liquide qui peut remplacer l'essence, seul ou mélangé à elle, dans un moteur prévu pour. »
type_etude : en_vente

MAUVAIS → POURQUOI
« Ordinateurs quantiques : des physiciens observent un phénomène prévu par la théorie » → titre vide (quel phénomène ?).
« On ignorait encore si ces molécules existaient dans l'espace. » → affirmation absolue que l'article ne fait pas (et souvent fausse).
« Aucune berline produite en série ne pouvait rouler au méthanol. » → idem ; écrire plutôt « Le méthanol reste un carburant rare pour les voitures particulières. »
« Ils ont observé des états d'Andreev répartis comme prévu. » → jargon non expliqué.
« Les prix vont de 76 800 à 96 800 yuans. » comme seul « Et après » → ne dit pas ce que ça change, et pas d'équivalent en euros.
« Les Nucléobases forment… » → majuscule fautive au milieu d'une phrase.
« Avant » qui raconte un autre projet sans rapport direct (un concurrent, l'histoire de l'entreprise) → le lecteur veut le problème que cette avancée règle.
« Le record appartient à Niels Herbrich. Le projet Kingchaser n'a atteint que 440 km/h. » → noms inconnus et détails sans intérêt. Mieux : « Faire voler très vite un petit avion télécommandé est difficile : il faut un moteur puissant dans un appareil léger et une longue piste pour accélérer. » (si l'article le dit).
« Les titres de plus de 12 mots » → compte les mots avant de répondre ; un titre trop long sera refusé.
« 11 de leurs 16 formes reconnues » puis « 11 des 13 espèces » → trois chiffres proches sur la même chose, sans lien : le lecteur s'y perd. Garde un seul compte, ou explique la différence.
« Batteries : des doigts de gel donnent 8 fois plus d'électricité par volume » → 8 fois plus QUE QUOI ? Écrire « … 8 fois plus qu'une électrode plate ».
Un « Et après » réduit à un espoir (« Cela pourrait donner des pistes pour les greffes. ») → il manque la limite : « il s'agit d'observations dans un seul lac » (si l'article le dit ou si c'est le cadre de l'étude).
« Ce sont des outils de base : l'étude ne porte ni sur un traitement, ni sur un test. » → BON réflexe : dire clairement ce que l'étude n'est PAS quand le lecteur pourrait le croire.

Réponds uniquement avec le JSON demandé."""


def schema(fil: str) -> dict:
    types = TYPES_SCIENCE if fil == "science" else TYPES_TECH
    return {
        "type": "object",
        "properties": {
            "faits": {"type": "array", "items": {"type": "string"}},
            "nouveaute": {"type": "string"},
            "jargon": {"type": "array", "items": {"type": "string"}},
            "titres_candidats": {"type": "array", "items": {"type": "string"}},
            "title": {"type": "string"},
            "avant": {"type": "string"},
            "decouverte": {"type": "string"},
            "apres": {"type": "string"},
            "mots": {"type": "array", "items": {
                "type": "object",
                "properties": {"mot": {"type": "string"}, "definition": {"type": "string"}},
                "required": ["mot", "definition"], "additionalProperties": False}},
            "type_etude": {"type": "string", "enum": types},
            "controle": {
                "type": "object",
                "properties": {
                    "faits_tous_dans_article": {"type": "boolean"},
                    "affirmation_absolue_non_soutenue": {"type": "boolean"},
                    "titre_concret": {"type": "boolean"},
                    "jargon_non_explique": {"type": "array", "items": {"type": "string"}},
                    "apres_dit_ce_que_ca_change_et_la_limite": {"type": "boolean"},
                    "chiffres_coherents": {"type": "boolean"},
                    "longueurs_respectees": {"type": "boolean"},
                    "avant_situe_les_resultats_anterieurs": {"type": "boolean"},
                    "note": {"type": "integer"},
                },
                "required": ["faits_tous_dans_article", "affirmation_absolue_non_soutenue", "titre_concret",
                             "jargon_non_explique", "apres_dit_ce_que_ca_change_et_la_limite",
                             "chiffres_coherents", "longueurs_respectees",
                             "avant_situe_les_resultats_anterieurs", "note"],
                "additionalProperties": False,
            },
        },
        "required": ["faits", "nouveaute", "jargon", "titres_candidats", "title", "avant", "decouverte", "apres", "mots",
                     "type_etude", "controle"],
        "additionalProperties": False,
    }


def _json(texte: str) -> dict:
    texte = (texte or "").strip()
    d, f = texte.find("{"), texte.rfind("}")
    try:
        return json.loads(texte[d:f + 1]) if 0 <= d < f else {}
    except json.JSONDecodeError:
        return {}


def message(art: dict, fil: str, brouillon: dict) -> str:
    jet = {k: brouillon.get(k) for k in ("title", "avant", "decouverte", "apres", "mots", "type_etude")}
    if os.environ.get("SANS_BROUILLON"):
        jet_txt = f"Premier jet : aucun (écris à partir de l'article). Titre d'un collègue, pour info : {brouillon.get('title', '')}\n\n"
    else:
        jet_txt = f"Premier jet (à améliorer, pas à recopier) :\n{json.dumps(jet, ensure_ascii=False)}\n\n"
    return (f"Fil : {'Sciences' if fil == 'science' else 'Technologies'}\n"
            f"Importance décidée (ne pas changer) : {brouillon.get('importance', 1)}/5\n\n"
            f"{jet_txt}"
            f"Article source — {art.get('source_name', '')} — titre d'origine : {art.get('title', '')}\n"
            f"{art.get('text', '')}")


def rediger(client, modele_id: str, art: dict, fil: str, brouillon: dict,
            essais: int = 3) -> tuple[dict | None, dict]:
    """Réécrit une fiche. Renvoie (fiche réécrite ou None, consommation de tokens).
    Ne lève jamais d'erreur : en cas de souci, l'appelant garde le premier jet.
    La raison d'un échec est dans conso["diag"]."""
    import time
    conso = {"in": 0, "out": 0, "cache_w": 0, "cache_r": 0, "diag": ""}
    for essai in range(essais):
        try:
            rep = client.messages.create(
                model=modele_id, max_tokens=16000,
                system=[{"type": "text", "text": CONSIGNE, "cache_control": {"type": "ephemeral"}}],
                messages=[{"role": "user", "content": message(art, fil, brouillon)}],
                output_config={"format": {"type": "json_schema", "schema": schema(fil)}, "effort": EFFORT},
            )
        except Exception as ex:
            conso["diag"] = f"{ex.__class__.__name__}: {str(ex)[:300]}"
            time.sleep(10 * (essai + 1))
            continue
        u = rep.usage
        conso["in"] += u.input_tokens or 0
        conso["out"] += u.output_tokens or 0
        conso["cache_w"] += getattr(u, "cache_creation_input_tokens", 0) or 0
        conso["cache_r"] += getattr(u, "cache_read_input_tokens", 0) or 0
        texte = "".join(b.text for b in rep.content if getattr(b, "type", "") == "text")
        d = _json(texte)
        if d.get("title") and d.get("decouverte"):
            d["title"] = " ".join(str(d["title"]).split()).rstrip(".")
            return d, conso
        conso["diag"] = f"arrêt={rep.stop_reason}, {len(texte)} caractères, début=« {texte[:120]} »"
    return None, conso


CONSIGNE_RELECTURE = """Tu es le relecteur le plus exigeant de NovaSTEM, une application qui explique les avancées scientifiques et technologiques à des lecteurs non spécialistes. Un rédacteur a écrit une fiche ; tu NE l'as PAS écrite et tu ne lui fais pas confiance. Compare-la phrase par phrase à l'article source, seule base de faits autorisée.

Cherche UNIQUEMENT ces défauts précis (un défaut = une ligne dans "problemes") :
1. "non_soutenu" : un fait, un chiffre, un bénéfice, un usage futur ou une comparaison qui n'est PAS dans l'article, ou qui le déforme (ex. « les malades pourraient éviter une opération » alors que la méthode demande toujours d'opérer).
2. "absolu" : « pour la première fois », « jamais », « aucun… ne pouvait », « on ignorait », « personne n'avait » que l'article ne dit pas, ou un contexte qui laisse croire que c'était inconnu alors que l'article cite des résultats antérieurs.
3. "titre" : titre vague (« un phénomène », « une nouvelle alimentation », « un nouveau système », « des états », « attendus »…), qui ne dit pas concrètement ce qui a été vu, fait ou lancé ; ou qui contient un nom propre inconnu du grand public (nom d'astéroïde, de mission, de produit, de molécule) ou un mot technique ; ou plus de 12 mots ; ou un thème (avant les deux-points) mal choisi.
4. "jargon" : une formule chimique, un nom latin d'espèce, une unité savante ou étrangère (K, mph, GW…) non convertie, ou un mot technique ou un sigle ni remplacé par des mots simples, ni expliqué juste après, ni donné en mot à connaître.
5. "comparaison" : un chiffre ou une comparaison incompréhensible sans référence (« 90 fois plus abondante » : que quoi ?), ou deux chiffres sur la même chose dont le lien n'est pas expliqué.
6. "apres" : le paragraphe « Et après » ne dit pas ce que ça peut changer, OU ne dit pas la limite principale ou la prochaine étape, OU n'est qu'une liste de prix.
7. "forme" : phrase qui parle de l'article, de la source ou de la publication (« l'article ne dit pas… », « selon la revue… ») au lieu des faits ; nom de personne inutile ou non présenté (« selon Travis Beals » sans dire qui c'est : écrire « selon un responsable du projet ») ; « avant » qui raconte l'histoire d'une entreprise au lieu du problème, phrase de plus de 30 mots, tournure maladroite ou traduite de l'anglais, date relative (« mardi », « hier »), majuscule fautive, « avant » de plus de 2 phrases, « decouverte » de plus de 3, « apres » de plus de 2.
8. "mot" : mot à connaître mal choisi (mot courant, nom propre, sigle, absent du texte, déjà expliqué dans le texte) ou définition qui reprend le mot ou reste vague.

Sois sévère mais juste : ne signale pas une préférence de style, seulement un vrai défaut de la liste.

Ce qui est PERMIS (ne le signale pas, ne le retire pas) :
- l'équivalent approximatif en euros d'un prix donné dans une autre monnaie (« 76 800 yuans, environ 9 000 € ») : c'est une règle de l'application ;
- dans la définition d'un mot à connaître, une connaissance générale exacte (« le mélanome est le cancer de la peau le plus dangereux ») ;
- une reformulation simple d'un terme technique, si elle reste exacte ;
- les mots connus de tous, qui ne sont PAS du jargon : ADN, ARN, gène, cellule, virus, vaccin, cancer, IA, robot, satellite, astéroïde, galaxie, trou noir, ordinateur quantique, batterie, électricité, protéine, molécule, neurone, laser, oxygène, carbone, volt.

Si tu retires de « apres » une limite non soutenue, remplace-la par une limite VRAIE tirée du cadre de l'étude (« chez la souris », « sur un seul site », « en laboratoire », « sur une seule année », « une démonstration, pas un produit ») : « apres » sans limite est un défaut.
Signale en "forme" un lien logique faux (« car », « donc » que l'article n'établit pas) et un « avant » qui désigne par « ce », « cette », « le même » une chose pas encore présentée.

Pour un titre vague, ne remplace pas un mot vague par un autre (« attendus » → « prévus par la théorie » ne change rien) : dis ce qui a été vu ou à quoi ça sert (« une piste vers des calculs sans erreurs se confirme »). Quand tu corriges le titre, le nouveau titre doit être PLUS concret que l'ancien (résultat chiffré, chose vue ou à quoi ça sert), jamais plus vague. Si tu ne trouves pas mieux, garde l'ancien.

Puis donne la fiche corrigée. CHAQUE défaut que tu as listé doit être corrigé dans la fiche corrigée (relis-la avant de répondre : un défaut listé mais encore présent est une faute grave). Donne la fiche corrigée : reprends la fiche telle quelle et corrige SEULEMENT les défauts trouvés, sans rien inventer (chaque correction s'appuie sur l'article). Règles de forme à garder : titre « Thème : phrase au présent », 12 mots au plus, sans point final ; avant 1-2 phrases ; decouverte 2-3 phrases ; apres 1-2 phrases, sans commencer par « Et après » ; noms communs en minuscule dans les phrases ; aucune mention de la publication, de la revue ou du média ; mots à connaître : 0 à 2, avec majuscule initiale, définition de 12 à 25 mots sans reprendre le mot. S'il n'y a aucun défaut, "problemes" est vide et la fiche corrigée est identique.

Réponds uniquement avec le JSON demandé."""

SCHEMA_RELECTURE = {
    "type": "object",
    "properties": {
        "problemes": {"type": "array", "items": {
            "type": "object",
            "properties": {
                "type": {"type": "string", "enum": ["non_soutenu", "absolu", "titre", "jargon", "comparaison",
                                                     "apres", "forme", "mot"]},
                "extrait": {"type": "string"},
                "explication": {"type": "string"},
            },
            "required": ["type", "extrait", "explication"], "additionalProperties": False}},
        "title": {"type": "string"},
        "avant": {"type": "string"},
        "decouverte": {"type": "string"},
        "apres": {"type": "string"},
        "mots": {"type": "array", "items": {
            "type": "object",
            "properties": {"mot": {"type": "string"}, "definition": {"type": "string"}},
            "required": ["mot", "definition"], "additionalProperties": False}},
    },
    "required": ["problemes", "title", "avant", "decouverte", "apres", "mots"],
    "additionalProperties": False,
}


def relire(client, modele_id: str, art: dict, fil: str, fiche: dict, essais: int = 3) -> tuple[dict | None, dict]:
    """Relecture critique par un second appel (03/11). Renvoie (fiche corrigée avec la
    liste « problemes », conso). En cas d'échec : (None, conso) et l'appelant garde la fiche."""
    import time
    conso = {"in": 0, "out": 0, "cache_w": 0, "cache_r": 0, "diag": ""}
    a_relire = {k: fiche.get(k) for k in ("title", "avant", "decouverte", "apres", "mots")}
    mesures = verifications(fiche)
    mesures_txt = ("Défauts MESURÉS automatiquement (certains : liste-les et corrige-les tous) :\n- "
                   + "\n- ".join(mesures) + "\n\n") if mesures else ""
    contenu = (f"Fil : {'Sciences' if fil == 'science' else 'Technologies'}\n\n"
               f"Fiche à relire :\n{json.dumps(a_relire, ensure_ascii=False)}\n\n{mesures_txt}"
               f"Article source — {art.get('source_name', '')} — titre d'origine : {art.get('title', '')}\n"
               f"{art.get('text', '')}")
    for essai in range(essais):
        try:
            rep = client.messages.create(
                model=modele_id, max_tokens=16000,
                system=[{"type": "text", "text": CONSIGNE_RELECTURE, "cache_control": {"type": "ephemeral"}}],
                messages=[{"role": "user", "content": contenu}],
                output_config={"format": {"type": "json_schema", "schema": SCHEMA_RELECTURE}, "effort": EFFORT},
            )
        except Exception as ex:
            conso["diag"] = f"{ex.__class__.__name__}: {str(ex)[:300]}"
            time.sleep(10 * (essai + 1))
            continue
        u = rep.usage
        conso["in"] += u.input_tokens or 0
        conso["out"] += u.output_tokens or 0
        conso["cache_w"] += getattr(u, "cache_creation_input_tokens", 0) or 0
        conso["cache_r"] += getattr(u, "cache_read_input_tokens", 0) or 0
        texte = "".join(b.text for b in rep.content if getattr(b, "type", "") == "text")
        d = _json(texte)
        if d.get("title") and d.get("decouverte"):
            d["title"] = " ".join(str(d["title"]).split()).rstrip(".")
            corrigee = dict(fiche)
            for k in ("title", "avant", "decouverte", "apres", "mots"):
                corrigee[k] = d.get(k, fiche.get(k))
            corrigee["problemes"] = d.get("problemes") or []
            return corrigee, conso
        conso["diag"] = f"arrêt={rep.stop_reason}, {len(texte)} caractères"
    return None, conso


# Filet de sécurité gratuit, après la réécriture : affirmations absolues restantes.
_ABSOLU = re.compile(r"\b(?:personne n'avait|aucun[e]? (?:\w+ ){0,3}ne (?:pouvai|savai|permettai)|on ignorait|"
                     r"jusqu'(?:ici|à présent) impossible|jamais (?:vu|observé|réalisé)|"
                     r"pour la première fois|première mondiale)", re.I)


def mots_titre(t: str) -> int:
    return len([w for w in re.split(r"\s+", (t or "").replace(" : ", " ")) if w.strip(":")])


def titre_valide(t: str) -> bool:
    t = " ".join((t or "").split())
    return " : " in t and 4 <= mots_titre(t) <= 13 and len(t) <= 110


def choisir_titre(fiche: dict, candidats: list[str]) -> None:
    """Filet gratuit : si le titre final est trop long ou mal formé, on prend le meilleur
    candidat valide proposé par le rédacteur (ils sont donnés du meilleur au moins bon)."""
    if titre_valide(fiche.get("title", "")):
        return
    for c in candidats or []:
        c = " ".join(str(c).split()).rstrip(".")
        if titre_valide(c):
            fiche["title"] = c
            return


_SIGLES_CONNUS = {"ADN", "ARN", "IA", "GPS", "NASA", "ESA", "CNRS", "UE", "ONU", "OMS", "CO2", "USB", "PC",
                  "TV", "SMS", "IRM", "VIH", "SIDA", "ARNm", "LED", "OK", "XXe", "XXIe", "km", "Wi-Fi", "5G", "4G",
                  "UV", "PDG", "CERN", "JO", "FBI", "BMW", "IBM", "AMD", "OLED", "SNCF", "EDF", "USA", "II", "III", "IV"}
_LIMITE = re.compile(r"\b(?:mais|reste|restent|encore|seulement|pour l'instant|pour le moment|uniquement|limite|"
                     r"prochaine étape|à vérifier|à confirmer|à tester|à mesurer|ne \w+ que|n'\w+ que|pas encore|"
                     r"chez la souris|chez l'animal|en laboratoire|une seule|un seul|démonstration|prototype)\b", re.I)


def _phrases(t: str) -> list[str]:
    return [p for p in re.split(r"(?<=[.!?])\s+(?=[A-ZÀ-Ý«])", (t or "").strip()) if p]


def verifications(fiche: dict) -> list[str]:
    """Défauts MESURABLES (gratuits, sans IA) : envoyés au relecteur pour qu'il les corrige
    à coup sûr, puis repris dans les alertes. Chaque entrée est une phrase d'instruction."""
    v = []
    titre = str(fiche.get("title", ""))
    if mots_titre(titre) > 12:
        v.append(f"titre de {mots_titre(titre)} mots : 12 au plus")
    if re.search(r"\bfois (?:plus|moins)\b", titre) and not re.search(r"\bqu(?:e|')", titre.split(":", 1)[-1]):
        v.append("titre : « fois plus/moins » sans dire QUE quoi")
    for champ, maxi in (("avant", 2), ("decouverte", 3), ("apres", 2)):
        ph = _phrases(str(fiche.get(champ, "")))
        if len(ph) > maxi:
            v.append(f"« {champ} » a {len(ph)} phrases : {maxi} au plus")
        for p in ph:
            if len(p.split()) > 28:
                v.append(f"phrase de {len(p.split())} mots dans « {champ} », à couper : « {p[:90]}… »")
    avant = str(fiche.get("avant", ""))
    m = re.match(r"\s*(?:\S+\s+){0,6}?(cette|ce|ces|cet|le même|la même|les mêmes)\s+(\w+)", avant, re.I)
    if m and _phrases(avant) and m.end() <= len(_phrases(avant)[0]):
        v.append(f"« avant » commence par « {m.group(1)} {m.group(2)} » : nomme la chose, l'avant doit se comprendre seul")
    textes = " ".join(str(fiche.get(k, "")) for k in ("title", "avant", "decouverte", "apres"))
    sigles = sorted({x for x in re.findall(r"\b[A-Z][A-Z0-9]{1,}[a-z]?\b", textes)
                     if not re.fullmatch(r"[IVXL]+", x)} - _SIGLES_CONNUS)
    if sigles:
        v.append("sigles ou noms codés inconnus du public : " + ", ".join(sigles)
                 + " → écris ce que c'est (ou supprime le nom s'il n'aide pas)")
    nb = len(re.findall(r"\d+(?:[ ,.]\d+)*", str(fiche.get("decouverte", ""))))
    if nb > 3:
        v.append(f"{nb} chiffres dans « decouverte » : garde les 3 plus parlants")
    apres = str(fiche.get("apres", ""))
    if apres and not _LIMITE.search(apres):
        v.append("« apres » ne dit pas la limite principale (chez l'animal, un seul site, prototype, à confirmer…)")
    for m in fiche.get("mots") or []:
        d = str((m or {}).get("definition", ""))
        if len(d.split()) > 25:
            v.append(f"définition de « {m.get('mot')} » trop longue ({len(d.split())} mots, 25 au plus)")
    return v


def alertes(fiche: dict) -> list[str]:
    textes = " ".join(str(fiche.get(k, "")) for k in ("title", "avant", "decouverte", "apres"))
    a = []
    for m in _ABSOLU.finditer(textes):
        debut = textes[max(0, m.start() - 40):m.start()].lower()
        if "selon" not in debut and "d'après" not in debut:
            a.append(f"affirmation absolue : « {m.group(0)} »")
    if re.search(r"[\u0400-\u04ff\u0590-\u06ff\u3040-\u30ff\u3400-\u9fff\uac00-\ud7af]", textes):
        a.append("caractères non latins (erreur de génération)")
    if re.search(r"\b(?:yuans?|dollars?|livres sterling|yens?|wons?)\b", textes, re.I) and "€" not in textes:
        a.append("prix sans équivalent en euros")
    a += verifications(fiche)
    c = fiche.get("controle") or {}
    if c.get("note") is not None and c.get("note") < 8:
        a.append(f"note du rédacteur : {c.get('note')}/10")
    return a
