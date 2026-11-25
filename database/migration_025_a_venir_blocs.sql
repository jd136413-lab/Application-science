-- Migration 025 (25/11/2026) : résumé « à blocs » des cartes À venir (maquette 112).
-- À lancer une fois dans Supabase : SQL Editor → New query → coller tout → Run.
-- Peut être relancée sans risque. Ne change rien aux cartes existantes : l'agent écrira
-- leur nouveau résumé petit à petit (les plus proches d'abord).

alter table upcoming_events add column if not exists blocs jsonb not null default '[]'::jsonb;
