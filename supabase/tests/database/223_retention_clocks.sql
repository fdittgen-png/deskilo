-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2571 / 0480: retention is reference data. The shape is validated, the clock
-- runs from the fiscal-year end or the document date, an unknown country falls
-- back to the `*` rule, and only a member of the space reads it.
-- Expected dates are written by hand from the statute rows.
begin;
select plan(14);

select ok(public.tax_reference_valid('retention', '{"years":6,"from":"fiscal_year_end"}'), 'a rule with years and a start is valid');
select ok(not public.tax_reference_valid('retention', '{"years":0,"from":"fiscal_year_end"}'), 'zero years is not a rule');
select ok(not public.tax_reference_valid('retention', '{"years":6,"from":"whenever"}'), 'an unknown start is not valid');
select ok(not public.tax_reference_valid('retention', '{"years":6.5,"from":"document_date"}'), 'a fraction of a year is not valid');
select ok(not public.tax_reference_valid('retention', '{"years":6,"from":"document_date","x":1}'), 'an extra key is not valid');

select is((select count(*)::int from public.tax_reference where domain = 'retention' and country = '*'), 4,
  'the default country has the four classes');
select is((select count(*)::int from public.tax_reference where domain = 'retention' and confirmed), 0,
  'every value arrives unconfirmed');

select is(public.retention_rule_of('gb', 'invoice') ->> 'years', '6', 'GB keeps invoices 6 years');
select is(public.retention_rule_of('DE', 'books') ->> 'years', '10', 'DE keeps books 10 years');
select is(public.retention_rule_of('DE', 'invoice') ->> 'years', '8', 'DE keeps invoices 8 years');
select is(public.retention_rule_of('ZZ', 'correspondence') ->> 'country', '*', 'a country without a row takes the default');
select is(public.retention_rule_of('GB', 'nope'), null, 'a class nobody listed has no rule');

-- the clock, as a signed-in member of a space
create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;
do $$
declare v_ws uuid; v_user uuid;
begin
  select m.workspace_id, m.user_id into v_ws, v_user from public.members m
   where m.status = 'active' order by m.id limit 1;
  perform set_config('t.ws', v_ws::text, true);
  perform set_config('t.user', v_user::text, true);
end $$;

select pg_temp.act_as(current_setting('t.user')::uuid);
select ok(public.retention_until(current_setting('t.ws')::uuid, 'invoice', date '2020-06-01') is not null,
  'a member reads the day an invoice may go');
reset role;

select pg_temp.act_as('00000000-0000-4000-8000-000000000001');
select throws_ok(format('select public.retention_until(%L, ''invoice'', date ''2020-06-01'')', current_setting('t.ws')),
  null, null, 'a stranger reads nothing');
reset role;

select * from finish();
rollback;
