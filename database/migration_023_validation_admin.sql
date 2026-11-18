-- Migration 023 (18/11/2026) : les résumés écrits par un lecteur attendent ta validation.
-- À lancer une fois dans Supabase (après la 022) : SQL Editor → New query → coller tout → Run.
-- Peut être relancée sans risque.
--
-- Comment ça marche :
--   • L'agent « Soumissions » prépare la fiche complète (vérifiée, traduite, avec sa vidéo) et
--     l'enregistre « en attente » : elle est INVISIBLE pour tout le monde (toutes les versions de
--     l'app et le site web), grâce à la règle de lecture de la table advances.
--   • Dans la boîte à idées, tu l'ouvres telle qu'elle apparaîtra, puis « Publier » ou « Refuser ».
--   • Publier : elle apparaît dans le fil. Refuser : elle est supprimée et le lecteur voit ta raison.

-- 1. Fiche en attente : invisible avec la clé publique de l'app
alter table advances add column if not exists en_attente boolean not null default false;

drop policy if exists "Lecture publique" on public.advances;
create policy "Lecture publique" on public.advances
  for select to anon, authenticated using (not en_attente);

-- 2. Voir une fiche en attente (administrateur seulement)
create or replace function admin_fiche(p_code text, p_id uuid) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
begin
  if admin_verifier(p_code) is null then
    return null;
  end if;
  return (select to_jsonb(a) from advances a where a.id = p_id);
end $$;
grant execute on function admin_fiche(text, uuid) to anon, authenticated;

-- 3. Publier ou refuser une proposition en attente (administrateur seulement)
create or replace function admin_valider(p_code text, p_id uuid, p_publier boolean, p_message text default null)
returns boolean
language plpgsql security definer set search_path = public as $$
declare f uuid; u text;
begin
  if admin_verifier(p_code) is null then
    return false;
  end if;
  select fiche_id into f from submissions where id = p_id and statut = 'a_valider';
  if not found then
    return false;
  end if;
  if p_publier then
    update advances set en_attente = false where id = f;
    update submissions set statut = 'publiee' where id = p_id;
  else
    select source_url into u from advances where id = f and en_attente;
    if u is not null then
      -- L'agent ne reprendra pas cet article de lui-même
      insert into seen_urls (url, reason) values (u, 'retiree_admin') on conflict (url) do nothing;
      delete from advances where id = f and en_attente;
    end if;
    update submissions set statut = 'refusee', fiche_id = null,
      message = coalesce(nullif(btrim(coalesce(p_message, '')), ''), 'Non retenue après relecture.')
     where id = p_id;
  end if;
  return true;
end $$;
grant execute on function admin_valider(text, uuid, boolean, text) to anon, authenticated;

-- 4. Si le lecteur supprime sa proposition pendant l'attente, la fiche cachée part avec elle
create or replace function supprimer_proposition(p_appareil text, p_id uuid) returns boolean
language plpgsql security definer set search_path = public as $$
declare f uuid;
begin
  select fiche_id into f from submissions
   where id = p_id and appareil = p_appareil and char_length(p_appareil) >= 20 and statut = 'a_valider';
  if found and f is not null then
    delete from advances where id = f and en_attente;
  end if;
  delete from submissions
   where id = p_id and appareil = p_appareil and char_length(p_appareil) >= 20 and statut <> 'en_cours';
  return found;
end $$;
grant execute on function supprimer_proposition(text, uuid) to anon, authenticated;
