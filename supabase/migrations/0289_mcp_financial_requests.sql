-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0289 (#1622) -- the financial request tools check their arguments before
-- asking a human, and read back the invoice they acted on.
--
-- request_invoice_issue / request_invoice_void / request_refund already run
-- through mcp_execute_v1 with the workspace-scoped target, the #1619 native
-- confirmation and the existing request_* workflows (quorum, thresholds,
-- automatic application). Two gaps remained:
--   * an invalid period (month 13) still produced a confirmation for a
--     person to answer; mcp_target now refuses it as invalid_arguments
--     before any confirmation exists;
--   * an applied or pending request answered an id at most; it now reads
--     the invoice back (number, period, total, currency, voided), and an
--     issue reported as applied with no invoice to read is an error.
-- Nothing else changes.

create or replace function public.mcp_invoice_view(p_invoice_id uuid)
returns jsonb language sql stable set search_path = public as $fn$
  select jsonb_build_object('invoice_id', i.id, 'invoice_number', i.number,
           'period', i.period, 'total_cents', i.total_cents, 'currency', i.currency,
           'voided', i.voided_at is not null)
    from public.invoices i where i.id = p_invoice_id;
$fn$;
revoke execute on function public.mcp_invoice_view(uuid) from public, anon, authenticated;

create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text language plpgsql as $f$
begin
  if position(p_old in p_def) = 0 then return null; end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $migration$
declare
  v_def text;
  v_next text;
begin
  v_def := pg_get_functiondef('public.mcp_target(uuid, text, jsonb)'::regprocedure);
  if position('#1622' in v_def) = 0 then
    v_next := pg_temp.anchor_replace(v_def,
      $a$  if p_operation in ('request_invoice_void', 'request_refund') then
    select * into v_invoice from public.invoices$a$,
      $a$  -- #1622 — a request a person could never approve is not put to them.
  if p_operation = 'request_invoice_issue'
     and coalesce(p_args->>'period', '') !~ '^\d{4}-(0[1-9]|1[0-2])$' then
    raise exception using errcode = '22023', message = 'period';
  end if;
  if p_operation in ('request_invoice_void', 'request_refund') then
    select * into v_invoice from public.invoices$a$);
    if v_next is null then raise exception '0289: mcp_target anchor not found'; end if;
    execute v_next;
  end if;

  v_def := pg_get_functiondef('public.mcp_execute_v1(uuid, uuid, text, jsonb, uuid)'::regprocedure);
  if position('public.mcp_invoice_view(' in v_def) = 0 then
    v_next := pg_temp.anchor_replace(v_def,
      $a$      if p_operation in ('create_reservation', 'update_reservation', 'check_in', 'check_out',$a$,
      $a$      if p_operation in ('request_invoice_issue', 'request_invoice_void', 'request_refund') then
        if p_operation = 'request_invoice_issue' and v_status = 'completed'
           and public.mcp_invoice_view((v_data->>'invoice_id')::uuid) is null then
          raise exception 'the invoice could not be read back';
        end if;
        v_data := coalesce(v_data, '{}'::jsonb) || coalesce(public.mcp_invoice_view(coalesce(
          (v_data->>'invoice_id')::uuid, public.mcp_uuid_arg(v_args, 'invoice_id', false))), '{}'::jsonb);
      end if;
      if p_operation in ('create_reservation', 'update_reservation', 'check_in', 'check_out',$a$);
    if v_next is null then raise exception '0289: mcp_execute_v1 anchor not found (needs 0288)'; end if;
    execute v_next;
  end if;
end
$migration$;

select public.set_deskilo_schema_version(289);
