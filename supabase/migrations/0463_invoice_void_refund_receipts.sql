-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0463 (#2585, C2) -- voiding an invoice and refunding a credit note carry
-- the same exact request identity as issuing one (0462).
--
--   * `request_invoice_void_v1` / `request_refund_v1` wrap the unchanged
--     `request_invoice_void` / `request_refund` (same authorization, same
--     validation policy) and write one receipt in the same transaction. The
--     subject invoice is part of the digest: the same id naming another
--     invoice, or another kind of command, is refused.
--   * A void or a refund answers no new id, so an applied receipt of those
--     kinds carries the SUBJECT invoice (`subject_invoice_id`) instead of a
--     made one: a documented successful void is proven by its receipt.
--   * `financial_command_outcome_v1` also answers `command_kind`, and reads a
--     confirmed void / refund event as applied.
--
-- Legacy `request_invoice_void` / `request_refund` keep their signatures.

alter table public.financial_command_receipts
  drop constraint financial_command_receipts_command_kind_check,
  drop constraint financial_command_receipts_check,
  add column subject_invoice_id uuid,
  add constraint financial_command_receipts_kind_check
    check (command_kind in ('invoice_issue', 'invoice_void', 'refund')),
  add constraint financial_command_receipts_subject_check
    check ((command_kind = 'invoice_issue') = (subject_invoice_id is null)),
  add constraint financial_command_receipts_applied_check
    check (state <> 'applied'
           or (command_kind = 'invoice_issue') = (invoice_id is not null));

-- One wrapper for both kinds, so the replay / conflict / lock logic exists
-- once. Not granted: the two public wrappers below call it.
create or replace function public.financial_subject_command_v1(
  p_kind text, p_invoice_id uuid, p_request_id uuid, p_text text
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_inv public.invoices;
  v_actor public.members;
  v_digest text;
  v_old public.financial_command_receipts;
  v_res jsonb;
begin
  select * into v_inv from public.invoices where id = p_invoice_id;
  if v_inv.id is null then raise exception 'unknown invoice'; end if;
  v_actor := public.my_active_member(v_inv.workspace_id);
  if not public.has_permission(v_inv.workspace_id, 'issueInvoices') then
    raise exception 'not allowed to issue invoices';
  end if;
  if p_request_id is null then raise exception 'a request id is required'; end if;
  v_digest := encode(sha256(convert_to(jsonb_build_object(
    'kind', p_kind, 'invoice_id', p_invoice_id, 'text', coalesce(p_text, '')
  )::text, 'UTF8')), 'hex');

  perform pg_advisory_xact_lock(hashtextextended(
    'financial_command:' || v_inv.workspace_id::text || ':' || v_actor.id::text
      || ':' || p_request_id::text, 0));
  select * into v_old from public.financial_command_receipts r
   where r.workspace_id = v_inv.workspace_id
     and r.actor_member_id = v_actor.id and r.request_id = p_request_id;
  if found then
    if v_old.command_kind <> p_kind or v_old.payload_digest <> v_digest then
      raise exception 'request conflict: this request id was used for another command';
    end if;
    if v_old.state = 'applied' then
      return jsonb_build_object('pending', false, 'replayed', true);
    end if;
    return jsonb_build_object('pending', true, 'event_id', v_old.event_id, 'replayed', true);
  end if;

  if p_kind = 'invoice_void' then
    v_res := public.request_invoice_void(p_invoice_id, coalesce(p_text, ''));
  else
    v_res := public.request_refund(p_invoice_id, coalesce(p_text, ''));
  end if;
  insert into public.financial_command_receipts
    (workspace_id, actor_member_id, request_id, command_kind, payload_digest, state,
     event_id, subject_invoice_id)
  values (v_inv.workspace_id, v_actor.id, p_request_id, p_kind, v_digest,
    case when (v_res->>'pending')::boolean then 'pending' else 'applied' end,
    case when (v_res->>'pending')::boolean then (v_res->>'event_id')::uuid end,
    p_invoice_id);
  return v_res;
end;
$fn$;
revoke execute on function public.financial_subject_command_v1(text, uuid, uuid, text)
  from public, anon, authenticated;

create or replace function public.request_invoice_void_v1(
  p_invoice_id uuid, p_request_id uuid, p_reason text default ''
) returns jsonb language sql security definer set search_path = public as $fn$
  select public.financial_subject_command_v1('invoice_void', p_invoice_id, p_request_id, p_reason);
$fn$;
revoke execute on function public.request_invoice_void_v1(uuid, uuid, text) from public, anon;
grant execute on function public.request_invoice_void_v1(uuid, uuid, text) to authenticated;

create or replace function public.request_refund_v1(
  p_invoice_id uuid, p_request_id uuid, p_note text default ''
) returns jsonb language sql security definer set search_path = public as $fn$
  select public.financial_subject_command_v1('refund', p_invoice_id, p_request_id, p_note);
$fn$;
revoke execute on function public.request_refund_v1(uuid, uuid, text) from public, anon;
grant execute on function public.request_refund_v1(uuid, uuid, text) to authenticated;

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
    return jsonb_build_object('state', 'applied', 'command_kind', v_r.command_kind,
      'invoice_id', coalesce(v_r.invoice_id, v_r.subject_invoice_id));
  end if;
  select * into v_ev from public.events e
   where e.id = v_r.event_id and e.workspace_id = p_workspace_id;
  if v_ev.status = 'confirmed' then
    if v_r.command_kind = 'invoice_issue' then
      if v_ev.payload ? 'invoice_id' then
        return jsonb_build_object('state', 'applied', 'command_kind', v_r.command_kind,
          'invoice_id', v_ev.payload->>'invoice_id');
      end if;
    else
      return jsonb_build_object('state', 'applied', 'command_kind', v_r.command_kind,
        'invoice_id', v_r.subject_invoice_id);
    end if;
  elsif v_ev.status in ('rejected', 'expired') then
    return jsonb_build_object('state', 'refused', 'command_kind', v_r.command_kind,
      'event_id', v_r.event_id, 'event_status', v_ev.status);
  end if;
  return jsonb_build_object('state', 'pending', 'command_kind', v_r.command_kind,
    'event_id', v_r.event_id, 'event_status', coalesce(v_ev.status, 'pending'));
end;
$fn$;
revoke execute on function public.financial_command_outcome_v1(uuid, uuid) from public, anon;
grant execute on function public.financial_command_outcome_v1(uuid, uuid) to authenticated;

select public.set_deskilo_schema_version(463);
