"""Essai du nouveau format de fiche (plan D, 25/11/2026, accord de Maxime). RIEN n'est publié.

Pour 8 fiches récentes (santé, Terre, maths, espace, solaire, leucémie, fossile, voiture) :
  • ACTUELLE : la fiche telle qu'elle est dans l'app aujourd'hui ;
  • NOUVELLE : rédigée avec redaction_blocs (relevé cité, blocs-questions, relecture), à partir
    du même article lu sur 10 000 caractères.
Un juge (Claude Sonnet, plus exigeant que le rédacteur) lit l'article et les deux fiches, sous des
lettres tirées au hasard (X / Y), et note chacune sur 10 : concret, exactitude, clarté, plaisir de
lecture, note globale ; il liste les erreurs et coche les questions de lecteur auxquelles la fiche
répond (questions préparées par l'atelier du 24/11, dont la réponse est dans l'article).
Résultat : journal + fichier essai_resumes.md (artefact du workflow). Coût prévu ≈ 0,10 $.
NB : Solaire et Leucémie servent d'exemples dans la nouvelle consigne ; leurs notes sont données à part.
"""

import json
import os
import random

import requests
from anthropic import Anthropic

import main as agent
import redaction
import redaction_blocs as rb
import fiche_blocs as fb

PLAFOND = 0.40   # $ : au-delà, on s'arrête
EXEMPLES_CONSIGNE = {"solaire", "leucemie"}
DONNEES = {
 "pancreas": {
  "url": "https://www.theguardian.com/society/2026/nov/20/pill-pancreatic-cancer-breakthrough-daraxonrasib",
  "questions": [
   "Comment agit le médicament (sa cible) ?",
   "Combien de patients ont été traités ?",
   "Comparé à quoi : y a-t-il un groupe témoin ?",
   "Le médicament est-il donné seul ou avec une chimiothérapie ?",
   "Quels effets indésirables ?",
   "Est-il autorisé ou disponible, et où ?"
  ]
 },
 "volcan": {
  "url": "https://www.livescience.com/planet-earth/impossible-volcanic-eruption-spotted-in-deepest-part-of-the-ocean-perplexing-scientists",
  "questions": [
   "Où exactement (nom de la fosse) ?",
   "Pourquoi la pression devrait-elle empêcher une explosion (gaz retenus) ?",
   "Pourquoi aucun volcan n'était attendu à cet endroit ?",
   "Quand et avec quoi les roches ont-elles été observées (robot, année) ?",
   "Combien de sites, sur quelle distance ?",
   "Comment sait-on que l'éruption est plutôt récente (verre qui s'use) ?",
   "Quelles hypothèses pour l'expliquer (fluide supercritique, nouvelle subduction) ?"
  ]
 },
 "riemann": {
  "url": "https://www.sciencenews.org/article/riemann-hypothesis-solved-math-ai",
  "questions": [
   "Que dit l'hypothèse de Riemann, en mots simples ?",
   "Qui a fait la preuve, avec quelle IA ?",
   "Quel a été le rôle de l'humain et celui de l'IA ?",
   "Comment la preuve a-t-elle été vérifiée (logiciel Lean, mathématiciens) ?",
   "A-t-elle été publiée dans une revue ou seulement mise en ligne ?",
   "Qui doute ou conteste ?",
   "Pourquoi est-ce important (résultats qui en dépendent) ?"
  ]
 },
 "trounoir": {
  "url": "https://www.almaobservatory.org/en/press-releases/alma-resolves-the-gravitational-reach-of-a-black-hole-in-the-early-universe/",
  "questions": [
   "Comment pèse-t-on le trou noir (vitesse du gaz près du centre) ?",
   "En quoi est-ce une première, et selon qui ?",
   "Pourquoi la mesure a-t-elle marché ici (rôle de la poussière) ?",
   "Quelle finesse de détail les radiotélescopes atteignent-ils ?",
   "À quelle époque de l'Univers voit-on cette galaxie ?",
   "La masse confirme-t-elle les estimations indirectes (ou la fiche dit-elle que ce n'est pas précisé) ?"
  ]
 },
 "solaire": {
  "url": "https://www.pv-magazine.com/2026/11/19/microquanta-achieves-world-record-efficiency-of-23-9-for-19-48-cm%c2%b2-perovskite-solar-module/",
  "questions": [
   "D'où vient la principale perte entre la cellule et le module ?",
   "Quelle astuce de fabrication, et pourquoi marche-t-elle ?",
   "Quelle taille fait le module, comparé aux panneaux visés ?",
   "Le record précédent cité porte-t-il sur un module comparable (taille) ?",
   "Qui a certifié la mesure ?",
   "Quel effet sur le vieillissement ?",
   "Qui l'a fait, et quel projet industriel ?"
  ]
 },
 "leucemie": {
  "url": "https://www.sciencedaily.com/releases/2026/11/261121221122.htm",
  "questions": [
   "Combien de personnes, avec un groupe témoin ?",
   "Comment date-t-on l'apparition des mutations ?",
   "Les témoins montraient-ils le même phénomène ?",
   "À quelle vitesse les cellules mutées grossissent-elles avec les mutations ?",
   "Pourquoi seulement des femmes ont-elles été étudiées ?",
   "Est-ce une cause ou un simple lien ?",
   "Que peut-on faire en pratique (dépistage, consultation) ?",
   "Dans quelle part des cas les cellules n'étaient visibles que peu avant le diagnostic ?"
  ]
 },
 "taung": {
  "url": "https://www.sciencedaily.com/releases/2026/11/261118065531.htm",
  "questions": [
   "Quel fossile (enfant de Taung, australopithèque) et pourquoi est-il une référence ?",
   "Comment l'ont-ils comparé aux autres fossiles (croissance) ?",
   "Quelle explication climatique proposent-ils ?",
   "Quel âge a le fossile ?",
   "Qu'est-ce que ça change à l'histoire connue de nos ancêtres ?"
  ]
 },
 "byd": {
  "url": "https://electrek.co/2026/11/19/byd-folding-steering-wheel-tai-9-production/",
  "questions": [
   "Comment le volant peut-il se ranger (pas de colonne de direction) ?",
   "Pourquoi maintenant (nouvelle norme chinoise) ?",
   "Est-ce vraiment une première (concurrents cités) ?",
   "Quel prix, pour quelle version (une seule conversion cohérente) ?",
   "Dans quelles conditions se range-t-il ?",
   "Où est-il vendu ?",
   "Quelle durée de vie annonce-t-on pour le mécanisme ?"
  ]
 }
}

