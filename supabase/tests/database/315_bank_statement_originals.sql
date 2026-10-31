-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- 0621 (#2380) — the original of an imported bank statement is kept in the
-- private bank-statements bucket at <workspace_id>/<sha256>. Its importer
-- stores it; a member of another workspace neither stores into nor reads
-- it; nobody changes or deletes it; bank_statements_v1 names it.
--
-- Real JWT claims and `set local role authenticated`; as postgres every
-- policy is bypassed. Rows are seeded before the first role switch.
begin;
select plan(7);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_a uuid := '00000000-0000-4000-8000-0000000023a1';
  u_b uuid := '00000000-0000-4000-8000-0000000023b1';
  ws_a uuid; ws_b uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email,
                          encrypted_password, email_confirmed_at,
                          created_at, updated_at)
  values (u_a, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'bank-a@deskilo.test', '', now(), now(), now()),
         (u_b, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'bank-b@deskilo.test', '', now(), now(), now());
  -- The flag and every parent on (moneyTab > invoicing > bankImport).
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Bank A', 'CH', 'CHF', 'Europe/Zurich', u_a,
          '{"moneyTab": true, "invoicing": true, "bankImport": true}'::jsonb) returning id into ws_a;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Bank B', 'CH', 'CHF', 'Europe/Zurich', u_b,
          '{"moneyTab": true, "invoicing": true, "bankImport": true}'::jsonb) returning id into ws_b;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws_a, u_a, true, true), (ws_b, u_b, true, true);
  perform set_config('t.ws_a', ws_a::text, true);
  perform set_config('t.ws_b', ws_b::text, true);
  perform set_config('t.u_a', u_a::text, true);
  perform set_config('t.u_b', u_b::text, true);
end;
$seed$;

select pg_temp.seed();
select ok(exists (select 1 from storage.buckets
                   where id = 'bank-statements' and not public and file_size_limit = 5242880),
  'the private bank-statements bucket exists, at the import size limit');

create or replace function pg_temp.try_insert(p_name text) returns boolean
language plpgsql as $t$
begin
  insert into storage.objects (bucket_id, name) values ('bank-statements', p_name);
  return true;
exception when others then
  return false;
end
$t$;
create or replace function pg_temp.try_update() returns int
language plpgsql as $t$
declare v_n int;
begin
  update storage.objects set name = name where bucket_id = 'bank-statements';
  get diagnostics v_n = row_count;
  return v_n;
end
$t$;
grant execute on all functions in schema pg_temp to authenticated;

-- ── as A ───────────────────────────────────────────────────────────────
select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('t.u_a'), 'role', 'authenticated')::text, true);
set local role authenticated;
select ok(pg_temp.try_insert(current_setting('t.ws_a') || '/' || repeat('a', 64)),
  'the importer keeps an original of its own space');
select ok(not pg_temp.try_insert(current_setting('t.ws_b') || '/' || repeat('a', 64)),
  'and cannot store into another space');
select ok(not pg_temp.try_insert(current_setting('t.ws_a') || '/not-a-digest'),
  'nor under a name that is not <space>/<sha256>');
select is(pg_temp.try_update(), 0,
  'nobody changes an original');
reset role;

-- ── as B ───────────────────────────────────────────────────────────────
select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('t.u_b'), 'role', 'authenticated')::text, true);
set local role authenticated;
select is((select count(*)::int from storage.objects where bucket_id = 'bank-statements'), 0,
  'a member of another space reads none of them');
reset role;

select ok(position('source_sha256' in pg_get_functiondef('public.bank_statements_v1(uuid)'::regprocedure)) > 0,
  'the statements name their original');

select * from finish();
rollback;
