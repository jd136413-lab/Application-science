-- =====================================================================
-- Migration 002 (18/10/2026) : fil Technologies, photos libres,
-- et un même article possible dans les deux fils
-- Supabase → SQL Editor → New query → New blank query → coller → Run
-- Sans danger pour les données existantes (elles restent dans le fil Sciences).
-- =====================================================================

-- 1) Nouvelles colonnes
alter table public.advances
  add column if not exists feed text not null default 'science',
  add column if not exists image_url text,
  add column if not exists image_credit text;

alter table public.advances drop constraint if exists advances_feed_check;
alter table public.advances add constraint advances_feed_check
  check (feed in ('science', 'tech'));

-- 2) Liste des thèmes : 25 thèmes Sciences + 20 thèmes Technologies
-- (retire l'ancienne règle sur les thèmes, quel que soit son nom)
do $$
declare r record;
begin
  for r in select conname from pg_constraint
           where conrelid = 'public.advances'::regclass and contype = 'c'
             and pg_get_constraintdef(oid) like '%theme%'
  loop
    execute format('alter table public.advances drop constraint %I', r.conname);
  end loop;
end $$;
alter table public.advances add constraint advances_theme_check check (theme in (
  -- Sciences
  'space','astronomy','environment','climate','technology','ai',
  'robotics','health','medicine','neuroscience','genetics','biology',
  'chemistry','physics','quantum','materials','energy','ocean',
  'geology','paleontology','archaeology','agriculture',
  'mathematics','transportation','other',
  -- Technologies
  'smartphones','wearables','gadgets','computers','chips',
  'ai_products','software','cybersecurity','cars','drones',
  'rockets','aircraft','satellites','batteries','solar','smart_home',
  'consoles','video_games','vr','tech_other'));

-- 3) La famille est toujours calculée automatiquement à partir du thème
create or replace function public.set_family() returns trigger
language plpgsql as $$
begin
  new.family := case
    -- Sciences
    when new.theme in ('space','astronomy') then 'space'
    when new.theme in ('environment','climate','ocean','agriculture') then 'environment'
    when new.theme in ('health','medicine','neuroscience') then 'health'
    when new.theme in ('technology','ai','robotics','energy','transportation') then 'technology'
    when new.theme in ('physics','quantum','chemistry','materials','mathematics') then 'physics'
    when new.theme in ('biology','genetics') then 'life'
    when new.theme in ('geology','paleontology','archaeology') then 'earth'
    -- Technologies
    when new.theme in ('smartphones','wearables','gadgets') then 'mobile'
    when new.theme in ('computers','chips') then 'computing'
    when new.theme in ('ai_products','software','cybersecurity') then 'ai_software'
    when new.theme in ('cars','drones') then 'mobility'
    when new.theme in ('rockets','aircraft','satellites') then 'aerospace'
    when new.theme in ('batteries','solar','smart_home') then 'energy_home'
    when new.theme in ('consoles','video_games','vr') then 'gaming'
    when new.theme = 'tech_other' then 'tech_other'
    else 'other'
  end;
  return new;
end $$;

-- 4) Un même article peut être publié dans les DEUX fils (avancée scientifique
--    ET technologique) : le lien n'est plus unique tout seul, mais par fil.
do $$
declare r record;
begin
  for r in select conname from pg_constraint
           where conrelid = 'public.advances'::regclass and contype = 'u'
  loop
    execute format('alter table public.advances drop constraint %I', r.conname);
  end loop;
end $$;
alter table public.advances add constraint advances_source_url_feed_key
  unique (source_url, feed);

-- 5) Index pour charger vite un fil précis
create index if not exists advances_feed_published_idx
  on public.advances (feed, published_at desc);
