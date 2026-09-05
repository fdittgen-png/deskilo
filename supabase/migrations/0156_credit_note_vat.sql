-- SPDX-License-Identifier: 0BSD
-- 0156 — #894: a reversal carries the VAT it gives back.
--
-- The breakdown counted CHARGES only (`amount_cents > 0`), and a credit
-- was stamped 0 % because a credit is money moving, not a supply. True
-- of a payment; false of a document that CANCELS a VAT-bearing charge:
-- art. 219 of the VAT Directive wants the reversing document to state
-- the tax it reverses. From here a credit may name the rate it gives
-- back, that rate reaches the invoice line, and a line that names a rate
-- counts in the breakdown even when it is negative — so the VAT of an
-- avoir is negative per rate and the declaration nets out.
-- Harness-verified 2026-09-05 (charge 120,00 @20 % + avoir 20,00 @20 %
-- + payment 50,00 → one 20 % entry: gross 100,00, net 83,33, VAT 16,67).
do $patch$
declare v_def text; v_anchor text;
begin
  -- 1. A credit keeps the rate it was stamped with; a payment has none
  --    and stays at 0 %.
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname='public' and p.proname='invoice_lines_for'
     and pg_get_function_identity_arguments(p.oid) = 'p_member_id uuid, p_period text';
  if v_def is null then raise exception '0156: invoice_lines_for not found'; end if;
  v_anchor := E'      ''vat_percent'', case when v_row.kind = ''credit'' then 0\n';
  if position(v_anchor in v_def) = 0 then raise exception '0156: anchor A missing'; end if;
  v_def := replace(v_def, v_anchor,
    E'      ''vat_percent'', case when v_row.kind = ''credit''\n'
 || E'                          then coalesce(v_row.vat_percent, 0)\n');
  execute v_def;

  -- 2. A line that NAMES a rate counts even when negative. A payment
  --    (0 %, negative) still never reaches the breakdown.
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname='public' and p.proname='create_invoice';
  v_anchor := E'     where (l->>''amount_cents'')::int > 0\n';
  if position(v_anchor in v_def) = 0 then raise exception '0156: anchor B missing'; end if;
  v_def := replace(v_def, v_anchor,
    E'     where (l->>''amount_cents'')::int > 0\n'
 || E'        or coalesce((l->>''vat_percent'')::numeric, 0) > 0\n');
  execute v_def;

  -- 3. A distributed expense stamps the workspace's rate on BOTH sides,
  --    so a reversal (#828) gives back the tax it charged.
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname='public' and p.proname='apply_expense_repartition';
  v_anchor := E'      (workspace_id, member_id, kind, category, amount_cents, description,\n       period, event_id)\n';
  if position(v_anchor in v_def) = 0 then raise exception '0156: anchor C missing'; end if;
  v_def := replace(v_def, v_anchor,
    E'      (workspace_id, member_id, kind, category, amount_cents, description,\n       period, event_id, vat_percent)\n');
  v_anchor := E'       v_r.event_id);\n';
  if position(v_anchor in v_def) = 0 then raise exception '0156: anchor D missing'; end if;
  v_def := replace(v_def, v_anchor,
    E'       v_r.event_id,\n'
 || E'       public.workspace_default_vat_percent(v_r.workspace_id));\n');
  execute v_def;
end
$patch$;
