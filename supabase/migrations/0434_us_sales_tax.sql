-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0434 (#2362) -- a sales-tax mode: what a seller in the United States
-- issues. The tax is ADDED to a net price (the VAT model of every other
-- country includes it), stated apart per jurisdiction, and a customer's
-- exemption certificate takes a taxable line out of it.
--
-- Nothing here is a tax value in code (ADR 0041). Three kinds of row hold them:
--
--   sales_tax    the tax a postal code carries: {state, components: [{level,
--                label, percent}]}, one component per jurisdiction (state,
--                county, city, district). Rates change by jurisdiction
--                constantly: the platform administrator enters them with their
--                source; none ships (a ZIP code is an approximation of a
--                jurisdiction, which the row's source says).
--   taxability   whether a kind of line is taxed in a state: key
--                `<STATE>:<kind>` (desk, office, level, subscription, overage,
--                accessories, service, package, adjustment) or
--                `<STATE>:<supply>` (property, general); value {status:
--                taxable | exempt | not_applicable}. A licence to occupy space
--                (property) is `not_applicable` without a row; any other kind
--                without a row REFUSES the invoice: taxability is configured,
--                never inferred.
--   issuing_gate gains `tax_system`: `sales_tax` makes a seller of that
--                country issue in this mode (a row, not a workspace setting).
--
-- The mode and the certificates:
--
--   * tax_exemption_certificates   a customer's certificate: kind (resale,
--     nonprofit, government, other), state (`*` = multistate, SST / MTC),
--     number, validity, the stored file. Written through
--     set_tax_exemption_certificate / end_tax_exemption_certificate by a
--     person with `manageBilling`.
--   * sales_tax_invoice            prices the lines of an invoice: a taxable
--     line is a net price plus the components of its postal code, rounded per
--     invoice and jurisdiction; a certificate in force makes the taxable lines
--     exempt (`exemption_basis` = certificate, the certificate frozen on the
--     entry and on the buyer); the others stay as the state says.
--   * create_invoice               calls it for a seller whose country's gate
--     says `sales_tax` (and while the `salesTax` feature is on). The line
--     amount is the price WITH its tax (the lines add up to the total, as
--     everywhere), `net_cents` the price the customer is quoted and
--     `tax_cents` its share of the tax; `vat_totals` carries net, tax and gross
--     per entry. Every other country is untouched.
--   * invoice_essentials_missing   has its own short list in this mode: no
--     VAT regime, no VAT id, no EN 16931 gate, no reverse charge.
--
-- The gate row of the United States arrives with the last slice: until then no
-- seller is in this mode and every issued document is byte-identical.

-- ── 1. the shapes ─────────────────────────────────────────────────────
do $migration$
declare
  v_def text;
begin
  select pg_get_functiondef('public.tax_reference_valid(text,jsonb)'::regprocedure) into v_def;
  v_def := replace(v_def,
    $a$array['supported', 'requires_tax_number', 'national_channel_required', 'currency']$a$,
    $a$array['supported', 'requires_tax_number', 'national_channel_required', 'currency', 'tax_system']$a$);
  if position($a$'currency', 'tax_system']$a$ in v_def) = 0 then
    raise exception '0434: issuing_gate keys anchor missing';
  end if;
  v_def := replace(v_def,
    $a$ and (p_value ->> 'currency') ~ '^[A-Z]{3}$')), false);$a$,
    $a$ and (p_value ->> 'currency') ~ '^[A-Z]{3}$'))
         and (not p_value ? 'tax_system'
              or (jsonb_typeof(p_value -> 'tax_system') = 'string'
                  and (p_value ->> 'tax_system') = any (array['vat', 'sales_tax']))), false);$a$);
  if position($a$array['vat', 'sales_tax']$a$ in v_def) = 0 then
    raise exception '0434: issuing_gate currency anchor missing';
  end if;
  v_def := replace(v_def,
    $a$    else
      return false;
  end case;$a$,
    $a$    when 'sales_tax' then
      -- The tax a postal code carries, one component per jurisdiction.
      if exists (select 1 from jsonb_object_keys(p_value) k where k <> all (array['state', 'components'])) then return false; end if;
      if jsonb_typeof(p_value -> 'state') is distinct from 'string'
         or (p_value ->> 'state') !~ '^[A-Z]{2}$' then return false; end if;
      if jsonb_typeof(p_value -> 'components') is distinct from 'array'
         or jsonb_array_length(p_value -> 'components') = 0 then return false; end if;
      if exists (select 1 from jsonb_array_elements(p_value -> 'components') c
                  where jsonb_typeof(c) <> 'object') then return false; end if;
      if exists (select 1 from jsonb_array_elements(p_value -> 'components') c
                  where exists (select 1 from jsonb_object_keys(c) k
                                 where k <> all (array['level', 'label', 'percent']))) then return false; end if;
      if exists (select 1 from jsonb_array_elements(p_value -> 'components') c
                  where jsonb_typeof(c -> 'level') is distinct from 'string'
                     or (c ->> 'level') <> all (array['state', 'county', 'city', 'district'])
                     or jsonb_typeof(c -> 'label') is distinct from 'string'
                     or btrim(c ->> 'label') = ''
                     or jsonb_typeof(c -> 'percent') is distinct from 'number') then return false; end if;
      return not exists (select 1 from jsonb_array_elements(p_value -> 'components') c
                          where (c ->> 'percent')::numeric < 0 or (c ->> 'percent')::numeric > 20);
    when 'taxability' then
      -- Whether a kind of line is taxed in a state.
      if exists (select 1 from jsonb_object_keys(p_value) k where k <> 'status') then return false; end if;
      return coalesce(jsonb_typeof(p_value -> 'status') = 'string'
         and (p_value ->> 'status') = any (array['taxable', 'exempt', 'not_applicable']), false);
    else
      return false;
  end case;$a$);
  if position($a$when 'taxability' then$a$ in v_def) = 0 then
    raise exception '0434: tax_reference_valid else anchor missing';
  end if;
  execute v_def;
