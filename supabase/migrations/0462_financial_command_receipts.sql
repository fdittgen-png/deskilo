-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0462 (#2585, C2) -- a native financial command has an exact identity.
--
-- The app names an attempt with a random request id and sends the SAME id
-- when it asks again. `request_invoice_issue_v1` is `request_invoice_issue`
-- (unchanged, same authorization, feature guard and validation policy) plus
-- one receipt row written in the SAME transaction: the receipt exists if and
-- only if the command's effect (an applied invoice, or the pending
-- validation event) committed. A lost answer is therefore recoverable
-- exactly: `financial_command_outcome_v1` reads THAT request's receipt, never
-- "the newest invoice of the member and month".
--
--   * key (workspace, acting member, request id): equal ids in two
--     workspaces or from two actors never meet; the actor is derived from
--     the session, never sent.
--   * command kind + digest of the canonical payload: the same id with a
--     changed kind or payload is refused, never reused.
--   * pending stays the existing validation event; the readback derives the
--     current status from that event and can neither approve nor resubmit.
--   * no receipt means NOT OBSERVED, which is not proof the original request
--     cannot still commit.
--
-- Legacy `request_invoice_issue` and the replacement path (`create_invoice`
-- with p_replaces) keep their signatures and carry no receipt.

create table public.financial_command_receipts (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  actor_member_id uuid not null references public.members(id) on delete cascade,
  request_id uuid not null,
  command_kind text not null check (command_kind in ('invoice_issue')),
  payload_digest text not null check (char_length(payload_digest) = 64),
  state text not null check (state in ('applied', 'pending')),
  invoice_id uuid,
  event_id uuid,
  unique (workspace_id, actor_member_id, request_id),
  check ((state = 'applied') = (invoice_id is not null)),
  check ((state = 'pending') = (event_id is not null))
);
select public.ensure_system_columns('financial_command_receipts');

alter table public.financial_command_receipts enable row level security;
revoke all on public.financial_command_receipts from public, anon, authenticated;
create policy mcp_delegated_deny on public.financial_command_receipts
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

create or replace function public.request_invoice_issue_v1(
  p_workspace_id uuid,
  p_member_id uuid,
  p_period text,
  p_request_id uuid,
  p_kind text default 'full',
  p_detailed boolean default false,
  p_allow_zero boolean default false,
  p_buyer_reference text default null,
  p_purchase_order text default null
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_actor public.members;
  v_digest text;
  v_old public.financial_command_receipts;
  v_res jsonb;
begin
  v_actor := public.my_active_member(p_workspace_id);
  if not public.has_permission(p_workspace_id, 'issueInvoices') then
    raise exception 'not allowed to issue invoices';
  end if;
  if p_request_id is null then raise exception 'a request id is required'; end if;
  v_digest := encode(sha256(convert_to(jsonb_build_object(
    'member_id', p_member_id, 'period', p_period, 'kind', p_kind,
    'detailed', p_detailed, 'allow_zero', p_allow_zero,
    'buyer_reference', p_buyer_reference, 'purchase_order', p_purchase_order
  )::text, 'UTF8')), 'hex');

  perform pg_advisory_xact_lock(hashtextextended(
    'financial_command:' || p_workspace_id::text || ':' || v_actor.id::text
      || ':' || p_request_id::text, 0));
  select * into v_old from public.financial_command_receipts r
   where r.workspace_id = p_workspace_id
     and r.actor_member_id = v_actor.id and r.request_id = p_request_id;
  if found then
    if v_old.command_kind <> 'invoice_issue' or v_old.payload_digest <> v_digest then
      raise exception 'request conflict: this request id was used for another command';
    end if;
    if v_old.state = 'applied' then
      return jsonb_build_object('pending', false, 'invoice_id', v_old.invoice_id, 'replayed', true);
    end if;
    return jsonb_build_object('pending', true, 'event_id', v_old.event_id, 'replayed', true);
  end if;

  v_res := public.request_invoice_issue(p_workspace_id, p_member_id, p_period, p_kind,
    p_detailed, p_allow_zero, p_buyer_reference, p_purchase_order);
  if (v_res->>'pending')::boolean then
    insert into public.financial_command_receipts
      (workspace_id, actor_member_id, request_id, command_kind, payload_digest, state, event_id)
    values (p_workspace_id, v_actor.id, p_request_id, 'invoice_issue', v_digest, 'pending',
      (v_res->>'event_id')::uuid);
  else
    insert into public.financial_command_receipts
      (workspace_id, actor_member_id, request_id, command_kind, payload_digest, state, invoice_id)
    values (p_workspace_id, v_actor.id, p_request_id, 'invoice_issue', v_digest, 'applied',
      (v_res->>'invoice_id')::uuid);
  end if;
  return v_res;
end;
$fn$;
revoke execute on function public.request_invoice_issue_v1(uuid, uuid, text, uuid, text, boolean, boolean, text, text)
  from public, anon;
grant execute on function public.request_invoice_issue_v1(uuid, uuid, text, uuid, text, boolean, boolean, text, text)
  to authenticated;

-- What happened to ONE request. state: not_observed | applied | pending |
-- refused. `pending` carries the validation event's current status; a
-- confirmed event reads as applied with the invoice it made.
create or replace function public.financial_command_outcome_v1(
  p_workspace_id uuid, p_request_id uuid
) returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_actor public.members;
  v_r public.financial_command_receipts;
  v_ev public.events;
begin
  v_actor := public.my_active_member(p_workspace_id);
  if not public.has_permission(p_workspace_id, 'issueInvoices') then
    raise exception 'not allowed to issue invoices';
  end if;
  select * into v_r from public.financial_command_receipts r
   where r.workspace_id = p_workspace_id
     and r.actor_member_id = v_actor.id and r.request_id = p_request_id;
  if not found then return jsonb_build_object('state', 'not_observed'); end if;
  if v_r.state = 'applied' then
    return jsonb_build_object('state', 'applied', 'invoice_id', v_r.invoice_id);
  end if;
  select * into v_ev from public.events e
   where e.id = v_r.event_id and e.workspace_id = p_workspace_id;
  if v_ev.status = 'confirmed' and v_ev.payload ? 'invoice_id' then
    return jsonb_build_object('state', 'applied', 'invoice_id', v_ev.payload->>'invoice_id');
  elsif v_ev.status in ('rejected', 'expired') then
    return jsonb_build_object('state', 'refused', 'event_id', v_r.event_id, 'event_status', v_ev.status);
  end if;
  return jsonb_build_object('state', 'pending', 'event_id', v_r.event_id,
    'event_status', coalesce(v_ev.status, 'pending'));
end;
$fn$;
revoke execute on function public.financial_command_outcome_v1(uuid, uuid) from public, anon;
grant execute on function public.financial_command_outcome_v1(uuid, uuid) to authenticated;

select public.set_deskilo_schema_version(462);
