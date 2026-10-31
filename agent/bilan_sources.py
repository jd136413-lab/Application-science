# =====================================================================
# BILAN DES SOURCES — NovaSTEM (31/10/2026)
# ---------------------------------------------------------------------
# À chaque passage, l'agent note ce que chaque source a apporté (gratuit,
# aucun appel à Claude). Le bilan des 14 derniers jours est écrit dans
# agent/bilan_sources.md (enregistré dans le repo chaque matin) : Claude et
# Maxime le lisent pour décider quelles sources ajouter ou retirer.
#
# Pour chaque article nouveau d'une source :
#   lu → prometteur (présélection) → examiné (juge) → publié, doublon ou écarté.
#   « même sujet » : l'article parlait d'une avancée choisie chez une autre source
#   (la source couvre bien l'actualité, mais n'était pas la meilleure à lire).
#   « plafond » : avancée laissée de côté car sa famille était au plafond.
# =====================================================================

import json
import os
from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone

FICHIER = "stats_sources.json"      # mémoire (cache GitHub, comme memoire_tri.json)
RAPPORT = "bilan_sources.md"
JOURS = 14
GARDER_JOURS = 30

# Région de chaque source (pour voir la couverture du monde). Les sources
# absentes de cette liste comptent dans « Monde / généraliste ».
REGIONS = {
    "Amérique du Nord": """NASA|NASA Science|NASA JPL|NASA Goddard|PLOS Biology|PLOS Medicine|PLOS ONE|PLOS Climate|
PLOS Computational Biology|PLOS Genetics|PLOS Pathogens|Science|Quanta Magazine|Live Science|Space.com|MIT News|NOAA|
NSF|NIST|USGS|Berkeley Lab|Argonne|Oak Ridge (ORNL)|SLAC|Harvard Gazette|Caltech|University of Washington|
University of Michigan|Broad Institute|MBARI (océans)|Carnegie Science|NRAO (radioastronomie)|Observatoire Keck|
SETI Institute|UBC (Canada)|Physics (APS)|Eos (sciences de la Terre)|Yale Environment 360|STAT News (santé)|
Science News|Universe Today|The Transmitter (neurosciences)|Archaeology Magazine|Cell|ScienceDaily|TechCrunch|Engadget|IEEE Spectrum|Electrek|MIT Technology Review|
Wired|9to5Mac|9to5Google|SpaceNews|InsideEVs|Apple Newsroom|NVIDIA Newsroom|Google Blog|OpenAI News|Microsoft News|
Google Research|Microsoft Research|IBM Research|Rocket Lab|PlayStation Blog|ServeTheHome (serveurs, puces)|EE Times (électronique)|
Semiconductor Engineering|The Robot Report|The Quantum Insider|Spaceflight Now|NASASpaceflight|Payload (industrie spatiale)|
MedTech Dive (technologies médicales)|DroneDJ (drones)|Woods Hole (WHOI)|Schmidt Ocean Institute|LLNL (fusion, Livermore)|
FDA (autorisations, États-Unis)|DARPA|Xbox Wire|Road to VR|UploadVR|Game Developer|PC Gamer|Steam (actualités)|
Unreal Engine (blog)|Construction Dive (bâtiment)|AgFunderNews (agritech, foodtech)|gCaptain (maritime)|PetaPixel (photo, imagerie)""",
    "Europe": """ESO|ESA/Webb|ESA/Hubble|ESA|Nature|CNRS Le journal|Inserm|Futura Sciences|Sciences et Avenir|Le Monde Sciences|
Observatoire de Paris|Max Planck|ETH Zurich|EPFL|Institut Paul Scherrer (PSI)|EMBL|Fraunhofer|Université de Copenhague|
Université de Lund|CNIO (cancer, Espagne)|Université de Cambridge|Francis Crick Institute|Chemistry World|Carbon Brief (climat)|
BBC Science|The Guardian Science|Pour la Science|Techno-Science.net|Ciel & Espace|Nature Communications|Communications Biology|
Communications Earth & Environment|Communications Physics|Communications Medicine|Scientific Reports|Nature Astronomy|
Nature Climate Change|Nature Ecology & Evolution|Nature Physics|Nature Geoscience|Nature Neuroscience|Nature Biotechnology|
BMJ|Nature Medicine|Phys.org|Medical Xpress|Tom's Hardware|GSMArena|Presse-citron|Journal du Geek|Tech Xplore|New Atlas|
Les Numériques|Clubic|Siècle Digital|Google DeepMind|Hugging Face|Arm|Siemens|Airbus|ESA (technologie spatiale)|The Decoder (IA)|
Robohub|pv magazine (solaire)|Energy-Storage.news (batteries)|electrive (véhicules électriques, Europe)|European Spaceflight|
Nintendo Life|L'Usine Nouvelle|L'Usine Digitale|British Antarctic Survey|Institut Alfred Wegener (pôles)|
Natural History Museum (Londres)|Copernicus (climat, Europe)|ITER (fusion)|World Nuclear News|Railway Gazette (trains)|
Digital Foundry (Eurogamer)|Eurogamer|VGC (Video Games Chronicle)|Gamekult|Jeuxvideo.com|El País Ciencia|3D Printing Industry""",
    "Asie": """RIKEN (Japon)|Université de Kyoto|A*STAR (Singapour)|NUS (Singapour)|Samsung Semiconductor|CnEVPost (véhicules électriques, Chine)|
Gematsu (jeux vidéo, Japon)|TechNode (Chine)|Pandaily (Chine)|SCMP Tech (Asie)|Académie chinoise des sciences|Xinhua Sciences|
CGTN Sci-Tech|The Hindu Science|Down To Earth (Inde)|IISc (Inde)|KAIST (Corée)|IBS (Corée)|The Korea Herald Tech|Times of India Tech""",
    "Moyen-Orient": "KAUST Discovery (Arabie saoudite)|Institut Weizmann|Technion|Nature Middle East",
    "Afrique": """TechCabal (Afrique)|Nature Africa|SciDev.Net|Université du Cap (UCT)|Université du Witwatersrand (Wits)|
Université de Stellenbosch|ILRI (élevage, Afrique)|icipe (insectes, Kenya)|Techpoint Africa|Disrupt Africa""",
    "Océanie": "UNSW Sydney|Université de Sydney|Université de Melbourne (Pursuit)|Cosmos Magazine|Université d'Auckland|ANU (Australie)",
    "Amérique latine": "Pesquisa FAPESP (Brésil)|SciELO en perspective",
}
REGION_DE = {n.strip(): r for r, noms in REGIONS.items() for n in noms.replace("\n", "").split("|") if n.strip()}

