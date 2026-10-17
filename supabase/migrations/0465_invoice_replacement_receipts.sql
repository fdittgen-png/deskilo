-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0465 (#2585, C2) -- the replacement of an erroneous invoice carries the
-- same exact request identity as every other financial command (0462-0464).
--
-- `create_invoice_replacement_v1` wraps `create_invoice` with p_replaces (the
-- correction of a document of record, issued directly, as before) and writes
-- one receipt in the same transaction: the receipt exists iff the new invoice
-- exists AND the replaced one was voided with it. The digest covers every
-- argument, including the replaced invoice and the correction reason; the
-- same id with another one is refused. The outcome read already answers the
-- made invoice's id for this kind.

alter table public.financial_command_receipts
  drop constraint financial_command_receipts_kind_check,
  drop constraint financial_command_receipts_subject_check,
  drop constraint financial_command_receipts_applied_check,
  add constraint financial_command_receipts_kind_check
    check (command_kind in ('invoice_issue', 'invoice_create', 'invoice_replace',
                            'settle_invoices', 'invoice_void', 'refund')),
  add constraint financial_command_receipts_subject_check
    check ((command_kind in ('invoice_issue', 'invoice_create', 'invoice_replace',
                             'settle_invoices')) = (subject_invoice_id is null)),
  add constraint financial_command_receipts_applied_check
    check (state <> 'applied'
           or (command_kind in ('invoice_issue', 'invoice_create', 'invoice_replace',
                                'settle_invoices')) = (invoice_id is not null));

create or replace function public.create_invoice_replacement_v1(
  p_workspace_id uuid, p_member_id uuid, p_period text, p_replaces uuid, p_request_id uuid,
  p_detailed boolean default false, p_kind text default 'full',
  p_buyer_reference text default '', p_purchase_order text default '',
  p_correction_reason text default ''
) returns uuid language plpgsql security definer set search_path = public as $fn$
declare
  v_actor public.members;
  v_digest text;
  v_id uuid;
begin
  v_actor := public.issuing_member(p_workspace_id);
  if p_request_id is null then raise exception 'a request id is required'; end if;
  if p_replaces is null then raise exception 'a replacement names the invoice it replaces'; end if;
  v_digest := encode(sha256(convert_to(jsonb_build_object(
    'member_id', p_member_id, 'period', p_period, 'replaces', p_replaces,
    'detailed', p_detailed, 'kind', p_kind,
    'buyer_reference', coalesce(p_buyer_reference, ''),
    'purchase_order', coalesce(p_purchase_order, ''),
    'correction_reason', coalesce(p_correction_reason, '')
  )::text, 'UTF8')), 'hex');
  v_id := public.financial_receipt_replay_v1(p_workspace_id, v_actor.id, p_request_id,
    'invoice_replace', v_digest);
  if v_id is not null then return v_id; end if;
  v_id := public.create_invoice(p_workspace_id, p_member_id, p_period, p_replaces,
    p_detailed, p_kind, false, coalesce(p_buyer_reference, ''), coalesce(p_purchase_order, ''),
    coalesce(p_correction_reason, ''));
  insert into public.financial_command_receipts
    (workspace_id, actor_member_id, request_id, command_kind, payload_digest, state, invoice_id)
  values (p_workspace_id, v_actor.id, p_request_id, 'invoice_replace', v_digest, 'applied', v_id);
  return v_id;
end;
$fn$;
revoke execute on function public.create_invoice_replacement_v1(uuid, uuid, text, uuid, uuid, boolean, text, text, text, text)
  from public, anon;
grant execute on function public.create_invoice_replacement_v1(uuid, uuid, text, uuid, uuid, boolean, text, text, text, text)
  to authenticated;

select public.set_deskilo_schema_version(465);
