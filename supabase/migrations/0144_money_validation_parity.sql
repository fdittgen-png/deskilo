-- SPDX-License-Identifier: 0BSD
-- 0144 — #816: the validation framework and the role gates on the money
-- flows, made to keep what the guide promises: the server enforces the
-- SAME matrix the UI shows, nobody validates their own event, and a
-- request that expires grants nothing silently.
--
-- What the audit found (2026-09-01) and what this migration does:
--
--  1. sweep_pending_events EXPIRED a pending invoice_payment without the
--     compensation the reject branch runs — the match row stayed pending
--     forever, the payment stayed reserved, the invoice fell out of
--     dunning. → release_invoice_payment(), ONE helper, called by the
--     reject branch (patched in place) AND by sweep_pending_events v2.
--  2. settle_invoices wrote its own invoice_payment event already
--     'applied' — self-validated, no quorum. → v2 honours the
--     invoice_payment policy; a reject voids the settlement and releases
--     its sources.
--  3. A settled source could still be voided, replaced or matched, and
--     voiding a settlement stranded its sources. → guards in
--     void_invoice / create_invoice / match_invoice; voiding a
--     settlement releases its sources (the immutability trigger learns
--     that one more transition).
--  4. set_role_permissions rejected the client's own payload (the two
--     negotiation permissions were missing from its catalog).
--  5. void_invoice, record_invoice_reminder, settle_credit_invoice ran the
--     pre-#513 gate (is_owner_of or the adminInvoicing flag);
--     request_invoice_writeoff checked no permission at all;
--     create_invoice, match_invoice and settle_invoices demanded
--     (is_admin or is_owner) BEFORE consulting the matrix. → every one of
--     them now asks has_permission(ws, 'issueInvoices') and nothing else.
--  6. A manual reminder wrote a row and no event — the member never
--     learned of it; its level was always 1. → v2 computes the level and
--     emits the same invoice_reminder event the sweep does.
--  7. invoice_matches, invoice_match_payments, invoice_reminders and
--     invoice_transmissions never moved to may_view_member_finances
--     (0131). → they do now; a member also sees their own transmissions.
--  8. Scoped validators ('listed' / 'members', 0135) could not SEE the
--     events they must decide. → events_select widened.
--  9. manageValidation and workspaceSettings were decorative. → the
--     validation_policies write policy asks manageValidation; dunning
--     and billing rules go through RPCs gated on workspaceSettings.
--
-- Every RPC below is re-created in full where its body is short, and
-- patched IN PLACE (pg_get_functiondef + replace, anchors asserted)
-- where it is long and owned by a later migration — 0131/0135/0139/0143
-- set the idiom.

