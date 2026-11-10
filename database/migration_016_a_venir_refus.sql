-- Migration 016 (10/11/2026) : cartes « À venir » retirées comme doublons
-- L'agent note ici l'adresse de chaque carte retirée (doublon ou incohérente),
-- pour ne jamais la remettre dans l'onglet. Invisible pour l'app (aucune lecture publique).
create table if not exists upcoming_refus (
  source_url text primary key,
  raison text,
  created_at timestamptz not null default now()
);
alter table upcoming_refus enable row level security;
