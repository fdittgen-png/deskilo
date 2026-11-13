-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3883 (0762): an Italian workspace opens its issuing gate with a sandbox
-- test document, without any invoice: refused -> test -> the SdI accepts ->
-- issues; and once its credentials change it is refused again. A test is a
-- transmission of kind test: no invoice, no ledger entry, sandbox only, never
-- read by members from the table, one at a time; a rejected test is sent
-- again. Only the service role prepares one. Rolled back.
begin;
select plan(20);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
values ('00000000-0000-4000-8000-0000003883a1','00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated','a1@t3883.test','',now(),now(),now());
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,feature_flags,invoice_legal)
values ('00000000-0000-4000-8000-0000003883b1','IT test','IT','EUR','Europe/Rome',
        '00000000-0000-4000-8000-0000003883a1','dev','{"invoicing":true}','{}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status,customer_capacity)
values ('00000000-0000-4000-8000-0000003883c1','00000000-0000-4000-8000-0000003883b1',
        '00000000-0000-4000-8000-0000003883a1',true,true,'active','business');
insert into public.einvoice_credentials (workspace_id, provider, config, updated_at)
values ('00000000-0000-4000-8000-0000003883b1', 'it_sdi',
        '{"base_url_uat":"https://sdi.test","login_url_uat":"https://login.test","username_uat":"u"}',
        now() - interval '1 hour');

create or replace function pg_temp.refused() returns boolean language sql as $$
  select 'seller_country_unsupported' = any(public.invoice_essentials_missing(
    '00000000-0000-4000-8000-0000003883b1'::uuid, '00000000-0000-4000-8000-0000003883c1'::uuid,
    jsonb_build_object('seller', jsonb_build_object('street','s','city','c','postal_code','00100',
                                                    'country','IT','vat_regime','vat_registered'),
                       'buyer', jsonb_build_object('name','Buyer','street','s','city','c','country','IT')),
    jsonb_build_array(jsonb_build_object('category','S','percent',22,'gross_cents',12200,
                                         'net_cents',10000,'vat_cents',2200))))
$$;
create or replace function pg_temp.test(p_hash text) returns jsonb language sql as $$
  select public.prepare_einvoice_test_v1('00000000-0000-4000-8000-0000003883b1', 'it_sdi',
    '00000000-0000-4000-8000-0000003883a1', 'T', 'fatturaPa', p_hash, 'TEST.xml',
    'application/xml', '\x01'::bytea)
$$;
-- the upload taken by the intermediary, then the SdI's verdict
create or replace function pg_temp.uploaded(p_id uuid) returns void language plpgsql as $f$
declare v_owner uuid := '00000000-0000-4000-8000-0000003883a1';
begin
  perform public.claim_einvoice_dispatch_v1(p_id, v_owner, 150);
  perform public.record_einvoice_outcome_v1(p_id, 1, v_owner, 'accepted', 'SDI-' || p_id, '',
                                            jsonb_build_object('uuid', 'SDI-' || p_id));
end
$f$;
create or replace function pg_temp.verdict(p_id uuid, p_status text) returns text language sql as $f$
  select public.record_einvoice_lookup_v1(p_id, null, null, null,
           jsonb_build_object('status', p_status, 'detail', p_status), null) ->> 'recorded'
$f$;

-- who may prepare one
select ok(not has_function_privilege('authenticated',
  'public.prepare_einvoice_test_v1(uuid, text, uuid, text, text, text, text, text, bytea, jsonb)', 'execute'),
  'a member cannot prepare a test document');
select ok(not has_function_privilege('anon',
  'public.prepare_einvoice_test_v1(uuid, text, uuid, text, text, text, text, text, bytea, jsonb)', 'execute'),
  'nor anon');

-- refused before
select ok(pg_temp.refused(), 'an Italian seller is refused before any acceptance');

-- a first test, rejected by the SdI
select set_config('t.r1', pg_temp.test('h1')::text, false);
select is(current_setting('t.r1')::jsonb ->> 'outcome', 'prepared', 'a test document is prepared without any invoice');
select is((select kind || '|' || coalesce(invoice_id::text, 'none') || '|' || environment || '|' || destination
             from public.invoice_transmissions where id = (current_setting('t.r1')::jsonb ->> 'id')::uuid),
          'test|none|uat|government', 'it is a sandbox test of the government channel, with no invoice');
select is(pg_temp.test('h1b') ->> 'outcome', 'test_pending', 'a second test waits while the first awaits its verdict');
select pg_temp.uploaded((current_setting('t.r1')::jsonb ->> 'id')::uuid);
select is(pg_temp.test('h1c') ->> 'outcome', 'test_pending', 'an upload with no verdict yet still waits');
select ok(pg_temp.refused(), 'an uploaded test with no verdict keeps the gate shut');
select is(pg_temp.verdict((current_setting('t.r1')::jsonb ->> 'id')::uuid, 'rejected'), 'true', 'the SdI refuses the test');
select ok(pg_temp.refused(), 'a refused test keeps the gate shut');

-- a second test, accepted
select set_config('t.r2', pg_temp.test('h2')::text, false);
select is(current_setting('t.r2')::jsonb ->> 'outcome', 'prepared', 'a refused test is sent again');
select pg_temp.uploaded((current_setting('t.r2')::jsonb ->> 'id')::uuid);
select is(pg_temp.verdict((current_setting('t.r2')::jsonb ->> 'id')::uuid, 'accepted'), 'true', 'the SdI accepts the test');
select ok(not pg_temp.refused(), 'the accepted test opens the gate: the workspace issues');
select is((select environment || '|' || (receipt ->> 'transmission_id') from public.national_channel_acceptances
            where workspace_id = '00000000-0000-4000-8000-0000003883b1'),
          'sandbox|' || (current_setting('t.r2')::jsonb ->> 'id'), 'as a sandbox acceptance of that test');

-- nothing of an invoice exists
select is((select count(*)::int from public.invoices where workspace_id = '00000000-0000-4000-8000-0000003883b1'), 0,
          'no invoice was created');
select is((select count(*)::int from public.ledger_entries where workspace_id = '00000000-0000-4000-8000-0000003883b1'), 0,
          'nor a ledger entry');

-- members never read a test from the table
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000003883a1","role":"authenticated"}', true);
set local role authenticated;
select is((select count(*)::int from public.invoice_transmissions), 0,
          'the owner''s list of transmissions leaves the tests out');
reset role;

-- the shape is held by the table
select throws_ok($$insert into public.invoice_transmissions (workspace_id, invoice_id, kind, provider, status, environment, destination)
                   values ('00000000-0000-4000-8000-0000003883b1', null, 'invoice', 'it_sdi', 'failed', 'prod', 'government')$$,
                 '23514', null, 'an invoice transmission names its invoice');
select throws_ok($$insert into public.invoice_transmissions (workspace_id, invoice_id, kind, provider, status, environment, destination)
                   values ('00000000-0000-4000-8000-0000003883b1', null, 'test', 'it_sdi', 'failed', 'prod', 'government')$$,
                 '23514', null, 'a test never goes to the live side');

-- changing the credentials closes the gate again
update public.einvoice_credentials set config = config || '{"username_uat":"v"}', updated_at = now()
 where workspace_id = '00000000-0000-4000-8000-0000003883b1';
select ok(pg_temp.refused(), 'new credentials close the gate until a test passes with them');

select * from finish();
rollback;
