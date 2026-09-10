-- SPDX-License-Identifier: 0BSD
-- 0193 — #1081: two members joining at the same moment, one gets no number.
--
-- `next_document_number` seeded the sequence row and then locked it:
--
--   insert into public.number_sequences (...) on conflict ... do nothing;
--   select * into v_seq from public.number_sequences ... for update;
--
-- `ON CONFLICT DO NOTHING` neither waits for nor locks a concurrent
-- inserter's UNCOMMITTED row. Two transactions arriving together: one
-- inserts, the other's insert is a silent no-op, and its `select ... for
-- update` then finds nothing — because the winner has not committed and
-- the loser's snapshot cannot see the row. `v_seq` stays all-NULL and
-- the function returns NULL.
--
-- Two people redeeming an invite into the same pre-0165 workspace at the
-- same moment both reach `join_workspace`'s
-- `member_number := next_document_number(ws, 'member')`, and the loser
-- fails the NOT NULL with an error that says nothing about why. It is
-- rare, unreproducible on demand, and lands on a first-run path — the
-- combination that lets a bug survive a year and get blamed on the
-- network. The same shape reaches every document number, not only
-- member numbers, on any workspace that has not yet adopted a sequence.
--
-- `DO UPDATE` is the fix rather than a retry loop: it takes the row lock
-- in BOTH branches and returns the row in both, which is exactly what
-- the separate `for update` was there for. The assignment is a
-- deliberate no-op — writing the column back to itself — because the
-- point is the lock and the RETURNING, not the data.
do $patch$
declare v_def text; v_old text;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'next_document_number';
  if v_def is null then raise exception '0193: next_document_number not found'; end if;

  v_old := E'  on conflict (workspace_id, journal) do nothing;\n  select * into v_seq from public.number_sequences\n   where workspace_id = p_workspace_id and journal = p_journal for update;\n';
  if position(v_old in v_def) = 0 then
    raise exception '0193: next_document_number seed/lock anchor missing';
  end if;

  v_def := replace(v_def, v_old,
       E'  on conflict (workspace_id, journal)\n'
    || E'    do update set journal = public.number_sequences.journal\n'
    || E'  returning * into v_seq;\n');

  execute v_def;
end
$patch$;
