-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (one table; three functions)
--
-- #4005 (decision 0052, point 5) -- the head adds a house abroad in one
-- command. create_organisation_house_once creates the business (with its
-- twin as the head has one), places it in the organisation, and carries the
-- head's configuration in merge mode, fenced:
--
-- * Every priced row arrives INACTIVE, whatever the currency: nothing is
--   sellable in a new country before its owner has looked at price and tax.
--   Its amounts are kept when the house's currency is the head's, and are 0
--   when it differs. The amounts carried are exactly those of
--   organisation_house_fenced_amounts(): plans' base and overage fees, the
--   prices of services and packages, and a validation policy's threshold
--   (0 in another currency: every amount then asks, never fewer). Booking
--   rules and reminders hold no amount; a new amount in a carried table
--   turns pgTAP 434 red until it is fenced here. Fee bands have no inactive
--   state and are not carried.
-- * No rate travels and none is invented: a business has no VAT rates at
--   birth (its setup guide's VAT step sets its country's), so every priced
--   row arrives with no rate, and the house's birth record keeps the head's
--   rate category per row as a hint for "Name your prices".
-- * Not carried: identity, payment instructions, invitations, sites, the
--   floor plan, counters, and closure days when the country differs (public
--   holidays are the country's). Carried: role definitions (no assignment),
--   booking rules, validation policies, reminders, the document design and
--   links, and the features the house's country offers.
-- * The caller owns the house as any business they create. The head's other
--   active owners and co-owners are added once, at birth, as co-owners: a
--   copy made at birth, not a mirror; nothing later follows from the head.
-- * organisation_houses is the house's birth record: where it came from,
--   what was carried, who was added, and whether its prices are still to be
--   named. It grants nothing and no check reads it for a right.
-- The head's `organisation` feature gates the command; an assistant's token
-- is refused; the same request id answers the same house.

-- ── 1. the birth record of a house ───────────────────────────────────────
create table if not exists public.organisation_houses (
  workspace_id uuid primary key references public.workspaces(id) on delete cascade,
  -- history: where the house came from; it stays when the house leaves
  organisation_id uuid references public.organisations(id) on delete set null,
  head_workspace_id uuid references public.workspaces(id) on delete set null,
  carried jsonb not null default '{}'::jsonb,
  co_owners_added uuid[] not null default '{}',
  prices_pending boolean not null default false
);
select public.ensure_system_columns('organisation_houses');
comment on table public.organisation_houses is
  '#4005 -- the birth record of a house created from the head of its organisation: where it came from, what was carried, who was added';

alter table public.organisation_houses enable row level security;
drop policy if exists organisation_houses_select on public.organisation_houses;
create policy organisation_houses_select on public.organisation_houses
  for select using (public.is_member_of(workspace_id));
drop policy if exists mcp_delegated_deny on public.organisation_houses;
create policy mcp_delegated_deny on public.organisation_houses as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
revoke insert, update, delete on public.organisation_houses from anon, authenticated;

-- ── 2. the amounts the carry fences ──────────────────────────────────────
-- Per carried table, its amount columns: kept when the currency is the
-- head's, 0 when it differs. pgTAP 434 fails when a carried table has an
-- amount column this list does not name.
create or replace function public.organisation_house_fenced_amounts()
returns jsonb language sql immutable set search_path = public as $fn$
  select '{"plans": ["base_fee_cents", "overage_fee_cents"],
           "services": ["price_cents"],
           "packages": ["price_cents"],
           "validation_policies": ["min_amount_cents"],
           "workspace_documents": [], "closure_days": []}'::jsonb
$fn$;
revoke execute on function public.organisation_house_fenced_amounts() from public, anon;
grant execute on function public.organisation_house_fenced_amounts() to authenticated;

-- ── 3. adding a house ────────────────────────────────────────────────────
create or replace function public.create_organisation_house_once(
  p_organisation uuid,
  p_name text,
  p_country text,
  p_currency text,
  p_timezone text,
  p_language text,
  p_client_request_id uuid
) returns jsonb
language plpgsql security definer set search_path = public as $fn$
declare
  v_head public.workspaces;
  v_house uuid;
  v_country text := upper(btrim(coalesce(p_country, '')));
  v_currency text := upper(btrim(coalesce(p_currency, '')));
  v_same_currency boolean;
  v_same_country boolean;
  v_cfg jsonb;
  v_fenced jsonb := public.organisation_house_fenced_amounts();
  v_tables jsonb := '{}'::jsonb;
  v_table text;
  v_rows jsonb;
  v_row jsonb;
  v_col text;
  v_hints jsonb := '{}'::jsonb;
  v_flags jsonb := '{}'::jsonb;
  v_flag record;
  v_priced int := 0;
  v_added uuid[];
  v_carried jsonb;
  v_existing public.organisation_houses;
