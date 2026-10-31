-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2556 C1: the inbox read where each conversation lives. The personal
-- home answers my person-to-person conversations and groups
-- (my_account_inbox_v1), a workspace host my workspace conversations and
-- inquiries (my_workspace_inbox_v1); each names the role it answers in,
-- refuses a role its installation does not play, pages newest first by
-- (time, kind:id) and is read by a first-party session only. The legacy
-- my_inbox keeps answering both. Everything rolls back.
begin;
select plan(26);

create function pg_temp.id(p_tail text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00002556' || p_tail)::uuid $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.u(p_n int) returns uuid language sql as $$
  select pg_temp.id('e00' || p_n) $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.t(p_min int) returns timestamptz language sql as $$
  select timestamptz '2026-03-01 10:00:00+00' + make_interval(mins => p_min) $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
-- plpgsql: each call reads what earlier statements wrote.
create function pg_temp.inbox(p_reader text, p_user int default 1, p_at text default null,
  p_key text default null, p_extra jsonb default '{}') returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform set_config('request.jwt.claims', (jsonb_build_object('sub', pg_temp.u(p_user),
    'role', 'authenticated') || p_extra)::text, true);
  execute format('select public.%I($1::timestamptz, $2)', p_reader) into v using p_at, p_key;
  return v;
end $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
-- kind/tail of every row of a page, in order.
create function pg_temp.keys(p jsonb) returns text language sql as $$
  select coalesce(string_agg((e->>'context_kind') || '/' || right(e->>'context_id', 4), ','
                  order by o), '') from jsonb_array_elements(p->'items') with ordinality x(e, o) $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.row_of(p jsonb, p_tail text) returns jsonb language sql as $$
  select e from jsonb_array_elements(p->'items') e where right(e->>'context_id', 4) = p_tail $$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- ── fixtures ──────────────────────────────────────────────────────────
select public.operator_set_installation_roles(array['personal_home', 'workspace_host']);
update public.setting_definitions set default_value = '50'::jsonb where key = 'messaging.inbox_page_size';
insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || n || '-2556@deskilo.test', '', now(), now(), now()
  from generate_series(1, 4) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, environment)
values (pg_temp.id('f001'), 'Loft W', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'dev'),
       (pg_temp.id('f002'), 'Other W', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(4), 'dev');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status)
values (pg_temp.id('c001'), pg_temp.id('f001'), pg_temp.u(1), true, true, 'active'),
       (pg_temp.id('c002'), pg_temp.id('f001'), pg_temp.u(2), false, false, 'active'),
       (pg_temp.id('c004'), pg_temp.id('f002'), pg_temp.u(4), true, true, 'active');
-- Workspace conversations: d001 direct with u2, d002 a group I archive.
insert into public.conversations (id, workspace_id, kind, title, created_by)
values (pg_temp.id('d001'), pg_temp.id('f001'), 'direct', null, pg_temp.id('c001')),
       (pg_temp.id('d002'), pg_temp.id('f001'), 'group', 'Archived group', pg_temp.id('c001'));
insert into public.conversation_participants (conversation_id, member_id)
select c, m from unnest(array[pg_temp.id('d001'), pg_temp.id('d002')]) c,
                 unnest(array[pg_temp.id('c001'), pg_temp.id('c002')]) m;
insert into public.member_notes (workspace_id, from_member_id, body, conversation_id, created_at)
values (pg_temp.id('f001'), pg_temp.id('c002'), 'See you', pg_temp.id('d001'), pg_temp.t(4)),
       (pg_temp.id('f001'), pg_temp.id('c001'), 'Old news', pg_temp.id('d002'), pg_temp.t(1));
update public.conversation_participants set archived_at = now(), pinned_at = now()
 where conversation_id = pg_temp.id('d002') and member_id = pg_temp.id('c001');
-- Inquiries: 9001 mine to Other W (answered), 9002 u3's to Loft W, which I host.
insert into public.space_inquiries (id, workspace_id, requester_user_id)
values (pg_temp.id('9001'), pg_temp.id('f002'), pg_temp.u(1)),
       (pg_temp.id('9002'), pg_temp.id('f001'), pg_temp.u(3));
insert into public.space_inquiry_messages (inquiry_id, author_user_id, body, created_at)
values (pg_temp.id('9001'), pg_temp.u(4), 'Welcome', pg_temp.t(7)),
       (pg_temp.id('9002'), pg_temp.u(3), 'Can I visit?', pg_temp.t(0));
-- Person to person: a001 with u2 (accepted), a002 u3's request to me
-- (pending), a003 my request to u4 (pending).
insert into public.account_conversations (id, user_a, user_b, request_state, requested_by)
values (pg_temp.id('a001'), pg_temp.u(1), pg_temp.u(2), 'accepted', null),
       (pg_temp.id('a002'), pg_temp.u(1), pg_temp.u(3), 'pending', pg_temp.u(3)),
       (pg_temp.id('a003'), pg_temp.u(1), pg_temp.u(4), 'pending', pg_temp.u(1));
