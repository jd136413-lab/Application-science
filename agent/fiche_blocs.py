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
APPUI = {
    "ce_qu_ils_ont_fait": {"acteur", "methode", "echantillon", "resultat"},
    "comment_ca_marche": {"mecanisme"},
    "comment_le_sait_on": {"preuve"},
    "sur_qui": {"echantillon"},
    "par_rapport_a_quoi": {"comparaison"},
    "pourquoi_surprenant": {"comparaison", "mecanisme"},
    "explication": {"hypothese"},
    "effets_indesirables": {"limite"},
    "cause_ou_lien": {"preuve", "limite"},
    "disponible": {"statut"},
    "qui_doute": {"preuve", "reserve"},
    "avant_le_produit": {"limite", "statut"},
    "a_quoi_ca_sert": {"portee", "statut"},
}
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
    permis = [q.rstrip("*") for q in PROFILS[prof]]
    n_max, mots_max = cible(importance, n_car)
    blocs = []
    for b in f["blocs"]:
        if b["cle"] not in permis:
            al.append(f"bloc hors profil retiré : {b['cle']}")
        elif not APPUI[b["cle"]] & types:
            al.append(f"bloc sans fait du bon type retiré : {b['cle']}")
        else:
            blocs.append(b)
    blocs.sort(key=lambda b: permis.index(b["cle"]))
    if len(blocs) > n_max:
        al.append(f"{len(blocs)} blocs : {n_max} au plus, retirés : {[b['cle'] for b in blocs[n_max:]]}")
        blocs = blocs[:n_max]
    f["blocs"] = blocs
    if f.get("en_chiffres") and len(f["en_chiffres"]) < 2:
        f["en_chiffres"] = []                                   # encadré seulement à partir de 2 chiffres
    if len(f.get("limites") or []) > 3:                          # 25/11 : 3 limites au plus
        al.append(f"{len(f['limites'])} limites : 3 au plus, retirées : {f['limites'][3:]}")
        f["limites"] = f["limites"][:3]
    tx = textes(f)
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
    limites = list(f.get("limites", [])) + [NON_PRECISE[k] for k in f.get("absents", []) if k in etoiles and k in NON_PRECISE]
    blocs = [{"cle": "chapo", "texte": f["chapo"]}]
    if f.get("en_chiffres"):
        blocs.append({"cle": "en_chiffres", "items": f["en_chiffres"]})
    blocs += [{"cle": b["cle"], "texte": b["texte"]} for b in f["blocs"]]
    if limites:
        blocs.append({"cle": "limites", "puces": limites})
    par_cle = {b["cle"]: b["texte"] for b in f["blocs"]}
    return {
        "blocs": blocs,
        "avant": par_cle.get("par_rapport_a_quoi") or par_cle.get("pourquoi_surprenant") or "",
        "decouverte": " ".join([f["chapo"]] + [b["texte"] for b in f["blocs"][:1]]),   # 1re phrase = notification
        "apres": " ".join(limites),
        "mots": f.get("mots", []), "type_etude": f["type_etude"], "title": f["title"],
    }

def message_utilisateur(fil, theme, importance, prof, n_car, article, autres, titre_provisoire=""):
    n_max, mots_max = cible(importance, n_car)
    qs = "\n".join(f"- {q.rstrip('*')} : « {LIBELLES[q.rstrip('*')][fil == 'tech']} »" + (" (à signaler)" if q.endswith("*") else "")
                   for q in PROFILS[prof])
    sources = "\n\n".join([f"[SOURCE 1]\n{article}"] + [f"[SOURCE {i + 2}]\n{a}" for i, a in enumerate(autres)])
    return (f"Fil : {'Technologies' if fil == 'tech' else 'Sciences'} · thème : {theme} · importance : {importance}/5\n"
            f"Titre provisoire du trieur : {titre_provisoire}\n"
            f"Questions pour cette fiche, dans l'ordre :\n{qs}\n"
            f"Blocs : {n_max} au plus. Longueur : {mots_max} mots au plus (chapô + blocs + limites).\n\n{sources}")
