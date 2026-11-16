-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4136 (0802): an attempt the reconciliation cannot read is told once to
-- those who read the finances. Unreadable in three runs, one notice, naming
-- the latest reason; read in a later run, the notice ends, and unreadable
-- again it opens again, still one; settled or ended by any path it ends,
-- and a late capture turns ended into settled; an attempt no longer open, or
-- not claimed, is told nothing; the database keeps one notice per attempt.
-- A notice never stops a payment. Read with viewFinances, by an
-- administrator who holds it as by the owner; the member it names does not
-- read it, even where a validation rule would let them in; the owner's own
-- export leaves it out. The calendar's events follow each event type's
-- reading rule: a holder of manageReservations without a type's right reads
-- nothing of it in another member's calendar, neither the event nor a
-- decision on it.
begin;
select plan(31);

create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00004136' || lpad(n::text, 4, '0'))::uuid;
$$;
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'told' || n || '@example.test', '', now(), now(), now()
  from generate_series(1, 4) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions)
values (pg_temp.u(101), 'Told 4136', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"customRoles": true}',
        '{"member": ["makeReservations"], "admin": ["manageMembers","approveExpenses","viewFinances","manageReservations","makeReservations"]}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status, joined_at)
values (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active', '2026-01-01'),
       (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active', '2026-01-01'),
       (pg_temp.u(203), pg_temp.u(101), pg_temp.u(3), false, true, 'active', '2026-01-01'),
       (pg_temp.u(204), pg_temp.u(101), pg_temp.u(4), false, false, 'active', '2026-01-01');
-- the front desk holds manageReservations and nothing else
insert into public.workspace_roles (id, workspace_id, key, permissions, names)
values (pg_temp.u(501), pg_temp.u(101), 'front_desk', array['manageReservations'], '{"en": "Front desk"}');
insert into public.workspace_role_members (workspace_id, role_id, member_id)
values (pg_temp.u(101), pg_temp.u(501), pg_temp.u(204));
-- a rule that would let every member validate a notice: only its reading rule keeps them out
delete from public.validation_policies where workspace_id = pg_temp.u(101);
insert into public.validation_policies (workspace_id, event_type, validator_scope)
values (pg_temp.u(101), 'payment_attempt_unreadable', 'members');
insert into public.payment_intents (id, workspace_id, member_id, provider, order_id, period, amount_cents, currency, reference, status, created_at)
select pg_temp.u(300 + n), pg_temp.u(101), pg_temp.u(202), 'stripe', 'cs_told' || n, '2026-10', 1000 + n, 'EUR',
       'PAY-T' || n, 'created', now() - interval '2 hours'
  from generate_series(1, 6) n;
-- the payer's own declared payment, which they read
insert into public.events (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
values (pg_temp.u(101), 'payment', 'submitted', pg_temp.u(202), pg_temp.u(202), '{"amount_cents": 500}', 'pending');

-- One run of the business under its lease, claiming [p_claimed]: its
-- read items are [p_read], [p_unreadable] the ones it could not read.
create function pg_temp.run(p_claimed int[], p_read int[], p_unreadable jsonb) returns boolean language plpgsql as $f$
declare v_token uuid := gen_random_uuid();
begin
  insert into public.payment_reconciliation_state (workspace_id, lease_token, lease_until, claimed)
  values (pg_temp.u(101), v_token, now() + interval '1 hour', array(select pg_temp.u(c) from unnest(p_claimed) c))
  on conflict (workspace_id) do update
    set lease_token = excluded.lease_token, lease_until = excluded.lease_until, claimed = excluded.claimed;
  return public.payment_reconciliation_finish_v1(pg_temp.u(101), v_token, jsonb_build_object(
    'read', cardinality(p_read),
    'read_items', (select coalesce(jsonb_agg(jsonb_build_object('intent', pg_temp.u(r))), '[]') from unnest(p_read) r),
    'unreadable', (select coalesce(jsonb_agg(jsonb_build_object('intent', pg_temp.u((e ->> 'n')::int), 'reason', e ->> 'reason')), '[]')
                     from jsonb_array_elements(p_unreadable) e)));
end $f$;
create function pg_temp.notices(n int) returns setof public.events language sql as $$
  select * from public.events
   where workspace_id = pg_temp.u(101) and type = 'payment_attempt_unreadable'
     and payload ->> 'intent' = pg_temp.u(n)::text;
$$;
-- [p_sql] as user [n]: its answer as text, or 'ERR <sqlstate>'.
create function pg_temp.as_user(n int, p_sql text) returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(n), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  execute p_sql into v;
  execute 'reset role';
  return v;
exception when others then
  execute 'reset role';
  return 'ERR ' || sqlstate;
end $f$;
create function pg_temp.notices_read_by(n int) returns text language sql as $$
  select pg_temp.as_user(n, format('select count(*)::text from public.events where workspace_id = %L and type = %L',
                                   pg_temp.u(101), 'payment_attempt_unreadable'));
$$;
-- The event types user [n] finds in [p_member]'s calendar, of [p_kind]
-- ('event', or 'validation' for the decisions on events).
create function pg_temp.calendar_types(n int, p_member int, p_kind text) returns text[] language plpgsql as $f$
declare v text;
begin
  v := pg_temp.as_user(n, format(
    $q$select coalesce(jsonb_agg(distinct coalesce(i -> 'payload' ->> 'event_type', split_part(i ->> 'title', '.', 1))), '[]')::text
         from jsonb_array_elements(public.calendar_items(%L, now() - interval '1 hour', now() + interval '1 hour', array[%L], %L) -> 'items') i$q$,
    pg_temp.u(101), p_kind, pg_temp.u(p_member)));
  if v like 'ERR%' then return array[v]; end if;
  return array(select jsonb_array_elements_text(v::jsonb) order by 1);
end $f$;

-- ── told once ──
select ok(pg_temp.run(array[301, 302, 303], array[301, 302, 303],
            '[{"n": 301, "reason": "unreachable"}, {"n": 302, "reason": "refused"}, {"n": 303, "reason": "mismatch"}]'),
  'a run that cannot read three attempts finishes');
select is((select string_agg(concat_ws(' ', payload ->> 'member_id', actor_member_id, subject_member_id, status, payload ->> 'reference',
                                       payload ->> 'provider', payload ->> 'amount_cents', payload ->> 'currency',
                                       payload ->> 'reason', (payload ? 'ended')::text), ',') from pg_temp.notices(301)),
  concat_ws(' ', pg_temp.u(202), pg_temp.u(201), pg_temp.u(201), 'applied', 'PAY-T1', 'stripe', '1001', 'EUR', 'unreachable', 'false'),
  'the notice names the payment, the member who pays it and the reason; the owner is its actor and subject');
select ok(pg_temp.run(array[301], array[301], '[{"n": 301, "reason": "refused"}]')
          and pg_temp.run(array[301], array[301], '[{"n": 301, "reason": "refused"}]'),
  'two more runs cannot read it');
select is((select count(*)::int from pg_temp.notices(301)), 1, 'unreadable in three runs: one notice');
select is((select payload ->> 'reason' from pg_temp.notices(301)), 'refused', 'naming the latest reason');
create function pg_temp.second_notice() returns text language plpgsql as $f$
begin
  insert into public.events (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
  values (pg_temp.u(101), 'payment_attempt_unreadable', 'created', pg_temp.u(201), pg_temp.u(201),
          jsonb_build_object('intent', pg_temp.u(301)::text), 'applied');
  return 'inserted';
exception when others then
  return sqlstate;
end $f$;
select is(pg_temp.second_notice(), '23505', 'the database itself refuses a second notice of an attempt');

-- ── its end, and its opening again ──
select ok(pg_temp.run(array[301, 304], array[301, 304], '[]'), 'a later run reads it');
select is((select (payload ->> 'ended') || ' ' || (payload ? 'ended_at') from pg_temp.notices(301)), 'read true',
  'its notice ends as read, with the time');
select is((select count(*)::int from pg_temp.notices(304)), 0, 'an attempt read at once is told nothing');
select ok(pg_temp.run(array[301], array[301], '[{"n": 301, "reason": "unreachable"}]'), 'unreadable again after the read');
select is((select count(*)::int || ' ' || bool_or(payload ? 'ended') || ' ' || min(payload ->> 'reason') from pg_temp.notices(301)),
  '1 false unreachable', 'the same notice opens again with the new reason, never a second');
update public.payment_intents set status = 'captured' where id = pg_temp.u(302);
update public.payment_intents set status = 'failed' where id = pg_temp.u(303);
select is((select string_agg(payload ->> 'ended', ' ') from (select * from pg_temp.notices(302) union all select * from pg_temp.notices(303)) n),
  'settled ended', 'settled or ended by any path, its notice ends');
update public.payment_intents set status = 'captured' where id = pg_temp.u(303);
select is((select payload ->> 'ended' from pg_temp.notices(303)), 'settled', 'a late capture of a failed attempt: settled');
select ok(pg_temp.run(array[301], array[301], '[{"n": 304, "reason": "refused"}]'), 'a run naming an open attempt it did not claim');
select is((select count(*)::int from pg_temp.notices(304)), 0, 'tells nothing about it');
update public.payment_intents set status = 'captured' where id = pg_temp.u(306);
select ok(pg_temp.run(array[306], array[306], '[{"n": 306, "reason": "unreachable"}]'), 'a run whose attempt was settled meanwhile');
select is((select count(*)::int from pg_temp.notices(306)), 0, 'tells nothing of an attempt no longer open');

-- ── a notice never stops a payment ──
select ok(pg_temp.run(array[305], array[305], '[{"n": 305, "reason": "unreachable"}]'), 'an attempt is told');
create function pg_temp.refuse_notice_update() returns trigger language plpgsql as $f$
begin
  if new.type = 'payment_attempt_unreadable' then
    raise exception 'a notice cannot be changed now' using errcode = 'P0001';
  end if;
  return new;
end $f$;
create trigger zz_refuse_notice_update before update on public.events
  for each row execute function pg_temp.refuse_notice_update();
update public.payment_intents set status = 'captured' where id = pg_temp.u(305);
select is((select status from public.payment_intents where id = pg_temp.u(305)) || ' ' || (select (payload ? 'ended')::text from pg_temp.notices(305)),
  'captured false', 'when its notice cannot be ended, the attempt still settles and the notice stays as it was');
drop trigger zz_refuse_notice_update on public.events;

-- ── who reads it ──
select is(pg_temp.notices_read_by(1), '4', 'the owner reads every notice');
select is(pg_temp.notices_read_by(3), '4', 'so does an administrator who holds viewFinances');
select is(pg_temp.notices_read_by(2), '0',
  'the member a notice names does not, though a rule would let every member validate it');
select is(pg_temp.as_user(2, format('select count(*)::text from public.events where workspace_id = %L and type = %L',
                                    pg_temp.u(101), 'payment')),
  '1', 'and still reads their own payment');
select is((select count(*)::int from public.events where workspace_id = pg_temp.u(101) and type = 'payment_attempt_unreadable'
              and pg_temp.u(202) in (actor_member_id, subject_member_id)),
  0, 'no notice is the named member''s own event');
select is(pg_temp.as_user(1, format($q$select (select count(*) from jsonb_array_elements(public.export_my_data(%L) -> 'events') e
                                              where e ->> 'type' = 'payment_attempt_unreadable')::text$q$, pg_temp.u(101))),
  '0', 'the owner''s own export leaves the notices out');

-- ── the calendar follows each type's reading rule ──
-- One event of every type that a reading right of its own or a restrictive
-- rule guards (not read with manageReservations), the owner's own; a
-- decision on each.
create temp table guarded as
  select t.type_name
    from (select (regexp_matches(pg_get_constraintdef(c.oid), '''([a-z_]+)''', 'g'))[1] type_name
            from pg_constraint c where c.conname = 'events_type_check' and c.conrelid = 'public.events'::regclass) t
   where not ('manageReservations' = any (public.event_type_view_permissions(t.type_name)));
create temp table not_seeded (type_name text, code text);
-- and one the front desk reads: a quota request of the owner's
insert into public.events (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
values (pg_temp.u(101), 'quota', 'submitted', pg_temp.u(201), pg_temp.u(201), '{"half_days": 1}', 'applied');
do $seed$
declare r record; v_id uuid;
begin
  for r in select type_name from guarded loop
    begin
      insert into public.events (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
      values (pg_temp.u(101), r.type_name, 'created', pg_temp.u(201), pg_temp.u(201), '{}', 'applied')
      returning id into v_id;
      insert into public.event_decisions (event_id, member_id, decision, workspace_id)
      values (v_id, pg_temp.u(201), 'accept', pg_temp.u(101));
    exception when others then
      insert into not_seeded values (r.type_name, sqlstate);
    end;
  end loop;
end $seed$;
select is((select string_agg(type_name || ' ' || code, ', ') from not_seeded), null,
  'every guarded type has an event and a decision in the owner''s calendar');
select ok(not (pg_temp.calendar_types(4, 201, 'event') && array(select type_name from guarded))
          and 'quota' = any (pg_temp.calendar_types(4, 201, 'event')),
  'a holder of manageReservations without their rights finds none of them in the owner''s calendar, and what they read');
select ok(not (pg_temp.calendar_types(4, 201, 'validation') && array(select type_name from guarded))
          and pg_temp.calendar_types(4, 201, 'validation') is not null
          and not exists (select 1 from unnest(pg_temp.calendar_types(4, 201, 'validation')) x where x like 'ERR%'),
  'nor any decision on them');
select is(pg_temp.calendar_types(1, 201, 'event') @> array(select type_name from guarded order by 1), true,
  'the owner finds every one of them');
select ok('payment_attempt_unreadable' = any (pg_temp.calendar_types(3, 201, 'event'))
          and not ('privacy_incident' = any (pg_temp.calendar_types(3, 201, 'event'))),
  'an administrator finds what their rights read, and not the rest');
select ok('payment' = any (pg_temp.calendar_types(2, 202, 'event')), 'a member''s own ordinary events still come');

select * from finish();
rollback;
