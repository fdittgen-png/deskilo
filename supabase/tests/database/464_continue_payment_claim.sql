-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4147: continuation reads an existing own payment's original facts. It
-- never opens a replacement, even after the balance or payment state changes.
begin;
select plan(32);

create function pg_temp.seed() returns void language plpgsql as $$
declare
  owner_id uuid := '00000000-0000-4000-8000-000004147001';
  ada_id uuid := '00000000-0000-4000-8000-000004147002';
  ben_id uuid := '00000000-0000-4000-8000-000004147003';
  ws uuid; mo uuid; ma uuid; mb uuid; i1 uuid; i2 uuid; payment uuid;
  request uuid := '00000000-0000-4000-8000-000004147004';
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
    'sub', '00000000-0000-4000-8000-00000414700' || p_suffix, 'role', 'authenticated')::text, true);
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

set local role authenticated;
select is(pg_temp.invoice()->>'claim_can_continue', 'true', 'own open payment offers Continue');
select is(pg_temp.invoice()->>'claim_payment_state', 'ready', 'the overview names a resumable payment');
select is(pg_temp.resume()->>'id', current_setting('t.payment'), 'continuation names the original intent');
select is(pg_temp.resume()->>'request_id', current_setting('t.request'), 'its request survives a new read/device');
select is(pg_temp.resume()->>'provider', 'stripe', 'the original provider is retained');
select is(pg_temp.resume()->>'amount_cents', '6500', 'the original amount is retained');
select is(pg_temp.resume()->>'currency', 'EUR', 'the original currency is retained');
select is(pg_temp.resume()->>'period', '2026-10', 'the original period is retained');
select is(pg_temp.resume()->'invoice_ids',
  (select jsonb_agg(x order by x) from unnest(array[current_setting('t.i1')::uuid,current_setting('t.i2')::uuid]) x),
  'the canonical original claim is retained');
select is(pg_temp.resume(), pg_temp.resume(), 'repeating Continue returns the same facts');
reset role;
insert into public.invoice_matches (workspace_id, invoice_id, paid_cents, resolution, status)
values (current_setting('t.ws')::uuid, current_setting('t.i1')::uuid, 1000, 'under_accepted', 'confirmed');
set local role authenticated;
select is(pg_temp.invoice()->>'still_due_cents', '3000', 'the invoice balance changed');
select is(pg_temp.invoice()->>'claim_can_continue', 'false', 'a claim that no longer equals what is owed offers no Continue');
select is(pg_temp.refusal(current_setting('t.payment')::uuid), 'DKC10:this payment cannot be continued',
  'and is refused: nothing is charged for what was already paid');
reset role;
select is((select count(*)::int from public.payment_intents where workspace_id = current_setting('t.ws')::uuid), 1,
  'repeated continuation creates no second intent');
select is((select count(*)::text from public.ledger_entries where workspace_id = current_setting('t.ws')::uuid),
  current_setting('t.ledger_count'), 'continuation creates no ledger credit');

do $$ begin perform pg_temp.act('3'); end $$;
set local role authenticated;
select is(pg_temp.refusal(current_setting('t.payment')::uuid), pg_temp.refusal(gen_random_uuid()),
  'another customer and an unknown payment have the same refusal');
select is(pg_temp.refusal(current_setting('t.payment')::uuid), 'DKC10:this payment cannot be continued',
  'another customer cannot continue the payment');
select is((select count(*)::int from jsonb_array_elements(public.my_finance_overview()->'invoices')), 0,
  'another customer receives no continuation facts in the overview');
reset role;
do $$ begin perform pg_temp.act('1'); end $$;
set local role authenticated;
select is(pg_temp.refusal(current_setting('t.payment')::uuid), 'DKC10:this payment cannot be continued',
  'administration of another customer does not authorize continuation');
reset role;
do $$ begin perform pg_temp.act('2'); end $$;
set local role authenticated;
select is(pg_temp.refusal(current_setting('t.payment')::uuid, gen_random_uuid()),
  'DKC10:this payment cannot be continued', 'a different workspace cannot continue it');
reset role;

update public.payment_intents set claim_withdrawn_at = now() where id = current_setting('t.payment')::uuid;
set local role authenticated;
select is(pg_temp.invoice()->>'claim_payment_state', 'withdrawn', 'a withdrawn payment explains its state');
select is(pg_temp.refusal(current_setting('t.payment')::uuid), 'DKC10:this payment cannot be continued',
  'an old overview cannot resume a withdrawn payment');
reset role;
update public.payment_intents set claim_withdrawn_at = null, status = 'failed' where id = current_setting('t.payment')::uuid;
set local role authenticated;
select is(pg_temp.invoice()->>'claim_payment_state', 'failed', 'a failed payment explains its state');
select is(pg_temp.refusal(current_setting('t.payment')::uuid), 'DKC10:this payment cannot be continued',
  'an old overview cannot resume a failed payment');
reset role;
update public.payment_intents set status = 'captured' where id = current_setting('t.payment')::uuid;
set local role authenticated;
select is(pg_temp.refusal(current_setting('t.payment')::uuid), 'DKC10:this payment cannot be continued',
  'a paid payment cannot be continued');
reset role;
update public.payment_intents set status = 'created', created_at = now() - interval '25 hours', handed_at = now() - interval '24 hours'
 where id = current_setting('t.payment')::uuid;
set local role authenticated;
select is(pg_temp.invoice()->>'claim_payment_state', 'awaiting_provider', 'a handed order beyond its provider''s window awaits the provider, it is not expired');
select is(pg_temp.invoice()->>'claim_can_continue', 'false', 'it offers no Continue');
select is(pg_temp.refusal(current_setting('t.payment')::uuid), 'DKC10:this payment cannot be continued',
  'an old overview cannot resume it');
reset role;
update public.payment_intents set created_at = now(), request_id = null where id = current_setting('t.payment')::uuid;
set local role authenticated;
select is(pg_temp.invoice()->>'claim_can_continue', 'false', 'an older payment without a durable request offers no Continue');
select is(pg_temp.refusal(current_setting('t.payment')::uuid), 'DKC10:this payment cannot be continued',
  'an older payment is not replaced by a new request');
reset role;
update public.payment_intents set request_id = current_setting('t.request')::uuid where id = current_setting('t.payment')::uuid;
update public.members set status = 'pending' where id = current_setting('t.ma')::uuid;
set local role authenticated;
select is(pg_temp.invoice()->>'claim_can_continue', 'false', 'revoked active access offers no Continue');
select is(pg_temp.refusal(current_setting('t.payment')::uuid), 'DKC10:this payment cannot be continued',
  'revoked access refuses a continuation from an old overview');
reset role;
select is(has_function_privilege('anon', 'public.resume_payment_claim(uuid,uuid)', 'execute'), false,
  'anonymous callers cannot invoke continuation');
select * from finish();
rollback;
