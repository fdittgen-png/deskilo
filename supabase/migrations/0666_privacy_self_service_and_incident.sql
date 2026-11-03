-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- #3278 (1 of 2) -- direct access, and the privacy incident.
--
-- * `privacy.member_self_service` (default on, so nothing changes): when a
--   workspace turns it off, a member's own `export_my_data` and
--   `erase_my_membership` are refused by the SERVER (the export was only gated
--   by the client) and the answer says to file a rights request, which stays
--   always open (0327). An owner, or anyone `rights_controller` allows, is never
--   blocked.
-- * `record_privacy_incident`: the personal data admin or an owner records a
--   data breach, a wrong invoice or another incident; one applied event per
--   active holder of `managePrivacy` (owners and co-owners by default, plus
--   whoever the workspace gave the permission, directly or through a role)
--   tells them. The badge alert (0629, 0639) is the idiom; the event is read
--   by `managePrivacy` holders.

-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('privacy.member_self_service', 'bool', 'true'::jsonb, null, null, '', 'security', array['platform', 'workspace'], 'managePrivacy', null, true, null, 'export_my_data, erase_my_membership (#3278)', 'Whether a member exports and erases their own data directly from the app. Off: they file a rights request, which the personal data admin handles. Owners and the personal data admin are never blocked, and filing a request is always open.')
on conflict (key) do nothing;
-- END GENERATED SEED
create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
declare
  v_pattern text;
  v_out text;
begin
  if position(p_old in p_def) > 0 then
    return replace(p_def, p_old, p_new);
  end if;
  v_pattern := regexp_replace(btrim(p_old, E' \t\n'), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
  v_pattern := regexp_replace(v_pattern, '\s+', '\\s*', 'g');
  v_out := regexp_replace(p_def, v_pattern, replace(btrim(p_new, E' \t\n'), '\', '\\'), 'g');
  return case when v_out = p_def then null else v_out end;
end
$f$;

revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $migration$
declare
  v_def text;
  r record;
begin
  -- direct access, both doors, the same guard right after the caller is known
  for r in select * from (values
      ('public.export_my_data(uuid)', 'export_my_data'),
      ('public.erase_my_membership(uuid)', 'erase_my_membership')) c(sig, name) loop
    select pg_get_functiondef(r.sig::regprocedure) into v_def;
    v_def := pg_temp.anchor_replace(v_def,
      $a$v_me := public.my_active_member(p_workspace_id);$a$,
      $a$v_me := public.my_active_member(p_workspace_id);
  -- #3278: a workspace may turn direct access off; its controllers never are.
  if not coalesce((public.setting_value(p_workspace_id, 'privacy.member_self_service') #>> '{}')::boolean, true)
     and not public.rights_controller(p_workspace_id) then
    raise exception 'privacy_self_service_off: file a rights request instead'
      using errcode = '42501';
  end if;$a$);
    if v_def is null then raise exception '0666: % anchor missing', r.name; end if;
    execute v_def;
  end loop;

  -- the incident event type: both type checks, as 0629 and 0639 did
  for r in select * from (values
    ('events','events_type_check','type'),
    ('validation_policies','validation_policies_event_type_check','event_type')
  ) as c(table_name,constraint_name,column_name) loop
    select pg_get_constraintdef(oid) into v_def from pg_constraint
     where conrelid=('public.'||r.table_name)::regclass and conname=r.constraint_name;
    if v_def is null or position('CHECK (' in v_def) <> 1 then
      raise exception 'event type constraint anchor missing: %',r.constraint_name;
    end if;
    if position('privacy_incident' in v_def)=0 then
      execute format('alter table public.%I drop constraint %I',r.table_name,r.constraint_name);
      execute format('alter table public.%I add constraint %I ',r.table_name,r.constraint_name)
        || replace(v_def,'CHECK (',format('CHECK (%I = %L OR ',r.column_name,'privacy_incident'));
    end if;
  end loop;

  -- who reads it: whoever may handle personal data (the owner holds every
  -- permission). 0639's body, one branch more.
  select pg_get_functiondef('public.event_type_view_permissions(text)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$when p_type = 'payment_instructions_change'
      then array['manageIntegrations']$a$,
    $a$when p_type = 'payment_instructions_change'
      then array['manageIntegrations']
    when p_type = 'privacy_incident'
      then array['managePrivacy']$a$);
  if v_def is null then raise exception '0666: event_type_view_permissions anchor missing'; end if;
  execute v_def;
end
$migration$;

create or replace function public.record_privacy_incident(
  p_workspace_id uuid, p_kind text, p_note text default '')
returns integer language plpgsql security definer set search_path = public as $fn$
declare
  v_me public.members;
  v_note text := coalesce(btrim(p_note), '');
  v_told integer;
begin
  v_me := public.my_active_member(p_workspace_id);
  if not (public.is_owner_of(p_workspace_id)
          or public.has_permission(p_workspace_id, 'managePrivacy')) then
    raise exception 'not allowed to record a privacy incident' using errcode = '42501';
  end if;
  if p_kind is null or p_kind not in ('data_breach', 'wrong_invoice', 'other') then
    raise exception 'unknown incident kind' using errcode = '22023';
  end if;
  if length(v_note) > 1000 then
    raise exception 'the note is limited to 1000 characters' using errcode = '22023';
  end if;
  with told as (
    insert into public.events
      (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
    select p_workspace_id, 'privacy_incident', 'created', v_me.id, h.id,
           jsonb_build_object('kind', p_kind, 'note', v_note), 'applied'
      from public.members h
     where h.workspace_id = p_workspace_id and h.status = 'active'
       and public.member_has_permission(h.id, 'managePrivacy')
    returning 1)
  select count(*) into v_told from told;
  return v_told;
end $fn$;
revoke execute on function public.record_privacy_incident(uuid, text, text) from public, anon;
grant execute on function public.record_privacy_incident(uuid, text, text) to authenticated;

select public.set_deskilo_schema_version(666);
