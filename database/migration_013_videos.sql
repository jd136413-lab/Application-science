-- Migration 013 (08/11/2026) : vidéo à l'appui d'une avancée ou d'un événement.
-- À lancer une fois dans Supabase : SQL Editor → New query → coller → Run.
alter table advances add column if not exists video_url text;
alter table advances add column if not exists video_titre text;
alter table upcoming_events add column if not exists video_url text;
alter table upcoming_events add column if not exists video_titre text;
