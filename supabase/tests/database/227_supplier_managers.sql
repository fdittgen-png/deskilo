-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2567 / 0484 (C1b): whoever manages the purchases manages the payees, but
-- not where the money goes. Real roles; every refusal is followed by a readback.
begin;
select plan(9);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;
create function pg_temp.as_json(p_user uuid, p_sql text) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform pg_temp.act_as(p_user);
  execute p_sql into v;
  reset role;
  return v;
exception when others then
  reset role;
  return jsonb_build_object('error', sqlerrm);
end;
$$;
create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00002574' || lpad(n::text, 4, '0'))::uuid;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(i), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || i || '@payees.test', '', now(), now(), now()
  from generate_series(1, 3) i;
-- 1 owner (manageBilling), 2 an admin given managePurchases, 3 plain member.
select pg_temp.act_as(pg_temp.u(1));
select set_config('t.a', public.create_workspace('Payees', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"supplyExpenses": true}',
       role_permissions = jsonb_build_object('admin', jsonb_build_array('managePurchases'))
 where id = current_setting('t.a')::uuid;
insert into public.members (workspace_id, user_id, is_owner, is_admin, status, subscription_pct, joined_at) values
 (current_setting('t.a')::uuid, pg_temp.u(2), false, true, 'active', 100, '2026-01-01'),
 (current_setting('t.a')::uuid, pg_temp.u(3), false, false, 'active', 100, '2026-01-01');

create function pg_temp.save(p_user uuid, p_name text) returns jsonb language plpgsql as $$
begin
  return pg_temp.as_json(p_user, format(
    'select to_jsonb(public.save_supplier(%L, null, %L, null, null, ''1 rue du Port'', ''34120'', ''Pézenas'', ''FR'', '''', null))',
    current_setting('t.a'), p_name));
end;
$$;

select ok(not (pg_temp.save(pg_temp.u(2), 'Net & Clair') ? 'error'), 'a member holding managePurchases creates a supplier');
select is((select count(*)::int from public.suppliers where workspace_id = current_setting('t.a')::uuid), 1, 'readback: it exists');
select ok(not (pg_temp.save(pg_temp.u(1), 'Ateliers du Sud') ? 'error'), 'and the owner still does');
select set_config('t.s', (select id::text from public.suppliers where name = 'Net & Clair'), true);
select is(pg_temp.as_json(pg_temp.u(2), format('select to_jsonb(public.set_supplier_bank(%L, ''Net & Clair'', ''FR7630006000011234567890189'', ''''))', current_setting('t.s'))) ->> 'error',
  'the payment destination is changed by whoever manages billing', 'but not the payment destination');
select is((select count(*)::int from public.supplier_bank_revisions where supplier_id = current_setting('t.s')::uuid and revision > 0), 0, 'readback: no bank revision was written');
select ok(not (pg_temp.as_json(pg_temp.u(1), format('select to_jsonb(public.set_supplier_bank(%L, ''Net & Clair'', ''FR7630006000011234567890189'', ''''))', current_setting('t.s'))) ? 'error'),
  'whoever manages billing sets it');
select is(pg_temp.as_json(pg_temp.u(2), format('select to_jsonb((select count(*) from public.suppliers where workspace_id = %L))', current_setting('t.a'))), '2'::jsonb,
  'the purchase manager reads the payees');
select is(pg_temp.as_json(pg_temp.u(2), format('select to_jsonb((select count(*) from public.supplier_bank_revisions where workspace_id = %L))', current_setting('t.a'))), '0'::jsonb,
  'and no bank revision');
select ok(pg_temp.save(pg_temp.u(3), 'Nobody Ltd') ? 'error', 'a plain member creates nothing');

select * from finish();
rollback;
