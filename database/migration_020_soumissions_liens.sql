-- Migration 020 (18/11/2026) : jusqu'à 5 liens d'articles par proposition, le 1er obligatoire.
-- À lancer une fois dans Supabase (après la 019) : SQL Editor → New query → coller → Run.
-- Peut être relancée sans risque.

-- Liens en plus du premier (colonne « lien ») : 4 au plus
alter table submissions add column if not exists liens_sup text[] not null default '{}'
  check (cardinality(liens_sup) <= 4);

-- « Mes propositions » : avec les liens en plus
drop function if exists mes_propositions(text);
create function mes_propositions(p_appareil text)
returns table (id uuid, created_at timestamptz, genre text, categorie text, fil text, texte text,
               statut text, message text, fiche_id uuid, sujet text, titre text, avant text,
               decouverte text, apres text, resume text, lien text, video text, type_evt text,
               quand date, quand_precision text, langue text, direct text, liens_sup text[])
language sql stable security definer set search_path = public as $$
  select s.id, s.created_at, s.genre, s.categorie, s.fil, coalesce(s.titre, s.sujet), s.statut, s.message,
         s.fiche_id, s.sujet, s.titre, s.avant, s.decouverte, s.apres, s.resume, s.lien, s.video, s.type_evt,
         s.quand, s.quand_precision, s.langue, s.direct, s.liens_sup
  from submissions s
  where char_length(p_appareil) >= 20 and s.appareil = p_appareil
  order by s.created_at desc
  limit 50
$$;
grant execute on function mes_propositions(text) to anon, authenticated;

-- Modifier (avant examen) : avec les liens en plus
create or replace function modifier_proposition(p_appareil text, p_id uuid, p jsonb) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  update submissions set
    sujet = p->>'sujet', titre = p->>'titre', avant = p->>'avant', decouverte = p->>'decouverte',
    apres = p->>'apres', resume = p->>'resume', lien = p->>'lien', video = p->>'video', direct = p->>'direct',
    fil = p->>'fil', type_evt = p->>'type_evt', quand = (p->>'quand')::date,
    quand_precision = p->>'quand_precision', langue = p->>'langue', categorie = p->>'categorie',
    infos = coalesce(p->>'infos', infos),
    liens_sup = coalesce(array(select jsonb_array_elements_text(p->'liens_sup')), '{}')
  where id = p_id and appareil = p_appareil and char_length(p_appareil) >= 20 and statut = 'nouvelle';
  return found;
end $$;
grant execute on function modifier_proposition(text, uuid, jsonb) to anon, authenticated;
