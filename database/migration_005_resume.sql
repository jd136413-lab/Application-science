-- =====================================================================
-- NovaSTEM — migration 005 : nouveau résumé (maquette 33, 21/10/2026)
-- ---------------------------------------------------------------------
-- Chaque nouvelle fiche aura :
--   avant       « Avant » : ce qu'on savait ou ce qui existait
--   decouverte  « La découverte » (Sciences) / « La nouveauté » (Technologies)
--   apres       « Et après ? » : ce que ça change, ce qu'il reste à prouver
--   mots        0 à 2 « mots à connaître » : [{"mot": …, "definition": …}]
--   type_etude  badge : essai_clinique, humain, animal, cellules, simulation,
--               observation, terrain, donnees (Sciences) ; en_vente, annonce,
--               demonstration, prototype, mise_a_jour (Technologies)
-- La colonne summary reste remplie (les trois parties à la suite) pour les
-- anciennes versions de l'app et la page de partage.
--
-- À lancer une fois : Supabase → SQL Editor → New query → New blank query →
-- coller ce fichier → Run. Sans risque si on le relance.
-- =====================================================================

alter table public.advances add column if not exists avant      text;
alter table public.advances add column if not exists decouverte text;
alter table public.advances add column if not exists apres      text;
alter table public.advances add column if not exists mots       jsonb not null default '[]'::jsonb;
alter table public.advances add column if not exists type_etude text;

-- Lecture publique : les nouvelles colonnes suivent la même règle que les autres.
-- (La politique de lecture existante porte sur toute la ligne : rien à ajouter.)

-- Vérification : les 5 nouvelles colonnes doivent apparaître
select column_name, data_type
  from information_schema.columns
 where table_schema = 'public' and table_name = 'advances'
   and column_name in ('avant', 'decouverte', 'apres', 'mots', 'type_etude')
 order by column_name;
