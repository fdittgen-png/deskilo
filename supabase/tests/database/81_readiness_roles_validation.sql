-- SPDX-License-Identifier: AGPL-3.0-or-later
-- 0294: the readiness checklist names roles and validation, and who acts
-- on every section. A policy nobody can satisfy is named; none at all is
-- not applicable; only a reservation's short policy blocks a first booking.
-- The optional assistant section appears only while mcpAccess is on and
-- names the gate that is missing, never blocking a booking.
begin;
select plan(13);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000000294a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'rv@deskilo.test', '', now(), now(), now());
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000294a1","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.ws', public.create_workspace_once('00000000-0000-4000-8000-00000000c295', 'Roles readiness', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null, null)::text, true);
reset role;
delete from public.validation_policies where workspace_id = current_setting('t.ws')::uuid;

create temp table snap(label text, v jsonb) on commit drop;
grant all on snap to authenticated;
create function pg_temp.read(p_label text) returns void language plpgsql as $$
begin
  set local role authenticated;
  insert into snap values (p_label, public.workspace_readiness(current_setting('t.ws')::uuid));
  reset role;
end $$;
create function pg_temp.rv(p_label text) returns jsonb language sql as $$
  select e from snap, jsonb_array_elements(v) e where label = p_label and e->>'section' = 'roles_validation'
$$;

select pg_temp.read('none');
insert into public.validation_policies (workspace_id, company_id, event_type, required_count)
  select id, company_id, 'expense', 3 from public.workspaces where id = current_setting('t.ws')::uuid;
select pg_temp.read('short_expense');
update public.validation_policies set event_type = 'reservation' where workspace_id = current_setting('t.ws')::uuid;
select pg_temp.read('short_reservation');
update public.validation_policies set required_count = 1 where workspace_id = current_setting('t.ws')::uuid;
select pg_temp.read('satisfied');

-- The assistant: off, then on but not exposed, then exposed to a caller
-- with no identity binding (no database eligibility).
create function pg_temp.asst(p_label text) returns jsonb language sql as $$
  select e from snap, jsonb_array_elements(v) e where label = p_label and e->>'section' = 'assistant'
$$;
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) - 'mcpAccess' || '{"mcpAccess": false}'
 where id = current_setting('t.ws')::uuid;
select pg_temp.read('mcp_off');
update public.workspaces set feature_flags = feature_flags || '{"mcpAccess": true}'
 where id = current_setting('t.ws')::uuid;
select pg_temp.read('mcp_unexposed');
insert into public.workspace_mcp_policies (workspace_id, installation_id, company_id, enabled, operations)
  select id, public.installation_id(), company_id, true, array['list_my_reservations'] from public.workspaces where id = current_setting('t.ws')::uuid;
select pg_temp.read('mcp_exposed');

select is(pg_temp.rv('none')->>'state', 'not_applicable', 'no policy: nothing waits for a validator');
select is(pg_temp.rv('short_expense')->>'state', 'needs_configuration', 'three validators wanted, one owner there');
select is(pg_temp.rv('short_expense')->>'reason', 'too_few_validators', 'and the reason says why');
select is((pg_temp.rv('short_expense')->>'required')::boolean, false, 'a short expense policy does not stop a booking');
select is((pg_temp.rv('short_reservation')->>'required')::boolean, true, 'a short reservation policy does');
select is(pg_temp.rv('satisfied')->>'state', 'ready', 'the owner alone satisfies one validator');
select is((select count(*)::int from snap, jsonb_array_elements(v) e where label = 'none' and e->>'actor' is null),
  0, 'every section names who acts on it');
select is((select e->>'actor' from snap, jsonb_array_elements(v) e where label = 'none' and e->>'section' = 'recovery'),
  'operator', 'recovery is the operator''s to answer');

select is(pg_temp.asst('mcp_off'), null, 'assistant access switched off: no section at all');
select ok(public.feature_effective(current_setting('t.ws')::uuid, 'mcpAccess'), 'the switch took, so the next reads are not vacuous');
select is(pg_temp.asst('mcp_unexposed')->>'reason', 'not_exposed', 'switched on but not exposed: the owner''s step');
select is(pg_temp.asst('mcp_exposed')->>'state' || '/' || (pg_temp.asst('mcp_exposed')->>'actor') || '/' || (pg_temp.asst('mcp_exposed')->>'reason'),
  'needs_operator/administrator/eligibility_no_identity', 'exposed, but this caller holds no eligibility: an administrator''s gate, named');
select is((select bool_or((e->>'required')::boolean) from snap, jsonb_array_elements(v) e where e->>'section' = 'assistant'),
  false, 'assistant access never blocks a first booking');

select * from finish();
rollback;
