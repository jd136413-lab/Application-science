-- =====================================================================
-- NovaSTEM : statistiques, version 2 (22/10/2026)
-- Supabase → SQL Editor → New query → New blank query → coller → Run
--
-- À lancer AVANT de compiler la version suivante de l'app.
-- - Nouvelle colonne « version » : chaque événement dit de quelle version
--   de l'app il vient (ex. 1.0.38), pour comparer les mises à jour.
-- - Nouveaux événements : signalement (motif), avis, hors_ligne,
--   memoire_videe.
-- - Nouveau résumé pour le tableau de bord : ce qui plaît le plus
--   (avancées, familles, notes, sources), par version, par heure.
-- Toujours AUCUN identifiant de téléphone ni de personne.
-- Le script peut être relancé sans risque.
-- =====================================================================

alter table public.stats add column if not exists version text
  check (version is null or length(version) <= 20);

alter table public.stats drop constraint if exists stats_evenement_check;
alter table public.stats add constraint stats_evenement_check check (evenement in (
  'installation','ouverture','lecture','article','favori','favori_retire',
  'masquee','source_masquee','partage','notif_ouverte','notif_formule','avis_demande',
  'signalement','avis','hors_ligne','memoire_videe'));

grant insert (evenement, avancee_id, fil, famille, theme, importance, valeur, version)
  on public.stats to anon, authenticated;

create index if not exists stats_avancee_idx on public.stats (avancee_id) where avancee_id is not null;

-- Totaux pour le tableau de bord (aucune ligne brute, aucun identifiant).
-- « score » d'une avancée = lectures + 2 × articles ouverts + 3 × favoris
-- + 3 × partages − 3 × masquages.
create or replace function public.stats_resume(jours int default 30)
returns json
language sql
security definer
set search_path = public
as $$
  with p as (select greatest(1, least(jours, 400)) as j),
  e as (
    select s.* from public.stats s, p
    where s.cree_le > now() - make_interval(days => p.j)
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
    where a.created_at > now() - make_interval(days => p.j)
  )
  select json_build_object(
    'jours', (select j from p),
    'genere_le', now(),
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

revoke all on function public.stats_resume(int) from public;
grant execute on function public.stats_resume(int) to anon, authenticated;
