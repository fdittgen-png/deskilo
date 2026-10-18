-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0483 (#2574) -- the maker-checker policy of supplier bills and payments is
-- two settings of the space (manageBilling), with today's behaviour as the
-- default:
--
--   purchase.single_approval_below_units   0..100 000 currency units, default 0
--       a bill whose gross is BELOW this amount may be approved by the person
--       who drafted or sent it, provided they hold approveExpenses. 0 keeps
--       the rule of 0468: another person approves every bill. Rejecting a bill
--       one submitted always takes another person.
--   purchase.payment_checker_from_units    0..100 000 000 currency units, default 0
--       a payment of at least this amount cannot be recorded by the person who
--       approved the bill it pays. 0 switches the rule off (today's behaviour).
--
-- Anchored patches of decide_purchase_v1 and record_supplier_payment_v1, each
-- anchor asserted to occur exactly once.

-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('purchase.single_approval_below_units', 'int', '0'::jsonb, 0, 100000, 'currency units', 'billing', array['workspace'], 'manageBilling', null, true, null, 'decide_purchase_v1 (0468)', 'A supplier bill below this amount, in whole currency units, may be approved by the person who drafted or sent it, if that person may approve expenses. 0 keeps the rule that another person approves every bill. Rejecting always takes another person.'),
('purchase.payment_checker_from_units', 'int', '0'::jsonb, 0, 100000000, 'currency units', 'billing', array['workspace'], 'manageBilling', null, true, null, 'record_supplier_payment_v1 (0468)', 'A payment of at least this amount, in whole currency units, cannot be recorded by the person who approved the bill it pays. 0 switches the rule off.')
on conflict (key) do nothing;
-- END GENERATED SEED

create or replace function pg_temp.patch_function(p_proc regprocedure, p_old text[], p_new text[])
returns void
language plpgsql
as $f$
declare
  v_def text := pg_get_functiondef(p_proc);
  i int;
begin
  for i in 1 .. cardinality(p_old) loop
    if (length(v_def) - length(replace(v_def, p_old[i], ''))) <> length(p_old[i]) then
      raise exception '0483: anchor % is not present exactly once in %', i, p_proc;
    end if;
    v_def := replace(v_def, p_old[i], p_new[i]);
  end loop;
  execute v_def;
end
$f$;
revoke execute on function pg_temp.patch_function(regprocedure, text[], text[]) from public, anon;

select pg_temp.patch_function(
  'public.decide_purchase_v1(uuid, uuid, int, boolean, text, uuid)'::regprocedure,
  array[$a$  if d.submitter_member_id = v_me or d.submitted_by_member_id = v_me then$a$],
  array[$a$  if (d.submitter_member_id = v_me or d.submitted_by_member_id = v_me)
     and not (coalesce(p_approve, false)
              and (select coalesce(sum(l.gross_cents), 0) from public.purchase_lines l where l.purchase_id = d.id)
                  < (public.setting_value(p_workspace_id, 'purchase.single_approval_below_units') #>> '{}')::bigint * 100) then$a$]);

select pg_temp.patch_function(
  'public.record_supplier_payment_v1(uuid, uuid, bigint, int, uuid, date, text, text)'::regprocedure,
  array[$a$  if o.state <> 'open' then raise exception 'this payable is not open'; end if;$a$],
  array[$a$  if o.state <> 'open' then raise exception 'this payable is not open'; end if;
  if (public.setting_value(p_workspace_id, 'purchase.payment_checker_from_units') #>> '{}')::bigint > 0
     and p_amount_cents >= (public.setting_value(p_workspace_id, 'purchase.payment_checker_from_units') #>> '{}')::bigint * 100
     and exists (select 1 from public.purchase_documents pd
                  where pd.id = o.purchase_id and pd.decided_by_member_id = v_me) then
    raise exception 'another person than the approver records a payment of this size';
  end if;$a$]);

select public.set_deskilo_schema_version(483);
