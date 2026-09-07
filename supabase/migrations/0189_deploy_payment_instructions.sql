-- SPDX-License-Identifier: 0BSD
-- 0189 — #1010: the payment instructions travel, and so do the report
-- images.
--
-- The bank block an invoice prints — IBAN, BIC, holder, reference — is
-- workspaces.payment_instructions, which the configuration transfer
-- never carried: a deployment dev → prod left the prod's invoices
-- without it. The key joins the transfer and becomes an entity of its
-- own, "Payment instructions", in the configuration group. The document
-- designs reference their images (the logo) by name under the
-- workspace's own storage prefix, so a deployed design pointed at files
-- the target could not read: deploying the designs now returns copy
-- jobs for every report image, exactly as the floor plan does.
do $patch$
declare v_def text; v_old text;
begin
  select pg_get_functiondef(p.oid) into v_def from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'export_workspace_configuration';
  v_old := '      ''feature_flags'', coalesce(w.feature_flags, ''{}''::jsonb)),';
  if position(v_old in v_def) = 0 then raise exception 'export anchor missing'; end if;
  v_def := replace(v_def, v_old, '      ''feature_flags'', coalesce(w.feature_flags, ''{}''::jsonb),' || E'\n' ||
    '      ''payment_instructions'', coalesce(w.payment_instructions, ''{}''::jsonb)),');
  execute v_def;

  select pg_get_functiondef(p.oid) into v_def from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'import_workspace_configuration';
  v_old := '    feature_flags = case when v_ws ? ''feature_flags'' then v_ws->''feature_flags'' else w.feature_flags end';
  if position(v_old in v_def) = 0 then raise exception 'import anchor missing'; end if;
  v_def := replace(v_def, v_old, v_old || ',' || E'\n' ||
    '    payment_instructions = case when v_ws ? ''payment_instructions'' then v_ws->''payment_instructions'' else w.payment_instructions end');
  execute v_def;

  select pg_get_functiondef(p.oid) into v_def from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'deployable_entities';
  v_old := 'jsonb_build_object(''key'', ''reminders'', ''kind'', ''configuration'',';
  if position(v_old in v_def) = 0 then raise exception 'registry anchor missing'; end if;
  v_def := replace(v_def, v_old,
    'jsonb_build_object(''key'', ''payment_instructions'', ''kind'', ''configuration'', ''requires'', ''[]''::jsonb,' || E'\n' ||
    '      ''workspace_keys'', ''["payment_instructions"]''::jsonb, ''tables'', ''[]''::jsonb),' || E'\n' ||
    '    ' || v_old);
  execute v_def;
end;
$patch$;

do $patch$
declare v_def text; v_old text;
begin
  select pg_get_functiondef(p.oid) into v_def from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'deploy_entities';
  v_old := '  select pair_id into v_pair from public.workspaces where id = p_from;';
  if position(v_old in v_def) = 0 then raise exception 'deploy anchor missing'; end if;
  v_def := replace(v_def, v_old,
    '  -- #1010 — the designs'' images: one copy job per file under report/.' || E'\n' ||
    '  if ''document_design'' = any (p_entities) then' || E'\n' ||
    '    v_jobs := v_jobs || coalesce((select jsonb_agg(jsonb_build_object(''from'', o.name, ''to'', regexp_replace(o.name, ''^[^/]+'', p_to::text)))' || E'\n' ||
    '      from storage.objects o where o.bucket_id = ''floor-plans'' and o.name like p_from::text || ''/report/%''), ''[]''::jsonb);' || E'\n' ||
    '  end if;' || E'\n' || v_old);
  execute v_def;
end;
$patch$;
