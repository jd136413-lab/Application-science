# =====================================================================
# RELECTURE DES TITRES — NovaSTEM (31/10/2026, choix de Maxime)
# ---------------------------------------------------------------------
# « Test du passant » : un titre doit se comprendre par quelqu'un qui n'a
# jamais entendu parler du sujet (pas de nom propre inconnu, pas de jargon,
# dire ce que ça change). Claude écrit déjà les titres avec cette règle ;
# ici, un second appel très bon marché RELIT les titres et réécrit seulement
# ceux qui échouent (une IA applique mieux une règle en relisant).
#
# Utilisé de deux façons :
#  - par l'agent (main.py), sur les nouvelles fiches de chaque passage,
#    avant les traductions et les notifications ;
#  - seul (« python titres.py », workflow « Réécrire les titres ») : toutes
#    les fiches déjà publiées ; leur traduction anglaise est refaite.
# =====================================================================

MODELE = "claude-haiku-5-5"
PRIX = (0.10, 0.50)          # $ par million de tokens (entrée, sortie)
PAQUET = 20                  # titres relus par appel
PLAFOND_COUT = 1.00          # $ : le workflow s'arrête au-delà
MAX_MOTS = 13                # garde-fou (la règle demande 12 au plus)

import json
import os
import sys
import time

import requests

CONSIGNE = """Tu relis les titres de NovaSTEM, une application gratuite qui présente les avancées scientifiques et technologiques à un large public (lycéens curieux, adultes sans formation scientifique).

Chaque titre a la forme « Thème : phrase » (sujet + verbe conjugué au présent + complément), 12 mots au plus, sans point final.

Applique le TEST DU PASSANT : le titre se comprend-il par quelqu'un qui n'a JAMAIS entendu parler du sujet ?
Il ÉCHOUE s'il contient :
- un nom propre que le grand public ne connaît pas : médicament, molécule, produit, modèle d'IA, mission, télescope, site, entreprise peu connue (connus de tous et donc acceptés : Apple, Google, Samsung, NASA, SpaceX, Mars, la Lune, Alzheimer, Parkinson, Covid, ChatGPT…) ;
- un mot technique, un sigle ou une unité savante (qubit, CRISPR, Gbps, amygdale, supraconducteur, sursaut gamma, colite…), y compris dans le thème ;
- une formulation qui ne dit pas de quoi il s'agit ou à quoi ça sert (« un comprimé fait mieux qu'un placebo » : pour quelle maladie ?).

Mots connus de tous, À GARDER (ce n'est pas du jargon) : ordinateur quantique, intelligence artificielle (IA), ADN, ARN, gène, vaccin, virus, bactérie, cellule, robot, satellite, fusée, astéroïde, galaxie, trou noir, cancer, diabète, batterie, électrique, laser, Einstein…
Ne rends JAMAIS un titre plus vague qu'avant : le résultat concret (chiffre, record, ce qui a été vu ou fait) doit rester. Dans le doute, garde le titre (ok = true).

Si le titre réussit le test : "ok" = true et "titre" = "".
S'il échoue : "ok" = false et "titre" = le titre réécrit, même forme, 12 mots au plus, mots de tous les jours. Remplace le nom inconnu par CE QUE C'EST (« un nouveau médicament », « une IA de Google », « des fossiles chinois », « un télescope spatial »), le jargon par des mots simples ou une comparaison parlante. Le thème aussi doit être simple (« Intestin » plutôt que « Colite », « Espace » plutôt que « Sursauts gamma »).
Reste EXACT : n'invente rien, n'exagère rien, garde les nuances (« chez la souris », « possible »). Appuie-toi sur le résumé fourni.

Exemples :
« Diabète : le retatrutide fait mieux que l'Ozempic » → « Diabète : un nouveau médicament fait mieux que le traitement de référence »
« Colite : un comprimé fait mieux qu'un placebo » → « Intestin : un comprimé apaise une maladie inflammatoire de l'intestin »
« Sursauts gamma : une explosion dure 27 jours, un record » → « Espace : une explosion cosmique dure 27 jours, du jamais vu »
« Internet : un test envoie plus de 750 Gbps de Kobe à Chiba » → « Internet : une connexion 750 fois plus rapide qu'une fibre à la maison »
Déjà bons (ok) : « Smartphones : Apple lance en magasin son premier iPhone pliable » ; « Cancer : une prise de sang repère les patients à risque de rechute ».

Réponds uniquement avec le JSON demandé, une entrée par titre, avec le même numéro « n »."""

