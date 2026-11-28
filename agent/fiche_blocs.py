"""Contrôles et mise en forme des fiches « à blocs » (proposition de l'ingénieur, tour 2).
Tout est gratuit (aucun appel à Claude). Les alertes partent au relecteur ; seules les
règles sûres agissent seules (fait sans citation retiré, bloc sans appui retiré)."""
import re
import unicodedata

# 1) Banque fermée d'intertitres : clé -> (libellé Sciences, libellé Technologies)
LIBELLES = {
    "ce_qu_ils_ont_fait":  ("Qu'ont-ils fait ?", "Qu'est-ce que c'est ?"),
    "comment_ca_marche":   ("Comment ça marche ?", "Comment ça marche ?"),
    "comment_le_sait_on":  ("Comment le sait-on ?", "Comment le sait-on ?"),
    "sur_qui":             ("Sur qui, sur combien ?", "Testé sur quoi ?"),
    "par_rapport_a_quoi":  ("Par rapport à quoi ?", "Qu'est-ce qui est nouveau ?"),
    "pourquoi_surprenant": ("Pourquoi est-ce surprenant ?", "Pourquoi est-ce surprenant ?"),
    "explication":         ("Quelle explication ?", "Quelle explication ?"),
    "effets_indesirables": ("Quels effets indésirables ?", "Quels risques ?"),
    "cause_ou_lien":       ("Cause ou simple lien ?", "Cause ou simple lien ?"),
    "disponible":          ("Disponible quand, où ?", "Prix et disponibilité"),
    "qui_doute":           ("Qui l'a vérifié, qui doute ?", "Qui l'a vérifié, qui doute ?"),
    "avant_le_produit":    ("Que manque-t-il avant un usage ?", "Que manque-t-il avant un produit ?"),
    "a_quoi_ca_sert":      ("À quoi ça pourrait servir ?", "À quoi ça pourrait servir ?"),
}
# 2) Un bloc n'existe que si le relevé contient un fait d'un de ces types
APPUI = {          # 25/11 (2e essai) : élargi, le 1er réglage retirait le bloc clé du trou noir
    "ce_qu_ils_ont_fait": {"acteur", "methode", "echantillon", "resultat"},
    "comment_ca_marche": {"mecanisme", "methode"},
    "comment_le_sait_on": {"preuve", "methode", "resultat"},
    "sur_qui": {"echantillon", "methode"},
    "par_rapport_a_quoi": {"comparaison", "revendication"},
    "pourquoi_surprenant": {"comparaison", "mecanisme", "revendication"},
    "explication": {"hypothese"},
    "effets_indesirables": {"limite"},
    "cause_ou_lien": {"preuve", "limite"},
    "disponible": {"statut"},
    "qui_doute": {"preuve", "reserve"},
    "avant_le_produit": {"limite", "statut"},
    "a_quoi_ca_sert": {"portee", "statut"},
    "autre": {"resultat", "acteur", "echantillon", "methode", "mecanisme", "preuve", "comparaison",
              "revendication", "hypothese", "portee", "statut", "limite", "reserve"},
}
# 25/11 (Maxime : « aucun paragraphe prédéfini ») : les profils ne sont plus que des PISTES ;
# le rédacteur choisit ses angles, leur ordre, et écrit l'intertitre de chaque bloc pour le sujet.
GENERIQUES = {"comment ça marche ?", "comment le sait-on ?", "et après ?", "avant", "la découverte",
              "pourquoi est-ce surprenant ?", "quelle explication ?", "qu'est-ce que c'est ?", "qu'ont-ils fait ?",
              "à quoi ça sert ?", "à quoi ça pourrait servir ?", "par rapport à quoi ?", "contexte", "résultats"}


def question_ok(q: str) -> bool:
    q = " ".join(str(q or "").split())
    return 2 <= len(q.split()) <= 12 and q.lower().replace("’", "'") not in GENERIQUES and "http" not in q.lower()
