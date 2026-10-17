-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0464 (#2585, C2) -- the batch issue and the settlement carry the same
-- exact request identity as 0462 / 0463.
--
--   * `create_invoice_receipted_v1` wraps `create_invoice` (the direct issue
--     the invoicing wizard uses, no validation policy -- unchanged) and
--     `settle_invoices_v1` wraps `settle_invoices`. Each writes one receipt in
--     the same transaction. The wizard draws one id per member, kept across
--     "issue again": a constituent that already committed replays instead of
--     failing on "already invoiced", and is never issued twice.
--   * The digest covers the member, the period and kind (issue) or the
--     member, the SORTED invoice ids and the note (settlement).
--   * `financial_command_outcome_v1` is unchanged: both kinds are "made an
--     invoice", so an applied receipt answers that invoice's id.

alter table public.financial_command_receipts
  drop constraint financial_command_receipts_kind_check,
  drop constraint financial_command_receipts_subject_check,
  drop constraint financial_command_receipts_applied_check,
  add constraint financial_command_receipts_kind_check
    check (command_kind in ('invoice_issue', 'invoice_create', 'settle_invoices',
                            'invoice_void', 'refund')),
  add constraint financial_command_receipts_subject_check
    check ((command_kind in ('invoice_issue', 'invoice_create', 'settle_invoices'))
           = (subject_invoice_id is null)),
  add constraint financial_command_receipts_applied_check
    check (state <> 'applied'
           or (command_kind in ('invoice_issue', 'invoice_create', 'settle_invoices'))
              = (invoice_id is not null));

-- The id a replay answers, or NULL when this request id is new. The same id
-- for another kind or payload is a conflict, never a reuse.
create or replace function public.financial_receipt_replay_v1(
  p_workspace_id uuid, p_actor uuid, p_request_id uuid, p_kind text, p_digest text
) returns uuid language plpgsql security definer set search_path = public as $fn$
declare
  v_old public.financial_command_receipts;
begin
  perform pg_advisory_xact_lock(hashtextextended(
    'financial_command:' || p_workspace_id::text || ':' || p_actor::text
      || ':' || p_request_id::text, 0));
  select * into v_old from public.financial_command_receipts r
   where r.workspace_id = p_workspace_id
     and r.actor_member_id = p_actor and r.request_id = p_request_id;
  if not found then return null; end if;
  if v_old.command_kind <> p_kind or v_old.payload_digest <> p_digest then
    raise exception 'request conflict: this request id was used for another command';
  end if;
  return v_old.invoice_id;
end;
$fn$;
revoke execute on function public.financial_receipt_replay_v1(uuid, uuid, uuid, text, text)
  from public, anon, authenticated;

create or replace function public.create_invoice_receipted_v1(
  p_workspace_id uuid, p_member_id uuid, p_period text, p_request_id uuid,
  p_kind text default 'full'
) returns uuid language plpgsql security definer set search_path = public as $fn$
declare
  v_actor public.members;
  v_digest text;
  v_id uuid;
begin
  v_actor := public.issuing_member(p_workspace_id);
  if p_request_id is null then raise exception 'a request id is required'; end if;
  v_digest := encode(sha256(convert_to(jsonb_build_object(
    'member_id', p_member_id, 'period', p_period, 'kind', p_kind
  )::text, 'UTF8')), 'hex');
  v_id := public.financial_receipt_replay_v1(p_workspace_id, v_actor.id, p_request_id,
    'invoice_create', v_digest);
  if v_id is not null then return v_id; end if;
  v_id := public.create_invoice(p_workspace_id, p_member_id, p_period, null, false, p_kind);
  insert into public.financial_command_receipts
    (workspace_id, actor_member_id, request_id, command_kind, payload_digest, state, invoice_id)
  values (p_workspace_id, v_actor.id, p_request_id, 'invoice_create', v_digest, 'applied', v_id);
  return v_id;
end;
$fn$;
revoke execute on function public.create_invoice_receipted_v1(uuid, uuid, text, uuid, text)
  from public, anon;
grant execute on function public.create_invoice_receipted_v1(uuid, uuid, text, uuid, text)
  to authenticated;

create or replace function public.settle_invoices_v1(
  p_workspace_id uuid, p_member_id uuid, p_invoice_ids uuid[], p_request_id uuid,
  p_note text default ''
) returns uuid language plpgsql security definer set search_path = public as $fn$
declare
  v_actor public.members;
  v_digest text;
  v_id uuid;
begin
  v_actor := public.issuing_member(p_workspace_id);
  if p_request_id is null then raise exception 'a request id is required'; end if;
  v_digest := encode(sha256(convert_to(jsonb_build_object(
    'member_id', p_member_id,
    'invoice_ids', (select coalesce(jsonb_agg(x order by x), '[]'::jsonb)
                      from unnest(p_invoice_ids) x),
    'note', coalesce(p_note, '')
  )::text, 'UTF8')), 'hex');
  v_id := public.financial_receipt_replay_v1(p_workspace_id, v_actor.id, p_request_id,
    'settle_invoices', v_digest);
  if v_id is not null then return v_id; end if;
  v_id := public.settle_invoices(p_workspace_id, p_member_id, p_invoice_ids, coalesce(p_note, ''));
  insert into public.financial_command_receipts
    (workspace_id, actor_member_id, request_id, command_kind, payload_digest, state, invoice_id)
  values (p_workspace_id, v_actor.id, p_request_id, 'settle_invoices', v_digest, 'applied', v_id);
  return v_id;
end;
$fn$;
revoke execute on function public.settle_invoices_v1(uuid, uuid, uuid[], uuid, text)
  from public, anon;
grant execute on function public.settle_invoices_v1(uuid, uuid, uuid[], uuid, text)
  to authenticated;

select public.set_deskilo_schema_version(464);
