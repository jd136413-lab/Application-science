-- Migration 015 (10/11/2026) : traductions des événements « À venir »
-- L'agent traduit une fois chaque carte (titre, ce qui est prévu, pourquoi,
-- lieu, infos pratiques…) ; l'app affiche ces traductions tout de suite.
-- Format : {"en": {"texte français": "English text", ...}}
alter table upcoming_events add column if not exists traductions jsonb;
