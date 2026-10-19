"""Transforme traductions/interface.txt en lib/textes_traduits.dart.

Vérifie au passage que chaque texte a bien ses 19 traductions et que les {n}
sont conservés. Lancé par Claude (ou dans un Codespace) :
    python3 app/traductions/generer.py
"""
from pathlib import Path

LANGUES = "en es pt de it nl pl ru uk tr ar hi bn ur zh ja ko id vi".split()
ICI = Path(__file__).resolve().parent
SOURCE = ICI / "interface.txt"
CIBLE = ICI.parent / "lib" / "textes_traduits.dart"


def lire():
    blocs, cle = {}, None
    for n, ligne in enumerate(SOURCE.read_text(encoding="utf-8").splitlines(), 1):
        ligne = ligne.rstrip()
        if not ligne or ligne.startswith("#"):
            continue
        if ligne.startswith("@ "):
            cle = ligne[2:]
            if cle in blocs:
                raise SystemExit(f"ligne {n} : texte en double « {cle} »")
            blocs[cle] = {}
            continue
        code, _, texte = ligne.partition(" ")
        if cle is None or code not in LANGUES or not texte:
            raise SystemExit(f"ligne {n} illisible : {ligne!r}")
        blocs[cle][code] = texte
    for cle, tr in blocs.items():
        manque = [c for c in LANGUES if c not in tr]
        if manque:
            raise SystemExit(f"« {cle} » : traductions manquantes {manque}")
        if "{n}" in cle:
            sans = [c for c, t in tr.items() if "{n}" not in t]
            if sans:
                raise SystemExit(f"« {cle} » : {{n}} oublié en {sans}")
    return blocs


def dart(s: str) -> str:
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$") + "'"


def main():
    blocs = lire()
    lignes = [
        "// FICHIER GÉNÉRÉ par app/traductions/generer.py à partir de",
        "// app/traductions/interface.txt : ne pas modifier à la main.",
        "",
        "const Map<String, Map<String, String>> textesTraduits = {",
    ]
    for code in LANGUES:
        lignes.append(f"  '{code}': {{")
        for cle, tr in blocs.items():
            lignes.append(f"    {dart(cle)}: {dart(tr[code])},")
        lignes.append("  },")
    lignes.append("};")
    CIBLE.write_text("\n".join(lignes) + "\n", encoding="utf-8")
    print(f"{len(blocs)} textes × {len(LANGUES)} langues → {CIBLE.name}")


if __name__ == "__main__":
    main()