insert into public.account_messages (conversation_id, author_id, body, created_at)
values (pg_temp.id('a001'), pg_temp.u(2), 'Lunch?', pg_temp.t(5)),
       (pg_temp.id('a002'), pg_temp.u(3), 'Hello stranger', pg_temp.t(4)),
       (pg_temp.id('a003'), pg_temp.u(1), 'Hello there', pg_temp.t(3));
-- Groups: b001 and b003 I am in, b002 I left.
insert into public.account_groups (id, title, created_by)
select pg_temp.id('b00' || n), 'Group ' || n, pg_temp.u(2) from generate_series(1, 3) n;
insert into public.account_group_members (group_id, user_id, left_at)
values (pg_temp.id('b001'), pg_temp.u(1), null), (pg_temp.id('b001'), pg_temp.u(2), null),
       (pg_temp.id('b002'), pg_temp.u(1), now()), (pg_temp.id('b003'), pg_temp.u(1), null);
insert into public.account_group_messages (group_id, author_id, body, created_at)
values (pg_temp.id('b001'), pg_temp.u(2), 'Hi all', pg_temp.t(2)),
       (pg_temp.id('b002'), pg_temp.u(2), 'Gone', pg_temp.t(6)),
       (pg_temp.id('b003'), pg_temp.u(2), 'Same minute', pg_temp.t(3));

-- ── the door ──────────────────────────────────────────────────────────
select is(has_function_privilege('anon', 'public.my_account_inbox_v1(timestamptz,text)', 'EXECUTE')::text
          || ' ' || has_function_privilege('authenticated', 'public.my_account_inbox_v1(timestamptz,text)', 'EXECUTE')::text,
  'false true', 'authenticated alone reads the personal inbox');
select is(has_function_privilege('anon', 'public.my_workspace_inbox_v1(timestamptz,text)', 'EXECUTE')::text
          || ' ' || has_function_privilege('authenticated', 'public.my_workspace_inbox_v1(timestamptz,text)', 'EXECUTE')::text,
  'false true', 'authenticated alone reads the workspace inbox');

-- ── the personal home ─────────────────────────────────────────────────
select is(pg_temp.keys(pg_temp.inbox('my_account_inbox_v1')),
  'account/a001,account_group/b003,account/a003,account_group/b001',
  'my conversations and groups, newest first, equal times by key; no request to me, no group I left');
select is((pg_temp.row_of(pg_temp.inbox('my_account_inbox_v1'), 'a001')->>'unread') || ' '
          || (pg_temp.row_of(pg_temp.inbox('my_account_inbox_v1'), 'a001')->>'peer_id' = pg_temp.u(2)::text)::text,
  '1 true', 'a conversation names the other person and what I have not read');
select is(pg_temp.row_of(pg_temp.inbox('my_account_inbox_v1'), 'b001')->>'member_count', '2',
  'a group counts its members');
select is((select count(*)::int from jsonb_array_elements(pg_temp.inbox('my_account_inbox_v1')->'items') e
            where e->>'workspace_id' is not null), 0, 'no personal row names a workspace');

-- ── the workspace host ────────────────────────────────────────────────
select is(pg_temp.keys(pg_temp.inbox('my_workspace_inbox_v1')),
  'inquiry_out/9001,space/d001,space/d002,inquiry_in/9002',
  'my workspace conversations, archived too, and the inquiries I wrote and host; no personal row');
select is((pg_temp.row_of(pg_temp.inbox('my_workspace_inbox_v1'), 'd002')->>'archived') || ' '
          || (pg_temp.row_of(pg_temp.inbox('my_workspace_inbox_v1'), 'd002')->>'pinned') || ' '
          || (pg_temp.row_of(pg_temp.inbox('my_workspace_inbox_v1'), 'd001')->>'archived'),
  'true true false', 'a workspace conversation carries the flags the server keeps');
select is(pg_temp.row_of(pg_temp.inbox('my_workspace_inbox_v1'), 'd001')->>'workspace_ref',
  (select network_id from public.workspaces where id = pg_temp.id('f001')),
  'a workspace row names its workspace by network reference');
select is((pg_temp.row_of(pg_temp.inbox('my_workspace_inbox_v1'), 'd001')->>'unread') || ' '
          || (pg_temp.row_of(pg_temp.inbox('my_workspace_inbox_v1'), '9001')->>'unread'),
  '1 1', 'unread counts what the others wrote');

-- ── the envelope names its role ───────────────────────────────────────
select is((select string_agg(k, ',' order by k) from jsonb_object_keys(pg_temp.inbox('my_account_inbox_v1')) k),
  'has_more,installation_id,items,next_cursor,schema_version,source_role', 'no hidden total in the envelope');
select is((pg_temp.inbox('my_account_inbox_v1')->>'source_role') || ' '
          || (pg_temp.inbox('my_workspace_inbox_v1')->>'source_role') || ' '
          || (pg_temp.inbox('my_workspace_inbox_v1')->>'installation_id' = public.installation_id()::text)::text,
  'personal_home workspace_host true', 'each reader says which role and installation answered');

