-- =====================================================================
-- NovaSTEM : bouton « Réinitialiser les statistiques » (22/10/2026)
-- Supabase → SQL Editor → New query → New blank query → coller → Run
--
-- Réinitialiser NE SUPPRIME RIEN : le tableau de bord recompte simplement
-- à partir du moment choisi. On peut donc annuler (bouton « Annuler la
-- réinitialisation » du tableau de bord).
-- Protégé par un code secret : sans lui, personne ne peut réinitialiser,
-- même en connaissant l'adresse du tableau de bord.
-- Le script peut être relancé sans risque.
-- =====================================================================

-- Réglages privés (lisibles seulement par les fonctions ci-dessous)
create table if not exists public.stats_reglages (
  id        int primary key default 1 check (id = 1),
  depuis    timestamptz,          -- les statistiques comptent à partir de cette date
  code_hash text                  -- empreinte du code secret (jamais le code lui-même)
);
insert into public.stats_reglages (id) values (1) on conflict (id) do nothing;
alter table public.stats_reglages enable row level security;  -- aucune règle : invisible pour l'app et la page
revoke all on public.stats_reglages from anon, authenticated;

-- Réinitialiser (annuler = false) ou annuler la réinitialisation (annuler = true)
create or replace function public.stats_reinitialiser(code text, annuler boolean default false)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare attendu text;
begin
  select code_hash into attendu from public.stats_reglages where id = 1;
  if attendu is null then
    return json_build_object('ok', false, 'raison', 'pas_de_code');
  end if;
  if code is null or encode(sha256(convert_to(code, 'UTF8')), 'hex') <> attendu then
    perform pg_sleep(2);  -- ralentit les essais au hasard
    return json_build_object('ok', false, 'raison', 'mauvais_code');
  end if;
  update public.stats_reglages set depuis = case when annuler then null else now() end where id = 1;
  return json_build_object('ok', true, 'depuis', (select depuis from public.stats_reglages where id = 1));
end;
$$;
revoke all on function public.stats_reinitialiser(text, boolean) from public;
grant execute on function public.stats_reinitialiser(text, boolean) to anon, authenticated;

-- Totaux du tableau de bord : comptés depuis la dernière réinitialisation
create or replace function public.stats_resume(jours int default 30)
returns json
language sql
security definer
set search_path = public
as $$
  with p as (
    select greatest(1, least(jours, 400)) as j,
           greatest(now() - make_interval(days => greatest(1, least(jours, 400))),
                    coalesce((select depuis from public.stats_reglages where id = 1), '-infinity')) as debut
  ),
  e as (
    select s.* from public.stats s, p
    where s.cree_le > p.debut
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
    where a.created_at > p.debut
  )
  select json_build_object(
    'jours', (select j from p),
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

revoke all on function public.stats_resume(int) from public;
grant execute on function public.stats_resume(int) to anon, authenticated;
