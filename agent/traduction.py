# =====================================================================
# TRADUCTION DES FICHES — NovaSTEM (31/10/2026)
# ---------------------------------------------------------------------
# Claude traduit chaque fiche (titre, « Avant », « La découverte »,
# « Et après ? », mots à connaître) UNE FOIS, juste après sa création.
# Les traductions sont rangées dans la colonne « traductions » de la base
# (migration 006) : le téléphone les affiche telles quelles, tout de suite.
# Pour les langues non traduites ici, le téléphone traduit lui-même (ML Kit).
#
# Utilisé de deux façons :
#  - par l'agent (main.py), à chaque passage : les nouvelles fiches, plus
#    quelques anciennes fiches encore sans traduction (rattrapage) ;
#  - seul (« python traduction.py », workflow « Traduire les fiches ») :
#    toutes les fiches existantes qui n'ont pas encore leur traduction.
# =====================================================================

# ------------------------- RÉGLAGES ----------------------------------
# Langues traduites par Claude (code → nom en français, pour la consigne).
# Pour ajouter une langue (décision de Maxime, d'après les statistiques) :
# ajouter une ligne, par ex. "es": "espagnol", puis lancer le workflow
# « Traduire les fiches » pour les fiches déjà publiées.
LANGUES = {
    "en": "anglais (américain)",
}
MODELE = "claude-haiku-5-5"        # économique, très bon en traduction
PRIX = (0.10, 0.50)                # $ par million de tokens (entrée, sortie), vérifié le 31/10/2026
PAQUET = 6                          # fiches par appel à Claude
RATTRAPAGE_PAR_PASSAGE = 30         # anciennes fiches sans traduction, traduites à chaque passage de l'agent
PLAFOND_COUT_RATTRAPAGE = 1.00      # $ : le workflow « Traduire les fiches » s'arrête au-delà
# ---------------------------------------------------------------------

import json
import os
import sys
import time
from concurrent.futures import ThreadPoolExecutor

import requests

import economie

CHAMPS = ("title", "summary", "avant", "decouverte", "apres")

CONSIGNE = """Tu es le traducteur de NovaSTEM, une application qui présente les avancées scientifiques et technologiques du moment à un large public. Tu traduis du français vers l'{langue} des fiches écrites pour un lycéen curieux.

Règles :
- Fidélité totale : mêmes faits, mêmes chiffres, mêmes nuances et précautions (« pourrait », « chez la souris », « premiers résultats »…). N'ajoute rien, n'enlève rien, n'exagère rien.
- Même ton simple : phrases courtes, mots de tous les jours, comparaisons concrètes. Écris comme un journaliste scientifique dont c'est la langue maternelle, pas mot à mot.
- Titre : garde la forme « Thème : sujet + verbe + complément », sans point final, 12 mots au plus. Applique la ponctuation et les majuscules normales de la langue cible (en anglais : « Space: … », deux-points collés au mot, majuscule seulement au premier mot du thème et du sujet et aux noms propres).
- Nombres et unités : garde le système métrique ; écris les nombres à la manière de la langue cible (en anglais : 3.5 et 12,000).
- Noms propres, médicaments, missions, entreprises, produits : tels quels ; un organisme qui a un nom officiel dans la langue cible prend ce nom (ex. « Agence spatiale européenne » → « European Space Agency »).
- Mots à connaître : traduis le mot (au singulier, avec une majuscule initiale) et sa définition ; même nombre de mots, même ordre.
- Un champ vide en entrée reste vide en sortie.

Tu reçois une liste de fiches numérotées (« n »). Réponds uniquement avec le JSON demandé : une entrée par fiche, avec le même « n »."""

SCHEMA = {
    "type": "object",
    "properties": {"fiches": {"type": "array", "items": {
        "type": "object",
        "properties": {
            "n": {"type": "integer"},
            **{c: {"type": "string"} for c in CHAMPS},
            "mots": {"type": "array", "items": {
                "type": "object",
                "properties": {"mot": {"type": "string"}, "definition": {"type": "string"}},
                "required": ["mot", "definition"], "additionalProperties": False}},
        },
        "required": ["n", *CHAMPS, "mots"], "additionalProperties": False}}},
    "required": ["fiches"], "additionalProperties": False,
}


class ColonneAbsente(Exception):
    """La migration 006 n'a pas encore été lancée dans Supabase."""


def _lire_json(texte: str) -> dict:
    texte = (texte or "").strip()
    debut, fin = texte.find("{"), texte.rfind("}")
    try:
        return json.loads(texte[debut:fin + 1]) if 0 <= debut < fin else {}
    except json.JSONDecodeError:
        return {}


def _propre(x) -> str:
    return " ".join(str(x or "").split())


