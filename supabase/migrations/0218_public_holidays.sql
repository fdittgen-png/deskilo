-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- 0218 (#1274) — public holidays as closure days, generated and previewed.
--
-- The association's entitlement table is `weekdays(month) − public
-- holidays`, and the workspace holds zero closure-day rows, so the table
-- is not yet true. The Availability screen adds them one date-picker tap
-- at a time; eleven French holidays a year, three of which move with
-- Easter.
--
-- The generator lives HERE and not in Dart, because `apply_workspace_template`
-- runs in SQL and cannot call a Dart generator (#1282). The client renders
-- what this returns and holds only the localized names, keyed by `key`.
-- ADR 0020: the database enforces the rules.

-- The country rules are DATA — a new country is another branch with its
-- own list, never a new function. Easter by the anonymous Gregorian
-- computus; everything else is a fixed day or an offset from it.
create or replace function public.public_holidays(p_country text, p_year int)
returns table("day" date, "key" text)
language plpgsql immutable set search_path = public as $fn$
declare
  a int; b int; c int; d int; e int; f int; g int; h int;
  i int; k int; l int; m int; mo int; da int; v_easter date;
begin
  a := p_year % 19; b := p_year / 100; c := p_year % 100;
  d := b / 4; e := b % 4; f := (b + 8) / 25; g := (b - f + 1) / 3;
  h := (19 * a + b - d - g + 15) % 30; i := c / 4; k := c % 4;
  l := (32 + 2 * e + 2 * i - h - k) % 7;
  m := (a + 11 * h + 22 * l) / 451;
  mo := (h + l - 7 * m + 114) / 31;
  da := ((h + l - 7 * m + 114) % 31) + 1;
  v_easter := make_date(p_year, mo, da);

  if upper(p_country) = 'FR' then
    -- Alsace-Moselle's Good Friday and 26 December are NOT here. They
    -- are a regional exception to a national list, and this function
    -- takes a country. Named rather than silently wrong (#1274).
    return query select d2.d, d2.k from (values
      (make_date(p_year, 1, 1), 'newYear'), (v_easter + 1, 'easterMonday'),
      (make_date(p_year, 5, 1), 'labourDay'), (make_date(p_year, 5, 8), 'victory1945'),
      (v_easter + 39, 'ascension'), (v_easter + 50, 'whitMonday'),
      (make_date(p_year, 7, 14), 'nationalDay'), (make_date(p_year, 8, 15), 'assumption'),
      (make_date(p_year, 11, 1), 'allSaints'), (make_date(p_year, 11, 11), 'armistice'),
      (make_date(p_year, 12, 25), 'christmas')
    ) as d2(d, k) order by d2.d;
  elsif upper(p_country) = 'DE' then
    -- The federal days only; the Länder differ, and that is out of scope
    -- for the same reason as Alsace-Moselle.
    return query select d2.d, d2.k from (values
      (make_date(p_year, 1, 1), 'newYear'), (v_easter - 2, 'goodFriday'),
      (v_easter + 1, 'easterMonday'), (make_date(p_year, 5, 1), 'labourDay'),
      (v_easter + 39, 'ascension'), (v_easter + 50, 'whitMonday'),
      (make_date(p_year, 10, 3), 'germanUnity'), (make_date(p_year, 12, 25), 'christmas'),
      (make_date(p_year, 12, 26), 'boxingDay')
    ) as d2(d, k) order by d2.d;
  else
    raise exception 'no public-holiday rules for country %', p_country
      using errcode = '22023';
  end if;
end
$fn$;

revoke execute on function public.public_holidays(text, int) from public, anon;
grant execute on function public.public_holidays(text, int) to authenticated;

-- One implementation for preview and apply, so the list an owner
-- confirms is the list that gets written (#1276's rule).
create or replace function public.generate_closure_days(
  p_workspace_id uuid,
  p_country text,
  p_year int,
  p_apply boolean default false
) returns jsonb
language plpgsql security definer set search_path = public as $fn$
declare
  v_locked text[]; v_created int := 0; v_days jsonb;
begin
  -- Exactly the rule `closure_days_write` already carries. Never wider.
  if not public.is_owner_of(p_workspace_id) then
    raise exception 'only an owner may generate closure days'
      using errcode = '42501';
  end if;

  -- A closure day added to an invoiced month changes open_days, and so
  -- included_half_days, and so that member's overage and their bill.
  -- Those months are SKIPPED and NAMED: generating holidays must never
  -- silently change financial history (#1274). Voided invoices count —
  -- they were issued.
  select coalesce(array_agg(distinct i.period), '{}')
    into v_locked
    from public.invoices i
   where i.workspace_id = p_workspace_id
     and i.period in (select distinct to_char(h.day, 'YYYY-MM')
                        from public.public_holidays(p_country, p_year) h);

  select coalesce(jsonb_agg(jsonb_build_object(
           'day', h.day, 'key', h.key,
           'locked', to_char(h.day, 'YYYY-MM') = any (v_locked),
           'present', exists (select 1 from public.closure_days c
                               where c.workspace_id = p_workspace_id
                                 and c.day = h.day)
         ) order by h.day), '[]'::jsonb)
    into v_days
    from public.public_holidays(p_country, p_year) h;

  if p_apply then
    insert into public.closure_days (workspace_id, day, reason)
    select p_workspace_id, h.day, h.key
      from public.public_holidays(p_country, p_year) h
     where not (to_char(h.day, 'YYYY-MM') = any (v_locked))
       and not exists (select 1 from public.closure_days c
                        where c.workspace_id = p_workspace_id
                          and c.day = h.day);
    get diagnostics v_created = row_count;
  end if;

  return jsonb_build_object('days', v_days,
                            'locked_months', to_jsonb(v_locked),
                            'created', v_created);
end
$fn$;

revoke execute on function public.generate_closure_days(uuid, text, int, boolean)
  from public, anon;
grant execute on function public.generate_closure_days(uuid, text, int, boolean)
  to authenticated;
