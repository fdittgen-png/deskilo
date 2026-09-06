-- SPDX-License-Identifier: 0BSD
-- 0171 — #948: registration and exemption numbers per site.
--
-- In France the VAT number is the legal entity's (FR + SIREN) and an
-- exemption belongs to the entity; each establishment has its own
-- SIRET (0168 carries it). A site that is a DISTINCT legal entity — a
-- subsidiary trading under the workspace's roof — may nevertheless
-- carry its own VAT number and exemption reason; the seller party of
-- a document at that site then names them. The client warns that such
-- a site is usually a separate workspace.
alter table public.sites
  add column if not exists vat_id text not null default '' check (char_length(vat_id) <= 40),
  add column if not exists tax_exemption_reason text not null default '' check (char_length(tax_exemption_reason) <= 200);

-- A defaulted parameter on an existing function needs the old signature
-- dropped first, or two overloads survive and PostgREST cannot choose.
drop function if exists public.upsert_site(uuid, uuid, text, text, text, text, text, text, int);
create or replace function public.upsert_site(
  p_workspace_id uuid, p_id uuid, p_name text, p_street text, p_postal_code text, p_city text,
  p_country_code text, p_legal_id text, p_sort_order int default 0,
  p_vat_id text default '', p_tax_exemption_reason text default '')
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_id uuid;
begin
  if not public.is_admin_of(p_workspace_id) then raise exception 'admins only'; end if;
  if p_id is null then
    insert into public.sites (workspace_id, name, street, postal_code, city, country_code, legal_id, sort_order, vat_id, tax_exemption_reason)
    values (p_workspace_id, btrim(p_name), btrim(coalesce(p_street,'')), btrim(coalesce(p_postal_code,'')), btrim(coalesce(p_city,'')),
            upper(btrim(coalesce(p_country_code,''))), btrim(coalesce(p_legal_id,'')), coalesce(p_sort_order, 0),
            btrim(coalesce(p_vat_id,'')), btrim(coalesce(p_tax_exemption_reason,'')))
    returning id into v_id;
  else
    update public.sites
       set name = btrim(p_name), street = btrim(coalesce(p_street,'')), postal_code = btrim(coalesce(p_postal_code,'')),
           city = btrim(coalesce(p_city,'')), country_code = upper(btrim(coalesce(p_country_code,''))),
           legal_id = btrim(coalesce(p_legal_id,'')), sort_order = coalesce(p_sort_order, sort_order),
           vat_id = btrim(coalesce(p_vat_id,'')), tax_exemption_reason = btrim(coalesce(p_tax_exemption_reason,''))
     where id = p_id and workspace_id = p_workspace_id
    returning id into v_id;
    if v_id is null then raise exception 'unknown site'; end if;
  end if;
  return v_id;
end;
$$;
grant execute on function public.upsert_site(uuid, uuid, text, text, text, text, text, text, int, text, text) to authenticated;

-- The seller party of a document at such a site names its numbers.
do $patch$
declare v_def text; v_old text;
begin
  select pg_get_functiondef(p.oid) into v_def from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_invoice' and p.prokind='f';
  v_old := E'      ''vat_id'', coalesce(v_workspace.vat_id, ''''),\n';
  if position(v_old in v_def) = 0 then raise exception '0171: anchor A missing'; end if;
  v_def := replace(v_def, v_old, E'      ''vat_id'', case when v_site.id is not null and not v_site.is_default and v_site.vat_id <> '''' then v_site.vat_id else coalesce(v_workspace.vat_id, '''') end,\n');
  v_old := E'      ''tax_exemption_reason'',\n        coalesce(v_workspace.tax_exemption_reason, '''')),\n';
  if position(v_old in v_def) = 0 then raise exception '0171: anchor B missing'; end if;
  v_def := replace(v_def, v_old, E'      ''tax_exemption_reason'',\n        case when v_site.id is not null and not v_site.is_default and v_site.tax_exemption_reason <> '''' then v_site.tax_exemption_reason\n             else coalesce(v_workspace.tax_exemption_reason, '''') end),\n');
  execute v_def;
end
$patch$;
