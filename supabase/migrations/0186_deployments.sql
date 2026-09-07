-- SPDX-License-Identifier: 0BSD
-- 0186 — #988: deployable entities, the preview, the deploy, the journal.
--
-- An ENTITY is a named slice of the configuration transfer (#916): the
-- workspace keys and the tables it owns, what it depends on, and its
-- kind (configuration or master data). The registry is one function;
-- export_entities filters the transfer document to the chosen entities;
-- preview_deployment diffs the two sides per entity by natural key;
-- deploy_entities applies the slice to the twin in one transaction and
-- journals it with what the target held before, so a deployment can be
-- rolled back. Transactional data never moves: the registry does not
-- know members, reservations, ledgers, invoices, payments or events.
--
-- Direction follows the side the actor stands on: into the prod needs
-- deployToProd on the source; into the dev needs deployToDev. The
-- transfer guards (exportData, manageConfiguration) are satisfied by
-- the deployment itself, through a transaction-local setting.

-- ── the registry ───────────────────────────────────────────────────
create or replace function public.deployable_entities()
returns jsonb language sql immutable as $fn$
  select jsonb_build_array(
    jsonb_build_object('key', 'identity', 'kind', 'configuration', 'requires', '[]'::jsonb,
      'workspace_keys', '["address","street","postal_code","city","default_locale","vat_regime","vat_id","legal_id","tax_exemption_reason","vat_account","invoice_legal"]'::jsonb,
      'tables', '[]'::jsonb),
    jsonb_build_object('key', 'vat', 'kind', 'master_data', 'requires', '[]'::jsonb,
      'workspace_keys', '["subscription_vat_rate"]'::jsonb, 'tables', '["vat_rates"]'::jsonb),
    jsonb_build_object('key', 'tariffs', 'kind', 'master_data', 'requires', '["vat"]'::jsonb,
      'workspace_keys', '["subscription_levels","billing_rules"]'::jsonb, 'tables', '["fee_bands","plans"]'::jsonb),
    jsonb_build_object('key', 'services', 'kind', 'master_data', 'requires', '["vat"]'::jsonb,
      'workspace_keys', '[]'::jsonb, 'tables', '["services"]'::jsonb),
    jsonb_build_object('key', 'packages', 'kind', 'master_data', 'requires', '["vat"]'::jsonb,
      'workspace_keys', '[]'::jsonb, 'tables', '["packages"]'::jsonb),
    jsonb_build_object('key', 'accessories', 'kind', 'master_data', 'requires', '["vat"]'::jsonb,
      'workspace_keys', '[]'::jsonb, 'tables', '["accessories"]'::jsonb),
    jsonb_build_object('key', 'sites', 'kind', 'master_data', 'requires', '[]'::jsonb,
      'workspace_keys', '[]'::jsonb, 'tables', '["sites"]'::jsonb),
    jsonb_build_object('key', 'booking_rules', 'kind', 'configuration', 'requires', '[]'::jsonb,
      'workspace_keys', '["booking_rules","desk_opacity"]'::jsonb, 'tables', '[]'::jsonb),
    jsonb_build_object('key', 'validation_rules', 'kind', 'configuration', 'requires', '[]'::jsonb,
      'workspace_keys', '[]'::jsonb, 'tables', '["validation_policies"]'::jsonb),
    jsonb_build_object('key', 'roles', 'kind', 'configuration', 'requires', '[]'::jsonb,
      'workspace_keys', '["role_permissions"]'::jsonb, 'tables', '[]'::jsonb),
    jsonb_build_object('key', 'reminders', 'kind', 'configuration', 'requires', '[]'::jsonb,
      'workspace_keys', '["dunning_rules"]'::jsonb, 'tables', '[]'::jsonb),
    jsonb_build_object('key', 'document_design', 'kind', 'configuration', 'requires', '[]'::jsonb,
      'workspace_keys', '["invoice_pdf_template"]'::jsonb, 'tables', '[]'::jsonb),
    jsonb_build_object('key', 'document_links', 'kind', 'configuration', 'requires', '[]'::jsonb,
      'workspace_keys', '[]'::jsonb, 'tables', '["workspace_documents"]'::jsonb),
    jsonb_build_object('key', 'closure_days', 'kind', 'configuration', 'requires', '[]'::jsonb,
      'workspace_keys', '[]'::jsonb, 'tables', '["closure_days"]'::jsonb),
    jsonb_build_object('key', 'invitations', 'kind', 'configuration', 'requires', '[]'::jsonb,
      'workspace_keys', '["invitation_template","invitation_templates","whatsapp_group"]'::jsonb, 'tables', '[]'::jsonb),
    jsonb_build_object('key', 'features', 'kind', 'configuration', 'requires', '[]'::jsonb,
      'workspace_keys', '["feature_flags"]'::jsonb, 'tables', '[]'::jsonb));
$fn$;

-- The natural key of each table's rows, for the diff.
create or replace function public.entity_row_key(p_table text, p_row jsonb)
returns text language sql immutable as $fn$
  select case p_table
    when 'vat_rates' then (p_row->>'label') || '@' || (p_row->>'percent')
    when 'fee_bands' then p_row->>'from_pct'
    when 'closure_days' then p_row->>'day'
    when 'validation_policies' then coalesce(p_row->>'event_type', 'default')
    when 'workspace_documents' then (p_row->>'title') || '@' || (p_row->>'url')
    else p_row->>'name' end;
$fn$;

-- ── the transfer learns features and accessories ───────────────────
do $patch$
declare v_def text; v_old text;
begin
  select pg_get_functiondef(p.oid) into v_def from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'export_workspace_configuration';
  v_old := '  if auth.uid() is null or not public.has_permission(p_workspace_id, ''exportData'') then';
  if position(v_old in v_def) = 0 then raise exception 'export guard anchor missing'; end if;
  v_def := replace(v_def, v_old, '  if auth.uid() is null or not (public.has_permission(p_workspace_id, ''exportData'') or public.deploying_touches(p_workspace_id)) then');
  v_old := '      ''invoice_pdf_template'', coalesce(w.invoice_pdf_template, ''{}''::jsonb)),';
  if position(v_old in v_def) = 0 then raise exception 'export keys anchor missing'; end if;
  v_def := replace(v_def, v_old, '      ''invoice_pdf_template'', coalesce(w.invoice_pdf_template, ''{}''::jsonb),' || E'\n' ||
    '      ''feature_flags'', coalesce(w.feature_flags, ''{}''::jsonb)),');
  v_old := '      ''workspace_documents'', coalesce((select jsonb_agg(jsonb_build_object(';
  if position(v_old in v_def) = 0 then raise exception 'export tables anchor missing'; end if;
  v_def := replace(v_def, v_old,
    '      ''accessories'', coalesce((select jsonb_agg(jsonb_build_object(' || E'\n' ||
    '          ''name'', a.name, ''supplement_cents'', a.supplement_cents, ''active'', a.active, ''sort_order'', a.sort_order,' || E'\n' ||
    '          ''vat_rate'', (select r.label from public.vat_rates r where r.id = a.vat_rate_id))' || E'\n' ||
    '          order by a.sort_order, a.name) from public.accessories a where a.workspace_id = p_workspace_id), ''[]''::jsonb),' || E'\n' ||
    v_old);
  execute v_def;

  select pg_get_functiondef(p.oid) into v_def from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'import_workspace_configuration';
  v_old := '  if auth.uid() is null or not public.has_permission(p_workspace_id, ''manageConfiguration'') then';
  if position(v_old in v_def) = 0 then raise exception 'import guard anchor missing'; end if;
  v_def := replace(v_def, v_old, '  if auth.uid() is null or not (public.has_permission(p_workspace_id, ''manageConfiguration'') or public.deploying_touches(p_workspace_id)) then');
  v_old := '    invoice_pdf_template = case when v_ws ? ''invoice_pdf_template'' then v_ws->''invoice_pdf_template'' else w.invoice_pdf_template end';
  if position(v_old in v_def) = 0 then raise exception 'import keys anchor missing'; end if;
  v_def := replace(v_def, v_old, v_old || ',' || E'\n' ||
    '    feature_flags = case when v_ws ? ''feature_flags'' then v_ws->''feature_flags'' else w.feature_flags end');
  v_old := '  if v_t ? ''workspace_documents'' then';
  if position(v_old in v_def) = 0 then raise exception 'import tables anchor missing'; end if;
  v_def := replace(v_def, v_old,
    '  if v_t ? ''accessories'' then' || E'\n' ||
    '    for v_row in select value from jsonb_array_elements(v_t->''accessories'') loop' || E'\n' ||
    '      select id into v_id from public.accessories where workspace_id = p_workspace_id and name = v_row->>''name'' order by created_at limit 1;' || E'\n' ||
    '      if v_id is null then' || E'\n' ||
    '        insert into public.accessories (workspace_id, name, supplement_cents, active, sort_order, vat_rate_id)' || E'\n' ||
    '        values (p_workspace_id, v_row->>''name'', coalesce((v_row->>''supplement_cents'')::int, 0), coalesce((v_row->>''active'')::boolean, true),' || E'\n' ||
    '                coalesce((v_row->>''sort_order'')::int, 0), public.vat_rate_id_by_label(p_workspace_id, v_row->>''vat_rate''));' || E'\n' ||
    '      else' || E'\n' ||
    '        update public.accessories set supplement_cents = coalesce((v_row->>''supplement_cents'')::int, 0),' || E'\n' ||
    '               active = coalesce((v_row->>''active'')::boolean, true), sort_order = coalesce((v_row->>''sort_order'')::int, 0),' || E'\n' ||
    '               vat_rate_id = public.vat_rate_id_by_label(p_workspace_id, v_row->>''vat_rate'')' || E'\n' ||
    '         where id = v_id;' || E'\n' ||
    '      end if;' || E'\n' ||
    '    end loop;' || E'\n' ||
    '    update public.accessories a set active = false where a.workspace_id = p_workspace_id' || E'\n' ||
    '       and not exists (select 1 from jsonb_array_elements(v_t->''accessories'') e where e.value->>''name'' = a.name);' || E'\n' ||
    '  end if;' || E'\n\n' || v_old);
  execute v_def;
end;
$patch$;

-- True while a deployment of this transaction touches the workspace.
create or replace function public.deploying_touches(p_workspace_id uuid)
returns boolean language sql stable as $fn$
  select p_workspace_id::text = any (string_to_array(coalesce(current_setting('deskilo.deploying', true), ''), ':'));
$fn$;

-- ── the slice ──────────────────────────────────────────────────────
create or replace function public.export_entities(p_workspace_id uuid, p_entities text[])
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_full jsonb;
  v_ws jsonb := '{}'::jsonb;
  v_t jsonb := '{}'::jsonb;
  v_e jsonb;
  v_k text;
begin
  v_full := public.export_workspace_configuration(p_workspace_id);
  for v_e in select value from jsonb_array_elements(public.deployable_entities()) loop
    if (v_e->>'key') = any (p_entities) then
      for v_k in select jsonb_array_elements_text(v_e->'workspace_keys') loop
        if v_full->'workspace' ? v_k then v_ws := v_ws || jsonb_build_object(v_k, v_full->'workspace'->v_k); end if;
      end loop;
      for v_k in select jsonb_array_elements_text(v_e->'tables') loop
        if v_full->'tables' ? v_k then v_t := v_t || jsonb_build_object(v_k, v_full->'tables'->v_k); end if;
      end loop;
    end if;
  end loop;
  return jsonb_build_object('entities', to_jsonb(p_entities), 'workspace', v_ws, 'tables', v_t);
end;
$fn$;

-- The pair check and the direction, in one place.
create or replace function public.deployment_direction(p_from uuid, p_to uuid)
returns text language plpgsql stable security definer set search_path = public as $fn$
declare v_from public.workspaces; v_to public.workspaces;
begin
  select * into v_from from public.workspaces where id = p_from;
  select * into v_to from public.workspaces where id = p_to;
  if v_from.id is null or v_to.id is null then raise exception 'unknown workspace'; end if;
  if v_from.id = v_to.id or v_from.pair_id is null or v_from.pair_id is distinct from v_to.pair_id then
    raise exception 'the two workspaces are not a pair';
  end if;
  return case when v_to.environment = 'prod' then 'dev_to_prod' else 'prod_to_dev' end;
end;
$fn$;

create or replace function public.may_deploy(p_from uuid, p_to uuid)
returns boolean language sql stable security definer set search_path = public as $fn$
  select case public.deployment_direction(p_from, p_to)
    when 'dev_to_prod' then public.has_permission(p_from, 'deployToProd')
    else public.has_permission(p_from, 'deployToDev') end;
$fn$;

-- ── the preview ────────────────────────────────────────────────────
create or replace function public.preview_deployment(p_from uuid, p_to uuid, p_entities text[])
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_src jsonb; v_dst jsonb; v_e jsonb; v_k text; v_out jsonb := '[]'::jsonb;
  v_added int; v_changed int; v_removed int; v_keys text[]; v_row jsonb; v_other jsonb; v_key text;
begin
  if not public.may_deploy(p_from, p_to) then raise exception 'not allowed to deploy in this direction'; end if;
  perform set_config('deskilo.deploying', p_from::text || ':' || p_to::text, true);
  v_src := public.export_entities(p_from, p_entities);
  v_dst := public.export_entities(p_to, p_entities);
  for v_e in select value from jsonb_array_elements(public.deployable_entities()) loop
    if not ((v_e->>'key') = any (p_entities)) then continue; end if;
    v_added := 0; v_changed := 0; v_removed := 0; v_keys := '{}';
    for v_k in select jsonb_array_elements_text(v_e->'workspace_keys') loop
      if (v_src->'workspace'->v_k) is distinct from (v_dst->'workspace'->v_k) then
        v_changed := v_changed + 1; v_keys := v_keys || v_k;
      end if;
    end loop;
    for v_k in select jsonb_array_elements_text(v_e->'tables') loop
      for v_row in select value from jsonb_array_elements(coalesce(v_src->'tables'->v_k, '[]'::jsonb)) loop
        v_key := public.entity_row_key(v_k, v_row);
        select value into v_other from jsonb_array_elements(coalesce(v_dst->'tables'->v_k, '[]'::jsonb)) o
         where public.entity_row_key(v_k, o.value) = v_key limit 1;
        if v_other is null then v_added := v_added + 1; v_keys := v_keys || ('+' || v_key);
        elsif v_other <> v_row then v_changed := v_changed + 1; v_keys := v_keys || ('~' || v_key); end if;
        v_other := null;
      end loop;
      for v_row in select value from jsonb_array_elements(coalesce(v_dst->'tables'->v_k, '[]'::jsonb)) loop
        v_key := public.entity_row_key(v_k, v_row);
        if not exists (select 1 from jsonb_array_elements(coalesce(v_src->'tables'->v_k, '[]'::jsonb)) s
                        where public.entity_row_key(v_k, s.value) = v_key) then
          v_removed := v_removed + 1; v_keys := v_keys || ('-' || v_key);
        end if;
      end loop;
    end loop;
    v_out := v_out || jsonb_build_object('key', v_e->>'key', 'kind', v_e->>'kind',
      'added', v_added, 'changed', v_changed, 'removed', v_removed, 'details', to_jsonb(v_keys));
  end loop;
  return jsonb_build_object('direction', public.deployment_direction(p_from, p_to), 'entities', v_out);
end;
$fn$;

-- ── the journal and the deploy ─────────────────────────────────────
create table if not exists public.deployments (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  pair_id uuid not null,
  from_workspace_id uuid not null references public.workspaces(id) on delete cascade,
  to_workspace_id uuid not null references public.workspaces(id) on delete cascade,
  direction text not null check (direction in ('dev_to_prod', 'prod_to_dev')),
  entities text[] not null,
  snapshot jsonb not null,
  before jsonb not null,
  summary jsonb not null default '[]'::jsonb,
  actor_user_id uuid,
  actor_name text not null default '',
  rolled_back_at timestamptz,
  created_at timestamptz not null default now()
);
select public.ensure_system_columns('deployments');
create index if not exists deployments_pair_idx on public.deployments (pair_id, created_at desc);
alter table public.deployments enable row level security;
drop policy if exists deployments_select on public.deployments;
create policy deployments_select on public.deployments for select to authenticated
  using (public.has_permission(from_workspace_id, 'deployToDev') or public.has_permission(to_workspace_id, 'deployToDev'));

create or replace function public.deploy_entities(p_from uuid, p_to uuid, p_entities text[])
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_direction text; v_preview jsonb; v_snapshot jsonb; v_before jsonb; v_id uuid; v_pair uuid; v_name text;
begin
  if p_entities is null or array_length(p_entities, 1) is null then raise exception 'nothing to deploy'; end if;
  v_direction := public.deployment_direction(p_from, p_to);
  if not public.may_deploy(p_from, p_to) then raise exception 'not allowed to deploy in this direction'; end if;
  perform set_config('deskilo.deploying', p_from::text || ':' || p_to::text, true);
  v_preview := public.preview_deployment(p_from, p_to, p_entities);
  v_before := public.export_entities(p_to, p_entities);
  v_snapshot := public.export_entities(p_from, p_entities);
  perform public.import_workspace_configuration(p_to, v_snapshot);
  select pair_id into v_pair from public.workspaces where id = p_from;
  select coalesce(display_name, '') into v_name from public.profiles where id = auth.uid();
  insert into public.deployments (workspace_id, pair_id, from_workspace_id, to_workspace_id, direction, entities, snapshot, before, summary, actor_user_id, actor_name)
  values (p_to, v_pair, p_from, p_to, v_direction, p_entities, v_snapshot, v_before, v_preview->'entities', auth.uid(), v_name)
  returning id into v_id;
  return jsonb_build_object('id', v_id, 'direction', v_direction, 'entities', v_preview->'entities');
end;
$fn$;

-- Undo the last deployment of a pair: what the target held before goes back.
create or replace function public.rollback_deployment(p_deployment_id uuid)
returns void language plpgsql security definer set search_path = public as $fn$
declare v_d public.deployments;
begin
  select * into v_d from public.deployments where id = p_deployment_id;
  if v_d.id is null then raise exception 'unknown deployment'; end if;
  if v_d.rolled_back_at is not null then raise exception 'already rolled back'; end if;
  if not public.may_deploy(v_d.from_workspace_id, v_d.to_workspace_id) then raise exception 'not allowed to deploy in this direction'; end if;
  if exists (select 1 from public.deployments d where d.pair_id = v_d.pair_id and d.to_workspace_id = v_d.to_workspace_id
              and d.created_at > v_d.created_at and d.rolled_back_at is null) then
    raise exception 'a later deployment stands on this side; roll that one back first';
  end if;
  perform set_config('deskilo.deploying', v_d.from_workspace_id::text || ':' || v_d.to_workspace_id::text, true);
  perform public.import_workspace_configuration(v_d.to_workspace_id, v_d.before);
  update public.deployments set rolled_back_at = now() where id = p_deployment_id;
end;
$fn$;
revoke execute on function public.deploy_entities(uuid, uuid, text[]) from public, anon;
revoke execute on function public.rollback_deployment(uuid) from public, anon;
revoke execute on function public.preview_deployment(uuid, uuid, text[]) from public, anon;
revoke execute on function public.export_entities(uuid, text[]) from public, anon;