# 3) Profils : questions proposées au rédacteur, dans l'ordre (* = « à signaler » si aucune source n'y répond)
PROFILS = {
    "traitement":  ["sur_qui*", "par_rapport_a_quoi*", "comment_ca_marche", "effets_indesirables*", "disponible*"],
    "sante_etude": ["sur_qui*", "comment_le_sait_on", "comment_ca_marche", "cause_ou_lien*", "a_quoi_ca_sert"],
    "vivant":      ["comment_ca_marche", "comment_le_sait_on", "sur_qui*", "a_quoi_ca_sert"],
    "observation": ["ce_qu_ils_ont_fait", "pourquoi_surprenant", "comment_le_sait_on", "explication", "par_rapport_a_quoi"],
    "labo":        ["comment_ca_marche", "par_rapport_a_quoi", "comment_le_sait_on", "avant_le_produit", "a_quoi_ca_sert"],
    "theorie":     ["ce_qu_ils_ont_fait", "comment_le_sait_on", "qui_doute*", "a_quoi_ca_sert"],
    "produit":     ["comment_ca_marche", "par_rapport_a_quoi", "disponible*", "qui_doute"],
    "prototype":   ["par_rapport_a_quoi", "comment_ca_marche", "comment_le_sait_on", "avant_le_produit*"],
}
SANTE = {"medicine", "health", "neuroscience", "psychology"}

def profil(fil: str, theme: str, type_etude: str) -> str:
    if fil == "tech":
        return "produit" if type_etude in ("en_vente", "annonce", "mise_a_jour") else "prototype"
    if type_etude == "essai_clinique":
        return "traitement"
    if theme in SANTE and type_etude in ("humain", "donnees"):
        return "sante_etude"
    if type_etude in ("animal", "cellules"):
        return "vivant"
    if type_etude in ("observation", "terrain"):
        return "observation"
    if type_etude == "aucun":
        return "theorie"
    return "labo"                       # laboratoire, simulation, donnees hors santé

def cible(importance: int, n_car_source: int) -> tuple[int, int]:
    """(nombre de blocs au plus, mots au plus pour chapô + blocs + limites)."""
    n, mots = {1: (3, 170), 2: (3, 200), 3: (4, 240)}.get(importance, (5, 280))
    if n_car_source < 3000:
        n, mots = min(n, 3), min(mots, 160)
    return n, mots

# 4) Citations
def _norm(s):
    s = unicodedata.normalize("NFKC", s or "").lower()
    for a, b in (("’", "'"), ("‘", "'"), ("“", '"'), ("”", '"'), ("–", "-"), ("—", "-")):
        s = s.replace(a, b)
    return re.sub(r"\s+", " ", s).strip()

def citation_ok(citation, sources):
    c = _norm(citation)
    for src in map(_norm, sources):
        if c and c in src:
            return True
        mots = [m for m in re.findall(r"\w+", c) if len(m) > 3]
        if mots and sum(m in src for m in mots) / len(mots) >= 0.85:
            return True
    return False

# 5) Nombres (même normalisation que main._nombres)
def nombres(t):
    t = re.sub(r"\b[A-Z][\w-]*\s?\d+\b", "", t or "")          # noms de modèles : « Tai 9 », « ET9 »
    t = unicodedata.normalize("NFKC", t.replace("²", "").replace("³", ""))
    t = re.sub(r"(?<=\d)[  ](?=\d{3}\b)", "", t)
    t = re.sub(r"(?<=\d),(?=\d{3}\b)", "", t)
    return [n.replace(",", ".") for n in re.findall(r"\d+(?:[.,]\d+)?", t)]

def textes(f):
    out = [("chapo", f.get("chapo", ""))]
    out += [(b["cle"], b["texte"]) for b in f.get("blocs", [])]
    out += [("en_chiffres", c["valeur"] + " " + c["sens"]) for c in f.get("en_chiffres", [])]
    out += [("limites", x) for x in f.get("limites", [])]
    return out

FORMULES_CREUSES = re.compile(
    r"ouvre (?:la|de nouvelles) (?:voie|perspectives)|pourrait r[ée]volutionner|change la donne|"
    r"aide (?:les (?:scientifiques|chercheurs) )?[àa] (?:mieux )?comprendre|permet(?:tra)? de mieux comprendre|"
    r"d'autres (?:études|essais|recherches|travaux) (?:sont|seront) n[ée]cessaires|"
    r"plus (?:vari[ée]e?|complexe|riche) qu'on (?:ne )?le pensait|ce sont des pistes|une [ée]tape (?:importante|cl[ée])", re.I)
