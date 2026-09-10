-- SPDX-License-Identifier: 0BSD
-- 0192 — #1092: create_workspace regains the two rules 0185 dropped.
--
-- 0185 re-created create_workspace FROM SCRATCH to add p_environment and
-- p_with_twin. `CREATE OR REPLACE` replaces the whole body, so every
-- anchored patch applied to it since 0001 was silently discarded:
--
--   0165  the founder's member_number
--   0166  "an owner must have an e-mail address"
--
-- Both confirmed absent from the live function, not merely from the
-- migration text. The e-mail rule still holds in activate_co_owner,
-- patched by the same 0166 block, so it applied to a co-owner and not to
-- the person who creates the space — which is the same as not holding.
--
-- The member_number loss was NOT in the issue and is the more concrete
-- of the two: one live owner already has none. It is restored for BOTH
-- inserts, because 0185 added a twin workspace and its owner is a second
-- member row that 0165's single-insert patch never knew about.
--
-- Anchors are asserted and each addition is idempotent, so re-running is
-- a no-op rather than a duplicate.

do $patch$
declare v_def text; v_old text;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'create_workspace';
  if v_def is null then raise exception '0192: create_workspace not found'; end if;

  -- ── 0166: an owner must have an e-mail address ──────────────────
  if position('user_has_email' in v_def) = 0 then
    v_old := E'  if auth.uid() is null then raise exception ''not authenticated''; end if;\n';
    if position(v_old in v_def) = 0 then
      raise exception '0192: create_workspace auth anchor missing';
    end if;
    v_def := replace(v_def, v_old, v_old ||
      E'  if not public.user_has_email(auth.uid()) then raise exception ''an owner must have an e-mail address''; end if;\n');
  end if;

  -- ── 0165: the founder carries a member number ───────────────────
  if position('next_document_number' in v_def) = 0 then
    v_old := E'  insert into public.members (workspace_id, user_id, is_admin, is_owner)\n  values (ws_id, auth.uid(), true, true);\n';
    if position(v_old in v_def) = 0 then
      raise exception '0192: create_workspace owner-insert anchor missing';
    end if;
    v_def := replace(v_def, v_old, v_old ||
      E'  update public.members set member_number = public.next_document_number(ws_id, ''member'')\n    where workspace_id = ws_id and user_id = auth.uid();\n');

    -- The twin's owner is a second row (0185). 0165 predates it.
    v_old := E'    insert into public.members (workspace_id, user_id, is_admin, is_owner)\n    values (twin_id, auth.uid(), true, true);\n';
    if position(v_old in v_def) = 0 then
      raise exception '0192: create_workspace twin-insert anchor missing';
    end if;
    v_def := replace(v_def, v_old, v_old ||
      E'    update public.members set member_number = public.next_document_number(twin_id, ''member'')\n      where workspace_id = twin_id and user_id = auth.uid();\n');
  end if;

  execute v_def;
end
$patch$;

-- ── the rows already created without a number ──────────────────────
-- Every member whose workspace adopted a sequence but who never got a
-- number. next_document_number is idempotent per workspace and hands out
-- the next free value, so this is safe to re-run.
do $backfill$
declare r record;
begin
  for r in
    select id, workspace_id from public.members
     where coalesce(member_number, '') = ''
     order by joined_at
  loop
    update public.members
       set member_number = public.next_document_number(r.workspace_id, 'member')
     where id = r.id;
  end loop;
end
$backfill$;
