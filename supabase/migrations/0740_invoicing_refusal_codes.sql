-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0740 — #3811 (part of #3657, i18n I11c): an invoicing refusal carries its
-- code, as the booking refusals do since 0739, so the app maps codes, never
-- sentences. The English message stays for an app from before.
--
--   DKI03 the invoice is voided          DKI06 the invoice is already matched
--   DKI04 the invoice is matched         DKI07 the period is already invoiced
--   DKI05 the invoice is already replaced      for this member
--   DKD01 already decided (a request, an e-invoice, a credit note)
--
-- DKI01 (essentials missing, 0396) is read by the app by its code now. What
-- catches a refusal (the assistant's reads and writes, sample data, joining
-- by invitation) catches these codes too, as 0739 made it for the booking
-- ones; DKI01 there answers "refused" instead of escaping as an error.

create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
begin
  if position(p_old in p_def) = 0 then
    return null;
  end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $refusals$
declare
  v_def text;
begin
  -- apply_supplier_credit_note_v1
  select pg_get_functiondef('public.apply_supplier_credit_note_v1(uuid,uuid,integer,uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'this credit note is already decided';$r$,
    $r$raise exception 'this credit note is already decided' using errcode = 'DKD01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3811 was not found in apply_supplier_credit_note_v1' using errcode = 'P0001';
  end if;
  execute v_def;

  -- create_invoice
  select pg_get_functiondef('public.create_invoice(uuid,uuid,text,uuid,boolean,text,boolean,text,text,text)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'period already invoiced for this member';$r$,
    $r$raise exception 'period already invoiced for this member' using errcode = 'DKI07';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'invoice already replaced';$r$,
    $r$raise exception 'invoice already replaced' using errcode = 'DKI05';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'invoice is matched';$r$,
    $r$raise exception 'invoice is matched' using errcode = 'DKI04';$r$);
  if v_def is null then
    raise exception 'an anchor of #3811 was not found in create_invoice' using errcode = 'P0001';
  end if;
  execute v_def;

  -- match_einvoice
  select pg_get_functiondef('public.match_einvoice(uuid,uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'this invoice was already decided';$r$,
    $r$raise exception 'this invoice was already decided' using errcode = 'DKD01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3811 was not found in match_einvoice' using errcode = 'P0001';
  end if;
  execute v_def;

  -- match_invoice
  select pg_get_functiondef('public.match_invoice(uuid,uuid,text,text,integer)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'invoice is voided';$r$,
    $r$raise exception 'invoice is voided' using errcode = 'DKI03';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'invoice already matched';$r$,
    $r$raise exception 'invoice already matched' using errcode = 'DKI06';$r$);
  if v_def is null then
    raise exception 'an anchor of #3811 was not found in match_invoice' using errcode = 'P0001';
  end if;
  execute v_def;

  -- record_invoice_reminder
  select pg_get_functiondef('public.record_invoice_reminder(uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'invoice is voided';$r$,
    $r$raise exception 'invoice is voided' using errcode = 'DKI03';$r$);
  if v_def is null then
    raise exception 'an anchor of #3811 was not found in record_invoice_reminder' using errcode = 'P0001';
  end if;
  execute v_def;

  -- reject_einvoice
  select pg_get_functiondef('public.reject_einvoice(uuid,text)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'this invoice was already decided';$r$,
    $r$raise exception 'this invoice was already decided' using errcode = 'DKD01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3811 was not found in reject_einvoice' using errcode = 'P0001';
  end if;
  execute v_def;

  -- respond_to_event
  select pg_get_functiondef('public.respond_to_event(uuid,boolean)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'already decided';$r$,
    $r$raise exception 'already decided' using errcode = 'DKD01';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'you already decided this event';$r$,
    $r$raise exception 'you already decided this event' using errcode = 'DKD01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3811 was not found in respond_to_event' using errcode = 'P0001';
  end if;
  execute v_def;

  -- settle_credit_invoice
  select pg_get_functiondef('public.settle_credit_invoice(uuid,text)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'invoice is voided';$r$,
    $r$raise exception 'invoice is voided' using errcode = 'DKI03';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'invoice already matched';$r$,
    $r$raise exception 'invoice already matched' using errcode = 'DKI06';$r$);
  if v_def is null then
    raise exception 'an anchor of #3811 was not found in settle_credit_invoice' using errcode = 'P0001';
  end if;
  execute v_def;

  -- void_invoice
  select pg_get_functiondef('public.void_invoice(uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'invoice is matched';$r$,
    $r$raise exception 'invoice is matched' using errcode = 'DKI04';$r$);
  if v_def is null then
    raise exception 'an anchor of #3811 was not found in void_invoice' using errcode = 'P0001';
  end if;
  execute v_def;
end;
$refusals$;

-- What catches a refusal catches these codes too.
do $handlers$
declare
  v_def text;
begin
  -- create_sample_data
  select pg_get_functiondef('public.create_sample_data(uuid,uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$or sqlstate 'DKK36' then$r$,
    $r$or sqlstate 'DKK36'
      -- #3811: an invoicing refusal carries its code (0740).
      or sqlstate 'DKI01' or sqlstate 'DKI03' or sqlstate 'DKI04' or sqlstate 'DKI05' or sqlstate 'DKI06' or sqlstate 'DKI07' or sqlstate 'DKD01' then$r$);
  if v_def is null then
    raise exception 'an anchor of #3811 was not found in create_sample_data' using errcode = 'P0001';
  end if;
  execute v_def;

  -- join_by_invitation
  select pg_get_functiondef('public.join_by_invitation(text)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$or sqlstate 'DKK36' then$r$,
    $r$or sqlstate 'DKK36'
      -- #3811: an invoicing refusal carries its code (0740).
      or sqlstate 'DKI01' or sqlstate 'DKI03' or sqlstate 'DKI04' or sqlstate 'DKI05' or sqlstate 'DKI06' or sqlstate 'DKI07' or sqlstate 'DKD01' then$r$);
  if v_def is null then
    raise exception 'an anchor of #3811 was not found in join_by_invitation' using errcode = 'P0001';
  end if;
  execute v_def;

  -- mcp_execute_v1
  select pg_get_functiondef('public.mcp_execute_v1(uuid,uuid,text,jsonb,uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$or sqlstate 'DKK36' then$r$,
    $r$or sqlstate 'DKK36'
      -- #3811: an invoicing refusal carries its code (0740).
      or sqlstate 'DKI01' or sqlstate 'DKI03' or sqlstate 'DKI04' or sqlstate 'DKI05' or sqlstate 'DKI06' or sqlstate 'DKI07' or sqlstate 'DKD01' then$r$);
  if v_def is null then
    raise exception 'an anchor of #3811 was not found in mcp_execute_v1' using errcode = 'P0001';
  end if;
  execute v_def;

  -- mcp_read_v1
  select pg_get_functiondef('public.mcp_read_v1(uuid,members,text,jsonb)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$or sqlstate 'DKK36' then$r$,
    $r$or sqlstate 'DKK36'
      -- #3811: an invoicing refusal carries its code (0740).
      or sqlstate 'DKI01' or sqlstate 'DKI03' or sqlstate 'DKI04' or sqlstate 'DKI05' or sqlstate 'DKI06' or sqlstate 'DKI07' or sqlstate 'DKD01' then$r$);
  if v_def is null then
    raise exception 'an anchor of #3811 was not found in mcp_read_v1' using errcode = 'P0001';
  end if;
  execute v_def;

  -- mcp_outcome_of
  select pg_get_functiondef('public.mcp_outcome_of(text,text)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$p_sqlstate = 'P0001' or p_sqlstate like 'DKK%' then$r$,
    $r$p_sqlstate = 'P0001' or p_sqlstate like 'DKK%'
      or p_sqlstate in ('DKI01', 'DKI03', 'DKI04', 'DKI05', 'DKI06', 'DKI07', 'DKD01') then$r$);
  if v_def is null then
    raise exception 'an anchor of #3811 was not found in mcp_outcome_of' using errcode = 'P0001';
  end if;
  execute v_def;
end;
$handlers$;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(740);
