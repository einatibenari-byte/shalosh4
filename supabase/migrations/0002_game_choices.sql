-- כסא או מעשה: what players chose for each MK and bill. Written only by the game's server
-- component with the secret key; no public read (totals are published as a static file).

begin;

create type game_choice as enum ('kise', 'maase');   -- כסא / מעשה

create table game_choice_log (
  id         bigserial primary key,
  played_at  timestamptz not null default now(),
  game_id    uuid not null,                          -- one random id per game, no personal data
  person_id  integer not null references person,
  vote_id    integer not null,                       -- KNS vote id the card showed
  choice     game_choice not null
);
create index on game_choice_log (person_id);

alter table game_choice_log enable row level security;   -- no policies: anon/public cannot read or write

create view v_game_totals as
  select person_id, choice, count(*) as n
  from game_choice_log group by person_id, choice;

commit;
