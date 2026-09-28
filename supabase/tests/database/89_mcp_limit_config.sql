-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1630 / 0302: only a database administrator at AAL2 may set the MCP
-- limits, and only lower than the ceiling; nobody else, and not an
-- assistant.
begin;
select plan(6);

create function pg_temp.act_as(p_user uuid, p_aal text default 'aal2', p_client text default null)
returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_strip_nulls(jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', p_aal, 'client_id', p_client))::text, true);
  execute 'set local role authenticated';
end;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select ('00000000-0000-4000-8000-0000000302' || s)::uuid, '00000000-0000-0000-0000-000000000000', 'authenticated',
       'authenticated', s || '@l302.deskilo.test', '', now(), now(), now()
  from unnest(array['a1', 'b2']) s;
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer) values ('native', 'https://auth.deskilo.test/auth/v1');
select pg_temp.act_as('00000000-0000-4000-8000-0000000302a1'); select public.finalize_identity_binding();
select pg_temp.act_as('00000000-0000-4000-8000-0000000302b2'); select public.finalize_identity_binding();
reset role;
select public.operator_grant_database_admin('00000000-0000-4000-8000-0000000302a1', false);

select pg_temp.act_as('00000000-0000-4000-8000-0000000302b2');
select throws_ok($$select public.set_mcp_limits(30, 5, 5000)$$, 'P0001', 'not a database administrator here',
  'someone who is not a database administrator cannot set them');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-0000000302a1', 'aal1');
select throws_ok($$select public.set_mcp_limits(30, 5, 5000)$$, 'P0001',
  'a database decision needs a second factor (aal2)', 'an administrator needs the second factor');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-0000000302a1', 'aal2', 'claude-test');
select throws_ok($$select public.set_mcp_limits(30, 5, 5000)$$, 'P0001',
  'limits are set in the Deskilo app, not by an assistant', 'an assistant cannot set them');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-0000000302a1');
select throws_ok($$select public.set_mcp_limits(61, 5, 5000)$$, 'P0001',
  'a limit may only be lowered: at most 60 calls and 10 mutations a minute, 10000 calls a day',
  'raising a limit above the ceiling is refused');
select is(public.set_mcp_limits(30, 5, 5000)->>'mutations_per_minute', '5', 'lowering is allowed');
reset role;
select is((select calls_per_minute || '/' || mutations_per_minute || '/' || workspace_calls_per_day
             from public.mcp_limits), '30/5/5000', 'and it is what the facade now reads');

select * from finish();
rollback;
