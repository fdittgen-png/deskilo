-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0250 (#1288 S5) — the questions travel with a template; the answers
-- never do.
--
-- A definition is configuration: what the space asks, in every language
-- it asks it, with its choices. An answer is a fact about a person, and
-- a person does not exist in the target workspace. So the entity carries
-- `workspace_field_definitions` and the tables beneath it, and nothing
-- reaches `workspace_field_values`.
--
-- **A type change under existing answers is a conflict, not a merge.**
-- `field_definition_conflicts` names every key whose type would change
-- while answers point at it, and the import refuses rather than
-- reinterpreting an answer as something it never was. #1276's change-set
-- shows it as `needs_attention`; a person decides.
--
-- Mirror mode DEACTIVATES a question the source no longer has rather
-- than deleting it, for the same reason the editor never deletes one:
-- deleting takes the answers with it, and somebody finds out months
-- later.
create or replace function public.field_definitions_export(p_workspace_id uuid)
returns jsonb
language sql stable security definer set search_path = public as $fn$
  select coalesce(jsonb_agg(jsonb_build_object(
      'key', d.key,
      'type', d.type,
      'required', d.required,
      'personal_data', d.personal_data,
      'visibility', d.visibility,
      'contexts', to_jsonb(d.contexts),
      'group_key', d.group_key,
      'sort_order', d.sort_order,
      'validation', d.validation,
      'active', d.active,
      'labels', (select coalesce(jsonb_object_agg(l.locale, jsonb_build_object(
                     'label', l.label, 'help_text', l.help_text)), '{}'::jsonb)
                   from public.workspace_field_labels l
                  where l.definition_id = d.id),
      'options', (select coalesce(jsonb_agg(jsonb_build_object(
                      'key', o.key, 'sort_order', o.sort_order, 'active', o.active,
                      'labels', (select coalesce(jsonb_object_agg(ol.locale, ol.label), '{}'::jsonb)
                                   from public.workspace_field_option_labels ol
                                  where ol.option_id = o.id))
                      order by o.sort_order, o.key), '[]'::jsonb)
                    from public.workspace_field_options o
                   where o.definition_id = d.id))
      order by d.group_key, d.sort_order, d.key), '[]'::jsonb)
    from public.workspace_field_definitions d
   where d.workspace_id = p_workspace_id;
$fn$;

-- No grant to `authenticated`: these are the innards of the
-- configuration transfer, called from `export_workspace_configuration`
-- and `import_workspace_configuration`, which check the caller. A
-- definer a client can call has to check for itself, and the honest
-- answer here is that a client has no business calling it.
revoke execute on function public.field_definitions_export(uuid) from public, anon, authenticated;

create or replace function public.field_definition_conflicts(
  p_workspace_id uuid, p_definitions jsonb
) returns jsonb
language sql stable security definer set search_path = public as $fn$
  select coalesce(jsonb_agg(jsonb_build_object(
      'key', d.key, 'from', d.type, 'to', e.value->>'type')), '[]'::jsonb)
    from jsonb_array_elements(coalesce(p_definitions, '[]'::jsonb)) e
    join public.workspace_field_definitions d
      on d.workspace_id = p_workspace_id and d.key = e.value->>'key'
   where d.type <> (e.value->>'type')
     and exists (select 1 from public.workspace_field_values v
                  where v.definition_id = d.id);
$fn$;

-- No grant to `authenticated`: these are the innards of the
-- configuration transfer, called from `export_workspace_configuration`
-- and `import_workspace_configuration`, which check the caller. A
-- definer a client can call has to check for itself, and the honest
-- answer here is that a client has no business calling it.
revoke execute on function public.field_definition_conflicts(uuid, jsonb) from public, anon, authenticated;

create or replace function public.field_definitions_import(
  p_workspace_id uuid, p_definitions jsonb, p_mode text
) returns void
language plpgsql security definer set search_path = public as $fn$
declare
  e jsonb;
  o jsonb;
  v_id uuid;
  v_locale text;
  v_conflicts jsonb;
begin
  if p_definitions is null then return; end if;

  v_conflicts := public.field_definition_conflicts(p_workspace_id, p_definitions);
  if jsonb_array_length(v_conflicts) > 0 then
    raise exception 'the answers already given do not fit: %', v_conflicts;
  end if;

  for e in select jsonb_array_elements(p_definitions) loop
    insert into public.workspace_field_definitions
      (workspace_id, key, type, required, personal_data, visibility, contexts,
       group_key, sort_order, validation, active)
    values (p_workspace_id, e->>'key', e->>'type',
            coalesce((e->>'required')::boolean, false),
            coalesce((e->>'personal_data')::boolean, true),
            coalesce(e->>'visibility', 'self'),
            coalesce((select array_agg(value) from jsonb_array_elements_text(e->'contexts')),
                     array['profile']::text[]),
            coalesce(e->>'group_key', 'general'),
            coalesce((e->>'sort_order')::int, 0),
            coalesce(e->'validation', '{}'::jsonb),
            coalesce((e->>'active')::boolean, true))
    on conflict (workspace_id, key) do update
      set type = excluded.type, required = excluded.required,
          personal_data = excluded.personal_data, visibility = excluded.visibility,
          contexts = excluded.contexts, group_key = excluded.group_key,
          sort_order = excluded.sort_order, validation = excluded.validation,
          active = excluded.active
    returning id into v_id;

    delete from public.workspace_field_labels where definition_id = v_id;
    for v_locale in select jsonb_object_keys(coalesce(e->'labels', '{}'::jsonb)) loop
      insert into public.workspace_field_labels
        (workspace_id, definition_id, locale, label, help_text)
      values (p_workspace_id, v_id, v_locale,
              e->'labels'->v_locale->>'label',
              coalesce(e->'labels'->v_locale->>'help_text', ''));
    end loop;

    for o in select jsonb_array_elements(coalesce(e->'options', '[]'::jsonb)) loop
      insert into public.workspace_field_options
        (workspace_id, definition_id, key, sort_order, active)
      values (p_workspace_id, v_id, o->>'key',
              coalesce((o->>'sort_order')::int, 0),
              coalesce((o->>'active')::boolean, true))
      on conflict (definition_id, key) do update
        set sort_order = excluded.sort_order, active = excluded.active;
      delete from public.workspace_field_option_labels ol
       using public.workspace_field_options po
       where po.id = ol.option_id and po.definition_id = v_id and po.key = o->>'key';
      for v_locale in select jsonb_object_keys(coalesce(o->'labels', '{}'::jsonb)) loop
        insert into public.workspace_field_option_labels
          (workspace_id, option_id, locale, label)
        select p_workspace_id, po.id, v_locale, o->'labels'->>v_locale
          from public.workspace_field_options po
         where po.definition_id = v_id and po.key = o->>'key';
      end loop;
    end loop;
  end loop;

  if p_mode = 'mirror' then
    update public.workspace_field_definitions d set active = false
     where d.workspace_id = p_workspace_id
       and not exists (select 1 from jsonb_array_elements(p_definitions) e
                        where e.value->>'key' = d.key);
  end if;
end $fn$;

-- No grant to `authenticated`: these are the innards of the
-- configuration transfer, called from `export_workspace_configuration`
-- and `import_workspace_configuration`, which check the caller. A
-- definer a client can call has to check for itself, and the honest
-- answer here is that a client has no business calling it.
revoke execute on function public.field_definitions_import(uuid, jsonb, text) from public, anon, authenticated;

-- ── the entity, the export and the import ────────────────────────────
create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text language plpgsql as $f$
begin
  if position(p_old in p_def) = 0 then return null; end if;
  return replace(p_def, p_old, p_new);
end
$f$;

revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $migration$
declare
  v_def text;
  v_patched text;
  v_missing text[] := '{}';
begin
  v_def := pg_get_functiondef('public.deployable_entities()'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    $a$    jsonb_build_object('key', 'features'$a$,
    $a$    jsonb_build_object('key', 'field_definitions', 'kind', 'configuration',
      'requires', '[]'::jsonb, 'merge_policy', 'keyed_update', 'group', 'forms',
      'workspace_keys', '[]'::jsonb,
      'tables', '["workspace_field_definitions"]'::jsonb),
    jsonb_build_object('key', 'features'$a$);
  if v_patched is null then v_missing := v_missing || 'entities'::text;
  else execute v_patched; end if;

  v_def := pg_get_functiondef('public.entity_row_key(text, jsonb)'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    $a$    when 'number_sequences' then p_row->>'journal'$a$,
    $a$    when 'number_sequences' then p_row->>'journal'
    when 'workspace_field_definitions' then p_row->>'key'$a$);
  if v_patched is null then v_missing := v_missing || 'row_key'::text;
  else execute v_patched; end if;

  v_def := pg_get_functiondef('public.export_workspace_configuration(uuid)'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    $a$      'closure_days', coalesce((select jsonb_agg(jsonb_build_object($a$,
    $a$      'workspace_field_definitions',
        public.field_definitions_export(p_workspace_id),
      'closure_days', coalesce((select jsonb_agg(jsonb_build_object($a$);
  if v_patched is null then v_missing := v_missing || 'export'::text;
  else execute v_patched; end if;

  -- Every deployable entity is classified for publication
  -- (`31_template_snapshots`), and a question is a form, not a secret:
  -- it names what the space asks, in the languages it asks it. What a
  -- published template must never carry is an ANSWER, and the entity
  -- does not reach the values table at all.
  v_def := pg_get_functiondef('public.template_publication_rules()'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    $a$    'features', jsonb_build_object('allowed', true)$a$,
    $a$    'field_definitions', jsonb_build_object('allowed', true,
      'reason', 'the questions and their wording; an answer is a fact about a person and never travels (#1288)'),
    'features', jsonb_build_object('allowed', true)$a$);
  if v_patched is null then v_missing := v_missing || 'publication'::text;
  else execute v_patched; end if;

  v_def := pg_get_functiondef('public.import_workspace_configuration(uuid, jsonb, text)'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    $a$  if v_t ? 'closure_days' then$a$,
    $a$  if v_t ? 'workspace_field_definitions' then
    perform public.field_definitions_import(
      p_workspace_id, v_t->'workspace_field_definitions', p_mode);
  end if;

  if v_t ? 'closure_days' then$a$);
  if v_patched is null then v_missing := v_missing || 'import'::text;
  else execute v_patched; end if;

  if cardinality(v_missing) > 0 then
    raise exception '0250: anchors did not match: %', array_to_string(v_missing, ', ');
  end if;
end
$migration$;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(250);
