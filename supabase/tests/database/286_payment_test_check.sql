-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2871 (9999): the online-payments step's test reads the keys a space
-- holds and says what a checkout would do with them, without paying.
-- No provider row: nothing to test. Stripe test key, Mollie test key and
-- PayPal sandbox: test keys. One live key: live. A key that names no mode,
-- or a field the space does not hold: unverified. A development space
-- never takes payments; a production one does. The answer never carries a
-- secret, nothing is charged, no payment intent is opened. A member who is
-- not an owner is refused, and so is an owner while online payments are off.
begin;
select plan(18);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000002871'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@payment-test.test','',now(),now(),now()
  from unnest(array['a1','a2']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,feature_flags) values
 ('00000000-0000-4000-8000-0000002871b1','Payment test dev','FR','EUR','Europe/Paris',
  '00000000-0000-4000-8000-0000002871a1','dev','{"moneyTab":true,"onlinePayments":true}'),
 ('00000000-0000-4000-8000-0000002871b2','Payment test prod','FR','EUR','Europe/Paris',
  '00000000-0000-4000-8000-0000002871a1','prod','{"moneyTab":true,"onlinePayments":true}'),
 ('00000000-0000-4000-8000-0000002871b3','Payment test off','FR','EUR','Europe/Paris',
  '00000000-0000-4000-8000-0000002871a1','prod','{"moneyTab":true,"onlinePayments":false}');
insert into public.members(workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000002871b1','00000000-0000-4000-8000-0000002871a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000002871b2','00000000-0000-4000-8000-0000002871a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000002871b3','00000000-0000-4000-8000-0000002871a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000002871b1','00000000-0000-4000-8000-0000002871a2',false,true,'active');

create function pg_temp.check(p_ws text) returns jsonb language sql as $$
  select public.payment_test_check(('00000000-0000-4000-8000-0000002871' || p_ws)::uuid)
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.mode(p_ws text, p_provider text) returns text language sql as $$
  select p->>'mode' from jsonb_array_elements(pg_temp.check(p_ws)->'providers') p
   where p->>'provider' = p_provider
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002871a1","role":"authenticated"}',true);

-- Nothing connected: nothing to test.
select is(pg_temp.check('b1')->>'verdict', 'no_provider', 'no provider row: nothing to test');
select is((pg_temp.check('b1')->>'charged')::boolean, false, 'the test never charges');
select is((pg_temp.check('b1')->>'takes_payments')::boolean, false, 'a development space takes no payment');
select is((pg_temp.check('b2')->>'takes_payments')::boolean, true, 'a production space takes payments');

-- Test keys only.
insert into public.payment_credentials(workspace_id,provider,config) values
 ('00000000-0000-4000-8000-0000002871b1','stripe','{"secret_key":"sk_test_51Abc","webhook_secret":"whsec_1","return_url":"https://x.test/r"}'),
 ('00000000-0000-4000-8000-0000002871b1','mollie','{"api_key":"test_dHar4XY7","return_url":"https://x.test/r"}'),
 ('00000000-0000-4000-8000-0000002871b1','paypal','{"client_id":"c","secret":"s","env":"sandbox","webhook_id":"w","return_url":"https://x.test/r"}');
select is(pg_temp.mode('b1','stripe'), 'test', 'a Stripe sk_test_ key is a test key');
select is(pg_temp.mode('b1','mollie'), 'test', 'a Mollie test_ key is a test key');
select is(pg_temp.mode('b1','paypal'), 'test', 'PayPal on the sandbox is a test key');
select is(pg_temp.check('b1')->>'verdict', 'test_keys', 'every key a test key: the checkout takes no real money');
select ok(position('sk_test_51Abc' in pg_temp.check('b1')::text) = 0
          and position('test_dHar4XY7' in pg_temp.check('b1')::text) = 0
          and position('whsec_1' in pg_temp.check('b1')::text) = 0,
  'the answer never carries a secret');

-- One live key makes the whole checkout real.
insert into public.payment_credentials(workspace_id,provider,config) values
 ('00000000-0000-4000-8000-0000002871b1','wero','{"api_key":"live_9Hk2","return_url":"https://x.test/r"}');
select is(pg_temp.mode('b1','wero'), 'live', 'a Mollie live_ key behind Wero is a live key');
select is(pg_temp.check('b1')->>'verdict', 'live_keys', 'one live key: the checkout charges a real card');

-- What cannot be read is never called a test.
insert into public.payment_credentials(workspace_id,provider,config) values
 ('00000000-0000-4000-8000-0000002871b2','stripe','{"secret_key":"pk_whatever","return_url":"https://x.test/r"}'),
 ('00000000-0000-4000-8000-0000002871b2','paypal','{"client_id":"c","secret":"s","return_url":"https://x.test/r"}'),
 ('00000000-0000-4000-8000-0000002871b2','mollie','{"return_url":"https://x.test/r"}');
select is(pg_temp.mode('b2','stripe'), 'unknown', 'a key of no known shape names no mode');
select is(pg_temp.mode('b2','paypal'), 'installation', 'PayPal without its environment: the installation decides');
select is(pg_temp.mode('b2','mollie'), 'installation', 'a key the space does not hold: the installation decides');
select is(pg_temp.check('b2')->>'verdict', 'unverified', 'any mode not read as test: unverified, never test');

-- Nothing was paid or opened.
select is((select count(*)::int from public.payment_intents
            where workspace_id in ('00000000-0000-4000-8000-0000002871b1','00000000-0000-4000-8000-0000002871b2')),
  0, 'no payment intent is opened');

-- Refusals.
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002871a2","role":"authenticated"}',true);
select throws_ok($$select pg_temp.check('b1')$$, '42501', null, 'an administrator who is not an owner is refused');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002871a1","role":"authenticated"}',true);
select throws_ok($$select pg_temp.check('b3')$$, '42501', null, 'online payments off: refused');

select * from finish();
rollback;