SPECIFIQUE = re.compile(r"\d|\b[A-Z][a-zà-ÿ]{2,}|chez (?:la|le|l')|en laboratoire|à l'arrêt|un seul|une seule|seules? ", re.U)

def chiffres_clairs(lignes, al=None) -> list:
    """25/11 (Maxime : « 47 / 46 … on comprend pas ») : une ligne = un seul nombre avec son unité,
    sans « / », et à droite une simple description qui commence par une majuscule."""
    clairs = []
    for c in lignes or []:
        if not isinstance(c, dict):
            continue
        v = " ".join(str(c.get("valeur", "")).split())
        sens = " ".join(str(c.get("sens", "")).split())
        if not v or not sens or "/" in v or len(v.split()) > 5 or \
                len(re.findall(r"\d+(?:[ ,.]\d+)*", v)) > 1 and "à" not in v and "sur" not in v:
            if al is not None:
                al.append(f"chiffre peu clair retiré de l'encadré : « {v} »")
            continue
        clairs.append({"valeur": v, "sens": sens[:1].upper() + sens[1:]})
    return clairs


# 25/11 (bilan du passage de 18h20) : des notes destinées à l'équipe s'affichaient aux lecteurs
# (« à vérifier avant publication »), et des « limites » qui n'en étaient pas (un avantage annoncé,
# une étape déjà passée). Les unités anglo-saxonnes restaient non converties (« 180 miles par heure »).
NOTE_REDACTEUR = re.compile(
    r"(?:à|a) v[ée]rifier|avant (?:la )?publication|doit (?:encore )?être v[ée]rifi|contredi[st]|"
    r"(?:la|le|les) (?:source|statut)s? (?:de la source )?(?:indique|annonce|signale)n?t? d[ée]j[àa]|"
    r"statut de la source|ne correspond pas à un [ée]v[ée]nement|incoh[ée]ren", re.I)
FAUSSE_LIMITE = re.compile(
    r"\bcontre\b[^.]*\b(?:pour|chez) (?:une|la|les) (?:puce|technologie|solution|concurren)|"
    r"\bplus (?:rapide|efficace|performant|fiable|l[ée]ger)|\bmoins (?:cher|co[uû]teu)|\brecord\b|\bavantage", re.I)
# 28/11 : remarque sur l'accès à la source (« l'article complet n'est pas accessible dans l'extrait fourni ») :
# le lecteur n'en a que faire. On coupe ce bout de phrase dans les limites, sans jeter la vraie limite.
EXTRAIT_FOURNI = re.compile(
    r"(?:[,;]\s*(?:et |mais )?|^)[^,;.]*\b(?:extrait|texte|résumé|article|source)s? (?:complet |intégral )?"
    r"(?:fourni|transmis)e?s?\b[^,;.]*|(?:[,;]\s*(?:et |mais )?|^)[^,;.]*\bn'(?:est|était) pas accessible\b[^,;.]*", re.I)
UNITES_US = re.compile(r"\d[\d  ,.]*\s*(?:miles?|mph|pieds|feet|ft\b|pouces|inch|livres? \(|lbs?\b|°\s?F\b|"
                       r"degr[ée]s? fahrenheit|gallons?|onces?)", re.I)
_MOIS = {m: i + 1 for i, m in enumerate(["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août",
                                         "septembre", "octobre", "novembre", "décembre"])}


def date_passee(t: str, aujourd_hui) -> bool:
    """Vrai si la phrase parle d'un mois + année déjà écoulé (« en février 2026 »)."""
    for m, a in re.findall(r"(janvier|février|mars|avril|mai|juin|juillet|août|septembre|octobre|novembre|décembre)\s+(20\d\d)",
                           t or "", re.I):
        if (int(a), _MOIS[m.lower()]) < (aujourd_hui.year, aujourd_hui.month):
            return True
    return False


