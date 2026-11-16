-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (events_status_check gains one status; respond_to_event is patched at one
--  asserted anchor to lock the event it decides; one member action is new)
--
-- #4140 (server) -- a member takes back a payment declaration that still
-- waits for the business: the declared payment's event (record_payment,
-- 0797) is ended as `withdrawn`, which closes its claim and frees the
-- invoices it names (open_claim_invoices reads only a pending declaration),
-- and the business reads in its events that it was withdrawn and by whom
-- (payload `withdrawn_by`, the member who did it). A withdrawal is the
-- declarer's own act: the member the declaration is for, or the member who
-- recorded it (an administrator who declared for someone takes their own
-- mistake back). Whoever else wants a declaration ended refuses it through
-- the decision, under the business's validation policy. A declaration
-- already confirmed, refused, expired or withdrawn is refused with its own
-- code (DKC13); anyone else's, an unknown one, or an event that is not a
-- payment gets the same answer as for a payment (DKC08).
--
-- The business deciding while the member withdraws ends in exactly one of
-- the two: both lock the event before they read its status, so whichever
-- comes second meets a decided event (respond_to_event: DKD01; the
-- withdrawal: DKC13). respond_to_event read the event without a lock; it now
-- takes the row's lock first (scripts/payment_claim_race.sh, case i: the
-- decision waits for a withdrawal held open). The withdrawal checks the
-- caller's right before it locks anything.

-- ── the status ───────────────────────────────────────────────────────────
do $constraint$
declare
  v_def text;
begin
  select pg_get_constraintdef(oid) into v_def from pg_constraint
   where conrelid = 'public.events'::regclass and conname = 'events_status_check';
  if v_def is null or position('CHECK (' in v_def) <> 1 then
    raise exception 'events_status_check anchor missing' using errcode = 'P0001';
  end if;
  -- Added NOT VALID, then validated: the table is not held under the full
  -- lock while every event is checked.
  if position('withdrawn' in v_def) = 0 then
    alter table public.events drop constraint events_status_check;
    execute 'alter table public.events add constraint events_status_check '
      || replace(v_def, 'CHECK (', 'CHECK (status = ''withdrawn''::text OR ') || ' NOT VALID';
    alter table public.events validate constraint events_status_check;
  end if;
end;
$constraint$;

-- ── the decision locks the event it decides ──────────────────────────────
do $patch$
declare
  v_def text := pg_get_functiondef('public.respond_to_event(uuid, boolean)'::regprocedure);
  v_old constant text := $r$select e.* into v_event from public.events e where e.id = p_event_id;$r$;
  v_new constant text := $r$select e.* into v_event from public.events e where e.id = p_event_id for update;$r$;
begin
  if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then
    raise exception 'respond_to_event: the anchor of its event read is not there exactly once' using errcode = 'P0001';
  end if;
  execute replace(v_def, v_old, v_new);
end;
$patch$;

-- ── the member takes the declaration back ────────────────────────────────
-- [p_event]: the declared payment's event. Ends it as withdrawn while it
-- still waits for the business; its claim then frees the invoices it names.
create or replace function public.withdraw_payment_declaration(p_event uuid)
returns void language plpgsql security definer set search_path = public as $fn$
declare
  v_event public.events;
  v_actor public.members;
begin
  -- The right first, without a lock: nobody waits on, or holds, a row they
  -- have no right to. Its business and member never change.
  select * into v_event from public.events where id = p_event and type = 'payment';
  select * into v_actor from public.members
   where workspace_id = v_event.workspace_id and user_id = auth.uid() and status = 'active';
  if v_event.id is null or v_actor.id is null
     or v_actor.id not in (v_event.subject_member_id, v_event.actor_member_id) then
    raise exception 'not one of your payments' using errcode = 'DKC08';
  end if;
  -- Then the lock, as the decision takes it, and the event read again under
  -- it: whichever comes second meets a decided event.
  select * into v_event from public.events where id = p_event for update;
  if v_event.status <> 'pending' then
    raise exception 'this declaration was already decided' using errcode = 'DKC13';
  end if;
  update public.events
     set status = 'withdrawn',
         decided_at = now(),
         payload = payload || jsonb_build_object('withdrawn_by', v_actor.id)
   where id = p_event;
end;
$fn$;
revoke execute on function public.withdraw_payment_declaration(uuid) from public, anon;
grant execute on function public.withdraw_payment_declaration(uuid) to authenticated;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(802);
