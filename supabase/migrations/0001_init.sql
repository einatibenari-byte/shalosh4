-- תעודת יושר: first migration (stage 3 data model). Postgres 15+ (Supabase).
-- Every displayed fact points at a source row. Nothing about a person is entered without one.
-- Names follow the brief's entity table (Person, Term, Position, Faction, Bill, Vote, ...).

begin;

-- ---------------------------------------------------------------- enums (closed lists from the brief)
create type attribution_level as enum (
  'demanded', 'promoted', 'committee_secured', 'allocated', 'transferred', 'ministry_action');  -- no new levels without approval
create type position_kind as enum ('mk', 'minister', 'deputy_minister', 'committee_chair', 'faction_chair', 'other');
create type initiator_role as enum ('primary', 'signer', 'joined');
create type vote_stage as enum ('preliminary', 'first', 'second_third', 'other');
create type vote_choice as enum ('for', 'against', 'abstain', 'present', 'absent');   -- 'present' = נוכח, counts as did not vote
create type review_status as enum ('draft', 'approved', 'rejected');
create type promise_origin as enum ('mk_words', 'platform');
create type action_kind as enum ('query', 'agenda_motion', 'committee_session_chaired', 'committee_session_initiated', 'other');
create type self_tag_cat as enum ('pay', 'immunity', 'elections_parties', 'knesset_gov_structure');

-- ---------------------------------------------------------------- sources and raw ingestion
create table source (
  id            bigserial primary key,
  url           text not null,
  kind          text not null,              -- e.g. 'odata:KNS_Bill', 'pdf:platform', 'xlsx:accountant'
  title         text,
  published_on  date,
  period_from   date,
  period_to     date,
  fetched_at    timestamptz not null default now(),
  content_hash  text,
  unique (url, content_hash)
);

-- raw rows exactly as fetched; ingestion re-runs only what changed (hash)
create table raw_record (
  id           bigserial primary key,
  endpoint     text not null,               -- 'KNS_Bill', 'KNS_PlenumVoteResult', ...
  external_id  text not null,
  payload      jsonb not null,
  hash         text not null,
  fetched_at   timestamptz not null default now(),
  unique (endpoint, external_id, hash)
);

-- ---------------------------------------------------------------- people, factions, positions
create table person (
  id               integer primary key,     -- KNS_Person.PersonID
  first_name       text not null,
  last_name        text not null,
  full_name        text generated always as (first_name || ' ' || last_name) stored,
  gender           char(1) check (gender in ('f', 'm')),   -- for Hebrew grammatical forms only
  illustration_url text,
  links            jsonb not null default '{}',
  source_id        bigint references source,
  updated_at       timestamptz not null default now()
);

create table faction (
  id          integer primary key,          -- KNS_Faction.FactionID
  name        text not null,
  knesset_num smallint not null,
  start_date  date,
  finish_date date,
  party_name  text,                         -- the list that ran in the election, when it differs
  source_id   bigint references source
);

-- splits and mergers during the term
create table faction_lineage (
  from_faction integer not null references faction,
  to_faction   integer not null references faction,
  kind         text not null check (kind in ('split', 'merge', 'rename')),
  on_date      date not null,
  source_id    bigint references source,
  primary key (from_faction, to_faction, on_date)
);

-- Term: membership of a person in a faction, by dates (every aggregate is attributed by date)
create table term (
  id          bigserial primary key,
  person_id   integer not null references person,
  faction_id  integer not null references faction,
  knesset_num smallint not null,
  from_date   date not null,
  to_date     date,                          -- null = still a member
  source_id   bigint references source,
  check (to_date is null or to_date >= from_date)
);
create index on term (faction_id, from_date);
create index on term (person_id);

create table position (
  id          bigserial primary key,
  person_id   integer not null references person,
  kind        position_kind not null,
  body        text,                          -- ministry / committee name
  body_id     integer,                       -- GovMinistryID / CommitteeID
  knesset_num smallint not null,
  from_date   date not null,
  to_date     date,
  source_id   bigint references source
);
create index on position (person_id, kind);

-- ---------------------------------------------------------------- topics (closed list, managed in admin)
create table topic (
  code      text primary key,               -- 'WEL', 'JUS', ...
  name      text not null,
  is_social boolean not null default false, -- women, education, welfare, housing, health, workers: every vote on these is shown
  sort      smallint not null default 0
);