def alertes_limites(limites, al) -> None:
    """Alertes pour le relecteur (le programme tranche ensuite avec limites_finales)."""
    from datetime import date
    for x in limites or []:
        if NOTE_REDACTEUR.search(x):
            al.append(f"limite qui s'adresse à l'équipe, pas au lecteur (à supprimer) : {x}")
        elif FAUSSE_LIMITE.search(x):
            al.append(f"« limite » qui est un avantage ou un fait établi (à supprimer ou déplacer) : {x}")
        elif date_passee(x, date.today()):
            al.append(f"limite sur une étape déjà passée (à supprimer) : {x}")


def limites_finales(limites, log_al=None) -> list:
    """Règle sûre, après relecture : ces limites ne s'affichent jamais. (Les « fausses limites »
    restent une alerte pour le relecteur : un mot comme « record » peut aussi servir une vraie limite.)"""
    from datetime import date
    garde = []
    for x in limites or []:
        if EXTRAIT_FOURNI.search(x or ""):
            x = re.sub(r"^(?:et|mais) ", "", EXTRAIT_FOURNI.sub("", x).strip(" ,;"), flags=re.I)
            x = (x[0].upper() + x[1:].rstrip(".") + ".") if len(x.split()) >= 4 else ""
            if not x:
                continue
        if NOTE_REDACTEUR.search(x) or date_passee(x, date.today()):
            if log_al is not None:
                log_al.append(f"limite retirée : {x[:80]}")
            continue
        garde.append(x)
    return garde


def sans_note_redacteur(t: str) -> str:
    """Retire d'un paragraphe les phrases qui s'adressent à l'équipe."""
    return " ".join(p for p in re.split(r"(?<=[.!?])\s+", t or "") if not NOTE_REDACTEUR.search(p)).strip()


def alertes_unites(textes_, al) -> None:
    for k, t in textes_:
        m = UNITES_US.search(t or "")
        if m:
            al.append(f"unité anglo-saxonne dans {k} : « {m.group(0).strip()} » → convertis en unité française "
                      f"(km, km/h, m, kg, °C…), en gardant au plus la valeur d'origine entre parenthèses")


def nb_mots(f) -> int:
    """Mots affichés : chapô + blocs + limites (l'encadré « En chiffres » à part)."""
    return sum(len(t.split()) for k, t in textes(f) if k != "en_chiffres")


