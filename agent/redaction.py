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
import re

TYPES_SCIENCE = ["essai_clinique", "humain", "animal", "cellules", "laboratoire", "simulation",
                 "observation", "terrain", "donnees"]
TYPES_TECH = ["en_vente", "annonce", "demonstration", "prototype", "mise_a_jour"]

CONSIGNE = """Tu es le rédacteur en chef de NovaSTEM, une application gratuite qui explique chaque jour les avancées scientifiques et technologiques à des lecteurs curieux mais non spécialistes (lycéens, adultes sans formation scientifique). Ta fiche doit être EXACTE, CLAIRE et UTILE. Un expert du domaine qui la lit ne doit trouver aucune erreur ; un lycéen doit tout comprendre du premier coup.

On te donne l'article source (seule base de faits autorisée), le fil (Sciences ou Technologies) et un premier jet écrit par un collègue. Le premier jet contient souvent des défauts : exagérations, jargon, titre vague. Ne le recopie pas : réécris la fiche à partir de l'ARTICLE.

# Méthode (remplis les champs du JSON dans cet ordre)

1. "faits" : 4 à 8 faits précis tirés de l'article (qui, quoi, combien, où, comment, limites), chacun en une ligne courte. Seulement ce que l'article dit.
2. "nouveaute" : en une phrase, ce qui est VRAIMENT nouveau selon l'article, et ce qui existait déjà avant. Si l'article dit « premier », « jamais », « record », note-le ici avec ses mots exacts ; sinon écris « l'article ne revendique pas de première ».
3. "jargon" : les mots techniques que tu risques d'employer, et pour chacun ce que tu en fais : « remplacé par … », « expliqué en quelques mots » ou « mot à connaître ».
4. La fiche : "title", "avant", "decouverte", "apres", "mots", "type_etude".
5. "controle" : relis ta fiche avec la liste de contrôle ci-dessous et réponds honnêtement à chaque question. Si une réponse est mauvaise, CORRIGE la fiche avant de répondre (le contrôle décrit la fiche finale).

# Règles d'exactitude (les plus importantes)

- Chaque fait, chiffre, nom ou date vient de l'article. Rien d'inventé, rien de « connu par ailleurs ».
- JAMAIS d'affirmation absolue sur le passé que l'article ne fait pas lui-même : « personne n'avait jamais », « aucun … ne pouvait », « on ignorait », « pour la première fois », « une première mondiale », « jusqu'ici impossible ». Ces phrases sont souvent fausses (une étude plus ancienne avait déjà trouvé la même chose, un autre produit existait déjà). Si l'article ne le dit pas clairement, décris plutôt la limite connue : « on cherchait encore à confirmer… », « ces carburants restaient peu utilisés… », « les preuves étaient encore rares… ». Si l'article le dit, attribue-le : « selon les chercheurs, c'est la première fois… », « selon le constructeur… ».
- Les promesses d'une entreprise restent des promesses : « annoncé », « selon le constructeur ».
- Les bénéfices et les usages futurs (« pourrait permettre de… », « éviterait… ») viennent eux aussi de l'article. N'en déduis pas de nouveaux : un avantage que l'article ne cite pas est une invention.
- Toute comparaison dit par rapport à quoi : « 4 fois plus net que le signal de 2024 », jamais « 90 fois plus abondante » tout seul.
- Deux chiffres sur la même chose doivent être expliqués l'un par rapport à l'autre (« 37 patients en tout, dont 15 à la dose retenue »).
- Les nuances restent : « chez la souris », « sur 15 patients », « en laboratoire », « pas encore relu par d'autres chercheurs ».
- Prix et sommes : donne aussi l'équivalent approximatif en euros, arrondi (1 $ ≈ 0,85 € ; 1 £ ≈ 1,15 € ; 1 yuan ≈ 0,12 € ; 100 yens ≈ 0,60 € ; 1 000 wons ≈ 0,60 € ; 1 franc suisse ≈ 1,05 €), par exemple « 76 800 yuans (environ 9 000 €) ».

# Règles de clarté

- Phrases courtes (25 mots au plus), une idée par phrase, mots de tous les jours.
- Chaque mot technique est soit REMPLACÉ par des mots simples, soit EXPLIQUÉ tout de suite en quelques mots (« un isolant topologique, un matériau isolant à l'intérieur mais conducteur en surface »), soit donné en « mot à connaître ». Au plus deux mots techniques dans toute la fiche. Si le sujet est très technique (physique quantique, chimie…), décris CE QU'ON A VU et À QUOI ÇA SERT plutôt que l'appareillage : un lecteur n'a pas besoin du nom de chaque composant.
- Les sigles sont écrits en entier ou expliqués à la première apparition.
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
  · Si l'article cite des résultats ou des produits antérieurs (autre étude, autre mission, autre météorite, modèle précédent), l'« avant » les mentionne en quelques mots pour situer EXACTEMENT ce qui est nouveau. Exemple : « Des météorites et des échantillons de l'astéroïde Bennu en contenaient déjà ; dans Ryugu, on n'en avait trouvé qu'une sur cinq. » Ne jamais écrire « on cherchait encore à savoir si… » quand l'article montre que c'était déjà connu ailleurs.
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

MAUVAIS → POURQUOI
« Ordinateurs quantiques : des physiciens observent un phénomène prévu par la théorie » → titre vide (quel phénomène ?).
« On ignorait encore si ces molécules existaient dans l'espace. » → affirmation absolue que l'article ne fait pas (et souvent fausse).
« Aucune berline produite en série ne pouvait rouler au méthanol. » → idem ; écrire plutôt « Le méthanol reste un carburant rare pour les voitures particulières. »
« Ils ont observé des états d'Andreev répartis comme prévu. » → jargon non expliqué.
« Les prix vont de 76 800 à 96 800 yuans. » comme seul « Et après » → ne dit pas ce que ça change, et pas d'équivalent en euros.
« Les Nucléobases forment… » → majuscule fautive au milieu d'une phrase.

Réponds uniquement avec le JSON demandé."""


