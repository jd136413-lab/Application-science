-- =====================================================================
-- NovaSTEM : statistiques anonymes (21/10/2026)
-- Supabase → SQL Editor → New query → New blank query → coller → Run
--
-- - Table « stats » : un événement par ligne (ouverture de l'app, lecture
--   d'une avancée, favori, masquage, partage…). AUCUN identifiant de
--   téléphone ni de personne : impossible de savoir qui a fait quoi.
-- - L'app peut seulement AJOUTER des lignes (clé publique), jamais les lire.
-- - Le tableau de bord lit uniquement des TOTAUX, par la fonction
--   stats_resume (qui ne renvoie aucune ligne brute).
-- Le script peut être relancé sans risque.
-- =====================================================================

create table if not exists public.stats (
  id          bigint generated always as identity primary key,
  cree_le     timestamptz not null default now(),
  evenement   text not null check (evenement in (
                'installation','ouverture','lecture','article','favori','favori_retire',
                'masquee','source_masquee','partage','notif_ouverte','notif_formule','avis_demande')),
  avancee_id  uuid,
  fil         text check (fil is null or fil in ('science','tech')),
  famille     text check (famille is null or length(famille) <= 30),
  theme       text check (theme is null or length(theme) <= 30),
  importance  smallint check (importance is null or importance between 1 and 5),
  valeur      text check (valeur is null or length(valeur) <= 200)
);

create index if not exists stats_date_idx on public.stats (cree_le desc);
create index if not exists stats_evenement_idx on public.stats (evenement, cree_le desc);

alter table public.stats enable row level security;

-- L'app (clé publique) peut seulement ajouter des événements datés de maintenant.
drop policy if exists "ajout anonyme des statistiques" on public.stats;
create policy "ajout anonyme des statistiques" on public.stats
  for insert to anon, authenticated
  with check (cree_le > now() - interval '5 minutes' and cree_le < now() + interval '5 minutes');

grant insert (evenement, avancee_id, fil, famille, theme, importance, valeur)
  on public.stats to anon, authenticated;

-- Totaux pour le tableau de bord (aucune ligne brute, aucun identifiant).
create or replace function public.stats_resume(jours int default 30)
returns json
language sql
security definer
set search_path = public
as $$
  with e as (
    select * from public.stats
    where cree_le > now() - make_interval(days => greatest(1, least(jours, 400)))
  )
  select json_build_object(
    'jours', greatest(1, least(jours, 400)),
    'totaux', (select coalesce(json_object_agg(evenement, n), '{}') from
                (select evenement, count(*) n from e group by evenement) t),
    'par_jour', (select coalesce(json_agg(t order by jour), '[]') from
                (select to_char(date_trunc('day', cree_le at time zone 'Europe/Paris'), 'YYYY-MM-DD') jour,
                        count(*) filter (where evenement = 'ouverture') ouvertures,
                        count(*) filter (where evenement = 'lecture') lectures
                 from e group by 1) t),
    'lectures_famille', (select coalesce(json_agg(t order by n desc), '[]') from
                (select fil, famille, count(*) n from e where evenement = 'lecture' and famille is not null
                 group by fil, famille) t),
    'lectures_theme', (select coalesce(json_agg(t order by n desc), '[]') from
                (select theme, count(*) n from e where evenement = 'lecture' and theme is not null
                 group by theme order by n desc limit 25) t),
    'lectures_importance', (select coalesce(json_agg(t order by importance), '[]') from
                (select importance, count(*) n from e where evenement = 'lecture' and importance is not null
                 group by importance) t),
    'favoris_famille', (select coalesce(json_agg(t order by n desc), '[]') from
                (select famille, count(*) n from e where evenement = 'favori' and famille is not null
                 group by famille) t),
    'masquees_famille', (select coalesce(json_agg(t order by n desc), '[]') from
                (select famille, count(*) n from e where evenement = 'masquee' and famille is not null
                 group by famille) t),
    'sources_masquees', (select coalesce(json_agg(t order by n desc), '[]') from
                (select valeur source, count(*) n from e where evenement = 'source_masquee' and valeur is not null
                 group by valeur order by n desc limit 20) t),
    'top_avancees', (select coalesce(json_agg(t order by n desc), '[]') from
                (select a.title titre, a.family famille, a.importance, count(*) n
                 from e join public.advances a on a.id = e.avancee_id
                 where e.evenement = 'lecture' group by a.id, a.title, a.family, a.importance
                 order by n desc limit 15) t),
    'langues', (select coalesce(json_agg(t order by n desc), '[]') from
                (select valeur langue, count(*) n from e where evenement = 'ouverture' and valeur is not null
                 group by valeur) t),
    'formules_notif', (select coalesce(json_agg(t order by n desc), '[]') from
                (select valeur formule, count(*) n from e where evenement = 'notif_formule' and valeur is not null
                 group by valeur) t)
  );
$$;

revoke all on function public.stats_resume(int) from public;
grant execute on function public.stats_resume(int) to anon, authenticated;