def nettoyer(f, sources, fil, prof, importance, n_car):
    """Applique les règles sûres et renvoie la liste des alertes pour le relecteur."""
    al = []
    garde = []
    for x in f["releve"]:
        if citation_ok(x["citation"], sources):
            garde.append(x)
        else:
            al.append(f"citation introuvable, fait retiré : {x['citation']}")
    f["releve"] = garde
    types = {x["type"] for x in garde}
    n_max, mots_max = cible(importance, n_car)
    blocs, vues = [], set()
    for b in f["blocs"]:
        q = " ".join(str(b.get("question", "")).split())
        if b.get("cle") not in APPUI:
            b["cle"] = "autre"
        if not APPUI[b["cle"]] & types:
            al.append(f"bloc sans fait du bon type retiré : {b['cle']} ({q})")
            continue
        if not question_ok(q) or q.lower() in vues:
            al.append(f"intertitre passe-partout ou répété : « {q} » ({b['cle']})")
            if b["cle"] == "autre":
                continue                    # sans intertitre propre, un bloc « autre » n'a pas de sens
            q = ""                          # l'app affichera l'intertitre de secours de la clé
        vues.add(q.lower())
        b["question"] = q
        blocs.append(b)                     # ordre choisi par le rédacteur
    if len(blocs) > n_max:
        al.append(f"{len(blocs)} blocs : {n_max} au plus, retirés : {[b['cle'] for b in blocs[n_max:]]}")
        blocs = blocs[:n_max]
    f["blocs"] = blocs
    f["en_chiffres"] = chiffres_clairs(f.get("en_chiffres"), al)
    if f.get("en_chiffres") and len(f["en_chiffres"]) < 2:
        f["en_chiffres"] = []                                   # encadré seulement à partir de 2 chiffres
    if len(f.get("limites") or []) > 3:                          # 25/11 : 3 limites au plus
        al.append(f"{len(f['limites'])} limites : 3 au plus, retirées : {f['limites'][3:]}")
        f["limites"] = f["limites"][:3]
    alertes_limites(f.get("limites"), al)
    tx = textes(f)
    alertes_unites(tx, al)
    if not f.get("en_chiffres"):                                # 25/11 : encadré absent de 3 fiches sur 4
        n_src = len(set(nombres(" ".join(sources))) - {str(i) for i in range(11)})
        if n_src >= 4:
            al.append("aucun encadré « en_chiffres » alors que les sources donnent plusieurs chiffres : "
                      "ajoute 2 à 3 lignes claires (valeur avec unité + description), sans répéter un nombre du texte")
    n_mots = nb_mots(f)
    if n_mots > int(mots_max * 1.2):                            # longueur justifiée : +20 % toléré (Maxime, 25/11)
        al.append(f"{n_mots} mots : {mots_max} visés, {int(mots_max * 1.2)} au plus")
    for k, t in tx:
        for p in re.split(r"(?<=[.!?])\s+", t):
            if len(p.split()) > 28:
                al.append(f"phrase de {len(p.split())} mots dans {k}")
        if FORMULES_CREUSES.search(t):
            al.append(f"formule creuse dans {k} : {FORMULES_CREUSES.search(t).group(0)}")
    vus = {}
    for k, t in tx:                                             # chaque nombre une seule fois (titre exclu)
        for n in set(nombres(t)) - {str(i) for i in range(11)}:   # 0 à 10 : trop courants
            if n in vus and vus[n] != k:
                al.append(f"nombre {n} répété ({vus[n]} et {k})")
            vus.setdefault(n, k)
    connus = set(nombres(" ".join(sources))) | set(nombres(" ".join(x["fait"] for x in garde)))
    inconnus = sorted({n for _, t in tx for n in nombres(t)} - connus - {str(i) for i in range(11)})
    if inconnus:
        al.append(f"nombres absents des sources : {inconnus}")
    def ng(t):
        w = re.findall(r"\w+", t.lower()); return {" ".join(w[i:i + 6]) for i in range(len(w) - 5)}
    for i in range(len(tx)):
        for j in range(i + 1, len(tx)):
            if tx[i][0] != tx[j][0] and ng(tx[i][1]) & ng(tx[j][1]):
                al.append(f"répétition entre {tx[i][0]} et {tx[j][0]}")
    for x in f.get("limites", []):
        if not SPECIFIQUE.search(x):
            al.append(f"limite générale : {x}")
    return al

# 6) Prix : une seule monnaie écrite par le rédacteur ; la conversion reste redaction.euros()
def un_seul_prix(t):
    """« 329 900 yuans (environ 49 000 dollars) » -> « 329 900 yuans » : la 2e monnaie disparaît."""
    return re.sub(r"(\d[\d  ]*(?:,\d+)?\s*(?:yuans?|dollars?|\$|livres?|yens?|wons?))"
                  r"\s*(?:\(|,\s*soit\s+)(?:environ\s+)?\d[\d  ]*(?:,\d+)?\s*(?:dollars?|\$|yuans?)\)?", r"\1", t)

# 7) Phrases « non précisé » écrites par le programme (traduites une fois dans l'app)
NON_PRECISE = {
    "sur_qui": "Le nombre de personnes ou d'échantillons étudiés n'est pas précisé.",
    "par_rapport_a_quoi": "Aucun groupe de comparaison n'est mentionné.",
    "effets_indesirables": "Les effets indésirables ne sont pas précisés.",
    "disponible": "Aucune date ni aucun pays de disponibilité n'est annoncé.",
    "cause_ou_lien": "L'étude ne dit pas si le lien observé est une cause.",
    "qui_doute": "Aucune vérification indépendante n'est mentionnée.",
    "avant_le_produit": "Ni durée de vie ni date de commercialisation ne sont annoncées.",
}

