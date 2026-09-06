-- SPDX-License-Identifier: 0BSD
-- 0177 — #916: the exported space IS the space.
--
-- Schema v3 of the workspace file adds a <configuration> section. Two
-- owner-only functions carry it: export_workspace_configuration returns
-- one jsonb with the workspace's configuration columns and its
-- configuration tables (VAT rates, fee bands, packages, services, plans,
-- closure days, validation policies, sites, document links), ids left
-- out and references expressed by label or name; import_workspace_
-- configuration applies such a document and returns the export of what
-- it wrote, so export → import → export is provably identical.
--
-- What never travels: the invite code, the e-invoice and payment
-- provider credentials (their own tables, never read here), members,
-- reservations, invoices, payments — nothing transactional. Rows a
-- backup does not name are never deleted when something may reference
-- them (VAT rates, packages, services, plans, sites): they are switched
-- off or left alone. Fee bands, closure days, validation policies and
-- document links are replaced wholesale — nothing references them.
--
-- import_floor_plan_v3 is v2 plus the plan attributes v2 dropped: level
-- and desk prices and bookable-as-whole, office prices, the level's site
-- (by name), seat NFC identifiers, and the accessory's VAT rate (by
-- label). The reservation refusal of v2 stays; the configuration import
-- has no such hazard and is a separate call on purpose.

