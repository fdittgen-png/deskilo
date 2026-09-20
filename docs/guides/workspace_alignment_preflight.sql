-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1285 S1 — the read-only preflight of docs/guides/WORKSPACE_ALIGNMENT.md.
--
-- It infers nothing. Every target is a parameter the operator sets by hand
-- in the same transaction; one missing parameter stops the run, and so does
-- one that disagrees with the database. It writes nothing: the block ends in
-- `raise exception`, so the transaction aborts even if a write were added by
-- mistake. Run it, read the report into the review packet, and run it again
-- after the change — the digests are what "unchanged" means.
--
--   begin;
--   set local alignment.backend_system_id = '...';  -- select system_identifier from pg_control_system()
--   set local alignment.environment       = 'prod'; -- workspaces.environment
--   set local alignment.workspace_id      = '...';
--   set local alignment.twin_id           = '...';  -- or 'none' when unpaired
--   set local alignment.template_key      = 'association_fr';
--   set local alignment.groups            = 'wording,hours_booking,pricing_credits,roles_access';
--   set local alignment.plan_ids          = 'none'; -- obsolete, unreferenced plans, by id
--   set local alignment.package_ids       = 'none';
--   set local alignment.level_ids         = 'none'; -- levels that lose whole-level booking
--   set local alignment.holiday_plan      = 'skip'; -- skip | enable_control | apply_group
--   \i docs/guides/workspace_alignment_preflight.sql
--   rollback;
do $preflight$
declare
  p_workspace_id uuid; p_twin_id uuid; p_groups text[];
  p_plan_ids uuid[]; p_package_ids uuid[]; p_level_ids uuid[];
  v_p jsonb := '{}'::jsonb; v_missing text[] := '{}'; v_stop text[] := '{}';
  v_report jsonb := '{}'::jsonb; v_data jsonb := '{}'::jsonb;
  v_ws public.workspaces; v_tpl public.workspace_templates;
  v_snap jsonb; v_flags jsonb; v_preview jsonb; v_k text; v_n bigint; v_digest text; v_years int;
