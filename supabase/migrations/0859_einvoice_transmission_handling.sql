-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (column privileges of invoice_transmissions change; one reader is new; one writer is patched
--  at an asserted anchor)
--
-- E-invoice transmissions: who reads what, and when a manual resolution is admitted.
--
--   * The columns that say how the business handled a transmission (the business key, the binding,
--     the owner and generation of the dispatch, its deadline, the last query error, who requested
--     and who resolved it, the reason and the evidence of a resolution) are read by those who may
--     issue invoices, through `einvoice_transmission_handling_v1`. The member an invoice is for
--     reads what happened to the invoice (its phase and status, the provider, the external id, the
--     document hash, the detail, the receipt and the verdict) and none of those columns: the
--     authenticated role holds a column privilege on the first set only.
--   * A manual resolution as `failed` is admitted only once the claim of the dispatch has ended: a
--     dispatch whose deadline has not passed may still be running, and `failed` would let the same
--     document be claimed and sent again. The answer is `claim_live`; a resolution as `accepted`
--     or `rejected` is a fact and stays admitted.

-- ── the columns a client reads ─────────────────────────────────────────
revoke select on public.invoice_transmissions from authenticated;
grant select (id, workspace_id, invoice_id, provider, status, external_id, document_hash, detail,
              sent_at, by_name, environment, destination, created_datetime, modified_datetime,
              company_id, site_id, created_by_user, modified_by_user, format, receipt, receipt_at,
              phase, verdict, kind)
  on public.invoice_transmissions to authenticated;

-- ── what the business did with a transmission: issuers only ────────────
create or replace function public.einvoice_transmission_handling_v1(
  p_workspace_id uuid, p_invoice_id uuid default null
) returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_me uuid;
begin
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception 'not allowed to read how transmissions were handled' using errcode = '42501';
  end if;
  select m.id into v_me from public.members m
   where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active'
     and (m.is_owner or m.is_admin or public.member_has_permission(m.id, 'issueInvoices'));
  if v_me is null then
    raise exception 'not allowed to read how transmissions were handled' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', t.id, 'invoice_id', t.invoice_id, 'phase', t.phase, 'business_key', t.business_key,
             'owner_id', t.owner_id, 'generation', t.generation, 'deadline', t.deadline,
             'query_error', t.query_error, 'requested_by', t.requested_by, 'resolved_by', t.resolved_by,
             'resolved_reason', t.resolved_reason, 'resolved_evidence', t.resolved_evidence,
             'resolved_at', t.resolved_at) order by t.sent_at desc, t.id)
      from public.invoice_transmissions t
     where t.workspace_id = p_workspace_id and (p_invoice_id is null or t.invoice_id = p_invoice_id)
  ), '[]'::jsonb);
end;
$fn$;
revoke execute on function public.einvoice_transmission_handling_v1(uuid, uuid) from public, anon;
grant execute on function public.einvoice_transmission_handling_v1(uuid, uuid) to authenticated;

-- ── a manual `failed` waits for the end of the claim ───────────────────
create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
declare
  v_pattern text;
  v_out text;
begin
  if position(p_old in p_def) > 0 then
    return replace(p_def, p_old, p_new);
  end if;
  v_pattern := regexp_replace(btrim(p_old, E' \t\n'), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
  v_pattern := regexp_replace(v_pattern, '\s+', '\\s*', 'g');
  v_out := regexp_replace(p_def, v_pattern, replace(btrim(p_new, E' \t\n'), '\', '\\'), 'g');
  return case when v_out = p_def then null else v_out end;
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $patch$
declare
  v_def text := pg_get_functiondef('public.resolve_einvoice_manually_v1(uuid, uuid, text, text, text, jsonb)'::regprocedure);
  v_next text;
begin
  v_next := pg_temp.anchor_replace(v_def,
    $o$  update public.invoice_transmissions
    set phase = p_outcome, resolved_by = p_actor,$o$,
    $n$  -- the claim of the dispatch is still live: it may be running, and `failed` would let the same
  -- document be claimed and sent again
  if p_outcome = 'failed' and exists (select 1 from public.invoice_transmissions t
       where t.id = p_id and t.phase = 'uncertain' and t.deadline is not null and t.deadline > now()) then
    return jsonb_build_object('resolved', false, 'phase', 'uncertain', 'detail', 'claim_live');
  end if;
  update public.invoice_transmissions
    set phase = p_outcome, resolved_by = p_actor,$n$);
  if v_next is null then raise exception '0859: the anchor of resolve_einvoice_manually_v1 is not found' using errcode = 'P0001'; end if;
  -- the write itself holds the same condition: the row moves only when its claim has ended
  v_next := pg_temp.anchor_replace(v_next,
    $o$    where id = p_id and phase = 'uncertain'
    returning * into v_row;$o$,
    $n$    where id = p_id and phase = 'uncertain'
      and not (p_outcome = 'failed' and deadline is not null and deadline > now())
    returning * into v_row;$n$);
  if v_next is null then raise exception '0859: the write anchor of resolve_einvoice_manually_v1 is not found' using errcode = 'P0001'; end if;
  execute v_next;
end
$patch$;

select public.set_deskilo_schema_version(859);
