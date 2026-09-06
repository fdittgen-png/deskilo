-- SPDX-License-Identifier: 0BSD
-- 0169 — #946: a document names the site it concerns.
--
-- With sites (0168), the seller's address on a document is the address
-- of the member's HOME site when that site has one of its own — with the
-- establishment's registration beside it — and the workspace's
-- otherwise. Each attendance row of the details names the site the
-- reservation stood at, so a member who worked from another site sees
-- it on the invoice. The frozen legacy address column follows the same
-- rule, so older readers print the same address as newer ones.
--
-- create_invoice is patched at five asserted anchors; a silent no-op
-- would freeze the wrong address on a real document.
create or replace function public.reservation_site(r public.reservations) returns public.sites
language sql stable security definer set search_path = public as $$
  select st from public.sites st
   where st.id = coalesce(
     (select l.site_id from public.levels l where l.id = r.level_id),
     (select l.site_id from public.offices o join public.levels l on l.id = o.level_id where o.id = r.office_id),
     (select l.site_id from public.desks d join public.offices o on o.id = d.office_id join public.levels l on l.id = o.level_id where d.id = r.desk_id),
     (select l.site_id from public.seats s join public.desks d on d.id = s.desk_id join public.offices o on o.id = d.office_id join public.levels l on l.id = o.level_id where s.id = r.seat_id));
$$;

do $patch$
declare v_def text; v_old text;
begin
  select pg_get_functiondef(p.oid) into v_def from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_invoice';
  v_old := E'  v_signature text;\n';
  if position(v_old in v_def) = 0 then raise exception '0169: anchor A missing'; end if;
  v_def := replace(v_def, v_old, v_old || E'  v_site public.sites;\n');
  v_old := E'  v_parties := jsonb_build_object(\n';
  if position(v_old in v_def) = 0 then raise exception '0169: anchor B missing'; end if;
  v_def := replace(v_def, v_old, E'  v_site := public.document_site_for_member(v_subject.id);\n' || v_old);
  v_old := E'    ''seller'', jsonb_build_object(\n      ''name'', v_workspace.name,\n      ''street'', coalesce(nullif(v_workspace.street, ''''),\n                         coalesce(v_workspace.address, '''')),\n      ''city'', coalesce(v_workspace.city, ''''),\n      ''postal_code'', coalesce(v_workspace.postal_code, ''''),\n      ''country'', v_workspace.country_code,\n      ''vat_id'', coalesce(v_workspace.vat_id, ''''),\n      ''legal_id'', coalesce(v_workspace.legal_id, ''''),\n';
  if position(v_old in v_def) = 0 then raise exception '0169: anchor C missing'; end if;
  v_def := replace(v_def, v_old,
       E'    ''seller'', jsonb_build_object(\n      ''name'', v_workspace.name,\n'
    || E'      ''site'', coalesce(v_site.name, ''''),\n'
    || E'      ''site_default'', coalesce(v_site.is_default, true),\n'
    || E'      ''street'', case when v_site.id is not null and not v_site.is_default and (v_site.street <> '''' or v_site.city <> '''') then v_site.street\n'
    || E'                       else coalesce(nullif(v_workspace.street, ''''), coalesce(v_workspace.address, '''')) end,\n'
    || E'      ''city'', case when v_site.id is not null and not v_site.is_default and (v_site.street <> '''' or v_site.city <> '''') then v_site.city else coalesce(v_workspace.city, '''') end,\n'
    || E'      ''postal_code'', case when v_site.id is not null and not v_site.is_default and (v_site.street <> '''' or v_site.city <> '''') then v_site.postal_code else coalesce(v_workspace.postal_code, '''') end,\n'
    || E'      ''country'', case when v_site.id is not null and not v_site.is_default and v_site.country_code <> '''' then v_site.country_code else v_workspace.country_code end,\n'
    || E'      ''vat_id'', coalesce(v_workspace.vat_id, ''''),\n'
    || E'      ''legal_id'', case when v_site.id is not null and not v_site.is_default and v_site.legal_id <> '''' then v_site.legal_id else coalesce(v_workspace.legal_id, '''') end,\n');
  v_old := E'              (select l.name from public.levels l where l.id = r.level_id),\n              ''''))\n';
  if position(v_old in v_def) = 0 then raise exception '0169: anchor D missing'; end if;
  v_def := replace(v_def, v_old, v_old || E'            , ''site'', coalesce((public.reservation_site(r)).name, '''')\n');
  v_old := E'     coalesce(v_workspace.address, ''''), v_issuer_name, v_signature,\n';
  if position(v_old in v_def) = 0 then raise exception '0169: anchor E missing'; end if;
  v_def := replace(v_def, v_old,
       E'     case when v_site.id is not null and not v_site.is_default and (v_site.street <> '''' or v_site.city <> '''')\n'
    || E'          then btrim(v_site.street || '', '' || v_site.postal_code || '' '' || v_site.city, '', '')\n'
    || E'          else coalesce(v_workspace.address, '''') end, v_issuer_name, v_signature,\n');
  execute v_def;
end
$patch$;
