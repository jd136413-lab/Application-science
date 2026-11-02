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
                    "resume": _en_bref(f.get("decouverte") or f.get("summary", "")),
                    "image": f.get("image_url") or "",
                    # Traductions faites par l'agent (traduction.py) : titre_en, resume_en…
                    **{k: v for code, t in (f.get("traductions") or {}).items() if isinstance(t, dict)
                       for k, v in ((f"titre_{code}", t.get("title") or ""),
                                    (f"resume_{code}", _en_bref(t.get("decouverte") or t.get("summary") or "")))
                       if v},
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


def envoyer_arrive(evenement: dict, fiche: dict, log) -> bool:
    """Onglet « À venir » (maquette 72) : la fiche d'un événement suivi vient d'être publiée.
    Seuls les téléphones qui avaient touché « Me le rappeler » sont abonnés au sujet
    evt_<id de l'événement> (aucun identifiant de téléphone)."""
    brut = (os.environ.get("FIREBASE_SERVICE_ACCOUNT") or "").strip()
    if not brut or not evenement.get("id") or not fiche.get("id"):
        return False
    try:
        compte = json.loads(brut)
        jeton = _jeton(compte)
        url = f"https://fcm.googleapis.com/v1/projects/{compte['project_id']}/messages:send"
        message = {"message": {
            "topic": f"evt_{evenement['id']}",
            "data": {
                "type": "arrive", "evt": str(evenement["id"]), "id": str(fiche["id"]),
                "titre": fiche.get("title", ""), "importance": str(int(fiche.get("importance") or 1)),
                **{f"titre_{code}": t.get("title") for code, t in (fiche.get("traductions") or {}).items()
                   if isinstance(t, dict) and t.get("title")},
            },
            "android": {"priority": "high", "ttl": "172800s"},
            "apns": {"headers": {"apns-priority": "5"}, "payload": {"aps": {"content-available": 1}}},
        }}
        r = requests.post(url, headers={"Authorization": f"Bearer {jeton}", "Content-Type": "application/json"},
                          json=message, timeout=30)
        if r.status_code >= 300:
            raise RuntimeError(f"{r.status_code} {r.text[:120]}")
        log(f"  🔔 « C'est arrivé » envoyé aux téléphones qui suivaient « {evenement.get('title', '')[:50]} »")
        return True
    except Exception as ex:
        log(f"  ⚠ « C'est arrivé » non envoyé ({str(ex)[:120]})")
        return False


def envoyer_changement(evenement: dict, nature: str, log) -> bool:
    """Onglet « À venir » (maquette 79) : un événement suivi est reporté, avancé, annulé ou
    enfin daté précisément. Envoyé aux seuls téléphones qui avaient touché « Me le rappeler »
    (sujet evt_<id>). Le téléphone affiche la notification et déplace son rappel."""
    brut = (os.environ.get("FIREBASE_SERVICE_ACCOUNT") or "").strip()
    if not brut or not evenement.get("id"):
        return False
    try:
        compte = json.loads(brut)
        jeton = _jeton(compte)
        url = f"https://fcm.googleapis.com/v1/projects/{compte['project_id']}/messages:send"
        donnees = {
            "type": "changement", "nature": nature, "evt": str(evenement["id"]),
            "titre": evenement.get("title", ""), "date": str(evenement.get("event_date") or ""),
            "utc": str(evenement.get("event_utc") or ""), "precision": str(evenement.get("precision") or "jour"),
        }
        message = {"message": {
            "topic": f"evt_{evenement['id']}",
            "data": donnees,
            "android": {"priority": "high", "ttl": "172800s"},
            "apns": {"headers": {"apns-priority": "5"}, "payload": {"aps": {"content-available": 1}}},
        }}
        r = requests.post(url, headers={"Authorization": f"Bearer {jeton}", "Content-Type": "application/json"},
                          json=message, timeout=30)
        if r.status_code >= 300:
            raise RuntimeError(f"{r.status_code} {r.text[:120]}")
        log(f"  🔔 « {nature} » envoyé aux téléphones qui suivaient « {evenement.get('title', '')[:50]} »")
        return True
    except Exception as ex:
        log(f"  ⚠ Changement non envoyé ({str(ex)[:120]})")
        return False
