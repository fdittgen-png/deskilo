-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #1655 — a template can be inspected field by field, by whoever may
-- read it and by nobody else, and the inspection never writes and never
-- shows what a template must not carry.
--
-- Readability is `workspace_template_readable`, proved here for every
-- shape: a builtin for anyone signed in, a private template for its
-- owner and not for a stranger nor a plain member of the owning space, a
-- shared one for the address invited and not after the grant is revoked,
-- a public one for everyone, and nobody at all for anon. Then the
-- inspection itself: the builtins pass the registry with no unknown
-- field (the registry is complete about what ships); an unknown key,
-- a duplicate natural key and a value the publication rules deny are
-- rejected, and the denied value does not appear in the answer; a
-- newer schema is reported unsupported, never coerced; a reference the
-- template cannot resolve becomes a required input; and the function is
-- declared stable, so it cannot write.
begin;
select plan(28);

create or replace function pg_temp.act_as(p_user uuid) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  execute 'set local role authenticated';
end
$act$;

create or replace function pg_temp.inspect(p_key text, p_owner uuid) returns jsonb language sql as $$
  select public.inspect_workspace_template((select id from public.workspace_templates
    where key = p_key and owner_workspace_id is not distinct from p_owner));
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
values ('00000000-0000-4000-8000-0000000016a1', '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated', 'inspect-owner@deskilo.test', '', now(), now(), now()),
       ('00000000-0000-4000-8000-0000000016a2', '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated', 'inspect-stranger@deskilo.test', '', now(), now(), now()),
       ('00000000-0000-4000-8000-0000000016a3', '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated', 'inspect-member@deskilo.test', '', now(), now(), now());
insert into public.profiles (id, email) values
  ('00000000-0000-4000-8000-0000000016a2', 'inspect-stranger@deskilo.test')
on conflict (id) do update set email = excluded.email;

-- ── the builtins pass the registry ─────────────────────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000000016a1');
select is(pg_temp.inspect('tiny', null)->>'status', 'ok', 'the tiny builtin inspects');
select is(pg_temp.inspect('tiny', null)->>'profile', 'legacy', 'a floor-plan-only template is legacy');
select is(pg_temp.inspect('association_fr', null)->>'status', 'ok',
  'the association builtin carries no field the registry does not know');
select is(pg_temp.inspect('association_fr', null)->>'profile', 'partial',
  'a builtin that declares some entities is a partial overlay');
select is((pg_temp.inspect('association_fr', null)->'coverage'->>'unknown')::int, 0,
  'no unknown field in the association builtin');
select matches(pg_temp.inspect('association_fr', null)->>'digest', '^[0-9a-f]{32}$', 'the digest is an md5');
select is(pg_temp.inspect('association_fr', null)->'outline',
  public.template_outline((select id from public.workspace_templates where key = 'association_fr' and owner_workspace_id is null))->'groups',
  'the outline inside the inspection is the outline');
select ok(pg_temp.inspect('association_fr', null)->'required_inputs' @> '[{"id": "workspace.name"}]'::jsonb,
  'the new space''s name is a required local input');
select ok(pg_temp.inspect('association_fr', null)->'fields' @>
  '[{"id": "workspace.booking_rules.simultaneous_reservations", "disposition": "absent", "absent": "product_default"}]'::jsonb,
  'an absent rule says it falls back to the product default');
select ok(pg_temp.inspect('association_fr', null)->'fields' @>
  '[{"id": "workspace.feature_flags.carnets", "disposition": "present", "value": true}]'::jsonb,
  'a present flag is reported with its value');

