-- =====================================================================
-- NovaSTEM — migration 006 (31/10/2026)
-- 1. Traductions des fiches faites par l'agent (Claude), rangées dans la base :
--    colonne « traductions » = {"en": {"title": …, "summary": …, "avant": …,
--    "decouverte": …, "apres": …, "mots": [{"mot": …, "definition": …}]}}
--    Le téléphone les affiche telles quelles (instantané, meilleure qualité) ;
--    pour les autres langues, il garde sa traduction sur le téléphone (ML Kit).
-- 2. Statistiques : nombre d'utilisateurs par langue, sans aucun identifiant.
--    Chaque téléphone envoie « actif_jour » une fois par jour et « actif_mois »
--    une fois par mois (avec sa langue) : en les comptant, on obtient le
--    nombre de téléphones actifs par jour et par mois, pour chaque langue.
--
-- À lancer une fois : Supabase → SQL Editor → New query → New blank query →
-- coller ce fichier → Run. Sans risque si on le relance.
-- =====================================================================

-- 1. Traductions -------------------------------------------------------
alter table public.advances add column if not exists traductions jsonb not null default '{}'::jsonb;
-- (lecture publique : la règle existante porte sur toute la ligne, rien à ajouter)

-- 2. Nouveaux événements de statistiques -------------------------------
alter table public.stats drop constraint if exists stats_evenement_check;
alter table public.stats add constraint stats_evenement_check check (evenement in (
  'installation','ouverture','lecture','article','favori','favori_retire',
  'masquee','source_masquee','partage','notif_ouverte','notif_formule','avis_demande',
  'signalement','avis','hors_ligne','memoire_videe','actif_jour','actif_mois'));

-- Réglages privés des statistiques (date de réinitialisation) : créés ici aussi
-- au cas où le script migration_005_stats_reinitialiser.sql n'a pas été lancé.
create table if not exists public.stats_reglages (
  id        int primary key default 1 check (id = 1),
  depuis    timestamptz,
  code_hash text
);
insert into public.stats_reglages (id) values (1) on conflict (id) do nothing;
alter table public.stats_reglages enable row level security;
revoke all on public.stats_reglages from anon, authenticated;

-- Utilisateurs par langue (tableau de bord, partie « Langues »).
-- Pour chaque langue : utilisateurs aujourd'hui, moyenne et maximum par jour sur
-- la période choisie, utilisateurs de ce mois-ci et du mois dernier, ouvertures.
-- Respecte la réinitialisation du tableau de bord (stats_reglages.depuis).
create or replace function public.stats_langues(jours int default 30)
returns json
language sql
security definer
set search_path = public
as $$
  with r as (
    select coalesce((select depuis from public.stats_reglages where id = 1), '-infinity'::timestamptz) as depuis
  ),
  b as (
    select (select depuis from r) as depuis,
           greatest(now() - make_interval(days => greatest(1, least(jours, 400))), (select depuis from r)) as debut,
           date_trunc('day',   now() at time zone 'Europe/Paris') as jour,
           date_trunc('month', now() at time zone 'Europe/Paris') as mois
  ),
  e as (
    select s.evenement, s.valeur as langue, s.cree_le, (s.cree_le at time zone 'Europe/Paris') as t
    from public.stats s, b
    where s.evenement in ('actif_jour', 'actif_mois', 'ouverture')
      and s.valeur is not null
      and s.cree_le > b.depuis
      and s.cree_le > least(b.debut, (b.mois - interval '1 month') at time zone 'Europe/Paris')
  ),
  nb as (  -- nombre de jours de la période où l'app a été utilisée (toutes langues)
    select greatest(1, count(distinct date_trunc('day', t))) as n
    from e, b where evenement = 'actif_jour' and cree_le > b.debut
  ),
  par_jour as (
    select langue, date_trunc('day', t) as j, count(*) as n
    from e, b where evenement = 'actif_jour' and cree_le > b.debut
    group by 1, 2
  ),
  lignes as (
    select l.langue,
      (select count(*) from e, b where e.langue = l.langue and evenement = 'actif_jour' and t >= b.jour) as aujourdhui,
      round((select coalesce(sum(n), 0) from par_jour pj where pj.langue = l.langue)::numeric / (select n from nb), 1) as moyenne_jour,
      (select coalesce(max(n), 0) from par_jour pj where pj.langue = l.langue) as max_jour,
      (select count(*) from e, b where e.langue = l.langue and evenement = 'actif_mois' and t >= b.mois) as ce_mois,
      (select count(*) from e, b where e.langue = l.langue and evenement = 'actif_mois'
          and t >= b.mois - interval '1 month' and t < b.mois) as mois_dernier,
      (select count(*) from e, b where e.langue = l.langue and evenement = 'ouverture' and cree_le > b.debut) as ouvertures
    from (select distinct langue from e) l
  )
  select coalesce(json_agg(lignes order by ce_mois desc, moyenne_jour desc, ouvertures desc), '[]') from lignes;
$$;
revoke all on function public.stats_langues(int) from public;
grant execute on function public.stats_langues(int) to anon, authenticated;

-- Vérification : doit afficher la colonne « traductions » (jsonb)
select column_name, data_type
  from information_schema.columns
 where table_schema = 'public' and table_name = 'advances' and column_name = 'traductions';