SCHEMA = {
    "type": "object",
    "properties": {"titres": {"type": "array", "items": {
        "type": "object",
        "properties": {"n": {"type": "integer"}, "ok": {"type": "boolean"}, "titre": {"type": "string"}},
        "required": ["n", "ok", "titre"], "additionalProperties": False}}},
    "required": ["titres"], "additionalProperties": False,
}


def _json(texte: str) -> dict:
    texte = (texte or "").strip()
    d, f = texte.find("{"), texte.rfind("}")
    try:
        return json.loads(texte[d:f + 1]) if 0 <= d < f else {}
    except json.JSONDecodeError:
        return {}


def _valide(titre: str) -> bool:
    t = " ".join(titre.split()).rstrip(".")
    return " : " in t and 4 <= len(t.split()) <= MAX_MOTS and len(t) <= 110


def _resume(f: dict) -> str:
    texte = f.get("decouverte") or f.get("summary") or ""
    return " ".join(texte.split()[:45])


def relire(client, fiches: list[dict], log) -> tuple[list[dict], float]:
    """Relit les titres ; met à jour fiche["title"] (et garde l'ancien dans
    fiche["_ancien_titre"]) pour ceux qui échouent. Renvoie (fiches changées, coût $).
    Ne lève jamais d'erreur : en cas de souci, les titres restent tels quels."""
    changees, t_in, t_out = [], 0, 0
    for d in range(0, len(fiches), PAQUET):
        paquet = fiches[d:d + PAQUET]
        lignes = [{"n": i, "titre": f.get("title", ""), "resume": _resume(f)} for i, f in enumerate(paquet)]
        try:
            rep = client.messages.create(
                model=MODELE, max_tokens=6000,
                system=[{"type": "text", "text": CONSIGNE, "cache_control": {"type": "ephemeral"}}],
                messages=[{"role": "user", "content": json.dumps({"titres": lignes}, ensure_ascii=False)}],
                output_config={"format": {"type": "json_schema", "schema": SCHEMA}},
            )
            u = rep.usage
            t_in += (u.input_tokens or 0) + (getattr(u, "cache_read_input_tokens", 0) or 0) \
                + (getattr(u, "cache_creation_input_tokens", 0) or 0)
            t_out += u.output_tokens or 0
            data = _json("".join(b.text for b in rep.content if getattr(b, "type", "") == "text"))
        except Exception as ex:
            log(f"  ⚠ relecture des titres impossible ({str(ex)[:120]}) : titres gardés tels quels")
            continue
        for x in data.get("titres") or []:
            try:
                n = int(x.get("n"))
            except (TypeError, ValueError):
                continue
            if not 0 <= n < len(paquet) or x.get("ok") is not False:
                continue
            nouveau = " ".join(str(x.get("titre", "")).split()).rstrip(".")
            f = paquet[n]
            if _valide(nouveau) and nouveau != f.get("title"):
                f["_ancien_titre"] = f.get("title", "")
                f["title"] = nouveau
                changees.append(f)
    return changees, (t_in * PRIX[0] + t_out * PRIX[1]) / 1e6


def passage_agent(db, client, fiches: list[dict], log) -> tuple[int, float]:
    """Appelé par main.py sur les fiches du passage, AVANT traductions et notifications."""
    fiches = [f for f in fiches if f.get("id")]
    if not fiches:
        return 0, 0.0
    changees, cout = relire(client, fiches, log)
    for f in changees:
        try:
            r = requests.patch(db.base, headers=dict(db.headers, Prefer="return=minimal"), timeout=30,
                               params={"id": f"eq.{f['id']}"}, json={"title": f["title"]})
            if r.status_code >= 300:
                raise RuntimeError(r.text[:120])
            log(f"  ✎ titre simplifié : « {f['_ancien_titre']} » → « {f['title']} »")
        except Exception as ex:
            f["title"] = f.pop("_ancien_titre")
            log(f"  ⚠ titre non modifié ({str(ex)[:100]})")
    return len(changees), cout