-- ── a private template, its owner, a stranger, a member ────────────────
select set_config('deskilo.insp.ws',
  public.create_workspace('Inspected', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
update public.workspaces set booking_rules = '{"granularity":"half_day","simultaneous_reservations":2}'
 where id = current_setting('deskilo.insp.ws')::uuid;
insert into public.members (workspace_id, user_id, is_owner, is_admin)
values (current_setting('deskilo.insp.ws')::uuid, '00000000-0000-4000-8000-0000000016a3', false, false);
select pg_temp.act_as('00000000-0000-4000-8000-0000000016a1');
select set_config('deskilo.insp.tpl', public.save_workspace_as_template(
  current_setting('deskilo.insp.ws')::uuid, 'inspected', 'Inspected', '', 'private', '{}',
  array['hours_booking'])::text, true);

select is(public.inspect_workspace_template(current_setting('deskilo.insp.tpl')::uuid)->>'status', 'ok',
  'the owner inspects a private template');
select ok(public.inspect_workspace_template(current_setting('deskilo.insp.tpl')::uuid)->'fields' @>
  '[{"path": "workspace.booking_rules.simultaneous_reservations", "value": 2, "disposition": "present"}]'::jsonb,
  'a saved rule is reported present with its value');

select pg_temp.act_as('00000000-0000-4000-8000-0000000016a2');
select throws_ok(
  $$ select public.inspect_workspace_template(current_setting('deskilo.insp.tpl')::uuid) $$,
  'unknown template', 'a stranger cannot inspect a private template');
select pg_temp.act_as('00000000-0000-4000-8000-0000000016a3');
select throws_ok(
  $$ select public.inspect_workspace_template(current_setting('deskilo.insp.tpl')::uuid) $$,
  'unknown template', 'a plain member of the owning space cannot inspect it either');

-- ── shared, then revoked; public ───────────────────────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000000016a1');
select public.set_workspace_template_visibility(current_setting('deskilo.insp.tpl')::uuid, 'shared');
select public.grant_workspace_template(current_setting('deskilo.insp.tpl')::uuid, 'inspect-stranger@deskilo.test');
select pg_temp.act_as('00000000-0000-4000-8000-0000000016a2');
select is(public.inspect_workspace_template(current_setting('deskilo.insp.tpl')::uuid)->>'status', 'ok',
  'the invited address inspects a shared template');
select pg_temp.act_as('00000000-0000-4000-8000-0000000016a1');
select public.revoke_workspace_template_grant(current_setting('deskilo.insp.tpl')::uuid, 'inspect-stranger@deskilo.test');
select pg_temp.act_as('00000000-0000-4000-8000-0000000016a2');
select throws_ok(
  $$ select public.inspect_workspace_template(current_setting('deskilo.insp.tpl')::uuid) $$,
  'unknown template', 'a revoked share is unknown again');
select pg_temp.act_as('00000000-0000-4000-8000-0000000016a1');
select public.set_workspace_template_visibility(current_setting('deskilo.insp.tpl')::uuid, 'public');
select pg_temp.act_as('00000000-0000-4000-8000-0000000016a2');
select is(public.inspect_workspace_template(current_setting('deskilo.insp.tpl')::uuid)->>'status', 'ok',
  'anyone signed in inspects a public template');

-- ── anon ───────────────────────────────────────────────────────────────
reset role;
select ok(not has_function_privilege('anon', 'public.inspect_workspace_template(uuid)', 'execute'),
  'anon cannot execute the inspection');
select set_config('request.jwt.claims', '', true);
select set_config('request.jwt.claim.sub', '', true);
select throws_ok(
  $$ select public.inspect_workspace_template(current_setting('deskilo.insp.tpl')::uuid) $$,
  'not authenticated', 'without a session even a public template is refused');

-- ── the payload is held to the registry ────────────────────────────────
update public.workspace_templates
   set configuration = configuration || '{"workspace": {"booking_rules": {"granularity": "half_day"}, "nonsense": 1}}'::jsonb
 where id = current_setting('deskilo.insp.tpl')::uuid;
select pg_temp.act_as('00000000-0000-4000-8000-0000000016a1');
select is(public.inspect_workspace_template(current_setting('deskilo.insp.tpl')::uuid)->>'status', 'rejected',
  'an unknown key rejects the template');
select ok(public.inspect_workspace_template(current_setting('deskilo.insp.tpl')::uuid)->'problems' @>
  '[{"path": "workspace.nonsense", "problem": "unknown_field"}]'::jsonb,
  'and names the key');

reset role;
update public.workspace_templates
   set configuration = '{"workspace": {"payment_instructions": {"iban": "FR76SECRETIBAN"}}, "tables": {}}'::jsonb
 where id = current_setting('deskilo.insp.tpl')::uuid;
select pg_temp.act_as('00000000-0000-4000-8000-0000000016a1');
select is(public.inspect_workspace_template(current_setting('deskilo.insp.tpl')::uuid)->>'status', 'rejected',
  'a value the publication rules deny rejects the template');
select is(public.inspect_workspace_template(current_setting('deskilo.insp.tpl')::uuid)::text ~ 'SECRETIBAN', false,
  'and the denied value is not in the answer');

reset role;
update public.workspace_templates
   set configuration = '{"workspace": {}, "tables": {"fee_bands": [{"from_pct": 0, "to_pct": 50, "fee_cents": 1}, {"from_pct": 0, "to_pct": 100, "fee_cents": 2}]}}'::jsonb,
       entities = array['tariffs']
 where id = current_setting('deskilo.insp.tpl')::uuid;
select pg_temp.act_as('00000000-0000-4000-8000-0000000016a1');
select ok(public.inspect_workspace_template(current_setting('deskilo.insp.tpl')::uuid)->'problems' @>
  '[{"problem": "duplicate_key"}]'::jsonb,
  'two rows with the same natural key are a duplicate');

reset role;
update public.workspace_templates
   set configuration = '{"workspace": {}, "tables": {"services": [{"name": "Coffee", "price_cents": 100, "active": true, "vat_rate": "Ghost"}]}}'::jsonb,
       entities = array['services']
 where id = current_setting('deskilo.insp.tpl')::uuid;
select pg_temp.act_as('00000000-0000-4000-8000-0000000016a1');
select ok(public.inspect_workspace_template(current_setting('deskilo.insp.tpl')::uuid)->'required_inputs' @>
  '[{"path": "tables.services[Coffee].vat_rate", "binding": "vat_rates.label"}]'::jsonb,
  'a VAT label the template does not define is a required input');

reset role;
update public.workspace_templates set schema_version = 999
 where id = current_setting('deskilo.insp.tpl')::uuid;
select pg_temp.act_as('00000000-0000-4000-8000-0000000016a1');
select is(public.inspect_workspace_template(current_setting('deskilo.insp.tpl')::uuid)->>'status', 'unsupported_version',
  'a newer schema is unsupported, never coerced');
select is(jsonb_array_length(public.inspect_workspace_template(current_setting('deskilo.insp.tpl')::uuid)->'fields'), 0,
  'and yields no usable field');

-- ── never writes ───────────────────────────────────────────────────────
reset role;
select is((select provolatile from pg_proc where oid = 'public.inspect_workspace_template(uuid)'::regprocedure), 's',
  'the inspection is declared stable: it cannot write');

select * from finish();
rollback;
