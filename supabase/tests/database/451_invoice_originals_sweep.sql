-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3985 (0799): the sweep of invoice-originals names, as candidates, only the
-- files of that bucket under the invoices' folder pattern, older than the
-- orphan age and named by no column the schema stores a storage path in --
-- one per listed column is kept here -- at most the cap per run, under its
-- lease; it reports unless the operator switched removal on; its record is
-- accepted only from the lease's holder and keeps reason words; nobody but
-- the service role reads or runs it.
begin;
select plan(14);

create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00003985' || lpad(n::text, 4, '0'))::uuid;
$$;
-- An object name under the invoices' pattern: <workspace>/<invoice>/<sha256>.pdf.
create function pg_temp.obj(n int) returns text language sql as $$
  select pg_temp.u(101)::text || '/' || pg_temp.u(500 + n)::text || '/'
         || encode(extensions.digest('file ' || n, 'sha256'), 'hex') || '.pdf';
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values (pg_temp.u(1), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
        'sweep1@example.test', '', now(), now(), now());
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, vat_regime,
                               feature_flags, street, city, postal_code)
values (pg_temp.u(101), 'Sweep 3985', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'not_subject',
        '{"invoicing": true}', '1 rue de la Paix', 'Paris', '75002');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status, joined_at)
values (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active', '2026-01-01');
insert into public.members (id, workspace_id, managed_name, status, subscription_pct, overage_policy, joined_at)
values (pg_temp.u(301), pg_temp.u(101), 'Client', 'active', 100, 'blocked', '2026-01-01');
insert into public.managed_identities (workspace_id, member_id, identity)
values (pg_temp.u(101), pg_temp.u(301),
        public.managed_identity_clean('{"first_name": "Ada", "last_name": "Client", "street": "2 rue du Bac", "city": "Paris", "postal_code": "75007"}'));
delete from public.fee_bands where workspace_id = pg_temp.u(101);
insert into public.fee_bands (workspace_id, from_pct, to_pct, fee_cents, overage_fee_cents)
values (pg_temp.u(101), 0, 100, 3500, 1000);
create function pg_temp.as_owner(p_sql text) returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(1), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  execute p_sql into v;
  execute 'reset role';
  return v;
exception when others then
  execute 'reset role';
  return 'ERR ' || sqlstate;
end $f$;
grant execute on all functions in schema pg_temp to authenticated, anon;
select set_config('t.inv', pg_temp.as_owner(format(
  'select public.create_invoice(%L, %L, %L)::text', pg_temp.u(101), pg_temp.u(301), '2026-09')), true);

-- ── one file named by each listed column ──
insert into public.invoice_originals (invoice_id, workspace_id, path, pdf_bytes, pdf_sha256, xml, xml_sha256)
values (current_setting('t.inv')::uuid, pg_temp.u(101), pg_temp.obj(1), 10, repeat('a', 64), '<x/>', repeat('b', 64));
update public.profiles set avatar_path = pg_temp.obj(2) where id = pg_temp.u(1);
insert into public.conversations (workspace_id, kind, created_by, avatar_path)
values (pg_temp.u(101), 'direct', pg_temp.u(201), pg_temp.obj(3));
insert into public.levels (id, workspace_id, name, background_path) values (pg_temp.u(401), pg_temp.u(101), 'Ground', pg_temp.obj(4));
insert into public.plan_images (workspace_id, level_id, x, y, w, h, storage_path)
values (pg_temp.u(101), pg_temp.u(401), 0, 0, 10, 10, pg_temp.obj(5));
insert into public.tax_exemption_certificates (workspace_id, member_id, kind, state, number, file_path)
values (pg_temp.u(101), pg_temp.u(301), 'resale', 'NY', 'EX-1', pg_temp.obj(6));

-- ── the stored files ──
-- Every other run's state and file is out of the way.
delete from public.maintenance_state where job = 'invoice-originals-sweep';
insert into storage.objects (bucket_id, name, created_at)
select 'invoice-originals', pg_temp.obj(n), now() - interval '3 days' from generate_series(1, 6) n;
insert into storage.objects (bucket_id, name, created_at) values
  ('invoice-originals', pg_temp.obj(7), now() - interval '10 days'),   -- named by none, old: the oldest candidate
  ('invoice-originals', pg_temp.obj(8), now() - interval '1 hour'),    -- named by none, young
  ('avatars', pg_temp.obj(9), now() - interval '10 days'),             -- another bucket
  ('invoice-originals', 'stray/' || pg_temp.obj(10), now() - interval '10 days');  -- another folder
-- Enough unnamed old files for the cap to bind.
insert into storage.objects (bucket_id, name, created_at)
select 'invoice-originals', pg_temp.obj(1000 + n), now() - interval '2 days'
  from generate_series(1, public.invoice_original_sweep_cap() + 5) n;

create temp table claimed as select * from public.invoice_originals_sweep_claim_v1(300);
create temp table names as
  select e ->> 'name' as name from claimed, jsonb_array_elements(candidates) e;

select is((select count(*)::int from claimed), 1, 'the sweep takes its lease');
select is((select mode from claimed), 'report', 'and reports unless removal is switched on');
select is((select count(*)::int from names where name in (select pg_temp.obj(n) from generate_series(1, 6) n)),
  0, 'a file named by any listed column is never a candidate');
select is((select candidates -> 0 ->> 'name' from claimed), pg_temp.obj(7),
  'an old file no column names is a candidate, oldest first');
select is((select count(*)::int from names where name = pg_temp.obj(8)), 0, 'a young one is not');
select is((select count(*)::int from names where name in (pg_temp.obj(9), 'stray/' || pg_temp.obj(10))),
  0, 'nor anything of another bucket or outside the invoices'' folders');
select is((select count(*)::int from names), public.invoice_original_sweep_cap(), 'at most the cap per run');
select is((select count(*)::int from public.invoice_originals_sweep_claim_v1(300)), 0,
  'and one run at a time');

-- ── finish ──
select is(public.maintenance_finish_v1('invoice-originals-sweep', gen_random_uuid(), now(), '{"candidates": 1}', '[]'),
  false, 'a record without the lease is refused');
select is(public.maintenance_finish_v1('invoice-originals-sweep', (select lease_token from claimed), now(),
  '{"candidates": 200, "removed": 0, "note": "text"}',
  jsonb_build_array(jsonb_build_object('item', pg_temp.obj(7), 'reason', 'remove_failed', 'body', 'x'),
                    jsonb_build_object('item', 'y', 'reason', 'A sentence.'))),
  true, 'the holder records its run');
select is((select jsonb_build_array(counts, failures) from public.maintenance_runs where job = 'invoice-originals-sweep'),
  jsonb_build_array('{"candidates": 200, "removed": 0}'::jsonb,
                    jsonb_build_array(jsonb_build_object('item', pg_temp.obj(7), 'reason', 'remove_failed'))),
  'counts are numbers, failures a name and a reason word');

-- ── the switch ──
insert into public.setting_values (scope, key, value) values ('platform', 'records.invoice_originals_sweep', '"remove"');
select is((select mode from public.invoice_originals_sweep_claim_v1(300)), 'remove',
  'removal only once the operator switched it on');

-- ── who reads it ──
select ok(not has_table_privilege('authenticated', 'public.maintenance_runs', 'select')
          and not has_table_privilege('authenticated', 'public.maintenance_state', 'select')
          and not has_function_privilege('authenticated', 'public.invoice_originals_sweep_claim_v1(integer)', 'execute')
          and not has_function_privilege('authenticated', 'public.maintenance_finish_v1(text, uuid, timestamptz, jsonb, jsonb)', 'execute')
          and not has_function_privilege('authenticated', 'public.maintenance_tick(text)', 'execute')
          and not has_function_privilege('authenticated', 'public.storage_path_columns()', 'execute'),
  'no client reads the record or runs the sweep');
select is((select array_agg(table_name || '.' || column_name order by 1) from public.storage_path_columns()),
  array['conversations.avatar_path', 'invoice_originals.path', 'levels.background_path',
        'plan_images.storage_path', 'profiles.avatar_path', 'tax_exemption_certificates.file_path'],
  'the columns that store a storage path, in one list');

select * from finish();
rollback;
