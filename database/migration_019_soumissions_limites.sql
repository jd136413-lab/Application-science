-- Migration 019 (17/11/2026) : limite de propositions PAR SEMAINE et détail d'une proposition.
-- À lancer une fois dans Supabase (après la 018) : SQL Editor → New query → coller → Run.
--
-- • Par téléphone et par semaine (7 jours glissants) : 1 sujet, 1 résumé et 1 amélioration,
--   soit 3 propositions au plus. Le téléphone administrateur n'a pas de limite.
-- • « Mes propositions » renvoie maintenant tout ce que la personne a envoyé, pour l'écran
--   de détail (ce qui se passe après l'envoi).

-- 1. Téléphones administrateurs (enregistrés quand le bon code est saisi), illisibles depuis l'app
create table if not exists admin_appareils (
  appareil text primary key,
  ajoute_le timestamptz not null default now()
);
alter table admin_appareils enable row level security;

create or replace function admin_activer(p_code text, p_appareil text) returns text
language plpgsql security definer set search_path = public as $$
declare s text;
begin
  s := admin_verifier(p_code);
  if s is not null and char_length(coalesce(p_appareil, '')) >= 20 then
    insert into admin_appareils (appareil) values (p_appareil) on conflict do nothing;
  end if;
  return s;
end $$;
grant execute on function admin_activer(text, text) to anon, authenticated;

-- 2. Limite par semaine : 1 par sorte (remplace la limite de 15 par jour de la migration 018)
create or replace function submissions_limite() returns trigger
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if exists (select 1 from admin_appareils where appareil = new.appareil) then
    return new;
  end if;
  select count(*) into n from submissions
   where appareil = new.appareil and created_at > now() - interval '7 days' and genre = new.genre;
  if n >= 1 then
    raise exception 'limite_semaine';
  end if;
  return new;
end $$;

-- 3. « Mes propositions » avec tout le contenu envoyé
drop function if exists mes_propositions(text);
create function mes_propositions(p_appareil text)
returns table (id uuid, created_at timestamptz, genre text, categorie text, fil text, texte text,
               statut text, message text, fiche_id uuid, sujet text, titre text, avant text,
               decouverte text, apres text, resume text, lien text, video text, type_evt text,
               quand date, quand_precision text, langue text)
language sql stable security definer set search_path = public as $$
  select s.id, s.created_at, s.genre, s.categorie, s.fil, coalesce(s.titre, s.sujet), s.statut, s.message,
         s.fiche_id, s.sujet, s.titre, s.avant, s.decouverte, s.apres, s.resume, s.lien, s.video, s.type_evt,
         s.quand, s.quand_precision, s.langue
  from submissions s
  where char_length(p_appareil) >= 20 and s.appareil = p_appareil
  order by s.created_at desc
  limit 50
$$;
grant execute on function mes_propositions(text) to anon, authenticated;

-- 4. Supprimer une de SES propositions (pas pendant sa vérification). Une fiche déjà publiée reste
--    publiée : seule la proposition disparaît de « Mes propositions ».
create or replace function supprimer_proposition(p_appareil text, p_id uuid) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  delete from submissions
   where id = p_id and appareil = p_appareil and char_length(p_appareil) >= 20 and statut <> 'en_cours';
  return found;
end $$;
grant execute on function supprimer_proposition(text, uuid) to anon, authenticated;

-- Ce fichier peut être relancé sans risque (tout est « create or replace » ou « if not exists »).
