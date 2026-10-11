-- כסא או מעשה, match mode (Lior 11.10): the player now casts their own vote per bill, and the game shows how often
-- it matches each MK's real vote. player_tag.tag holds F (בעד) / A (נגד) / B (נמנע/ת). The old K/M marks were test
-- data from before launch and are removed.
begin;

delete from player_tag;
drop view v_tag_tally;
alter table player_tag drop constraint player_tag_tag_check;
alter table player_tag add constraint player_tag_tag_check check (tag in ('F', 'A', 'B'));
comment on column player_tag.tag is 'the player''s own vote: F = בעד, A = נגד, B = נמנע/ת';

-- per bill: how the players voted
create view v_tag_tally as
  select vote_id, count(*) filter (where tag = 'F') as f, count(*) filter (where tag = 'A') as a,
         count(*) filter (where tag = 'B') as b
  from player_tag group by vote_id;

commit;