ETAPES = ("lu", "prometteur", "meme_sujet", "examine", "publie", "doublon", "ecarte", "plafond")


def _charger() -> dict:
    try:
        return json.load(open(FICHIER, encoding="utf-8"))
    except Exception:
        return {"articles": {}}


def enregistrer(tous: list[dict], examines: set, publies: list[dict], doublons: list, ecartes: list,
                au_plafond: list, maintenant: datetime) -> None:
    """Met à jour la mémoire avec ce passage. Ne lève jamais d'erreur."""
    try:
        m = _charger()
        arts = m.setdefault("articles", {})
        jour = maintenant.strftime("%Y-%m-%d")

        def marque(a: dict, etape: str, famille: str | None = None):
            u = a.get("url") or a.get("source_url")
            if not u:
                return
            x = arts.setdefault(u, {"s": a.get("source_name", "?"), "f": a.get("fil_source") or a.get("feed") or "science",
                                    "j": jour, "e": []})
            if etape not in x["e"]:
                x["e"].append(etape)
            if famille:
                x["fam"] = famille

        for a in tous:
            marque(a, "lu")
            if a.get("note_tri"):
                marque(a, "prometteur")
            if a.get("_meme_sujet"):
                marque(a, "meme_sujet")
        for a in tous:
            if a["url"] in examines:
                marque(a, "examine")
        for a, _ in doublons:
            marque(a, "doublon")
        for a, *_ in ecartes:
            marque(a, "ecarte")
        for a in au_plafond:
            marque(a, "plafond")
        for l in publies:
            marque({"url": l["source_url"], "source_name": l["source_name"], "feed": l["feed"]}, "publie",
                   l.get("family"))
        limite = (maintenant - timedelta(days=GARDER_JOURS)).strftime("%Y-%m-%d")
        m["articles"] = {u: x for u, x in arts.items() if x["j"] >= limite}
        m["maj"] = maintenant.isoformat()
        json.dump(m, open(FICHIER, "w", encoding="utf-8"), ensure_ascii=False)
    except Exception as ex:
        print(f"⚠ Bilan des sources non enregistré ({ex.__class__.__name__})", flush=True)


