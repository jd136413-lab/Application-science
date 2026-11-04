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

# Paramètre ajouté à chaque appel client.messages.create(...)
PARAMS = {} if REFLEXION else {"thinking": {"type": "disabled"}}
