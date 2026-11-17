-- Migration 018 (17/11/2026) : onglet « Soumettre » et boîte à idées (maquette 96).
-- À lancer une fois dans Supabase : SQL Editor → New query → coller tout → Run.
--
-- Sécurité (deux verrous) :
--   • Tout le monde peut ENVOYER une proposition (sujet, résumé, amélioration).
--   • Personne ne peut LIRE la table avec la clé publique de l'app : aucune règle de lecture.
--   • Chaque téléphone retrouve seulement SES propositions (identifiant aléatoire du téléphone).
--   • La boîte à idées ne s'ouvre qu'avec le code administrateur de Maxime, vérifié ICI,
--     dans la base. Le code n'est écrit nulle part dans l'app ; la base n'en garde qu'une
--     empreinte (bcrypt), jamais le code lui-même.

create extension if not exists pgcrypto with schema extensions;

-- 1. Le secret administrateur (une seule ligne, illisible depuis l'app)
create table if not exists admin_secret (
  id smallint primary key default 1 check (id = 1),
  code_hash text not null,
  -- Sujet de notification réservé au téléphone administrateur (impossible à deviner)
  sujet_notif text not null default 'adm_' || replace(gen_random_uuid()::text, '-', '')
);
alter table admin_secret enable row level security;   -- aucune règle : personne ne la lit

-- 2. Les propositions
create table if not exists submissions (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  appareil text not null check (char_length(appareil) between 20 and 64),
  genre text not null check (genre in ('sujet', 'resume', 'amelioration')),
  categorie text check (categorie in ('idee', 'bug', 'design')),
  sujet text check (char_length(sujet) <= 400),
  titre text check (char_length(titre) <= 160),
  resume text check (char_length(resume) <= 1500),
  lien text check (char_length(lien) <= 600),
  fil text check (fil in ('science', 'tech', 'a_venir')),
  -- Événement « À venir » proposé : type, date et précision (jour, mois ou inconnue)
  type_evt text check (char_length(type_evt) <= 30),
  quand date,
  quand_precision text check (quand_precision in ('jour', 'mois', 'inconnue')),
  infos text check (char_length(infos) <= 200),            -- version de l'app et téléphone
  -- nouvelle · en_cours · publiee · refusee (sujets et résumés)
  -- nouvelle · a_faire · faite · ignoree (améliorations)
  statut text not null default 'nouvelle',
  message text,                                            -- raison d'un refus, corrections…
  fiche_id uuid,
  notifiee boolean not null default false
);
create index if not exists submissions_appareil on submissions (appareil, created_at desc);
create index if not exists submissions_statut on submissions (statut, created_at desc);
alter table submissions enable row level security;

drop policy if exists "envoi public" on submissions;
create policy "envoi public" on submissions for insert to anon, authenticated
  with check (statut = 'nouvelle' and message is null and fiche_id is null and notifiee = false);
grant insert on submissions to anon, authenticated;

-- Anti-abus : 15 propositions par téléphone et par jour au plus
create or replace function submissions_limite() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from submissions
      where appareil = new.appareil and created_at > now() - interval '1 day') >= 15 then
    raise exception 'trop de propositions aujourd''hui';
  end if;
  return new;
end $$;
drop trigger if exists submissions_limite on submissions;
create trigger submissions_limite before insert on submissions
  for each row execute function submissions_limite();

-- 3. « Mes propositions » : seulement celles de ce téléphone
create or replace function mes_propositions(p_appareil text)
returns table (id uuid, created_at timestamptz, genre text, categorie text, fil text, texte text,
               statut text, message text, fiche_id uuid)
language sql stable security definer set search_path = public as $$
  select s.id, s.created_at, s.genre, s.categorie, s.fil, coalesce(s.titre, s.sujet), s.statut, s.message, s.fiche_id
  from submissions s
  where char_length(p_appareil) >= 20 and s.appareil = p_appareil
  order by s.created_at desc
  limit 50
$$;
grant execute on function mes_propositions(text) to anon, authenticated;

-- 4. Administration (code de Maxime vérifié dans la base)
create or replace function admin_verifier(p_code text) returns text
language sql stable security definer set search_path = public, extensions as $$
  select sujet_notif from admin_secret
  where id = 1 and char_length(coalesce(p_code, '')) >= 6 and code_hash = extensions.crypt(p_code, code_hash)
$$;
grant execute on function admin_verifier(text) to anon, authenticated;

create or replace function admin_propositions(p_code text)
returns setof submissions
language plpgsql stable security definer set search_path = public as $$
begin
  if admin_verifier(p_code) is null then
    raise exception 'code administrateur incorrect';
  end if;
  return query select * from submissions order by created_at desc limit 300;
end $$;
grant execute on function admin_propositions(text) to anon, authenticated;

create or replace function admin_statut(p_code text, p_id uuid, p_statut text, p_message text default null)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if admin_verifier(p_code) is null then
    raise exception 'code administrateur incorrect';
  end if;
  if p_statut not in ('nouvelle', 'a_faire', 'faite', 'ignoree', 'refusee') then
    raise exception 'statut inconnu';
  end if;
  update submissions set statut = p_statut, message = coalesce(p_message, message) where id = p_id;
end $$;
grant execute on function admin_statut(text, uuid, text, text) to anon, authenticated;

-- 5. Fiches proposées par un lecteur (bandeau « Proposée par un lecteur »)
alter table advances add column if not exists proposee boolean not null default false;

-- ---------------------------------------------------------------------------------------
-- ENSUITE (une seule fois), dans une NOUVELLE requête : choisis ton code (8 caractères au
-- moins, pas un mot du dictionnaire) et remplace TON_CODE ci-dessous, puis Run :
--
-- insert into admin_secret (code_hash)
-- values (extensions.crypt('TON_CODE', extensions.gen_salt('bf')))
-- on conflict (id) do update set code_hash = excluded.code_hash;
--
-- Puis supprime cette requête de l'historique du SQL Editor (menu ⋯ → Delete query).
-- Pour changer de code plus tard : relancer la même requête avec le nouveau code.
-- ---------------------------------------------------------------------------------------
