-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3821 (0745, part of #3657): a permission refusal carries the code DKN01.
-- Structure: no permission sentence of the schema is raised without it.
-- The code tells a caller who is not allowed nothing the sentence did not:
-- no DETAIL, no HINT. Where a function answers the same for "not allowed"
-- and "does not exist", it still does, to the last field. The assistant's
-- outcome reads DKN01 as it reads P0001, reason included. Rolled back.
begin;
select plan(6);

-- The code, the detail, the hint and the message a statement is refused with.
create or replace function pg_temp.refusal(sql text) returns text language plpgsql as $f$
declare v_state text; v_detail text; v_hint text; v_message text;
begin
  execute sql;
  return 'no refusal';
exception when others then
  get stacked diagnostics v_state = returned_sqlstate, v_detail = pg_exception_detail,
                          v_hint = pg_exception_hint, v_message = message_text;
  return v_state || '|' || coalesce(v_detail, '') || '|' || coalesce(v_hint, '') || '|' || v_message;
end
$f$;

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare u_o uuid := '00000000-0000-4000-8000-0000038210a1'; u_m uuid := '00000000-0000-4000-8000-0000038210a2';
        ws uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  select x, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'not-allowed-' || x || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_m]) x;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Not allowed', 'FR', 'EUR', 'Europe/Paris', u_o) returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, status)
  values (ws, u_o, true, true, 'active'), (ws, u_m, false, false, 'active');
  perform set_config('t.ws', ws::text, false);
  perform set_config('t.m', u_m::text, false);
end;
$seed$;
select pg_temp.seed();

create or replace function pg_temp.as_member(sql text) returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('t.m'), 'role', 'authenticated')::text, true);
  set local role authenticated;
  v := pg_temp.refusal(sql);
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

select is((select string_agg(p.proname || ': ' || left(m[1], 80), E'\n')
             from pg_proc p join pg_namespace n on n.oid = p.pronamespace,
                  regexp_matches(p.prosrc, '(raise exception ''(?:[^'']|'''')*''[^;]*;)', 'g') m
            where n.nspname = 'public'
              and m[1] ~ '(not an admin of this workspace|not the owner of this workspace|admins only|platform owners only|only role managers may|only owners may|only admins may|only workspace settings managers may|not allowed to manage this profile|not allowed to read this profile)'
              and m[1] !~ 'errcode'), null,
  'no permission sentence is raised without its code');
select ok((select count(distinct p.oid) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' and p.prosrc ~ 'errcode = ''DKN01''') >= 56,
  'the fifty-six functions raise DKN01');

select is(pg_temp.as_member(format('select public.set_dev_mode(%L, true)', current_setting('t.ws'))),
  'DKN01|||not an admin of this workspace',
  'a member who is not allowed is told so by code, with no detail and no hint');
select is(pg_temp.as_member(format('select public.set_dev_mode(%L, true)', '00000000-0000-4000-8000-0000038210ff')),
          pg_temp.as_member(format('select public.set_dev_mode(%L, true)', current_setting('t.ws'))),
  'a workspace that does not exist gets the very same answer: the code tells the two apart no more than the sentence did');

select is(public.mcp_outcome_of('DKN01', 'not an admin of this workspace') ->> 'status',
          public.mcp_outcome_of('P0001', 'not an admin of this workspace') ->> 'status',
  'the assistant reads DKN01 as it read P0001');
select is(public.mcp_outcome_of('DKN01', 'not an admin of this workspace') -> 'data' ->> 'reason',
          'not an admin of this workspace', 'with its reason');

select * from finish();
rollback;