-- ---------------------------------------------------------------- bills and other actions
create table bill (
  id                 integer primary key,    -- KNS_Bill.BillID
  knesset_num        smallint not null,
  name               text not null,          -- official name
  sub_type           text,                   -- פרטית / ממשלתית / ועדה
  private_number     integer,
  status_id          integer,
  status_desc        text,
  submitted_on       date,
  explanatory_url    text,
  union_group        integer,                -- identical bills merged (KNS_BillUnion)
  self_tag           self_tag_cat,           -- "נוגע לנבחרים עצמם", one broad tag
  self_tag_basis     text,                   -- the law it amends / why
  is_dissolution     boolean not null default false,  -- counted in totals, never shown in topics or tags
  source_id          bigint references source
);

create table bill_initiator (
  bill_id   integer not null references bill,
  person_id integer not null references person,
  role      initiator_role not null,
  ordinal   smallint,
  primary key (bill_id, person_id)
);
create index on bill_initiator (person_id);

create table bill_topic (
  bill_id    integer not null references bill,
  topic_code text not null references topic,
  is_primary boolean not null default true,
  status     review_status not null default 'draft',   -- classification is a draft until reviewed
  primary key (bill_id, topic_code)
);

-- queries, agenda motions, committee sessions: anything a person did that isn't a bill
create table action (
  id                bigserial primary key,
  person_id         integer not null references person,
  kind              action_kind not null,
  title             text not null,
  on_date           date,
  external_id       text,
  bill_id           integer references bill,
  attribution_level attribution_level not null,
  source_id         bigint not null references source
);
create index on action (person_id, kind);

-- ---------------------------------------------------------------- votes
create table vote (
  id              integer primary key,       -- KNS_PlenumVote.Id
  knesset_num     smallint not null,
  voted_at        timestamptz not null,
  bill_id         integer references bill,
  stage           vote_stage not null,
  official_title  text not null,
  topic_code      text references topic,
  for_count       smallint,
  against_count   smallint,
  abstain_count   smallint,
  passed          boolean,                   -- stored, shown only in the sources table
  important_rule  boolean not null default false,  -- 105 voters / 15 committee sessions / 30 reservations
  excluded_reason text,                      -- e.g. 'dissolution', 'budget-technical'
  in_plain_list   boolean not null default false,  -- shown in the short for/against list
  source_id       bigint references source
);
create index on vote (bill_id);
create index on vote (voted_at);

create table vote_record (
  vote_id   integer not null references vote,
  person_id integer not null references person,
  choice    vote_choice not null,
  primary key (vote_id, person_id)
);
create index on vote_record (person_id);

