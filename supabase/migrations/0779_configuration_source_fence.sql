-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (one function; three anchored patches)
--
-- #4028 -- a configuration applied to a business in another currency or
-- country carries no amount and no tax rate as a bare number.
--
-- * The export states its source: `workspace.currency_code` and
--   `workspace.country_code`. The import reads them as facts and never
--   writes them.
-- * A payload that states a currency other than the target's has its
--   priced entities refused (every entity that requires `vat`: tariffs,
--   services, packages, accessories, credit products), with a reason naming
--   both currencies; a validation threshold is an amount too, so the target
--   keeps its own. A payload that states another country has `vat`
--   refused the same way. The other entities are applied.
-- * A payload that states neither applies as before; a business and its
--   own twin share both, so deployments inside a pair are unaffected.
-- * Applying a template states its owner business's currency and country
--   at apply time; a template without an owner (built in) applies as before.
-- * The import's answer, and the template apply's, name what was refused
--   (`refused`: entity, code, source, target, reason).

-- ── 1. the fence ─────────────────────────────────────────────────────────
create or replace function public.configuration_source_fence(p_workspace_id uuid, p_configuration jsonb)
returns jsonb language plpgsql stable set search_path = public as $fn$
declare
  v_ws jsonb := coalesce(p_configuration->'workspace', '{}'::jsonb);
  v_t jsonb := coalesce(p_configuration->'tables', '{}'::jsonb);
  v_currency text;
  v_country text;
  v_src_currency text;
  v_src_country text;
  v_refused jsonb := '[]'::jsonb;
  v_entity jsonb;
  v_key text;
  v_present boolean;
begin
  if jsonb_typeof(v_ws) <> 'object' or jsonb_typeof(v_t) <> 'object' then
    -- the importer refuses a malformed payload itself
    return jsonb_build_object('configuration', p_configuration, 'refused', v_refused);
  end if;
  select upper(w.currency_code), upper(w.country_code) into v_currency, v_country
    from public.workspaces w where w.id = p_workspace_id;
  v_src_currency := upper(nullif(btrim(v_ws->>'currency_code'), ''));
  v_src_country := upper(nullif(btrim(v_ws->>'country_code'), ''));

  for v_entity in select value from jsonb_array_elements(public.deployable_entities()) loop
    if (v_src_currency is not null and v_src_currency is distinct from v_currency
          and (v_entity->'requires') ? 'vat')
       or (v_src_country is not null and v_src_country is distinct from v_country
          and v_entity->>'key' = 'vat') then
      v_present := false;
      for v_key in select jsonb_array_elements_text(v_entity->'tables') loop
        v_present := v_present or coalesce(v_t->v_key, 'null') not in ('null', '[]', '{}', '""');
        v_t := v_t - v_key;
      end loop;
      for v_key in select jsonb_array_elements_text(v_entity->'workspace_keys') loop
        v_present := v_present or coalesce(v_ws->v_key, 'null') not in ('null', '[]', '{}', '""');
        v_ws := v_ws - v_key;
      end loop;
      -- named only when the payload held something of it
      if v_present then
        v_refused := v_refused || jsonb_build_array(case when v_entity->>'key' = 'vat'
          then jsonb_build_object('entity', 'vat', 'code', 'country',
                 'source', v_src_country, 'target', v_country,
                 'reason', format('the configuration''s tax rates are those of %s and this business is in %s',
                                  v_src_country, v_country))
          else jsonb_build_object('entity', v_entity->>'key', 'code', 'currency',
                 'source', v_src_currency, 'target', v_currency,
                 'reason', format('the configuration is priced in %s and this business in %s',
                                  v_src_currency, v_currency)) end);
      end if;
    end if;
  end loop;

  -- a validation threshold is an amount: in another currency the target keeps its own
  if v_src_currency is not null and v_src_currency is distinct from v_currency
     and jsonb_typeof(v_t->'validation_policies') = 'array'
     and exists (select 1 from jsonb_array_elements(v_t->'validation_policies') e where e.value ? 'min_amount_cents') then
    v_t := jsonb_set(v_t, '{validation_policies}',
      (select coalesce(jsonb_agg(e.value - 'min_amount_cents' order by e.ordinality), '[]'::jsonb)
         from jsonb_array_elements(v_t->'validation_policies') with ordinality e));
    v_refused := v_refused || jsonb_build_array(jsonb_build_object(
      'entity', 'validation_rules', 'field', 'min_amount_cents', 'code', 'currency',
      'source', v_src_currency, 'target', v_currency,
      'reason', format('a validation threshold in %s is not one in %s: this business keeps its own',
                       v_src_currency, v_currency)));
  end if;

  v_ws := v_ws - 'currency_code' - 'country_code';
  return jsonb_build_object(
    'configuration', p_configuration || jsonb_build_object('workspace', v_ws, 'tables', v_t),
    'refused', v_refused);
