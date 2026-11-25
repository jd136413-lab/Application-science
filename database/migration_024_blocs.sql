-- Migration 024 (25/11/2026) : résumé « à blocs » (plan D, maquette 109).
-- À lancer une fois dans Supabase : SQL Editor → New query → coller tout → Run.
-- Peut être relancée sans risque. Ne change rien aux fiches existantes.
--
-- La colonne « blocs » contient le nouveau résumé : En bref, En chiffres, les blocs-questions
-- (Comment ça marche ?, Comment le sait-on ?…) et « Ce qu'on ne sait pas encore ».
-- Les anciennes colonnes (avant, decouverte, apres) restent remplies pour les versions de
-- l'app déjà installées sur les téléphones.

alter table advances add column if not exists blocs jsonb not null default '[]'::jsonb;
