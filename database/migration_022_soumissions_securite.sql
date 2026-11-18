-- Migration 022 (18/11/2026) : sécurité des propositions (audit du 18/11).
-- À lancer une fois dans Supabase (après la 021) : SQL Editor → New query → coller tout → Run.
-- Peut être relancée sans risque.
--
-- Pourquoi : la clé publique de l'app est lisible par tout le monde. Quelqu'un peut donc
-- envoyer des propositions SANS passer par l'app, et sauter tous les contrôles du formulaire.
-- Tout ce qui compte est maintenant vérifié ICI, dans la base :
--   1. Date, statut et identifiant imposés par la base (avant : une date d'envoi antidatée
--      contournait la limite d'une proposition par semaine).
--   2. Texte nettoyé : caractères invisibles et caractères qui inversent le sens d'écriture retirés.
--   3. Champs obligatoires et liens contrôlés (https://… ou http://…, rien d'autre).
--   4. Plafond global : 30 propositions par heure pour tout le monde (avant : changer
--      d'identifiant de téléphone à chaque envoi permettait d'en envoyer sans fin).
--   5. Code administrateur : au-delà de 30 codes faux en une heure, tout est bloqué une heure
--      (avant : on pouvait essayer environ 250 codes par seconde).
--   6. Limites de longueur doublées (un emoji compte pour 1 dans l'app mais jusqu'à 7 ici).
--   7. Compteur d'essais pour l'agent (une proposition qui plante n'est plus retentée sans fin).

-- ------------------------------------------------------------------ 7. Compteur d'essais
alter table submissions add column if not exists essais smallint not null default 0;

-- ------------------------------------------------------------------ 6. Longueurs (×2)
alter table submissions drop constraint if exists submissions_sujet_check;
alter table submissions add constraint submissions_sujet_check check (char_length(sujet) <= 800);
alter table submissions drop constraint if exists submissions_titre_check;
alter table submissions add constraint submissions_titre_check check (char_length(titre) <= 320);
alter table submissions drop constraint if exists submissions_resume_check;
alter table submissions add constraint submissions_resume_check check (char_length(resume) <= 3000);
alter table submissions drop constraint if exists submissions_avant_check;
alter table submissions add constraint submissions_avant_check check (char_length(avant) <= 1200);
alter table submissions drop constraint if exists submissions_decouverte_check;
alter table submissions add constraint submissions_decouverte_check check (char_length(decouverte) <= 1800);
alter table submissions drop constraint if exists submissions_apres_check;
alter table submissions add constraint submissions_apres_check check (char_length(apres) <= 1200);

-- ------------------------------------------------------------------ 2 et 3. Nettoyage et contrôles
-- Retire les caractères de contrôle (sauf retour à la ligne et tabulation), les espaces
-- invisibles et les caractères qui inversent le sens d'écriture (ils permettent d'afficher
-- un texte différent de ce qui est vraiment écrit). Le « joint » des emojis (U+200D) est gardé.
create or replace function sub_nettoyer(t text) returns text
language sql immutable as $$
  select nullif(btrim(regexp_replace(coalesce(t, ''),
    '[\x01-\x08\x0B\x0C\x0E-\x1F\x7F​‎‏‪-‮⁦-⁩﻿]', '', 'g')), '')
$$;

-- Un lien d'article : http(s)://nom.domaine/…, sans espace, 600 caractères au plus.
create or replace function sub_lien_ok(u text) returns boolean
language sql immutable as $$
  select u is not null and char_length(u) <= 600 and u ~* '^https?://[a-z0-9.-]+\.[a-z]{2,}(:[0-9]+)?([/?#][^[:space:]]*)?$'
$$;

create or replace function submissions_controle() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    -- 1. Imposé par la base, quoi qu'envoie le téléphone
    new.id := gen_random_uuid();
    new.created_at := now();
    new.statut := 'nouvelle';
    new.message := null;
    new.fiche_id := null;
    new.notifiee := false;
    new.essais := 0;
  elsif (new.sujet, new.titre, new.resume, new.avant, new.decouverte, new.apres, new.lien, new.liens_sup,
         new.video, new.direct, new.type_evt, new.infos)
        is not distinct from
        (old.sujet, old.titre, old.resume, old.avant, old.decouverte, old.apres, old.lien, old.liens_sup,
         old.video, old.direct, old.type_evt, old.infos) then
    return new;   -- changement de statut par l'agent ou l'administrateur : rien à contrôler
  end if;

  -- 2. Nettoyage
  new.sujet := sub_nettoyer(new.sujet);
  new.titre := sub_nettoyer(new.titre);
  new.resume := sub_nettoyer(new.resume);
  new.avant := sub_nettoyer(new.avant);
  new.decouverte := sub_nettoyer(new.decouverte);
  new.apres := sub_nettoyer(new.apres);
  new.type_evt := sub_nettoyer(new.type_evt);
  new.infos := sub_nettoyer(new.infos);
  new.lien := nullif(btrim(coalesce(new.lien, '')), '');
  new.video := nullif(btrim(coalesce(new.video, '')), '');
  new.direct := nullif(btrim(coalesce(new.direct, '')), '');
  new.liens_sup := coalesce(array(select btrim(x) from unnest(new.liens_sup) x where btrim(coalesce(x, '')) <> ''), '{}');

  -- 3. Contrôles
  if new.genre = 'amelioration' and new.sujet is null then
    raise exception 'proposition_invalide : texte vide';
  end if;
  if new.genre = 'sujet' and new.sujet is null then
    raise exception 'proposition_invalide : sujet vide';
  end if;
  if new.genre = 'resume' and (new.titre is null or new.decouverte is null) then
    raise exception 'proposition_invalide : titre ou découverte vide';
  end if;
  if new.genre in ('sujet', 'resume') and not sub_lien_ok(new.lien) then
    raise exception 'proposition_invalide : lien d''article manquant ou incorrect';
  end if;
  if new.lien is not null and not sub_lien_ok(new.lien) then
    raise exception 'proposition_invalide : lien incorrect';
  end if;
  if exists (select 1 from unnest(new.liens_sup) x where not sub_lien_ok(x)) then
    raise exception 'proposition_invalide : lien supplémentaire incorrect';
  end if;
  if new.video is not null and new.video !~* '^https://[a-z0-9.-]+\.[a-z]{2,}/[^[:space:]]*$' then
    raise exception 'proposition_invalide : lien de vidéo incorrect';
  end if;
  if new.direct is not null and new.direct !~* '^https://[a-z0-9.-]+\.[a-z]{2,}/[^[:space:]]*$' then
    raise exception 'proposition_invalide : lien du direct incorrect';
  end if;
  return new;
end $$;
drop trigger if exists submissions_controle on submissions;
-- (les déclencheurs s'exécutent par ordre alphabétique : « controle » passe avant « limite »)
create trigger submissions_controle before insert or update on submissions
  for each row execute function submissions_controle();

-- ------------------------------------------------------------------ 4. Limites (par semaine + plafond global)
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
  select count(*) into n from submissions s
   where s.created_at > now() - interval '1 hour'
     and not exists (select 1 from admin_appareils a where a.appareil = s.appareil);
  if n >= 30 then
    raise exception 'trop_de_propositions';
  end if;
  return new;
end $$;

-- ------------------------------------------------------------------ 5. Code administrateur
create table if not exists admin_essais (moment timestamptz not null default now());
alter table admin_essais enable row level security;   -- aucune règle : illisible depuis l'app
create index if not exists admin_essais_moment on admin_essais (moment);

create or replace function admin_verifier(p_code text) returns text
language plpgsql volatile security definer set search_path = public, extensions as $$
declare s text;
begin
  -- Plus de 30 codes faux en une heure : tout est refusé pendant une heure, même le bon code.
  if (select count(*) from admin_essais where moment > now() - interval '1 hour') >= 30 then
    return null;
  end if;
  select sujet_notif into s from admin_secret
   where id = 1 and char_length(coalesce(p_code, '')) >= 6 and code_hash = extensions.crypt(p_code, code_hash);
  if s is null then
    insert into admin_essais default values;
    delete from admin_essais where moment < now() - interval '1 day';
  end if;
  return s;
end $$;
grant execute on function admin_verifier(text) to anon, authenticated;

-- Les fonctions administrateur ne lèvent plus d'erreur sur un code faux : une erreur annulerait
-- l'enregistrement de l'essai raté (et le compteur ne servirait à rien). Elles ne font rien.
create or replace function admin_propositions(p_code text)
returns setof submissions
language plpgsql volatile security definer set search_path = public as $$
begin
  if admin_verifier(p_code) is null then
    return;
  end if;
  return query select * from submissions order by created_at desc limit 300;
end $$;
grant execute on function admin_propositions(text) to anon, authenticated;

create or replace function admin_statut(p_code text, p_id uuid, p_statut text, p_message text default null)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if admin_verifier(p_code) is null then
    return;
  end if;
  if p_statut not in ('nouvelle', 'a_faire', 'faite', 'ignoree', 'refusee') then
    raise exception 'statut inconnu';
  end if;
  update submissions set statut = p_statut, message = coalesce(p_message, message) where id = p_id;
end $$;
grant execute on function admin_statut(text, uuid, text, text) to anon, authenticated;

create or replace function admin_supprimer_fiche(p_code text, p_id uuid) returns boolean
language plpgsql security definer set search_path = public as $$
declare f record;
begin
  if admin_verifier(p_code) is null then
    return false;
  end if;
  select source_url, autres_sources into f from advances where id = p_id;
  if not found then
    return false;
  end if;
  insert into seen_urls (url, reason) values (f.source_url, 'retiree_admin') on conflict (url) do nothing;
  insert into seen_urls (url, reason)
    select s->>'url', 'retiree_admin' from jsonb_array_elements(coalesce(f.autres_sources, '[]'::jsonb)) s
    where coalesce(s->>'url', '') <> ''
  on conflict (url) do nothing;
  delete from advances where id = p_id;
  return true;
end $$;
grant execute on function admin_supprimer_fiche(text, uuid) to anon, authenticated;

create or replace function admin_supprimer_evenement(p_code text, p_id uuid) returns boolean
language plpgsql security definer set search_path = public as $$
declare u text;
begin
  if admin_verifier(p_code) is null then
    return false;
  end if;
  select source_url into u from upcoming_events where id = p_id;
  if not found then
    return false;
  end if;
  if coalesce(u, '') <> '' then
    insert into upcoming_refus (source_url, raison) values (u, 'retiree_admin')
    on conflict (source_url) do nothing;
  end if;
  delete from upcoming_events where id = p_id;
  return true;
end $$;
grant execute on function admin_supprimer_evenement(text, uuid) to anon, authenticated;
