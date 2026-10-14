-- private stats page for Lior (14.10): /stats/#k=<key>, read through the site's server function only
begin;
create table admin_key (
  key        text primary key,
  note       text,
  created_at timestamptz not null default now()
);
alter table admin_key enable row level security;   -- no policies: read only by the site's server function

-- everything the stats page shows, in one call; times are Israel time
create or replace function game_stats() returns jsonb language sql stable as $$
  with p as (select player_id, min(updated_at) first_at, count(*) n from player_tag group by 1)
  select jsonb_build_object(
    'now', now(),
    'players', (select count(*) from p),
    'players_24h', (select count(*) from p where first_at > now() - interval '1 day'),
    'players_1h', (select count(*) from p where first_at > now() - interval '1 hour'),
    'marks', (select count(*) from player_tag),
    'bills', (select count(distinct vote_id) from player_tag),
    'first_at', (select min(first_at) from p),
    'median', (select percentile_cont(0.5) within group (order by n) from p),
    'avg', (select round(avg(n), 1) from p),
    'max', (select max(n) from p),
    'buckets', (select jsonb_object_agg(b, c) from (
        select case when n = 1 then '1' when n <= 4 then '2-4' when n <= 9 then '5-9' when n <= 24 then '10-24' when n <= 49 then '25-49' else '50+' end b, count(*) c
        from p group by 1) x),
    'tags', (select jsonb_object_agg(tag, c) from (select tag, count(*) c from player_tag group by 1) x),
    'hours', (select coalesce(jsonb_agg(jsonb_build_array(h, c) order by h), '[]') from (
        select to_char(date_trunc('hour', first_at at time zone 'Asia/Jerusalem'), 'YYYY-MM-DD"T"HH24') h, count(*) c
        from p where first_at > now() - interval '3 days' group by 1) x),
    'days', (select coalesce(jsonb_agg(jsonb_build_array(d, c) order by d), '[]') from (
        select to_char(first_at at time zone 'Asia/Jerusalem', 'YYYY-MM-DD') d, count(*) c from p group by 1) x),
    'top', (select coalesce(jsonb_agg(jsonb_build_array(vote_id, c, f, a, b) order by c desc), '[]') from (
        select vote_id, count(*) c, count(*) filter (where tag = 'F') f, count(*) filter (where tag = 'A') a, count(*) filter (where tag = 'B') b
        from player_tag group by 1 order by 2 desc limit 15) x),
    'shares', (select coalesce(jsonb_object_agg(kind, total), '{}') from v_share_counts),
    'reports', (select count(*) from error_report),
    'reports_open', (select count(*) from error_report where not handled)
  ) from (select 1) one;
$$;
revoke execute on function game_stats() from public, anon, authenticated;
commit;
