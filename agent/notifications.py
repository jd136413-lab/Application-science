"""Envoi des notifications NovaSTEM par Firebase Cloud Messaging (FCM).

Chaque téléphone s'abonne lui-même à des « sujets » selon ses réglages
(Réglages → Notifications). Un sujet = une famille + un niveau d'importance :
    n_<famille>_<importance>      ex. n_space_4, n_gaming_3
Une avancée de la famille « space » notée 4 part donc sur le sujet n_space_4,
et seuls les téléphones abonnés à ce sujet la reçoivent.

Les messages sont des « données » (pas de notification toute faite) : c'est le
téléphone qui affiche les notifications. Il en garde au plus UNE par fil
(Sciences, Technologies) : la plus importante en vedette (avec son « en bref »
et sa photo libre s'il y en a une), les autres listées dessous (maquette 28 D).
Les avancées partent de la plus importante à la moins importante.

Sans le secret FIREBASE_SERVICE_ACCOUNT, rien n'est envoyé (aucune erreur).
"""
import json
import os
import re
from datetime import datetime, timezone

import requests

PORTEE = "https://www.googleapis.com/auth/firebase.messaging"


def _jeton(compte: dict) -> str:
    from google.oauth2 import service_account
    from google.auth.transport.requests import Request

    cred = service_account.Credentials.from_service_account_info(compte, scopes=[PORTEE])
    cred.refresh(Request())
    return cred.token


def _en_bref(resume: str) -> str:
    """Première phrase du résumé (300 caractères au plus), pour la notification."""
    resume = " ".join((resume or "").split())
    m = re.match(r"(.+?[.!?])(\s|$)", resume)
    phrase = m.group(1) if m else resume
    return phrase if len(phrase) <= 300 else phrase[:297].rstrip() + "…"


def envoyer(fiches: list[dict], log) -> tuple[int, int]:
    """Envoie une notification par fiche enregistrée. Renvoie (envoyées, échecs)."""
    brut = (os.environ.get("FIREBASE_SERVICE_ACCOUNT") or "").strip()
    if not brut:
        log("🔕 Notifications : secret FIREBASE_SERVICE_ACCOUNT absent, rien n'est envoyé.")
        return 0, 0
    fiches = [f for f in fiches if f.get("id") and f.get("family")]
    if not fiches:
        return 0, 0
    try:
        compte = json.loads(brut)
        jeton = _jeton(compte)
    except Exception as ex:
        log(f"⚠ Notifications : compte de service Firebase illisible ({ex.__class__.__name__}).")
        return 0, len(fiches)

    url = f"https://fcm.googleapis.com/v1/projects/{compte['project_id']}/messages:send"
    entetes = {"Authorization": f"Bearer {jeton}", "Content-Type": "application/json"}
    lot = datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")  # identifie cette exécution
    envoyees, echecs = 0, 0
    for f in sorted(fiches, key=lambda x: -int(x["importance"])):
        message = {
            "message": {
                "topic": f"n_{f['family']}_{int(f['importance'])}",
                "data": {
                    "id": str(f["id"]),
                    "lot": lot,
                    "titre": f["title"],
                    "famille": f["family"],
                    "importance": str(int(f["importance"])),
                    "fil": f["feed"],
                    "resume": _en_bref(f.get("summary", "")),
                    "image": f.get("image_url") or "",
                },
                "android": {"priority": "high", "ttl": "86400s"},
                "apns": {"headers": {"apns-priority": "5"}, "payload": {"aps": {"content-available": 1}}},
            }
        }
        try:
            r = requests.post(url, headers=entetes, json=message, timeout=30)
            if r.status_code >= 300:
                raise RuntimeError(f"{r.status_code} {r.text[:150]}")
            envoyees += 1
        except Exception as ex:
            echecs += 1
            log(f"  ⚠ notification non envoyée ({f['title'][:50]}) : {str(ex)[:160]}")
    log(f"🔔 Notifications : {envoyees} envoyée(s), {echecs} échec(s).")
    return envoyees, echecs
