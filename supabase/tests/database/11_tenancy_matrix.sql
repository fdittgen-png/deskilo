-- SPDX-License-Identifier: 0BSD
--
-- #1227 — the matrix, generated from the table list.
--
-- `10_tenancy_isolation.sql` proves the four tables a person would think
-- to check by hand. This file proves EVERY table that carries a
-- `workspace_id`, and it finds them by asking the catalogue rather than
-- by being edited — so a table added next year without isolation is a
-- red build on the day it is added, which is the whole property worth
-- having.
--
-- The rows are generic. For each table the seeder fills the columns that
-- are NOT NULL and have no default: `workspace_id` and any foreign key
-- to `workspaces` get workspace B, a foreign key to `members` gets B's
-- member, any other foreign key reuses a row this seeder already made,
-- a `text` column under a `check (col = any (array[…]))` takes the first
-- value that check allows, and everything else takes a harmless value of
-- its type. Six passes, because a table can only be filled once the
-- tables it points at are.
--
-- What it CANNOT fill it names. The count of covered tables is asserted
-- with a floor rather than an equality: coverage may go up and must not
-- go down, and the list of the ones still missed is printed by the
-- diagnostic at the end so the next person knows what to hand-seed.
begin;
select plan(7);

create or replace function pg_temp.fill(p_ws uuid, p_member uuid)
returns text[] language plpgsql as $fill$
declare
  pass int; progress boolean; t record; col record;
  cols text; vals text; v text; new_id uuid; ok boolean;
  seeded text[] := '{}'; allowed text;
