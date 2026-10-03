-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- 0353 (#1835 A) — a person takes part in a space without becoming its
-- member. A space that does not admit guests refuses the request; one that
-- does creates a visit and no member row; the same request id is the same
-- visit, another window under it is refused; nobody reads the table
-- directly; a stranger and a member decide nothing, a host who manages
-- reservations does; the host's note never reaches the guest; joining and
-- leaving the space afterwards rewrites nothing; a member may hold a visit
-- too; only the guest cancels, once; the audit is append-only; the flag
-- off again hides nothing the person already holds.
begin;
select plan(30);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal1')::text, true);
  execute 'set local role authenticated';
end;
$$;
create function pg_temp.err(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return 'none';
exception when others then
  return sqlerrm;
end;
$$;

-- a1 owner (host), a2 administrator (manageReservations by default), a4
-- stranger, a5 member, a6 the guest, a7 a guest who joins and leaves.
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select ('00000000-0000-4000-8000-0000001835' || s)::uuid, '00000000-0000-0000-0000-000000000000',
       'authenticated', 'authenticated', s || '@guests.test', '', now(), now(), now()
  from unnest(array['a1', 'a2', 'a4', 'a5', 'a6', 'a7']) s;
select pg_temp.act_as('00000000-0000-4000-8000-0000001835a1');
select set_config('t.ws', public.create_workspace('Guest space', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select set_config('t.other', public.create_workspace('Other space', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
insert into public.members (workspace_id, user_id, status, is_admin) values
  (current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000001835a2', 'active', true),
  (current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000001835a5', 'active', false);
with s as (insert into public.sites (workspace_id, name) values (current_setting('t.ws')::uuid, 'Hall') returning id)
select set_config('t.site', (select id::text from s), true);
with s as (insert into public.sites (workspace_id, name) values (current_setting('t.other')::uuid, 'Elsewhere') returning id)
select set_config('t.foreign_site', (select id::text from s), true);
select set_config('t.from', (now() + interval '2 days')::text, true);
select set_config('t.to', (now() + interval '2 days 4 hours')::text, true);
select set_config('t.rq', '00000000-0000-4000-8000-00000000d835', true);

-- ── a space that does not admit guests ──────────────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000001835a6');
select alike(pg_temp.err(format($$select public.request_guest_visit(%L, %L, %L, %L, %L, 'hello')$$,
  current_setting('t.ws'), current_setting('t.site'), current_setting('t.from'), current_setting('t.to'), current_setting('t.rq'))),
  '%does not admit guests%', 'with the flag off, nobody asks');
reset role;
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"guestParticipation": true}'
 where id = current_setting('t.ws')::uuid;

-- ── the guest asks ──────────────────────────────────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000001835a6');
select set_config('t.r1', public.request_guest_visit(current_setting('t.ws')::uuid, current_setting('t.site')::uuid,
  current_setting('t.from')::timestamptz, current_setting('t.to')::timestamptz, current_setting('t.rq')::uuid, 'hello')::text, true);
select is(current_setting('t.r1')::jsonb->>'status', 'created', 'the visit is created');
select is(current_setting('t.r1')::jsonb->'visit'->>'status', 'requested', 'and waits for the host');
select set_config('t.id', current_setting('t.r1')::jsonb->'visit'->>'id', true);
select is(public.request_guest_visit(current_setting('t.ws')::uuid, current_setting('t.site')::uuid,
  current_setting('t.from')::timestamptz, current_setting('t.to')::timestamptz, current_setting('t.rq')::uuid, 'hello')->>'status',
  'replayed', 'the same request id answers the same visit');
select alike(pg_temp.err(format($$select public.request_guest_visit(%L, %L, %L, %L, %L)$$,
  current_setting('t.ws'), current_setting('t.site'), current_setting('t.from'),
  (current_setting('t.to')::timestamptz + interval '1 hour')::text, current_setting('t.rq'))),
  '%used for another visit%', 'the same id for another window is refused');
select alike(pg_temp.err(format($$select public.request_guest_visit(%L, %L, %L, %L, %L)$$,
  current_setting('t.ws'), current_setting('t.foreign_site'), current_setting('t.from'), current_setting('t.to'), gen_random_uuid())),
  '%not this space%', 'a site of another space is refused');
select alike(pg_temp.err(format($$select public.request_guest_visit(%L, %L, %L, %L, %L)$$,
  current_setting('t.ws'), current_setting('t.site'), (now() - interval '2 days')::text, (now() - interval '1 day')::text, gen_random_uuid())),
  '%in the past%', 'a visit in the past is refused');
select throws_ok($$select count(*) from public.guest_participations$$, '42501', null,
  'the table is never read directly');
select is(jsonb_array_length(public.my_guest_participations()), 1, 'the guest reads their one visit');
select is(public.my_guest_participations()->0->>'workspace_name', 'Guest space', 'named by its space');
select ok(not (public.my_guest_participations()->0 ? 'host_note'), 'and never the host''s note');
reset role;
select is((select count(*)::int from public.members where user_id = '00000000-0000-4000-8000-0000001835a6'), 0,
  'asking created no membership');
select is((select count(*)::int from public.guest_participations where guest_user_id = '00000000-0000-4000-8000-0000001835a6'), 1,
  'one visit, however many retries');

-- ── who decides ─────────────────────────────────────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000001835a5');
select is(jsonb_array_length(public.my_guest_participations()), 0, 'a member sees none of it');
select alike(pg_temp.err(format($$select public.decide_guest_visit(%L, true)$$, current_setting('t.id'))),
  '%manages this space''s reservations%', 'a plain member decides nothing');
select pg_temp.act_as('00000000-0000-4000-8000-0000001835a4');
select alike(pg_temp.err(format($$select public.decide_guest_visit(%L, true)$$, current_setting('t.id'))),
  '%manages this space''s reservations%', 'a stranger decides nothing');
select alike(pg_temp.err(format($$select public.cancel_my_guest_visit(%L)$$, current_setting('t.id'))),
  '%unknown visit%', 'and cannot cancel what is not theirs');
select pg_temp.act_as('00000000-0000-4000-8000-0000001835a2');
select ok(public.has_permission(current_setting('t.ws')::uuid, 'manageReservations'),
  'the administrator fixture really holds manageReservations (else the next assertion proves nothing)');
select is(public.decide_guest_visit(current_setting('t.id')::uuid, true, 'CANARY-HOST-NOTE', 1)->>'current', 'confirmed',
  'an administrator who manages reservations admits the guest');
select is(public.decide_guest_visit(current_setting('t.id')::uuid, false)->>'status', 'unchanged',
  'a decision is taken once');
select pg_temp.act_as('00000000-0000-4000-8000-0000001835a6');
select is(public.my_guest_participations()->0->>'status', 'confirmed', 'the guest sees the decision');
select ok(position('CANARY-HOST-NOTE' in public.my_guest_participations()::text) = 0,
  'the host''s note is nowhere in what the guest reads');
reset role;

-- ── membership and visit are independent ────────────────────────────
insert into public.members (workspace_id, user_id, status, is_admin)
values (current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000001835a6', 'active', false);
update public.members set status = 'exited'
 where workspace_id = current_setting('t.ws')::uuid and user_id = '00000000-0000-4000-8000-0000001835a6';
delete from public.members
 where workspace_id = current_setting('t.ws')::uuid and user_id = '00000000-0000-4000-8000-0000001835a6';
select is((select status from public.guest_participations where id = current_setting('t.id')::uuid), 'confirmed',
  'joining, leaving and being removed rewrote no visit');
select pg_temp.act_as('00000000-0000-4000-8000-0000001835a5');
select is(public.request_guest_visit(current_setting('t.ws')::uuid, null,
  current_setting('t.from')::timestamptz, current_setting('t.to')::timestamptz, gen_random_uuid())->>'status',
  'created', 'a member may hold a visit of their own beside the membership');
reset role;
select is((select count(*)::int from public.members where user_id = '00000000-0000-4000-8000-0000001835a5'), 1,
  'and still one membership');

-- ── the guest cancels; the audit keeps everything ───────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000001835a6');
select is(public.cancel_my_guest_visit(current_setting('t.id')::uuid)->>'status', 'cancelled', 'the guest cancels');
select is(public.cancel_my_guest_visit(current_setting('t.id')::uuid)->>'status', 'unchanged', 'once');
reset role;
select is((select string_agg(action, ',' order by id) from public.guest_participation_audit
            where participation_id = current_setting('t.id')::uuid), 'requested,confirmed,cancelled',
  'every transition was appended');
select throws_like($$update public.guest_participation_audit set action = 'requested'$$,
  '%append-only%', 'and none is rewritten');

-- ── the flag off again: what the person holds stays theirs ──────────
update public.workspaces set feature_flags = feature_flags || '{"guestParticipation": false}'
 where id = current_setting('t.ws')::uuid;
select pg_temp.act_as('00000000-0000-4000-8000-0000001835a6');
select is(jsonb_array_length(public.my_guest_participations()), 1, 'self reads need no workspace flag');
reset role;
select ok(not has_function_privilege('anon', 'public.request_guest_visit(uuid, uuid, timestamptz, timestamptz, uuid, text)', 'execute'),
  'anonymous asks nothing');

select * from finish();
rollback;
