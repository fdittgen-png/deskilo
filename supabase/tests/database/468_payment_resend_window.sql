-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4217 (0814): a checkout continues only while the claim still equals what is
-- owed, online payments are on, the provider's own window (a platform setting
-- per provider, from the hand-over) is open, and the provider account is the
-- one it was handed to. A handed claim past its window awaits the provider.
begin;
select plan(21);

create function pg_temp.seed() returns void language plpgsql as $$
declare
  owner_id uuid := '00000000-0000-4000-8000-000004217001';
  ada_id uuid := '00000000-0000-4000-8000-000004217002';
  ben_id uuid := '00000000-0000-4000-8000-000004217003';
  ws uuid; mo uuid; ma uuid; mb uuid; i1 uuid; i2 uuid; payment uuid;
  request uuid := '00000000-0000-4000-8000-000004217004';
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'continue-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[owner_id, ada_id, ben_id]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Continue payment', 'FR', 'EUR', 'Europe/Paris', owner_id,
          '{"moneyTab":true,"invoicing":true,"onlinePayments":true}'::jsonb)
  returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, status, joined_at)
  values (ws, owner_id, true, true, 'active', '2026-01-01'),
         (ws, ada_id, false, false, 'active', '2026-01-01'),
         (ws, ben_id, false, false, 'active', '2026-01-01');
  select id into mo from public.members where workspace_id = ws and user_id = owner_id;
  select id into ma from public.members where workspace_id = ws and user_id = ada_id;
  select id into mb from public.members where workspace_id = ws and user_id = ben_id;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title,
    lines, total_cents, currency, member_name, workspace_name, issuer_name, signature, period, issued_at, kind)
  values (ws, ma, mo, 'CONTINUE-A1', 'A1', '[]', 4000, 'EUR', 'Ada', 'Continue payment', 'Owner', 'sig', '2026-10', '2026-11-02', 'full')
  returning id into i1;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title,
    lines, total_cents, currency, member_name, workspace_name, issuer_name, signature, period, issued_at, kind)
  values (ws, ma, mo, 'CONTINUE-A2', 'A2', '[]', 2500, 'EUR', 'Ada', 'Continue payment', 'Owner', 'sig', '2026-10', '2026-11-02', 'usage')
  returning id into i2;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', ada_id, 'role', 'authenticated')::text, true);
  select id into payment from public.open_payment_intent(ws, ma, 'stripe', '2026-10', 6500, 'EUR', request, array[i2,i1]);
  perform set_config('t.ws', ws::text, true);
  perform set_config('t.ma', ma::text, true);
  perform set_config('t.mb', mb::text, true);
  perform set_config('t.i1', i1::text, true);
  perform set_config('t.i2', i2::text, true);
  perform set_config('t.payment', payment::text, true);
  perform set_config('t.request', request::text, true);
  perform set_config('t.ledger_count', (select count(*)::text from public.ledger_entries where workspace_id = ws), true);
end $$;
do $$ begin perform pg_temp.seed(); end $$;

create function pg_temp.act(p_suffix text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', '00000000-0000-4000-8000-00000421700' || p_suffix, 'role', 'authenticated')::text, true);
end $$;
create function pg_temp.invoice() returns jsonb language sql as $$
  select x from jsonb_array_elements(public.my_finance_overview()->'invoices') x
   where x->>'id' = current_setting('t.i1')
$$;
create function pg_temp.resume() returns jsonb language plpgsql as $$
begin
  return public.resume_payment_claim(current_setting('t.ws')::uuid, current_setting('t.payment')::uuid);
end $$;
create function pg_temp.refusal(p_payment uuid, p_workspace uuid default null) returns text language plpgsql as $$
begin
  perform public.resume_payment_claim(coalesce(p_workspace, current_setting('t.ws')::uuid), p_payment);
  return 'accepted';
exception when others then return sqlstate || ':' || sqlerrm;
end $$;
grant execute on all functions in schema pg_temp to authenticated;

-- a handed claim, in a window: the provider's own, from the hand-over
create function pg_temp.state() returns text language sql as $$
  select pg_temp.invoice()->>'claim_payment_state' || '/' || (pg_temp.invoice()->>'claim_can_continue');
$$;
create function pg_temp.hand(p_provider text, p_minutes int) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '', true);
  execute 'reset role';
  update public.payment_intents set provider = p_provider, handed_at = now() - make_interval(mins => p_minutes),
         created_at = now() - make_interval(mins => p_minutes + 5)
   where id = current_setting('t.payment')::uuid;
  perform pg_temp.act('2');
  execute 'set local role authenticated';
end $$;
grant execute on all functions in schema pg_temp to authenticated;

