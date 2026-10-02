-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1922: a reminder is an intent, and what happened to it is appended
-- evidence. The sweep prepares one intent per due level and records the
-- push it queued or why it could not; a second sweep adds nothing, and a
-- manual send after it is the next level, never a second copy of the
-- same one. A held invoice gets no intent. A manual send records the
-- sender's declaration that the share sheet completed — not a receipt.
-- Evidence cannot be rewritten or deleted. Reconciliation turns the
-- queue's answer into provider_accepted or failed, and silence into
-- unknown after an hour; running it twice changes nothing, and a
-- provider acceptance leaves the collectible amount untouched. Only
-- whoever issues invoices in the space and the invoice's own member read
-- the evidence.
begin;
select plan(20);

-- a1 owner of b1 · a2 member A · a3 plain member C · a4 owner of b2.
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000001922'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@evidence.test','',now(),now(),now()
  from unnest(array['a1','a2','a3','a4']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,feature_flags,dunning_rules) values
 ('00000000-0000-4000-8000-0000001922b1','Evidence','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000001922a1','dev',
  '{"paymentReminders":true}','{"levels":3,"first_after_days":30,"between_days":14,"automatic":true}'),
 ('00000000-0000-4000-8000-0000001922b2','Foreign evidence','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000001922a4','dev','{}','{}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000001922c1','00000000-0000-4000-8000-0000001922b1','00000000-0000-4000-8000-0000001922a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000001922c2','00000000-0000-4000-8000-0000001922b1','00000000-0000-4000-8000-0000001922a2',false,false,'active'),
 ('00000000-0000-4000-8000-0000001922c3','00000000-0000-4000-8000-0000001922b1','00000000-0000-4000-8000-0000001922a3',false,false,'active'),
 ('00000000-0000-4000-8000-0000001922c4','00000000-0000-4000-8000-0000001922b2','00000000-0000-4000-8000-0000001922a4',true,true,'active');
insert into public.invoices (id, workspace_id, member_id, issuer_member_id, number, title, lines, total_cents,
                             currency, member_name, workspace_name, issuer_name, signature, issued_at)
select ('00000000-0000-4000-8000-0000001922' || k)::uuid, '00000000-0000-4000-8000-0000001922b1',
       '00000000-0000-4000-8000-0000001922c2', '00000000-0000-4000-8000-0000001922c1',
       'EV-' || k, 'T', '[]'::jsonb, 12000, 'EUR', 'A', 'Evidence', 'Owner', 'sig', now() - interval '40 days'
  from unnest(array['f1', 'f2', 'f3']) k;
insert into public.invoice_dunning_holds (workspace_id, invoice_id, reason)
values ('00000000-0000-4000-8000-0000001922b1', '00000000-0000-4000-8000-0000001922f2', 'dispute');

create temp table seen(k text primary key, v jsonb);
grant select, insert on seen to authenticated;

-- ── the sweep, twice, then a manual send ────────────────────────────
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001922a1","role":"authenticated"}',true);
set local role authenticated;
select lives_ok($$select public.sweep_payment_reminders('00000000-0000-4000-8000-0000001922b1')$$, 'the sweep runs');
insert into seen values ('second', to_jsonb(public.sweep_payment_reminders('00000000-0000-4000-8000-0000001922b1')));
select lives_ok($$select public.record_invoice_reminder('00000000-0000-4000-8000-0000001922f1')$$,
  'a manual send right after the sweep');
select lives_ok($$select public.record_invoice_reminder('00000000-0000-4000-8000-0000001922f3')$$,
  'a manual send of another invoice');
reset role;

select is((select count(*)::int from public.reminder_intents
            where invoice_id = '00000000-0000-4000-8000-0000001922f1' and origin = 'automatic'), 1,
  'the sweep prepared one intent for the due level');
select ok((select status in ('queued', 'failed') from public.reminder_intents
            where invoice_id = '00000000-0000-4000-8000-0000001922f1' and origin = 'automatic'),
  'and says whether its push was queued or why it could not be');
select is((select count(*)::int from public.reminder_attempts a join public.reminder_intents ri on ri.id = a.intent_id
            where ri.invoice_id = '00000000-0000-4000-8000-0000001922f1' and ri.origin = 'automatic'), 1,
  'with exactly one recorded attempt');
