-- =====================================================================
-- NovaSTEM : plusieurs sources pour un événement « À venir » (03/11/2026)
-- Supabase → SQL Editor → New query → New blank query → coller → Run
--
-- Comme pour les avancées (migration 007) : quand un autre média parle du
-- même événement, l'agent l'ajoute dans « autres_sources »
-- ([{"nom", "url", "langue", "date"}]). L'appli les affiche sous
-- « SpaceNews + 2 autres », dépliable.
-- Sans risque, peut être relancé. L'agent marche aussi sans (une seule source).
-- =====================================================================

alter table public.upcoming_events
  add column if not exists autres_sources jsonb;