begin
  for pass in 1..6 loop
    progress := false;
    for t in
      select c.oid, c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
       where n.nspname = 'public' and c.relkind = 'r'
         and c.relname not in ('members', 'workspaces')
         and exists (select 1 from pg_attribute a
                      where a.attrelid = c.oid and a.attname = 'workspace_id'
                        and a.attnum > 0 and not a.attisdropped)
         and not (c.relname = any(seeded))
       order by c.relname
    loop
      cols := ''; vals := ''; ok := true;
      for col in
        select a.attname, format_type(a.atttypid, a.atttypmod) as typ,
               (select cl.relname from pg_constraint k join pg_class cl on cl.oid = k.confrelid
                 where k.conrelid = t.oid and k.contype = 'f'
                   and a.attnum = any(k.conkey) limit 1) as fk
          from pg_attribute a
         where a.attrelid = t.oid and a.attnum > 0 and not a.attisdropped
           and a.attnotnull
           and not exists (select 1 from pg_attrdef d
                            where d.adrelid = a.attrelid and d.adnum = a.attnum)
         order by a.attnum
      loop
        if col.attname = 'workspace_id' or col.fk = 'workspaces' then
          v := quote_literal(p_ws) || '::uuid';
        elsif col.fk = 'members' then
          v := quote_literal(p_member) || '::uuid';
        elsif col.fk is not null then
          select id::text into v from pg_temp.seed_ids where tbl = col.fk limit 1;
          if v is null then ok := false; exit; end if;
          v := quote_literal(v) || '::uuid';
        elsif col.typ ~ '^(text|character)' then
          select (regexp_match(pg_get_constraintdef(k.oid),
                               '''([a-zA-Z0-9_-]+)''::text'))[1]
            into allowed
            from pg_constraint k
           where k.conrelid = t.oid and k.contype = 'c'
             and pg_get_constraintdef(k.oid) like '%' || col.attname || '%'
             and pg_get_constraintdef(k.oid) like '%ANY (ARRAY%'
           limit 1;
          v := quote_literal(coalesce(allowed, 'x'));
        elsif col.typ ~ '^json' then v := quote_literal('{}') || '::jsonb';
        elsif col.typ ~ '^bool' then v := 'false';
        elsif col.typ ~ '^(small|big)?int' then v := '1';
        elsif col.typ ~ '^numeric' then v := '0';
        elsif col.typ ~ '^timestamp' then v := 'now()';
        elsif col.typ ~ '^date' then v := 'current_date';
        elsif col.typ ~ '\[\]$' then v := quote_literal('{}') || '::' || col.typ;
        elsif col.typ = 'uuid' then v := quote_literal(gen_random_uuid()) || '::uuid';
        else ok := false; exit;
        end if;
        cols := cols || case when cols = '' then '' else ', ' end || quote_ident(col.attname);
        vals := vals || case when vals = '' then '' else ', ' end || v;
      end loop;
      if not ok then continue; end if;
      begin
        execute format('insert into public.%I (%s) values (%s) returning id',
                       t.relname, cols, vals) into new_id;
        seeded := seeded || t.relname;
        insert into pg_temp.seed_ids values (t.relname, new_id);
        progress := true;
      exception when others then
        -- A check constraint, a unique index or a trigger this seeder
        -- cannot satisfy. Named in the diagnostic, not swallowed.
        null;
      end;
    end loop;
    exit when not progress;
  end loop;
  return seeded;
end;
$fill$;

create temp table seed_ids (tbl text, id uuid) on commit drop;

do $seed$
declare
  u_a uuid := '00000000-0000-4000-8000-0000000000a1';
  u_b uuid := '00000000-0000-4000-8000-0000000000b1';
  ws_a uuid; ws_b uuid; m_a uuid; m_b uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u_a, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'matrix-a@deskilo.test', '', now(), now(), now()),
         (u_b, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'matrix-b@deskilo.test', '', now(), now(), now());
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Matrix A', 'FR', 'EUR', 'Europe/Paris', u_a) returning id into ws_a;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Matrix B', 'FR', 'EUR', 'Europe/Paris', u_b) returning id into ws_b;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws_a, u_a, true, true) returning id into m_a;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws_b, u_b, true, true) returning id into m_b;
  insert into pg_temp.seed_ids values ('workspaces', ws_b), ('members', m_b);

  -- The money tables the generic seeder cannot reach: a check constraint
  -- on `kind`, a signature, a document number. They are also the ones it
  -- would be least acceptable to leave uncovered.
  insert into public.ledger_entries (workspace_id, member_id, kind, category,
                                     amount_cents, description, period)
  values (ws_b, m_b, 'charge', 'subscription', 20000, 'B subscription', '2026-09');
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number,
                               title, lines, total_cents, currency, member_name,
                               workspace_name, issuer_name, signature)
  values (ws_b, m_b, m_b, 'B-1', 'B', '[]'::jsonb, 20000, 'EUR', 'B',
          'Matrix B', 'B', 'sig');
  -- `reservations_one_target` wants exactly one of seat/desk/office/level,
  -- or a free-text space label. The label is the one shape that needs no
  -- floor plan, and this seed runs before the generic pass builds one.
  insert into public.reservations (workspace_id, member_id, starts_at, ends_at,
                                   space_label)
  values (ws_b, m_b, now() + interval '1 day',
          now() + interval '1 day 4 hours', 'Matrix seat');

  perform set_config('deskilo.matrix.ws_a', ws_a::text, false);
  perform set_config('deskilo.matrix.ws_b', ws_b::text, false);
  perform set_config('deskilo.matrix.u_a', u_a::text, false);
  perform set_config('deskilo.matrix.m_b', m_b::text, false);
  perform set_config('deskilo.matrix.filled',
    array_to_string(pg_temp.fill(ws_b, m_b) ||
                    array['ledger_entries', 'invoices', 'reservations'], ','), false);
end;
$seed$;

-- What did we actually cover, and what is still out of reach?
create or replace function pg_temp.covered() returns text[] language sql as $$
  select string_to_array(current_setting('deskilo.matrix.filled'), ',');
$$;

create or replace function pg_temp.uncovered() returns text[] language sql as $$
  select coalesce(array_agg(c.relname order by c.relname), '{}')
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'r'
     and c.relname not in ('members', 'workspaces')
     and exists (select 1 from pg_attribute a
                  where a.attrelid = c.oid and a.attname = 'workspace_id'
                    and a.attnum > 0 and not a.attisdropped)
     and not (c.relname = any(pg_temp.covered()));
$$;

-- Read every covered table as a member of A. A table that returns a row
-- of workspace B is a leak; a table that refuses the read outright (the
-- grant is revoked) is a stronger pass, not a failure.
create or replace function pg_temp.leaks(p_role text, p_claims text)
returns text[] language plpgsql as $leaks$
declare v text; n int; out text[] := '{}';
begin
  perform set_config('request.jwt.claims', p_claims, true);
  execute format('set local role %I', p_role);
  foreach v in array pg_temp.covered() loop
    begin
      execute format('select count(*) from public.%I where workspace_id = %L',
                     v, current_setting('deskilo.matrix.ws_b')) into n;
      if n <> 0 then out := out || v; end if;
    exception
      when insufficient_privilege then null;  -- closed at the grant layer
      when undefined_table then null;
    end;
  end loop;
  reset role;
  return out;
end;
$leaks$;

select is(
  pg_temp.leaks('authenticated',
    json_build_object('sub', current_setting('deskilo.matrix.u_a'),
                      'role', 'authenticated')::text),
  '{}'::text[],
  'no table with a workspace_id shows a member of A a row of workspace B');

select is(
  pg_temp.leaks('anon', json_build_object('role', 'anon')::text),
  '{}'::text[],
  'and an anonymous caller sees none of them either');

-- #1335 — reading was never the whole of isolation. A member of A must
-- not change or remove a row of B either. Each probe runs in its own
-- subtransaction that is always rolled back, so a probe that DID write
-- cannot disturb the next one; the count it saw is what is judged. A
-- refusal at the grant layer, or by a trigger or constraint, is a pass.
create or replace function pg_temp.write_leaks(p_role text, p_claims text)
returns text[] language plpgsql as $writes$
declare v text; verb text; n int; out text[] := '{}';
begin
  perform set_config('request.jwt.claims', p_claims, true);
  execute format('set local role %I', p_role);
  foreach v in array pg_temp.covered() loop
    foreach verb in array array['update', 'delete'] loop
      n := 0;
      begin
        if verb = 'update' then
          execute format('with w as (update public.%I set workspace_id = workspace_id '
                         'where workspace_id = %L returning 1) select count(*) from w',
                         v, current_setting('deskilo.matrix.ws_b')) into n;
        else
          execute format('with w as (delete from public.%I where workspace_id = %L '
                         'returning 1) select count(*) from w',
                         v, current_setting('deskilo.matrix.ws_b')) into n;
        end if;
        raise exception using errcode = 'P0B35', message = 'undo the probe';
      exception
        when sqlstate 'P0B35' then null;
        when others then null;
      end;
      if n > 0 then out := out || (verb || ' ' || v); end if;
    end loop;
  end loop;
  reset role;
  return out;
end;
$writes$;

select is(
  pg_temp.write_leaks('authenticated',
    json_build_object('sub', current_setting('deskilo.matrix.u_a'),
                      'role', 'authenticated')::text),
  '{}'::text[],
  'no table with a workspace_id lets a member of A update or delete a row of workspace B');

select is(
  pg_temp.write_leaks('anon', json_build_object('role', 'anon')::text),
  '{}'::text[],
  'and an anonymous caller can change none of them either');

-- The floor. It may rise; it may not fall. When it does fall, the
-- diagnostic below names the table that stopped being coverable.
select cmp_ok(array_length(pg_temp.covered(), 1), '>=', 30,
  'the sweep covers at least 30 of the workspace-scoped tables');

select diag('tenancy matrix: ' || array_length(pg_temp.covered(), 1)
  || ' tables covered; still hand-seed these to raise the floor: '
  || array_to_string(pg_temp.uncovered(), ', '));

-- The positive control, without which every assertion above is also true
-- of a database with no rows in it at all.
do $be_a$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('deskilo.matrix.u_a'),
                      'role', 'authenticated')::text, false);
end;
$be_a$;
set local role authenticated;

select is(
  (select count(*) from public.workspaces
    where id = current_setting('deskilo.matrix.ws_a')::uuid)::int,
  1, 'the positive control: A does read its own workspace');

reset role;

-- And the last one: the seeder is not allowed to quietly stop working.
-- If it seeds nothing, every leak check passes vacuously.
select cmp_ok(
  (select count(*)::int from public.reservations
    where workspace_id = current_setting('deskilo.matrix.ws_b')::uuid),
  '>=', 1,
  'the seed really wrote rows into workspace B');

select * from finish();
rollback;