def manquantes(db, limite: int) -> list[dict]:
    """Fiches (les plus récentes d'abord) auxquelles il manque au moins une langue."""
    r = requests.get(db.base, headers=db.headers, timeout=60, params={
        "select": "id,title,summary,avant,decouverte,apres,mots,traductions",
        "order": "created_at.desc", "limit": "5000"})
    if r.status_code == 400 and "traductions" in r.text:
        raise ColonneAbsente()
    r.raise_for_status()
    res = []
    for f in r.json():
        t = f.get("traductions") or {}
        if any(code not in t for code in LANGUES):
            f["traductions"] = t
            res.append(f)
            if len(res) >= limite:
                break
    return res


def enregistrer(db, fiche: dict) -> None:
    r = requests.patch(db.base, headers=dict(db.headers, Prefer="return=minimal"), timeout=30,
                       params={"id": f"eq.{fiche['id']}"}, json={"traductions": fiche["traductions"]})
    if r.status_code == 400 and "traductions" in r.text:
        raise ColonneAbsente()
    if r.status_code >= 300:
        raise RuntimeError(f"Supabase {r.status_code} : {r.text[:150]}")


def _entree(n: int, f: dict) -> dict:
    nouveau = bool(_propre(f.get("decouverte")))
    return {
        "n": n,
        "title": _propre(f.get("title")),
        # Fiches d'avant le 21/10 : un seul résumé. Sinon les trois parties suffisent.
        "summary": "" if nouveau else _propre(f.get("summary")),
        "avant": _propre(f.get("avant")),
        "decouverte": _propre(f.get("decouverte")),
        "apres": _propre(f.get("apres")),
        "mots": [{"mot": _propre(m.get("mot")), "definition": _propre(m.get("definition"))}
                 for m in (f.get("mots") or []) if isinstance(m, dict)],
    }


def _traduire_paquet(client, fiches: list[dict], code: str) -> tuple[dict[int, dict], int, int]:
    """Traduit un paquet de fiches dans une langue. Renvoie ({n: traduction}, tokens entrée, sortie)."""
    entrees = [_entree(i, f) for i, f in enumerate(fiches)]
    rep = client.messages.create(
        model=MODELE, max_tokens=12000,
        system=[{"type": "text", "text": CONSIGNE.format(langue=LANGUES[code]),
                 "cache_control": {"type": "ephemeral"}}],
        messages=[{"role": "user", "content": json.dumps({"fiches": entrees}, ensure_ascii=False)}],
        output_config={"format": {"type": "json_schema", "schema": SCHEMA}},
        **economie.PARAMS,
    )
    u = rep.usage
    entree = (u.input_tokens or 0) + (getattr(u, "cache_creation_input_tokens", 0) or 0) \
        + (getattr(u, "cache_read_input_tokens", 0) or 0)
    texte = "".join(b.text for b in rep.content if getattr(b, "type", "") == "text")
    data = _lire_json(texte)
    res = {}
    for t in data.get("fiches") or []:
        try:
            n = int(t.get("n"))
        except (TypeError, ValueError):
            continue
        if not (0 <= n < len(fiches)) or not _propre(t.get("title")):
            continue
        orig = entrees[n]
        trad = {c: _propre(t.get(c)) if orig[c] else "" for c in CHAMPS}
        trad["title"] = trad["title"].rstrip(".")
        if orig["decouverte"]:
            if not trad["decouverte"]:
                continue   # traduction incomplète : on réessaiera plus tard
            trad["summary"] = " ".join(x for x in (trad["avant"], trad["decouverte"], trad["apres"]) if x)
        elif orig["summary"] and not trad["summary"]:
            continue
        mots = [m for m in (t.get("mots") or []) if isinstance(m, dict)]
        trad["mots"] = [{"mot": _propre(m.get("mot"))[:60], "definition": _propre(m.get("definition"))[:300]}
                        for m in mots[:len(orig["mots"])] if _propre(m.get("mot"))]
        if len(trad["mots"]) != len(orig["mots"]):
            trad["mots"] = []   # mots incomplets : le téléphone traduira lui-même ces mots-là
            trad["mots_incomplets"] = True
        res[n] = {k: v for k, v in trad.items() if v or k == "mots"}
    return res, entree, u.output_tokens or 0


