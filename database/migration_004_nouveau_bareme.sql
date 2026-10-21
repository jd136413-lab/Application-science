-- =====================================================================
-- NovaSTEM — migration 004 : nouveau barème d'importance (21/10/2026)
-- ---------------------------------------------------------------------
-- Le barème est décalé d'un cran pour que les notes correspondent aux
-- fréquences de l'écran Notifications :
--   ★ Intéressant (la note normale) · ★★ Notable (≈ 3 par jour)
--   ★★★ Important (quelques-unes par semaine) · ★★★★ Majeur (par mois)
--   ★★★★★ Rupture (par an)
-- Les fiches déjà publiées passent donc : 3 → 2 et 2 → 1.
-- Les notes 1, 4 et 5 ne changent pas.
--
-- À lancer UNE SEULE FOIS : Supabase → SQL Editor → New query →
-- New blank query → coller ce fichier → Run.
-- (Le relancer décalerait encore les notes : la garde ci-dessous l'empêche.)
-- =====================================================================

create table if not exists public.migrations_faites (
  nom   text primary key,
  le    timestamptz not null default now()
);
alter table public.migrations_faites enable row level security;

do $$
begin
  if exists (select 1 from public.migrations_faites where nom = '004_nouveau_bareme') then
    raise notice 'Déjà fait : rien n''a été changé.';
    return;
  end if;

  update public.advances
     set importance = importance - 1
   where importance in (2, 3);

  insert into public.migrations_faites (nom) values ('004_nouveau_bareme');
  raise notice 'Nouveau barème appliqué.';
end $$;

-- Vérification : nombre de fiches par note
select importance, count(*) as fiches
  from public.advances
 group by importance
 order by importance;