CONSIGNE_JUGE = """Tu es rédacteur en chef d'un grand magazine de vulgarisation scientifique, très exigeant. On te donne un article source et deux fiches (X et Y) écrites pour une application qui explique l'actualité scientifique à des lecteurs non spécialistes (lycéens, adultes curieux). Juge-les avec rigueur et impartialité : l'ordre et les lettres sont tirés au hasard.

Pour CHAQUE fiche, note de 1 à 10 :
- "concret" : la fiche transmet-elle vraiment l'information (comment ça marche, comment on le sait, par rapport à quoi, chiffres avec repères) au lieu de survoler ?
- "exactitude" : 10 = aucune erreur ni exagération par rapport à l'article ; enlève des points pour chaque fait faux, déformé, nuance perdue ou lien logique inventé.
- "clarte" : un lycéen comprend-il tout du premier coup (jargon expliqué, phrases simples) ?
- "lecture" : est-ce agréable et efficace à lire sur un téléphone (pas de répétition, pas de remplissage, longueur justifiée, l'essentiel d'abord) ?
- "globale" : ta note d'ensemble.
Liste ses "erreurs" (faits faux ou déformés, avec une courte explication ; liste vide s'il n'y en a pas).
"questions" : les numéros des questions de lecteur auxquelles la fiche répond VRAIMENT (une réponse précise, pas une allusion).
Puis "preferee" : "X", "Y" ou "egal", et "pourquoi" en 2 phrases.

Réponds uniquement avec le JSON demandé."""