CONSIGNE_CORRECTION = """Tu corriges des titres de NovaSTEM (application d'avancées scientifiques et technologiques pour le grand public).

Pour chaque fiche, on te donne le titre D'ORIGINE, sa version SIMPLIFIÉE (écrite pour être comprise par quelqu'un qui ne connaît pas le sujet) et le résumé. La version simplifiée a parfois été trop loin :
- elle a retiré des mots que tout le monde connaît (ordinateur quantique, IA, ADN, ARN, gène, vaccin, virus, robot, satellite, astéroïde, trou noir, Einstein…) : remets-les (« Ordinateurs quantiques » et non « Ordinateurs ») ;
- elle est devenue vague et a perdu le résultat concret (chiffre, record, ce qui a été vu ou fait) : rends-le.
Garde la simplification quand elle est bonne (nom propre inconnu remplacé par ce que c'est, jargon remplacé).

Donne pour chaque fiche le TITRE FINAL : forme « Thème : phrase », 12 mots au plus, sans point final, exact (n'invente rien). Si la version simplifiée est déjà la meilleure, renvoie-la telle quelle.
Réponds uniquement avec le JSON demandé, une entrée par fiche, avec le même numéro « n »."""

SCHEMA_CORRECTION = {
    "type": "object",
    "properties": {"titres": {"type": "array", "items": {
        "type": "object", "properties": {"n": {"type": "integer"}, "titre": {"type": "string"}},
        "required": ["n", "titre"], "additionalProperties": False}}},
    "required": ["titres"], "additionalProperties": False,
}


def corriger(db, client, log) -> int:
    """Reprend les titres listés dans titres_reecrits.md (avant → après) : remet les mots
    connus de tous et la précision perdue. Retraduit les titres modifiés."""
    import traduction
    paires = []
    for ligne in open("titres_reecrits.md", encoding="utf-8"):
        morceaux = [m.strip() for m in ligne.strip().strip("|").split("|")]
        if len(morceaux) == 2 and " : " in morceaux[1] and morceaux[0] != "Avant":
            paires.append(tuple(morceaux))
    r = requests.get(db.base, headers=db.headers, timeout=60, params={
        "select": "id,title,summary,avant,decouverte,apres,mots,traductions", "limit": "5000"})
    r.raise_for_status()
    par_titre = {f["title"]: f for f in r.json()}
    fiches = []
    for avant, apres in paires:
        f = par_titre.get(apres)
        if f:
            f["_origine"] = avant
            fiches.append(f)
    log(f"▶ {len(fiches)} titre(s) réécrit(s) à vérifier (sur {len(paires)} dans la liste)")
    changees, t_in, t_out = [], 0, 0
    for d in range(0, len(fiches), PAQUET):
        paquet = fiches[d:d + PAQUET]
        lignes = [{"n": i, "origine": f["_origine"], "simplifie": f["title"], "resume": _resume(f)}
                  for i, f in enumerate(paquet)]
        rep = client.messages.create(
            model=MODELE, max_tokens=6000, system=CONSIGNE_CORRECTION,
            messages=[{"role": "user", "content": json.dumps({"fiches": lignes}, ensure_ascii=False)}],
            output_config={"format": {"type": "json_schema", "schema": SCHEMA_CORRECTION}},
        )
        t_in += rep.usage.input_tokens or 0
        t_out += rep.usage.output_tokens or 0
        for x in _json("".join(b.text for b in rep.content if getattr(b, "type", "") == "text")).get("titres") or []:
            try:
                n = int(x.get("n"))
            except (TypeError, ValueError):
                continue
            nouveau = " ".join(str(x.get("titre", "")).split()).rstrip(".")
            if 0 <= n < len(paquet) and _valide(nouveau) and nouveau != paquet[n]["title"]:
                f = paquet[n]
                f["_ancien_titre"], f["title"] = f["title"], nouveau
                changees.append(f)
    lignes_md = ["# Titres corrigés (mots connus remis, précision rendue)", "",
                 "| Origine | Simplifié | Final |", "|---|---|---|"]
    for f in changees:
        f.setdefault("traductions", {}).pop("en", None)
        r = requests.patch(db.base, headers=dict(db.headers, Prefer="return=minimal"), timeout=30,
                           params={"id": f"eq.{f['id']}"}, json={"title": f["title"], "traductions": f["traductions"]})
        if r.status_code < 300:
            lignes_md.append(f"| {f['_origine']} | {f['_ancien_titre']} | {f['title']} |")
            log(f"  ✎ « {f['_ancien_titre']} » → « {f['title']} »")
            if os.environ.get("GITHUB_ACTIONS"):
                print(f"::notice title=Titre corrigé::{f['_ancien_titre']} → {f['title']}", flush=True)
    n_trad, cout_trad = traduction.traduire(client, changees, log,
                                            sauver=lambda f: traduction.enregistrer(db, f), fils=4) if changees else (0, 0.0)
    cout = (t_in * PRIX[0] + t_out * PRIX[1]) / 1e6 + cout_trad
    lignes_md.insert(2, f"{len(changees)} titre(s) corrigé(s) sur {len(fiches)}, {n_trad} retraduit(s), coût {cout:.4f} $.")
    lignes_md.insert(3, "")
    open("titres_corriges.md", "w", encoding="utf-8").write("\n".join(lignes_md) + "\n")
    log(f"✔ {len(changees)} titre(s) corrigé(s), {n_trad} retraduit(s), coût {cout:.4f} $")
    if os.environ.get("GITHUB_ACTIONS"):
        print(f"::notice title=Titres corrigés::{len(changees)} sur {len(fiches)}, coût {cout:.4f} $", flush=True)
    return 0


