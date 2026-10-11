-- כסא או מעשה: each player's mark per bill (one row per player per bill; a later mark replaces the earlier one).
-- Podium totals = per bill, the players' majority mark; computed in the browser from tally().
-- Starts empty on launch day: nothing from the build/test period is carried over.
begin;

create table player_tag (
  player_id  uuid not null,                                -- random id kept in the player's browser, no personal data
  vote_id    integer not null,                             -- KNS plenum vote id of the bill card
  tag        char(1) not null check (tag in ('K', 'M')),   -- K = כסא, M = מעשה
  updated_at timestamptz not null default now(),
  primary key (player_id, vote_id)
);
create index on player_tag (vote_id);

alter table player_tag enable row level security;          -- no policies: only the site's server function writes or reads

-- per bill: how many players marked כסא and how many מעשה
create view v_tag_tally as
  select vote_id, count(*) filter (where tag = 'K') as k, count(*) filter (where tag = 'M') as m
  from player_tag group by vote_id;

commit;
