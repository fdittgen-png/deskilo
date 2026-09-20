-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0230 (#1276 S3) — one change-set for a deployment and a template, and a
-- merge that really never deletes.
--
-- ## What 0219 left unfinished
--
-- Merge mode stopped the deletes, but the inserts behind them were still
-- the mirror's plain inserts. Tracing a full template application over a
-- workspace that already runs:
--
--   * fee bands — `unique (workspace_id, from_pct)`: every new workspace is
--     seeded with bands, so applying a template's tariffs failed outright;
--   * closure days — `unique (workspace_id, day)`: one shared holiday
--     failed the whole application;
--   * validation policies — `unique nulls not distinct (workspace_id,
--     event_type)`: the same;
--   * VAT rates — `vat_rates_one_default`: the template's default and the
--     target's collided;
--   * the floor plan — `strip_template_plan` wrote `price_cents: 0` and
--     `merge_floor_plan` reads a present key as a value, so a level, room
--     or desk whose name matched LOST ITS PRICE.
--
-- Each is fixed at the writer, in merge mode only; mirror is untouched:
--
--   * a fee schedule partitions 0–100 %, so it is a setting replaced whole
--     (`replace_setting`), never merged band by band — interleaving two
--     schedules makes `member_statement`'s band lookup ambiguous. An empty
--     schedule in a snapshot replaces nothing;
--   * closure days and documents are added when absent (`additive`);
--   * a validation policy is updated by event type (`keyed_update`);
--   * the target keeps its default VAT rate if it has one;
--   * the stripped plan carries no price at all, so matching rows keep
--     theirs and new ones start at zero.
--
-- ## One change-set
--
-- `configuration_change_set(to, snapshot, entities, mode)` is the only
-- comparison. It does not authorize — it is revoked from every client —
-- and has two authorizing callers:
--
--   * `preview_deployment` keeps `may_deploy` and its exact output (the
--     harness compared it, before and after, on every live pair) — except
--     number series, which it misreported as removed and re-added because
--     `entity_row_key` had no key for them; fixed here;
--   * `preview_workspace_template` asks `manageConfiguration` on the target
--     and a readable template, and reports per group — `new`, `change`,
--     `matching` or `needs_attention` — with the items and, for attention,
--     the reason.
--
-- In merge mode the change-set never reports a removal, and reports only
-- what the writer will actually do: a key the snapshot does not carry, a
-- closure day that already exists, the target's own VAT default are not
-- changes. So a second application previews as `matching` throughout.
--
-- `apply_workspace_template` computes the same change-set, stores it on the
-- application, and applies the same entities from the same snapshot.
--
-- ## Compatibility
--
-- `template_compatibility` is the one verdict: `not_supported` for a
-- snapshot format or an entity this server does not know, `partial` only
-- when the caller chose groups and so excluded the unknown ones, otherwise
-- `supported`. Preview reports it; apply refuses on `not_supported`, and
-- the target is unchanged.

-- ── the writer: merge that never collides ──────────────────────────────
-- Anchors go through the same whitespace-tolerant replace as 0227: the
-- hosted body and the body a replay builds from the files wrap lines
-- differently. The exact text matches first on the hosted project.
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
  v_next text;
  v_missing text[] := '{}';
  v_count int;
  v_step record;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'import_workspace_configuration'
     and pg_get_function_identity_arguments(p.oid) = 'p_workspace_id uuid, p_configuration jsonb, p_mode text';
  if v_def is null then
    raise exception '0230: import_workspace_configuration(uuid, jsonb, text) not found';
  end if;

  for v_step in
    select * from (values
      -- An unknown mode used to behave as a half-merge.
      (1, 'mode guard',
       $a$if p_configuration is null or jsonb_typeof(p_configuration) <> 'object' then$a$,
       $a$if p_mode not in ('mirror', 'merge') then raise exception 'unknown import mode %', p_mode; end if;
  if p_configuration is null or jsonb_typeof(p_configuration) <> 'object' then$a$),
      -- Fee bands: a schedule is replaced whole unless the snapshot has none.
      (2, 'fee bands',
       $a$if p_mode = 'mirror' then delete from public.fee_bands where workspace_id = p_workspace_id; end if;$a$,
       $a$if p_mode = 'mirror' or jsonb_array_length(v_t->'fee_bands') > 0 then delete from public.fee_bands where workspace_id = p_workspace_id; end if;$a$),
      -- Closure days: additive. In mirror the table was just emptied.
      (3, 'closure days',
       $a$from jsonb_array_elements(v_t->'closure_days') e;$a$,
       $a$from jsonb_array_elements(v_t->'closure_days') e
    on conflict (workspace_id, day) do nothing;$a$),
      -- Validation policies: keyed by event type.
      (4, 'validation policies',
       $a$from jsonb_array_elements(v_t->'validation_policies') e;$a$,
       $a$from jsonb_array_elements(v_t->'validation_policies') e
    on conflict on constraint validation_policies_workspace_id_event_type_key do update set required_count = excluded.required_count, admins_may_validate = excluded.admins_may_validate, owner_required = excluded.owner_required, auto_validate_admin = excluded.auto_validate_admin, auto_validate_owner = excluded.auto_validate_owner, validator_scope = excluded.validator_scope, owner_may_self_validate = excluded.owner_may_self_validate, sequential = excluded.sequential;$a$),
      -- Documents: additive by title and address.
      (5, 'documents',
       $a$from jsonb_array_elements(v_t->'workspace_documents') e;$a$,
       $a$from jsonb_array_elements(v_t->'workspace_documents') e
     where p_mode = 'mirror' or not exists (select 1 from public.workspace_documents d where d.workspace_id = p_workspace_id and d.title = e.value->>'title' and d.url = e.value->>'url');$a$),
      -- VAT rates: the target keeps the default it has.
      (6, 'VAT insert',
       $a$coalesce((v_row->>'is_default')::boolean, false), coalesce((v_row->>'active')::boolean, true),$a$,
       $a$case when p_mode = 'merge' and exists (select 1 from public.vat_rates d where d.workspace_id = p_workspace_id and d.is_default) then false else coalesce((v_row->>'is_default')::boolean, false) end, coalesce((v_row->>'active')::boolean, true),$a$),
      (7, 'VAT update',
       $a$is_default = coalesce((v_row->>'is_default')::boolean, false),
               active = coalesce((v_row->>'active')::boolean, true),$a$,
       $a$is_default = case when p_mode = 'merge' then is_default or (coalesce((v_row->>'is_default')::boolean, false) and not exists (select 1 from public.vat_rates d where d.workspace_id = p_workspace_id and d.is_default and d.id <> v_id)) else coalesce((v_row->>'is_default')::boolean, false) end,
               active = coalesce((v_row->>'active')::boolean, true),$a$)
    ) as t(ord, name, old_text, new_text)
    order by ord
  loop
    v_next := pg_temp.anchor_replace(v_def, v_step.old_text, v_step.new_text);
    if v_next is null then
      v_missing := v_missing || v_step.name::text;
    else
      v_def := v_next;
    end if;
  end loop;
  if cardinality(v_missing) > 0 then
    raise exception '0230: anchors did not match: %', array_to_string(v_missing, ', ');
  end if;

  -- Each anchor must have landed exactly once where it matters.
  select count(*) into v_count from regexp_matches(v_def, 'p_mode = ''merge''', 'g');
  if v_count <> 2 then raise exception '0230: expected 2 merge-only VAT branches, built %', v_count; end if;
  select count(*) into v_count from regexp_matches(v_def, 'on conflict \(workspace_id, day\) do nothing', 'g');
  if v_count <> 1 then raise exception '0230: expected 1 additive closure insert, built %', v_count; end if;

  execute v_def;
end
$migration$;

revoke execute on function public.import_workspace_configuration(uuid, jsonb, text) from public, anon;

-- ── the stripped plan carries no price ────────────────────────────────
-- A present `price_cents: 0` is a value to `merge_floor_plan`; an absent
-- key keeps the target's. New rows still start at zero.
create or replace function public.strip_template_plan(p_tree jsonb)
returns jsonb
language plpgsql
immutable
as $$
declare
  v_out jsonb := '[]'::jsonb;
  v_l jsonb; v_o jsonb; v_d jsonb;
  v_offices jsonb; v_desks jsonb;
begin
  if p_tree is null or jsonb_typeof(p_tree) <> 'array' then
    return '[]'::jsonb;
  end if;
  for v_l in select value from jsonb_array_elements(p_tree) loop
    v_offices := '[]'::jsonb;
    for v_o in select value
                 from jsonb_array_elements(coalesce(v_l->'offices', '[]'::jsonb)) loop
      v_desks := '[]'::jsonb;
      for v_d in select value
                   from jsonb_array_elements(coalesce(v_o->'desks', '[]'::jsonb)) loop
        v_desks := v_desks || jsonb_build_array(v_d - 'price_cents');
      end loop;
      v_offices := v_offices || jsonb_build_array(
        (v_o - 'desks' - 'price_cents') || jsonb_build_object('desks', v_desks));
    end loop;
    v_out := v_out || jsonb_build_array(
      (v_l - 'offices' - 'images' - 'site' - 'background_path' - 'price_cents')
      || jsonb_build_object(
           'background_path', '',
           'images', '[]'::jsonb,
           'offices', v_offices));
  end loop;
  return v_out;
end $$;

revoke execute on function public.strip_template_plan(jsonb) from public, anon;

-- ── number series have a key ───────────────────────────────────────────
-- A series is keyed by its journal. `entity_row_key` fell through to
-- `name`, which a series does not have, so every series compared as null:
-- the deployment preview reported each one removed and re-added, and a
-- template could never preview as matching.
create or replace function public.entity_row_key(p_table text, p_row jsonb)
returns text
language sql
immutable
as $$
  select case p_table
    when 'vat_rates' then (p_row->>'label') || '@' || (p_row->>'percent')
    when 'fee_bands' then p_row->>'from_pct'
    when 'closure_days' then p_row->>'day'
    when 'validation_policies' then coalesce(p_row->>'event_type', 'default')
    when 'workspace_documents' then (p_row->>'title') || '@' || (p_row->>'url')
    when 'number_sequences' then p_row->>'journal'
    else p_row->>'name' end;
$$;

revoke execute on function public.entity_row_key(text, jsonb) from public, anon;

-- ── the one comparison ─────────────────────────────────────────────────
create or replace function public.configuration_change_set(
  p_to uuid, p_snapshot jsonb, p_entities text[], p_mode text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_dst jsonb;
  v_src_ws jsonb := coalesce(p_snapshot->'workspace', '{}'::jsonb);
  v_src_t jsonb := coalesce(p_snapshot->'tables', '{}'::jsonb);
  v_e jsonb;
  v_k text;
  v_items jsonb;
  v_out jsonb := '[]'::jsonb;
  v_row jsonb;
  v_other jsonb;
  v_cmp jsonb;
  v_after jsonb;
  v_key text;
  v_r record;
  v_has_default boolean;
begin
  if p_mode not in ('mirror', 'merge') then
    raise exception 'unknown change-set mode %', p_mode;
  end if;
  v_dst := public.export_entities(p_to, p_entities);
  v_has_default := exists (select 1 from jsonb_array_elements(coalesce(v_dst->'tables'->'vat_rates', '[]'::jsonb)) d
                            where coalesce((d.value->>'is_default')::boolean, false));

  for v_e in select value from jsonb_array_elements(public.deployable_entities()) loop
    if not ((v_e->>'key') = any (p_entities)) then continue; end if;
    v_items := '[]'::jsonb;

    for v_k in select jsonb_array_elements_text(v_e->'workspace_keys') loop
      -- A merge writes only the keys the snapshot carries.
      if p_mode = 'merge' and not v_src_ws ? v_k then continue; end if;
      v_after := v_src_ws->v_k;
      if p_mode = 'merge' and v_k = 'feature_flags' then
        v_after := public.imported_feature_flags(v_after);
      end if;
      if v_after is distinct from (v_dst->'workspace'->v_k) then
        v_items := v_items || jsonb_build_object('scope', 'workspace', 'op', 'change', 'key', v_k,
          'before', v_dst->'workspace'->v_k, 'after', v_after, 'attention', false);
      end if;
    end loop;

    if (v_e->>'key') = 'floor_plan' then
      for v_r in select s.key, s.data, d.data as other
                   from public.floor_plan_rows(v_src_t->'floor_plan') s
                   left join public.floor_plan_rows(v_dst->'tables'->'floor_plan') d on d.key = s.key loop
        if v_r.other is null then
          v_items := v_items || jsonb_build_object('scope', 'row', 'op', 'add', 'key', v_r.key,
            'before', null, 'after', v_r.data, 'attention', false);
        elsif p_mode = 'mirror' then
          if v_r.other <> v_r.data then
            v_items := v_items || jsonb_build_object('scope', 'row', 'op', 'change', 'key', v_r.key,
              'before', v_r.other, 'after', v_r.data, 'attention', false);
          end if;
        else
          -- A blank background and an absent key leave the target's alone.
          v_cmp := v_r.data;
          if coalesce(v_cmp->>'background', '') = '' then v_cmp := v_cmp - 'background'; end if;
          if not (v_r.other @> v_cmp) then
            v_items := v_items || jsonb_build_object('scope', 'row', 'op', 'change', 'key', v_r.key,
              'before', v_r.other, 'after', v_r.data, 'attention', false);
          end if;
        end if;
      end loop;
      if p_mode = 'mirror' then
        for v_r in select d.key, d.data from public.floor_plan_rows(v_dst->'tables'->'floor_plan') d
                   where not exists (select 1 from public.floor_plan_rows(v_src_t->'floor_plan') s where s.key = d.key) loop
          v_items := v_items || jsonb_build_object('scope', 'row', 'op', 'remove', 'key', v_r.key,
            'before', v_r.data, 'after', null, 'attention', false);
        end loop;
      end if;
    else
      for v_k in select jsonb_array_elements_text(v_e->'tables') loop
        if p_mode = 'merge' and not v_src_t ? v_k then continue; end if;

        -- A fee schedule is one setting: compared and replaced whole.
        if p_mode = 'merge' and v_k = 'fee_bands' then
          if jsonb_array_length(coalesce(v_src_t->'fee_bands', '[]'::jsonb)) > 0
             and (select jsonb_agg(b.value order by (b.value->>'from_pct')::int) from jsonb_array_elements(v_src_t->'fee_bands') b)
                 is distinct from
                 (select jsonb_agg(b.value order by (b.value->>'from_pct')::int) from jsonb_array_elements(coalesce(v_dst->'tables'->'fee_bands', '[]'::jsonb)) b) then
            v_items := v_items || jsonb_build_object('scope', 'row', 'op', 'replace', 'key', 'fee_bands',
              'before', v_dst->'tables'->'fee_bands', 'after', v_src_t->'fee_bands',
              'attention', jsonb_array_length(coalesce(v_dst->'tables'->'fee_bands', '[]'::jsonb)) > 0,
              'reason', 'fee_schedule_replaced_whole');
          end if;
          continue;
        end if;

        for v_row in select value from jsonb_array_elements(coalesce(v_src_t->v_k, '[]'::jsonb)) loop
          v_key := public.entity_row_key(v_k, v_row);
          v_other := null;
          select value into v_other from jsonb_array_elements(coalesce(v_dst->'tables'->v_k, '[]'::jsonb)) o
           where public.entity_row_key(v_k, o.value) = v_key limit 1;
          if v_other is null then
            v_items := v_items || jsonb_build_object('scope', 'row', 'op', 'add', 'key', v_key,
              'before', null, 'after', v_row, 'attention', false);
          elsif p_mode = 'mirror' then
            if v_other <> v_row then
              v_items := v_items || jsonb_build_object('scope', 'row', 'op', 'change', 'key', v_key,
                'before', v_other, 'after', v_row, 'attention', false);
            end if;
          elsif (v_e->>'merge_policy') <> 'additive' then
            v_cmp := v_row;
            if v_k = 'vat_rates' and v_has_default then v_cmp := v_cmp - 'is_default'; end if;
            if not (v_other @> v_cmp) then
              v_items := v_items || jsonb_build_object('scope', 'row', 'op', 'change', 'key', v_key,
                'before', v_other, 'after', v_row, 'attention', false);
            end if;
          end if;
        end loop;

        if p_mode = 'mirror' then
          for v_row in select value from jsonb_array_elements(coalesce(v_dst->'tables'->v_k, '[]'::jsonb)) loop
            v_key := public.entity_row_key(v_k, v_row);
            if not exists (select 1 from jsonb_array_elements(coalesce(v_src_t->v_k, '[]'::jsonb)) s
                            where public.entity_row_key(v_k, s.value) = v_key) then
              v_items := v_items || jsonb_build_object('scope', 'row', 'op', 'remove', 'key', v_key,
                'before', v_row, 'after', null, 'attention', false);
            end if;
          end loop;
        end if;
      end loop;
    end if;

    v_out := v_out || jsonb_build_object('key', v_e->>'key', 'kind', v_e->>'kind',
      'group', v_e->>'group', 'merge_policy', v_e->>'merge_policy', 'items', v_items);
  end loop;
  return jsonb_build_object('mode', p_mode, 'entities', v_out);
end;
$$;

-- Not authorizing: only its callers decide who may compare what.
revoke execute on function public.configuration_change_set(uuid, jsonb, text[], text)
  from public, anon, authenticated;

-- ── deployment: the same preview, from the one comparison ─────────────
create or replace function public.preview_deployment(p_from uuid, p_to uuid, p_entities text[])
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_set jsonb; v_e jsonb; v_i jsonb; v_out jsonb := '[]'::jsonb;
  v_added int; v_changed int; v_removed int; v_keys text[]; v_r record;
begin
  if not public.may_deploy(p_from, p_to) then raise exception 'not allowed to deploy in this direction'; end if;
  perform set_config('deskilo.deploying', p_from::text || ':' || p_to::text, true);
  v_set := public.configuration_change_set(p_to, public.export_entities(p_from, p_entities), p_entities, 'mirror');
  for v_e in select value from jsonb_array_elements(v_set->'entities') loop
    v_added := 0; v_changed := 0; v_removed := 0; v_keys := '{}';
    for v_i in select value from jsonb_array_elements(v_e->'items') loop
      if v_i->>'scope' = 'workspace' then
        v_changed := v_changed + 1; v_keys := v_keys || (v_i->>'key');
      elsif v_i->>'op' = 'add' then
        v_added := v_added + 1; v_keys := v_keys || ('+' || (v_i->>'key'));
      elsif v_i->>'op' = 'change' then
        v_changed := v_changed + 1; v_keys := v_keys || ('~' || (v_i->>'key'));
      else
        v_removed := v_removed + 1; v_keys := v_keys || ('-' || (v_i->>'key'));
      end if;
    end loop;
    -- #1012 — the designs' images the target lacks are additions.
    if (v_e->>'key') = 'document_design' then
      for v_r in select s as name from public.report_image_names(p_from) s
                 where not exists (select 1 from public.report_image_names(p_to) t where t = s) loop
        v_added := v_added + 1; v_keys := v_keys || ('+image:' || v_r.name);
      end loop;
    end if;
    v_out := v_out || jsonb_build_object('key', v_e->>'key', 'kind', v_e->>'kind',
      'added', v_added, 'changed', v_changed, 'removed', v_removed, 'details', to_jsonb(v_keys));
  end loop;
  return jsonb_build_object('direction', public.deployment_direction(p_from, p_to), 'entities', v_out);
end;
$$;

revoke execute on function public.preview_deployment(uuid, uuid, text[]) from public, anon;

-- ── per group, the vocabulary the UI shows ─────────────────────────────
create or replace function public.configuration_group_states(p_set jsonb)
returns jsonb
language plpgsql
immutable
set search_path = public
as $$
declare
  v_groups text[];
  v_g text;
  v_items jsonb;
  v_state text;
  v_reason text;
  v_out jsonb := '[]'::jsonb;
begin
  select array_agg(g order by o) into v_groups
    from (select e.value->>'group' as g, min(e.ord) as o
            from jsonb_array_elements(coalesce(p_set->'entities', '[]'::jsonb)) with ordinality e(value, ord)
           group by 1) s;
  foreach v_g in array coalesce(v_groups, '{}') loop
    select coalesce(jsonb_agg(i.value || jsonb_build_object('entity', e.value->>'key', 'label', i.value->>'key')
                              order by e.ord, i.ord), '[]'::jsonb)
      into v_items
      from jsonb_array_elements(p_set->'entities') with ordinality e(value, ord)
      cross join lateral jsonb_array_elements(e.value->'items') with ordinality i(value, ord)
     where e.value->>'group' = v_g;
    v_reason := null;
    if jsonb_array_length(v_items) = 0 then
      v_state := 'matching';
    elsif exists (select 1 from jsonb_array_elements(v_items) x where coalesce((x.value->>'attention')::boolean, false)) then
      v_state := 'needs_attention';
      select string_agg(distinct x.value->>'reason', ',') into v_reason
        from jsonb_array_elements(v_items) x where coalesce((x.value->>'attention')::boolean, false);
    elsif not exists (select 1 from jsonb_array_elements(v_items) x where x.value->>'op' <> 'add') then
      v_state := 'new';
    else
      v_state := 'change';
    end if;
    v_out := v_out || jsonb_build_object('group', v_g, 'state', v_state, 'items', v_items, 'reason', v_reason);
  end loop;
  return v_out;
end $$;

revoke execute on function public.configuration_group_states(jsonb) from public, anon;

-- ── compatibility: one verdict ─────────────────────────────────────────
create or replace function public.template_compatibility(
  p_template public.workspace_templates, p_groups text[])
returns jsonb
language plpgsql
stable
set search_path = public
as $$
declare
  v_unknown text[];
  v_selected text[];
begin
  if not p_template.schema_version = any (public.template_supported_schema_versions()) then
    return jsonb_build_object('status', 'not_supported', 'code', 'schema',
      'reason', format('template schema %s is newer than this server', p_template.schema_version),
      'selected', '[]'::jsonb);
  end if;
  select coalesce(array_agg(k), '{}') into v_unknown
    from unnest(p_template.entities) k
   where not exists (select 1 from jsonb_array_elements(public.deployable_entities()) e
                      where e.value->>'key' = k);
  if cardinality(v_unknown) > 0 and p_groups is null then
    return jsonb_build_object('status', 'not_supported', 'code', 'entity',
      'reason', format('this server has no entity %s', array_to_string(v_unknown, ', ')),
      'selected', '[]'::jsonb);
  end if;
  select coalesce(array_agg(e.value->>'key' order by e.ord), '{}') into v_selected
    from jsonb_array_elements(public.deployable_entities()) with ordinality e(value, ord)
   where (e.value->>'key') = any (p_template.entities)
     and (p_groups is null or (e.value->>'group') = any (p_groups));
  if cardinality(v_selected) = 0 then
    return jsonb_build_object('status', 'not_supported', 'code', 'empty',
      'reason', 'the template carries nothing in the chosen groups', 'selected', '[]'::jsonb);
  end if;
  return jsonb_build_object(
    'status', case when cardinality(v_unknown) > 0 then 'partial' else 'supported' end,
    'code', null,
    'reason', case when cardinality(v_unknown) > 0
                   then format('left out: this server has no entity %s', array_to_string(v_unknown, ', ')) end,
    'selected', to_jsonb(v_selected));
end $$;

revoke execute on function public.template_compatibility(public.workspace_templates, text[]) from public, anon;

-- The snapshot a template applies: its configuration, and its plan with
-- every price removed (templates saved before this migration hold zeros).
create or replace function public.template_snapshot(p_template public.workspace_templates)
returns jsonb
language sql
immutable
set search_path = public
as $$
  select jsonb_build_object(
    'workspace', coalesce(p_template.configuration->'workspace', '{}'::jsonb),
    'tables', coalesce(p_template.configuration->'tables', '{}'::jsonb)
              || jsonb_build_object('floor_plan', public.strip_template_plan(p_template.floor_plan)));
$$;

revoke execute on function public.template_snapshot(public.workspace_templates) from public, anon;

-- ── preview a template ─────────────────────────────────────────────────
create or replace function public.preview_workspace_template(
  p_workspace_id uuid,
  p_template_id uuid,
  p_groups text[] default null
) returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tpl public.workspace_templates;
  v_compat jsonb;
  v_head jsonb;
begin
  if auth.uid() is null
     or not public.has_permission(p_workspace_id, 'manageConfiguration') then
    raise exception 'only someone who configures this workspace applies a template';
  end if;
  if not public.workspace_template_readable(p_template_id) then
    raise exception 'unknown template';
  end if;
  select * into v_tpl from public.workspace_templates where id = p_template_id;
  v_compat := public.template_compatibility(v_tpl, p_groups);
  v_head := jsonb_build_object(
    'compatibility', v_compat->>'status',
    'reason', v_compat->'reason',
    'schema_version', v_tpl.schema_version,
    'template_version', v_tpl.template_version,
    'entities', v_compat->'selected');
  if v_compat->>'status' = 'not_supported' then
    return v_head || jsonb_build_object('groups', '[]'::jsonb);
  end if;
  return v_head || jsonb_build_object('groups', public.configuration_group_states(
    public.configuration_change_set(p_workspace_id, public.template_snapshot(v_tpl),
      array(select jsonb_array_elements_text(v_compat->'selected')), 'merge')));
end $$;

revoke execute on function public.preview_workspace_template(uuid, uuid, text[]) from public, anon;
grant execute on function public.preview_workspace_template(uuid, uuid, text[]) to authenticated;

-- ── apply exactly what was previewed ───────────────────────────────────
create or replace function public.apply_workspace_template(
  p_workspace_id uuid,
  p_template_id uuid,
  p_groups text[] default null
) returns jsonb
language plpgsql security definer set search_path = public as $fn$
declare
  v_tpl public.workspace_templates;
  v_compat jsonb;
  v_selected text[];
  v_table_entities text[];
  v_snapshot jsonb;
  v_before jsonb;
  v_change_set jsonb;
  v_plan_result jsonb := null;
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

  v_compat := public.template_compatibility(v_tpl, p_groups);
  if v_compat->>'status' = 'not_supported' then
    if v_compat->>'code' = 'empty' then
      raise exception '%', v_compat->>'reason';
    end if;
    raise exception 'not supported: %', v_compat->>'reason';
  end if;
  v_selected := array(select jsonb_array_elements_text(v_compat->'selected'));
  v_snapshot := public.template_snapshot(v_tpl);

  -- What the target held, and what this application changes. Reading them
  -- asks exportData; a delegate who may configure but not export still
  -- applies, and the record says the snapshot was not theirs to take.
  begin
    v_before := public.export_entities(p_workspace_id, v_selected);
    v_change_set := public.configuration_group_states(
      public.configuration_change_set(p_workspace_id, v_snapshot, v_selected, 'merge'));
  exception when others then
    v_before := jsonb_build_object('unavailable', sqlerrm);
    v_change_set := null;
  end;

  v_table_entities := array(select k from unnest(v_selected) k where k <> 'floor_plan');
  if cardinality(v_table_entities) > 0 then
    for v_entity in select value from jsonb_array_elements(public.deployable_entities()) loop
      if not (v_entity->>'key') = any (v_table_entities) then continue; end if;
      for v_key in select jsonb_array_elements_text(v_entity->'workspace_keys') loop
        if (v_snapshot->'workspace') ? v_key then
          v_ws := v_ws || jsonb_build_object(v_key, v_snapshot->'workspace'->v_key);
        end if;
      end loop;
      for v_key in select jsonb_array_elements_text(v_entity->'tables') loop
        if (v_snapshot->'tables') ? v_key then
          v_tables := v_tables || jsonb_build_object(v_key, v_snapshot->'tables'->v_key);
        end if;
      end loop;
    end loop;
    perform public.import_workspace_configuration(p_workspace_id,
      jsonb_build_object('workspace', v_ws, 'tables', v_tables), 'merge');
  end if;

  if 'floor_plan' = any (v_selected) then
    v_plan_result := public.merge_floor_plan(p_workspace_id, v_snapshot->'tables'->'floor_plan');
  end if;

  insert into public.workspace_template_applications
    (workspace_id, template_id, template_key, template_version, schema_version,
     groups, entities, change_set, before, applied_by)
  values
    (p_workspace_id, v_tpl.id, v_tpl.key, v_tpl.template_version, v_tpl.schema_version,
     coalesce(p_groups, '{}'), v_selected, v_change_set, v_before, auth.uid());

  return coalesce(v_plan_result, '{}'::jsonb)
         || jsonb_build_object('applied_entities', to_jsonb(v_selected),
                               'compatibility', v_compat->>'status',
                               'reason', v_compat->'reason');
end $fn$;

revoke execute on function public.apply_workspace_template(uuid, uuid, text[]) from public, anon;
grant execute on function public.apply_workspace_template(uuid, uuid, text[]) to authenticated;

select public.set_deskilo_schema_version(230);