-- ---------------------------------------------------------------- 4. the catalog
create or replace function public.set_role_permissions(
  p_workspace_id uuid,
  p_role text,
  p_permissions text[]
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_catalog text[] := array[
    'manageRoles','manageMembers','manageValidation','workspaceSettings',
    'issueInvoices','viewFinances','manageDocuments','manageServices',
    'approveExpenses','viewNegotiations','manageNegotiations'];
  v_perm text;
begin
  if not public.has_permission(p_workspace_id, 'manageRoles') then
    raise exception 'only role managers may edit permissions';
  end if;
  if p_role not in ('co_owner','admin','member') then
    raise exception 'unknown role';
  end if;
  foreach v_perm in array coalesce(p_permissions, '{}') loop
    if not (v_perm = any(v_catalog)) then
      raise exception 'unknown permission %', v_perm;
    end if;
  end loop;
  update public.workspaces
    set role_permissions = jsonb_set(
      coalesce(role_permissions, '{}'::jsonb),
      array[p_role],
      coalesce(to_jsonb(p_permissions), '[]'::jsonb))
    where id = p_workspace_id;
end;
$$;
revoke execute on function public.set_role_permissions(uuid, text, text[])
  from public, anon;
grant execute on function public.set_role_permissions(uuid, text, text[])
  to authenticated;

-- ---------------------------------------------------------------- 5. ONE issuer gate
-- The caller as an ACTIVE member holding issueInvoices — owner, co-owner,
-- admin or member, exactly as the matrix says. Raises the message every
-- invoicing RPC has always raised, so the client's mapping stays valid.
create or replace function public.issuing_member(p_workspace_id uuid)
returns public.members language plpgsql stable security definer
set search_path = public as $$
declare
  v_actor public.members;
begin
  select * into v_actor from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid()
      and status = 'active';
  if v_actor.id is null then raise exception 'not a member'; end if;
  if not public.has_permission(p_workspace_id, 'issueInvoices') then
    raise exception 'admins may not issue invoices here';
  end if;
  return v_actor;
end;
$$;
revoke execute on function public.issuing_member(uuid) from public, anon;

-- ---------------------------------------------------------------- 3. immutability v3
-- Two more transitions, both for the settlement lifecycle: a source's
-- pointer may be CLEARED (the settlement was voided or rejected), and
-- voiding may stamp a settlement whose sources are released in the same
-- statement batch.
create or replace function public.invoices_immutable()
returns trigger language plpgsql as $$
begin
  if tg_op = 'UPDATE'
     and old.voided_at is null
     and new.voided_at is not null
     and (to_jsonb(old) - 'voided_at' - 'voided_by_name')
       = (to_jsonb(new) - 'voided_at' - 'voided_by_name') then
    return new;
  end if;
  -- #804 — the settlement back-pointer, set once…
  if tg_op = 'UPDATE'
     and old.settled_by_invoice_id is null
     and new.settled_by_invoice_id is not null
     and (to_jsonb(old) - 'settled_by_invoice_id')
       = (to_jsonb(new) - 'settled_by_invoice_id') then
    return new;
  end if;
  -- #816 — …and cleared once, when the settlement did not stand.
  if tg_op = 'UPDATE'
     and old.settled_by_invoice_id is not null
     and new.settled_by_invoice_id is null
     and (to_jsonb(old) - 'settled_by_invoice_id')
       = (to_jsonb(new) - 'settled_by_invoice_id') then
    return new;
  end if;
  raise exception 'invoices are immutable';
end;
$$;

-- ---------------------------------------------------------------- 1. the release
-- Everything a NOT-STANDING invoice_payment leaves behind, undone: the
-- credit note it minted, the match row, the payment reservations of an
-- additional payment (#506) — and, for a settlement, the settlement
-- document voided and its sources released. The reject branch and the
-- expiry sweep both call this; before #816 only the reject branch knew.
create or replace function public.release_invoice_payment(p_event_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_event public.events;
  v_settlement uuid;
begin
  select * into v_event from public.events where id = p_event_id;
  if v_event.id is null then return; end if;
  delete from public.ledger_entries
    where id = (select credit_ledger_id from public.invoice_matches
                 where event_id = p_event_id);
  delete from public.invoice_matches where event_id = p_event_id;
  delete from public.ledger_entries
    where id in (select credit_ledger_id
                   from public.invoice_match_payments
                  where event_id = p_event_id
                    and credit_ledger_id is not null);
  delete from public.invoice_match_payments where event_id = p_event_id;
  if coalesce(v_event.payload->>'kind', '') = 'settlement' then
    v_settlement := (v_event.payload->>'invoice_id')::uuid;
    update public.invoices set settled_by_invoice_id = null
      where settled_by_invoice_id = v_settlement;
    update public.invoices
       set voided_at = now(), voided_by_name = 'validation'
     where id = v_settlement and voided_at is null;
  end if;
end;
$$;
revoke execute on function public.release_invoice_payment(uuid) from public, anon;

-- respond_to_event: the reject branch delegates to the helper (in place —
-- 0135 patched this body last; the block below is the 0101 text AS THE
-- HOSTED PROJECT HOLDS IT: without the two #506 comment lines the file
-- carries — pg_get_functiondef returned the body comment-free there, and
-- the live harness caught the mismatch on the first run).
do $patch$
declare
  v_def text;
  v_old text := $o$    if v_event.type = 'invoice_payment' then
      delete from public.ledger_entries
        where id = (select credit_ledger_id from public.invoice_matches
                     where event_id = v_event.id);
      delete from public.invoice_matches where event_id = v_event.id;
      delete from public.ledger_entries
        where id in (select credit_ledger_id
                       from public.invoice_match_payments
                      where event_id = v_event.id
                        and credit_ledger_id is not null);
      delete from public.invoice_match_payments
        where event_id = v_event.id;
    end if;$o$;
  v_new text := $n$    if v_event.type = 'invoice_payment' then
      -- #816 — ONE release, shared with the expiry sweep.
      perform public.release_invoice_payment(v_event.id);
    end if;$n$;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'respond_to_event';
  if v_def is null then raise exception 'respond_to_event missing'; end if;
  if position('release_invoice_payment' in v_def) > 0 then
    raise notice 'respond_to_event already releases through the helper';
    return;
  end if;
  if position(v_old in v_def) = 0 then
    raise exception '0144: respond_to_event reject block not found — body drifted';
  end if;
  execute replace(v_def, v_old, v_new);
end $patch$;

-- sweep_pending_events v2: the money events it expires are released
-- exactly as a reject releases them.
create or replace function public.sweep_pending_events(p_workspace_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
begin
  if not public.is_member_of(p_workspace_id) then
    raise exception 'not a member';
  end if;
  -- non-destructive (creations/modifications): auto-confirm
  insert into public.event_decisions (event_id, member_id, decision, decided_by_system)
  select e.id, null, 'accept', true from public.events e
    where e.workspace_id = p_workspace_id and e.status = 'pending'
      and e.action in ('created','modified')
      and e.created_at < now() - interval '7 days';
  update public.events
    set status = 'confirmed', decided_at = now()
    where workspace_id = p_workspace_id and status = 'pending'
      and action in ('created','modified')
      and created_at < now() - interval '7 days';
  -- destructive (cancellations) or debits: auto-expire and undo tentative
  update public.reservations r set status = 'cancelled'
    from public.events e
    where e.workspace_id = p_workspace_id and e.status = 'pending'
      and e.action not in ('created','modified')
      and e.created_at < now() - interval '7 days'
      and r.id = e.reservation_id and r.status in ('reserved','checked_in');
  -- #816 — an expired invoice_payment releases what it held, like a reject.
  for v_id in
    select e.id from public.events e
     where e.workspace_id = p_workspace_id and e.status = 'pending'
       and e.type = 'invoice_payment'
       and e.action not in ('created','modified')
       and e.created_at < now() - interval '7 days'
  loop
    perform public.release_invoice_payment(v_id);
  end loop;
  insert into public.event_decisions (event_id, member_id, decision, decided_by_system)
  select e.id, null, 'reject', true from public.events e
    where e.workspace_id = p_workspace_id and e.status = 'pending'
      and e.action not in ('created','modified')
      and e.created_at < now() - interval '7 days';
  update public.events
    set status = 'expired', decided_at = now()
    where workspace_id = p_workspace_id and status = 'pending'
      and action not in ('created','modified')
      and created_at < now() - interval '7 days';
end;
$$;
revoke execute on function public.sweep_pending_events(uuid) from public, anon;

-- ---------------------------------------------------------------- 5+3. void_invoice v3
create or replace function public.void_invoice(p_invoice_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_invoice public.invoices;
  v_actor public.members;
  v_actor_name text;
begin
  select * into v_invoice from public.invoices where id = p_invoice_id;
  if v_invoice.id is null then raise exception 'unknown invoice'; end if;
  if exists (select 1 from public.invoice_matches
              where invoice_id = p_invoice_id) then
    -- 0068: a paid (or awaiting-validation) invoice is definitive.
    raise exception 'invoice is matched';
  end if;
  -- #816 — a source folded into a settlement is owed THROUGH the
  -- settlement; correct the settlement, not the source.
  if v_invoice.settled_by_invoice_id is not null then
    raise exception 'invoice is settled';
  end if;
  v_actor := public.issuing_member(v_invoice.workspace_id);
  if v_invoice.voided_at is not null then
    raise exception 'invoice already voided';
  end if;
  select coalesce(display_name, '') into v_actor_name
    from public.profiles where id = v_actor.user_id;
  update public.invoices
     set voided_at = now(), voided_by_name = v_actor_name
   where id = p_invoice_id;
  -- #816 — voiding a settlement releases its sources: they are owed
  -- separately again and dunning sees them again.
  if v_invoice.kind = 'settlement' then
    update public.invoices set settled_by_invoice_id = null
      where settled_by_invoice_id = p_invoice_id;
  end if;
end;
$$;
revoke execute on function public.void_invoice(uuid) from public, anon;
grant execute on function public.void_invoice(uuid) to authenticated;

-- ---------------------------------------------------------------- 5+6. record_invoice_reminder v2
create or replace function public.record_invoice_reminder(
  p_invoice_id uuid
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_invoice public.invoices;
  v_actor public.members;
  v_actor_name text;
  v_rules jsonb;
  v_levels int;
  v_first int;
  v_count int;
  v_level int;
  v_event_id uuid;
  v_cfg public.push_config;
begin
  select * into v_invoice from public.invoices where id = p_invoice_id;
  if v_invoice.id is null then raise exception 'unknown invoice'; end if;
  if v_invoice.voided_at is not null then
    raise exception 'invoice is voided';
  end if;
  v_actor := public.issuing_member(v_invoice.workspace_id);
  select coalesce(display_name, '') into v_actor_name
    from public.profiles where id = v_actor.user_id;
  -- #816 — the level of THIS send, the way the sweep and the client
  -- letter count it: one past what was already sent, capped at the
  -- configured maximum (extra sends reuse the last level).
  select coalesce(w.dunning_rules, '{}'::jsonb) into v_rules
    from public.workspaces w where w.id = v_invoice.workspace_id;
  v_levels := least(greatest(coalesce((v_rules ->> 'levels')::int, 3), 1), 9);
  v_first := least(greatest(coalesce((v_rules ->> 'first_after_days')::int, 14), 1), 365);
  select count(*) into v_count
    from public.invoice_reminders r where r.invoice_id = p_invoice_id;
  v_level := least(v_count + 1, v_levels);
  insert into public.invoice_reminders
    (workspace_id, invoice_id, by_name, automatic, level)
  values (v_invoice.workspace_id, p_invoice_id, v_actor_name, false, v_level);
  -- The SAME feed entry the automatic sweep files (0134): the member
  -- learns of a manual reminder too.
  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
  values
    (v_invoice.workspace_id, 'invoice_reminder', 'created', v_actor.id,
     v_invoice.member_id,
     jsonb_build_object(
       'invoice_id', v_invoice.id,
       'number', v_invoice.number,
       'level', v_level,
       'levels', v_levels,
       'amount_cents', v_invoice.total_cents,
       'currency', v_invoice.currency,
       'issued_at', v_invoice.issued_at,
       'days_overdue', greatest(0, (extract(epoch from now() - v_invoice.issued_at) / 86400)::int - v_first),
       'automatic', false),
     'applied')
  returning id into v_event_id;
  select * into v_cfg from public.push_config where id;
  if v_cfg.functions_url is not null then
    begin
      perform net.http_post(
        url := v_cfg.functions_url || '/send-push',
        headers := jsonb_build_object(
          'Authorization', 'Bearer ' || v_cfg.anon_key,
          'Content-Type', 'application/json'),
        body := jsonb_build_object('event_id', v_event_id),
        timeout_milliseconds := 5000);
    exception when others then
      null;
    end;
  end if;
end;
$$;
revoke execute on function public.record_invoice_reminder(uuid)
  from public, anon;
grant execute on function public.record_invoice_reminder(uuid) to authenticated;

-- ---------------------------------------------------------------- 5. settle_credit_invoice v2
create or replace function public.settle_credit_invoice(
  p_invoice_id uuid, p_note text default ''
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_invoice public.invoices;
  v_actor public.members;
  v_actor_name text;
  v_note text := btrim(coalesce(p_note, ''));
  v_has_policy boolean;
  v_event_id uuid;
  v_payout_id uuid;
  v_amount int;
begin
  select * into v_invoice from public.invoices where id = p_invoice_id;
  if v_invoice.id is null then raise exception 'unknown invoice'; end if;
  if v_invoice.voided_at is not null then
    raise exception 'invoice is voided';
  end if;
  if v_invoice.total_cents >= 0 then
    raise exception 'not a credit note';
  end if;
  if exists (select 1 from public.invoice_matches
              where invoice_id = p_invoice_id) then
    raise exception 'invoice already matched';
  end if;
  v_actor := public.issuing_member(v_invoice.workspace_id);

  v_amount := -v_invoice.total_cents;
  select coalesce(display_name, '') into v_actor_name
    from public.profiles where id = v_actor.user_id;

  insert into public.ledger_entries
    (workspace_id, member_id, kind, category, amount_cents,
     description, period)
  values
    (v_invoice.workspace_id, v_invoice.member_id, 'charge',
     'adjustment', v_amount,
     'Refund ' || v_invoice.number
       || case when v_note = '' then '' else ' — ' || v_note end,
     to_char(now(), 'YYYY-MM'))
  returning id into v_payout_id;

  v_has_policy := exists (
    select 1 from public.validation_policies vp
    where vp.workspace_id = v_invoice.workspace_id
      and vp.event_type = 'invoice_payment');

  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id,
     payload, status, decided_at)
  values
    (v_invoice.workspace_id, 'invoice_payment', 'submitted',
     v_actor.id, v_invoice.member_id,
     jsonb_build_object(
       'invoice_id', v_invoice.id,
       'number', v_invoice.number,
       'due_cents', v_invoice.total_cents,
       'paid_cents', v_amount,
       'amount_cents', v_amount,
       'resolution', 'refunded',
       'note', v_note),
     case when v_has_policy then 'pending' else 'confirmed' end,
     case when v_has_policy then null else now() end)
  returning id into v_event_id;

  insert into public.invoice_matches
    (workspace_id, invoice_id, paid_cents, resolution, note, status,
     event_id, credit_ledger_id, by_name)
  values
    (v_invoice.workspace_id, p_invoice_id, v_amount, 'refunded',
     v_note, case when v_has_policy then 'pending' else 'confirmed' end,
     v_event_id, v_payout_id, v_actor_name);
end;
$$;
revoke execute on function
  public.settle_credit_invoice(uuid, text) from public, anon;
grant execute on function
  public.settle_credit_invoice(uuid, text) to authenticated;

-- ---------------------------------------------------------------- 5. request_invoice_writeoff v2
create or replace function public.request_invoice_writeoff(
  p_invoice_id uuid, p_reason text default ''
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_invoice public.invoices;
  v_match public.invoice_matches;
  v_actor public.members;
  v_id uuid;
begin
  select * into v_invoice from public.invoices where id = p_invoice_id;
  if v_invoice.id is null then raise exception 'unknown invoice'; end if;
  -- #816 — the same permission as every other invoicing act; the
  -- message the client already maps.
  begin
    v_actor := public.issuing_member(v_invoice.workspace_id);
  exception when others then
    raise exception 'only admins may cancel outstanding amounts';
  end;
  select * into v_match from public.invoice_matches
    where invoice_id = p_invoice_id;
  if v_match.invoice_id is null or v_match.status <> 'confirmed'
     or v_match.resolution <> 'under_accepted' then
    raise exception 'no partially paid match to write off';
  end if;
  if v_match.writeoff_at is not null then
    raise exception 'remainder already cancelled';
  end if;
  if exists (select 1 from public.events
              where type = 'invoice_writeoff' and status = 'pending'
                and (payload->>'invoice_id')::uuid = p_invoice_id) then
    raise exception 'write-off already requested';
  end if;
  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id,
     payload, status)
  values (
    v_invoice.workspace_id, 'invoice_writeoff', 'submitted',
    v_actor.id, v_invoice.member_id,
    jsonb_build_object(
      'invoice_id', v_invoice.id,
      'number', v_invoice.number,
      'amount_cents', v_invoice.total_cents - v_match.paid_cents,
      'reason', left(coalesce(p_reason, ''), 300)
    ),
    'pending'
  )
  returning id into v_id;
  return v_id;
end;
$$;
revoke execute on function
  public.request_invoice_writeoff(uuid, text) from public, anon;
grant execute on function
  public.request_invoice_writeoff(uuid, text) to authenticated;

-- ---------------------------------------------------------------- 5+3. create_invoice (in place)
do $patch$
declare
  v_def text;
  v_old_gate text := $o$    select * into v_actor from public.members
      where workspace_id = p_workspace_id and user_id = auth.uid()
        and status = 'active' and (is_admin or is_owner);
    if v_actor.id is null then raise exception 'not an admin of this workspace'; end if;$o$;
  v_new_gate text := $n$    -- #816 — the matrix alone decides who issues.
    v_actor := public.issuing_member(p_workspace_id);$n$;
  v_old_replace text := $o$    if exists (select 1 from public.invoice_matches
                where invoice_id = p_replaces) then
      raise exception 'invoice is matched';
    end if;$o$;
  v_new_replace text := $n$    if exists (select 1 from public.invoice_matches
                where invoice_id = p_replaces) then
      raise exception 'invoice is matched';
    end if;
    if v_replaced.settled_by_invoice_id is not null then
      raise exception 'invoice is settled';
    end if;$n$;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'create_invoice';
  if v_def is null then raise exception 'create_invoice missing'; end if;
  if position('issuing_member' in v_def) > 0 then
    raise notice 'create_invoice already gates through issuing_member';
    return;
  end if;
  if position(v_old_gate in v_def) = 0 then
    raise exception '0144: create_invoice gate not found — body drifted';
  end if;
  if position(v_old_replace in v_def) = 0 then
    raise exception '0144: create_invoice replace guard not found — body drifted';
  end if;
  v_def := replace(v_def, v_old_gate, v_new_gate);
  v_def := replace(v_def, v_old_replace, v_new_replace);
  execute v_def;
end $patch$;

-- ---------------------------------------------------------------- 5+3. match_invoice (in place)
do $patch$
declare
  v_def text;
  v_old_gate text := $o$  select * into v_actor from public.members
    where workspace_id = v_invoice.workspace_id and user_id = auth.uid()
      and status = 'active' and (is_admin or is_owner);
  if v_actor.id is null then raise exception 'not an admin of this workspace'; end if;$o$;
  v_new_gate text := $n$  -- #816 — the matrix alone decides who matches.
  v_actor := public.issuing_member(v_invoice.workspace_id);$n$;
  v_old_void text := $o$  if v_invoice.voided_at is not null then
    raise exception 'invoice is voided';
  end if;
  select * into v_existing from public.invoice_matches$o$;
  v_new_void text := $n$  if v_invoice.voided_at is not null then
    raise exception 'invoice is voided';
  end if;
  if v_invoice.settled_by_invoice_id is not null then
    raise exception 'invoice is settled';
  end if;
  select * into v_existing from public.invoice_matches$n$;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'match_invoice';
  if v_def is null then raise exception 'match_invoice missing'; end if;
  if position('issuing_member' in v_def) > 0 then
    raise notice 'match_invoice already gates through issuing_member';
    return;
  end if;
  if position(v_old_gate in v_def) = 0 then
    raise exception '0144: match_invoice gate not found — body drifted';
  end if;
  if position(v_old_void in v_def) = 0 then
    raise exception '0144: match_invoice void guard not found — body drifted';
  end if;
  v_def := replace(v_def, v_old_gate, v_new_gate);
  v_def := replace(v_def, v_old_void, v_new_void);
  execute v_def;
end $patch$;

-- ---------------------------------------------------------------- 2. settle_invoices v2
create or replace function public.settle_invoices(
  p_workspace_id uuid,
  p_member_id uuid,
  p_invoice_ids uuid[],
  p_note text default ''
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_actor public.members;
  v_subject public.members;
  v_workspace public.workspaces;
  v_latest public.invoices;
  v_lines jsonb := '[]'::jsonb;
  v_settles jsonb := '[]'::jsonb;
  v_total int := 0;
  v_count int;
  v_number text;
  v_id uuid;
  v_signature text;
  v_issuer_name text;
  v_src public.invoices;
  v_n int := 0;
  v_has_policy boolean;
begin
  -- #816 — the matrix alone decides; the feature must be on.
  v_actor := public.issuing_member(p_workspace_id);
  select * into v_workspace from public.workspaces where id = p_workspace_id;
  if not coalesce((v_workspace.feature_flags ->> 'invoiceSettlement')::boolean, true) then
    raise exception 'invoice settlement is not enabled';
  end if;

  select * into v_subject from public.members
    where id = p_member_id and workspace_id = p_workspace_id
      and status = 'active' and not is_kiosk;
  if v_subject.id is null then raise exception 'unknown subject member'; end if;

  if p_invoice_ids is null or array_length(p_invoice_ids, 1) is null
     or array_length(p_invoice_ids, 1) < 2 then
    raise exception 'settle at least two invoices';
  end if;

  perform pg_advisory_xact_lock(hashtext(p_workspace_id::text));

  for v_src in
    select * from public.invoices
     where id = any(p_invoice_ids)
     order by issued_at, number
  loop
    v_n := v_n + 1;
    if v_src.workspace_id <> p_workspace_id then
      raise exception 'invoice % is not in this workspace', v_src.number;
    end if;
    if v_src.member_id <> p_member_id then
      raise exception 'invoice % belongs to another member', v_src.number;
    end if;
    if v_src.voided_at is not null then
      raise exception 'invoice % is void', v_src.number;
    end if;
    if v_src.settled_by_invoice_id is not null then
      raise exception 'invoice % is already settled', v_src.number;
    end if;
    if v_src.kind = 'settlement' then
      raise exception 'invoice % is itself a settlement', v_src.number;
    end if;
    if exists (select 1 from public.invoice_matches m
                where m.invoice_id = v_src.id) then
      raise exception 'invoice % already has a payment', v_src.number;
    end if;

    v_total := v_total + v_src.total_cents;
    v_lines := v_lines || jsonb_build_object(
      'kind', 'settled_invoice',
      'label', v_src.number,
      'quantity', 1,
      'vat_percent', 0,
      'amount_cents', v_src.total_cents);
    v_settles := v_settles || jsonb_build_object(
      'invoice_id', v_src.id,
      'number', v_src.number,
      'period', v_src.period,
      'kind', v_src.kind,
      'issued_at', v_src.issued_at,
      'total_cents', v_src.total_cents,
      'currency', v_src.currency,
      'lines', v_src.lines,
      'vat_totals', v_src.vat_totals);
    v_latest := v_src;
  end loop;

  if v_n <> array_length(p_invoice_ids, 1) then
    raise exception 'unknown invoice in the selection';
  end if;

  select coalesce(display_name, '') into v_issuer_name
    from public.profiles where id = v_actor.user_id;

  select count(*) into v_count from public.invoices
    where workspace_id = p_workspace_id
      and date_part('year', issued_at) = date_part('year', now());
  v_number := 'INV-' || date_part('year', now())::int || '-'
      || lpad((v_count + 1)::text, 4, '0');

  v_id := gen_random_uuid();
  v_signature := encode(extensions.digest(convert_to(concat_ws('|',
      v_id::text, v_number, p_workspace_id::text, v_subject.id::text,
      v_lines::text, v_total::text, v_settles::text,
      now()::date::text, 'settlement'),
      'UTF8'), 'sha256'), 'hex');

  insert into public.invoices
    (id, workspace_id, member_id, issuer_member_id, number, period, title,
     lines, total_cents, currency, member_name, member_address,
     workspace_name, workspace_address, issuer_name, signature,
     parties, vat_totals, kind, settles)
  values
    (v_id, p_workspace_id, p_member_id, v_actor.id, v_number,
     null, coalesce(nullif(p_note, ''), v_number),
     v_lines, v_total, v_latest.currency,
     v_latest.member_name, v_latest.member_address,
     v_latest.workspace_name, v_latest.workspace_address,
     v_issuer_name, v_signature,
     v_latest.parties,
     '[]'::jsonb, 'settlement', v_settles);

  update public.invoices
     set settled_by_invoice_id = v_id
   where id = any(p_invoice_ids);

  -- #816 — the SAME rule every other invoice_payment obeys: a policy on
  -- the domain makes the regrouping wait for the validators (the sources
  -- are already held, like a pending match); a reject voids the
  -- settlement and releases them. No policy: confirmed on the spot, but
  -- never 'applied' by its own author.
  v_has_policy := exists (
    select 1 from public.validation_policies vp
    where vp.workspace_id = p_workspace_id
      and vp.event_type = 'invoice_payment');
  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id,
     payload, status, decided_at)
  values
    (p_workspace_id, 'invoice_payment', 'submitted', v_actor.id, p_member_id,
     jsonb_build_object(
       'invoice_id', v_id, 'number', v_number, 'kind', 'settlement',
       'amount_cents', v_total, 'currency', v_latest.currency,
       'settled_count', v_n,
       'settled_numbers', (select jsonb_agg(s->>'number')
                             from jsonb_array_elements(v_settles) s)),
     case when v_has_policy then 'pending' else 'confirmed' end,
     case when v_has_policy then null else now() end);

  return v_id;
end;
$$;
revoke execute on function
  public.settle_invoices(uuid, uuid, uuid[], text) from public, anon;
grant execute on function
  public.settle_invoices(uuid, uuid, uuid[], text) to authenticated;

-- ---------------------------------------------------------------- 7. finance RLS
-- The four tables 0131 left behind: the same audience as the invoices
-- they describe.
create or replace function public.may_view_invoice(p_invoice_id uuid)
returns boolean language sql stable security definer
set search_path = public as $$
  select exists (
    select 1 from public.invoices i
     where i.id = p_invoice_id
       and public.may_view_member_finances(i.member_id)
  );
$$;
revoke execute on function public.may_view_invoice(uuid) from public, anon;

alter policy invoice_matches_select on public.invoice_matches
  using (public.may_view_invoice(invoice_id));
alter policy invoice_match_payments_select on public.invoice_match_payments
  using (public.may_view_invoice(invoice_id));
alter policy invoice_reminders_select on public.invoice_reminders
  using (public.may_view_invoice(invoice_id));
alter policy invoice_transmissions_select on public.invoice_transmissions
  using (public.may_view_invoice(invoice_id));

-- ---------------------------------------------------------------- 8. validators see their events
-- A validator named by a 'listed' rule, or any member under a 'members'
-- rule, must read the pending event they are asked to decide.
create or replace function public.may_validate_event_type(
  p_workspace_id uuid, p_type text
) returns boolean language sql stable security definer
set search_path = public as $$
  select exists (
    select 1
      from public.validation_policies vp
      join public.members m
        on m.workspace_id = vp.workspace_id and m.user_id = auth.uid()
       and m.status = 'active'
     where vp.workspace_id = p_workspace_id
       and (vp.event_type = p_type or vp.event_type is null)
       and (vp.validator_scope = 'members'
            or (vp.validator_scope = 'listed'
                and m.id = any(vp.eligible_admin_ids)))
  );
$$;
revoke execute on function public.may_validate_event_type(uuid, text) from public, anon;

alter policy events_select on public.events
  using (
    public.is_admin_of(workspace_id)
    or exists (
      select 1 from public.members m
      where m.user_id = auth.uid()
        and m.id in (events.actor_member_id, events.subject_member_id)
    )
    or public.may_validate_event_type(workspace_id, events.type)
  );

-- ---------------------------------------------------------------- 9. manageValidation / workspaceSettings
alter policy validation_policies_write on public.validation_policies
  using (public.has_permission(workspace_id, 'manageValidation'))
  with check (public.has_permission(workspace_id, 'manageValidation'));

create or replace function public.set_dunning_rules(
  p_workspace_id uuid, p_rules jsonb
) returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.has_permission(p_workspace_id, 'workspaceSettings') then
    raise exception 'not allowed to change the workspace settings';
  end if;
  update public.workspaces set dunning_rules = coalesce(p_rules, '{}'::jsonb)
    where id = p_workspace_id;
end;
$$;
revoke execute on function public.set_dunning_rules(uuid, jsonb) from public, anon;
grant execute on function public.set_dunning_rules(uuid, jsonb) to authenticated;

create or replace function public.set_billing_rules(
  p_workspace_id uuid, p_rules jsonb
) returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.has_permission(p_workspace_id, 'workspaceSettings') then
    raise exception 'not allowed to change the workspace settings';
  end if;
  update public.workspaces set billing_rules = coalesce(p_rules, '{}'::jsonb)
    where id = p_workspace_id;
end;
$$;
revoke execute on function public.set_billing_rules(uuid, jsonb) from public, anon;
grant execute on function public.set_billing_rules(uuid, jsonb) to authenticated;
