-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3673 (0728): the queue's batch read answers, for the listed invoices of
-- one workspace, what the single read answers for one (the same three
-- reasons) and each invoice's latest reminder e-mail as recorded. Only a
-- native session of someone who issues invoices is answered; an invoice of
-- another workspace is not in the answer. Rolled back.
begin;
select plan(8);

do $seed$
declare ws uuid := '00000000-0000-4000-8000-0000036730b1';
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  select ('00000000-0000-4000-8000-000003673' || s)::uuid, '00000000-0000-0000-0000-000000000000', 'authenticated',
         'authenticated', s || '@queue.test', '', now(), now(), now()
    from unnest(array['0a1', '0a2', '0a3', '0a4']) s;
  insert into public.profiles (id, email) values
    ('00000000-0000-4000-8000-0000036730a1', 'a1@queue.test'),
    ('00000000-0000-4000-8000-0000036730a2', 'a2@queue.test'),
    ('00000000-0000-4000-8000-0000036730a3', ''),
    ('00000000-0000-4000-8000-0000036730a4', 'a4@queue.test')
  on conflict (id) do update set email = excluded.email;
  insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, dunning_rules)
  values (ws, 'Queue', 'FR', 'EUR', 'Europe/Paris', '00000000-0000-4000-8000-0000036730a1',
          '{"moneyTab": true, "invoicing": true, "dunning": true, "paymentReminders": true, "reminderEmail": false}',
          '{"levels": 3, "first_after_days": 30, "between_days": 14, "automatic": false}'),
         ('00000000-0000-4000-8000-0000036730b2', 'Other', 'FR', 'EUR', 'Europe/Paris', '00000000-0000-4000-8000-0000036730a4',
          '{"moneyTab": true, "invoicing": true}', '{}');
  insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
    ('00000000-0000-4000-8000-0000036730c1', ws, '00000000-0000-4000-8000-0000036730a1', true, true, 'active'),
    ('00000000-0000-4000-8000-0000036730c2', ws, '00000000-0000-4000-8000-0000036730a2', false, false, 'active'),
    ('00000000-0000-4000-8000-0000036730c3', ws, '00000000-0000-4000-8000-0000036730a3', false, false, 'active'),
    ('00000000-0000-4000-8000-0000036730c4', '00000000-0000-4000-8000-0000036730b2', '00000000-0000-4000-8000-0000036730a4', true, true, 'active');
  insert into public.invoices (id, workspace_id, member_id, issuer_member_id, number, title, lines, total_cents,
                               currency, member_name, workspace_name, issuer_name, signature, issued_at)
  values
    ('00000000-0000-4000-8000-0000036730f1', ws, '00000000-0000-4000-8000-0000036730c2', '00000000-0000-4000-8000-0000036730c1',
     'Q-1', 'T', '[]'::jsonb, 12000, 'EUR', 'A', 'Queue', 'Owner', 'sig', now() - interval '40 days'),
    ('00000000-0000-4000-8000-0000036730f3', ws, '00000000-0000-4000-8000-0000036730c3', '00000000-0000-4000-8000-0000036730c1',
     'Q-3', 'T', '[]'::jsonb, 12000, 'EUR', 'C', 'Queue', 'Owner', 'sig', now() - interval '40 days'),
    ('00000000-0000-4000-8000-0000036730f9', '00000000-0000-4000-8000-0000036730b2', '00000000-0000-4000-8000-0000036730c4',
     '00000000-0000-4000-8000-0000036730c4', 'O-1', 'T', '[]'::jsonb, 12000, 'EUR', 'D', 'Other', 'Owner', 'sig', now() - interval '40 days');
end;
$seed$;

create or replace function pg_temp.targets(p_user text, p_delegated boolean default false) returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims', (case when p_delegated
    then json_build_object('sub', '00000000-0000-4000-8000-000003673' || p_user, 'role', 'authenticated', 'client_id', 'delegated')
    else json_build_object('sub', '00000000-0000-4000-8000-000003673' || p_user, 'role', 'authenticated') end)::text, true);
  set local role authenticated;
  select public.reminder_email_targets_v1('00000000-0000-4000-8000-0000036730b1',
           array['00000000-0000-4000-8000-0000036730f1', '00000000-0000-4000-8000-0000036730f3',
                 '00000000-0000-4000-8000-0000036730f9']::uuid[])::text into v;
  reset role;
  return v;
exception when others then
  reset role;
  return 'ERROR: ' || sqlerrm;
end
$f$;
create or replace function pg_temp.of(p_answer text, p_invoice text) returns jsonb language sql as $f$
  select e from jsonb_array_elements(p_answer::jsonb) e
   where e ->> 'invoice_id' = '00000000-0000-4000-8000-0000036730' || p_invoice
$f$;

select is(pg_temp.targets('0a1', true), 'ERROR: not allowed', 'an assistant''s delegated session is not answered');
select is(pg_temp.targets('0a2'), 'ERROR: not allowed', 'a member who issues no invoices is not answered');
select ok(pg_temp.of(pg_temp.targets('0a1'), 'f1') ->> 'reason' = 'feature_off'
          and pg_temp.of(pg_temp.targets('0a1'), 'f3') ->> 'reason' = 'feature_off',
          'with the feature off, every line says so');
update public.workspaces set feature_flags = feature_flags || '{"reminderEmail": true}'
 where id = '00000000-0000-4000-8000-0000036730b1';
select is(pg_temp.of(pg_temp.targets('0a1'), 'f1') ->> 'reason', 'sender_not_configured',
          'without the sender, the line says so');
insert into public.purchase_order_mail_settings (workspace_id, sender_email, sender_name, has_api_key)
values ('00000000-0000-4000-8000-0000036730b1', 'billing@queue.test', 'Queue', true);
select ok((pg_temp.of(pg_temp.targets('0a1'), 'f1') ->> 'available')::boolean
          and pg_temp.of(pg_temp.targets('0a1'), 'f1') ->> 'recipient' = 'a2@queue.test',
          'a reachable customer: available, with the address');
select is(pg_temp.of(pg_temp.targets('0a1'), 'f3') ->> 'reason', 'no_address', 'a customer without an address says so');
select is(jsonb_array_length(pg_temp.targets('0a1')::jsonb), 2, 'an invoice of another workspace is not in the answer');

-- The latest e-mail as the server recorded it.
do $s$ begin
  perform set_config('request.jwt.claims', '{"sub": "00000000-0000-4000-8000-0000036730a1", "role": "authenticated"}', true);
  perform public.begin_reminder_email_v1('00000000-0000-4000-8000-0000036730b1', '00000000-0000-4000-8000-0000036730f1',
                                         1, 'fr', '00000000-0000-4000-8000-0000036730e1');
  perform public.finish_reminder_email('00000000-0000-4000-8000-0000036730e1', 'accepted', 'prov-1', '');
end $s$;
select ok(pg_temp.of(pg_temp.targets('0a1'), 'f1') -> 'last_send' ->> 'state' = 'accepted'
          and pg_temp.of(pg_temp.targets('0a1'), 'f1') -> 'last_send' ->> 'level' = '1'
          and pg_temp.of(pg_temp.targets('0a1'), 'f3') -> 'last_send' = 'null'::jsonb,
          'each line carries its latest e-mail as recorded, or none');

select * from finish();
rollback;
