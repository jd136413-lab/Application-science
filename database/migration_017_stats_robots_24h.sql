-- Migration 017 (10/11/2026) : statistiques sans robots, pour TOUTES les versions.
-- Certains téléphones-robots de Google (rapport de pré-lancement) installent l'app
-- depuis le Play Store comme un humain : l'app ne peut pas les reconnaître.
-- On écarte donc, pour chaque version, les 24 heures qui suivent sa première
-- apparition (les vrais utilisateurs ne la reçoivent qu'après validation par Google).
-- Rien n'est supprimé : seuls les calculs du tableau de bord changent.
create or replace function public.stats_sans_robots()
returns setof public.stats
language sql
stable
security definer
set search_path = public
as $$
  with premiere as (
    select version, min(cree_le) as debut from public.stats
    where version is not null group by version
  )
  select s.* from public.stats s
  left join premiere v on v.version = s.version
  where s.version is null
     or v.debut is null
     or s.cree_le >= v.debut + interval '24 hours';
$$;
revoke all on function public.stats_sans_robots() from public, anon, authenticated;
