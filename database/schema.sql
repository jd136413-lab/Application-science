-- =====================================================================
-- Application science : schéma de la base (exécuté dans Supabase le 18/10/2026)
-- Supabase → SQL Editor → New query → New blank query → coller → Run
-- =====================================================================

create table if not exists public.advances (
  id           uuid primary key default gen_random_uuid(),
  title        text not null,
  summary      text not null,
  theme        text not null default 'other' check (theme in (
                 'space','astronomy','environment','climate','technology','ai',
                 'robotics','health','medicine','neuroscience','genetics','biology',
                 'chemistry','physics','quantum','materials','energy','ocean',
                 'geology','paleontology','archaeology','agriculture',
                 'mathematics','transportation','other')),
  family       text not null default 'other',
  importance   smallint not null default 2 check (importance between 1 and 5),
  source_url   text not null unique,
  source_name  text not null,
  published_at timestamptz not null default now(),
  created_at   timestamptz not null default now()
);

-- La famille est calculée automatiquement à partir du thème
create or replace function public.set_family() returns trigger
language plpgsql as $$
begin
  new.family := case
    when new.theme in ('space','astronomy') then 'space'
    when new.theme in ('environment','climate','ocean','agriculture') then 'environment'
    when new.theme in ('health','medicine','neuroscience') then 'health'
    when new.theme in ('technology','ai','robotics','energy','transportation') then 'technology'
    when new.theme in ('physics','quantum','chemistry','materials','mathematics') then 'physics'
    when new.theme in ('biology','genetics') then 'life'
    when new.theme in ('geology','paleontology','archaeology') then 'earth'
    else 'other'
  end;
  return new;
end $$;

drop trigger if exists advances_set_family on public.advances;
create trigger advances_set_family
  before insert or update of theme on public.advances
  for each row execute function public.set_family();

create index if not exists advances_published_idx
  on public.advances (published_at desc);
create index if not exists advances_family_published_idx
  on public.advances (family, published_at desc);
create index if not exists advances_importance_published_idx
  on public.advances (importance desc, published_at desc);

alter table public.advances enable row level security;

drop policy if exists "Lecture publique" on public.advances;
create policy "Lecture publique" on public.advances
  for select to anon, authenticated using (true);

grant select on public.advances to anon, authenticated;
revoke insert, update, delete on public.advances from anon, authenticated;
grant all on public.advances to service_role;