SCHEMA_JUGE = {"type": "object", "properties": {
    "fiches": {"type": "array", "items": {"type": "object", "properties": {
        "lettre": {"type": "string", "enum": ["X", "Y"]},
        "concret": {"type": "integer"}, "exactitude": {"type": "integer"}, "clarte": {"type": "integer"},
        "lecture": {"type": "integer"}, "globale": {"type": "integer"},
        "erreurs": {"type": "array", "items": {"type": "string"}},
        "questions": {"type": "array", "items": {"type": "integer"}}},
        "required": ["lettre", "concret", "exactitude", "clarte", "lecture", "globale", "erreurs", "questions"],
        "additionalProperties": False}},
    "preferee": {"type": "string", "enum": ["X", "Y", "egal"]}, "pourquoi": {"type": "string"}},
    "required": ["fiches", "preferee", "pourquoi"], "additionalProperties": False}

CRITERES = ["concret", "exactitude", "clarte", "lecture", "globale"]


def texte_actuelle(f: dict) -> str:
    mots = "; ".join(f"{m.get('mot', '')} : {m.get('definition', '')}" for m in f.get("mots") or [])
    return (f"{f['title']}\n\nAVANT\n{f.get('avant') or ''}\n\n"
            f"{'LA NOUVEAUTÉ' if f.get('feed') == 'tech' else 'LA DÉCOUVERTE'}\n{f.get('decouverte') or ''}\n\n"
            f"ET APRÈS ?\n{f.get('apres') or ''}" + (f"\n\nMots à connaître : {mots}" if mots else ""))


def texte_nouvelle(fiche: dict, fil: str) -> str:
    lignes = [fiche["title"], ""]
    for b in fiche["_base"]["blocs"]:
        if b["cle"] == "chapo":
            lignes += ["EN BREF", b["texte"], ""]
        elif b["cle"] == "en_chiffres":
            lignes += ["EN CHIFFRES"] + [f"- {c['valeur']} : {c['sens']}" for c in b["items"]] + [""]
        elif b["cle"] == "limites":
            lignes += ["CE QU'ON NE SAIT PAS ENCORE"] + [f"- {x}" for x in b["puces"]] + [""]
        else:
            titre = b.get("question") or fb.LIBELLES[b["cle"]][fil == "tech"]
            lignes += [titre.upper() if not b.get("question") else titre, b["texte"], ""]
    mots = "; ".join(f"{m.get('mot', '')} : {m.get('definition', '')}" for m in fiche.get("mots") or [])
    if mots:
        lignes.append(f"Mots à connaître : {mots}")
    return "\n".join(lignes).strip()


def n_mots(t: str) -> int:
    return len(t.split())


