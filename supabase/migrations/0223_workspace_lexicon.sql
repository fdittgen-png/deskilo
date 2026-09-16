-- SPDX-License-Identifier: 0BSD
--
-- 0223 (#1277 S1) — a workspace may say its own words.
--
-- An association calls a seat «une place»; a space with private offices
-- calls a desk «un poste». Today the product's word is the only word,
-- because every string is an ARB key resolved at build time.
--
-- ## Why an allow-list and not a general mechanism
--
-- There are 3 046 ARB keys × 5 locales. Re-templating them around
-- abstract terms was rejected on cost, and wrapping `AppLocalizations`
-- would mean a delegating class with 3 046 members. Instead a small,
-- declared set of PRODUCT TERMINOLOGY may be overridden — the legend
-- labels, the space nouns, the shell destinations, the booking sheet's
-- own words — and everything else is untouched.
--
-- The allow-list is the security boundary as much as the design one: a
-- workspace cannot rewrite an error message, a legal mention, or a
-- confirmation, because those keys are not in it.
--
-- ## Only simple messages
--
-- Every one of the 33 keys below is a plain string in `app_en.arb` with
-- NO ICU `plural`/`select` and NO placeholders — verified against the
-- ARB before this was written, AND is actually rendered somewhere: a
-- term an owner may rename must change something on screen, or the
-- editor offers a word that does nothing. `levelReserveTitle` was cut
-- for exactly that reason — it exists in five locales and no widget
-- reads it. `placeholders` is still carried per key,
-- and the writer still compares the override's `{token}` set against it,
-- so the day an allow-listed key acquires a placeholder the rule already
-- exists and the writer refuses an override that drops it.
--
-- ## Two pairs share their English text, deliberately
--
--   shellReserveButton / planReserveButton  → both "Reserve"
--   planCheckInTitle   / planCheckInButton  → both "Check in"
--
-- They are different surfaces, so both are overridable; but an owner who
-- renames one and not the other gets a shell that says «Réserver» over a
-- booking sheet that does not. The editor (S3) must therefore show the
-- SURFACE, not only the default text. This is the same shape as the
-- duplicated "My badge" keys: perfectly parallel is not the same as
-- correct.
--
-- ## The guard order, stated because it is observable
--
-- `set_workspace_lexicon_term` checks the permission FIRST, so a caller
-- without `workspaceSettings` gets "only workspace settings managers may
-- change the wording" even for a workspace id that does not exist. The
-- `unknown workspace` branch is therefore reachable only by somebody who
-- may already write — which is the correct way round: an unauthorised
-- caller learns nothing about which workspaces exist.
--
-- ## Harnessed before applying (rolled back, twice)
--
--   allowed=34 set1=Libre set2=Libre/Place
--   unknown_key=[unknown wording key notAKey]
--   bad_locale=[unsupported locale zz]
--   bad_placeholder=[the wording must carry exactly the placeholders {}]
--   removal=[<removed> sibling=Place]
--   entities=20 group=wording policy=keyed_update keys=["lexicon"]
--
--   plain_may_manage=false plain=[refused] anonymous=[refused]
--   unknown_ws=[refused] owner_writes=[Libre]
--
-- The second run exists because the first proved every happy path and
-- not the gate. `plain_may_manage=false` is what makes its refusal mean
-- something, and `owner_writes` in the same run is what stops a function
-- that refuses EVERYONE from reading as a pass.

-- 1. The words themselves. `{}` — a workspace that has said nothing
--    renders exactly as before.
alter table public.workspaces
  add column if not exists lexicon jsonb not null default '{}'::jsonb;

comment on column public.workspaces.lexicon is
  'Per-locale overrides of allow-listed product terminology: {locale: {key: text}}. #1277';

-- 2. What may be overridden, and with which placeholders. The client
--    holds the same list and a lint pins the two together, so a key
--    cannot be offered in the editor that the server would refuse.
create or replace function public.lexicon_allowed_keys()
returns table(key text, placeholders text[])
language sql stable as $fn$
  select * from (values
    -- the plan legend
    ('legendFree','{}'::text[]),('legendReserved','{}'::text[]),
    ('legendOccupied','{}'::text[]),('legendMine','{}'::text[]),
    ('legendBlocked','{}'::text[]),('legendClosed','{}'::text[]),
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

-- 3. One key at a time, merged in the database.
--
-- Not a whole-blob writer: two administrators with the wording editor
-- open would each write the map as they had found it and the second
-- would silently revert the first — the shape #1089 removed from the
-- booking rules and #1294 avoided again for the billing rules.
--
-- `p_text null` REMOVES the override rather than storing the default.
-- Storing the default would freeze that word against every future
-- product rewording, which is the one thing a reset must not do.
create or replace function public.set_workspace_lexicon_term(
  p_workspace_id uuid,
  p_locale text,
  p_key text,
  p_text text
) returns jsonb
language plpgsql security definer set search_path = public as $fn$
declare v_lex jsonb; v_declared text[]; v_found text[];
begin
  if auth.uid() is null
     or not public.has_permission(p_workspace_id, 'workspaceSettings') then
    raise exception 'only workspace settings managers may change the wording';
  end if;
  if p_locale not in ('en','fr','de','es','it') then
    raise exception 'unsupported locale %', p_locale;
  end if;
  select placeholders into v_declared
    from public.lexicon_allowed_keys() where key = p_key;
  if v_declared is null then
    raise exception 'unknown wording key %', p_key;
  end if;

  if p_text is null then
    update public.workspaces
       set lexicon = case when lexicon->p_locale is null then lexicon
                          else jsonb_set(lexicon, array[p_locale],
                                         (lexicon->p_locale) - p_key) end
     where id = p_workspace_id
    returning lexicon into v_lex;
  else
    if length(p_text) > 120 then
      raise exception 'a word is at most 120 characters';
    end if;
    select coalesce(array_agg(distinct m[1] order by m[1]), '{}'::text[])
      into v_found from regexp_matches(p_text, '\{(\w+)\}', 'g') m;
    if v_found is distinct from v_declared then
      raise exception 'the wording must carry exactly the placeholders %', v_declared;
    end if;
    update public.workspaces
       set lexicon = jsonb_set(coalesce(lexicon, '{}'::jsonb), array[p_locale],
             coalesce(lexicon->p_locale, '{}'::jsonb)
               || jsonb_build_object(p_key, p_text), true)
     where id = p_workspace_id
    returning lexicon into v_lex;
  end if;

  if v_lex is null then raise exception 'unknown workspace'; end if;
  return v_lex;
end $fn$;

revoke execute on function public.lexicon_allowed_keys() from public, anon;
grant  execute on function public.lexicon_allowed_keys() to authenticated;
revoke execute on function public.set_workspace_lexicon_term(uuid, text, text, text)
  from public, anon;
grant  execute on function public.set_workspace_lexicon_term(uuid, text, text, text)
  to authenticated;

-- 4. The words travel with a template, keyed on (locale, key), in the
--    `wording` group beside the invitation templates. `keyed_update`
--    because a template that supplies French words must not delete the
--    German ones a space already wrote.
do $entity$
declare v_def text; v_anchor text;
begin
  select pg_get_functiondef(p.oid) into v_def from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'deployable_entities' limit 1;
  if v_def is null then raise exception '0223: deployable_entities not found'; end if;

  v_anchor := $a$    jsonb_build_object('key', 'features'$a$;
  if position(v_anchor in v_def) = 0 then
    raise exception '0223: the features anchor did not match';
  end if;

  v_def := replace(v_def, v_anchor,
    $a$    jsonb_build_object('key', 'lexicon', 'kind', 'configuration', 'requires', '[]'::jsonb,
      'merge_policy', 'keyed_update', 'group', 'wording',
      'workspace_keys', '["lexicon"]'::jsonb, 'tables', '[]'::jsonb),
    jsonb_build_object('key', 'features'$a$);
  execute v_def;

  -- Asserted after, because the anchor matching is not the same claim
  -- as the registry being right.
  if not exists (select 1 from jsonb_array_elements(public.deployable_entities()) e
                  where e->>'key' = 'lexicon'
                    and e->>'merge_policy' = 'keyed_update'
                    and e->>'group' = 'wording') then
    raise exception '0223: the lexicon entity did not register';
  end if;
  if (select count(*) from jsonb_array_elements(public.deployable_entities()) e
       where e ? 'key' and e ? 'kind' and e ? 'requires' and e ? 'workspace_keys'
         and e ? 'tables' and e ? 'merge_policy' and e ? 'group')
     <> (select count(*) from jsonb_array_elements(public.deployable_entities()) e) then
    raise exception '0223: an entity lost one of its seven keys';
  end if;
end
$entity$;
