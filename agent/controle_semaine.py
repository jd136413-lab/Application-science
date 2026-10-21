"""Contrôle hebdomadaire : les grands sujets de la semaine sont-ils dans l'app ?

1. Lit les titres des 7 derniers jours dans des sources de référence
   (grands médias et revues : BBC, Guardian, Nature, Science…).
2. Lit les fiches publiées dans l'app pendant la même semaine.
3. Un seul appel à Claude (Haiku, ≈ 0,002 $) repère les grands sujets de la
   semaine (repris par plusieurs sources de référence, ou clairement majeurs)
   et dit pour chacun s'il est couvert par une fiche de l'app.
4. Résultat : annotations GitHub (« 12 grands sujets : 10 couverts, 2 ratés »)
   et résumé dans la page de l'exécution.

Lancé automatiquement le dimanche soir à la fin du passage de l'agent
(voir agent.yml), ou à la main (case « Contrôle de la semaine »).
"""
import json
import os
import re
import sys
from datetime import datetime, timedelta, timezone

import feedparser
import requests
from anthropic import Anthropic

MODELE = "claude-haiku-5-5"
PRIX = (0.10, 0.50)   # $ par million de jetons (entrée, sortie)
UA = "Mozilla/5.0 (compatible; ApplicationScienceBot/1.0)"
MAINTENANT = datetime.now(timezone.utc)
DEPUIS = MAINTENANT - timedelta(days=7)

# Sources de référence : celles qui couvrent les grands sujets de la semaine
REFERENCES = [
    ("BBC Science", "https://feeds.bbci.co.uk/news/science_and_environment/rss.xml"),
    ("The Guardian Science", "https://www.theguardian.com/science/rss"),
    ("Nature", "https://www.nature.com/nature.rss"),
    ("Science", "https://www.science.org/rss/news_current.xml"),
    ("Science News", "https://www.sciencenews.org/feed"),
    ("Quanta Magazine", "https://www.quantamagazine.org/feed/"),
    ("Le Monde Sciences", "https://www.lemonde.fr/sciences/rss_full.xml"),
    ("MIT Technology Review", "https://www.technologyreview.com/feed/"),
    ("Wired", "https://www.wired.com/feed/rss"),
    ("IEEE Spectrum", "https://spectrum.ieee.org/feeds/feed.rss"),
    ("TechCrunch", "https://techcrunch.com/feed/"),
    ("Engadget", "https://www.engadget.com/rss.xml"),
]

CONSIGNE = """Tu contrôles une application qui doit présenter les vraies avancées scientifiques et technologiques importantes (découvertes, résultats de recherche, premières, records, missions réussies, produits technologiques réellement nouveaux).

On te donne :
A) les titres de la semaine dans des sources de référence (grands médias et revues), avec la source ;
B) les titres des fiches publiées dans l'application pendant la même semaine (en français).

1. Repère les GRANDS SUJETS de la semaine qui sont de vraies avancées : repris par au moins 2 sources de référence différentes, ou clairement majeurs (première mondiale, découverte qui fera date, produit qui change un secteur). Ignore la politique, l'économie, les procès, les nominations, les opinions, les explications, les rumeurs et les missions seulement à venir.
2. Pour chaque grand sujet, dis s'il est couvert par une fiche de l'application (même sujet, même formulé autrement ou dans une autre langue) et laquelle.
Renvoie au plus 20 grands sujets, du plus important au moins important. "sujet" : 6 à 12 mots en français."""

SCHEMA = {
    "type": "object",
    "properties": {"sujets": {"type": "array", "items": {
        "type": "object",
        "properties": {
            "sujet": {"type": "string"},
            "sources": {"type": "array", "items": {"type": "string"}},
            "couvert": {"type": "boolean"},
            "fiche": {"type": "string"},
        },
        "required": ["sujet", "sources", "couvert", "fiche"], "additionalProperties": False}}},
    "required": ["sujets"], "additionalProperties": False,
}


def titres_references() -> list[str]:
    lignes = []
    for nom, url in REFERENCES:
        try:
            r = requests.get(url, timeout=30, headers={"User-Agent": UA})
            f = feedparser.parse(r.content)
        except Exception:
            print(f"⚠ {nom} injoignable")
            continue
        for e in f.entries:
            t = e.get("published_parsed") or e.get("updated_parsed")
            if t and datetime(*t[:6], tzinfo=timezone.utc) < DEPUIS:
                continue
            titre = re.sub(r"\s+", " ", e.get("title", "")).strip()
            if titre:
                lignes.append(f"- {titre[:160]} [{nom}]")
    return lignes


