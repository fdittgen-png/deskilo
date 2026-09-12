-- SPDX-License-Identifier: 0BSD
-- 0208 — #1154: member_statement reads the month's reservations ONCE.
--
-- The statement is ten aggregations over the same slice — used
-- half-days, the hours-mode variant, accessory / level / office / desk
-- supplements in both modes — and each one re-scanned
-- public.reservations with the same five predicates, the last of them
-- `reservation_counts_for_usage(r, rules, tz)`: plpgsql, so not
-- inlinable, evaluated per row per scan. Ten index scans and ten
-- predicate passes for one number per member per month, and the
-- invoicing run calls this for every member.
--
-- The slice is fetched once into an array; every aggregation reads
-- `unnest(v_month)` and keeps ONLY its own extra filter (the space
-- column that must be set, the accessory since-date). The arithmetic
-- is untouched — this file rewrites the FROM/WHERE of each scan by
-- regular expression over the live definition, asserts that exactly
-- ten were rewritten, and proves the result on this project before
-- installing it: for every member and every month they ever booked in,
-- the old and the new function return the same jsonb, as the
-- workspace's owner.
do $patch$
declare
  v_def text;
  v_new text;
  v_hits int;
  v_anchor text;
  m record;
  p text;
  v_old jsonb;
  v_next jsonb;
  v_checked int := 0;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'member_statement';
  if v_def is null then raise exception '0208: member_statement not found'; end if;
  if position('unnest(v_month)' in v_def) > 0 then
    raise notice '0208: already applied'; return;
  end if;

  -- 1. the declaration
  v_anchor := E'  v_half_minutes numeric;\nbegin';
  if position(v_anchor in v_def) = 0 then raise exception '0208: declare anchor missing'; end if;
  v_new := replace(v_def, v_anchor,
    E'  v_half_minutes numeric;\n  -- #1154 — the month''s counting reservations, fetched once.\n  v_month public.reservations[];\nbegin');

  -- 2. the one fetch, right before the first aggregation
  v_anchor := E'  select count(distinct (date_trunc(''day'', r.starts_at at time zone v_tz)::date, s.slot))\n  into v_used';
  if position(v_anchor in v_new) = 0 then raise exception '0208: first-scan anchor missing'; end if;
  v_new := replace(v_new, v_anchor,
    E'  select coalesce(array_agg(r), ''{}'') into v_month\n'
    || E'    from public.reservations r\n'
    || E'   where r.member_id = p_member_id\n'
    || E'     and r.status in (''reserved'',''checked_in'',''completed'')\n'
    || E'     and r.starts_at >= v_period_start and r.starts_at < v_period_end\n'
    || E'     -- #624: outside-only bookings may be free or exempt\n'
    || E'     and public.reservation_counts_for_usage(r, v_rules, v_tz);\n\n'
    || v_anchor);

  -- 3. every scan reads the array; only its own extra filter survives
  select count(*) into v_hits from regexp_matches(v_new,
    'from public\.reservations r\s+where r\.member_id = p_member_id\s+(and r\.(?:seat|level|office|desk)_id is not null\s+)?and r\.status in \(''reserved'',''checked_in'',''completed''\)\s+and r\.starts_at >= (v_period_start|greatest\(v_period_start, v_supp_since\))\s+and r\.starts_at < v_period_end\s+-- #624[^\n]*\n\s+and public\.reservation_counts_for_usage\(r, v_rules, v_tz\)',
    'g');
  if v_hits <> 10 then
    raise exception '0208: expected 10 reservation scans to rewrite, found %', v_hits;
  end if;
  v_new := regexp_replace(v_new,
    'from public\.reservations r\s+where r\.member_id = p_member_id\s+(and r\.(?:seat|level|office|desk)_id is not null\s+)?and r\.status in \(''reserved'',''checked_in'',''completed''\)\s+and r\.starts_at >= (v_period_start|greatest\(v_period_start, v_supp_since\))\s+and r\.starts_at < v_period_end\s+-- #624[^\n]*\n\s+and public\.reservation_counts_for_usage\(r, v_rules, v_tz\)',
    E'from unnest(v_month) r\n      where true\n        \\1and r.starts_at >= \\2',
    'g');
  -- The one fetch above is the only public.reservations read left.
  if (select count(*) from regexp_matches(v_new, 'from public\.reservations r', 'g')) <> 1 then
    raise exception '0208: a reservation scan survived the rewrite';
  end if;

  -- 4. install beside the original, prove equality, then replace
  execute replace(v_new, 'FUNCTION public.member_statement(', 'FUNCTION public.member_statement_0208(');
  for m in
    select mem.id, mem.workspace_id, own.user_id as owner_user_id
      from public.members mem
      join lateral (
        select o.user_id from public.members o
         where o.workspace_id = mem.workspace_id and o.is_owner
         order by o.joined_at nulls last, o.id limit 1
      ) own on true
  loop
    perform set_config('request.jwt.claims',
      json_build_object('sub', m.owner_user_id, 'role', 'authenticated')::text, true);
    for p in
      select distinct to_char(r.starts_at at time zone w.timezone, 'YYYY-MM')
        from public.reservations r join public.workspaces w on w.id = m.workspace_id
       where r.member_id = m.id
      union select to_char(now(), 'YYYY-MM')
    loop
      v_old := public.member_statement(m.id, p);
      v_next := public.member_statement_0208(m.id, p);
      if v_old is distinct from v_next then
        raise exception '0208: member % period % differs: old % new %', m.id, p, v_old, v_next;
      end if;
      v_checked := v_checked + 1;
    end loop;
  end loop;
  perform set_config('request.jwt.claims', '', true);
  drop function public.member_statement_0208(uuid, text);
  raise notice '0208: % member-months identical', v_checked;
  execute v_new;
end
$patch$;
