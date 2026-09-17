-- SPDX-License-Identifier: 0BSD
-- risk: additive
--
-- 0231 (#1280 S3) — publishing a template chooses its groups, and shows
-- the publisher what travels, what never does, and which names go with
-- the plan.
--
-- `save_workspace_as_template` published every allowed entity. The publish
-- flow lets an owner choose groups (a template of opening hours alone, say),
-- so it gains `p_groups text[] default null` — null publishes everything
-- allowed, as before.
--
-- `template_publication_preview(workspace, groups)` answers, before
-- anything is written:
--
--   * `published` — the entities the chosen groups would carry, with the
--     keys stripped from each;
--   * `never_published` — every entity the allow-list denies, with its
--     reason, whatever groups were chosen: the publisher sees what stays
--     home;
--   * `plan_names` — the level, room, desk and seat names the floor plan
--     would publish. Names cannot be stripped because the merge matches by
--     name (#1276 decision 4), so the publisher is shown them instead.
--
-- Both ask the same question the save asks: an owner of the source.

drop function if exists public.save_workspace_as_template(uuid, text, text, text, text, text[]);

create or replace function public.save_workspace_as_template(
  p_workspace_id uuid,
  p_key text,
  p_name text,
  p_description text default '',
  p_visibility text default 'private',
  p_tags text[] default '{}',
  p_groups text[] default null
) returns uuid
language plpgsql security definer set search_path = public as $fn$
declare
  v_plan jsonb := '[]'::jsonb;
  v_config jsonb;
  v_publishable text[];
  v_id uuid;
begin
  if auth.uid() is null or not public.is_owner_of(p_workspace_id) then
    raise exception 'only an owner publishes a template from a workspace';
  end if;
  if p_visibility not in ('private', 'shared', 'public') then
    raise exception 'a workspace cannot publish a % template', p_visibility;
  end if;
  if p_key !~ '^[a-z][a-z0-9_]{0,39}$' then
    raise exception 'a template key is lower-case letters, digits and underscores';
  end if;
  if coalesce(trim(p_name), '') = '' then
    raise exception 'a template needs a name';
  end if;

  select array_agg(r.k) into v_publishable
    from jsonb_each(public.template_publication_rules()) r(k, v)
   where (r.v->>'allowed')::boolean
     and (p_groups is null or exists (
           select 1 from jsonb_array_elements(public.deployable_entities()) e
            where e.value->>'key' = r.k and (e.value->>'group') = any (p_groups)));
  if v_publishable is null then
    raise exception 'the chosen groups carry nothing that may be published';
  end if;

  if 'floor_plan' = any (v_publishable) then
    v_plan := public.strip_template_plan(public.export_floor_plan(p_workspace_id));
  end if;
  v_config := public.strip_template_configuration(
    public.export_entities(p_workspace_id, v_publishable), v_publishable);
  if jsonb_array_length(v_plan) = 0 then
    v_config := jsonb_set(v_config, '{entities}',
      coalesce((select jsonb_agg(e) from jsonb_array_elements_text(v_config->'entities') e
                 where e <> 'floor_plan'), '[]'::jsonb));
  end if;
  if jsonb_array_length(v_config->'entities') = 0 then
    raise exception 'the chosen groups carry nothing that may be published';
  end if;

  insert into public.workspace_templates
    (key, name, description, visibility, owner_workspace_id, floor_plan,
     configuration, entities, tags)
  values
    (p_key, left(trim(p_name), 80), left(coalesce(p_description, ''), 400),
     p_visibility, p_workspace_id, v_plan,
     v_config - 'entities',
     array(select jsonb_array_elements_text(v_config->'entities')),
     coalesce(p_tags, '{}'))
  on conflict (owner_workspace_id, key) where owner_workspace_id is not null
  do update set name             = excluded.name,
                description      = excluded.description,
                visibility       = excluded.visibility,
                floor_plan       = excluded.floor_plan,
                configuration    = excluded.configuration,
                entities         = excluded.entities,
                tags             = excluded.tags,
                template_version = public.workspace_templates.template_version + 1
  returning id into v_id;
  return v_id;
end $fn$;

revoke execute on function public.save_workspace_as_template(uuid, text, text, text, text, text[], text[])
  from public, anon;
grant execute on function public.save_workspace_as_template(uuid, text, text, text, text, text[], text[])
  to authenticated;

create or replace function public.template_publication_preview(
  p_workspace_id uuid,
  p_groups text[] default null
) returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_rules jsonb := public.template_publication_rules();
  v_entity jsonb;
  v_rule jsonb;
  v_published jsonb := '[]'::jsonb;
  v_never jsonb := '[]'::jsonb;
  v_names jsonb := '[]'::jsonb;
begin
  if auth.uid() is null or not public.is_owner_of(p_workspace_id) then
    raise exception 'only an owner publishes a template from a workspace';
  end if;
  for v_entity in select value from jsonb_array_elements(public.deployable_entities()) loop
    v_rule := v_rules -> (v_entity->>'key');
    if v_rule is null or not coalesce((v_rule->>'allowed')::boolean, false) then
      v_never := v_never || jsonb_build_object(
        'entity', v_entity->>'key', 'group', v_entity->>'group',
        'reason', coalesce(v_rule->>'reason', 'not classified for publication'));
    elsif p_groups is null or (v_entity->>'group') = any (p_groups) then
      v_published := v_published || jsonb_build_object(
        'entity', v_entity->>'key', 'group', v_entity->>'group',
        'stripped', coalesce(v_rule->'strip_keys', '[]'::jsonb));
    end if;
  end loop;

  if exists (select 1 from jsonb_array_elements(v_published) p where p.value->>'entity' = 'floor_plan') then
    select coalesce(jsonb_agg(n order by n), '[]'::jsonb) into v_names
      from (select distinct regexp_replace(r.key, '^.*[:/]', '') as n
              from public.floor_plan_rows(public.export_floor_plan(p_workspace_id)) r
             where r.key !~ '^I:' and r.key !~ 'xy:[^/]*$') names
     where n <> '';
  end if;

  return jsonb_build_object('published', v_published,
                            'never_published', v_never,
                            'plan_names', v_names);
end $fn$;

revoke execute on function public.template_publication_preview(uuid, text[]) from public, anon;
grant execute on function public.template_publication_preview(uuid, text[]) to authenticated;

select public.set_deskilo_schema_version(231);