-- the fixed headline list, same on every page
create table key_issue (
  id      serial primary key,
  label   text not null,
  vote_id integer not null references vote,
  sort    smallint not null,
  set_by  text not null,
  set_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------- presence and benchmarks
create table attendance (
  person_id         integer not null references person,
  knesset_num       smallint not null,
  period_from       date not null,
  period_to         date not null,
  plenum_vote_days  smallint,                -- days with at least one recorded vote by the MK
  committee_days    smallint,                -- null = no data (shown as "חסר נתון")
  days_served       smallint not null,       -- for normalising partial terms
  method            text not null,
  source_id         bigint references source,
  primary key (person_id, knesset_num, period_from)
);

create table benchmark (
  metric       text not null,                -- 'plenum_vote_days', 'committee_days'
  knesset_num  smallint not null,
  group_desc   text not null,                -- '50 full-term MKs who held no government post'
  n            smallint not null,
  median       numeric not null,
  min_value    numeric,
  max_value    numeric,
  total_days   smallint,                     -- e.g. 373 plenum days with recorded votes
  computed_at  timestamptz not null default now(),
  primary key (metric, knesset_num, group_desc)
);

-- ---------------------------------------------------------------- promises
create table promise (
  id            bigserial primary key,
  person_id     integer references person,
  faction_id    integer references faction,
  quote         text not null,               -- exact words
  context       text,
  origin        promise_origin not null,
  said_on       date,
  sort          smallint not null,           -- order given by the fixed rule, never by later deeds
  rule_version  text not null,
  source_id     bigint not null references source,
  check ((person_id is null) <> (faction_id is null))
);

-- ---------------------------------------------------------------- money (phase 2; table ready, nothing shown)
create table money_item (
  id                bigserial primary key,
  person_id         integer references person,
  faction_id        integer references faction,
  amount_ils        numeric not null,
  chain_stage       text not null check (chain_stage in ('promise', 'agreement', 'allocation', 'transfer', 'execution', 'salary', 'office')),
  description       text,
  period_from       date,
  period_to         date,
  attribution_level attribution_level not null,
  source_id         bigint not null references source
);

-- ---------------------------------------------------------------- AI text and the approval queue
-- plain bill titles, vote labels, summary sentences, plain promise wording: all drafts until approved
create table ai_text (
  id             bigserial primary key,
  target_table   text not null,              -- 'bill', 'vote', 'person', 'faction', 'promise'
  target_id      text not null,
  field          text not null,              -- 'plain_title', 'summary', 'plain'
  text           text not null,
  model          text not null,
  prompt_version text not null,
  source_ids     bigint[] not null,
  status         review_status not null default 'draft',
  reviewed_by    text,
  reviewed_at    timestamptz,
  created_at     timestamptz not null default now()
);
create index on ai_text (target_table, target_id, field, status);

-- ---------------------------------------------------------------- corrections, replies, change log
create table correction (
  id           bigserial primary key,
  target_table text not null,
  target_id    text not null,
  kind         text not null check (kind in ('error_report', 'official_reply')),
  description  text not null,
  submitted_by text,
  source_url   text,
  status       review_status not null default 'draft',
  public_note  text,
  created_at   timestamptz not null default now(),
  resolved_at  timestamptz
);

create table change_log (
  id         bigserial primary key,
  at         timestamptz not null default now(),
  actor      text not null,
  table_name text not null,
  row_id     text not null,
  action     text not null,
  diff       jsonb
);

-- ---------------------------------------------------------------- views the pages read
-- Approved AI text only; drafts never reach the site.
create view v_ai_published as
  select distinct on (target_table, target_id, field) target_table, target_id, field, text, source_ids
  from ai_text where status = 'approved'
  order by target_table, target_id, field, reviewed_at desc;

-- A bill belongs to a faction if any initiator was a member on the day it was submitted. KNS_Bill has no
-- submission date, so until ingestion fills submitted_on (open: from the bill's first document or history),
-- a bill without one counts for the faction the initiator belonged to in that Knesset.
create view v_faction_bill as
  select distinct t.faction_id, b.id as bill_id
  from bill b
  join bill_initiator bi on bi.bill_id = b.id
  join term t on t.person_id = bi.person_id and t.knesset_num = b.knesset_num
   and (b.submitted_on is null
        or (b.submitted_on >= t.from_date and (t.to_date is null or b.submitted_on <= t.to_date)));

-- How each faction's members voted, counting only people who were members on the vote date.
create view v_faction_vote as
  select t.faction_id, v.id as vote_id,
         count(*) filter (where vr.choice = 'for')                          as n_for,
         count(*) filter (where vr.choice = 'against')                      as n_against,
         count(*) filter (where vr.choice is null or vr.choice in ('abstain', 'present', 'absent')) as n_not_voted,
         count(*)                                                           as n_members
  from vote v
  join term t on v.voted_at::date >= t.from_date and (t.to_date is null or v.voted_at::date <= t.to_date)
  left join vote_record vr on vr.vote_id = v.id and vr.person_id = t.person_id
  group by t.faction_id, v.id;

create view v_faction_vote_majority as
  select *, case
    when n_for * 2 > n_members then 'for'
    when n_against * 2 > n_members then 'against'
    when n_not_voted * 2 > n_members then 'not_voted'
    else 'no_majority' end as majority
  from v_faction_vote;

-- ---------------------------------------------------------------- public read access (Supabase RLS)
-- The public site reads with the anon key: read-only, and never the draft queue or corrections inbox.
do $$
declare t text;
begin
  foreach t in array array['source','person','faction','faction_lineage','term','position','topic','bill',
                           'bill_initiator','bill_topic','action','vote','vote_record','key_issue','attendance',
                           'benchmark','promise','money_item','ai_text','correction','change_log','raw_record']
  loop
    execute format('alter table %I enable row level security', t);
  end loop;
  foreach t in array array['source','person','faction','faction_lineage','term','position','topic','bill',
                           'bill_initiator','action','vote','vote_record','key_issue','attendance','benchmark','promise']
  loop
    execute format('create policy public_read on %I for select using (true)', t);
  end loop;
end $$;
create policy public_read on bill_topic for select using (status = 'approved');
create policy public_read on ai_text    for select using (status = 'approved');
create policy public_read on correction for select using (kind = 'official_reply' and status = 'approved');

commit;