end
$migration$;

-- ── 2. the customer's exemption certificate ───────────────────────────
create table if not exists public.tax_exemption_certificates (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete cascade,
  kind text not null check (kind in ('resale', 'nonprofit', 'government', 'other')),
  -- A state, or `*` for a multistate certificate (SST, MTC).
  state text not null check (state = '*' or state ~ '^[A-Z]{2}$'),
  number text not null check (btrim(number) <> ''),
  valid_from date not null default current_date,
  valid_to date,
  -- The stored copy of the certificate (a path in the documents bucket).
  file_path text not null default '',
  constraint tax_exemption_certificates_period check (valid_to is null or valid_to >= valid_from)
);
select public.ensure_system_columns('tax_exemption_certificates');
create index if not exists tax_exemption_certificates_member
  on public.tax_exemption_certificates (workspace_id, member_id, state);
alter table public.tax_exemption_certificates enable row level security;
revoke all on table public.tax_exemption_certificates from anon, authenticated;
grant select on table public.tax_exemption_certificates to authenticated;
drop policy if exists tax_exemption_certificates_select on public.tax_exemption_certificates;
create policy tax_exemption_certificates_select on public.tax_exemption_certificates
  for select to authenticated
  using (public.has_permission(workspace_id, 'manageBilling')
         or member_id in (select m.id from public.members m
                           where m.user_id = auth.uid() and m.workspace_id = tax_exemption_certificates.workspace_id));
drop policy if exists mcp_delegated_deny on public.tax_exemption_certificates;
create policy mcp_delegated_deny on public.tax_exemption_certificates as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

create or replace function public.set_tax_exemption_certificate(
  p_workspace_id uuid, p_member_id uuid, p_kind text, p_state text, p_number text,
  p_valid_from date, p_valid_to date, p_file_path text)
returns uuid language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_id uuid;
begin
  if auth.uid() is null or not public.has_permission(p_workspace_id, 'manageBilling') then
    raise exception 'not allowed';
  end if;
  if not exists (select 1 from public.members m
                  where m.id = p_member_id and m.workspace_id = p_workspace_id) then
    raise exception 'unknown member';
  end if;
  insert into public.tax_exemption_certificates
    (workspace_id, member_id, kind, state, number, valid_from, valid_to, file_path)
  values (p_workspace_id, p_member_id, p_kind, upper(btrim(p_state)), btrim(p_number),
          coalesce(p_valid_from, current_date), p_valid_to, coalesce(p_file_path, ''))
  returning id into v_id;
  return v_id;
end;
$fn$;
revoke execute on function public.set_tax_exemption_certificate(uuid, uuid, text, text, text, date, date, text)
  from public, anon;
grant execute on function public.set_tax_exemption_certificate(uuid, uuid, text, text, text, date, date, text)
  to authenticated;

-- A certificate is never deleted (an issued invoice cites it): it ends.
create or replace function public.end_tax_exemption_certificate(p_id uuid, p_on date)
returns void language plpgsql volatile security definer set search_path = public as $fn$
declare
  c public.tax_exemption_certificates;
