-- 14.10: a third kind of share, the all-factions table from the end of the game
alter table share_event drop constraint if exists share_event_kind_check;
alter table share_event add constraint share_event_kind_check check (kind in ('summary', 'vote', 'open', 'factions'));