def principal() -> int:
    url = os.environ["SUPABASE_URL"].rstrip("/")
    cle = os.environ["SUPABASE_SECRET_KEY"]
    h = {"apikey": cle, "Authorization": f"Bearer {cle}"}
    client = Anthropic()
    haiku, sonnet = agent.MODELES["haiku"], agent.MODELES["sonnet"]
    log = print
    items, lignes_db, arts = [], {}, {}
    for k, d in DONNEES.items():
        r = requests.get(f"{url}/rest/v1/advances", headers=h, timeout=30, params={
            "select": "title,theme,importance,type_etude,feed,family,avant,decouverte,apres,mots,source_name,source_url",
            "source_url": f"eq.{d['url']}", "limit": "1"})
        if not r.ok or not r.json():
            log(f"✗ {k} : fiche introuvable en base")
            continue
        f = r.json()[0]
        art = {"url": d["url"], "title": f["title"], "text": "", "source_name": f["source_name"], "videos": []}
        agent.lire_page(art)
        n = len(art.get("texte_long") or art.get("text", ""))
        log(f"· {k} : article lu, {n} caractères ({art.get('lecture', '?')}, statut {art.get('statut_page')})")
        if n < 1500:
            log(f"  ✗ {k} : article illisible pour l'agent, fiche écartée de l'essai")
            continue
        lignes_db[k], arts[k] = f, art
        items.append((k, art, f["feed"], {"title": f["title"], "theme": f["theme"], "importance": f["importance"],
                                          "type_etude": f.get("type_etude") or ""}))
    res, cout = rb.rediger_lot(client, haiku["id"], haiku["prix"], items, par_lot=True, attente_lot=900, log=log)
    log(f"Rédaction des nouvelles fiches : {len(res)} sur {len(items)}, {cout:.4f} $")
    if cout > PLAFOND:
        log("Plafond dépassé : arrêt avant le jugement.")
        return 1
    # Jugement à l'aveugle
    rnd = random.Random(2511)
    demandes, ordre = {}, {}
    for k, art, fil, _ in items:
        if k not in res:
            continue
        a, n = texte_actuelle(lignes_db[k]), texte_nouvelle(res[k]["fiche"], fil)
        x_est_nouvelle = rnd.random() < 0.5
        ordre[k] = x_est_nouvelle
        x, y = (n, a) if x_est_nouvelle else (a, n)
        qs = "\n".join(f"{i + 1}. {q}" for i, q in enumerate(DONNEES[k]["questions"]))
        contenu = (f"ARTICLE SOURCE ({art.get('source_name', '')})\n{art.get('texte_long') or art.get('text', '')}\n\n"
                   f"QUESTIONS DE LECTEUR\n{qs}\n\nFICHE X\n{x}\n\nFICHE Y\n{y}")
        demandes[k] = dict(model=sonnet["id"], max_tokens=4000, system=CONSIGNE_JUGE,
                           messages=[{"role": "user", "content": contenu}],
                           output_config={"format": {"type": "json_schema", "schema": SCHEMA_JUGE}},
                           **economie_params(sonnet["id"]))
    rep, _ = redaction._appeler(client, demandes, True, 1200, log)
    resultats = {}
    for k in demandes:
        texte, usage, lot, arret = rep.get(k, ("", None, False, "absent"))
        cout += rb._cout(usage, sonnet["prix"], lot)
        j = redaction._json(texte)
        if not j.get("fiches"):
            log(f"✗ {k} : jugement vide ({arret})")
            continue
        par = {x["lettre"]: x for x in j["fiches"]}
        nv, ac = (par.get("X"), par.get("Y")) if ordre[k] else (par.get("Y"), par.get("X"))
        pref = j.get("preferee")
        pref = "egal" if pref == "egal" else ("nouvelle" if (pref == "X") == ordre[k] else "actuelle")
        resultats[k] = {"nouvelle": nv, "actuelle": ac, "preferee": pref, "pourquoi": j.get("pourquoi", ""),
                        "nb_questions": len(DONNEES[k]["questions"]),
                        "mots_actuelle": n_mots(texte_actuelle(lignes_db[k])),
                        "mots_nouvelle": n_mots(texte_nouvelle(res[k]["fiche"], lignes_db[k]["feed"])),
                        "texte_actuelle": texte_actuelle(lignes_db[k]),
                        "texte_nouvelle": texte_nouvelle(res[k]["fiche"], lignes_db[k]["feed"]),
                        "alertes": res[k]["alertes"], "alertes_finales": res[k]["alertes_finales"],
                        "problemes_relecture": res[k]["problemes"], "profil": res[k]["profil"],
                        "releve": res[k]["fiche"].get("releve"), "base": res[k]["fiche"]["_base"]}
    rapport(resultats, cout, log)
    return 0


def economie_params(modele_id):
    import economie
    return economie.params_modele(modele_id)


def moyenne(vals):
    vals = [v for v in vals if isinstance(v, (int, float))]
    return sum(vals) / len(vals) if vals else 0