begin
  select * into c from public.tax_exemption_certificates where id = p_id;
  if c.id is null then raise exception 'unknown certificate'; end if;
  if auth.uid() is null or not public.has_permission(c.workspace_id, 'manageBilling') then
    raise exception 'not allowed';
  end if;
  update public.tax_exemption_certificates
     set valid_to = greatest(c.valid_from, coalesce(p_on, current_date))
   where id = p_id;
end;
$fn$;
revoke execute on function public.end_tax_exemption_certificate(uuid, date) from public, anon;
grant execute on function public.end_tax_exemption_certificate(uuid, date) to authenticated;

-- ── 3. the readers and the pricing ────────────────────────────────────
-- The five digits of a postal code (ZIP+4 and spaces dropped).
create or replace function public.sales_tax_zip(p_postal text)
returns text language sql immutable set search_path = public as $fn$
  select left(regexp_replace(coalesce(p_postal, ''), '[^0-9]', '', 'g'), 5);
$fn$;
revoke execute on function public.sales_tax_zip(text) from public, anon, authenticated;

-- What a postal code carries on p_on: {state, components}, or null.
create or replace function public.sales_tax_zip_rate(p_postal text, p_on date)
returns jsonb language sql stable security definer set search_path = public as $fn$
  select t.value
    from public.tax_reference t
   where t.domain = 'sales_tax' and t.country = 'US'
     and t.key = public.sales_tax_zip(p_postal)
     and t.valid_from <= coalesce(p_on, current_date)
     and (t.valid_to is null or t.valid_to > coalesce(p_on, current_date))
   limit 1;
$fn$;
revoke execute on function public.sales_tax_zip_rate(text, date) from public, anon, authenticated;

-- Whether a kind of line is taxed in a state: the row of the kind, else the
-- row of its supply (property / general), else -- for a licence to occupy
-- space only -- not applicable. Null: nobody said, and nothing is inferred.
create or replace function public.sales_tax_status(p_state text, p_kind text, p_supply text, p_on date)
returns text language sql stable security definer set search_path = public as $fn$
  select coalesce(
    (select t.value ->> 'status' from public.tax_reference t
      where t.domain = 'taxability' and t.country = 'US' and t.key = p_state || ':' || p_kind
        and t.valid_from <= coalesce(p_on, current_date)
        and (t.valid_to is null or t.valid_to > coalesce(p_on, current_date)) limit 1),
    (select t.value ->> 'status' from public.tax_reference t
      where t.domain = 'taxability' and t.country = 'US' and t.key = p_state || ':' || p_supply
        and t.valid_from <= coalesce(p_on, current_date)
        and (t.valid_to is null or t.valid_to > coalesce(p_on, current_date)) limit 1),
    case when p_supply = 'property' then 'not_applicable' end);
$fn$;
revoke execute on function public.sales_tax_status(text, text, text, date) from public, anon, authenticated;

-- The certificate of a customer in force in a state on p_on (its own state
-- first, a multistate one otherwise), as {id, kind, state, number, valid_to}.
create or replace function public.sales_tax_certificate_of(
  p_workspace_id uuid, p_member_id uuid, p_state text, p_on date)
returns jsonb language sql stable security definer set search_path = public as $fn$
  select jsonb_build_object('id', c.id, 'kind', c.kind, 'state', c.state, 'number', c.number,
                            'valid_to', c.valid_to)
    from public.tax_exemption_certificates c
   where c.workspace_id = p_workspace_id and c.member_id = p_member_id
     and (c.state = p_state or c.state = '*')
     and c.valid_from <= coalesce(p_on, current_date)
     and (c.valid_to is null or c.valid_to >= coalesce(p_on, current_date))
   order by (c.state = '*'), c.valid_from desc
   limit 1;
$fn$;
revoke execute on function public.sales_tax_certificate_of(uuid, uuid, text, date) from public, anon, authenticated;

-- The lines of an invoice in sales-tax mode. p_lines carry NET amounts; the
-- lines returned carry the price with its tax (see above).
-- Returns {lines, vat_totals, total_cents, missing, certificate}: each line
-- with its tax category (S taxed, E exempt, O outside the tax) and how it was
-- decided; one entry of vat_totals per category (and exemption basis) with the
-- jurisdiction components of the taxed one, each rounded on the entry's net.
create or replace function public.sales_tax_invoice(
  p_workspace_id uuid, p_member_id uuid, p_postal text, p_lines jsonb, p_on date)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_rate jsonb := public.sales_tax_zip_rate(p_postal, p_on);
  v_state text := v_rate ->> 'state';
  v_cert jsonb;
  v_missing text[] := '{}';
  v_lines jsonb := '[]'::jsonb;
  v_totals jsonb := '[]'::jsonb;
  v_line jsonb;
  v_kind text;
  v_supply text;
  v_status text;
  v_bucket text;
  v_basis text;
  v_pct numeric := 0;
  v_group record;
  v_comp jsonb;
  v_comps jsonb;
  v_tax bigint;
  v_vat bigint;
  v_entry jsonb;
  v_used_cert boolean := false;
  v_sum bigint := 0;
  v_s_net bigint;
  v_s_vat bigint;
  v_left bigint;
  v_last bigint;
  v_ord bigint;
  v_out jsonb;
