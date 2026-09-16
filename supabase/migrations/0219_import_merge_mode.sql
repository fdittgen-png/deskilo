-- SPDX-License-Identifier: 0BSD
--
-- 0219 (#1276 S1) — the configuration import gains a mode.
--
-- `import_workspace_configuration` is a MIRROR: it deletes fee bands,
-- closure days, validation policies and documents, and deactivates every
-- package, service, plan, accessory and VAT rate the payload does not
-- name. That is correct for a production deployment, which must make the
-- target equal the source.
--
-- It is wrong for a template. Applying "the French coworking rules" to a
-- workspace that already runs must add and update, never remove — a
-- space that applies a template should not lose its own closure days.
--
-- So the writer gains a mode rather than growing a twin. One
-- implementation, two behaviours, and `mirror` stays the default so that
-- every existing caller means exactly what it meant yesterday.
--
-- The body is patched from `pg_get_functiondef`, not retyped: the hosted
-- body diverges from the migration files, and 14 000 characters retyped
-- by hand is a defect waiting for a quiet afternoon. Every substitution
-- is asserted — a silent no-op here is how 0169 broke detailed invoices
-- for a day (#960).
do $migration$
declare
  v_def text;
  v_count int;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'import_workspace_configuration'
     and pg_get_function_identity_arguments(p.oid) = 'p_workspace_id uuid, p_configuration jsonb'
   limit 1;
  if v_def is null then
    raise exception '0219: import_workspace_configuration(uuid, jsonb) not found';
  end if;

  v_def := replace(v_def,
    'FUNCTION public.import_workspace_configuration(p_workspace_id uuid, p_configuration jsonb)',
    'FUNCTION public.import_workspace_configuration(p_workspace_id uuid, p_configuration jsonb, p_mode text default ''mirror'')');
  if position('p_mode text default' in v_def) = 0 then
    raise exception '0219: the signature anchor did not match';
  end if;

  -- Whole statements: guarded.
  v_def := replace(v_def, 'delete from public.fee_bands where workspace_id = p_workspace_id;',
    'if p_mode = ''mirror'' then delete from public.fee_bands where workspace_id = p_workspace_id; end if;');
  v_def := replace(v_def, 'delete from public.closure_days where workspace_id = p_workspace_id;',
    'if p_mode = ''mirror'' then delete from public.closure_days where workspace_id = p_workspace_id; end if;');
  v_def := replace(v_def, 'delete from public.validation_policies where workspace_id = p_workspace_id;',
    'if p_mode = ''mirror'' then delete from public.validation_policies where workspace_id = p_workspace_id; end if;');
  v_def := replace(v_def, 'delete from public.workspace_documents where workspace_id = p_workspace_id;',
    'if p_mode = ''mirror'' then delete from public.workspace_documents where workspace_id = p_workspace_id; end if;');
  v_def := replace(v_def, 'update public.vat_rates set is_default = false where workspace_id = p_workspace_id;',
    'if p_mode = ''mirror'' then update public.vat_rates set is_default = false where workspace_id = p_workspace_id; end if;');
  v_def := replace(v_def, 'update public.sites set is_default = false where workspace_id = p_workspace_id;',
    'if p_mode = ''mirror'' then update public.sites set is_default = false where workspace_id = p_workspace_id; end if;');
  select count(*) into v_count from regexp_matches(v_def, 'if p_mode = ''mirror'' then', 'g');
  if v_count <> 6 then
    raise exception '0219: expected 6 guarded statements, built %', v_count;
  end if;

  -- The deactivations already carry a `where`; a second one is a syntax
  -- error, so the condition joins the existing clause. `packages` and
  -- `plans` share the alias `p`, hence the table name in each pattern.
  v_def := regexp_replace(v_def,
    'update public\.vat_rates r set active = false\s+where r\.workspace_id',
    'update public.vat_rates r set active = false where p_mode = ''mirror'' and r.workspace_id');
  v_def := regexp_replace(v_def,
    'update public\.packages p set active = false\s+where p\.workspace_id',
    'update public.packages p set active = false where p_mode = ''mirror'' and p.workspace_id');
  v_def := regexp_replace(v_def,
    'update public\.services s set active = false\s+where s\.workspace_id',
    'update public.services s set active = false where p_mode = ''mirror'' and s.workspace_id');
  v_def := regexp_replace(v_def,
    'update public\.plans p set active = false\s+where p\.workspace_id',
    'update public.plans p set active = false where p_mode = ''mirror'' and p.workspace_id');
  v_def := regexp_replace(v_def,
    'update public\.accessories a set active = false\s+where a\.workspace_id',
    'update public.accessories a set active = false where p_mode = ''mirror'' and a.workspace_id');
  select count(*) into v_count
    from regexp_matches(v_def, 'set active = false where p_mode = ''mirror'' and', 'g');
  if v_count <> 5 then
    raise exception '0219: expected 5 guarded deactivations, built %', v_count;
  end if;

  execute v_def;
end
$migration$;

-- The two-argument form must GO, not linger. A defaulted third argument
-- creates a second function, and every existing two-argument call —
-- deploy_entities, rollback_deployment, create_workspace_twin and the
-- client — would then fail with "function is not unique".
drop function if exists public.import_workspace_configuration(uuid, jsonb);

revoke execute on function
  public.import_workspace_configuration(uuid, jsonb, text) from public, anon;
grant execute on function
  public.import_workspace_configuration(uuid, jsonb, text) to authenticated;

-- Every internal caller says `mirror` out loud. A deployment that
-- silently inherited a default would be a deployment nobody could read.
--
-- Anchored on each call's OWN text, not on a general pattern. The first
-- attempt used `import_workspace_configuration\(([^;]*?)\)` and would
-- have closed the argument at the INNER parenthesis of
-- `jsonb_build_object('tables', (v_snapshot->'tables') - 'floor_plan')`,
-- mangling deploy_entities — silently, because counting how many
-- functions were patched says nothing about whether the split was right.
do $callers$
declare
  v_def text;
  v_patched int := 0;
begin
  select pg_get_functiondef(p.oid) into v_def from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'deploy_entities' limit 1;
  if position('perform public.import_workspace_configuration(p_to, v_snapshot - ''tables'' || jsonb_build_object(''tables'', (v_snapshot->''tables'') - ''floor_plan''));' in v_def) = 0 then
    raise exception '0219: deploy_entities call site not found';
  end if;
  execute replace(v_def,
    'perform public.import_workspace_configuration(p_to, v_snapshot - ''tables'' || jsonb_build_object(''tables'', (v_snapshot->''tables'') - ''floor_plan''));',
    'perform public.import_workspace_configuration(p_to, v_snapshot - ''tables'' || jsonb_build_object(''tables'', (v_snapshot->''tables'') - ''floor_plan''), ''mirror'');');
  v_patched := v_patched + 1;

  select pg_get_functiondef(p.oid) into v_def from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'rollback_deployment' limit 1;
  if position('perform public.import_workspace_configuration(v_d.to_workspace_id, v_d.before - ''tables'' || jsonb_build_object(''tables'', (v_d.before->''tables'') - ''floor_plan''));' in v_def) = 0 then
    raise exception '0219: rollback_deployment call site not found';
  end if;
  execute replace(v_def,
    'perform public.import_workspace_configuration(v_d.to_workspace_id, v_d.before - ''tables'' || jsonb_build_object(''tables'', (v_d.before->''tables'') - ''floor_plan''));',
    'perform public.import_workspace_configuration(v_d.to_workspace_id, v_d.before - ''tables'' || jsonb_build_object(''tables'', (v_d.before->''tables'') - ''floor_plan''), ''mirror'');');
  v_patched := v_patched + 1;

  select pg_get_functiondef(p.oid) into v_def from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'create_workspace_twin' limit 1;
  if position('perform public.import_workspace_configuration(twin_id, public.export_workspace_configuration(p_workspace_id));' in v_def) = 0 then
    raise exception '0219: create_workspace_twin call site not found';
  end if;
  execute replace(v_def,
    'perform public.import_workspace_configuration(twin_id, public.export_workspace_configuration(p_workspace_id));',
    'perform public.import_workspace_configuration(twin_id, public.export_workspace_configuration(p_workspace_id), ''mirror'');');
  v_patched := v_patched + 1;

  if v_patched <> 3 then
    raise exception '0219: expected 3 callers patched, patched %', v_patched;
  end if;
end
$callers$;

-- Each entity declares HOW it merges and WHICH group it belongs to.
--
-- `merge_policy` is what the writer above actually does in merge mode;
-- `group` is the only vocabulary the UI shows (#1280, #1307), so that a
-- person chooses "hours and booking" rather than "booking_rules".
--
-- The whole body is restated rather than patched: it is one
-- `jsonb_build_array` of data with no logic, and an anchored patch
-- across eighteen objects would be less readable than the array itself.
--
-- `tariffs` is `replace_setting`, not `keyed_update`. Fee bands
-- PARTITION 0–100, and `entity_row_key` keys them by `from_pct`, so
-- merging a template's (0,50] into a workspace holding (0,40] and
-- (40,100] leaves overlapping ranges — and `member_statement`'s lookup
-- (`from_pct < pct and pct <= to_pct`) then picks one of them
-- arbitrarily. A set that must stay coherent travels whole or not at all.
create or replace function public.deployable_entities()
returns jsonb language sql immutable as $function$
  select jsonb_build_array(
    jsonb_build_object('key', 'identity', 'kind', 'configuration', 'requires', '[]'::jsonb,
      'merge_policy', 'replace_setting', 'group', 'wording',
      'workspace_keys', '["address","street","postal_code","city","default_locale","vat_regime","vat_id","legal_id","tax_exemption_reason","vat_account","invoice_legal"]'::jsonb,
      'tables', '[]'::jsonb),
    jsonb_build_object('key', 'vat', 'kind', 'master_data', 'requires', '[]'::jsonb,
      'merge_policy', 'keyed_update', 'group', 'pricing_credits',
      'workspace_keys', '["subscription_vat_rate"]'::jsonb, 'tables', '["vat_rates"]'::jsonb),
    jsonb_build_object('key', 'tariffs', 'kind', 'master_data', 'requires', '["vat"]'::jsonb,
      'merge_policy', 'replace_setting', 'group', 'pricing_credits',
      'workspace_keys', '["subscription_levels","billing_rules"]'::jsonb, 'tables', '["fee_bands","plans"]'::jsonb),
    jsonb_build_object('key', 'services', 'kind', 'master_data', 'requires', '["vat"]'::jsonb,
      'merge_policy', 'keyed_update', 'group', 'pricing_credits',
      'workspace_keys', '[]'::jsonb, 'tables', '["services"]'::jsonb),
    jsonb_build_object('key', 'packages', 'kind', 'master_data', 'requires', '["vat"]'::jsonb,
      'merge_policy', 'keyed_update', 'group', 'pricing_credits',
      'workspace_keys', '[]'::jsonb, 'tables', '["packages"]'::jsonb),
    jsonb_build_object('key', 'accessories', 'kind', 'master_data', 'requires', '["vat"]'::jsonb,
      'merge_policy', 'keyed_update', 'group', 'space',
      'workspace_keys', '[]'::jsonb, 'tables', '["accessories"]'::jsonb),
    jsonb_build_object('key', 'floor_plan', 'kind', 'master_data', 'requires', '["accessories","sites"]'::jsonb,
      'merge_policy', 'manual', 'group', 'space',
      'workspace_keys', '[]'::jsonb, 'tables', '["floor_plan"]'::jsonb),
    jsonb_build_object('key', 'sites', 'kind', 'master_data', 'requires', '[]'::jsonb,
      'merge_policy', 'keyed_update', 'group', 'space',
      'workspace_keys', '[]'::jsonb, 'tables', '["sites"]'::jsonb),
    jsonb_build_object('key', 'booking_rules', 'kind', 'configuration', 'requires', '[]'::jsonb,
      'merge_policy', 'replace_setting', 'group', 'hours_booking',
      'workspace_keys', '["booking_rules","desk_opacity"]'::jsonb, 'tables', '[]'::jsonb),
    jsonb_build_object('key', 'validation_rules', 'kind', 'configuration', 'requires', '[]'::jsonb,
      'merge_policy', 'keyed_update', 'group', 'roles_access',
      'workspace_keys', '[]'::jsonb, 'tables', '["validation_policies"]'::jsonb),
    jsonb_build_object('key', 'roles', 'kind', 'configuration', 'requires', '[]'::jsonb,
      'merge_policy', 'replace_setting', 'group', 'roles_access',
      'workspace_keys', '["role_permissions"]'::jsonb, 'tables', '[]'::jsonb),
    jsonb_build_object('key', 'payment_instructions', 'kind', 'configuration', 'requires', '[]'::jsonb,
      'merge_policy', 'replace_setting', 'group', 'documents_operations',
      'workspace_keys', '["payment_instructions"]'::jsonb, 'tables', '[]'::jsonb),
    jsonb_build_object('key', 'reminders', 'kind', 'configuration', 'requires', '[]'::jsonb,
      'merge_policy', 'replace_setting', 'group', 'documents_operations',
      'workspace_keys', '["dunning_rules"]'::jsonb, 'tables', '[]'::jsonb),
    jsonb_build_object('key', 'document_design', 'kind', 'reports', 'requires', '[]'::jsonb,
      'merge_policy', 'replace_setting', 'group', 'documents_operations',
      'workspace_keys', '["invoice_pdf_template"]'::jsonb, 'tables', '[]'::jsonb),
    jsonb_build_object('key', 'document_links', 'kind', 'configuration', 'requires', '[]'::jsonb,
      'merge_policy', 'keyed_update', 'group', 'documents_operations',
      'workspace_keys', '[]'::jsonb, 'tables', '["workspace_documents"]'::jsonb),
    jsonb_build_object('key', 'closure_days', 'kind', 'configuration', 'requires', '[]'::jsonb,
      'merge_policy', 'additive', 'group', 'calendar_navigation',
      'workspace_keys', '[]'::jsonb, 'tables', '["closure_days"]'::jsonb),
    jsonb_build_object('key', 'invitations', 'kind', 'configuration', 'requires', '[]'::jsonb,
      'merge_policy', 'replace_setting', 'group', 'wording',
      'workspace_keys', '["invitation_template","invitation_templates","whatsapp_group"]'::jsonb, 'tables', '[]'::jsonb),
    jsonb_build_object('key', 'features', 'kind', 'configuration', 'requires', '[]'::jsonb,
      'merge_policy', 'replace_setting', 'group', 'roles_access',
      'workspace_keys', '["feature_flags"]'::jsonb, 'tables', '[]'::jsonb));
$function$;

revoke execute on function public.deployable_entities() from public, anon;
grant execute on function public.deployable_entities() to authenticated;
