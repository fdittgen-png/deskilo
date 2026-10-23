-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2867 — the setup guide and the readiness cards it replaced agree: for
-- every workspace, a step the guide derives from a readiness section reads
-- ready exactly when that section does (a step set aside or not used is
-- left out). Run as each workspace's owner, over every workspace there is,
-- so a detector that drifts from its section shows here. Rolls back.
begin;
select plan(3);

-- A fresh space of its own, so there is always something to compare, beside
-- every workspace the database already holds.
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
values ('00000000-0000-4000-8000-0000002867a1','00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated','a1@steps-match.test','',now(),now(),now());
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,booking_rules)
values ('00000000-0000-4000-8000-0000002867b1','Steps match','FR','EUR','Europe/Paris',
        '00000000-0000-4000-8000-0000002867a1','dev','{"open_weekdays":[1,2,3,4,5]}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000002867c1','00000000-0000-4000-8000-0000002867b1',
  '00000000-0000-4000-8000-0000002867a1',true,true,'active');

create temp table _cmp(workspace text, step text, step_state text, section_state text);

do $cmp$
declare r record; p record; v_st jsonb; v_rd jsonb; s jsonb; x jsonb;
begin
  for r in select w.id, w.name, m.user_id from public.workspaces w
             join lateral (select user_id from public.members
                            where workspace_id = w.id and is_owner and status = 'active'
                              and user_id is not null limit 1) m on true loop
    perform set_config('request.jwt.claims',
      json_build_object('sub', r.user_id, 'role', 'authenticated')::text, true);
    v_st := public.workspace_setup_status(r.id);
    v_rd := public.workspace_readiness(r.id);
    for p in select * from (values ('hours','region_rules'), ('places','resources'),
        ('member_rights','member_permissions'), ('invite','invitations'),
        ('pricing','pricing'), ('payment_methods','payments'),
        ('first_booking','first_booking'), ('recovery','recovery'),
        ('assistant','assistant')) t(step, section) loop
      select e into s from jsonb_array_elements(v_st->'steps') e where e->>'step' = p.step;
      select e into x from jsonb_array_elements(v_rd) e where e->>'section' = p.section;
      continue when s is null or x is null or s->>'state' in ('not_applicable', 'deferred');
      insert into _cmp values (r.name, p.step, s->>'state', x->>'state');
    end loop;
  end loop;
end $cmp$;

select ok((select count(*) from _cmp) > 0, 'there are steps to compare');
select ok((select count(distinct step) from _cmp) >= 5, 'most of the derived steps are compared');
select is(
  (select string_agg(workspace || ': ' || step || ' ' || step_state || ' / ' || section_state, '; ')
     from _cmp where (step_state = 'ready') <> (section_state = 'ready')),
  null,
  'every derived step is ready exactly when its readiness section is');

select * from finish();
rollback;
