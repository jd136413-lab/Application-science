-- Migration 021 (18/11/2026) : l'administrateur (Maxime) peut supprimer une fiche ou une carte
-- « À venir » directement depuis l'app. Le code administrateur est vérifié ICI (admin_verifier) :
-- sans lui, rien n'est supprimé.
-- Les adresses de la fiche supprimée sont notées comme « déjà vues » pour que l'agent ne la
-- recrée pas au passage suivant.
-- À lancer une fois dans Supabase : SQL Editor → New query → coller → Run. Relançable sans risque.

create or replace function admin_supprimer_fiche(p_code text, p_id uuid) returns boolean
language plpgsql security definer set search_path = public as $$
declare f record;
begin
  if admin_verifier(p_code) is null then
    raise exception 'code administrateur incorrect';
  end if;
  select source_url, autres_sources into f from advances where id = p_id;
  if not found then
    return false;
  end if;
  -- Ne plus jamais reprendre ces articles
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
    raise exception 'code administrateur incorrect';
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
