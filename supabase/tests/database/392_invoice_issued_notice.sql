-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3672 (0723): a new invoice tells its customer. Issuing records one
-- `invoice_issued` event per invoice in the same transaction (customer as
-- subject, issuer as actor), and what became of its push (queued, or failed
-- with why). The customer reads the event; a stranger does not; a second
-- event for the same invoice is refused by its key. Rolled back.
begin;
select plan(8);

do $seed$
declare o uuid := '00000000-0000-4000-8000-0000003672a1'; c uuid := '00000000-0000-4000-8000-0000003672a2';
        x uuid := '00000000-0000-4000-8000-0000003672a3'; ws uuid; mo uuid; mc uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', u || '@notice.test', '', now(), now(), now()
    from unnest(array[o, c, x]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by) values ('Notice', 'FR', 'EUR', 'Europe/Paris', o) returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, status) values (ws, o, true, true, 'active') returning id into mo;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, status) values (ws, c, false, false, 'active') returning id into mc;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, status) values (ws, x, false, false, 'active');
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines, total_cents, currency,
                               member_name, workspace_name, issuer_name, signature)
  values (ws, mc, mo, 'N-1', 'March', '[]'::jsonb, 12000, 'EUR', 'Customer', 'Notice', 'Owner', 'sig'),
         (ws, mo, mo, 'N-2', 'March', '[]'::jsonb, 3000, 'EUR', 'Owner', 'Notice', 'Owner', 'sig');
  perform set_config('t.ws', ws::text, false);
  perform set_config('t.mc', mc::text, false);
  perform set_config('t.mo', mo::text, false);
  perform set_config('t.c', c::text, false);
  perform set_config('t.x', x::text, false);
end;
$seed$;

create or replace function pg_temp.seen_by(p_user text) returns int language plpgsql as $f$
declare n int;
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('t.' || p_user), 'role', 'authenticated')::text, true);
  set local role authenticated;
  select count(*)::int into n from public.events
   where workspace_id = current_setting('t.ws')::uuid and type = 'invoice_issued'
     and subject_member_id = current_setting('t.mc')::uuid;
  reset role;
  return n;
end
$f$;

select is((select count(*)::int from public.events
            where workspace_id = current_setting('t.ws')::uuid and type = 'invoice_issued'), 2,
          'each new invoice records one invoice_issued event');
select is((select actor_member_id::text || '|' || subject_member_id::text || '|' || status || '|' || (payload ->> 'number')
             from public.events where type = 'invoice_issued' and payload ->> 'number' = 'N-1'),
          current_setting('t.mo') || '|' || current_setting('t.mc') || '|applied|N-1',
          'the issuer is its actor, the customer its subject, and it waits on nothing');
select is((select subject_member_id::text from public.events where type = 'invoice_issued' and payload ->> 'number' = 'N-2'),
          current_setting('t.mo'), 'an owner who invoices themselves is the subject too');
select is((select count(*)::int from public.invoice_issue_notices where workspace_id = current_setting('t.ws')::uuid), 2,
          'what became of each push is recorded');
select ok((select bool_and(push_outcome in ('queued', 'failed') and (push_outcome = 'queued') = (net_request_id is not null))
             from public.invoice_issue_notices where workspace_id = current_setting('t.ws')::uuid),
          'queued with its request, or failed with why');
select is(pg_temp.seen_by('c'), 1, 'the customer reads the event in their feed');
select is(pg_temp.seen_by('x'), 0, 'another member does not');
select throws_ok(format($$insert into public.events (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
  values (%L, 'invoice_issued', 'created', %L, %L, jsonb_build_object('invoice_id',
    (select id from public.invoices where number = 'N-1' and workspace_id = %L)), 'applied')$$,
  current_setting('t.ws'), current_setting('t.mo'), current_setting('t.mc'), current_setting('t.ws')),
  '23505', null, 'a second event for the same invoice is refused by its key');

select * from finish();
rollback;
