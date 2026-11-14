-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3889 (0764): a payment term is the business's own only when somebody wrote
-- it. Saving the reminder rules for another field leaves the term as the
-- platform's default, and an invoice issued afterwards keeps the default
-- term (needs review); changing the term states it. Rolled back.
begin;
select plan(5);

create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00003889' || lpad(n::text, 4, '0'))::uuid;
$$;
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values (pg_temp.u(1), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
        'term@example.test', '', now(), now(), now());
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by)
values (pg_temp.u(101), 'Terms', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1));
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status)
values (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active');
-- The rules as an import or a template leaves them: the term mirrors the
-- platform's default and nobody stated it (the setting is the platform's).
set local session_replication_role = replica;
update public.workspaces
   set dunning_rules = '{"levels": 1, "first_after_days": 14, "between_days": 14, "automatic": false}'
 where id = pg_temp.u(101);
set local session_replication_role = origin;
delete from public.setting_values where workspace_id = pg_temp.u(101) and key = 'dunning.first_after_days';

create function pg_temp.issue(p_number text) returns text language plpgsql as $f$
declare v_id uuid := gen_random_uuid();
begin
  insert into public.invoices (id, workspace_id, member_id, issuer_member_id, number, title, lines, total_cents,
                               currency, member_name, workspace_name, issuer_name, signature, issued_at)
  values (v_id, pg_temp.u(101), pg_temp.u(201), pg_temp.u(201), p_number, 'T', '[]'::jsonb, 1000,
          'EUR', 'A', 'B', 'O', 'sig', now());
  return (select basis || ' ' || terms_days from public.invoice_maturities where invoice_id = v_id);
end
$f$;

select set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(1), 'role', 'authenticated')::text, true);
select lives_ok($$ select public.set_dunning_rules('00000000-0000-4000-8000-000038890101',
  '{"levels": 1, "first_after_days": 14, "between_days": 14, "automatic": true}') $$,
  'the owner saves the rules for another field');
select isnt(public.setting_origin(pg_temp.u(101), 'dunning.first_after_days'), 'workspace',
  'the unchanged term is not stated by that whole write');
select is(pg_temp.issue('T-1'), 'default_term 14',
  'an invoice issued afterwards keeps the default term, which needs review');

select lives_ok($$ select public.set_dunning_rules('00000000-0000-4000-8000-000038890101',
  '{"levels": 1, "first_after_days": 20, "between_days": 14, "automatic": true}') $$,
  'the owner changes the term');
select is(pg_temp.issue('T-2'), 'document_term 20', 'a changed term is the business''s own');

select * from finish();
rollback;
