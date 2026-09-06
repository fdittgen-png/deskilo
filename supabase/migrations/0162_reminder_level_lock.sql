-- SPDX-License-Identifier: 0BSD
-- 0162 — #926: two reminders cannot take the same level.
--
-- Both places that write a reminder derived its level the same way:
--
--     select count(*) into v_count from public.invoice_reminders
--      where invoice_id = …;
--     v_level := v_count + 1;
--
-- with no lock and no constraint. The sweep runs every morning AND
-- whenever an owner or admin opens Finances; a manual send can land in
-- the same second. Two writers read the same count and both write the
-- same level, and the member is escalated twice with one letter.
--
-- The fix is the invoice ROW lock, taken before the count and held to
-- commit. It serialises exactly the writers of ONE invoice's reminders,
-- for microseconds, and makes read-count-write atomic — which is the
-- whole defect. It is not a workspace-wide advisory lock (see #925 on
-- why those are too wide) and it is not a unique (invoice_id, level)
-- constraint: the cap `least(v_count + 1, v_levels)` deliberately
-- REUSES the last level once the dunning ladder is exhausted ("extra
-- sends reuse the last level", 0144), so a repeated top level is a
-- designed outcome, not a duplicate. A constraint would have forbidden
-- it. The lock forbids only the race.
--
-- The nine duplicate rows in production are NOT this race. Seven were
-- written before 0144 by the 0066 function, which set no level at all,
-- so the column default (1) applied to every manual reminder; the last
-- pair is the cap-reuse above, working as designed. They are left as
-- they are: each row records a letter that was really sent, and the
-- event feed already told the member so. Rewriting them would make the
-- table disagree with what the person was told.
--
-- Both functions are patched at asserted anchors: a silent no-op would
-- leave the race exactly where it was.

do $patch$
declare
  v_def text;
  v_anchor text;
begin
  -- 1. The manual send (record_invoice_reminder, 0144).
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'record_invoice_reminder';
  if v_def is null then raise exception '0162: record_invoice_reminder not found'; end if;
  v_anchor := E'  select count(*) into v_count\n'
           || E'    from public.invoice_reminders r where r.invoice_id = p_invoice_id;\n';
  if position(v_anchor in v_def) = 0 then raise exception '0162: manual anchor missing'; end if;
  v_def := replace(v_def, v_anchor,
       E'  -- #926: the invoice row lock makes count -> level -> insert atomic\n'
    || E'  -- against a concurrent sweep or a second admin.\n'
    || E'  perform 1 from public.invoices where id = p_invoice_id for update;\n'
    || v_anchor);
  execute v_def;

  -- 2. The automatic sweep (sweep_payment_reminders, 0134).
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'sweep_payment_reminders';
  if v_def is null then raise exception '0162: sweep_payment_reminders not found'; end if;
  v_anchor := E'      select count(*), max(sent_at) into v_count, v_last\n'
           || E'        from public.invoice_reminders r where r.invoice_id = v_inv.id;\n';
  if position(v_anchor in v_def) = 0 then raise exception '0162: sweep anchor missing'; end if;
  v_def := replace(v_def, v_anchor,
       E'      -- #926: same lock as the manual path, per invoice.\n'
    || E'      perform 1 from public.invoices where id = v_inv.id for update;\n'
    || v_anchor);
  execute v_def;
end
$patch$;
