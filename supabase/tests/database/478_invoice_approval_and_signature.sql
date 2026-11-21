-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4262 + #4261 (0822): every issuing command applies the invoice-approval
-- policy (no invoice, no number), the approval's own application and the dry
-- runs still work, a policy below its threshold changes nothing; and an
-- invoice's signature covers the address it stores, so an untouched invoice of
-- a site other than the default one verifies, and altering its stored address
-- is detected.
begin;
select plan(15);

create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00004262' || lpad(n::text, 4, '0'))::uuid;
$$;
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'ap' || n || '@example.test', '', now(), now(), now() from generate_series(1, 3) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags,
                               vat_regime, vat_id, legal_id, street, city, postal_code, address)
values (pg_temp.u(101), 'Approval 4262', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"invoicing": true}',
        'vat_registered', 'FR40303265045', '30326504500014', '4 avenue de Castelnau', 'Pézenas', '34120',
        '4 avenue de Castelnau, 34120 Pézenas');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status, joined_at)
values (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active', '2026-01-01'),
       (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active', '2026-01-01'),
       (pg_temp.u(203), pg_temp.u(101), pg_temp.u(3), false, false, 'active', '2026-01-01');
update public.profiles set display_name = 'Ana Martin', company = 'Martin SAS', street = '1 rue X',
       postal_code = '75001', city = 'Paris', country_code = 'FR', legal_id = '12345678900012'
 where id = pg_temp.u(3);
insert into public.vat_rates (id, workspace_id, label, percent, category, is_default, active, valid_from)
values (pg_temp.u(301), pg_temp.u(101), 'Normal 20 %', 20, 'S', true, true, '2000-01-01')
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
  return 'ERR ' || sqlstate || ' ' || coalesce(nullif(substr(sqlerrm, 1, 50), ''), '');
end $f$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.invoices() returns int language sql as $$
  select count(*)::int from public.invoices where workspace_id = pg_temp.u(101)
$$;
create function pg_temp.next_number() returns text language sql as $$
  select coalesce((select next_value::text from public.number_sequences
                    where workspace_id = pg_temp.u(101) and journal = 'invoice'), '-')
$$;

-- ── #4261: a site's invoice verifies ──
insert into public.sites (id, workspace_id, name, street, postal_code, city, country_code, is_default)
values (pg_temp.u(401), pg_temp.u(101), 'Annex', '9 rue du Site', '34500', 'Béziers', 'FR', false);
update public.members set home_site_id = pg_temp.u(401) where id = pg_temp.u(203);
select set_config('i.site', pg_temp.as_user(1, format($$select public.create_invoice(%L, %L, '2026-09', null, false, 'full', true)::text$$,
  pg_temp.u(101), pg_temp.u(203))), false);
select ok(current_setting('i.site') ~ '^[0-9a-f-]{36}$', 'an invoice of a site is issued: ' || current_setting('i.site'));
select is((select workspace_address from public.invoices where id = current_setting('i.site')::uuid),
  '9 rue du Site, 34500 Béziers', 'it stores the site''s address');
select is(pg_temp.as_user(1, format($$select public.verify_invoice_signature(%L)$$, current_setting('i.site'))),
  'verified', 'and verifies as unchanged');
set local session_replication_role = replica;
update public.invoices set workspace_address = '1 rue Falsifiée' where id = current_setting('i.site')::uuid;
set local session_replication_role = origin;
select is(pg_temp.as_user(1, format($$select public.verify_invoice_signature(%L)$$, current_setting('i.site'))),
  'altered', 'altering the stored address is detected');
update public.members set home_site_id = null where id = pg_temp.u(203);
select set_config('i.def', pg_temp.as_user(1, format($$select public.create_invoice(%L, %L, '2026-08', null, false, 'full', true)::text$$,
  pg_temp.u(101), pg_temp.u(203))), false);
select is(pg_temp.as_user(1, format($$select public.verify_invoice_signature(%L)$$, current_setting('i.def'))),
  'verified', 'an invoice of the default address verifies, as before');

-- ── #4262: the policy applies to every issuing command ──
insert into public.validation_policies (workspace_id, event_type, min_amount_cents)
values (pg_temp.u(101), 'invoice_issue', 0);
select set_config('n.before', pg_temp.invoices()::text || '|' || pg_temp.next_number(), false);
select ok(pg_temp.as_user(1, format($$select public.create_invoice(%L, %L, '2026-07', null, false, 'full', true)::text$$,
  pg_temp.u(101), pg_temp.u(203))) like 'ERR DKI01%', 'a direct create_invoice is refused while the policy requires approval');
select ok(pg_temp.as_user(1, format($$select public.create_invoice_receipted_v1(%L, %L, '2026-07', %L)::text$$,
  pg_temp.u(101), pg_temp.u(203), pg_temp.u(901))) like 'ERR DKI01%', 'the wizard''s receipted issue is refused');
select ok(pg_temp.as_user(1, format($$select public.create_invoice_replacement_v1(%L, %L, '2026-08', %L, %L)::text$$,
  pg_temp.u(101), pg_temp.u(203), current_setting('i.def'), pg_temp.u(902))) like 'ERR DKI01%', 'a replacement is refused');
select is((select voided_at is null from public.invoices where id = current_setting('i.def')::uuid), true,
  'and the invoice it would replace is not voided');
create function pg_temp.draft() returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(1), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  v := public.save_standalone_invoice_draft_v1(pg_temp.u(101), null, null, pg_temp.u(203), current_date, current_date + 30, '', '',
         jsonb_build_array(jsonb_build_object('description', 'x', 'quantity', '1', 'unit_price', '10', 'basis', 'net',
           'supply', 'general', 'base_quantity', '1',
           'unit', jsonb_build_object('code', 'hour', 'label', 'h', 'un_ece_code', 'HUR')))) ->> 'draft_id';
  execute 'reset role';
  return v;
end $f$;
grant execute on all functions in schema pg_temp to authenticated, anon;
select set_config('d.a', pg_temp.draft(), false);
select ok(pg_temp.as_user(1, format($$select public.issue_standalone_invoice_v1(%L, %L, 1, %L)::text$$,
  pg_temp.u(101), current_setting('d.a'), pg_temp.u(903))) like 'ERR DKI01%', 'a standalone issue is refused');
select is(pg_temp.invoices()::text || '|' || pg_temp.next_number(), current_setting('n.before'),
  'none of them made an invoice or took a number');
select is((pg_temp.as_user(1, format($$select (public.request_invoice_issue(%L, %L, '2026-07', 'full', false, true))->>'pending'$$,
  pg_temp.u(101), pg_temp.u(203)))), 'true', 'request_invoice_issue still routes the issue to an approval');
select is(pg_temp.as_user(1, format($$select (public.invoice_issue_readiness(%L, %L, '2026-07'))::text$$,
  pg_temp.u(101), pg_temp.u(203))), '{}', 'the dry run still says nothing is missing');
update public.events set status = 'confirmed'
 where workspace_id = pg_temp.u(101) and type = 'invoice_issue' and status = 'pending';
select is(pg_temp.invoices(), 3, 'the approval, once confirmed, issues the invoice');

-- below its threshold the policy changes nothing
update public.validation_policies set min_amount_cents = 100000000 where workspace_id = pg_temp.u(101);
select ok(pg_temp.as_user(1, format($$select public.create_invoice(%L, %L, '2026-06', null, false, 'full', true)::text$$,
  pg_temp.u(101), pg_temp.u(203))) ~ '^[0-9a-f-]{36}$', 'an invoice below the policy''s threshold issues as today');

select * from finish();
rollback;
