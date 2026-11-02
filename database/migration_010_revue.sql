-- =====================================================================
-- NovaSTEM — migration 010 : revue scientifique et DOI de l'étude (02/11/2026)
-- ---------------------------------------------------------------------
-- revue : la revue où l'étude est publiée (ex. « Physical Review Letters »),
--         distincte du média qui en parle (ex. Phys.org) ;
-- doi   : identifiant de l'étude (ex. 10.1103/PhysRevLett.xxx), pour un futur
--         bouton « Lire l'étude ».
-- À lancer une fois : Supabase → SQL Editor → New query → New blank query →
-- coller ce fichier → Run. Sans risque si on le relance.
-- =====================================================================

alter table public.advances add column if not exists revue text;
alter table public.advances add column if not exists doi   text;

-- Vérification : les 2 nouvelles colonnes doivent apparaître
select column_name, data_type
  from information_schema.columns
 where table_schema = 'public' and table_name = 'advances'
   and column_name in ('revue', 'doi')
 order by column_name;