def main() -> int:
    """Workflow « Réécrire les titres » : toutes les fiches déjà publiées."""
    from anthropic import Anthropic
    from main import Supabase
    import traduction

    def log(m):
        print(m, flush=True)

    for var in ("ANTHROPIC_API_KEY", "SUPABASE_URL", "SUPABASE_SECRET_KEY"):
        if not os.environ.get(var):
            log(f"❌ Secret manquant : {var}")
            return 1
    db = Supabase(os.environ["SUPABASE_URL"], os.environ["SUPABASE_SECRET_KEY"])
    if os.environ.get("MODE") == "corriger":
        return corriger(db, Anthropic(), log)
    avec_trad = True
    r = requests.get(db.base, headers=db.headers, timeout=60, params={
        "select": "id,title,summary,avant,decouverte,apres,mots,traductions", "order": "created_at.desc",
        "limit": "5000"})
    if r.status_code == 400 and "traductions" in r.text:
        avec_trad = False
        r = requests.get(db.base, headers=db.headers, timeout=60, params={
            "select": "id,title,summary,decouverte", "order": "created_at.desc", "limit": "5000"})
    r.raise_for_status()
    fiches = r.json()
    log(f"▶ {len(fiches)} fiche(s) à relire (plafond de sécurité : {PLAFOND_COUT:.2f} $)")
    client, debut = Anthropic(), time.time()
    changees, cout = [], 0.0
    for d in range(0, len(fiches), 200):
        if cout > PLAFOND_COUT:
            log("⚠ Plafond de coût atteint : relancer le workflow pour la suite.")
            break
        c, k = relire(client, fiches[d:d + 200], log)
        changees += c
        cout += k
    for f in changees:
        try:
            corps = {"title": f["title"]}
            if avec_trad and isinstance(f.get("traductions"), dict):
                f["traductions"].pop("en", None)        # traduction à refaire avec le nouveau titre
                corps["traductions"] = f["traductions"]
            r = requests.patch(db.base, headers=dict(db.headers, Prefer="return=minimal"), timeout=30,
                               params={"id": f"eq.{f['id']}"}, json=corps)
            if r.status_code >= 300:
                raise RuntimeError(r.text[:120])
            log(f"  ✎ « {f['_ancien_titre']} » → « {f['title']} »")
        except Exception as ex:
            log(f"  ⚠ non modifié ({str(ex)[:100]}) : {f['_ancien_titre']}")
    n_trad, cout_trad = 0, 0.0
    if avec_trad and changees:
        log(f"\nTraduction des {len(changees)} titre(s) réécrit(s)…")
        n_trad, cout_trad = traduction.traduire(client, changees, log,
                                                sauver=lambda f: traduction.enregistrer(db, f), fils=4)
    log(f"\n✔ {len(changees)} titre(s) réécrit(s) sur {len(fiches)} en {int(time.time() - debut)} s ; "
        f"{n_trad} retraduit(s) ; coût estimé {cout + cout_trad:.4f} $")
    try:   # liste complète, enregistrée dans le repo par le workflow (agent/titres_reecrits.md)
        with open("titres_reecrits.md", "w", encoding="utf-8") as fic:
            fic.write(f"# Titres réécrits (test du passant)\n\n{len(changees)} titre(s) réécrit(s) sur {len(fiches)}, "
                      f"coût {cout + cout_trad:.4f} $.\n\n| Avant | Après |\n|---|---|\n")
            for f in changees:
                fic.write(f"| {f['_ancien_titre']} | {f['title']} |\n")
    except Exception:
        pass
    if os.environ.get("GITHUB_ACTIONS"):
        print(f"::notice title=Titres::{len(changees)} titre(s) réécrit(s) sur {len(fiches)}, "
              f"{n_trad} retraduit(s), coût {cout + cout_trad:.4f} $", flush=True)
        for f in changees[:40]:
            print(f"::notice title=Titre réécrit::{f['_ancien_titre']} → {f['title']}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