end;
$fn$;
revoke execute on function public.configuration_source_fence(uuid, jsonb) from public, anon, authenticated;

-- ── 2. the export states its source; the import fences first ────────────
do $migration$
declare
  v_exp text := pg_get_functiondef('public.export_workspace_configuration(uuid)'::regprocedure);
  v_imp text := pg_get_functiondef('public.import_workspace_configuration(uuid,jsonb,text)'::regprocedure);
  v_apply text := pg_get_functiondef('public.apply_workspace_template(uuid,uuid,text[])'::regprocedure);
  v_old text;
  v_new text;
begin
  if position('''currency_code'', w.currency_code' in v_exp) = 0 then
    v_old := $a$    'workspace', jsonb_build_object(
      'address', coalesce(w.address, ''),$a$;
    if position(v_old in v_exp) = 0 then
      raise exception 'export_workspace_configuration no longer has the workspace shape 0779 extends' using errcode = 'P0001';
    end if;
    execute replace(v_exp, v_old, $a$    'workspace', jsonb_build_object(
      -- #4028: the source's currency and country, facts an import compares
      'currency_code', w.currency_code,
      'country_code', w.country_code,
      'address', coalesce(w.address, ''),$a$);
  end if;

  if position('configuration_source_fence' in v_imp) = 0 then
    for v_old, v_new in select * from (values
      ($a$declare v_ws jsonb; v_t jsonb;$a$, $a$declare v_fence jsonb; v_ws jsonb; v_t jsonb;$a$),
      ($a$  v_ws := coalesce(p_configuration->'workspace', '{}'::jsonb);$a$,
       $a$  -- #4028: what another currency or country cannot take is left out, and named
  v_fence := public.configuration_source_fence(p_workspace_id, p_configuration);
  p_configuration := v_fence->'configuration';
  v_ws := coalesce(p_configuration->'workspace', '{}'::jsonb);$a$),
      ($a$  return public.export_workspace_configuration(p_workspace_id);$a$,
       $a$  return public.export_workspace_configuration(p_workspace_id)
    || case when jsonb_array_length(v_fence->'refused') > 0
         then jsonb_build_object('refused', v_fence->'refused') else '{}'::jsonb end;$a$)) v(o, n)
    loop
      if (length(v_imp) - length(replace(v_imp, v_old, ''))) / length(v_old) <> 1 then
        raise exception 'import_workspace_configuration no longer has the shape 0779 extends: %', left(v_old, 60) using errcode = 'P0001';
      end if;
      v_imp := replace(v_imp, v_old, v_new);
    end loop;
    execute v_imp;
  end if;

  if position('v_imported' in v_apply) = 0 then
    for v_old, v_new in select * from (values
      ($a$  v_key text;
begin$a$, $a$  v_key text;
  v_imported jsonb;
begin$a$),
      ($a$    perform public.import_workspace_configuration(p_workspace_id,
      jsonb_build_object('workspace', v_ws, 'tables', v_tables), 'merge');$a$,
       $a$    -- #4028: the template's prices and rates are its owner business's
    v_imported := public.import_workspace_configuration(p_workspace_id,
      jsonb_build_object('workspace', v_ws || coalesce(
        (select jsonb_build_object('currency_code', o.currency_code, 'country_code', o.country_code)
           from public.workspaces o where o.id = v_tpl.owner_workspace_id), '{}'::jsonb),
        'tables', v_tables), 'merge');$a$),
      ($a$'validation_blocked', public.template_blocked_validations(v_snapshot->'tables', v_selected),$a$,
       $a$'validation_blocked', public.template_blocked_validations(v_snapshot->'tables', v_selected),
                               'refused', coalesce(v_imported->'refused', '[]'::jsonb),$a$)) v(o, n)
    loop
      if (length(v_apply) - length(replace(v_apply, v_old, ''))) / length(v_old) <> 1 then
        raise exception 'apply_workspace_template no longer has the shape 0779 extends: %', left(v_old, 60) using errcode = 'P0001';
      end if;
      v_apply := replace(v_apply, v_old, v_new);
    end loop;
    execute v_apply;
  end if;
end
$migration$;

select public.set_deskilo_schema_version(779);
