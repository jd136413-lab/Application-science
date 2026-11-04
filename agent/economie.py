# =====================================================================
# ÉCONOMIE — un seul interrupteur pour tous les appels à Claude
# ---------------------------------------------------------------------
# Décision de Maxime (04/11/2026) : 2 € par mois au maximum pour l'agent.
# Haiku 5.5 « réfléchit » par défaut avant de répondre, et cette réflexion
# cachée représente la plus grande partie des tokens de sortie (les plus
# chers). Nos consignes font déjà raisonner Claude à voix haute dans le
# JSON (faits, nouveauté, jargon, titres candidats, liste de contrôle,
# défauts trouvés) : la réflexion cachée fait en grande partie doublon.
# REFLEXION = False la coupe partout (≈ 2 fois moins cher).
# Remettre True pour revenir au fonctionnement d'avant.
# =====================================================================

REFLEXION = False

# Exception pour le TRI (présélection, regroupement par sujet, décision et anti-doublons) :
# sans réflexion, 2 doublons sur 5 sont passés le 04/11 au soir. Éviter les doublons est la
# priorité n° 1 de Maxime : la réflexion y est rallumée, en effort « low » pour limiter le coût.
REFLEXION_TRI = True

# Paramètre ajouté à chaque appel client.messages.create(...)
PARAMS = {} if REFLEXION else {"thinking": {"type": "disabled"}}
PARAMS_TRI = {} if REFLEXION_TRI else {"thinking": {"type": "disabled"}}
EFFORT_TRI = "low"

# Exception pour la réécriture et la relecture des fiches (redaction.py) : là, la réflexion
# améliore nettement la qualité (7,9 au lieu de 7,7 sur nos tests). Elle redevient abordable
# grâce au traitement par lot (−50 %) et au premier jet réduit au tri (04/11).
REFLEXION_REDACTION = True
PARAMS_REDACTION = {} if REFLEXION_REDACTION else {"thinking": {"type": "disabled"}}
