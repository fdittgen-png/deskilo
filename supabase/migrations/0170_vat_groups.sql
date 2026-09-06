-- SPDX-License-Identifier: 0BSD
-- 0170 — #947: VAT groups. An item follows the law of its category.
--
-- vat_rates held a percentage and an EN 16931 category. What the law
-- reasons in is the GROUP a supply belongs to — standard, intermediate,
-- reduced, super-reduced, zero, exempt, not subject — plus two that are
-- not rates at all: a refundable DEPOSIT, outside the VAT base where the
-- law puts it there, and an EXCISE-bearing good (alcohol, sugar drinks)
-- taxed at the standard rate with the excise inside the price. Each rate
-- now carries its group, whether it sits outside the base, and the
-- exemption reason an exempt or not-subject group prints. Existing rows
-- are back-filled from their percentage; set_vat_rates accepts the three
-- new keys and keeps working for a client that sends none.
alter table public.vat_rates
  add column if not exists group_key text not null default 'standard',
  add column if not exists outside_base boolean not null default false,
  add column if not exists exemption_reason text not null default '' ;
alter table public.vat_rates drop constraint if exists vat_rates_group_key_check;
alter table public.vat_rates add constraint vat_rates_group_key_check
  check (group_key in ('standard','intermediate','reduced','super_reduced','zero','exempt','not_subject','deposit','excise'));
update public.vat_rates set group_key = case
    when category = 'E' then 'exempt'
    when category = 'O' then 'not_subject'
    when percent = 0 then 'zero'
    when percent >= 15 then 'standard'
    when percent >= 8 then 'intermediate'
    when percent >= 4 then 'reduced'
    else 'super_reduced' end
  where group_key = 'standard';

do $patch$
declare v_def text; v_old text;
begin
  select pg_get_functiondef(p.oid) into v_def from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='set_vat_rates' and p.prokind='f';
  v_old := E'         set label = v_rate->>''label'',\n';
  if position(v_old in v_def) = 0 then raise exception '0170: anchor A missing'; end if;
  v_def := replace(v_def, v_old, v_old
    || E'             group_key = coalesce(nullif(v_rate->>''group_key'', ''''), group_key),\n'
    || E'             outside_base = coalesce((v_rate->>''outside_base'')::boolean, false),\n'
    || E'             exemption_reason = left(coalesce(v_rate->>''exemption_reason'', ''''), 200),\n');
  v_old := E'        (workspace_id, label, percent, category, is_default, active)\n      values (\n        p_workspace_id,\n        v_rate->>''label'',\n';
  if position(v_old in v_def) = 0 then raise exception '0170: anchor B missing'; end if;
  v_def := replace(v_def, v_old,
       E'        (workspace_id, label, percent, category, is_default, active, group_key, outside_base, exemption_reason)\n      values (\n        p_workspace_id,\n        v_rate->>''label'',\n');
  v_old := E'        coalesce((v_rate->>''active'')::boolean, true))\n      returning id into v_id;\n';
  if position(v_old in v_def) = 0 then raise exception '0170: anchor C missing'; end if;
  v_def := replace(v_def, v_old,
       E'        coalesce((v_rate->>''active'')::boolean, true),\n'
    || E'        coalesce(nullif(v_rate->>''group_key'', ''''), ''standard''),\n'
    || E'        coalesce((v_rate->>''outside_base'')::boolean, false),\n'
    || E'        left(coalesce(v_rate->>''exemption_reason'', ''''), 200))\n      returning id into v_id;\n');
  execute v_def;
end
$patch$;