begin
  select coalesce(sum((l ->> 'amount_cents')::bigint), 0) into v_sum
    from jsonb_array_elements(coalesce(p_lines, '[]'::jsonb)) l;
  if v_rate is null then
    return jsonb_build_object('lines', coalesce(p_lines, '[]'::jsonb), 'vat_totals', '[]'::jsonb,
                              'total_cents', v_sum, 'missing', jsonb_build_array('sales_tax_rate_unset'),
                              'certificate', null);
  end if;
  select coalesce(sum((c ->> 'percent')::numeric), 0) into v_pct
    from jsonb_array_elements(v_rate -> 'components') c;
  v_cert := public.sales_tax_certificate_of(p_workspace_id, p_member_id, v_state, p_on);

  for v_line in
    select t.l from jsonb_array_elements(coalesce(p_lines, '[]'::jsonb)) with ordinality t(l, o) order by t.o
  loop
    v_kind := coalesce(v_line ->> 'kind', '');
    v_supply := case when v_line ->> 'supply' = 'general' then 'general' else 'property' end;
    -- A payment or an expense credited on the invoice is not a supply.
    v_status := case when v_kind in ('payment', 'expense') then 'not_applicable'
                     else public.sales_tax_status(v_state, v_kind, v_supply, p_on) end;
    if v_status is null then
      if not 'sales_tax_taxability_unset' = any (v_missing) then
        v_missing := array_append(v_missing, 'sales_tax_taxability_unset');
      end if;
      v_status := 'not_applicable';
    end if;
    v_basis := case when v_status = 'taxable' and v_cert is not null then 'certificate'
                    when v_status = 'exempt' then 'statute' else '' end;
    v_bucket := case v_status
                  when 'taxable' then case when v_cert is not null then 'E' else 'S' end
                  when 'exempt' then 'E' else 'O' end;
    if v_basis = 'certificate' then v_used_cert := true; end if;
    v_lines := v_lines || (v_line || jsonb_build_object(
      'vat_percent', case when v_bucket = 'S' then v_pct else 0 end,
      'vat_category', v_bucket,
      'taxability', v_status,
      'exemption_basis', v_basis,
      'net_cents', (v_line ->> 'amount_cents')::bigint,
      'tax_cents', 0));
  end loop;

  for v_group in
    select g.cat, g.basis, g.net
      from (select l ->> 'vat_category' as cat, l ->> 'exemption_basis' as basis,
                   sum((l ->> 'amount_cents')::bigint) as net
              from jsonb_array_elements(v_lines) l
             where (l ->> 'amount_cents')::bigint > 0 or (l ->> 'vat_percent')::numeric > 0
             group by 1, 2) g
     order by case g.cat when 'S' then 1 when 'E' then 2 else 3 end, g.basis
  loop
    v_comps := '[]'::jsonb;
    v_vat := 0;
    if v_group.cat = 'S' then
      for v_comp in select c from jsonb_array_elements(v_rate -> 'components') c loop
        v_tax := round(v_group.net * (v_comp ->> 'percent')::numeric / 100)::bigint;
        v_vat := v_vat + v_tax;
        v_comps := v_comps || jsonb_build_object(
          'scheme', 'SALES_TAX', 'authority', 'US-' || v_state, 'level', v_comp ->> 'level',
          'name', v_comp ->> 'label', 'percent', (v_comp ->> 'percent')::numeric,
          'base_cents', v_group.net, 'tax_cents', v_tax);
      end loop;
    end if;
    v_entry := jsonb_build_object(
      'percent', case when v_group.cat = 'S' then v_pct else 0 end,
      'category', v_group.cat,
      'gross_cents', v_group.net + v_vat,
      'net_cents', v_group.net,
      'vat_cents', v_vat,
      'state', v_state,
      'jurisdiction', public.sales_tax_zip(p_postal));
    if v_group.cat = 'S' then
      v_entry := v_entry || jsonb_build_object('components', v_comps);
    end if;
    if v_group.basis <> '' then
      v_entry := v_entry || jsonb_build_object('exemption_basis', v_group.basis);
    end if;
    if v_group.basis = 'certificate' then
      v_entry := v_entry || jsonb_build_object('certificate', v_cert);
    end if;
    v_totals := v_totals || v_entry;
  end loop;

  -- The price of a line is its net plus its share of the taxed entry's tax
  -- (the last taxed line takes the rounding remainder): the document keeps
  -- the invariant of every other country -- the lines add up to the total --
  -- and `net_cents` is the price the customer is quoted.
  select (t ->> 'net_cents')::bigint, (t ->> 'vat_cents')::bigint into v_s_net, v_s_vat
    from jsonb_array_elements(v_totals) t where t ->> 'category' = 'S' limit 1;
  if found then
    select max(x.o) into v_last
      from jsonb_array_elements(v_lines) with ordinality x(l, o) where x.l ->> 'vat_category' = 'S';
    v_left := v_s_vat;
    v_out := '[]'::jsonb;
    for v_line, v_ord in
      select x.l, x.o from jsonb_array_elements(v_lines) with ordinality x(l, o) order by x.o
    loop
      if v_line ->> 'vat_category' = 'S' then
        v_tax := case when v_ord = v_last then v_left
                      when v_s_net = 0 then 0
                      else round((v_line ->> 'net_cents')::bigint * v_s_vat::numeric / v_s_net)::bigint end;
        v_left := v_left - v_tax;
        v_line := v_line || jsonb_build_object(
          'tax_cents', v_tax, 'amount_cents', (v_line ->> 'net_cents')::bigint + v_tax);
      end if;
      v_out := v_out || v_line;
    end loop;
    v_lines := v_out;
  end if;

  return jsonb_build_object(
    'lines', v_lines,
    'vat_totals', v_totals,
    'total_cents', coalesce((select sum((l ->> 'amount_cents')::bigint)
                               from jsonb_array_elements(v_lines) l), 0),
    'missing', to_jsonb(v_missing),
    'certificate', case when v_used_cert then v_cert end);
