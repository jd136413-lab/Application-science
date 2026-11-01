-- =====================================================================
-- NovaSTEM : statistiques JOUR PAR JOUR (01/11/2026)
-- Supabase → SQL Editor → New query → New blank query → coller → Run
--
-- Ajoute deux fonctions au tableau de bord (stats.html) :
--   stats_periode(du, au) : tout le détail d'un jour choisi (ou de plusieurs jours) ;
--   stats_par_jour(du, au) : une ligne par jour (utilisateurs, ouvertures, vues…).
-- Rien n'est supprimé ni modifié dans les données. Le script peut être relancé.
-- La réinitialisation du tableau de bord (stats_reglages.depuis) est respectée.
-- =====================================================================

create table if not exists public.stats_reglages (
  id        int primary key default 1 check (id = 1),
  depuis    timestamptz,
  code_hash text
);
insert into public.stats_reglages (id) values (1) on conflict (id) do nothing;
alter table public.stats_reglages enable row level security;
revoke all on public.stats_reglages from anon, authenticated;

-- 1) Le détail d'une journée (du = au) ou de plusieurs jours.
create or replace function public.stats_periode(du date, au date default null)
returns json
language sql
security definer
set search_path = public
as $$
  with p as (
    -- Journées entières à l'heure de Paris, du « du » au « au » inclus (au plus 400 jours).
    select (least(coalesce(au, du), du + 399) - du + 1) as j,
           greatest((du::timestamp at time zone 'Europe/Paris'),
                    coalesce((select depuis from public.stats_reglages where id = 1), '-infinity')) as debut,
           ((least(coalesce(au, du), du + 399) + 1)::timestamp at time zone 'Europe/Paris') as fin
  ),
  e as (
    select s.* from public.stats s, p
    where s.cree_le >= p.debut and s.cree_le < p.fin
  ),
  par_avancee as (
    select avancee_id,
      count(*) filter (where evenement = 'lecture')     as lectures,
      count(*) filter (where evenement = 'article')     as articles,
      count(*) filter (where evenement = 'favori')      as favoris,
      count(*) filter (where evenement = 'partage')     as partages,
      count(*) filter (where evenement = 'masquee')     as masquees,
      count(*) filter (where evenement = 'signalement') as signalements
    from e where avancee_id is not null group by avancee_id
  ),
  scores as (
    select a.id, a.title as titre, a.family as famille, a.feed as fil, a.importance,
           a.source_name as source, a.published_at as publie_le,
           pa.lectures, pa.articles, pa.favoris, pa.partages, pa.masquees, pa.signalements,
           pa.lectures + 2 * pa.articles + 3 * pa.favoris + 3 * pa.partages - 3 * pa.masquees as score
    from par_avancee pa join public.advances a on a.id = pa.avancee_id
  ),
  fiches as (
    select a.feed as fil, a.family as famille, a.importance, a.source_name as source
    from public.advances a, p
    where a.created_at >= p.debut and a.created_at < p.fin
  )
  select json_build_object(
    'jours', (select j from p),
    'du', du,
    'au', coalesce(au, du),
    'utilisateurs', (select count(*) from e where evenement = 'actif_jour'),
    'utilisateurs_langues', (select coalesce(json_agg(t order by utilisateurs desc, ouvertures desc), '[]') from
                (select valeur as langue,
                        count(*) filter (where evenement = 'actif_jour') as utilisateurs,
                        count(*) filter (where evenement = 'ouverture')  as ouvertures
                 from e where evenement in ('actif_jour', 'ouverture') and valeur is not null group by 1) t),
    'genere_le', now(),
    'depuis', (select depuis from public.stats_reglages where id = 1),
    'totaux', (select coalesce(json_object_agg(evenement, n), '{}') from
                (select evenement, count(*) as n from e group by evenement) t),
    'fiches_publiees', (select count(*) from fiches),
    'par_jour', (select coalesce(json_agg(t order by jour), '[]') from
                (select to_char(date_trunc('day', cree_le at time zone 'Europe/Paris'), 'YYYY-MM-DD') as jour,
                        count(*) filter (where evenement = 'ouverture')    as ouvertures,
                        count(*) filter (where evenement = 'lecture')      as lectures,
                        count(*) filter (where evenement = 'article')      as articles,
                        count(*) filter (where evenement = 'favori')       as favoris,
                        count(*) filter (where evenement = 'installation') as installations
                 from e group by 1) t),
    'par_heure', (select coalesce(json_agg(t order by heure), '[]') from
                (select extract(hour from cree_le at time zone 'Europe/Paris')::int as heure, count(*) as n
                 from e where evenement = 'ouverture' group by 1) t),
    'par_version', (select coalesce(json_agg(t order by premier desc), '[]') from
                (select version, min(cree_le) as premier,
                        count(*) filter (where evenement = 'ouverture') as ouvertures,
                        count(*) filter (where evenement = 'lecture')   as lectures,
                        count(*) filter (where evenement = 'article')   as articles,
                        count(*) filter (where evenement = 'favori')    as favoris
                 from e where version is not null group by version) t),
    'top_avancees', (select coalesce(json_agg(t order by score desc, lectures desc), '[]') from
                (select titre, famille, fil, importance, source, publie_le, lectures, articles, favoris,
                        partages, masquees, signalements, score
                 from scores order by score desc, lectures desc limit 20) t),
    'familles', (select coalesce(json_agg(t order by lectures desc), '[]') from
                (select coalesce(f.fil, s.fil) as fil, coalesce(f.famille, s.famille) as famille,
                        coalesce(f.fiches, 0) as fiches, coalesce(s.lectures, 0) as lectures,
                        coalesce(s.articles, 0) as articles, coalesce(s.favoris, 0) as favoris,
                        coalesce(s.partages, 0) as partages, coalesce(s.masquees, 0) as masquees
                 from (select fil, famille, count(*) as fiches from fiches group by 1, 2) f
                 full join (select fil, famille, sum(lectures) as lectures, sum(articles) as articles,
                                   sum(favoris) as favoris, sum(partages) as partages, sum(masquees) as masquees
                            from scores group by 1, 2) s
                   on f.fil = s.fil and f.famille = s.famille) t),
    'importance', (select coalesce(json_agg(t order by importance), '[]') from
                (select coalesce(f.importance, s.importance) as importance,
                        coalesce(f.fiches, 0) as fiches, coalesce(s.lectures, 0) as lectures,
                        coalesce(s.articles, 0) as articles, coalesce(s.favoris, 0) as favoris
                 from (select importance, count(*) as fiches from fiches group by 1) f
                 full join (select importance, sum(lectures) as lectures, sum(articles) as articles,
                                   sum(favoris) as favoris from scores group by 1) s
                   on f.importance = s.importance) t),
    'sources', (select coalesce(json_agg(t order by lectures desc, fiches desc), '[]') from
                (select coalesce(f.source, s.source) as source, coalesce(f.fiches, 0) as fiches,
                        coalesce(s.lectures, 0) as lectures, coalesce(s.favoris, 0) as favoris,
                        coalesce(m.n, 0) as masquee
                 from (select source, count(*) as fiches from fiches group by 1) f
                 full join (select source, sum(lectures) as lectures, sum(favoris) as favoris
                            from scores group by 1) s on f.source = s.source
                 left join (select valeur as source, count(*) as n from e
                            where evenement = 'source_masquee' group by 1) m
                   on m.source = coalesce(f.source, s.source)
                 order by coalesce(s.lectures, 0) desc, coalesce(f.fiches, 0) desc limit 30) t),
    'origine_lectures', (select coalesce(json_object_agg(origine, n), '{}') from
                (select coalesce(valeur, 'fil') as origine, count(*) as n
                 from e where evenement = 'lecture' group by 1) t),
    'signalements', (select coalesce(json_agg(t order by n desc), '[]') from
                (select valeur as motif, count(*) as n from e
                 where evenement = 'signalement' group by 1) t),
    'langues', (select coalesce(json_agg(t order by n desc), '[]') from
                (select valeur as langue, count(*) as n from e
                 where evenement = 'ouverture' and valeur is not null group by 1) t),
    'formules_notif', (select coalesce(json_agg(t order by n desc), '[]') from
                (select valeur as formule, count(*) as n from e
                 where evenement = 'notif_formule' and valeur is not null group by 1) t)
  );
