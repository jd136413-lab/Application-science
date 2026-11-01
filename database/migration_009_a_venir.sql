-- =====================================================================
-- NovaSTEM : onglet « À venir » (01/11/2026, maquette 70)
-- Supabase → SQL Editor → New query → New blank query → coller → Run
--
-- Une table pour les événements datés à venir (lancements, sorties de
-- produits, résultats attendus, événements dans le ciel, grands sommets),
-- repérés par l'agent dans les articles qu'il lit.
-- L'app peut seulement LIRE ; seul l'agent (clé secrète) écrit.
-- Rien n'est supprimé ni modifié ailleurs. Le script peut être relancé.
-- =====================================================================

create table if not exists public.upcoming_events (
  id            uuid primary key default gen_random_uuid(),
  title         text not null check (length(title) <= 200),
  prevu         text,                       -- « Ce qui est prévu »
  pourquoi      text,                       -- « Pourquoi c'est important »
  type          text not null default 'evenement'
                check (type in ('lancement', 'sortie', 'resultats', 'ciel', 'evenement', 'annonce')),
  family        text,
  feed          text not null default 'science' check (feed in ('science', 'tech')),
  event_date    date not null,              -- jour de l'événement (heure de Paris)
  event_time    text check (event_time is null or event_time ~ '^[0-2][0-9]:[0-5][0-9]$'),
  precision     text not null default 'jour' check (precision in ('jour', 'mois')),
  importance    smallint not null default 2 check (importance between 1 and 5),
  source_url    text not null unique,
  source_name   text,
  previous_date date,                       -- ancienne date quand elle a changé (retard…)
  advance_id    uuid references public.advances(id) on delete set null,  -- « C'est arrivé »
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists upcoming_events_date_idx on public.upcoming_events (event_date);

alter table public.upcoming_events enable row level security;
drop policy if exists "lecture publique des événements à venir" on public.upcoming_events;
create policy "lecture publique des événements à venir"
  on public.upcoming_events for select to anon, authenticated using (true);
grant select on public.upcoming_events to anon, authenticated;

-- Vérification : doit afficher une ligne « upcoming_events »
select table_name from information_schema.tables
 where table_schema = 'public' and table_name = 'upcoming_events';
