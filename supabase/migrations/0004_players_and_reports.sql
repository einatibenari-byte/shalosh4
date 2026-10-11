-- number of distinct players (for "כולם"), and the "מצאת טעות?" reports from bill cards
begin;
create view v_tag_players as select count(distinct player_id) as players from player_tag;

create table error_report (
  id         bigserial primary key,
  created_at timestamptz not null default now(),
  vote_id    integer not null,
  text       text not null check (length(text) between 2 and 2000),
  handled    boolean not null default false
);
alter table error_report enable row level security;   -- no policies: written only by the site's server function
commit;
