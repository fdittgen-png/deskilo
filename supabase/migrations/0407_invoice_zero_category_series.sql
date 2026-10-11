-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0407 (#2356) — what a 0 % line is, which series a credit note takes,
-- and a rate in force that changes only as a new version.
--
--   * `vat_zero_category(ws, regime, on)`: a 0 % line of a seller outside
--     the scope is O, of an exempt seller E (as before); a VAT-registered
--     seller's is the category of its own 0 % rate in force on the tax
--     point — Z zero-rated, E exempt, O a deposit — when exactly one
--     category answers. Until now every such line was O, and EN 16931's
--     BR-O rules applied to a zero-rated supply. No 0 % rate, or rates of
--     two categories, stays O: the line does not say which rate priced it,
--     so it is not guessed, and issuing refuses it as before (0393,
--     `vat_line_zero_unexplained`).
--   * `create_invoice` draws a credit note (a total below zero, Dart
--     `isCreditNote`) from the `credit_note` series once the owner saved
--     one (numberSequences on); otherwise from `invoice`, as before — art.
--     226(2) allows one sequence, French and German practice expect the
--     configured one. `settle_invoices` takes the same zero category.
--   * `set_vat_rates` refuses a new percent on a saved rate that has been
--     in force while an invoice was issued (`vat_rate_versioned`, DKV01):
--     the change is a new version from a date (Change by law, 0182), and
--     the old version keeps the invoices it is on. A rate no invoice can
--     carry yet is still corrected in place.
--
-- Issued invoices are untouched (`invoices_immutable`).

-- ── the zero category ─────────────────────────────────────────────────
create or replace function public.vat_zero_category(
  p_workspace_id uuid, p_regime text, p_on date
) returns text
language sql stable security definer set search_path = public as $fn$
  select case coalesce(p_regime, 'not_subject')
    when 'exempt' then 'E'
    when 'vat_registered' then coalesce((
      select min(r.category) from public.vat_rates r
       where r.workspace_id = p_workspace_id and r.active and r.percent = 0
         and r.category in ('Z', 'E', 'O')
         and r.valid_from <= p_on and (r.valid_to is null or r.valid_to > p_on)
      having count(distinct r.category) = 1), 'O')
    else 'O' end;
$fn$;
revoke execute on function public.vat_zero_category(uuid, text, date) from public, anon, authenticated;

-- ── a rate in force changes as a new version ──────────────────────────
create or replace function public.set_vat_rates(p_workspace_id uuid, p_rates jsonb)
returns void
language plpgsql security definer set search_path = public as $fn$
declare
  v_rate jsonb;
  v_defaults int := 0;
  v_keep uuid[] := '{}';
  v_id uuid;
  v_super uuid;
  v_old public.vat_rates;
begin
  if not public.has_permission(p_workspace_id, 'manageBilling') then
    raise exception 'not the owner of this workspace';
  end if;
  if p_rates is null or jsonb_typeof(p_rates) <> 'array' then
    raise exception 'rates must be an array';
  end if;
  for v_rate in select * from jsonb_array_elements(p_rates) loop
    if coalesce((v_rate->>'is_default')::boolean, false) then
      v_defaults := v_defaults + 1;
    end if;
  end loop;
  if jsonb_array_length(p_rates) > 0 and v_defaults <> 1 then
    raise exception 'exactly one rate must be the default';
  end if;

  for v_rate in select * from jsonb_array_elements(p_rates) loop
    v_super := null;
    if nullif(v_rate->>'supersedes_id', '') is not null then
      select id into v_super from public.vat_rates
       where id = (v_rate->>'supersedes_id')::uuid and workspace_id = p_workspace_id;
    end if;
    if (v_rate->>'id') is not null and (v_rate->>'id') <> '' then
      v_id := (v_rate->>'id')::uuid;
      -- #2356 — a percent in force while an invoice was issued is history:
      -- the new value is a new version, never an edit of this one.
      select * into v_old from public.vat_rates
       where id = v_id and workspace_id = p_workspace_id;
      if v_old.id is not null
         and v_old.percent <> (v_rate->>'percent')::numeric
         and v_old.valid_from <= current_date
         and exists (select 1 from public.invoices i
                      where i.workspace_id = p_workspace_id
                        and i.issued_at >= v_old.valid_from
                        and (v_old.valid_to is null or i.issued_at < v_old.valid_to)) then
        raise exception 'vat_rate_versioned: % is on issued invoices; change it by law from a date', v_old.label
          using errcode = 'DKV01';
      end if;
      update public.vat_rates
         set label = v_rate->>'label',
             group_key = coalesce(nullif(v_rate->>'group_key', ''), group_key),
             outside_base = coalesce((v_rate->>'outside_base')::boolean, false),
             exemption_reason = left(coalesce(v_rate->>'exemption_reason', ''), 200),
             percent = (v_rate->>'percent')::numeric,
             category = coalesce(v_rate->>'category', 'S'),
             is_default = false,
             active = coalesce((v_rate->>'active')::boolean, true),
             valid_from = coalesce((nullif(v_rate->>'valid_from', ''))::date, valid_from),
             valid_to = (nullif(v_rate->>'valid_to', ''))::date,
             supersedes_id = case when v_rate ? 'supersedes_id' then v_super else supersedes_id end
       where id = v_id and workspace_id = p_workspace_id;
    else
      insert into public.vat_rates
        (workspace_id, label, percent, category, is_default, active, group_key, outside_base, exemption_reason,
         valid_from, valid_to, supersedes_id)
      values (
        p_workspace_id,
        v_rate->>'label',
        (v_rate->>'percent')::numeric,
        coalesce(v_rate->>'category', 'S'),
        false,
        coalesce((v_rate->>'active')::boolean, true),
        coalesce(nullif(v_rate->>'group_key', ''), 'standard'),
        coalesce((v_rate->>'outside_base')::boolean, false),
        left(coalesce(v_rate->>'exemption_reason', ''), 200),
        coalesce((nullif(v_rate->>'valid_from', ''))::date, '1900-01-01'::date),
        (nullif(v_rate->>'valid_to', ''))::date,
        v_super)
      returning id into v_id;
    end if;
    v_keep := v_keep || v_id;
  end loop;

  update public.vat_rates set active = false, is_default = false
   where workspace_id = p_workspace_id and not (id = any(v_keep));

  for v_rate in select * from jsonb_array_elements(p_rates) loop
    if coalesce((v_rate->>'is_default')::boolean, false) then
      update public.vat_rates set is_default = true
       where workspace_id = p_workspace_id
         and (case when (v_rate->>'id') is not null and (v_rate->>'id') <> ''
                   then id = (v_rate->>'id')::uuid
                   else label = v_rate->>'label'
                        and percent = (v_rate->>'percent')::numeric end);
    end if;
  end loop;
end;
$fn$;
revoke execute on function public.set_vat_rates(uuid, jsonb) from public, anon;
grant execute on function public.set_vat_rates(uuid, jsonb) to authenticated;

-- ── anchored patches ──────────────────────────────────────────────────
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

do $migration$
declare
  v_def text;
begin
  select pg_get_functiondef('public.create_invoice(uuid,uuid,text,uuid,boolean,text,boolean,text,text)'::regprocedure)
    into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$  v_zero_category := case coalesce(v_workspace.vat_regime, 'not_subject')
                       when 'exempt' then 'E' else 'O' end;$a$,
    $a$  -- #2356 — a 0 % line is what the seller's own 0 % rate says it is.
  v_zero_category := public.vat_zero_category(
    p_workspace_id, coalesce(v_workspace.vat_regime, 'not_subject'),
    public.vat_tax_point(p_period));$a$);
  if v_def is null then raise exception '0407: create_invoice zero-category anchor missing'; end if;
  v_def := pg_temp.anchor_replace(v_def,
    $a$  v_number := public.next_document_number(p_workspace_id, 'invoice');$a$,
    $a$  -- #2356 — a credit note takes the series the owner set up for it.
  v_number := public.next_document_number(p_workspace_id,
    case when v_total < 0
              and public.feature_effective(p_workspace_id, 'numberSequences')
              and exists (select 1 from public.number_sequences s
                           where s.workspace_id = p_workspace_id
                             and s.journal = 'credit_note')
         then 'credit_note' else 'invoice' end);$a$);
  if v_def is null then raise exception '0407: create_invoice numbering anchor missing'; end if;
  execute v_def;

  select pg_get_functiondef('public.settle_invoices(uuid,uuid,uuid[],text)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$  v_zero_category := case coalesce(v_workspace.vat_regime, 'not_subject') when 'exempt' then 'E' else 'O' end;$a$,
    $a$  v_zero_category := public.vat_zero_category(
    p_workspace_id, coalesce(v_workspace.vat_regime, 'not_subject'), current_date);$a$);
  if v_def is null then raise exception '0407: settle_invoices zero-category anchor missing'; end if;
  execute v_def;
end
$migration$;

select public.set_deskilo_schema_version(407);