end;
$fn$;
revoke execute on function public.sales_tax_invoice(uuid, uuid, text, jsonb, date) from public, anon, authenticated;

-- ── 4. anchored patches ───────────────────────────────────────────────
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
  v_step record;
begin
  -- The short list of a seller in sales-tax mode.
  select pg_get_functiondef('public.invoice_essentials_missing(uuid,uuid,jsonb,jsonb)'::regprocedure)
    into v_def;
  for v_step in
    select * from (values
      (1, 'the sales-tax list',
       $old$  v_gate := public.issuing_gate_of(v_cc);
$old$,
       $new$  v_gate := public.issuing_gate_of(v_cc);
  -- #2362: a seller whose country's gate says `sales_tax` has a list of its
  -- own: no VAT regime, VAT id, EN 16931 gate or reverse charge applies.
  if coalesce(v_gate ->> 'tax_system', 'vat') = 'sales_tax' then
    if not coalesce((v_gate ->> 'supported')::boolean, false)
       or not public.feature_effective(p_workspace_id, 'salesTax') then
      v_missing := array_append(v_missing, 'seller_country_unsupported'::text);
    end if;
    v_national := nullif(v_gate ->> 'currency', '');
    if v_national is not null
       and exists (select 1 from jsonb_array_elements(coalesce(p_vat_totals, '[]'::jsonb)) t
                    where coalesce((t ->> 'vat_cents')::bigint, 0) <> 0)
       and upper(coalesce((select w.currency_code from public.workspaces w
                            where w.id = p_workspace_id), '')) <> v_national then
      v_missing := array_append(v_missing, 'vat_national_currency'::text);
    end if;
    if btrim(coalesce(v_buyer ->> 'name', '')) = ''
       and btrim(coalesce(v_buyer ->> 'company', '')) = '' then
      v_missing := array_append(v_missing, 'buyer_name'::text);
    end if;
    return v_missing;
  end if;
$new$)
    ) as s(n, what, old_text, new_text) order by n
  loop
    v_def := pg_temp.anchor_replace(v_def, v_step.old_text, v_step.new_text);
    if v_def is null then
      raise exception '0434: invoice_essentials_missing anchor % (%) missing', v_step.n, v_step.what;
    end if;
  end loop;
  execute v_def;

  -- create_invoice prices a sales-tax invoice by sales_tax_invoice.
  select pg_get_functiondef('public.create_invoice(uuid,uuid,text,uuid,boolean,text,boolean,text,text,text)'::regprocedure)
    into v_def;
  for v_step in
    select * from (values
      (1, 'declarations',
       $old$  v_essentials text[];
$old$,
       $new$  v_essentials text[];
  v_gate jsonb;
  v_sales_tax boolean := false;
  v_st jsonb;
  v_st_missing text[] := '{}';
$new$),
      (2, 'the totals of a sales-tax invoice',
       $old$  with charges as (
    select coalesce((l->>'vat_percent')::numeric, 0) as percent,$old$,
       $new$  -- #2362: a seller in sales-tax mode adds the tax of the site's postal code
  -- to NET line amounts, per jurisdiction; every other seller is untouched.
  v_gate := public.issuing_gate_of(v_seller_country);
  v_sales_tax := coalesce(v_gate ->> 'tax_system', 'vat') = 'sales_tax'
                 and coalesce((v_gate ->> 'supported')::boolean, false)
                 and public.feature_effective(p_workspace_id, 'salesTax');
  if v_sales_tax then
    v_st := public.sales_tax_invoice(
      p_workspace_id, v_subject.id,
      case when v_site.id is not null and not v_site.is_default
                and (v_site.street <> '' or v_site.city <> '')
           then v_site.postal_code else coalesce(v_workspace.postal_code, '') end,
      v_lines, public.vat_tax_point(p_period));
    v_lines := v_st -> 'lines';
    v_vat_totals := v_st -> 'vat_totals';
    v_total := (v_st ->> 'total_cents')::int;
    v_st_missing := array(select jsonb_array_elements_text(v_st -> 'missing'));
    v_reverse_charge := false;
    v_capacity_unknown := false;
  else
  with charges as (
    select coalesce((l->>'vat_percent')::numeric, 0) as percent,$new$),
      (3, 'the end of the totals',
       $old$        from charges group by percent, line_category
    ) grouped;
$old$,
       $new$        from charges group by percent, line_category
    ) grouped;
  end if;
$new$),
      (4, 'the certificate on the buyer',
       $old$  -- #2440 — RD 1619/2012 art. 15: a Spanish correction names its reason.
$old$,
       $new$  -- #2362: the customer's exemption certificate is cited on the invoice.
  if v_st is not null and jsonb_typeof(v_st -> 'certificate') = 'object' then
    v_parties := jsonb_set(v_parties, '{buyer,exemption_certificate}', v_st -> 'certificate');
  end if;
  -- #2440 — RD 1619/2012 art. 15: a Spanish correction names its reason.
$new$),
      (5, 'the refusals of a sales-tax invoice',
       $old$  if cardinality(v_essentials) > 0 then
$old$,
       $new$  v_essentials := v_essentials || v_st_missing;
  if cardinality(v_essentials) > 0 then
$new$)
    ) as s(n, what, old_text, new_text) order by n
  loop
    v_def := pg_temp.anchor_replace(v_def, v_step.old_text, v_step.new_text);
    if v_def is null then
      raise exception '0434: create_invoice anchor % (%) missing', v_step.n, v_step.what;
    end if;
  end loop;
  execute v_def;

  -- A subject-access request returns the customer's own certificates.
  select pg_get_functiondef('public.export_my_data(uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$    'exported_at', now(),$a$,
    $a$    'exported_at', now(),
    'tax_exemption_certificates', (select coalesce(jsonb_agg(to_jsonb(c)), '[]'::jsonb)
                                     from public.tax_exemption_certificates c
                                    where c.member_id in (select m.id from public.members m
                                                           where m.user_id = auth.uid())),$a$);
  if v_def is null then raise exception '0434: export_my_data anchor missing'; end if;
  execute v_def;