def ecrire_rapport(sources: list[dict], maintenant: datetime) -> str:
    """Écrit bilan_sources.md (14 derniers jours) et renvoie un résumé d'une ligne."""
    m = _charger()
    limite = (maintenant - timedelta(days=JOURS)).strftime("%Y-%m-%d")
    arts = [x for x in m.get("articles", {}).values() if x["j"] >= limite]
    debut = min((x["j"] for x in m.get("articles", {}).values()), default=maintenant.strftime("%Y-%m-%d"))
    par = defaultdict(Counter)
    familles = defaultdict(Counter)
    for x in arts:
        for e in x["e"]:
            par[x["s"]][e] += 1
        if "publie" in x["e"] and x.get("fam"):
            familles[x["s"]][x["fam"]] += 1
    fil_de = {s["name"]: s["feed"] for s in sources}
    noms = [s["name"] for s in sources]

    L = ["# Bilan des sources (14 derniers jours)", "",
         f"Mis à jour le {maintenant.astimezone(timezone(timedelta(hours=1))):%d/%m/%Y à %H h %M} (heure de Paris) · "
         f"données depuis le {datetime.strptime(debut, '%Y-%m-%d'):%d/%m/%Y} · {len(sources)} sources lues.", "",
         "Colonnes : **nouveaux** = articles jamais vus ; **prometteurs** = gardés par la présélection ; "
         "**même sujet** = parlaient d'une avancée retenue chez une autre source ; **examinés** = lus par le juge ; "
         "**publiés** ; **doublons** ; **écartés** par le juge ; **plafond** = laissés de côté (famille au plafond).", ""]

    # Par région
    L += ["## Par région", "", "| Région | Sources | Nouveaux | Prometteurs | Publiés |", "|---|---|---|---|---|"]
    reg = defaultdict(lambda: [0, Counter()])
    for n in noms:
        r = REGION_DE.get(n, "Monde / généraliste")
        reg[r][0] += 1
        reg[r][1].update(par[n])
    for r, (nb, c) in sorted(reg.items(), key=lambda kv: -kv[1][1]["publie"]):
        L.append(f"| {r} | {nb} | {c['lu']} | {c['prometteur']} | {c['publie']} |")

    # Par famille (fiches publiées)
    fam_tot = Counter()
    for c in familles.values():
        fam_tot.update(c)
    L += ["", "## Fiches publiées par famille", "",
          ", ".join(f"{f} : {n}" for f, n in fam_tot.most_common()) or "Pas encore de données.", ""]

    # Par source
    def ligne(n):
        c = par[n]
        fam = ", ".join(f"{f} {k}" for f, k in familles[n].most_common(3))
        return (f"| {n} | {fil_de.get(n, '?')} | {REGION_DE.get(n, 'Monde')} | {c['lu']} | {c['prometteur']} | "
                f"{c['meme_sujet']} | {c['examine']} | **{c['publie']}** | {c['doublon']} | {c['ecarte']} | "
                f"{c['plafond']} | {fam} |")
    entete = ["| Source | Fil | Région | Nouveaux | Prometteurs | Même sujet | Examinés | Publiés | Doublons | "
              "Écartés | Plafond | Familles publiées |", "|---|---|---|---|---|---|---|---|---|---|---|---|"]
    tri = sorted(noms, key=lambda n: (-par[n]["publie"], -par[n]["prometteur"], -par[n]["lu"]))
    L += ["## Toutes les sources (de la plus utile à la moins utile)", ""] + entete + [ligne(n) for n in tri]

    rien = [n for n in noms if par[n]["prometteur"] == 0 and par[n]["meme_sujet"] == 0]
    muets = [n for n in noms if par[n]["lu"] == 0]
    que_doublons = [n for n in noms if par[n]["doublon"] >= 2 and par[n]["publie"] == 0]
    jours_de_donnees = (maintenant.date() - datetime.strptime(debut, "%Y-%m-%d").date()).days + 1
    if jours_de_donnees < 7:
        L += ["", "## À surveiller", "", f"Pas encore assez de recul ({jours_de_donnees} jour(s) de données sur {JOURS}) : "
              "les listes ci-dessous seront fiables après une semaine.", ""]
    L += ["", "## À surveiller", "",
          f"- **Aucun article nouveau** en {JOURS} jours (flux en panne ou abandonné ?) : {', '.join(muets) or 'aucune'}",
          f"- **Rien de prometteur** (articles lus mais jamais retenus par la présélection) : "
          f"{', '.join(n for n in rien if n not in muets) or 'aucune'}",
          f"- **Seulement des doublons** : {', '.join(que_doublons) or 'aucune'}", ""]
    try:
        open(RAPPORT, "w", encoding="utf-8").write("\n".join(L) + "\n")
    except Exception:
        pass
    return (f"{len(sources)} sources ; {sum(c['publie'] for c in par.values())} publiés sur {JOURS} jours ; "
            f"{len(muets)} sans nouvel article, {len([n for n in rien if n not in muets])} sans rien de prometteur")