select pg_temp.act('2');
set local role authenticated;
-- 3: each provider's own window, from the hand-over
select pg_temp.hand('mollie', 70);
select is(pg_temp.state(), 'awaiting_provider/false', 'handed 70 minutes ago to Mollie, which keeps a key one hour, it awaits the provider');
select pg_temp.hand('mollie', 30);
select is(pg_temp.state(), 'ready/true', 'handed 30 minutes ago to Mollie, it continues');
select pg_temp.hand('paypal', 70);
select is(pg_temp.state(), 'ready/true', 'handed 70 minutes ago to PayPal, which keeps a key six hours, it continues');
select pg_temp.hand('paypal', 400);
select is(pg_temp.state(), 'awaiting_provider/false', 'handed 400 minutes ago to PayPal, it awaits the provider');
select pg_temp.hand('stripe', 1300);
select is(pg_temp.state(), 'ready/true', 'handed 1300 minutes ago to Stripe, which keeps a key a day, it continues');
select pg_temp.hand('stripe', 1400);
select is(pg_temp.state(), 'awaiting_provider/false', 'handed 1400 minutes ago to Stripe, it awaits the provider');
reset role;
select is((select public.payment_resend_window('wero')::text), (select public.payment_resend_window('mollie')::text), 'Wero rides Mollie''s window');
-- the window is a setting an operator changes
insert into public.setting_values (scope, key, value) values ('platform', 'payments.resend_window_stripe_minutes', '10'::jsonb);
select pg_temp.act('2');
set local role authenticated;
select pg_temp.hand('stripe', 30);
select is(pg_temp.state(), 'awaiting_provider/false', 'with the Stripe window set to 10 minutes, a claim handed 30 minutes ago awaits the provider');
reset role;
delete from public.setting_values where key = 'payments.resend_window_stripe_minutes';

-- 1: the claim equals what is owed, every invoice of it open
select pg_temp.hand('stripe', 5);
select pg_temp.act('2');
set local role authenticated;
select is(pg_temp.state(), 'ready/true', 'the claim equals what is owed: it continues');
reset role;
insert into public.invoice_matches (workspace_id, invoice_id, paid_cents, resolution, status)
values (current_setting('t.ws')::uuid, current_setting('t.i1')::uuid, 4000, 'exact', 'confirmed');
set local role authenticated;
select is(pg_temp.state(), 'changed/false', 'one invoice of the claim settled by a transfer: the claim is changed');
select is(pg_temp.refusal(current_setting('t.payment')::uuid), 'DKC10:this payment cannot be continued', 'it is refused; nothing is charged');
reset role;
delete from public.invoice_matches where invoice_id = current_setting('t.i1')::uuid;

-- the rules again where the charge happens: the hand-over of the checkout
create function pg_temp.fresh() returns void language sql as $$
  update public.payment_intents set handed_at = null, created_at = now() - interval '5 minutes', provider = 'stripe'
   where id = current_setting('t.payment')::uuid;
$$;
select pg_temp.fresh();
select ok(public.hand_payment_intent(current_setting('t.payment')::uuid), 'a claim that equals what is owed is handed over');
select pg_temp.fresh();
insert into public.invoice_matches (workspace_id, invoice_id, paid_cents, resolution, status)
values (current_setting('t.ws')::uuid, current_setting('t.i1')::uuid, 4000, 'exact', 'confirmed');
select ok(not public.hand_payment_intent(current_setting('t.payment')::uuid), 'one invoice settled between the continuation and the charge: the hand-over refuses');
select ok((select handed_at is null from public.payment_intents where id = current_setting('t.payment')::uuid), 'and nothing was handed');
delete from public.invoice_matches where invoice_id = current_setting('t.i1')::uuid;
update public.workspaces set feature_flags = feature_flags || '{"onlinePayments": false}' where id = current_setting('t.ws')::uuid;
select ok(not public.hand_payment_intent(current_setting('t.payment')::uuid), 'online payments switched off before the charge: the hand-over refuses');
update public.workspaces set feature_flags = feature_flags || '{"onlinePayments": true}' where id = current_setting('t.ws')::uuid;
select ok(public.payment_resend_window('nothing') = interval '0', 'a provider outside the three has no window');
update public.payment_intents set handed_at = now() - interval '5 minutes' where id = current_setting('t.payment')::uuid;

-- 2: the business's online-payment setting
update public.workspaces set feature_flags = feature_flags || '{"onlinePayments": false}' where id = current_setting('t.ws')::uuid;
select pg_temp.act('2');
set local role authenticated;
select is(pg_temp.state(), 'unavailable/false', 'with online payments off, Continue is not offered');
select is(pg_temp.refusal(current_setting('t.payment')::uuid), 'DKC10:this payment cannot be continued', 'and not accepted');
reset role;
update public.workspaces set feature_flags = feature_flags || '{"onlinePayments": true}' where id = current_setting('t.ws')::uuid;

-- 4: a provider account the business has since replaced
insert into public.payment_credentials (workspace_id, provider, config, updated_at)
values (current_setting('t.ws')::uuid, 'stripe', '{}'::jsonb, now() + interval '1 minute')
on conflict (workspace_id, provider) do update set updated_at = now() + interval '1 minute';
select pg_temp.act('2');
set local role authenticated;
select is(pg_temp.state(), 'changed/false', 'a claim handed before the business replaced the provider account cannot be continued');
select is(pg_temp.refusal(current_setting('t.payment')::uuid), 'DKC10:this payment cannot be continued', 'it is refused');
reset role;
select ok(not has_function_privilege('authenticated', 'public.payment_resend_window(text)', 'execute'), 'no client reads a provider window');

select * from finish();
rollback;