end
$migration$;

-- ── 5. the feature registry knows `salesTax` (dart run tool/build_feature_registry_sql.dart) ──
create or replace function public.feature_registry()
returns jsonb
language sql
immutable
set search_path = public
as $registry$
  select '{
    "calendarTab": {"parent": null, "default": true, "core": true},
    "eventsTab": {"parent": null, "default": true, "core": true},
    "moneyTab": {"parent": null, "default": true, "core": true},
    "services": {"parent": "moneyTab", "default": true, "core": true},
    "accessorySupplements": {"parent": "moneyTab", "default": false, "core": false},
    "onlinePayments": {"parent": "moneyTab", "default": false, "core": false},
    "invoicing": {"parent": "moneyTab", "default": true, "core": true},
    "adminInvoicing": {"parent": "invoicing", "default": false, "core": false},
    "pdfExport": {"parent": null, "default": true, "core": true},
    "seriesBooking": {"parent": null, "default": true, "core": true},
    "bookForOthers": {"parent": null, "default": true, "core": true},
    "pushNotifications": {"parent": null, "default": true, "core": true},
    "adminSeatBlocking": {"parent": null, "default": false, "core": false},
    "levelBooking": {"parent": null, "default": false, "core": false},
    "adminLevelAssign": {"parent": "levelBooking", "default": false, "core": false},
    "kioskMode": {"parent": null, "default": true, "core": false},
    "nfcBadges": {"parent": "kioskMode", "default": true, "core": false},
    "membersDirectory": {"parent": null, "default": true, "core": true},
    "whatsappIntegration": {"parent": "membersDirectory", "default": true, "core": false},
    "spaceQrCodes": {"parent": null, "default": true, "core": true},
    "coOwner": {"parent": null, "default": true, "core": false},
    "autoCheckInOut": {"parent": null, "default": false, "core": false},
    "dataExport": {"parent": null, "default": true, "core": true},
    "workingHours": {"parent": null, "default": true, "core": true},
    "invoicePdfTemplate": {"parent": "invoicing", "default": true, "core": false},
    "invoiceAddressWindow": {"parent": "invoicing", "default": true, "core": false},
    "memberNotifications": {"parent": null, "default": true, "core": true},
    "documents": {"parent": null, "default": true, "core": true},
    "dunning": {"parent": "invoicing", "default": true, "core": false},
    "memberReports": {"parent": "moneyTab", "default": true, "core": false},
    "deletionRequests": {"parent": null, "default": true, "core": true},
    "roleManagement": {"parent": null, "default": true, "core": true},
    "vatManagement": {"parent": "invoicing", "default": true, "core": false},
    "vatDeclarations": {"parent": "vatManagement", "default": true, "core": false},
    "einvoiceCustomerDelivery": {"parent": "invoicing", "default": true, "core": false},
    "planObjectDelete": {"parent": null, "default": true, "core": true},
    "notificationGrouping": {"parent": "eventsTab", "default": true, "core": true},
    "bookingPolicies": {"parent": null, "default": true, "core": true},
    "bookingGate": {"parent": "bookingPolicies", "default": true, "core": true},
    "nfcSeatTags": {"parent": null, "default": true, "core": false},
    "qrBadges": {"parent": "kioskMode", "default": true, "core": false},
    "kioskMemberPhotos": {"parent": "kioskMode", "default": true, "core": false},
    "subscriptionInvoices": {"parent": "invoicing", "default": true, "core": false},
    "usageInvoices": {"parent": "invoicing", "default": true, "core": false},
    "invoiceSettlement": {"parent": "invoicing", "default": true, "core": false},
    "invoiceJourney": {"parent": "invoicing", "default": true, "core": false},
    "messageGestures": {"parent": null, "default": true, "core": true},
    "uniqueMonograms": {"parent": null, "default": true, "core": true},
    "planMemberPhotos": {"parent": null, "default": true, "core": false},
    "regionalFormats": {"parent": null, "default": true, "core": true},
    "calendarHub": {"parent": null, "default": true, "core": true},
    "calendarViews": {"parent": "calendarHub", "default": true, "core": true},
    "messagesHub": {"parent": null, "default": true, "core": true},
    "reportDesigner": {"parent": "invoicePdfTemplate", "default": true, "core": false},
    "memberPage": {"parent": "membersDirectory", "default": true, "core": true},
    "invoicingWizard": {"parent": "invoicing", "default": true, "core": false},
    "expenseRepartition": {"parent": "invoicing", "default": true, "core": false},
    "settlementFold": {"parent": "invoiceSettlement", "default": true, "core": false},
    "configurationTransfer": {"parent": "dataExport", "default": true, "core": false},
    "navigationStyle": {"parent": null, "default": true, "core": true},
    "demoMode": {"parent": null, "default": true, "core": false},
    "instanceWizard": {"parent": null, "default": true, "core": false},
    "dataAccessLog": {"parent": "moneyTab", "default": true, "core": false},
    "memberDataExport": {"parent": null, "default": true, "core": true},
    "financeFaces": {"parent": "moneyTab", "default": true, "core": true},
    "paymentReminders": {"parent": "dunning", "default": true, "core": false},
    "supplyExpenses": {"parent": "services", "default": true, "core": false},
    "validationScopes": {"parent": null, "default": true, "core": false},
    "validationChain": {"parent": null, "default": true, "core": false},
    "richMessageRefs": {"parent": "memberNotifications", "default": true, "core": true},
    "calendarValidations": {"parent": "calendarHub", "default": true, "core": false},
    "usageRecords": {"parent": "invoicing", "default": true, "core": false},
    "reportDesignExchange": {"parent": "reportDesigner", "default": true, "core": false},
    "reportLayouts": {"parent": "reportDesigner", "default": true, "core": false},
    "personalInfo": {"parent": null, "default": true, "core": true},
    "managedProfiles": {"parent": "membersDirectory", "default": true, "core": false},
    "numberSequences": {"parent": "invoicing", "default": false, "core": false},
    "workspaceStatus": {"parent": "invoicing", "default": false, "core": false},
    "expenseRepartitionWizard": {"parent": "expenseRepartition", "default": false, "core": false},
    "multiSite": {"parent": null, "default": false, "core": false},
    "siteDocuments": {"parent": "multiSite", "default": false, "core": false},
    "vatGroups": {"parent": "vatManagement", "default": false, "core": false},
    "vatRateHistory": {"parent": "vatManagement", "default": false, "core": false},
    "vatCounterparty": {"parent": "vatManagement", "default": false, "core": false},
    "environmentPairs": {"parent": null, "default": true, "core": false},
    "deployments": {"parent": "environmentPairs", "default": true, "core": false},
    "managedProfileAccess": {"parent": "managedProfiles", "default": false, "core": false},
    "seatDayTimeline": {"parent": null, "default": true, "core": true},
    "memberPaymentTerms": {"parent": "invoicing", "default": true, "core": false},
    "usageReport": {"parent": "usageRecords", "default": true, "core": false},
    "reportTexts": {"parent": "reportDesigner", "default": true, "core": false},
    "letterStandard": {"parent": "reportLayouts", "default": true, "core": false},
    "vatReport": {"parent": "vatDeclarations", "default": true, "core": false},
    "priceNegotiations": {"parent": "moneyTab", "default": true, "core": false},
    "scheduledExpenses": {"parent": "moneyTab", "default": true, "core": false},
    "badgeSignIn": {"parent": "nfcBadges", "default": false, "core": false},
    "formHelpHints": {"parent": null, "default": true, "core": true},
    "uiAnimations": {"parent": null, "default": true, "core": true},
    "memberOrigin": {"parent": "membersDirectory", "default": false, "core": false},
    "memberEnvironments": {"parent": "environmentPairs", "default": false, "core": false},
    "workspaceLibrary": {"parent": null, "default": false, "core": false},
    "singleRoomLevelNames": {"parent": null, "default": true, "core": true},
    "publicHolidays": {"parent": null, "default": false, "core": false},
    "workspaceVocabulary": {"parent": null, "default": false, "core": false},
    "carnets": {"parent": "invoicing", "default": false, "core": false},
    "publicListings": {"parent": null, "default": false, "core": true},
    "workspaceBranding": {"parent": null, "default": false, "core": false},
    "customRoles": {"parent": null, "default": false, "core": false},
    "customFields": {"parent": null, "default": false, "core": false},
    "decisionSurface": {"parent": null, "default": false, "core": false},
    "recordingPrivacy": {"parent": null, "default": false, "core": false},
    "memberAccountMenu": {"parent": null, "default": false, "core": false},
    "mcpAccess": {"parent": null, "default": false, "core": false},
    "calendarFileExport": {"parent": null, "default": true, "core": true},
    "memberGettingStarted": {"parent": null, "default": true, "core": true},
    "placeFeedback": {"parent": null, "default": true, "core": true},
    "spaceInquiries": {"parent": null, "default": true, "core": true},
    "messageForwarding": {"parent": "memberNotifications", "default": true, "core": true},
    "captureProtection": {"parent": "memberNotifications", "default": true, "core": true},
    "holidayImport": {"parent": "publicHolidays", "default": false, "core": false},
    "capacityKpi": {"parent": null, "default": false, "core": false},
    "accountingBook": {"parent": "invoicing", "default": false, "core": false},
    "roleAssignment": {"parent": "roleManagement", "default": true, "core": true},
    "taskRecorder": {"parent": null, "default": false, "core": false},
    "guestParticipation": {"parent": null, "default": false, "core": true},
    "messageMentions": {"parent": "memberNotifications", "default": true, "core": true},
    "supplyClassification": {"parent": "vatManagement", "default": true, "core": false},
    "viesVerification": {"parent": "supplyClassification", "default": true, "core": false},
    "recapitulativeStatement": {"parent": "vatDeclarations", "default": true, "core": false},
    "inputVat": {"parent": "vatDeclarations", "default": true, "core": false},
    "configurableSettings": {"parent": null, "default": true, "core": false},
    "salesTax": {"parent": "invoicing", "default": true, "core": false}
  }'::jsonb
$registry$;
revoke execute on function public.feature_registry() from public, anon;
grant execute on function public.feature_registry() to authenticated;

select public.set_deskilo_schema_version(434);
