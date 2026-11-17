"""Prévient le téléphone administrateur (Maxime) des nouvelles propositions (maquette 96).

Lancé toutes les heures par le workflow « Propositions : notification » (gratuit : aucun appel
à Claude). Lit les propositions pas encore signalées, envoie UNE notification au sujet FCM
réservé à l'administrateur (table admin_secret), puis les marque comme signalées.
Le téléphone ne reçoit rien tant que « Me prévenir des nouvelles propositions » est désactivé
dans ses réglages administrateur (il n'est alors pas abonné à ce sujet).
"""

import json
import os
import sys

import requests

import notifications

NOMS = {"amelioration": "amélioration", "sujet": "sujet", "resume": "résumé"}


def main() -> int:
    url, cle = os.environ.get("SUPABASE_URL", "").rstrip("/"), os.environ.get("SUPABASE_SECRET_KEY", "")
    brut = (os.environ.get("FIREBASE_SERVICE_ACCOUNT") or "").strip()
    if not (url and cle and brut):
        print("Secrets manquants (SUPABASE_URL, SUPABASE_SECRET_KEY, FIREBASE_SERVICE_ACCOUNT).")
        return 0
    h = {"apikey": cle, "Authorization": f"Bearer {cle}", "Content-Type": "application/json"}
    r = requests.get(f"{url}/rest/v1/submissions", headers=h, timeout=30, params={
        "select": "id,genre,categorie,sujet,titre", "notifiee": "eq.false", "order": "created_at.asc", "limit": "50"})
    if r.status_code == 404 or (r.status_code == 400 and "submissions" in r.text):
        print("Table submissions absente : lancer database/migration_018_soumissions.sql.")
        return 0
    r.raise_for_status()
    nouvelles = r.json()
    if not nouvelles:
        print("Aucune nouvelle proposition.")
        return 0
    s = requests.get(f"{url}/rest/v1/admin_secret", headers=h, timeout=30, params={"select": "sujet_notif", "id": "eq.1"})
    sujet = (s.json() or [{}])[0].get("sujet_notif") if s.ok else None
    if not sujet:
        print("Code administrateur pas encore choisi (admin_secret vide) : rien n'est envoyé.")
        return 0
    n = len(nouvelles)
    premier = nouvelles[-1]
    texte = (premier.get("titre") or premier.get("sujet") or "").strip()
    titre = (f"Nouvelle proposition ({NOMS.get(premier['genre'], premier['genre'])})" if n == 1
             else f"{n} nouvelles propositions")
    compte = json.loads(brut)
    message = {"message": {
        "topic": sujet,
        "data": {"type": "admin", "titre": titre, "texte": texte[:300], "n": str(n)},
        "android": {"priority": "high", "ttl": "86400s"},
        "apns": {"headers": {"apns-priority": "5"}, "payload": {"aps": {"content-available": 1}}},
    }}
    rep = requests.post(f"https://fcm.googleapis.com/v1/projects/{compte['project_id']}/messages:send",
                        headers={"Authorization": f"Bearer {notifications._jeton(compte)}",
                                 "Content-Type": "application/json"}, json=message, timeout=30)
    if rep.status_code >= 300:
        print(f"Notification non envoyée : {rep.status_code} {rep.text[:200]}")
        return 1
    ids = ",".join(x["id"] for x in nouvelles)
    requests.patch(f"{url}/rest/v1/submissions", headers=dict(h, Prefer="return=minimal"), timeout=30,
                   params={"id": f"in.({ids})"}, json={"notifiee": True}).raise_for_status()
    print(f"🔔 {titre} : notification envoyée.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
