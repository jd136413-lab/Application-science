-- =====================================================================
-- NovaSTEM — migration 007 : familles élargies (31/10/2026, choix de Maxime)
-- On garde les 16 familles (mêmes codes, donc les filtres, favoris et
-- abonnements aux notifications ne bougent pas), mais certaines s'élargissent
-- grâce à de nouveaux thèmes :
--   other       « Autre » → « Humain & société » : psychology, society
--   tech_other  « Autre » → « Industrie & fabrication » : manufacturing,
--               construction, agritech
--   aerospace   « Espace, aviation & défense » : defense
--   energy_home « Énergie & maison » : nuclear
--   mobility    « Transports » : trains, ships
--   mobile      « Appareils & objets » : cameras
-- Les fiches déjà publiées gardent leur thème et leur famille.
--
-- À lancer une fois : Supabase → SQL Editor → New query → New blank query →
-- coller ce fichier → Run. Sans risque si on le relance.
-- =====================================================================

-- 1) Liste des thèmes autorisés
alter table public.advances drop constraint if exists advances_theme_check;
alter table public.advances add constraint advances_theme_check check (theme in (
  -- Sciences
  'space','astronomy','environment','climate','technology','ai',
  'robotics','health','medicine','neuroscience','genetics','biology',
  'chemistry','physics','quantum','materials','energy','ocean',
  'geology','paleontology','archaeology','agriculture',
  'mathematics','transportation','psychology','society','other',
  -- Technologies
  'smartphones','wearables','gadgets','cameras','computers','chips',
  'ai_products','software','cybersecurity','cars','drones','trains','ships',
  'rockets','aircraft','satellites','defense','batteries','solar','nuclear','smart_home',
  'consoles','video_games','vr','manufacturing','construction','agritech','tech_other'));

-- 2) Famille calculée à partir du thème
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
    when new.theme in ('psychology','society') then 'other'
    -- Technologies
    when new.theme in ('smartphones','wearables','gadgets','cameras') then 'mobile'
    when new.theme in ('computers','chips') then 'computing'
    when new.theme in ('ai_products','software','cybersecurity') then 'ai_software'
    when new.theme in ('cars','drones','trains','ships') then 'mobility'
    when new.theme in ('rockets','aircraft','satellites','defense') then 'aerospace'
    when new.theme in ('batteries','solar','nuclear','smart_home') then 'energy_home'
    when new.theme in ('consoles','video_games','vr') then 'gaming'
    when new.theme in ('manufacturing','construction','agritech','tech_other') then 'tech_other'
    else 'other'
  end;
  return new;
end $$;

-- Vérification : doit afficher « ok »
select case when pg_get_constraintdef(oid) like '%psychology%' then 'ok' else 'à relancer' end as familles_elargies
  from pg_constraint where conname = 'advances_theme_check';
