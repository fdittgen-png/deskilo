-- SPDX-License-Identifier: 0BSD
-- 0172 — #954: one representation of the VAT rate on every invoice line.
--
-- Older snapshots carried the rate three ways — a number, a string, or
-- nothing. Every reader tolerated all three; the exports and the
-- e-invoice are simpler to trust when there is one. From here on
-- create_invoice normalises every line to a numeric vat_percent (0 when
-- the line carried none). Older snapshots stay as issued.
do $patch$
declare v_def text; v_old text;
begin
  select pg_get_functiondef(p.oid) into v_def from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_invoice' and p.prokind='f';
  v_old := E'  v_lines := public.invoice_lines_for(p_member_id, p_period, p_kind);\n';
  if position(v_old in v_def) = 0 then raise exception '0172: anchor missing'; end if;
  v_def := replace(v_def, v_old, v_old
    || E'  -- #954 — one representation of the rate on every line: a number,\n'
    || E'  -- 0 when the line carried none, so every reader and every export\n'
    || E'  -- sees the same thing.\n'
    || E'  select coalesce(jsonb_agg(l || jsonb_build_object(''vat_percent'', coalesce((l->>''vat_percent'')::numeric, 0))), ''[]''::jsonb)\n'
    || E'    into v_lines from jsonb_array_elements(v_lines) l;\n');
  execute v_def;
end
$patch$;