select is((select v from seen where k = 'second'), '0'::jsonb, 'a second sweep prepares nothing');
select is((select count(distinct level)::int - count(*)::int from public.reminder_intents
            where invoice_id = '00000000-0000-4000-8000-0000001922f1'), 0,
  'the manual send after the sweep is the next level, never a second copy');
select is((select count(*)::int from public.reminder_intents
            where invoice_id = '00000000-0000-4000-8000-0000001922f2'), 0, 'a held invoice gets no intent');
select ok((select ri.status = 'declared_delivered' and a.channel = 'share' and a.detail like '%not a receipt%'
             from public.reminder_intents ri join public.reminder_attempts a on a.intent_id = ri.id
            where ri.invoice_id = '00000000-0000-4000-8000-0000001922f3' and a.channel = 'share'),
  'a manual send records the sender''s declaration, not a receipt');

-- ── evidence is appended, never rewritten ───────────────────────────
select throws_ok($$update public.reminder_attempts set outcome = 'provider_accepted'
                    where intent_id in (select id from public.reminder_intents
                                         where invoice_id = '00000000-0000-4000-8000-0000001922f3')$$,
  'reminder evidence is appended, never rewritten', 'an attempt cannot be rewritten');
select throws_ok($$delete from public.reminder_attempts
                    where intent_id in (select id from public.reminder_intents
                                         where invoice_id = '00000000-0000-4000-8000-0000001922f3')$$,
  'reminder evidence is appended, never rewritten', 'nor deleted');

-- ── reconciliation ──────────────────────────────────────────────────
insert into public.reminder_intents (id, workspace_id, invoice_id, level, origin, status, collectible_cents, currency)
select ('00000000-0000-4000-8000-00000019229' || k)::uuid, '00000000-0000-4000-8000-0000001922b1',
       '00000000-0000-4000-8000-0000001922f3', 3, 'automatic', 'queued', 12000, 'EUR'
  from unnest(array['1', '2', '3']) k;
insert into public.reminder_attempts (workspace_id, intent_id, channel, outcome, net_request_id, at) values
 ('00000000-0000-4000-8000-0000001922b1', '00000000-0000-4000-8000-000000192291', 'push', 'queued', 919220001, now()),
 ('00000000-0000-4000-8000-0000001922b1', '00000000-0000-4000-8000-000000192292', 'push', 'queued', 919220002, now()),
 ('00000000-0000-4000-8000-0000001922b1', '00000000-0000-4000-8000-000000192293', 'push', 'queued', 919220003, now() - interval '2 hours');
insert into net._http_response (id, status_code, content, timed_out, created) values
 (919220001, 200, '{"sent":1}', false, now()),
 (919220002, 500, '{"error":"x"}', false, now());
select ok(public.reconcile_reminder_attempts() >= 3, 'reconciliation records the three outcomes');
select is((select status from public.reminder_intents where id = '00000000-0000-4000-8000-000000192291'), 'provider_accepted',
  'an accepted push is provider_accepted');
select is((select status from public.reminder_intents where id = '00000000-0000-4000-8000-000000192292'), 'failed',
  'a rejected push is failed');
select is((select status from public.reminder_intents where id = '00000000-0000-4000-8000-000000192293'), 'unknown',
  'an unanswered push is unknown after an hour, not resent');
select is(public.reconcile_reminder_attempts(), 0, 'running it again changes nothing');
select is(public.invoice_dunning_state_core('00000000-0000-4000-8000-0000001922f3', now())->>'collectible_cents', '12000',
  'a provider acceptance does not mark anything paid');

-- ── who reads the evidence ──────────────────────────────────────────
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001922a3","role":"authenticated"}',true);
set local role authenticated;
insert into seen values ('plain_rows', to_jsonb((select count(*) from public.reminder_attempts)));
select throws_ok($$select public.invoice_reminder_evidence('00000000-0000-4000-8000-0000001922f3')$$,
  'not allowed to read the reminder evidence of this invoice', 'a plain member reads no other member''s evidence');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001922a2","role":"authenticated"}',true);
insert into seen values ('own', public.invoice_reminder_evidence('00000000-0000-4000-8000-0000001922f3'));
reset role;
select ok((select v = '0'::jsonb from seen where k = 'plain_rows')
          and jsonb_array_length((select v from seen where k = 'own')) >= 1,
  'not even through the table, while the invoice''s own member reads theirs');

select * from finish();
rollback;
