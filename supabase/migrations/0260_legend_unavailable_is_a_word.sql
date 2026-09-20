-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0260 (#1597) — the one legend word a workspace could not say.
--
-- #1281 gave a space the SIMPLE legend profile: blocked and closed are
-- one answer to a member, «you cannot have this», so the canvas paints
-- one group and `SeatLegend` renders one word — `legendUnavailable`.
--
-- That word was never registered. It is in the five ARB bundles and on
-- screen, and it is in neither `lexiconAllowList`, nor `lexiconDefault`,
-- nor the list below. Three consequences, none of them loud:
--
--   * the wording editor does not offer it, so the term cannot be
--     displayed, saved, removed or reset;
--   * `set_workspace_lexicon_term` raises `unknown wording key`;
--   * `imported_lexicon` filters an incoming template against this
--     function and drops the term WITHOUT a word — a template carrying
--     «Place non disponible» applies, reports success, and the legend
--     still says «Indisponible».
--
-- The last one is what made it worth a migration rather than a client
-- patch: the loss happens server-side, inside the supported export →
-- template → apply workflow.
--
-- Additive: one more row in an allow-list. Nothing that was allowed
-- stops being allowed, no stored lexicon is rewritten, and a workspace
-- that never says the word renders exactly as before — `lexiconText`
-- falls back to the product's own translated string.
--
-- The lint that should have caught this now does: `lexicon_allow_list_test`
-- scans `lib/` for the keys the app RENDERS and requires each of them in
-- the allow-list, in `lexiconDefault` and in this function. The tests it
-- had walked the lists outwards, so two matching incomplete lists passed.
--
-- ## Harnessed before applying (rolled back)
--
--   allowed_before=33 allowed_after=34 lost=[] added=[legendUnavailable]
--   import_merge={"fr": {"legendFree": "Place libre",
--                        "legendUnavailable": "Place non disponible"}}
--   import_keeps_existing={"fr": {"legendFree": "Place libre",
--                                 "legendMine": "Ma place",
--                                 "legendUnavailable": "Place non disponible"}}
--   import_rejects_junk={"fr": {"legendUnavailable": "Place non disponible"}}
--   placeholders={} declared_empty=true

create or replace function public.lexicon_allowed_keys()
returns table(key text, placeholders text[])
language sql stable as $fn$
  select * from (values
    -- the plan legend
    ('legendFree','{}'::text[]),('legendReserved','{}'::text[]),
    ('legendOccupied','{}'::text[]),('legendMine','{}'::text[]),
    ('legendBlocked','{}'::text[]),('legendClosed','{}'::text[]),
    -- #1597: the simple profile's one word for blocked AND closed
    ('legendUnavailable','{}'::text[]),
    ('reserveClosedShort','{}'::text[]),
    -- what a space is made of
    ('spaceKindSeat','{}'::text[]),('spaceKindDesk','{}'::text[]),
    ('spaceKindOffice','{}'::text[]),('spaceKindLevel','{}'::text[]),
    ('levelDetail','{}'::text[]),('deskDetail','{}'::text[]),
    -- the shell's destinations
    ('tabPlan','{}'::text[]),('tabCalendar','{}'::text[]),
    ('tabEvents','{}'::text[]),('tabMoney','{}'::text[]),
    ('directoryTitle','{}'::text[]),('messagesTitle','{}'::text[]),
    -- reserving
    ('shellReserveButton','{}'::text[]),('planReserveButton','{}'::text[]),
    ('levelReserveButton','{}'::text[]),
    ('planMorningChip','{}'::text[]),('planAfternoonChip','{}'::text[]),
    ('planFromLabel','{}'::text[]),('planDurationLabel','{}'::text[]),
    ('planBookForLabel','{}'::text[]),('planCheckInTitle','{}'::text[]),
    ('planCheckInButton','{}'::text[]),
    ('reserveMonthView','{}'::text[]),('reserveDayView','{}'::text[]),
    ('reserveWeekView','{}'::text[]),('reserveFullDayChip','{}'::text[])
  ) as t(key, placeholders);
$fn$;

revoke execute on function public.lexicon_allowed_keys() from public, anon;
grant  execute on function public.lexicon_allowed_keys() to authenticated;

-- Asserted after, because replacing the body is not the same claim as
-- the key being reachable through the two functions that read it.
do $assert$
begin
  if not exists (select 1 from public.lexicon_allowed_keys()
                  where key = 'legendUnavailable' and placeholders = '{}'::text[]) then
    raise exception '0260: legendUnavailable did not register';
  end if;
  if (select count(*) from public.lexicon_allowed_keys()) <> 34 then
    raise exception '0260: the allow-list is % keys, expected 34',
      (select count(*) from public.lexicon_allowed_keys());
  end if;
  if public.imported_lexicon('{}'::jsonb,
       '{"fr":{"legendUnavailable":"Place non disponible"}}'::jsonb, 'merge')
     <> '{"fr":{"legendUnavailable":"Place non disponible"}}'::jsonb then
    raise exception '0260: a template still loses the term';
  end if;
end
$assert$;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(260);