def fiches_de_la_semaine() -> list[str]:
    base = os.environ["SUPABASE_URL"].rstrip("/") + "/rest/v1/advances"
    cle = os.environ["SUPABASE_SECRET_KEY"]
    h = {"apikey": cle}
    if cle.startswith("eyJ"):
        h["Authorization"] = f"Bearer {cle}"
    r = requests.get(base, headers=h, timeout=30, params={
        "select": "title,feed,importance", "created_at": f"gte.{DEPUIS.isoformat()}",
        "order": "created_at.desc", "limit": "400"})
    r.raise_for_status()
    return [f"- {x['title']} ({'Sciences' if x.get('feed') == 'science' else 'Technologies'}, {x.get('importance')}★)"
            for x in r.json()]


def main() -> int:
    refs = titres_references()
    fiches = fiches_de_la_semaine()
    print(f"{len(refs)} titres de référence, {len(fiches)} fiches publiées cette semaine.")
    if len(refs) < 10:
        print("::warning title=Contrôle de la semaine::trop peu de titres de référence lus, contrôle annulé")
        return 0
    contenu = ("A) Sources de référence (7 derniers jours) :\n" + "\n".join(refs[:400])
               + "\n\nB) Fiches publiées dans l'application :\n" + ("\n".join(fiches) or "(aucune)"))
    rep = Anthropic().messages.create(
        model=MODELE, max_tokens=4000, system=CONSIGNE,
        messages=[{"role": "user", "content": contenu}],
        output_config={"format": {"type": "json_schema", "schema": SCHEMA}},
    )
    texte = "".join(b.text for b in rep.content if getattr(b, "type", "") == "text")
    try:
        sujets = json.loads(texte).get("sujets", [])
    except Exception:
        m = re.search(r"\{.*\}", texte, re.S)
        sujets = json.loads(m.group(0)).get("sujets", []) if m else []
    cout = (rep.usage.input_tokens * PRIX[0] + rep.usage.output_tokens * PRIX[1]) / 1_000_000
    sources_lues = sorted({re.search(r"\[([^\]]+)\]$", l).group(1) for l in refs if re.search(r"\[([^\]]+)\]$", l)})
    print(f"::warning title=Contrôle — diagnostic::{len(refs)} titres de référence ({len(sources_lues)} sources : "
          f"{', '.join(sources_lues)}) ; {len(fiches)} fiches ; arrêt : {rep.stop_reason} ; "
          f"jetons {rep.usage.input_tokens} → {rep.usage.output_tokens} ; "
          f"blocs : {[getattr(b, 'type', '?') for b in rep.content]} ; début de réponse : {texte[:300]!r}", flush=True)
    couverts = [s for s in sujets if s.get("couvert")]
    rates = [s for s in sujets if not s.get("couvert")]

    print(f"::notice title=Contrôle de la semaine::{len(sujets)} grands sujets : {len(couverts)} couverts, "
          f"{len(rates)} ratés ({len(fiches)} fiches publiées en 7 jours ; coût {cout:.4f} $)", flush=True)
    if rates:
        print("::warning title=Grands sujets ratés::" + "  ||  ".join(
            f"{s['sujet']} ({', '.join(s.get('sources', [])[:4])})" for s in rates), flush=True)
    if couverts:
        print("::notice title=Grands sujets couverts::" + "  ||  ".join(
            f"{s['sujet']} → {s.get('fiche', '')[:80]}" for s in couverts), flush=True)

    fichier = os.environ.get("GITHUB_STEP_SUMMARY")
    if fichier:
        with open(fichier, "a", encoding="utf-8") as f:
            f.write(f"\n## Contrôle de la semaine\n\n{len(sujets)} grands sujets : "
                    f"**{len(couverts)} couverts**, **{len(rates)} ratés**.\n\n")
            for s in sujets:
                f.write(f"- {'✅' if s.get('couvert') else '❌'} {s['sujet']} "
                        f"({', '.join(s.get('sources', []))})"
                        + (f" → {s.get('fiche')}" if s.get("couvert") else "") + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