def schema(fil: str) -> dict:
    types = TYPES_SCIENCE if fil == "science" else TYPES_TECH
    return {
        "type": "object",
        "properties": {
            "faits": {"type": "array", "items": {"type": "string"}},
            "nouveaute": {"type": "string"},
            "jargon": {"type": "array", "items": {"type": "string"}},
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
        "required": ["faits", "nouveaute", "jargon", "title", "avant", "decouverte", "apres", "mots",
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
    return (f"Fil : {'Sciences' if fil == 'science' else 'Technologies'}\n"
            f"Importance décidée (ne pas changer) : {brouillon.get('importance', 1)}/5\n\n"
            f"Premier jet (à améliorer, pas à recopier) :\n{json.dumps(jet, ensure_ascii=False)}\n\n"
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
                output_config={"format": {"type": "json_schema", "schema": schema(fil)}},
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
4. "jargon" : un mot technique ou un sigle ni remplacé par des mots simples, ni expliqué juste après, ni donné en mot à connaître.
5. "comparaison" : un chiffre ou une comparaison incompréhensible sans référence (« 90 fois plus abondante » : que quoi ?), ou deux chiffres sur la même chose dont le lien n'est pas expliqué.
6. "apres" : le paragraphe « Et après » ne dit pas ce que ça peut changer, OU ne dit pas la limite principale ou la prochaine étape, OU n'est qu'une liste de prix.
7. "forme" : nom de personne inutile (chercheur d'une autre équipe), « avant » qui raconte l'histoire d'une entreprise au lieu du problème, phrase de plus de 30 mots, tournure maladroite ou traduite de l'anglais, date relative (« mardi », « hier »), majuscule fautive, « avant » de plus de 2 phrases, « decouverte » de plus de 3, « apres » de plus de 2.
8. "mot" : mot à connaître mal choisi (mot courant, nom propre, sigle, absent du texte, déjà expliqué dans le texte) ou définition qui reprend le mot ou reste vague.

Sois sévère mais juste : ne signale pas une préférence de style, seulement un vrai défaut de la liste.

Ce qui est PERMIS (ne le signale pas, ne le retire pas) :
- l'équivalent approximatif en euros d'un prix donné dans une autre monnaie (« 76 800 yuans, environ 9 000 € ») : c'est une règle de l'application ;
- dans la définition d'un mot à connaître, une connaissance générale exacte (« le mélanome est le cancer de la peau le plus dangereux ») ;
- une reformulation simple d'un terme technique, si elle reste exacte.

Quand tu corriges le titre, le nouveau titre doit être PLUS concret que l'ancien (résultat chiffré, chose vue ou à quoi ça sert), jamais plus vague. Si tu ne trouves pas mieux, garde l'ancien.

Puis donne la fiche corrigée : reprends la fiche telle quelle et corrige SEULEMENT les défauts trouvés, sans rien inventer (chaque correction s'appuie sur l'article). Règles de forme à garder : titre « Thème : phrase au présent », 12 mots au plus, sans point final ; avant 1-2 phrases ; decouverte 2-3 phrases ; apres 1-2 phrases, sans commencer par « Et après » ; noms communs en minuscule dans les phrases ; aucune mention de la publication, de la revue ou du média ; mots à connaître : 0 à 2, avec majuscule initiale, définition de 12 à 25 mots sans reprendre le mot. S'il n'y a aucun défaut, "problemes" est vide et la fiche corrigée est identique.

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
    contenu = (f"Fil : {'Sciences' if fil == 'science' else 'Technologies'}\n\n"
               f"Fiche à relire :\n{json.dumps(a_relire, ensure_ascii=False)}\n\n"
               f"Article source — {art.get('source_name', '')} — titre d'origine : {art.get('title', '')}\n"
               f"{art.get('text', '')}")
    for essai in range(essais):
        try:
            rep = client.messages.create(
                model=modele_id, max_tokens=16000,
                system=[{"type": "text", "text": CONSIGNE_RELECTURE, "cache_control": {"type": "ephemeral"}}],
                messages=[{"role": "user", "content": contenu}],
                output_config={"format": {"type": "json_schema", "schema": SCHEMA_RELECTURE}},
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


def alertes(fiche: dict) -> list[str]:
    textes = " ".join(str(fiche.get(k, "")) for k in ("title", "avant", "decouverte", "apres"))
    a = []
    for m in _ABSOLU.finditer(textes):
        debut = textes[max(0, m.start() - 40):m.start()].lower()
        if "selon" not in debut and "d'après" not in debut:
            a.append(f"affirmation absolue : « {m.group(0)} »")
    if re.search(r"\b(?:yuans?|dollars?|livres sterling|yens?|wons?)\b", textes, re.I) and "€" not in textes:
        a.append("prix sans équivalent en euros")
    c = fiche.get("controle") or {}
    if c.get("note") is not None and c.get("note") < 8:
        a.append(f"note du rédacteur : {c.get('note')}/10")
    return a