def rapport(R: dict, cout: float, log) -> None:
    out = ["# Essai du nouveau format de fiche (plan D)", "",
           "Notes sur 10 données par un juge (Claude Sonnet) qui lit l'article et les deux fiches à l'aveugle.", "",
           "| Fiche | Version | Concret | Exactitude | Clarté | Lecture | Globale | Questions | Mots | Erreurs |",
           "|---|---|---|---|---|---|---|---|---|---|"]
    for k, r in R.items():
        for v in ("actuelle", "nouvelle"):
            n = r[v] or {}
            q = f"{len(set(n.get('questions') or []))}/{r['nb_questions']}"
            out.append(f"| {k}{' (exemple)' if k in EXEMPLES_CONSIGNE else ''} | {v} | "
                       + " | ".join(str(n.get(c, '?')) for c in CRITERES)
                       + f" | {q} | {r['mots_' + v]} | {len(n.get('erreurs') or [])} |")
    for groupe, cles in (("Les 6 fiches hors exemples", [k for k in R if k not in EXEMPLES_CONSIGNE]),
                         ("Toutes les fiches", list(R))):
        out += ["", f"## Moyennes : {groupe.lower()} ({len(cles)})", "", "| Version | " + " | ".join(CRITERES) + " | questions répondues | mots | erreurs |",
                "|---|---|---|---|---|---|---|---|---|"]
        for v in ("actuelle", "nouvelle"):
            ns = [R[k][v] or {} for k in cles]
            qtot = sum(R[k]["nb_questions"] for k in cles)
            qok = sum(len(set((R[k][v] or {}).get("questions") or [])) for k in cles)
            out.append(f"| {v} | " + " | ".join(f"{moyenne([n.get(c) for n in ns]):.1f}" for c in CRITERES)
                       + f" | {qok}/{qtot} ({100 * qok / max(qtot, 1):.0f} %) | {moyenne([R[k]['mots_' + v] for k in cles]):.0f}"
                       + f" | {sum(len(n.get('erreurs') or []) for n in ns)} |")
        prefs = [R[k]["preferee"] for k in cles]
        out.append(f"\nPréférée par le juge : nouvelle {prefs.count('nouvelle')}, actuelle {prefs.count('actuelle')}, égalité {prefs.count('egal')}.")
    out += ["", f"Coût total de l'essai : {cout:.4f} $", ""]
    for k, r in R.items():
        out += ["---", f"## {k} (profil {r['profil']})", "",
                f"**Avis du juge** (préférée : {r['preferee']}) : {r['pourquoi']}", ""]
        for v in ("actuelle", "nouvelle"):
            n = r[v] or {}
            out += [f"### Version {v} ({r['mots_' + v]} mots, note globale {n.get('globale', '?')}/10)", "", "```",
                    r["texte_" + v], "```"]
            if n.get("erreurs"):
                out += ["Erreurs relevées par le juge :"] + [f"- {e}" for e in n["erreurs"]]
            out.append("")
        out += ["Alertes du programme (premier jet) : " + ("; ".join(r["alertes"]) or "aucune"),
                "", "Défauts corrigés par la relecture : " + ("; ".join(f"{p['type']} : {p['extrait'][:80]}" for p in r["problemes_relecture"]) or "aucun"),
                "", "Alertes restantes : " + ("; ".join(r["alertes_finales"]) or "aucune"), ""]
    md = "\n".join(out)
    open("essai_resumes.md", "w", encoding="utf-8").write(md)
    json.dump(R, open("essai_resumes.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    log(md)
    toutes = [R[k] for k in R]
    if toutes:
        log(f"::notice::Nouvelle fiche : globale {moyenne([(r['nouvelle'] or {}).get('globale') for r in toutes]):.1f}/10 "
            f"contre {moyenne([(r['actuelle'] or {}).get('globale') for r in toutes]):.1f} ; coût {cout:.3f} $")


if __name__ == "__main__":
    raise SystemExit(principal())