def traduire(client, fiches: list[dict], log, sauver=None, plafond: float | None = None,
             fils: int = 1) -> tuple[int, float]:
    """Traduit les fiches dans toutes les LANGUES qui leur manquent.
    Ajoute chaque traduction dans fiche["traductions"][code] ; si [sauver] est
    donné, il est appelé après chaque fiche complétée. Renvoie (fiches traduites, coût $)."""
    travaux = []
    for code in LANGUES:
        a_faire = [f for f in fiches if code not in (f.get("traductions") or {})]
        travaux += [(code, a_faire[i:i + PAQUET]) for i in range(0, len(a_faire), PAQUET)]
    tokens = {"in": 0, "out": 0}
    traduites, erreurs = set(), 0

    def cout() -> float:
        return (tokens["in"] * PRIX[0] + tokens["out"] * PRIX[1]) / 1e6

    def un(travail):
        code, paquet = travail
        if plafond is not None and cout() > plafond:
            return code, paquet, None, 0, 0
        for essai in range(3):
            try:
                return (code, paquet, *_traduire_paquet(client, paquet, code))
            except Exception as ex:
                if essai == 2:
                    return code, paquet, ex, 0, 0
                time.sleep(5 * (essai + 1))

    with ThreadPoolExecutor(max_workers=max(1, fils)) as pool:
        for code, paquet, res, t_in, t_out in pool.map(un, travaux):
            tokens["in"] += t_in
            tokens["out"] += t_out
            if res is None:
                continue          # plafond de coût atteint
            if isinstance(res, Exception):
                erreurs += 1
                log(f"  ⚠ traduction ({code}) en erreur : {str(res)[:150]}")
                continue
            for n, trad in res.items():
                f = paquet[n]
                f.setdefault("traductions", {})[code] = trad
                if sauver:
                    try:
                        sauver(f)
                    except ColonneAbsente:
                        raise
                    except Exception as ex:
                        erreurs += 1
                        log(f"  ⚠ traduction non enregistrée ({f.get('title', '')[:50]}) : {str(ex)[:120]}")
                        continue
                traduites.add(id(f))
    if erreurs:
        log(f"  ({erreurs} erreur(s) de traduction : ces fiches seront reprises au prochain passage)")
    return len(traduites), cout()


def passage_agent(db, client, nouvelles: list[dict], log) -> tuple[int, int, float]:
    """Appelé par main.py après l'ajout des fiches, AVANT les notifications
    (pour qu'elles partent aussi traduites). Traduit les nouvelles fiches et
    quelques anciennes encore sans traduction. Renvoie (nouvelles traduites,
    anciennes traduites, coût $). Ne lève jamais d'erreur."""
    nouvelles = [f for f in nouvelles if f.get("id")]
    for f in nouvelles:
        f.setdefault("traductions", {})
    try:
        ids = {str(f["id"]) for f in nouvelles}
        anciennes = [f for f in manquantes(db, RATTRAPAGE_PAR_PASSAGE + len(ids)) if str(f["id"]) not in ids]
        anciennes = anciennes[:RATTRAPAGE_PAR_PASSAGE]
        n, cout = traduire(client, nouvelles + anciennes, log, sauver=lambda f: enregistrer(db, f))
        nb_nouv = sum(1 for f in nouvelles if all(c in f["traductions"] for c in LANGUES))
        return nb_nouv, max(0, n - nb_nouv), cout
    except ColonneAbsente:
        log("⚠ Traductions : colonne « traductions » absente (lancer database/migration_006_traductions_langues.sql "
            "dans Supabase). Les fiches restent en français ; le téléphone traduit lui-même.")
    except Exception as ex:
        log(f"⚠ Traductions impossibles ce passage ({str(ex)[:150]}) : elles seront faites au prochain.")
    return 0, 0, 0.0


def main() -> int:
    """Workflow « Traduire les fiches » : toutes les fiches qui n'ont pas encore leur traduction."""
    from anthropic import Anthropic
    from main import Supabase

    def log(m):
        print(m, flush=True)

    for var in ("ANTHROPIC_API_KEY", "SUPABASE_URL", "SUPABASE_SECRET_KEY"):
        if not os.environ.get(var):
            log(f"❌ Secret manquant : {var}")
            return 1
    try:
        maximum = int(os.environ.get("MAXIMUM") or 3000)
    except ValueError:
        maximum = 3000
    db = Supabase(os.environ["SUPABASE_URL"], os.environ["SUPABASE_SECRET_KEY"])
    try:
        fiches = manquantes(db, maximum)
    except ColonneAbsente:
        log("❌ Colonne « traductions » absente : lance d'abord database/migration_006_traductions_langues.sql "
            "dans Supabase (SQL Editor).")
        return 1
    log(f"▶ {len(fiches)} fiche(s) à traduire en : {', '.join(LANGUES)} "
        f"(plafond de sécurité : {PLAFOND_COUT_RATTRAPAGE:.2f} $)")
    debut = time.time()
    try:
        n, cout = traduire(Anthropic(), fiches, log, sauver=lambda f: enregistrer(db, f),
                           plafond=PLAFOND_COUT_RATTRAPAGE, fils=4)
    except ColonneAbsente:
        log("❌ Colonne « traductions » absente (migration 006).")
        return 1
    restantes = len(fiches) - n
    try:  # les événements « À venir » aussi (migration 015)
        from datetime import date, timedelta
        import traduction_a_venir
        cout += traduction_a_venir.passage(db, Anthropic(), log, (date.today() - timedelta(days=7)).isoformat(), maximum=400)
    except Exception as ex:
        log(f"⚠ À venir : traductions ignorées ({ex.__class__.__name__})")
    log(f"\n✔ {n} fiche(s) traduite(s) en {int(time.time() - debut)} s — coût estimé : {cout:.4f} $"
        + (f" — {restantes} restante(s) (relancer le workflow)" if restantes else ""))
    if os.environ.get("GITHUB_ACTIONS"):
        print(f"::notice title=Traductions::{n} fiche(s) traduite(s), {restantes} restante(s), "
              f"coût {cout:.4f} $", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