begin
  -- 0 ─ the parameters, all of them, or nothing happens
  foreach v_k in array array['backend_system_id', 'environment', 'workspace_id', 'twin_id',
                             'template_key', 'groups', 'plan_ids', 'package_ids', 'level_ids',
                             'holiday_plan'] loop
    if coalesce(current_setting('alignment.' || v_k, true), '') = '' then
      v_missing := v_missing || v_k;
    else
      v_p := v_p || jsonb_build_object(v_k, current_setting('alignment.' || v_k, true));
    end if;
  end loop;
  if cardinality(v_missing) > 0 then
    raise exception 'PREFLIGHT STOP — parameters not set: %', array_to_string(v_missing, ', ');
  end if;
  p_workspace_id := (v_p->>'workspace_id')::uuid;
  p_twin_id      := nullif(v_p->>'twin_id', 'none')::uuid;
  p_groups       := string_to_array(v_p->>'groups', ',');
  p_plan_ids     := coalesce(string_to_array(nullif(v_p->>'plan_ids', 'none'), ',')::uuid[], '{}');
  p_package_ids  := coalesce(string_to_array(nullif(v_p->>'package_ids', 'none'), ',')::uuid[], '{}');
  p_level_ids    := coalesce(string_to_array(nullif(v_p->>'level_ids', 'none'), ',')::uuid[], '{}');

  -- 1 ─ the backend, before anything is read from it
  if (select system_identifier::text from pg_control_system()) <> (v_p->>'backend_system_id') then
    raise exception 'PREFLIGHT STOP — this connection is not the declared backend';
  end if;

  -- 2 ─ the target, named and never guessed
  select * into v_ws from public.workspaces where id = p_workspace_id;
  if not found then
    raise exception 'PREFLIGHT STOP — no workspace with that id on this backend';
  end if;
  if v_ws.environment is distinct from (v_p->>'environment') then
    v_stop := v_stop || format('environment: declared %s, found %s', v_p->>'environment', v_ws.environment);
  end if;
  if v_ws.pair_id is null and p_twin_id is not null then
    v_stop := v_stop || 'twin: a twin was declared but the target is unpaired'::text;
  elsif v_ws.pair_id is not null then
    if p_twin_id is null then
      v_stop := v_stop || 'twin: the target is paired and no twin was declared'::text;
    elsif not exists (select 1 from public.workspaces t
                       where t.id = p_twin_id and t.pair_id = v_ws.pair_id and t.id <> v_ws.id) then
      v_stop := v_stop || 'twin: the declared twin is not the other half of this pair'::text;
    end if;
    if (select count(*) from public.workspaces t where t.pair_id = v_ws.pair_id) <> 2 then
      v_stop := v_stop || 'twin: this pair does not hold exactly two workspaces'::text;
    end if;
  end if;
  select count(*) into v_n from public.workspaces w where w.name = v_ws.name;  -- a name is not an id
  v_report := jsonb_build_object('target', jsonb_build_object(
    'id', v_ws.id, 'environment', v_ws.environment, 'pair_id', v_ws.pair_id, 'twin', p_twin_id,
    'workspaces_sharing_this_name', v_n, 'country', v_ws.country_code, 'timezone', v_ws.timezone,
    'default_locale', coalesce(v_ws.default_locale, ''), 'booking_rules', v_ws.booking_rules));

  -- 3 ─ protected data: contents and relationships, never counts alone
  foreach v_k in array array['members', 'reservations', 'invoices', 'ledger_entries'] loop
    execute format(
      'select count(*), coalesce(md5(string_agg(md5(t::text), '''' order by md5(t::text))), ''empty'')'
      ' from public.%I t where t.workspace_id = $1', v_k)
      into v_n, v_digest using p_workspace_id;
    v_data := v_data || jsonb_build_object(v_k, jsonb_build_object('rows', v_n, 'digest', v_digest));
  end loop;
  v_report := v_report || jsonb_build_object('protected', v_data || jsonb_build_object(
    'members_on_a_plan', (select count(*) from public.members m
                           where m.workspace_id = p_workspace_id and m.plan_id is not null),
    'reservations_per_level', (select coalesce(jsonb_object_agg(l.name, x.c), '{}'::jsonb)
        from public.levels l cross join lateral (select count(*) c from public.reservations r
             where r.level_id = l.id) x where l.workspace_id = p_workspace_id),
    'invoices_per_member', (select coalesce(md5(string_agg(x.k, '|' order by x.k)), 'empty')
        from (select i.member_id::text || ':' || count(*)::text k from public.invoices i
               where i.workspace_id = p_workspace_id group by i.member_id) x)));

  -- 4 ─ the template, its compatibility, and the group that is refused
  select * into v_tpl from public.workspace_templates where key = (v_p->>'template_key');
  if not found then
    raise exception 'PREFLIGHT STOP — no template keyed %', v_p->>'template_key';
  end if;
  v_snap := public.template_snapshot(v_tpl, p_workspace_id);
  if 'space' = any (p_groups) then
    v_stop := v_stop || 'groups: `space` carries floor_plan, and merge_floor_plan matches level names — it adds the rest'::text;
  end if;
  begin  -- the preview reads the configuration, so it asks the export gate
    v_preview := public.configuration_group_states(public.configuration_change_set(
      p_workspace_id, v_snap, array(select jsonb_array_elements_text(
        public.template_compatibility(v_tpl, p_groups)->'selected')), 'merge'));
  exception when others then
    v_preview := jsonb_build_object('unavailable', sqlerrm);
    v_stop := v_stop || 'preview: not readable from this session — run the preflight as the owner who will apply'::text;
  end;
  v_report := v_report || jsonb_build_object('template', jsonb_build_object(
    'key', v_tpl.key, 'template_version', v_tpl.template_version,
    'compatibility', public.template_compatibility(v_tpl, p_groups),
    'preview', v_preview,
    'levels_it_would_add', (select coalesce(jsonb_agg(l->>'name'), '[]'::jsonb)
        from jsonb_array_elements(v_tpl.floor_plan) l
       where not exists (select 1 from public.levels t
                          where t.workspace_id = p_workspace_id and t.name = l->>'name'))));

  -- 5 ─ obsolete rows: by id, and only when nothing points at them
  v_report := v_report || jsonb_build_object('plans', (
    select coalesce(jsonb_agg(jsonb_build_object('id', p.id, 'active', p.active,
             'members_pointing_at_it', (select count(*) from public.members m where m.plan_id = p.id),
             'listed', p.id = any (p_plan_ids)) order by p.created_at), '[]'::jsonb)
      from public.plans p where p.workspace_id = p_workspace_id));
  if exists (select 1 from unnest(p_plan_ids) i
              where not exists (select 1 from public.plans p where p.id = i
                                 and p.workspace_id = p_workspace_id
                                 and not exists (select 1 from public.members m where m.plan_id = p.id))) then
    v_stop := v_stop || 'plans: a listed id is foreign to this workspace or still referenced by a member'::text;
  end if;
  v_report := v_report || jsonb_build_object('packages', (
    select coalesce(jsonb_agg(jsonb_build_object('id', k.id, 'active', k.active,
             'listed', k.id = any (p_package_ids)) order by k.created_at), '[]'::jsonb)
      from public.packages k where k.workspace_id = p_workspace_id));
  if exists (select 1 from unnest(p_package_ids) i
              where not exists (select 1 from public.packages k
                                 where k.id = i and k.workspace_id = p_workspace_id)) then
    v_stop := v_stop || 'packages: a listed id is foreign to this workspace'::text;
  end if;

  -- 6 ─ whole-level booking: the listed levels change, every other is preserved
  v_report := v_report || jsonb_build_object('levels', (
    select coalesce(jsonb_agg(jsonb_build_object('id', l.id, 'name', l.name,
             'bookable_as_whole', l.bookable_as_whole,
             'action', case when l.id = any (p_level_ids) then 'set false' else 'preserved' end)
           order by l.sort_order), '[]'::jsonb)
      from public.levels l where l.workspace_id = p_workspace_id));
  if exists (select 1 from unnest(p_level_ids) i
              where not exists (select 1 from public.levels l where l.id = i
                                 and l.workspace_id = p_workspace_id and l.bookable_as_whole)) then
    v_stop := v_stop || 'levels: a listed id is foreign to this workspace, or is already not bookable as a whole'::text;
  end if;

  -- 7 ─ the holidays: which control, which months, and never in silence
  v_flags := coalesce(v_snap->'workspace'->'feature_flags', '{}'::jsonb);
  v_years := greatest(coalesce((v_tpl.configuration->'holidays'->>'years')::int, 1), 1);
  v_report := v_report || jsonb_build_object('holidays', jsonb_build_object(
    'plan', v_p->>'holiday_plan',
    'control_enabled_now', public.feature_effective(p_workspace_id, 'publicHolidays'),
    'control_after_the_feature_map', case when 'roles_access' = any (p_groups)
        then coalesce(v_flags->'publicHolidays', 'null'::jsonb) else '"unchanged"'::jsonb end,
    'calendar_navigation_selected', 'calendar_navigation' = any (p_groups),
    'days_the_template_resolved', jsonb_array_length(coalesce(v_snap->'tables'->'closure_days', '[]'::jsonb)),
    'months_locked_by_an_invoice', (select coalesce(jsonb_agg(distinct i.period), '[]'::jsonb)
        from public.invoices i where i.workspace_id = p_workspace_id and i.period is not null),
    'months_eligible', (select coalesce(jsonb_agg(distinct to_char(h.day, 'YYYY-MM')), '[]'::jsonb)
        from generate_series(extract(year from now() at time zone v_ws.timezone)::int,
                             extract(year from now() at time zone v_ws.timezone)::int + v_years - 1) y
       cross join lateral public.public_holidays(coalesce(v_ws.country_code, ''), y) h
       where not exists (select 1 from public.invoices i where i.workspace_id = p_workspace_id
                          and i.period = to_char(h.day, 'YYYY-MM')))));
  if (v_p->>'holiday_plan') not in ('skip', 'enable_control', 'apply_group') then
    v_stop := v_stop || 'holidays: no decision recorded'::text;
  elsif (v_p->>'holiday_plan') = 'apply_group' and not ('calendar_navigation' = any (p_groups)) then
    v_stop := v_stop || 'holidays: apply_group without the calendar_navigation group'::text;
  elsif (v_p->>'holiday_plan') = 'enable_control' and 'roles_access' = any (p_groups)
        and coalesce((v_flags->>'publicHolidays')::boolean, true) is false then
    v_stop := v_stop || 'holidays: the feature map turns publicHolidays off, so the control would be hidden'::text;
  end if;

  raise exception 'PREFLIGHT % %',
    case when cardinality(v_stop) > 0 then 'STOP' else 'CLEAR' end,
    jsonb_pretty(v_report || jsonb_build_object('stop', to_jsonb(v_stop)));
end
$preflight$;
