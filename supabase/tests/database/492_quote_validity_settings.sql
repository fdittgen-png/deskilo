-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4291 (0844): how long a quote stays valid is the business's own setting. A
-- business that never set it keeps today's 30 days by default and refuses more
-- than 365; one that set 14 and 60 gets a draft ending in 14 days when no end is
-- stated, accepts 60 and refuses 61; a default beyond the longest validity is the
-- longest; another business is not affected.
begin;
select plan(8);

create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00004291' || lpad(n::text, 4, '0'))::uuid;
$$;
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'validity' || n || '@example.test', '', now(), now(), now() from generate_series(1, 2) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags,
                               vat_regime, vat_id, legal_id, street, city, postal_code, address)
values (pg_temp.u(101), 'Validity A', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"invoicing": true, "standaloneInvoicing": true, "customerQuotes": true}',
        'vat_registered', 'FR40303265045', '30326504500014', '4 avenue de Castelnau', 'Pézenas', '34120', '4 avenue de Castelnau, 34120 Pézenas'),
       (pg_temp.u(102), 'Validity B', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(2), '{"invoicing": true, "standaloneInvoicing": true, "customerQuotes": true}',
        'vat_registered', 'FR40303265045', '30326504500014', '4 avenue de Castelnau', 'Pézenas', '34120', '4 avenue de Castelnau, 34120 Pézenas');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status, joined_at)
values (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active', '2026-01-01'),
       (pg_temp.u(202), pg_temp.u(102), pg_temp.u(2), true, true, 'active', '2026-01-01');
insert into public.vat_rates (id, workspace_id, label, percent, category, is_default, active, valid_from)
values (pg_temp.u(301), pg_temp.u(101), 'Normal 20 %', 20, 'S', true, true, '2000-01-01'),
       (pg_temp.u(302), pg_temp.u(102), 'Normal 20 %', 20, 'S', true, true, '2000-01-01')
on conflict do nothing;

create function pg_temp.as_user(n int, p_sql text) returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(n), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  execute p_sql into v;
  execute 'reset role';
  return coalesce(nullif(v, ''), 'ok');
exception when others then
  execute 'reset role';
  return 'ERR ' || sqlstate;
end $f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- a customer for each business, and a draft that states its end or does not
select set_config('t.cust_a', pg_temp.as_user(1, format(
  $s$select public.billing_customer_create_v1(%L, '{"company": "Atelier A", "street": "1 rue du Port", "postal_code": "34120", "city": "Pezenas", "country_code": "FR", "vat_id": "FR12345678901"}'::jsonb, 'business')::text$s$,
  pg_temp.u(101))), false);
select set_config('t.cust_b', pg_temp.as_user(2, format(
  $s$select public.billing_customer_create_v1(%L, '{"company": "Atelier B", "street": "1 rue du Port", "postal_code": "34120", "city": "Pezenas", "country_code": "FR", "vat_id": "FR12345678901"}'::jsonb, 'business')::text$s$,
  pg_temp.u(102))), false);
create function pg_temp.draft(p_user int, p_ws uuid, p_customer text, p_until text) returns text language sql as $$
  select pg_temp.as_user(p_user, format(
    $s$select (public.save_customer_quote_draft_v1(%L, null, null, %L, date '2026-03-01', %s, '', '', '', %L::jsonb)->>'quote_id')$s$,
    p_ws, p_customer, coalesce(quote_nullable(p_until), 'null'),
    '[{"description": "Consulting", "quantity": "1", "unit_price": "100", "basis": "net", "supply": "general", "base_quantity": "1", "unit": {"code": "hour", "label": "h", "un_ece_code": "HUR"}}]'))
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.ends(p_quote text) returns date language sql as $$
  select valid_until from public.customer_quote_revisions where quote_id = p_quote::uuid
$$;

-- a business that never set it: today's 30 and 365
select set_config('t.q1', pg_temp.draft(1, pg_temp.u(101), current_setting('t.cust_a'), null), false);
select is(pg_temp.ends(current_setting('t.q1')), date '2026-03-31', 'no setting: a draft with no end is valid 30 days');
select ok(pg_temp.draft(1, pg_temp.u(101), current_setting('t.cust_a'), '2027-03-01') ~ '^[0-9a-f-]{36}$', 'no setting: 365 days is accepted');
select is(pg_temp.draft(1, pg_temp.u(101), current_setting('t.cust_a'), '2027-03-02'), 'ERR DKQ06', 'no setting: 366 days is refused');

-- the business sets 14 and 60
insert into public.setting_values (scope, workspace_id, key, value, note) values
  ('workspace', pg_temp.u(101), 'quotes.default_validity_days', '14'::jsonb, 'short offers'),
  ('workspace', pg_temp.u(101), 'quotes.max_validity_days', '60'::jsonb, 'never long');
select set_config('t.q2', pg_temp.draft(1, pg_temp.u(101), current_setting('t.cust_a'), null), false);
select is(pg_temp.ends(current_setting('t.q2')), date '2026-03-15', 'set to 14: a draft with no end is valid 14 days');
select ok(pg_temp.draft(1, pg_temp.u(101), current_setting('t.cust_a'), '2026-04-30') ~ '^[0-9a-f-]{36}$', 'set to 60: 60 days is accepted');
select is(pg_temp.draft(1, pg_temp.u(101), current_setting('t.cust_a'), '2026-05-01'), 'ERR DKQ06', 'set to 60: 61 days is refused');

-- a default beyond the longest is the longest
update public.setting_values set value = '90'::jsonb where workspace_id = pg_temp.u(101) and key = 'quotes.default_validity_days';
select set_config('t.q3', pg_temp.draft(1, pg_temp.u(101), current_setting('t.cust_a'), null), false);
select is(pg_temp.ends(current_setting('t.q3')), date '2026-04-30', 'a default of 90 beyond a longest of 60 is 60');

-- another business is not affected
select set_config('t.q4', pg_temp.draft(2, pg_temp.u(102), current_setting('t.cust_b'), null), false);
select is(pg_temp.ends(current_setting('t.q4')), date '2026-03-31', 'another business keeps its own: 30 days');

select * from finish();
rollback;
