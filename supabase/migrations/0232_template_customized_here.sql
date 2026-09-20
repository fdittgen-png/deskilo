-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0232 (#1280 S4) — updating from a template does not undo what this
-- workspace changed since it last applied it.
--
-- A workspace that applied "French coworking rules" last spring and then
-- moved its opening hour to 08:30 would, on applying the template's next
-- version, see hours_booking as a plain "change" — and one tick would put
-- 09:00 back. The workspace_template_applications row (0229) remembers what
-- the last application of the same template SET, item by item, in its
-- change_set. So the preview can tell a local customization from drift:
--
--   an item whose current value differs from what the last application of
--   this template set is **customized here**.
--
-- `preview_workspace_template` marks such items `customized: true` and
-- their group `customized: true`; the client leaves those groups unticked
-- (#1280 decision D). Nothing is refused: choosing the group still applies
-- it. A workspace that never applied the template sees no marks.

create or replace function public.template_customizations(
  p_workspace_id uuid, p_template public.workspace_templates, p_groups jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_last jsonb;
  v_set jsonb := '{}'::jsonb;
  v_group jsonb;
  v_item jsonb;
  v_items jsonb;
  v_out jsonb := '[]'::jsonb;
  v_any boolean;
  v_key text;
begin
  select a.change_set into v_last
    from public.workspace_template_applications a
   where a.workspace_id = p_workspace_id
     and (a.template_id = p_template.id or a.template_key = p_template.key)
     and a.change_set is not null
   order by a.applied_at desc
   limit 1;
  if v_last is null then
    return p_groups;
  end if;

  -- What the last application set: entity + key → after.
  for v_group in select value from jsonb_array_elements(v_last) loop
    for v_item in select value from jsonb_array_elements(coalesce(v_group->'items', '[]'::jsonb)) loop
      v_set := v_set || jsonb_build_object(
        (v_item->>'entity') || '|' || coalesce(v_item->>'key', ''), v_item->'after');
    end loop;
  end loop;

  for v_group in select value from jsonb_array_elements(p_groups) loop
    v_items := '[]'::jsonb;
    v_any := false;
    for v_item in select value from jsonb_array_elements(coalesce(v_group->'items', '[]'::jsonb)) loop
      v_key := (v_item->>'entity') || '|' || coalesce(v_item->>'key', '');
      if v_set ? v_key and (v_item->'before') is distinct from (v_set->v_key) then
        v_item := v_item || jsonb_build_object('customized', true);
        v_any := true;
      end if;
      v_items := v_items || v_item;
    end loop;
    v_out := v_out || (v_group || jsonb_build_object('items', v_items, 'customized', v_any));
  end loop;
  return v_out;
end;
$$;

revoke execute on function public.template_customizations(uuid, public.workspace_templates, jsonb)
  from public, anon, authenticated;

do $migration$
declare
  v_def text;
  v_next text;
begin
  select pg_get_functiondef('public.preview_workspace_template(uuid, uuid, text[])'::regprocedure)
    into v_def;
  v_next := replace(v_def,
    'return v_head || jsonb_build_object(''groups'', public.configuration_group_states(',
    'return v_head || jsonb_build_object(''groups'', public.template_customizations(p_workspace_id, v_tpl, public.configuration_group_states(');
  if v_next = v_def then
    raise exception '0232: the preview return anchor did not match';
  end if;
  v_def := v_next;
  v_next := replace(v_def,
    'array(select jsonb_array_elements_text(v_compat->''selected'')), ''merge'')));',
    'array(select jsonb_array_elements_text(v_compat->''selected'')), ''merge''))));');
  if v_next = v_def then
    raise exception '0232: the preview closing anchor did not match';
  end if;
  execute v_next;
end
$migration$;

select public.set_deskilo_schema_version(232);
