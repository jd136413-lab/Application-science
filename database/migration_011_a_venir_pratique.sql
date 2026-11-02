-- =====================================================================
-- NovaSTEM : onglet « À venir », infos pratiques (02/11/2026, maquettes 78-79)
-- Supabase → SQL Editor → New query → New blank query → coller → Run
--
-- Ajoute à chaque événement : l'heure exacte (affichée à l'heure du
-- téléphone), la fin (événements sur plusieurs jours), le lieu, les lignes
-- « En pratique », le lien du direct, les régions du monde d'où on le voit
-- (événements du ciel), et son statut (prévu, reporté, annulé).
-- Élargit aussi les types d'événements et ajoute la date floue « d'ici fin … ».
-- Rien n'est supprimé. Le script peut être relancé sans risque.
-- =====================================================================

alter table public.upcoming_events
  add column if not exists event_utc       timestamptz,   -- instant exact (heure universelle), si connu
  add column if not exists event_end       date,          -- dernier jour (salon, sommet…)
  add column if not exists lieu            text,          -- « Antalya, en Turquie », « En ligne »…
  add column if not exists pratique        jsonb,         -- lignes « En pratique » : [{"k": icône, "t": titre, "v": texte}]
  add column if not exists lien_direct     text,          -- page du direct (YouTube, site officiel…)
  add column if not exists lien_direct_nom text,          -- « Chaîne YouTube de SpaceX »…
  add column if not exists visible_regions text[],        -- ciel : régions d'où on le voit en entier
  add column if not exists visible_partiel text[],        -- ciel : régions d'où on le voit en partie
  add column if not exists visible_texte   text,          -- ciel : « Chili, Argentine, ouest de l'Afrique »
  add column if not exists statut          text not null default 'prevu',
  add column if not exists statut_raison   text,          -- « météo », « problème technique »… (si la source le dit)
  add column if not exists verifie_le      timestamptz;   -- dernière vérification de la date par l'agent

-- Statut
alter table public.upcoming_events drop constraint if exists upcoming_events_statut_check;
alter table public.upcoming_events add constraint upcoming_events_statut_check
  check (statut in ('prevu', 'reporte', 'annule'));

-- Plus de types d'événements (les anciens restent valables)
alter table public.upcoming_events drop constraint if exists upcoming_events_type_check;
alter table public.upcoming_events add constraint upcoming_events_type_check
  check (type in ('lancement', 'arrivee', 'ciel', 'sortie', 'presentation', 'salon', 'sommet',
                  'resultats', 'decision', 'prix', 'mise_en_service', 'essai', 'evenement', 'annonce'));

-- Date floue : 'avant' = « d'ici fin <mois> » (event_date = dernier jour possible)
alter table public.upcoming_events drop constraint if exists upcoming_events_precision_check;
alter table public.upcoming_events add constraint upcoming_events_precision_check
  check (precision in ('jour', 'mois', 'avant'));

-- Vérification : doit afficher 12 lignes (les nouvelles colonnes)
select column_name from information_schema.columns
 where table_schema = 'public' and table_name = 'upcoming_events'
   and column_name in ('event_utc', 'event_end', 'lieu', 'pratique', 'lien_direct', 'lien_direct_nom',
                       'visible_regions', 'visible_partiel', 'visible_texte', 'statut', 'statut_raison', 'verifie_le');
