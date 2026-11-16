-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- #3649 (leaf 3b) -- a site and a supplier keep the region of their address.
-- upsert_site and save_supplier gain p_subdivision, stored as its code
-- (subdivision_code, 0785). A caller that does not send it (null) keeps the
-- region already stored, so an older client never erases one. Each function
-- is restated whole from its current definition, with the same refusals.
-- The earlier signature is dropped first, so no overload stays beside the new
-- one: a call by name resolves to one function, and no body without the
-- region rule remains callable. No data changes.

drop function if exists public.upsert_site(uuid, uuid, text, text, text, text, text, text, integer, text, text);

create or replace function public.upsert_site(p_workspace_id uuid, p_id uuid, p_name text, p_street text, p_postal_code text, p_city text, p_country_code text, p_legal_id text, p_sort_order integer DEFAULT 0, p_vat_id text DEFAULT ''::text, p_tax_exemption_reason text DEFAULT ''::text, p_subdivision text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $fn$
declare v_id uuid;
begin
  if not public.has_permission(p_workspace_id, 'manageSites') then raise exception 'admins only' using errcode = 'DKN01'; end if;
  if p_id is null then
    insert into public.sites (workspace_id, name, street, postal_code, city, country_code, legal_id, sort_order, vat_id, tax_exemption_reason, subdivision)
    values (p_workspace_id, btrim(p_name), btrim(coalesce(p_street,'')), btrim(coalesce(p_postal_code,'')), btrim(coalesce(p_city,'')),
            upper(btrim(coalesce(p_country_code,''))), btrim(coalesce(p_legal_id,'')), coalesce(p_sort_order, 0),
            btrim(coalesce(p_vat_id,'')), btrim(coalesce(p_tax_exemption_reason,'')),
            public.subdivision_code(p_subdivision))
    returning id into v_id;
  else
    update public.sites
       set name = btrim(p_name), street = btrim(coalesce(p_street,'')), postal_code = btrim(coalesce(p_postal_code,'')),
           city = btrim(coalesce(p_city,'')), country_code = upper(btrim(coalesce(p_country_code,''))),
           legal_id = btrim(coalesce(p_legal_id,'')), sort_order = coalesce(p_sort_order, sort_order),
           vat_id = btrim(coalesce(p_vat_id,'')), tax_exemption_reason = btrim(coalesce(p_tax_exemption_reason,'')),
           subdivision = case when p_subdivision is null then subdivision else public.subdivision_code(p_subdivision) end
     where id = p_id and workspace_id = p_workspace_id
    returning id into v_id;
    if v_id is null then raise exception 'unknown site' using errcode = 'P0001'; end if;
  end if;
  return v_id;
end;
$fn$;
revoke execute on function public.upsert_site(uuid, uuid, text, text, text, text, text, text, integer, text, text, text)
  from public, anon;
grant execute on function public.upsert_site(uuid, uuid, text, text, text, text, text, text, integer, text, text, text)
  to authenticated, service_role;

drop function if exists public.save_supplier(uuid, uuid, text, text, text, text, text, text, text, text, text);

create or replace function public.save_supplier(p_workspace_id uuid, p_supplier_id uuid, p_name text, p_tax_id text, p_tax_id_kind text, p_street text, p_postal_code text, p_city text, p_country_code text, p_contact text, p_number text, p_subdivision text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $fn$
declare
  v_member uuid := public.supplier_guard(p_workspace_id);
  v_name text := btrim(coalesce(p_name, ''));
  v_entered text := btrim(coalesce(p_tax_id, ''));
  v_kind text := coalesce(nullif(p_tax_id_kind, ''), 'vat');
  v_value text := coalesce(public.supplier_tax_identifier(p_tax_id) ->> 'value', '');
  v_number text := btrim(coalesce(p_number, ''));
  v_id uuid := p_supplier_id;
begin
  if char_length(v_name) not between 1 and 300 then
    raise exception 'a supplier needs a name of 1-300 characters' using errcode = 'P0001';
  end if;
  if v_kind not in ('vat', 'vat_group') then raise exception 'unknown identifier kind' using errcode = 'P0001'; end if;
  if v_value <> '' and v_kind = 'vat' and exists (
       select 1 from public.suppliers s
        where s.workspace_id = p_workspace_id and s.tax_identifier = v_value
          and s.tax_id_kind = 'vat' and s.id is distinct from p_supplier_id) then
    raise exception 'another supplier already has this tax identifier' using errcode = 'P0001';
  end if;
  if v_number <> '' and exists (
       select 1 from public.suppliers s
        where s.workspace_id = p_workspace_id and s.supplier_number = v_number
          and s.id is distinct from p_supplier_id) then
    raise exception 'this supplier number is already used' using errcode = 'P0001';
  end if;
  if p_supplier_id is null then
    insert into public.suppliers
      (workspace_id, supplier_number, name, tax_id_entered, tax_identifier, tax_id_kind,
       street, postal_code, city, country_code, contact, created_by, subdivision)
    values (p_workspace_id,
            case when v_number = '' then public.supplier_next_number(p_workspace_id) else v_number end,
            v_name, left(v_entered, 60), v_value, v_kind,
            coalesce(p_street, ''), coalesce(p_postal_code, ''), coalesce(p_city, ''),
            upper(coalesce(p_country_code, '')), coalesce(p_contact, ''), v_member,
            public.subdivision_code(p_subdivision))
    returning id into v_id;
  else
    update public.suppliers set
      name = v_name, tax_id_entered = left(v_entered, 60), tax_identifier = v_value,
      tax_id_kind = v_kind, street = coalesce(p_street, ''),
      postal_code = coalesce(p_postal_code, ''), city = coalesce(p_city, ''),
      country_code = upper(coalesce(p_country_code, '')), contact = coalesce(p_contact, ''),
      subdivision = case when p_subdivision is null then subdivision else public.subdivision_code(p_subdivision) end,
      supplier_number = case when v_number = '' then supplier_number else v_number end
     where id = p_supplier_id and workspace_id = p_workspace_id;
    if not found then raise exception 'unknown supplier' using errcode = 'P0001'; end if;
  end if;
  return v_id;
end;
$fn$;
revoke execute on function public.save_supplier(uuid, uuid, text, text, text, text, text, text, text, text, text, text)
  from public, anon;
grant execute on function public.save_supplier(uuid, uuid, text, text, text, text, text, text, text, text, text, text)
  to authenticated, service_role;

select public.set_deskilo_schema_version(789);
