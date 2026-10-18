-- =====================================================================
-- REMISE À ZÉRO (phase de test uniquement) — IRRÉVERSIBLE
-- Vide les articles publiés ET la mémoire des liens écartés.
-- Les tables, index et règles de sécurité restent en place.
-- Supabase → SQL Editor → New query → New blank query → coller → Run
-- =====================================================================
truncate table public.advances, public.seen_urls;