$$;

revoke all on function public.stats_periode(date, date) from public;
grant execute on function public.stats_periode(date, date) to anon, authenticated;

-- 2) Une ligne par jour, pour le tableau « Jour par jour » et la courbe.
create or replace function public.stats_par_jour(du date, au date)
returns json
language sql
security definer
set search_path = public
as $$
  with p as (
    select greatest((du::timestamp at time zone 'Europe/Paris'),
                    coalesce((select depuis from public.stats_reglages where id = 1), '-infinity')) as debut,
           ((least(au, du + 399) + 1)::timestamp at time zone 'Europe/Paris') as fin
  ),
  e as (
    select to_char(s.cree_le at time zone 'Europe/Paris', 'YYYY-MM-DD') as jour, s.evenement
    from public.stats s, p where s.cree_le >= p.debut and s.cree_le < p.fin
  ),
  f as (
    select to_char(a.created_at at time zone 'Europe/Paris', 'YYYY-MM-DD') as jour, count(*) as fiches
    from public.advances a, p where a.created_at >= p.debut and a.created_at < p.fin group by 1
  ),
  j as (
    select jour,
      count(*) filter (where evenement = 'actif_jour')    as utilisateurs,
      count(*) filter (where evenement = 'ouverture')     as ouvertures,
      count(*) filter (where evenement = 'installation')  as installations,
      count(*) filter (where evenement = 'lecture')       as lectures,
      count(*) filter (where evenement = 'article')       as articles,
      count(*) filter (where evenement = 'favori')        as favoris,
      count(*) filter (where evenement = 'partage')       as partages,
      count(*) filter (where evenement = 'notif_ouverte') as notifs,
      count(*) filter (where evenement = 'masquee')       as masquees
    from e group by 1
  )
  select coalesce(json_agg(t order by jour desc), '[]') from (
    select coalesce(j.jour, f.jour) as jour,
           coalesce(j.utilisateurs, 0) as utilisateurs, coalesce(j.ouvertures, 0) as ouvertures,
           coalesce(j.installations, 0) as installations, coalesce(j.lectures, 0) as lectures,
           coalesce(j.articles, 0) as articles, coalesce(j.favoris, 0) as favoris,
           coalesce(j.partages, 0) as partages, coalesce(j.notifs, 0) as notifs,
           coalesce(j.masquees, 0) as masquees, coalesce(f.fiches, 0) as fiches
    from j full join f on f.jour = j.jour
  ) t;
$$;
revoke all on function public.stats_par_jour(date, date) from public;
grant execute on function public.stats_par_jour(date, date) to anon, authenticated;

-- Vérification : doit afficher deux lignes (stats_par_jour et stats_periode)
select proname from pg_proc where proname in ('stats_periode', 'stats_par_jour') order by 1;