-- ── keyset paging ─────────────────────────────────────────────────────
update public.setting_definitions set default_value = '2'::jsonb where key = 'messaging.inbox_page_size';
select is(pg_temp.keys(pg_temp.inbox('my_account_inbox_v1')) || ' '
          || (pg_temp.inbox('my_account_inbox_v1')->>'has_more') || ' '
          || (pg_temp.inbox('my_account_inbox_v1')->'next_cursor'->>'before_key' = 'account_group:' || pg_temp.id('b003'))::text,
  'account/a001,account_group/b003 true true', 'a page of two, the cursor at its last row');
select is(pg_temp.keys(pg_temp.inbox('my_account_inbox_v1', 1,
            pg_temp.inbox('my_account_inbox_v1')->'next_cursor'->>'before_at',
            pg_temp.inbox('my_account_inbox_v1')->'next_cursor'->>'before_key')) || ' '
          || coalesce(pg_temp.inbox('my_account_inbox_v1', 1,
            pg_temp.inbox('my_account_inbox_v1')->'next_cursor'->>'before_at',
            pg_temp.inbox('my_account_inbox_v1')->'next_cursor'->>'before_key')->>'next_cursor', 'null'),
  'account/a003,account_group/b001 null', 'the next page continues past the tie and ends the list');
select is(pg_temp.keys(pg_temp.inbox('my_workspace_inbox_v1', 1,
            pg_temp.inbox('my_workspace_inbox_v1')->'next_cursor'->>'before_at',
            pg_temp.inbox('my_workspace_inbox_v1')->'next_cursor'->>'before_key')),
  'space/d002,inquiry_in/9002', 'the workspace inbox pages the same way');
update public.setting_definitions set default_value = '50'::jsonb where key = 'messaging.inbox_page_size';

-- ── another person reads only their own ──────────────────────────────
select is(pg_temp.keys(pg_temp.inbox('my_account_inbox_v1', 3)) || ' | '
          || pg_temp.keys(pg_temp.inbox('my_workspace_inbox_v1', 3)),
  'account/a002 | inquiry_out/9002', 'u3 reads their request and their inquiry, nothing of mine');

-- ── refusals ──────────────────────────────────────────────────────────
select throws_ok($$select pg_temp.inbox('my_account_inbox_v1', 1, '2026-03-01T10:00:00+00:00', null)$$,
  '22023', null, 'half a cursor');
select throws_ok(format($$select pg_temp.inbox('my_account_inbox_v1', 1, '2026-03-01T10:00:00+00:00', %L)$$,
  'space:' || pg_temp.id('d001')), '22023', null, 'a workspace key on the personal inbox');
select throws_ok(format($$select pg_temp.inbox('my_workspace_inbox_v1', 1, '2026-03-01T10:00:00+00:00', %L)$$,
  'account:' || pg_temp.id('a001')), '22023', null, 'a personal key on the workspace inbox');
select throws_ok($$select pg_temp.inbox('my_account_inbox_v1', p_extra => '{"client_id": "00000000-0000-4000-8000-00002556c099"}')$$,
  'P0001', 'connections are managed in the Deskilo app', 'a delegated assistant token reads no inbox');
select throws_ok($$select pg_temp.inbox('my_workspace_inbox_v1', p_extra => '{"role": "deskilo_identity"}')$$,
  'P0001', 'identity_session_refused', 'nor an upstream identity token');

-- ── an installation answers only the role it plays ────────────────────
-- Set at the row: the operator refuses to drop workspace_host while
-- workspaces exist, and the readers must refuse whatever the rows hold.
update public.installation_identity set roles = array['workspace_host'];
select throws_ok($$select pg_temp.inbox('my_account_inbox_v1')$$, '0A000', null,
  'a workspace host does not answer as a personal home');
update public.installation_identity set roles = array['personal_home'];
select throws_ok($$select pg_temp.inbox('my_workspace_inbox_v1')$$, '0A000', null,
  'a personal home alone answers no workspace inbox');
update public.installation_identity set roles = array['personal_home', 'workspace_host'];

-- ── the legacy inbox keeps answering both ─────────────────────────────
select set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(1), 'role', 'authenticated')::text, true);
select is(jsonb_array_length(public.my_inbox()), 5,
  'my_inbox still lists the personal and workspace rows, without the archived one and my groups');

-- ── as the API roles ──────────────────────────────────────────────────
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-00002556e001","role":"authenticated"}', true);
set local role authenticated;
select is(jsonb_array_length(public.my_account_inbox_v1()->'items'), 4, 'the signed-in person reads the personal inbox');
reset role;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select throws_ok($$select public.my_workspace_inbox_v1()$$, '42501', null,
  'an anonymous caller reads nothing');
reset role;
select set_config('request.jwt.claims', '', true);

select * from finish();
rollback;