# 8) Ce qui est enregistré : colonne jsonb « blocs » + anciennes colonnes pour les anciennes versions de l'app
def pour_la_base(f, prof):
    etoiles = {q.rstrip("*") for q in PROFILS[prof] if q.endswith("*")}
    # 26/11 (suivi qualité) : avec 2 vraies limites ou plus, pas de phrase passe-partout « cause ou lien » ni
    # « durée de vie / commercialisation » en plus (rein de porc, main bionique, scanner IA, planeur)
    assez = len(f.get("limites", [])) >= 2
    # 27/11 (suivi qualité) : pas de phrase « non précisé » si la fiche a déjà ce paragraphe, ni de phrase
    # « commercialisation » si une limite parle déjà de produit (micropuce UV, réacteur BN-800)
    deja = {b.get("cle") for b in f.get("blocs", [])}
    deja_produit = re.search(r"produit|production|industri|grande échelle|commerciali|durée de vie",
                             " ".join(f.get("limites", [])), re.I)
    # 27/11 soir (suivi qualité) : « durée de vie » n'a pas de sens pour un logiciel ou un modèle d'IA (cyclones)
    deja_produit = deja_produit or re.search(r"\b(modèle|logiciel|algorithme)s? d'(IA|intelligence artificielle)|\blogiciel",
                                             f.get("chapo", ""), re.I)
    limites = list(f.get("limites", [])) + [NON_PRECISE[k] for k in f.get("absents", []) if k in etoiles and k in NON_PRECISE
                                            and k not in deja and not (k == "avant_le_produit" and deja_produit)
                                            and not (assez and k in ("cause_ou_lien", "avant_le_produit"))]
    blocs = [{"cle": "chapo", "texte": f["chapo"]}]
    if f.get("en_chiffres"):
        blocs.append({"cle": "en_chiffres", "items": f["en_chiffres"]})
    blocs += [{"cle": b["cle"], "texte": b["texte"], **({"question": b["question"]} if b.get("question") else {})}
              for b in f["blocs"]]
    if limites:
        blocs.append({"cle": "limites", "puces": limites})
    par_cle = {b["cle"]: b["texte"] for b in f["blocs"]}
    avant = par_cle.get("par_rapport_a_quoi") or par_cle.get("pourquoi_surprenant") or ""
    # 27/11 soir (suivi qualité) : le 1er paragraphe était souvent « avant » lui-même → texte en double dans
    # avant + decouverte (résumé anglais, vidéo de la semaine). On prend le 1er paragraphe différent.
    suite = [b["texte"] for b in f["blocs"] if b["texte"] != avant][:1]
    return {
        "blocs": blocs,
        "avant": avant,
        "decouverte": " ".join([f["chapo"]] + suite),   # 1re phrase = notification
        "apres": " ".join(limites),
        "mots": f.get("mots", []), "type_etude": f["type_etude"], "title": f["title"],
    }

def message_utilisateur(fil, theme, importance, prof, n_car, article, autres, titre_provisoire=""):
    n_max, mots_max = cible(importance, n_car)
    qs = "\n".join(f"- {q.rstrip('*')} : « {LIBELLES[q.rstrip('*')][fil == 'tech']} »" + (" (à signaler)" if q.endswith("*") else "")
                   for q in PROFILS[prof])
    autres_cles = ", ".join(k for k in LIBELLES if k not in {q.rstrip("*") for q in PROFILS[prof]})
    sources = "\n\n".join([f"[SOURCE 1]\n{article}"] + [f"[SOURCE {i + 2}]\n{a}" for i, a in enumerate(autres)])
    return (f"Fil : {'Technologies' if fil == 'tech' else 'Sciences'} · thème : {theme} · importance : {importance}/5\n"
            f"Titre provisoire du trieur : {titre_provisoire}\n"
            f"Pistes de questions pour ce type de sujet (à toi de choisir les angles et leur ordre) :\n{qs}\n"
            f"Autres clés possibles : {autres_cles}, autre.\n"
            f"Blocs : {n_max} au plus. Longueur : {mots_max} mots au plus (chapô + blocs + limites).\n\n{sources}")
