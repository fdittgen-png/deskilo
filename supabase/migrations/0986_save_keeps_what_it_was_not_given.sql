-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- apps: additive
--
-- #4498 (audit WS-03, WS-04 server side, the single-choice guard) -- a save keeps what it did not change on the server too.
--   * `set_workspace_field` / `save_workspace_field`: every attribute of a question the save is NOT GIVEN keeps its value on the server
--     (required, personal data, visibility, contexts, grouping, order, validation rules, active state): the parameters default to null,
--     and null means "as it is" for a question that exists, the old defaults for a new one. A save of the labels alone no longer
--     resets the rest. The labels of a question are upserted by locale, so their help texts survive; a locale the save does not name is
--     taken away (with its help text), as the save says.
--   * `set_workspace_field_options`: a choice key is the identity of a choice. A choice that an answer uses cannot be removed or
--     renamed (a rename is a removal and an addition), whether the answer is a multiple choice (the join table, as before) or a single
--     choice (its text is the key: 0248 stores it in `text_value`); it can be RETIRED (`active` = false), and a retired choice stays
--     readable on the answers that hold it. Refused with DKW01.
--   * DKW01: a question or its choices are asked to change in a way that would break an answer.
-- Anchored patches of the live definitions (0248, 0252), each anchor asserted once.

create or replace function pg_temp.anchor_once(p_def text, p_old text, p_new text, p_what text)
returns text
language plpgsql
as $f$
begin
  if (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old) <> 1 then
    raise exception '0986: % is not found exactly once', p_what using errcode = 'P0001';
  end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_once(text, text, text, text) from public;

do $migration$
declare
  v_def text;
  v_old_header text := $h$p_required boolean DEFAULT false, p_personal_data boolean DEFAULT true, p_visibility text DEFAULT 'self'::text, p_contexts text[] DEFAULT ARRAY['profile'::text], p_group_key text DEFAULT 'general'::text, p_sort_order integer DEFAULT 0, p_validation jsonb DEFAULT '{}'::jsonb, p_active boolean DEFAULT true$h$;
  v_new_header text := $h$p_required boolean DEFAULT NULL, p_personal_data boolean DEFAULT NULL, p_visibility text DEFAULT NULL, p_contexts text[] DEFAULT NULL, p_group_key text DEFAULT NULL, p_sort_order integer DEFAULT NULL, p_validation jsonb DEFAULT NULL, p_active boolean DEFAULT NULL$h$;
begin
  select pg_get_functiondef('public.set_workspace_field(uuid,text,text,jsonb,boolean,boolean,text,text[],text,integer,jsonb,boolean)'::regprocedure) into v_def;
  if position('workspace_field_definitions.required' in v_def) = 0 then
    v_def := pg_temp.anchor_once(v_def, v_old_header, v_new_header, 'the parameters');
    v_def := pg_temp.anchor_once(v_def, $o$  if coalesce(array_length(p_contexts, 1), 0) = 0 then$o$,
      $n$  if p_contexts is not null and coalesce(array_length(p_contexts, 1), 0) = 0 then$n$, 'the contexts check');
    v_def := pg_temp.anchor_once(v_def, $o$          p_visibility, p_contexts, coalesce(p_group_key,'general')$o$,
      $n$          coalesce(p_visibility,'self'), coalesce(p_contexts, array['profile']::text[]), coalesce(p_group_key,'general')$n$, 'the new question');
    v_def := pg_temp.anchor_once(v_def,
      $o$    set type = excluded.type, required = excluded.required,
        personal_data = excluded.personal_data, visibility = excluded.visibility,
        contexts = excluded.contexts, group_key = excluded.group_key,
        sort_order = excluded.sort_order, validation = excluded.validation,
        active = excluded.active$o$,
      $n$    set type = excluded.type,
        required = coalesce(p_required, public.workspace_field_definitions.required),
        personal_data = coalesce(p_personal_data, public.workspace_field_definitions.personal_data),
        visibility = coalesce(p_visibility, public.workspace_field_definitions.visibility),
        contexts = coalesce(p_contexts, public.workspace_field_definitions.contexts),
        group_key = coalesce(p_group_key, public.workspace_field_definitions.group_key),
        sort_order = coalesce(p_sort_order, public.workspace_field_definitions.sort_order),
        validation = coalesce(p_validation, public.workspace_field_definitions.validation),
        active = coalesce(p_active, public.workspace_field_definitions.active)$n$, 'the question that exists');
    v_def := pg_temp.anchor_once(v_def,
      $o$  delete from public.workspace_field_labels where definition_id = v_id;
  insert into public.workspace_field_labels (workspace_id, definition_id, locale, label)
  select p_workspace_id, v_id, k, p_labels->>k from jsonb_object_keys(p_labels) k;$o$,
      $n$  -- the labels are upserted by locale: the help text of a label the save names is kept; a locale it does not name goes
  delete from public.workspace_field_labels where definition_id = v_id and not (locale in (select jsonb_object_keys(p_labels)));
  insert into public.workspace_field_labels (workspace_id, definition_id, locale, label)
  select p_workspace_id, v_id, k, p_labels->>k from jsonb_object_keys(p_labels) k
  on conflict (definition_id, locale) do update set label = excluded.label;$n$, 'the labels');
    execute v_def;
  end if;

  select pg_get_functiondef('public.save_workspace_field(uuid,text,text,jsonb,boolean,boolean,text,text[],text,integer,jsonb,boolean,jsonb)'::regprocedure) into v_def;
  if position('p_required boolean DEFAULT NULL' in v_def) = 0 then
    v_def := pg_temp.anchor_once(v_def, v_old_header, v_new_header, 'the parameters of the save');
    execute v_def;
  end if;

  select pg_get_functiondef('public.set_workspace_field_options(uuid,jsonb)'::regprocedure) into v_def;
  if position('DKW01' in v_def) = 0 then
    v_def := pg_temp.anchor_once(v_def, $o$  delete from public.workspace_field_options o
   where o.definition_id = d.id and not (o.key = any(v_keys));$o$,
      $n$  -- a single choice is stored as the text of its key: a choice an answer holds is retired, never removed or renamed
  if exists (select 1 from public.workspace_field_options o
              join public.workspace_field_values fv on fv.definition_id = d.id and fv.text_value = o.key
             where o.definition_id = d.id and not (o.key = any(v_keys))) then
    raise exception 'a choice that has been made cannot be removed or renamed; retire it instead' using errcode = 'DKW01';
  end if;
  delete from public.workspace_field_options o
   where o.definition_id = d.id and not (o.key = any(v_keys));$n$, 'the removal of choices');
    execute v_def;
  end if;
end
$migration$;

select public.set_deskilo_schema_version(986);
