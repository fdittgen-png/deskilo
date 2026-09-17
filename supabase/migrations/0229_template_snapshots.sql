-- SPDX-License-Identifier: 0BSD
-- risk: additive
--
-- 0229 (#1276 S2) — a template carries configuration, published through an
-- allow-list, applied as a merge, and it remembers being applied.
--
-- Until now a template was a floor plan and nothing else: hours, tariffs,
-- validation rules, the feature profile — none of it fit in
-- `workspace_templates.floor_plan`. The deployment engine already knows
-- every one of those as an entity (`deployable_entities()`), and 0219 gave
-- its importer a `merge` mode that never deletes or deactivates. A template
-- is that engine pointed at a stored snapshot.
--
-- ## Publication is a positive allow-list
--
-- `template_publication_rules()` classifies EVERY deployable entity: allowed,
-- allowed with keys removed, or denied with the reason. Denied for good:
-- payment instructions, VAT id, legal id, exemption reason, VAT account,
-- invoice legal mentions, the WhatsApp group, invitation templates, site
-- addresses, document links and designs that point at the source's own
-- files. `31_template_snapshots.sql` asserts every entity is classified, so an
-- entity added next year is unpublishable until somebody decides.
--
-- `strip_template_configuration` applies the rules SERVER-SIDE before the
-- row is written, where a client cannot skip it. Floor-plan names are kept
-- (merge_floor_plan matches by name) and shown to the publisher by #1280.
--
-- ## Applying
--
-- `apply_workspace_template(workspace, template, groups default null)`:
-- `manageConfiguration` on the target (owners always hold it) and a
-- readable template; a schema this build does not understand refuses with
-- `not supported`; the chosen groups' entities go through
-- `import_workspace_configuration(…, 'merge')` and the floor plan through
-- `merge_floor_plan`, exactly as before. Every application is recorded in
-- `workspace_template_applications` with what the target held before, so it
-- is reversible the way `rollback_deployment` reverses a deployment.
--
-- `tiny` and every template saved before this migration carry an empty
-- configuration and `{floor_plan}`: they apply exactly as they did.

alter table public.workspace_templates
  add column if not exists configuration jsonb not null default '{}'::jsonb,
  add column if not exists entities text[] not null default '{floor_plan}',
  add column if not exists schema_version int not null default 1,
  add column if not exists template_version int not null default 1,
  add column if not exists tags text[] not null default '{}';

comment on column public.workspace_templates.configuration is
  '#1276 — the stripped export (`workspace` keys and `tables`) of every '
  'entity in `entities` except the floor plan, which stays in `floor_plan`.';

-- ── what may be published ──────────────────────────────────────────────
create or replace function public.template_publication_rules()
returns jsonb
language sql
immutable
set search_path = public
as $$
  select jsonb_build_object(
    'identity', jsonb_build_object('allowed', true,
      'strip_keys', jsonb_build_array('address', 'street', 'postal_code', 'city',
        'vat_id', 'legal_id', 'tax_exemption_reason', 'vat_account',
        'invoice_legal', 'whatsapp_group'),
      'reason', 'only the default language and the VAT regime travel; the address, legal identifiers, legal mentions and the WhatsApp group are the source''s own'),
    'vat', jsonb_build_object('allowed', true),
    'tariffs', jsonb_build_object('allowed', true),
    'services', jsonb_build_object('allowed', true),
    'packages', jsonb_build_object('allowed', true),
    'accessories', jsonb_build_object('allowed', true),
    'floor_plan', jsonb_build_object('allowed', true,
      'reason', 'prices, image paths, the background and the site are removed by strip_template_plan; names are kept because the merge matches by name'),
    'sites', jsonb_build_object('allowed', false,
      'reason', 'sites carry street addresses, legal identifiers and VAT numbers'),
    'booking_rules', jsonb_build_object('allowed', true),
    'validation_rules', jsonb_build_object('allowed', true),
    'roles', jsonb_build_object('allowed', true,
      'reason', 'the role matrix only; nothing assigns a role to a person'),
    'payment_instructions', jsonb_build_object('allowed', false,
      'reason', 'bank details are the source''s own'),
    'reminders', jsonb_build_object('allowed', true),
    'document_design', jsonb_build_object('allowed', false,
      'reason', 'a design points at the source''s own image library in storage; it travels with the report design exchange instead'),
    'document_links', jsonb_build_object('allowed', false,
      'reason', 'links to the source''s own documents'),
    'closure_days', jsonb_build_object('allowed', true),
    'invitations', jsonb_build_object('allowed', false,
      'reason', 'invitation texts name the source space and its people'),
    'number_sequences', jsonb_build_object('allowed', true,
      'reason', 'formats only; counters never travel (#1295)'),
    'lexicon', jsonb_build_object('allowed', true),
    'features', jsonb_build_object('allowed', true)
  );
$$;

revoke execute on function public.template_publication_rules() from public, anon;
grant execute on function public.template_publication_rules() to authenticated;

-- ── stripping ──────────────────────────────────────────────────────────
create or replace function public.strip_template_configuration(
  p_export jsonb, p_entities text[])
returns jsonb
language plpgsql
immutable
set search_path = public
as $$
declare
  v_rules jsonb := public.template_publication_rules();
  v_ws jsonb := '{}'::jsonb;
  v_tables jsonb := '{}'::jsonb;
  v_kept text[] := '{}';
  v_entity jsonb;
  v_key text;
  v_rule jsonb;
begin
  for v_entity in select value from jsonb_array_elements(public.deployable_entities()) loop
    v_key := v_entity->>'key';
    if not v_key = any (coalesce(p_entities, '{}')) then continue; end if;
    v_rule := v_rules -> v_key;
    -- Unclassified is denied: a new entity is unpublishable until decided.
    if v_rule is null or not coalesce((v_rule->>'allowed')::boolean, false) then
      continue;
    end if;
    v_kept := v_kept || v_key;
    if v_key = 'floor_plan' then continue; end if;
    for v_key in select jsonb_array_elements_text(v_entity->'workspace_keys') loop
      if (p_export->'workspace') ? v_key
         and not coalesce(v_rule->'strip_keys', '[]'::jsonb) ? v_key then
        v_ws := v_ws || jsonb_build_object(v_key, p_export->'workspace'->v_key);
      end if;
    end loop;
    for v_key in select jsonb_array_elements_text(v_entity->'tables') loop
      if (p_export->'tables') ? v_key then
        v_tables := v_tables || jsonb_build_object(v_key, p_export->'tables'->v_key);
      end if;
    end loop;
  end loop;
  return jsonb_build_object('entities', to_jsonb(v_kept),
                            'workspace', v_ws, 'tables', v_tables);
end;
$$;

revoke execute on function public.strip_template_configuration(jsonb, text[]) from public, anon;

-- ── provenance ─────────────────────────────────────────────────────────
create table if not exists public.workspace_template_applications (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  template_id uuid references public.workspace_templates(id) on delete set null,
  template_key text not null,
  template_version int not null,
  schema_version int not null,
  groups text[] not null default '{}',
  entities text[] not null default '{}',
  change_set jsonb,
  before jsonb not null default '{}'::jsonb,
  applied_by uuid references auth.users(id) on delete set null,
  applied_at timestamptz not null default now()
);
select public.ensure_system_columns('workspace_template_applications');

alter table public.workspace_template_applications enable row level security;
drop policy if exists workspace_template_applications_select
  on public.workspace_template_applications;
create policy workspace_template_applications_select
  on public.workspace_template_applications
  for select to authenticated
  using (public.has_permission(workspace_id, 'manageConfiguration'));
revoke all on table public.workspace_template_applications from anon, authenticated;
grant select on table public.workspace_template_applications to authenticated;

-- ── the schema versions this build applies ────────────────────────────
create or replace function public.template_supported_schema_versions()
returns int[]
language sql
immutable
set search_path = public
as $$ select array[1] $$;

revoke execute on function public.template_supported_schema_versions() from public, anon;
grant execute on function public.template_supported_schema_versions() to authenticated;

-- ── publishing ─────────────────────────────────────────────────────────
drop function if exists public.save_workspace_as_template(uuid, text, text, text, text);

create or replace function public.save_workspace_as_template(
  p_workspace_id uuid,
  p_key text,
  p_name text,
  p_description text default '',
  p_visibility text default 'private',
  p_tags text[] default '{}'
) returns uuid
language plpgsql security definer set search_path = public as $fn$
declare
  v_plan jsonb;
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

  v_plan := public.strip_template_plan(public.export_floor_plan(p_workspace_id));
  select array_agg(k) into v_publishable
    from jsonb_each(public.template_publication_rules()) r(k, v)
   where (v->>'allowed')::boolean;
  v_config := public.strip_template_configuration(
    public.export_entities(p_workspace_id, v_publishable), v_publishable);
  if jsonb_array_length(v_plan) = 0 then
    v_config := jsonb_set(v_config, '{entities}',
      coalesce((select jsonb_agg(e) from jsonb_array_elements_text(v_config->'entities') e
                 where e <> 'floor_plan'), '[]'::jsonb));
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

revoke execute on function public.save_workspace_as_template(uuid, text, text, text, text, text[])
  from public, anon;
grant execute on function public.save_workspace_as_template(uuid, text, text, text, text, text[])
  to authenticated;

-- ── applying ───────────────────────────────────────────────────────────
drop function if exists public.apply_workspace_template(uuid, uuid);

create or replace function public.apply_workspace_template(
  p_workspace_id uuid,
  p_template_id uuid,
  p_groups text[] default null
) returns jsonb
language plpgsql security definer set search_path = public as $fn$
declare
  v_tpl public.workspace_templates;
  v_selected text[];
  v_table_entities text[];
  v_before jsonb;
  v_plan_result jsonb := null;
  v_config jsonb;
  v_tables jsonb := '{}'::jsonb;
  v_ws jsonb := '{}'::jsonb;
  v_entity jsonb;
  v_key text;
begin
  if auth.uid() is null
     or not public.has_permission(p_workspace_id, 'manageConfiguration') then
    raise exception 'only someone who configures this workspace applies a template';
  end if;
  if not public.workspace_template_readable(p_template_id) then
    raise exception 'unknown template';
  end if;
  select * into v_tpl from public.workspace_templates where id = p_template_id;
  if not v_tpl.schema_version = any (public.template_supported_schema_versions()) then
    raise exception 'not supported: template schema % is newer than this server', v_tpl.schema_version;
  end if;

  -- The entities of the chosen groups; all of the template's when none.
  select coalesce(array_agg(e->>'key'), '{}') into v_selected
    from jsonb_array_elements(public.deployable_entities()) e
   where (e->>'key') = any (v_tpl.entities)
     and (p_groups is null or (e->>'group') = any (p_groups));
  if cardinality(v_selected) = 0 then
    raise exception 'the template carries nothing in the chosen groups';
  end if;
  -- Fail closed on an entity this server does not know — unless the
  -- caller chose groups, which excludes it explicitly (it has no group).
  if p_groups is null then
    foreach v_key in array v_tpl.entities loop
      if not exists (select 1 from jsonb_array_elements(public.deployable_entities()) e
                      where e->>'key' = v_key) then
        raise exception 'not supported: this server has no entity %', v_key;
      end if;
    end loop;
  end if;

  v_table_entities := array(select k from unnest(v_selected) k where k <> 'floor_plan');
  -- What the target held, so the application can be reversed. Reading it
  -- asks exportData; a delegate who may configure but not export still
  -- applies, and the record says the snapshot was not theirs to take.
  begin
    v_before := public.export_entities(p_workspace_id, v_selected);
  exception when others then
    v_before := jsonb_build_object('unavailable', sqlerrm);
  end;

  if cardinality(v_table_entities) > 0 then
    for v_entity in select value from jsonb_array_elements(public.deployable_entities()) loop
      if not (v_entity->>'key') = any (v_table_entities) then continue; end if;
      for v_key in select jsonb_array_elements_text(v_entity->'workspace_keys') loop
        if (v_tpl.configuration->'workspace') ? v_key then
          v_ws := v_ws || jsonb_build_object(v_key, v_tpl.configuration->'workspace'->v_key);
        end if;
      end loop;
      for v_key in select jsonb_array_elements_text(v_entity->'tables') loop
        if (v_tpl.configuration->'tables') ? v_key then
          v_tables := v_tables || jsonb_build_object(v_key, v_tpl.configuration->'tables'->v_key);
        end if;
      end loop;
    end loop;
    v_config := jsonb_build_object('workspace', v_ws, 'tables', v_tables);
    perform public.import_workspace_configuration(p_workspace_id, v_config, 'merge');
  end if;

  if 'floor_plan' = any (v_selected) then
    v_plan_result := public.merge_floor_plan(p_workspace_id, v_tpl.floor_plan);
  end if;

  insert into public.workspace_template_applications
    (workspace_id, template_id, template_key, template_version, schema_version,
     groups, entities, before, applied_by)
  values
    (p_workspace_id, v_tpl.id, v_tpl.key, v_tpl.template_version, v_tpl.schema_version,
     coalesce(p_groups, '{}'), v_selected, v_before, auth.uid());

  -- The floor-plan merge's own result stays the answer for callers that
  -- only ever applied plans; the applied entities ride beside it.
  return coalesce(v_plan_result, '{}'::jsonb)
         || jsonb_build_object('applied_entities', to_jsonb(v_selected));
end $fn$;

revoke execute on function public.apply_workspace_template(uuid, uuid, text[]) from public, anon;
grant execute on function public.apply_workspace_template(uuid, uuid, text[]) to authenticated;

select public.set_deskilo_schema_version(229);
