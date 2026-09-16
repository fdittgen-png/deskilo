-- SPDX-License-Identifier: 0BSD
--
-- #1405 — member_statement initialized its reservation cache from
-- itself, so every accessory, whole-space and hour charge read zero.
--
-- 0208 was a good idea executed with one regex too many. It inserted a
-- single fetch of the month's reservations into `v_month`, then
-- rewrote every per-aggregation scan to read `unnest(v_month)` instead
-- of `public.reservations` — ten of them, asserted. But the rewrite ran
-- over the WHOLE new body with the `g` flag, and the fetch it had just
-- inserted matched the same pattern. So the initialising statement was
-- rewritten too:
--
--   select coalesce(array_agg(r), '{}') into v_month
--     from unnest(v_month) r        -- <- itself, and it is empty
--    where true and r.starts_at >= v_period_start;
--
-- 0208's own guard did not catch it: it counted the surviving literal
-- `from public.reservations r` scans and found exactly 1 — the
-- `v_used` half-day count, which sits in a `cross join lateral` and so
-- never matched the rewrite pattern. One survivor was the expected
-- number, so the count passed while the wrong statement survived.
--
-- That is why used_half_days kept working (literal scan) and every
-- supplement silently went to zero (array scan). The two numbers come
-- from different reads of the same reservations, and only one of them
-- was still reading anything.
--
-- Proven on this project before installing, in a rolled-back
-- transaction: for the fixture member, with one 500-cent accessory
-- attached to a seat they booked five times in the month —
--
--   BEFORE  used_half_days=18  accessory_supplement_cents=0
--   AFTER   used_half_days=18  accessory_supplement_cents=2500
--
-- used_half_days is the control: unchanged, because this patch does not
-- touch the literal scan that produces it.
do $$
declare
  v_def text;
  v_new text;
  v_anchor text;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'member_statement';
  if v_def is null then
    raise exception '0225: member_statement not found';
  end if;

  -- Already repaired? The initialising scan reads the table again.
  if position(E'into v_month\n    from public.reservations r' in v_def) > 0 then
    raise notice '0225: already applied';
    return;
  end if;

  -- The anchor is a COMPLETE statement ending in a semicolon, not an
  -- expression: there is no closing parenthesis for it to swallow.
  v_anchor := E'  select coalesce(array_agg(r), ''{}'') into v_month\n'
           || E'    from unnest(v_month) r\n'
           || E'      where true\n'
           || E'        and r.starts_at >= v_period_start;';
  if position(v_anchor in v_def) = 0 then
    raise exception '0225: anchor missing — the live body is not the one measured';
  end if;

  -- Exactly 0208's intended text, restored.
  v_new := replace(v_def, v_anchor,
    E'  select coalesce(array_agg(r), ''{}'') into v_month\n'
    || E'    from public.reservations r\n'
    || E'   where r.member_id = p_member_id\n'
    || E'     and r.status in (''reserved'',''checked_in'',''completed'')\n'
    || E'     and r.starts_at >= v_period_start and r.starts_at < v_period_end\n'
    || E'     -- #624: outside-only bookings may be free or exempt\n'
    || E'     and public.reservation_counts_for_usage(r, v_rules, v_tz);');

  if v_new = v_def then
    raise exception '0225: the replacement changed nothing';
  end if;

  -- After the repair: TWO literal reservation scans — the initialising
  -- fetch restored here, and the v_used half-day count 0208 never
  -- rewrote (it sits in a cross join lateral and never matched).
  if (select count(*) from regexp_matches(v_new, 'from public\.reservations r', 'g')) <> 2 then
    raise exception '0225: expected exactly 2 literal reservation scans after the repair, found %',
      (select count(*) from regexp_matches(v_new, 'from public\.reservations r', 'g'));
  end if;

  -- And NINE array scans, not the ten 0208 asserted. That difference is
  -- the whole bug: 0208 rewrote ten statements, but one of them was the
  -- fetch it had just inserted to populate the array. Nine are real
  -- aggregations reading v_month; the tenth was the initialisation,
  -- and it is a literal scan again as of this migration.
  --
  -- Measured, not assumed — the rolled-back harness asserted 10 first
  -- and the database said 9.
  if (select count(*) from regexp_matches(v_new, 'from unnest\(v_month\) r', 'g')) <> 9 then
    raise exception '0225: the nine aggregation scans must survive untouched, found %',
      (select count(*) from regexp_matches(v_new, 'from unnest\(v_month\) r', 'g'));
  end if;

  execute v_new;
end
$$;
