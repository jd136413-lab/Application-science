"""Repartir à zéro (demande de Maxime du 25/11/2026, confirmée par « OUI ») :
  • supprime TOUTES les fiches de l'app (table advances) ; les cartes « À venir » restent ;
  • vide la mémoire du tri (les articles déjà jugés), pour que l'agent reprenne les meilleurs
    articles des 7 derniers jours et les réécrive au nouveau format (plan D) ;
  • garde dans cette mémoire les dépenses du mois et les réglages (clés commençant par « _ »).
Lancé une seule fois par le workflow « Repartir à zéro » (mot de confirmation : OUI).
"""

import json
import os

import requests

url = os.environ["SUPABASE_URL"].rstrip("/") + "/rest/v1/advances"
cle = os.environ["SUPABASE_SECRET_KEY"]
h = {"apikey": cle, "Authorization": f"Bearer {cle}"}

r = requests.get(url, headers=dict(h, Prefer="count=exact", Range="0-0"), params={"select": "id"}, timeout=30)
avant = r.headers.get("content-range", "?").split("/")[-1]
print(f"Fiches avant : {avant}")
r = requests.delete(url, headers=dict(h, Prefer="return=minimal"), params={"id": "not.is.null"}, timeout=120)
print(f"Suppression : HTTP {r.status_code} {r.text[:200]}")
r.raise_for_status()
r = requests.get(url, headers=dict(h, Prefer="count=exact", Range="0-0"), params={"select": "id"}, timeout=30)
print(f"Fiches après : {r.headers.get('content-range', '?').split('/')[-1]}")

try:
    m = json.load(open("memoire_tri.json", encoding="utf-8"))
except Exception:
    m = {}
gardees = {k: v for k, v in m.items() if k.startswith("_")}
print(f"Mémoire du tri : {len(m) - len(gardees)} article(s) oublié(s), gardé : {sorted(gardees)}")
json.dump(gardees, open("memoire_tri.json", "w", encoding="utf-8"))