create or replace function public.export_workspace_configuration(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare w public.workspaces;
begin
  if auth.uid() is null or not public.is_owner_of(p_workspace_id) then
    raise exception 'only an owner exports the configuration';
  end if;
  select * into w from public.workspaces where id = p_workspace_id;
  if w.id is null then raise exception 'unknown workspace'; end if;
  return jsonb_build_object(
    'workspace', jsonb_build_object(
      'address', coalesce(w.address, ''),
      'street', coalesce(w.street, ''),
      'postal_code', coalesce(w.postal_code, ''),
      'city', coalesce(w.city, ''),
      'default_locale', coalesce(w.default_locale, ''),
      'whatsapp_group', coalesce(w.whatsapp_group, ''),
      'desk_opacity', coalesce(w.desk_opacity, 100),
      'invitation_template', coalesce(w.invitation_template, ''),
      'invitation_templates', coalesce(w.invitation_templates, '{}'::jsonb),
      'vat_regime', coalesce(w.vat_regime, 'not_subject'),
      'vat_id', coalesce(w.vat_id, ''),
      'legal_id', coalesce(w.legal_id, ''),
      'tax_exemption_reason', coalesce(w.tax_exemption_reason, ''),
      'vat_account', coalesce(w.vat_account, ''),
      'subscription_vat_rate', (select r.label from public.vat_rates r where r.id = w.subscription_vat_rate_id),
      'booking_rules', coalesce(w.booking_rules, '{}'::jsonb),
      'subscription_levels', coalesce(w.subscription_levels, '{}'::jsonb),
      'billing_rules', coalesce(w.billing_rules, '{}'::jsonb),
      'dunning_rules', coalesce(w.dunning_rules, '{}'::jsonb),
      'invoice_legal', coalesce(w.invoice_legal, '{}'::jsonb),
      'role_permissions', coalesce(w.role_permissions, '{}'::jsonb),
      'invoice_pdf_template', coalesce(w.invoice_pdf_template, '{}'::jsonb)),
    'tables', jsonb_build_object(
      'vat_rates', coalesce((select jsonb_agg(jsonb_build_object(
          'label', r.label, 'percent', r.percent, 'category', r.category,
          'is_default', r.is_default, 'active', r.active, 'group_key', r.group_key,
          'outside_base', r.outside_base, 'exemption_reason', r.exemption_reason)
          order by r.label, r.percent) from public.vat_rates r where r.workspace_id = p_workspace_id), '[]'::jsonb),
      'fee_bands', coalesce((select jsonb_agg(jsonb_build_object(
          'from_pct', b.from_pct, 'to_pct', b.to_pct, 'fee_cents', b.fee_cents,
          'overage_fee_cents', b.overage_fee_cents)
          order by b.from_pct) from public.fee_bands b where b.workspace_id = p_workspace_id), '[]'::jsonb),
      'packages', coalesce((select jsonb_agg(jsonb_build_object(
          'name', p.name, 'days', p.days, 'price_cents', p.price_cents, 'active', p.active,
          'vat_rate', (select r.label from public.vat_rates r where r.id = p.vat_rate_id))
          order by p.name) from public.packages p where p.workspace_id = p_workspace_id), '[]'::jsonb),
      'services', coalesce((select jsonb_agg(jsonb_build_object(
          'name', s.name, 'price_cents', s.price_cents, 'active', s.active, 'stock', s.stock,
          'vat_rate', (select r.label from public.vat_rates r where r.id = s.vat_rate_id))
          order by s.name) from public.services s where s.workspace_id = p_workspace_id), '[]'::jsonb),
      'plans', coalesce((select jsonb_agg(jsonb_build_object(
          'name', p.name, 'base_fee_cents', p.base_fee_cents, 'included_half_days', p.included_half_days,
          'overage_fee_cents', p.overage_fee_cents, 'active', p.active)
          order by p.name) from public.plans p where p.workspace_id = p_workspace_id), '[]'::jsonb),
      'closure_days', coalesce((select jsonb_agg(jsonb_build_object(
          'day', c.day::text, 'reason', coalesce(c.reason, ''))
          order by c.day) from public.closure_days c where c.workspace_id = p_workspace_id), '[]'::jsonb),
      'validation_policies', coalesce((select jsonb_agg(jsonb_build_object(
          'event_type', v.event_type, 'required_count', v.required_count,
          'admins_may_validate', v.admins_may_validate, 'owner_required', v.owner_required,
          'auto_validate_admin', v.auto_validate_admin, 'auto_validate_owner', v.auto_validate_owner,
          'validator_scope', v.validator_scope, 'owner_may_self_validate', v.owner_may_self_validate,
          'sequential', v.sequential)
          order by v.event_type) from public.validation_policies v where v.workspace_id = p_workspace_id), '[]'::jsonb),
      'sites', coalesce((select jsonb_agg(jsonb_build_object(
          'name', st.name, 'street', st.street, 'postal_code', st.postal_code, 'city', st.city,
          'country_code', st.country_code, 'legal_id', st.legal_id, 'is_default', st.is_default,
          'sort_order', st.sort_order, 'vat_id', st.vat_id, 'tax_exemption_reason', st.tax_exemption_reason)
          order by st.is_default desc, st.sort_order, st.name) from public.sites st where st.workspace_id = p_workspace_id), '[]'::jsonb),
      'workspace_documents', coalesce((select jsonb_agg(jsonb_build_object(
          'title', d.title, 'category', d.category, 'provider', d.provider, 'url', d.url, 'min_role', d.min_role)
          order by d.title, d.url) from public.workspace_documents d where d.workspace_id = p_workspace_id), '[]'::jsonb)));
end $$;
revoke execute on function public.export_workspace_configuration(uuid) from public, anon;
grant execute on function public.export_workspace_configuration(uuid) to authenticated;

create or replace function public.vat_rate_id_by_label(p_workspace_id uuid, p_label text)
returns uuid language sql stable security definer set search_path = public as $$
  select r.id from public.vat_rates r
   where r.workspace_id = p_workspace_id and p_label is not null and r.label = p_label
   order by r.created_at limit 1;
$$;
revoke execute on function public.vat_rate_id_by_label(uuid, text) from public, anon;

create or replace function public.import_workspace_configuration(p_workspace_id uuid, p_configuration jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_ws jsonb; v_t jsonb; v_row jsonb; v_id uuid;
begin
  if auth.uid() is null or not public.is_owner_of(p_workspace_id) then
    raise exception 'only an owner imports the configuration';
  end if;
  if p_configuration is null or jsonb_typeof(p_configuration) <> 'object' then
    raise exception 'malformed configuration';
  end if;
  v_ws := coalesce(p_configuration->'workspace', '{}'::jsonb);
  v_t := coalesce(p_configuration->'tables', '{}'::jsonb);
  if jsonb_typeof(v_ws) <> 'object' or jsonb_typeof(v_t) <> 'object' then
    raise exception 'malformed configuration';
  end if;

  -- VAT rates first: everything else references them by label. Upsert by
  -- (label, percent); rates the file does not name are switched off,
  -- never deleted — invoices and catalogue rows may point at them.
  if v_t ? 'vat_rates' then
    update public.vat_rates set is_default = false where workspace_id = p_workspace_id;
    for v_row in select value from jsonb_array_elements(v_t->'vat_rates') loop
      select id into v_id from public.vat_rates
       where workspace_id = p_workspace_id and label = v_row->>'label'
         and percent = (v_row->>'percent')::numeric
       order by created_at limit 1;
      if v_id is null then
        insert into public.vat_rates (workspace_id, label, percent, category, is_default, active, group_key, outside_base, exemption_reason)
        values (p_workspace_id, v_row->>'label', (v_row->>'percent')::numeric, v_row->>'category',
                coalesce((v_row->>'is_default')::boolean, false), coalesce((v_row->>'active')::boolean, true),
                v_row->>'group_key', coalesce((v_row->>'outside_base')::boolean, false), v_row->>'exemption_reason');
      else
        update public.vat_rates set category = v_row->>'category',
               is_default = coalesce((v_row->>'is_default')::boolean, false),
               active = coalesce((v_row->>'active')::boolean, true),
               group_key = v_row->>'group_key',
               outside_base = coalesce((v_row->>'outside_base')::boolean, false),
               exemption_reason = v_row->>'exemption_reason'
         where id = v_id;
      end if;
    end loop;
    update public.vat_rates r set active = false
     where r.workspace_id = p_workspace_id
       and not exists (select 1 from jsonb_array_elements(v_t->'vat_rates') e
                        where e.value->>'label' = r.label and (e.value->>'percent')::numeric = r.percent);
  end if;

  -- The workspace's own columns: only the keys the file carries change.
  update public.workspaces w set
    address = case when v_ws ? 'address' then v_ws->>'address' else w.address end,
    street = case when v_ws ? 'street' then v_ws->>'street' else w.street end,
    postal_code = case when v_ws ? 'postal_code' then v_ws->>'postal_code' else w.postal_code end,
    city = case when v_ws ? 'city' then v_ws->>'city' else w.city end,
    default_locale = case when v_ws ? 'default_locale' then v_ws->>'default_locale' else w.default_locale end,
    whatsapp_group = case when v_ws ? 'whatsapp_group' then v_ws->>'whatsapp_group' else w.whatsapp_group end,
    desk_opacity = case when v_ws ? 'desk_opacity' then (v_ws->>'desk_opacity')::smallint else w.desk_opacity end,
    invitation_template = case when v_ws ? 'invitation_template' then v_ws->>'invitation_template' else w.invitation_template end,
    invitation_templates = case when v_ws ? 'invitation_templates' then v_ws->'invitation_templates' else w.invitation_templates end,
    vat_regime = case when v_ws ? 'vat_regime' then v_ws->>'vat_regime' else w.vat_regime end,
    vat_id = case when v_ws ? 'vat_id' then v_ws->>'vat_id' else w.vat_id end,
    legal_id = case when v_ws ? 'legal_id' then v_ws->>'legal_id' else w.legal_id end,
    tax_exemption_reason = case when v_ws ? 'tax_exemption_reason' then v_ws->>'tax_exemption_reason' else w.tax_exemption_reason end,
    vat_account = case when v_ws ? 'vat_account' then v_ws->>'vat_account' else w.vat_account end,
    subscription_vat_rate_id = case when v_ws ? 'subscription_vat_rate'
      then public.vat_rate_id_by_label(p_workspace_id, v_ws->>'subscription_vat_rate') else w.subscription_vat_rate_id end,
    booking_rules = case when v_ws ? 'booking_rules' then v_ws->'booking_rules' else w.booking_rules end,
    subscription_levels = case when v_ws ? 'subscription_levels' then v_ws->'subscription_levels' else w.subscription_levels end,
    billing_rules = case when v_ws ? 'billing_rules' then v_ws->'billing_rules' else w.billing_rules end,
    dunning_rules = case when v_ws ? 'dunning_rules' then v_ws->'dunning_rules' else w.dunning_rules end,
    invoice_legal = case when v_ws ? 'invoice_legal' then v_ws->'invoice_legal' else w.invoice_legal end,
    role_permissions = case when v_ws ? 'role_permissions' then v_ws->'role_permissions' else w.role_permissions end,
    invoice_pdf_template = case when v_ws ? 'invoice_pdf_template' then v_ws->'invoice_pdf_template' else w.invoice_pdf_template end
  where w.id = p_workspace_id;

  if v_t ? 'fee_bands' then
    delete from public.fee_bands where workspace_id = p_workspace_id;
    insert into public.fee_bands (workspace_id, from_pct, to_pct, fee_cents, overage_fee_cents)
    select p_workspace_id, (e.value->>'from_pct')::int, (e.value->>'to_pct')::int,
           (e.value->>'fee_cents')::int, coalesce((e.value->>'overage_fee_cents')::int, 0)
      from jsonb_array_elements(v_t->'fee_bands') e;
  end if;

  if v_t ? 'packages' then
    for v_row in select value from jsonb_array_elements(v_t->'packages') loop
      select id into v_id from public.packages where workspace_id = p_workspace_id and name = v_row->>'name' order by created_at limit 1;
      if v_id is null then
        insert into public.packages (workspace_id, name, days, price_cents, active, vat_rate_id)
        values (p_workspace_id, v_row->>'name', (v_row->>'days')::int, (v_row->>'price_cents')::int,
                coalesce((v_row->>'active')::boolean, true), public.vat_rate_id_by_label(p_workspace_id, v_row->>'vat_rate'));
      else
        update public.packages set days = (v_row->>'days')::int, price_cents = (v_row->>'price_cents')::int,
               active = coalesce((v_row->>'active')::boolean, true),
               vat_rate_id = public.vat_rate_id_by_label(p_workspace_id, v_row->>'vat_rate')
         where id = v_id;
      end if;
    end loop;
    update public.packages p set active = false where p.workspace_id = p_workspace_id
       and not exists (select 1 from jsonb_array_elements(v_t->'packages') e where e.value->>'name' = p.name);
  end if;

  if v_t ? 'services' then
    for v_row in select value from jsonb_array_elements(v_t->'services') loop
      select id into v_id from public.services where workspace_id = p_workspace_id and name = v_row->>'name' order by created_at limit 1;
      if v_id is null then
        insert into public.services (workspace_id, name, price_cents, active, stock, vat_rate_id)
        values (p_workspace_id, v_row->>'name', (v_row->>'price_cents')::int, coalesce((v_row->>'active')::boolean, true),
                (v_row->>'stock')::int, public.vat_rate_id_by_label(p_workspace_id, v_row->>'vat_rate'));
      else
        update public.services set price_cents = (v_row->>'price_cents')::int,
               active = coalesce((v_row->>'active')::boolean, true), stock = (v_row->>'stock')::int,
               vat_rate_id = public.vat_rate_id_by_label(p_workspace_id, v_row->>'vat_rate')
         where id = v_id;
      end if;
    end loop;
    update public.services s set active = false where s.workspace_id = p_workspace_id
       and not exists (select 1 from jsonb_array_elements(v_t->'services') e where e.value->>'name' = s.name);
  end if;

  if v_t ? 'plans' then
    for v_row in select value from jsonb_array_elements(v_t->'plans') loop
      select id into v_id from public.plans where workspace_id = p_workspace_id and name = v_row->>'name' order by created_at limit 1;
      if v_id is null then
        insert into public.plans (workspace_id, name, base_fee_cents, included_half_days, overage_fee_cents, active)
        values (p_workspace_id, v_row->>'name', (v_row->>'base_fee_cents')::int, (v_row->>'included_half_days')::int,
                (v_row->>'overage_fee_cents')::int, coalesce((v_row->>'active')::boolean, true));
      else
        update public.plans set base_fee_cents = (v_row->>'base_fee_cents')::int,
               included_half_days = (v_row->>'included_half_days')::int,
               overage_fee_cents = (v_row->>'overage_fee_cents')::int,
               active = coalesce((v_row->>'active')::boolean, true)
         where id = v_id;
      end if;
    end loop;
    update public.plans p set active = false where p.workspace_id = p_workspace_id
       and not exists (select 1 from jsonb_array_elements(v_t->'plans') e where e.value->>'name' = p.name);
  end if;

  if v_t ? 'closure_days' then
    delete from public.closure_days where workspace_id = p_workspace_id;
    insert into public.closure_days (workspace_id, day, reason)
    select p_workspace_id, (e.value->>'day')::date, coalesce(e.value->>'reason', '')
      from jsonb_array_elements(v_t->'closure_days') e;
  end if;

  if v_t ? 'validation_policies' then
    delete from public.validation_policies where workspace_id = p_workspace_id;
    insert into public.validation_policies (workspace_id, event_type, required_count, admins_may_validate, owner_required,
        auto_validate_admin, auto_validate_owner, validator_scope, owner_may_self_validate, sequential)
    select p_workspace_id, e.value->>'event_type', (e.value->>'required_count')::int,
           coalesce((e.value->>'admins_may_validate')::boolean, true), coalesce((e.value->>'owner_required')::boolean, false),
           coalesce((e.value->>'auto_validate_admin')::boolean, false), coalesce((e.value->>'auto_validate_owner')::boolean, false),
           e.value->>'validator_scope', coalesce((e.value->>'owner_may_self_validate')::boolean, false),
           coalesce((e.value->>'sequential')::boolean, false)
      from jsonb_array_elements(v_t->'validation_policies') e;
  end if;

  if v_t ? 'sites' then
    update public.sites set is_default = false where workspace_id = p_workspace_id;
    for v_row in select value from jsonb_array_elements(v_t->'sites') loop
      select id into v_id from public.sites where workspace_id = p_workspace_id and name = v_row->>'name' order by created_at limit 1;
      if v_id is null then
        insert into public.sites (workspace_id, name, street, postal_code, city, country_code, legal_id, is_default, sort_order, vat_id, tax_exemption_reason)
        values (p_workspace_id, v_row->>'name', coalesce(v_row->>'street', ''), coalesce(v_row->>'postal_code', ''), coalesce(v_row->>'city', ''),
                coalesce(v_row->>'country_code', ''), coalesce(v_row->>'legal_id', ''), coalesce((v_row->>'is_default')::boolean, false),
                coalesce((v_row->>'sort_order')::int, 0), coalesce(v_row->>'vat_id', ''), coalesce(v_row->>'tax_exemption_reason', ''));
      else
        update public.sites set street = coalesce(v_row->>'street', ''), postal_code = coalesce(v_row->>'postal_code', ''),
               city = coalesce(v_row->>'city', ''), country_code = coalesce(v_row->>'country_code', ''),
               legal_id = coalesce(v_row->>'legal_id', ''), is_default = coalesce((v_row->>'is_default')::boolean, false),
               sort_order = coalesce((v_row->>'sort_order')::int, 0), vat_id = coalesce(v_row->>'vat_id', ''),
               tax_exemption_reason = coalesce(v_row->>'tax_exemption_reason', '')
         where id = v_id;
      end if;
    end loop;
  end if;

  if v_t ? 'workspace_documents' then
    delete from public.workspace_documents where workspace_id = p_workspace_id;
    insert into public.workspace_documents (workspace_id, title, category, provider, url, min_role)
    select p_workspace_id, e.value->>'title', e.value->>'category', e.value->>'provider', e.value->>'url', e.value->>'min_role'
      from jsonb_array_elements(v_t->'workspace_documents') e;
  end if;

  return public.export_workspace_configuration(p_workspace_id);
end $$;
revoke execute on function public.import_workspace_configuration(uuid, jsonb) from public, anon;
grant execute on function public.import_workspace_configuration(uuid, jsonb) to authenticated;

-- import_floor_plan_v3 = v2 patched at asserted anchors.
do $patch$
declare v_def text; v_old text;
begin
  select pg_get_functiondef(p.oid) into v_def from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'import_floor_plan_v2';
  v_old := 'public.import_floor_plan_v2(';
  if position(v_old in v_def) = 0 then raise exception '0177: anchor name missing'; end if;
  v_def := replace(v_def, v_old, 'public.import_floor_plan_v3(');

  v_old := E'      (workspace_id, name, supplement_cents, active, sort_order)\n    values (\n      p_workspace_id,\n      v_accessory->>''name'',\n      (v_accessory->>''supplement_cents'')::int,\n      (v_accessory->>''active'')::boolean,\n      (v_accessory->>''sort_order'')::int\n    )\n    on conflict (workspace_id, name) do update\n      set supplement_cents = excluded.supplement_cents,\n          active = excluded.active,\n          sort_order = excluded.sort_order;';
  if position(v_old in v_def) = 0 then raise exception '0177: anchor accessories missing'; end if;
  v_def := replace(v_def, v_old,
    E'      (workspace_id, name, supplement_cents, active, sort_order, vat_rate_id)\n    values (\n      p_workspace_id,\n      v_accessory->>''name'',\n      (v_accessory->>''supplement_cents'')::int,\n      (v_accessory->>''active'')::boolean,\n      (v_accessory->>''sort_order'')::int,\n      public.vat_rate_id_by_label(p_workspace_id, v_accessory->>''vat_rate'')\n    )\n    on conflict (workspace_id, name) do update\n      set supplement_cents = excluded.supplement_cents,\n          active = excluded.active,\n          sort_order = excluded.sort_order,\n          vat_rate_id = case when v_accessory ? ''vat_rate'' then excluded.vat_rate_id else public.accessories.vat_rate_id end;');

  v_old := E'    insert into public.levels (workspace_id, name, sort_order)\n      values (p_workspace_id, v_level->>''name'', (v_level->>''sort_order'')::int)';
  if position(v_old in v_def) = 0 then raise exception '0177: anchor levels missing'; end if;
  v_def := replace(v_def, v_old,
    E'    insert into public.levels (workspace_id, name, sort_order, price_cents, bookable_as_whole, site_id)\n      values (p_workspace_id, v_level->>''name'', (v_level->>''sort_order'')::int,\n              coalesce((v_level->>''price_cents'')::int, 0), coalesce((v_level->>''bookable_as_whole'')::boolean, false),\n              (select st.id from public.sites st where st.workspace_id = p_workspace_id and st.name = v_level->>''site'' order by st.created_at limit 1))');

  v_old := E'        (workspace_id, level_id, name, color, bookable_as_whole, x, y, w, h)\n      values (\n        p_workspace_id, v_level_id,\n        v_office->>''name'',\n        (v_office->>''color'')::int,\n        (v_office->>''bookable_as_whole'')::boolean,\n        (v_office->>''x'')::int, (v_office->>''y'')::int,\n        (v_office->>''w'')::int, (v_office->>''h'')::int\n      )';
  if position(v_old in v_def) = 0 then raise exception '0177: anchor offices missing'; end if;
  v_def := replace(v_def, v_old,
    E'        (workspace_id, level_id, name, color, bookable_as_whole, x, y, w, h, price_cents)\n      values (\n        p_workspace_id, v_level_id,\n        v_office->>''name'',\n        (v_office->>''color'')::int,\n        (v_office->>''bookable_as_whole'')::boolean,\n        (v_office->>''x'')::int, (v_office->>''y'')::int,\n        (v_office->>''w'')::int, (v_office->>''h'')::int,\n        coalesce((v_office->>''price_cents'')::int, 0)\n      )');

  v_old := E'        insert into public.desks (workspace_id, office_id, name, x, y, w, h)\n        values (\n          p_workspace_id, v_office_id,\n          v_desk->>''name'',\n          (v_desk->>''x'')::int, (v_desk->>''y'')::int,\n          (v_desk->>''w'')::int, (v_desk->>''h'')::int\n        )';
  if position(v_old in v_def) = 0 then raise exception '0177: anchor desks missing'; end if;
  v_def := replace(v_def, v_old,
    E'        insert into public.desks (workspace_id, office_id, name, x, y, w, h, price_cents, bookable_as_whole)\n        values (\n          p_workspace_id, v_office_id,\n          v_desk->>''name'',\n          (v_desk->>''x'')::int, (v_desk->>''y'')::int,\n          (v_desk->>''w'')::int, (v_desk->>''h'')::int,\n          coalesce((v_desk->>''price_cents'')::int, 0), coalesce((v_desk->>''bookable_as_whole'')::boolean, false)\n        )');

  v_old := E'             amenities, blocked_from, blocked_to)\n          values (\n            p_workspace_id, v_desk_id,\n            v_seat->>''name'',\n            (v_seat->>''x'')::int, (v_seat->>''y'')::int,\n            v_seat->>''orientation'',\n            coalesce(v_seat->>''chair'', ''''),\n            v_amenities,\n            (v_seat->>''blocked_from'')::timestamptz,\n            (v_seat->>''blocked_to'')::timestamptz\n          )';
  if position(v_old in v_def) = 0 then raise exception '0177: anchor seats missing'; end if;
  v_def := replace(v_def, v_old,
    E'             amenities, blocked_from, blocked_to, nfc_uid)\n          values (\n            p_workspace_id, v_desk_id,\n            v_seat->>''name'',\n            (v_seat->>''x'')::int, (v_seat->>''y'')::int,\n            v_seat->>''orientation'',\n            coalesce(v_seat->>''chair'', ''''),\n            v_amenities,\n            (v_seat->>''blocked_from'')::timestamptz,\n            (v_seat->>''blocked_to'')::timestamptz,\n            nullif(v_seat->>''nfc_uid'', '''')\n          )');
  execute v_def;
end
$patch$;
revoke execute on function public.import_floor_plan_v3(uuid, jsonb, jsonb) from public, anon;
grant execute on function public.import_floor_plan_v3(uuid, jsonb, jsonb) to authenticated;