begin
  select w.* into v_head from public.workspaces w
    join public.organisations o on o.head_workspace_id = w.id
   where o.id = p_organisation;
  perform public.organisation_owner_check(v_head.id);
  perform public.organisation_feature_check(v_head.id);

  -- the business, as any the caller creates; the same request answers the same house
  v_house := public.create_workspace_once(
    p_client_request_id, p_name, v_country, v_currency, p_timezone,
    v_head.environment, v_head.pair_id is not null, null, null);
  select * into v_existing from public.organisation_houses where workspace_id = v_house;
  if v_existing.workspace_id is not null then
    return jsonb_build_object('workspace_id', v_house, 'carried', v_existing.carried);
  end if;
  update public.workspaces w
     set default_locale = coalesce(nullif(btrim(p_language), ''), w.default_locale)
   where w.id = v_house
      or (w.pair_id is not null and w.pair_id = (select x.pair_id from public.workspaces x where x.id = v_house));
  perform public.organisation_place(v_house, p_organisation);

  -- the head's other owners, once, as co-owners: a copy at birth, not a mirror
  with added as (
    insert into public.members (workspace_id, user_id, is_owner, is_admin, co_owner, status)
    select v_house, m.user_id, false, true, 'active', 'active'
      from public.members m
     where m.workspace_id = v_head.id and m.status = 'active'
       and (m.is_owner or m.co_owner = 'active')
       and m.user_id is not null and m.user_id <> auth.uid()
    on conflict do nothing
    returning user_id)
  select coalesce(array_agg(user_id), '{}') into v_added from added;

  -- the features the house's country offers, as the head has them
  for v_flag in select key, value from jsonb_each(coalesce(v_head.feature_flags, '{}'::jsonb)) loop
    if public.feature_available_in(v_country, v_flag.key) then
      v_flags := v_flags || jsonb_build_object(v_flag.key, v_flag.value);
    end if;
  end loop;
  update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || v_flags
   where id = v_house;

  -- the head's configuration, fenced
  v_cfg := public.export_workspace_configuration(v_head.id);
  v_same_currency := upper(v_head.currency_code) = v_currency;
  v_same_country := upper(v_head.country_code) = v_country;
  for v_table in select jsonb_object_keys(v_fenced) loop
    if v_table = 'closure_days' and not v_same_country then continue; end if;
    v_rows := '[]'::jsonb;
    for v_row in select value from jsonb_array_elements(coalesce(v_cfg->'tables'->v_table, '[]'::jsonb)) loop
      if v_table in ('plans', 'services', 'packages') then
        -- priced: inactive, no rate, the head's rate category as a hint
        if v_row->>'vat_rate' is not null then
          v_hints := v_hints || jsonb_build_object(v_table || ':' || (v_row->>'name'),
            (select r.category from public.vat_rates r
              where r.workspace_id = v_head.id and r.label = v_row->>'vat_rate' limit 1));
        end if;
        v_row := (v_row - 'vat_rate') || jsonb_build_object('active', false);
        v_priced := v_priced + 1;
      end if;
      -- every fenced amount: kept in the same currency, 0 in another
      if not v_same_currency then
        for v_col in select jsonb_array_elements_text(v_fenced->v_table) loop
          if v_row ? v_col then v_row := v_row || jsonb_build_object(v_col, 0); end if;
        end loop;
      end if;
      v_rows := v_rows || jsonb_build_array(v_row);
    end loop;
    v_tables := v_tables || jsonb_build_object(v_table, v_rows);
  end loop;
  perform public.import_workspace_configuration(v_house, jsonb_build_object(
    'workspace', jsonb_strip_nulls(jsonb_build_object(
      'booking_rules', v_cfg->'workspace'->'booking_rules',
      'desk_opacity', v_cfg->'workspace'->'desk_opacity',
      'role_permissions', v_cfg->'workspace'->'role_permissions',
      'dunning_rules', v_cfg->'workspace'->'dunning_rules',
      'invoice_pdf_template', v_cfg->'workspace'->'invoice_pdf_template')),
    'tables', v_tables), 'merge');

  v_carried := jsonb_build_object(
    'plans', jsonb_array_length(v_tables->'plans'),
    'services', jsonb_array_length(v_tables->'services'),
    'packages', jsonb_array_length(v_tables->'packages'),
    'validation_policies', jsonb_array_length(v_tables->'validation_policies'),
    'workspace_documents', jsonb_array_length(v_tables->'workspace_documents'),
    'closure_days', coalesce(jsonb_array_length(v_tables->'closure_days'), 0),
    'features', (select count(*) from jsonb_object_keys(v_flags)),
    'amounts_kept', v_same_currency,
    'rate_hints', v_hints);
  insert into public.organisation_houses
    (workspace_id, organisation_id, head_workspace_id, carried, co_owners_added, prices_pending)
  values (v_house, p_organisation, v_head.id, v_carried, v_added, v_priced > 0);
  return jsonb_build_object('workspace_id', v_house, 'carried', v_carried);
end;
$fn$;
revoke execute on function public.create_organisation_house_once(uuid, text, text, text, text, text, uuid)
  from public, anon;
grant execute on function public.create_organisation_house_once(uuid, text, text, text, text, text, uuid)
  to authenticated;

-- ── 4. the prices are named ──────────────────────────────────────────────
-- The owner's "Name your prices" step closes; closing twice is no error.
create or replace function public.clear_house_prices_pending(p_workspace_id uuid)
returns void language plpgsql security definer set search_path = public as $fn$
begin
  if auth.uid() is null or public.mcp_is_delegated()
     or not coalesce(public.is_owner_of(p_workspace_id), false) then
    raise exception 'only an owner of this business may do this' using errcode = '42501';
  end if;
  update public.organisation_houses set prices_pending = false
   where workspace_id = p_workspace_id and prices_pending;
end;
$fn$;
revoke execute on function public.clear_house_prices_pending(uuid) from public, anon;
grant execute on function public.clear_house_prices_pending(uuid) to authenticated;

select public.set_deskilo_schema_version(778);
