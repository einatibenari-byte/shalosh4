-- shares from the game (Lior 13.10): one row per completed share, and per visit that came from a shared link
begin;
create table share_event (
  id         bigserial primary key,
  created_at timestamptz not null default now(),
  kind       text not null check (kind in ('summary', 'vote', 'open')),  -- summary card / single vote / someone opened a shared link
  how        text check (how in ('sheet', 'download')),                  -- phone share sheet, or saved the image on a computer
  target     text check (length(target) <= 40)                           -- MK/faction id or vote id, when known
);
alter table share_event enable row level security;   -- no policies: written only by the site's server function
create view v_share_counts as
  select kind, count(*) as total, count(*) filter (where created_at > now() - interval '1 day') as last_24h
  from share_event group by kind;
commit;
