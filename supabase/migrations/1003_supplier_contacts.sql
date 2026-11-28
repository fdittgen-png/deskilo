-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
-- (two tables with their roles seeded; three nullable columns on suppliers; export_workspace_records restated whole)
--
-- #4518 (STK-11, #4500 package 4) -- a supplier has contacts, each with a role, and one of them is its preferred purchasing contact; the
-- supplier carries the commercial defaults agreed once (the currency its orders are placed in, the days its bills are due after their date,
-- the days its orders expect their goods after they are sent).
--
--   * supplier_contact_roles: the roles a business gives its suppliers' contacts, one list per business: orders, invoices, delivery,
--     accounting and other are built in (an empty label: the app shows its five-language words), the business adds, renames, orders and
--     retires the others. Never deleted; its code never moves; two active roles do not share a label.
--   * supplier_contacts: the people of a supplier: a name, a role, an e-mail, a phone, a note, retired or not, and at most one preferred
--     purchasing contact per supplier (a partial unique index; making another one preferred swaps in one command). The preferred one has an
--     e-mail and is not retired. A contact is a person's data: the table joins the business's export, and it is read by whoever reads the
--     suppliers (viewFinances or manageBilling) and written only through the commands, by whoever manages suppliers (manageBilling) while the
--     suppliers (supplyExpenses) and the contacts (supplierContacts) are on.
--   * suppliers gets order_currency, payment_term_days and order_lead_days, all optional, written by save_supplier_terms_v1. The payment term
--     is read through supplier_payment_term_days(supplier): nothing else reads the column, so the payment-term profiles (FIN-15) can
--     take its place by a reference without a data break.
--   * The text `suppliers.contact` is kept as it is.
-- A refusal carries DKX02 (checked free in lib/core/codes/dk_code.dart; its words are the app's).

-- BEGIN FEATURE REGISTRY ROWS (dart run tool/build_feature_registry_sql.dart)
insert into public.feature_registry_entries (feature_key, parent, default_on, core, countries) values
('supplierContacts', 'supplyExpenses', true, false, null)
on conflict (feature_key) do update set parent = excluded.parent, default_on = excluded.default_on, core = excluded.core, countries = excluded.countries;
-- END FEATURE REGISTRY ROWS

-- a default-on feature that is not core reads as off where the business's flags do not hold the key (feature_raw, 0227): the existing
-- businesses are given it
update public.workspaces set feature_flags = feature_flags || '{"supplierContacts": true}'::jsonb
 where not (coalesce(feature_flags, '{}'::jsonb) ? 'supplierContacts');

-- ── the roles of a supplier's contacts ──────────────────────────────────────────────────────────────────
create table public.supplier_contact_roles (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  code text not null check (code ~ '^[a-z][a-z0-9_]{0,39}$'),
  label text not null default '' check (char_length(label) <= 60),
  sort_order int not null default 1000 check (sort_order between 0 and 100000),
  built_in boolean not null default false,
  retired_at timestamptz,
  check (built_in or btrim(label) <> ''),
  unique (workspace_id, code)
);
select public.ensure_system_columns('supplier_contact_roles');
create unique index supplier_contact_roles_active_label on public.supplier_contact_roles (workspace_id, lower(btrim(label)))
  where retired_at is null and btrim(label) <> '';

create or replace function public.supplier_contact_roles_seed(p_workspace_id uuid)
returns void language sql security definer set search_path = public as $fn$
  insert into public.supplier_contact_roles (workspace_id, code, built_in, sort_order)
  select p_workspace_id, b.code, true, b.ord
    from (values ('orders', 10), ('invoices', 20), ('delivery', 30), ('accounting', 40), ('other', 50)) as b (code, ord)
  on conflict (workspace_id, code) do nothing;
$fn$;
revoke execute on function public.supplier_contact_roles_seed(uuid) from public, anon, authenticated;

select public.supplier_contact_roles_seed(w.id) from public.workspaces w;

create or replace function public.supplier_contact_roles_seed_trigger()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  perform public.supplier_contact_roles_seed(new.id);
  return new;
end;
$fn$;
revoke execute on function public.supplier_contact_roles_seed_trigger() from public, anon, authenticated;
create trigger workspaces_seed_supplier_contact_roles after insert on public.workspaces
  for each row execute function public.supplier_contact_roles_seed_trigger();

create or replace function public.supplier_contact_roles_guard()
returns trigger language plpgsql set search_path = public as $fn$
begin
  if tg_op = 'DELETE' then
    if pg_trigger_depth() > 1 and not exists (select 1 from public.workspaces w where w.id = old.workspace_id) then
      return old;
    end if;
    raise exception 'a contact role is retired, never deleted' using errcode = 'DKX02', detail = 'role_fixed';
  end if;
  if new.workspace_id <> old.workspace_id or new.code <> old.code or new.built_in <> old.built_in then
    raise exception 'the code of a contact role never changes' using errcode = 'DKX02', detail = 'role_fixed';
  end if;
  return new;
end;
$fn$;
revoke execute on function public.supplier_contact_roles_guard() from public, anon, authenticated;
create trigger supplier_contact_roles_rules before update or delete on public.supplier_contact_roles
  for each row execute function public.supplier_contact_roles_guard();

alter table public.supplier_contact_roles enable row level security;
revoke all on table public.supplier_contact_roles from public, anon, authenticated;
grant select on table public.supplier_contact_roles to authenticated;
create policy supplier_contact_roles_select on public.supplier_contact_roles for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewFinances', 'manageBilling'])));
create policy mcp_delegated_deny on public.supplier_contact_roles as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── the contacts of a supplier ──────────────────────────────────────────────────────────────────────────
create table public.supplier_contacts (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  supplier_id uuid not null references public.suppliers (id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 120),
  role_id uuid not null references public.supplier_contact_roles (id),
  email text not null default '' check (char_length(email) <= 254),
  phone text not null default '' check (char_length(phone) <= 40),
  note text not null default '' check (char_length(note) <= 300),
  preferred boolean not null default false,
  retired_at timestamptz,
  check (not preferred or (email <> '' and retired_at is null))
);
select public.ensure_system_columns('supplier_contacts');
create unique index supplier_contacts_one_preferred on public.supplier_contacts (supplier_id) where preferred;
create index supplier_contacts_supplier on public.supplier_contacts (workspace_id, supplier_id);

alter table public.supplier_contacts enable row level security;
revoke all on table public.supplier_contacts from public, anon, authenticated;
grant select on table public.supplier_contacts to authenticated;
create policy supplier_contacts_select on public.supplier_contacts for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewFinances', 'manageBilling'])));
create policy mcp_delegated_deny on public.supplier_contacts as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── the commercial defaults of a supplier ───────────────────────────────────────────────────────────────
-- audience: all row readers
alter table public.suppliers
  add column if not exists order_currency text check (order_currency is null or order_currency ~ '^[A-Z]{3}$'),
  add column if not exists payment_term_days int check (payment_term_days is null or payment_term_days between 0 and 365),
  add column if not exists order_lead_days int check (order_lead_days is null or order_lead_days between 0 and 365);

-- the days a bill of [p_supplier_id] is due after its date, or null when the supplier states none: the one reader of the column
create or replace function public.supplier_payment_term_days(p_supplier_id uuid)
returns int language sql stable security definer set search_path = public as $fn$
  select s.payment_term_days from public.suppliers s
   where s.id = p_supplier_id and s.workspace_id in (select public.workspaces_permitting(array['viewFinances', 'manageBilling']));
$fn$;
revoke execute on function public.supplier_payment_term_days(uuid) from public, anon;
grant execute on function public.supplier_payment_term_days(uuid) to authenticated;

-- ── writing ─────────────────────────────────────────────────────────────────────────────────────────────
-- Who may: whoever manages suppliers (manageBilling) while the suppliers and the contacts are on; the refusal of a right or of a
-- switched-off feature is the permission code DKN01, the refusal of the data DKX02.
create or replace function public.supplier_contacts_actor(p_workspace_id uuid)
returns uuid language plpgsql stable security definer set search_path = public as $fn$
declare
  v_me uuid;
begin
  v_me := public.command_actor(p_workspace_id, 'manageBilling', 'supplierContacts', 'not allowed to maintain the supplier contacts', 'the supplier contacts are off');
  if not public.feature_effective(p_workspace_id, 'supplyExpenses') then
    raise exception 'supplier management is switched off in this space' using errcode = 'DKN01';
  end if;
  return v_me;
end;
$fn$;
revoke execute on function public.supplier_contacts_actor(uuid) from public, anon, authenticated;

create or replace function public.supplier_contact_role_save_v1(p_workspace_id uuid, p_request_id uuid, p_role jsonb)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_digest text;
  v_done jsonb;
  v_row public.supplier_contact_roles;
  v_label text;
  v_order int;
  v_out jsonb;
begin
  perform public.supplier_contacts_actor(p_workspace_id);
  if p_role is null or jsonb_typeof(p_role) <> 'object' then
    raise exception 'a contact role is an object' using errcode = 'DKX02', detail = 'role_malformed';
  end if;
  v_digest := md5(p_workspace_id::text || '|' || p_role::text);
  v_done := public.request_begin(p_workspace_id, p_request_id, 'supplier_contact_role_save', v_digest);
  if v_done is not null then
    return v_done || jsonb_build_object('replayed', true);
  end if;
  if nullif(p_role ->> 'id', '') is not null then
    select * into v_row from public.supplier_contact_roles where id = (p_role ->> 'id')::uuid and workspace_id = p_workspace_id for update;
    if v_row.id is null then
      raise exception 'unknown contact role' using errcode = 'DKX02', detail = 'role_unknown';
    end if;
  end if;
  v_label := case when p_role ? 'label' then btrim(coalesce(p_role ->> 'label', '')) else coalesce(v_row.label, '') end;
  v_order := coalesce((p_role ->> 'sort_order')::int, v_row.sort_order, 1000);
  if char_length(v_label) > 60 then
    raise exception 'the name of a contact role is at most 60 characters' using errcode = 'DKX02', detail = 'label_too_long';
  end if;
  if v_label = '' and not coalesce(v_row.built_in, false) then
    raise exception 'a contact role has a name' using errcode = 'DKX02', detail = 'label_required';
  end if;
  if v_label <> '' and exists (
       select 1 from public.supplier_contact_roles r
        where r.workspace_id = p_workspace_id and r.retired_at is null and lower(btrim(r.label)) = lower(v_label)
          and r.id is distinct from v_row.id) then
    raise exception 'another active contact role has this name' using errcode = 'DKX02', detail = 'label_taken';
  end if;
  if v_row.id is null then
    insert into public.supplier_contact_roles (workspace_id, code, label, sort_order)
    values (p_workspace_id, 'r_' || replace(left(gen_random_uuid()::text, 8), '-', ''), v_label, v_order)
    returning * into v_row;
  else
    update public.supplier_contact_roles set label = v_label, sort_order = v_order where id = v_row.id returning * into v_row;
  end if;
  v_out := jsonb_build_object('id', v_row.id, 'code', v_row.code, 'label', v_row.label, 'sort_order', v_row.sort_order,
                              'built_in', v_row.built_in, 'retired', v_row.retired_at is not null);
  return public.request_finish(p_workspace_id, p_request_id, 'supplier_contact_role_save', v_digest, v_out);
end;
$fn$;
revoke execute on function public.supplier_contact_role_save_v1(uuid, uuid, jsonb) from public, anon;
grant execute on function public.supplier_contact_role_save_v1(uuid, uuid, jsonb) to authenticated;

create or replace function public.supplier_contact_role_retire_v1(p_workspace_id uuid, p_request_id uuid, p_id uuid, p_retired boolean)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_digest text;
  v_done jsonb;
  v_row public.supplier_contact_roles;
  v_out jsonb;
begin
  perform public.supplier_contacts_actor(p_workspace_id);
  v_digest := md5(p_workspace_id::text || '|' || coalesce(p_id::text, '') || '|' || coalesce(p_retired::text, ''));
  v_done := public.request_begin(p_workspace_id, p_request_id, 'supplier_contact_role_retire', v_digest);
  if v_done is not null then
    return v_done || jsonb_build_object('replayed', true);
  end if;
  select * into v_row from public.supplier_contact_roles where id = p_id and workspace_id = p_workspace_id for update;
  if v_row.id is null then
    raise exception 'unknown contact role' using errcode = 'DKX02', detail = 'role_unknown';
  end if;
  if not coalesce(p_retired, true) and v_row.retired_at is not null and btrim(v_row.label) <> '' and exists (
       select 1 from public.supplier_contact_roles r
        where r.workspace_id = p_workspace_id and r.retired_at is null and lower(btrim(r.label)) = lower(btrim(v_row.label))) then
    raise exception 'another active contact role has this name' using errcode = 'DKX02', detail = 'label_taken';
  end if;
  update public.supplier_contact_roles
     set retired_at = case when coalesce(p_retired, true) then coalesce(retired_at, now()) end
   where id = v_row.id returning * into v_row;
  v_out := jsonb_build_object('id', v_row.id, 'code', v_row.code, 'retired', v_row.retired_at is not null);
  return public.request_finish(p_workspace_id, p_request_id, 'supplier_contact_role_retire', v_digest, v_out);
end;
$fn$;
revoke execute on function public.supplier_contact_role_retire_v1(uuid, uuid, uuid, boolean) from public, anon;
grant execute on function public.supplier_contact_role_retire_v1(uuid, uuid, uuid, boolean) to authenticated;

-- a contact: new (no id) or changed, with its role, its e-mail, and whether it is the preferred purchasing contact of its supplier
create or replace function public.supplier_contact_save_v1(p_workspace_id uuid, p_request_id uuid, p_contact jsonb)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_digest text;
  v_done jsonb;
  v_row public.supplier_contacts;
  v_supplier uuid;
  v_role uuid;
  v_name text;
  v_email text;
  v_phone text;
  v_note text;
  v_preferred boolean;
  v_out jsonb;
begin
  perform public.supplier_contacts_actor(p_workspace_id);
  if p_contact is null or jsonb_typeof(p_contact) <> 'object' then
    raise exception 'a supplier contact is an object' using errcode = 'DKX02', detail = 'contact_malformed';
  end if;
  v_digest := md5(p_workspace_id::text || '|' || p_contact::text);
  v_done := public.request_begin(p_workspace_id, p_request_id, 'supplier_contact_save', v_digest);
  if v_done is not null then
    return v_done || jsonb_build_object('replayed', true);
  end if;
  if nullif(p_contact ->> 'id', '') is not null then
    select * into v_row from public.supplier_contacts where id = (p_contact ->> 'id')::uuid and workspace_id = p_workspace_id for update;
    if v_row.id is null then
      raise exception 'unknown supplier contact' using errcode = 'DKX02', detail = 'contact_unknown';
    end if;
    v_supplier := v_row.supplier_id;
  else
    v_supplier := nullif(p_contact ->> 'supplier_id', '')::uuid;
  end if;
  if v_supplier is null or not exists (select 1 from public.suppliers s where s.id = v_supplier and s.workspace_id = p_workspace_id) then
    raise exception 'unknown supplier' using errcode = 'DKX02', detail = 'supplier_unknown';
  end if;
  v_name := case when p_contact ? 'name' then btrim(coalesce(p_contact ->> 'name', '')) else coalesce(v_row.name, '') end;
  v_email := case when p_contact ? 'email' then btrim(coalesce(p_contact ->> 'email', '')) else coalesce(v_row.email, '') end;
  v_phone := case when p_contact ? 'phone' then btrim(coalesce(p_contact ->> 'phone', '')) else coalesce(v_row.phone, '') end;
  v_note := case when p_contact ? 'note' then btrim(coalesce(p_contact ->> 'note', '')) else coalesce(v_row.note, '') end;
  v_preferred := case when p_contact ? 'preferred' then coalesce((p_contact ->> 'preferred')::boolean, false) else coalesce(v_row.preferred, false) end;
  v_role := case when p_contact ? 'role_id' then nullif(p_contact ->> 'role_id', '')::uuid else v_row.role_id end;
  if char_length(v_name) not between 1 and 120 then
    raise exception 'a contact has a name of 1-120 characters' using errcode = 'DKX02', detail = 'name_required';
  end if;
  if v_email <> '' and (v_email !~ '^[^\s@<>",;()\[\]\\]+@[^\s@<>",;()\[\]\\]+\.[^\s@<>",;()\[\]\\]+$' or char_length(v_email) > 254) then
    raise exception 'the e-mail of a contact is an address' using errcode = 'DKX02', detail = 'email_invalid';
  end if;
  if char_length(v_phone) > 40 or char_length(v_note) > 300 then
    raise exception 'the phone or the note of a contact is too long' using errcode = 'DKX02', detail = 'too_long';
  end if;
  -- the role is an active role of the business, or the one the contact already holds
  if v_role is null or not exists (
       select 1 from public.supplier_contact_roles r
        where r.id = v_role and r.workspace_id = p_workspace_id and (r.retired_at is null or r.id is not distinct from v_row.role_id)) then
    raise exception 'unknown contact role' using errcode = 'DKX02', detail = 'role_unknown';
  end if;
  if v_preferred and v_email = '' then
    raise exception 'the preferred purchasing contact has an e-mail' using errcode = 'DKX02', detail = 'preferred_needs_email';
  end if;
  if v_preferred and v_row.retired_at is not null then
    raise exception 'a retired contact is not the preferred contact' using errcode = 'DKX02', detail = 'preferred_retired';
  end if;
  -- one preferred purchasing contact per supplier: making this one preferred frees the other
  if v_preferred then
    update public.supplier_contacts set preferred = false
     where supplier_id = v_supplier and preferred and id is distinct from v_row.id;
  end if;
  if v_row.id is null then
    insert into public.supplier_contacts (workspace_id, supplier_id, name, role_id, email, phone, note, preferred)
    values (p_workspace_id, v_supplier, v_name, v_role, v_email, v_phone, v_note, v_preferred)
    returning * into v_row;
  else
    update public.supplier_contacts
       set name = v_name, role_id = v_role, email = v_email, phone = v_phone, note = v_note, preferred = v_preferred
     where id = v_row.id returning * into v_row;
  end if;
  v_out := jsonb_build_object('id', v_row.id, 'supplier_id', v_row.supplier_id, 'name', v_row.name, 'role_id', v_row.role_id,
                              'email', v_row.email, 'phone', v_row.phone, 'note', v_row.note, 'preferred', v_row.preferred,
                              'retired', v_row.retired_at is not null);
  return public.request_finish(p_workspace_id, p_request_id, 'supplier_contact_save', v_digest, v_out);
end;
$fn$;
revoke execute on function public.supplier_contact_save_v1(uuid, uuid, jsonb) from public, anon;
grant execute on function public.supplier_contact_save_v1(uuid, uuid, jsonb) to authenticated;

create or replace function public.supplier_contact_retire_v1(p_workspace_id uuid, p_request_id uuid, p_id uuid, p_retired boolean)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_digest text;
  v_done jsonb;
  v_row public.supplier_contacts;
  v_out jsonb;
begin
  perform public.supplier_contacts_actor(p_workspace_id);
  v_digest := md5(p_workspace_id::text || '|' || coalesce(p_id::text, '') || '|' || coalesce(p_retired::text, ''));
  v_done := public.request_begin(p_workspace_id, p_request_id, 'supplier_contact_retire', v_digest);
  if v_done is not null then
    return v_done || jsonb_build_object('replayed', true);
  end if;
  select * into v_row from public.supplier_contacts where id = p_id and workspace_id = p_workspace_id for update;
  if v_row.id is null then
    raise exception 'unknown supplier contact' using errcode = 'DKX02', detail = 'contact_unknown';
  end if;
  -- a retired contact is no longer the preferred one; bringing it back does not make it so
  update public.supplier_contacts
     set retired_at = case when coalesce(p_retired, true) then coalesce(retired_at, now()) end,
         preferred = case when coalesce(p_retired, true) then false else preferred end
   where id = v_row.id returning * into v_row;
  v_out := jsonb_build_object('id', v_row.id, 'retired', v_row.retired_at is not null, 'preferred', v_row.preferred);
  return public.request_finish(p_workspace_id, p_request_id, 'supplier_contact_retire', v_digest, v_out);
end;
$fn$;
revoke execute on function public.supplier_contact_retire_v1(uuid, uuid, uuid, boolean) from public, anon;
grant execute on function public.supplier_contact_retire_v1(uuid, uuid, uuid, boolean) to authenticated;

-- the commercial defaults of a supplier: each given or null (none stated)
create or replace function public.save_supplier_terms_v1(p_workspace_id uuid, p_request_id uuid, p_supplier_id uuid, p_terms jsonb)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_digest text;
  v_done jsonb;
  v_row public.suppliers;
  v_currency text;
  v_term int;
  v_lead int;
  v_out jsonb;
begin
  perform public.supplier_contacts_actor(p_workspace_id);
  if p_terms is null or jsonb_typeof(p_terms) <> 'object' then
    raise exception 'the terms of a supplier are an object' using errcode = 'DKX02', detail = 'terms_malformed';
  end if;
  v_digest := md5(p_workspace_id::text || '|' || coalesce(p_supplier_id::text, '') || '|' || p_terms::text);
  v_done := public.request_begin(p_workspace_id, p_request_id, 'supplier_terms_save', v_digest);
  if v_done is not null then
    return v_done || jsonb_build_object('replayed', true);
  end if;
  select * into v_row from public.suppliers where id = p_supplier_id and workspace_id = p_workspace_id for update;
  if v_row.id is null then
    raise exception 'unknown supplier' using errcode = 'DKX02', detail = 'supplier_unknown';
  end if;
  v_currency := case when p_terms ? 'order_currency' then nullif(upper(btrim(coalesce(p_terms ->> 'order_currency', ''))), '') else v_row.order_currency end;
  v_term := case when p_terms ? 'payment_term_days' then nullif(p_terms ->> 'payment_term_days', '')::int else v_row.payment_term_days end;
  v_lead := case when p_terms ? 'order_lead_days' then nullif(p_terms ->> 'order_lead_days', '')::int else v_row.order_lead_days end;
  if v_currency is not null and v_currency !~ '^[A-Z]{3}$' then
    raise exception 'a currency is three capital letters' using errcode = 'DKX02', detail = 'currency_invalid';
  end if;
  if v_term is not null and v_term not between 0 and 365 or v_lead is not null and v_lead not between 0 and 365 then
    raise exception 'a term is between 0 and 365 days' using errcode = 'DKX02', detail = 'term_invalid';
  end if;
  update public.suppliers set order_currency = v_currency, payment_term_days = v_term, order_lead_days = v_lead where id = v_row.id;
  v_out := jsonb_build_object('supplier_id', v_row.id, 'order_currency', v_currency, 'payment_term_days', v_term, 'order_lead_days', v_lead);
  return public.request_finish(p_workspace_id, p_request_id, 'supplier_terms_save', v_digest, v_out);
end;
$fn$;
revoke execute on function public.save_supplier_terms_v1(uuid, uuid, uuid, jsonb) from public, anon;
grant execute on function public.save_supplier_terms_v1(uuid, uuid, uuid, jsonb) to authenticated;

-- ── the export carries the tables ───────────────────────────────────────────────────────────────────────
-- restates 0998 (export_workspace_records)

CREATE OR REPLACE FUNCTION public.export_workspace_records(p_workspace_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_tables text[] := array[
    -- configuration, readable (the XML stays the re-importable copy)
    'sites', 'fee_bands', 'packages', 'credit_products', 'vat_rates',
    'accessories', 'seat_accessories', 'closure_days', 'validation_policies',
    'workspace_roles', 'workspace_role_members', 'workspace_field_definitions',
    'workspace_field_values', 'number_sequences', 'charging_stations',
    'plan_images', 'setting_values',
    -- member accounts
    'member_credits', 'member_credit_uses', 'price_negotiations',
    'quota_extensions', 'usage_records', 'invoice_matches', 'invoice_reminders',
    'invoice_dunning_holds', 'tax_exemption_certificates',
    -- purchases, premises, assets, books
    'suppliers', 'purchase_documents', 'purchase_lines', 'purchase_obligations',
    'outgoing_payments', 'expense_schedules', 'expense_occurrences',
    'expense_repartitions', 'premises_leases', 'lease_terms',
    'lease_settlements', 'room_rentals', 'room_rental_fees', 'workspace_assets',
    'asset_valuation_batches', 'asset_valuation_rows', 'book_profiles',
    'book_accounts', 'book_mappings', 'book_periods', 'vat_declarations',
    'einvoice_inbox',
    -- people the space is accountable to
    'guest_participations', 'rights_requests',
    -- #3307 the orders to the suppliers
    'purchase_orders', 'purchase_order_lines', 'purchase_order_sends',
    'purchase_order_receipts', 'purchase_order_receipt_lines',
    -- #3308 the passes the space sells and the passes it sold
    'guest_pass_offers', 'guest_passes',
    -- #3824 the goods ledger
    'item_units', 'item_codes', 'stock_locations', 'stock_lots', 'stock_movements',
    'stock_balances',
    -- #4362 the tags bound to items, places and pieces, and the named pieces
    'stock_tags', 'stock_tagged_units', 'stock_movement_units',
    'stock_handling_units', 'stock_handling_unit_lines', 'stock_handling_unit_pieces', 'stock_movement_handling_units',
    'stock_repacks', 'stock_repack_lines',
    -- #4184 the counter's receipts, their lines and their tenders
    'counter_receipts', 'counter_receipt_lines', 'counter_tenders', 'counter_refunds',
    -- #4367 the tills, their sessions, the cash entries and the day closes
    'counter_tills', 'counter_till_sessions', 'counter_cash_entries', 'counter_day_closes',
    -- #4373 the sales a till made offline, as the server received them
    'counter_offline_sales',
    -- #4164 the billing identity of each customer the business invoices
    'billing_parties',
    -- #4166 the customer quotes, their revisions, the decisions the issuer recorded and
    -- the conversions into invoices
    'customer_quotes', 'customer_quote_revisions', 'customer_quote_decisions',
    'customer_quote_conversions',
    -- #4169 the variants and the supplier's article
    'item_dimensions', 'item_dimension_values', 'item_variants', 'item_variant_values',
    'supplier_item_mappings',
    -- #4171 what was put away from a delivery
    'stock_receipt_allocations',
    -- #4170 the transfers between sites and what each loaded
    'stock_transfers', 'stock_transfer_lines',
    -- #4294 the reorder points
    'stock_reorder_points', 'item_groups', 'item_group_history',
    -- #4172 the returns, and what each line reversed
    'stock_returns', 'stock_reversals',
    -- #4172 the counts and their decisions
    'stock_counts',
    -- #4295 the plans, the tasks and their lines
    'stock_count_plans', 'stock_count_tasks', 'stock_count_task_lines',
    -- #4178 the engagements of the services ordered, their steps and the invoice
    -- lines that billed a direct commitment
    'service_fulfilments', 'service_fulfilment_transitions', 'service_fulfilment_invoice_links',
    -- #4436 the track IDs frozen on the goods lines of an issued invoice
    'invoice_line_tracks',
    -- #4442 the units of measure of the business and their conversions
    'workspace_units', 'unit_conversions', 'expense_categories', 'supplier_contact_roles', 'supplier_contacts',
    -- #4476 the copies printed of a counter receipt
    'counter_receipt_copies'];
  v_left_out text[] := public.system_column_names() || array['workspace_id', 'source_xml'];
  v_table text;
  v_columns text[];
  v_rows jsonb;
  v_out jsonb := '[]'::jsonb;
begin
  if auth.uid() is null or not public.has_permission(p_workspace_id, 'exportData') then
    raise exception 'only someone who may export this workspace''s data reads its records'
      using errcode = 'DKN01';
  end if;
  foreach v_table in array v_tables loop
    -- the sessions, their entries and the day closes carry the expected cash and the differences: the finances' to export
    if v_table in ('counter_till_sessions', 'counter_cash_entries', 'counter_day_closes', 'counter_offline_sales', 'invoice_line_tracks') and not public.has_permission(p_workspace_id, 'viewFinances') then
      continue;
    end if;
    select array_agg(c.column_name::text order by c.ordinal_position) into v_columns
      from information_schema.columns c
     where c.table_schema = 'public' and c.table_name = v_table
       and c.column_name <> all (v_left_out);
    execute format(
      'select coalesce(jsonb_agg(jsonb_build_array(%s) order by created_datetime), ''[]''::jsonb)
         from public.%I where workspace_id = $1',
      (select string_agg(format('%I', c), ', ') from unnest(v_columns) c), v_table)
      into v_rows using p_workspace_id;
    v_out := v_out || jsonb_build_array(jsonb_build_object(
      'table', v_table, 'columns', to_jsonb(v_columns), 'rows', v_rows));
  end loop;
  return v_out;
end;
$function$;
revoke execute on function public.export_workspace_records(uuid) from public, anon;

select public.set_deskilo_schema_version(1003);
