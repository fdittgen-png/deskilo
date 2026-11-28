-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
-- (one table with its rows seeded; two columns' worth of new reads: purchase_documents.category_id; submit_expense,
--  save_purchase_draft_v1 and export_workspace_records restated whole from their live definitions)
--
-- #4512 (FIN-06, #4500 package 4) -- the categories an expense is filed under are the business's own records.
--
--   * expense_categories(workspace_id, code, label, sort_order, built_in, retired_at). Every business starts with
--     coffee, supplies, equipment and other (built in: an empty label, the app shows its five-language words) and the
--     literal the scheduled occurrences file under, scheduled (retired from the start: no picker offers it, what is
--     filed under it stays readable). A trigger seeds a new business; a backfill seeds the existing ones. Nothing stored
--     is rewritten: the text of every expense and purchase stays what it was.
--   * A category is never deleted, only retired; its code and business never move. Two active categories of a business
--     do not share a label.
--   * expense_category_save_v1 (a new category, a rename, an order) and expense_category_retire_v1 (retire and bring
--     back) are the commands, for the right workspaceSettings and the feature expenseCategories.
--   * expense_category_resolve is the one rule at every door: a category is named by its identity (category_id) or by the
--     code of one of the business (case-folded); it must be active, a retired one only on a draft that already holds
--     it. Anything else is DKX01, the expense category refusal. submit_expense (a new defaulted parameter
--     p_category_id) and save_purchase_draft_v1 (payload.category_id, or the text of payload.category as a code) take
--     it; the event and the purchase keep the label the category had when they were filed (its code for a built-in
--     with no label), so every reader of the text -- the obligations, the cost allocation, the accounting source, the
--     DATEV facts -- reads what it read, and `category_id` beside it names the record.
--   * The table joins the business's export.
-- A refusal carries DKX01 (the app reads it by its code; checked free in lib/core/codes/dk_code.dart).

-- BEGIN FEATURE REGISTRY ROWS (dart run tool/build_feature_registry_sql.dart)
insert into public.feature_registry_entries (feature_key, parent, default_on, core, countries) values
('expenseCategories', null, true, false, null)
on conflict (feature_key) do update set parent = excluded.parent, default_on = excluded.default_on, core = excluded.core, countries = excluded.countries;
-- END FEATURE REGISTRY ROWS

-- a default-on feature that is not core reads as off where the business's flags do not hold the key (feature_raw, 0227): the
-- existing businesses are given it
update public.workspaces set feature_flags = feature_flags || '{"expenseCategories": true}'::jsonb
 where not (coalesce(feature_flags, '{}'::jsonb) ? 'expenseCategories');

create table public.expense_categories (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  code text not null check (code ~ '^[a-z][a-z0-9_]{0,39}$'),
  label text not null default '' check (char_length(label) <= 80),
  sort_order int not null default 1000 check (sort_order between 0 and 100000),
  built_in boolean not null default false,
  retired_at timestamptz,
  check (built_in or btrim(label) <> ''),
  unique (workspace_id, code)
);
select public.ensure_system_columns('expense_categories');
create unique index expense_categories_active_label on public.expense_categories (workspace_id, lower(btrim(label)))
  where retired_at is null and btrim(label) <> '';

-- the categories every business starts with: (code, order, retired)
create or replace function public.expense_categories_seed(p_workspace_id uuid)
returns void language sql security definer set search_path = public as $fn$
  insert into public.expense_categories (workspace_id, code, built_in, sort_order, retired_at)
  select p_workspace_id, b.code, true, b.ord, case when b.retired then now() end
    from (values ('coffee', 10, false), ('supplies', 20, false), ('equipment', 30, false), ('other', 40, false),
                 ('scheduled', 50, true)) as b (code, ord, retired)
  on conflict (workspace_id, code) do nothing;
$fn$;
revoke execute on function public.expense_categories_seed(uuid) from public, anon, authenticated;

select public.expense_categories_seed(w.id) from public.workspaces w;

create or replace function public.expense_categories_seed_trigger()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  perform public.expense_categories_seed(new.id);
  return new;
end;
$fn$;
revoke execute on function public.expense_categories_seed_trigger() from public, anon, authenticated;
create trigger workspaces_seed_expense_categories after insert on public.workspaces
  for each row execute function public.expense_categories_seed_trigger();

-- the rules of a row: never deleted (but with its business), its code, business and built-in kind never move
create or replace function public.expense_categories_guard()
returns trigger language plpgsql set search_path = public as $fn$
begin
  if tg_op = 'DELETE' then
    if pg_trigger_depth() > 1 and not exists (select 1 from public.workspaces w where w.id = old.workspace_id) then
      return old;
    end if;
    raise exception 'an expense category is retired, never deleted' using errcode = 'DKX01', detail = 'category_fixed';
  end if;
  if new.workspace_id <> old.workspace_id or new.code <> old.code or new.built_in <> old.built_in then
    raise exception 'the code of an expense category never changes' using errcode = 'DKX01', detail = 'category_fixed';
  end if;
  return new;
end;
$fn$;
revoke execute on function public.expense_categories_guard() from public, anon, authenticated;
create trigger expense_categories_rules before update or delete on public.expense_categories
  for each row execute function public.expense_categories_guard();

alter table public.expense_categories enable row level security;
revoke all on table public.expense_categories from public, anon, authenticated;
grant select on table public.expense_categories to authenticated;
create policy expense_categories_select on public.expense_categories for select to authenticated
  using (public.is_member_of(workspace_id));
create policy mcp_delegated_deny on public.expense_categories as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- the purchase names the record it was filed under
-- audience: all row readers
alter table public.purchase_documents
  add column if not exists category_id uuid references public.expense_categories (id);

-- ── the texts the drafts already carry become the business's categories ──────────────────────────────────
-- each distinct text of a purchase DRAFT that is not the code of one of the business's categories (case-folded) is made a
-- category of its own, with the text as its label, and the draft is given the record it will be filed under. A decided or
-- submitted purchase is frozen and keeps its text, as does every expense: nothing stored is rewritten.
insert into public.expense_categories (workspace_id, code, label)
select d.workspace_id, 'c_' || left(md5(d.workspace_id::text || '|' || lower(btrim(d.category))), 8), min(left(btrim(d.category), 80))
  from public.purchase_documents d
 where d.state = 'draft' and btrim(d.category) <> ''
   and not exists (select 1 from public.expense_categories c
                    where c.workspace_id = d.workspace_id and c.code = lower(btrim(d.category)))
 group by d.workspace_id, lower(btrim(d.category))
on conflict (workspace_id, code) do nothing;

update public.purchase_documents d set category_id = c.id
  from public.expense_categories c
 where c.workspace_id = d.workspace_id and d.state = 'draft' and d.category_id is null and btrim(d.category) <> ''
   and (c.code = lower(btrim(d.category)) or c.code = 'c_' || left(md5(d.workspace_id::text || '|' || lower(btrim(d.category))), 8));

-- ── the one rule: a category of the business, by identity or by code ────────────────────────────────────
create or replace function public.expense_category_resolve(p_workspace_id uuid, p_id uuid, p_text text, p_held uuid)
returns table (category_id uuid, snapshot text) language plpgsql stable security definer set search_path = public as $fn$
declare
  v public.expense_categories;
  v_code text := lower(btrim(coalesce(p_text, '')));
begin
  if p_id is not null then
    select * into v from public.expense_categories c where c.id = p_id and c.workspace_id = p_workspace_id;
  elsif v_code <> '' then
    select * into v from public.expense_categories c where c.workspace_id = p_workspace_id and c.code = v_code;
  end if;
  if v.id is null or (v.retired_at is not null and v.id is distinct from p_held) then
    raise exception 'expense_category_unknown' using errcode = 'DKX01', detail = 'expense_category_unknown';
  end if;
  return query select v.id, coalesce(nullif(btrim(v.label), ''), v.code);
end;
$fn$;
revoke execute on function public.expense_category_resolve(uuid, uuid, text, uuid) from public, anon, authenticated;

-- ── writing: one command creates or edits, one retires or brings back ───────────────────────────────────
create or replace function public.expense_category_save_v1(p_workspace_id uuid, p_request_id uuid, p_category jsonb)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  v_row public.expense_categories;
  v_label text;
  v_order int;
  v_out jsonb;
begin
  v_me := public.command_actor(p_workspace_id, 'workspaceSettings', 'expenseCategories', 'not allowed to maintain the expense categories', 'the expense categories are off');
  if p_category is null or jsonb_typeof(p_category) <> 'object' then
    raise exception 'an expense category is an object' using errcode = 'DKX01', detail = 'category_malformed';
  end if;
  v_digest := md5(p_workspace_id::text || '|' || p_category::text);
  v_done := public.request_begin(p_workspace_id, p_request_id, 'expense_category_save', v_digest);
  if v_done is not null then
    return v_done || jsonb_build_object('replayed', true);
  end if;
  if nullif(p_category ->> 'id', '') is not null then
    select * into v_row from public.expense_categories where id = (p_category ->> 'id')::uuid and workspace_id = p_workspace_id for update;
    if v_row.id is null then
      raise exception 'expense_category_unknown' using errcode = 'DKX01', detail = 'expense_category_unknown';
    end if;
  end if;
  v_label := case when p_category ? 'label' then btrim(coalesce(p_category ->> 'label', '')) else coalesce(v_row.label, '') end;
  v_order := coalesce((p_category ->> 'sort_order')::int, v_row.sort_order, 1000);
  if char_length(v_label) > 80 then
    raise exception 'the name of an expense category is at most 80 characters' using errcode = 'DKX01', detail = 'label_too_long';
  end if;
  if v_label = '' and not coalesce(v_row.built_in, false) then
    raise exception 'an expense category has a name' using errcode = 'DKX01', detail = 'label_required';
  end if;
  if v_label <> '' and exists (
       select 1 from public.expense_categories c
        where c.workspace_id = p_workspace_id and c.retired_at is null and lower(btrim(c.label)) = lower(v_label)
          and c.id is distinct from v_row.id) then
    raise exception 'another active expense category has this name' using errcode = 'DKX01', detail = 'label_taken';
  end if;
  if v_row.id is null then
    insert into public.expense_categories (workspace_id, code, label, sort_order)
    values (p_workspace_id, 'c_' || replace(left(gen_random_uuid()::text, 8), '-', ''), v_label, v_order)
    returning * into v_row;
  else
    update public.expense_categories set label = v_label, sort_order = v_order where id = v_row.id returning * into v_row;
  end if;
  v_out := jsonb_build_object('id', v_row.id, 'code', v_row.code, 'label', v_row.label, 'sort_order', v_row.sort_order,
                              'built_in', v_row.built_in, 'retired', v_row.retired_at is not null);
  return public.request_finish(p_workspace_id, p_request_id, 'expense_category_save', v_digest, v_out);
end;
$fn$;
revoke execute on function public.expense_category_save_v1(uuid, uuid, jsonb) from public, anon;
grant execute on function public.expense_category_save_v1(uuid, uuid, jsonb) to authenticated;

create or replace function public.expense_category_retire_v1(p_workspace_id uuid, p_request_id uuid, p_id uuid, p_retired boolean)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  v_row public.expense_categories;
  v_out jsonb;
begin
  v_me := public.command_actor(p_workspace_id, 'workspaceSettings', 'expenseCategories', 'not allowed to maintain the expense categories', 'the expense categories are off');
  v_digest := md5(p_workspace_id::text || '|' || coalesce(p_id::text, '') || '|' || coalesce(p_retired::text, ''));
  v_done := public.request_begin(p_workspace_id, p_request_id, 'expense_category_retire', v_digest);
  if v_done is not null then
    return v_done || jsonb_build_object('replayed', true);
  end if;
  select * into v_row from public.expense_categories where id = p_id and workspace_id = p_workspace_id for update;
  if v_row.id is null then
    raise exception 'expense_category_unknown' using errcode = 'DKX01', detail = 'expense_category_unknown';
  end if;
  -- bringing one back must not meet another active category of the same name
  if not coalesce(p_retired, true) and v_row.retired_at is not null and btrim(v_row.label) <> '' and exists (
       select 1 from public.expense_categories c
        where c.workspace_id = p_workspace_id and c.retired_at is null and lower(btrim(c.label)) = lower(btrim(v_row.label))) then
    raise exception 'another active expense category has this name' using errcode = 'DKX01', detail = 'label_taken';
  end if;
  update public.expense_categories
     set retired_at = case when coalesce(p_retired, true) then coalesce(retired_at, now()) end
   where id = v_row.id returning * into v_row;
  v_out := jsonb_build_object('id', v_row.id, 'code', v_row.code, 'retired', v_row.retired_at is not null);
  return public.request_finish(p_workspace_id, p_request_id, 'expense_category_retire', v_digest, v_out);
end;
$fn$;
revoke execute on function public.expense_category_retire_v1(uuid, uuid, uuid, boolean) from public, anon;
grant execute on function public.expense_category_retire_v1(uuid, uuid, uuid, boolean) to authenticated;

-- ── the writers take the one rule ──────────────────────────────────────────────────────────────────────
-- restates 0413 (submit_expense): a new defaulted parameter, so the old signature goes
drop function if exists public.submit_expense(uuid, integer, text, text, jsonb, jsonb);

CREATE OR REPLACE FUNCTION public.submit_expense(p_workspace_id uuid, p_amount_cents integer, p_category text, p_description text DEFAULT ''::text, p_supply jsonb DEFAULT NULL::jsonb, p_vat jsonb DEFAULT NULL::jsonb, p_category_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_actor public.members;
  v_event_id uuid;
  v_supply jsonb := null;
  v_vat jsonb := null;
  v_qty int;
  v_unit int;
  v_name text;
  v_service_id uuid;
  v_cat_id uuid;
  v_cat_text text;
  v_held uuid;
begin
  select * into v_actor from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid() and status = 'active';
  if v_actor.id is null then raise exception 'not an active member'; end if;
  if p_amount_cents <= 0 then raise exception 'amount must be positive'; end if;
  -- #4512: the category is one of the business's own, by identity or by the code it names; the event keeps its label
  -- a purchase submitted through here keeps the category it holds even if it was retired since
  v_held := (select d.category_id from public.purchase_documents d
              where d.id = nullif(current_setting('deskilo.purchase_bridge', true), '')::uuid and d.workspace_id = p_workspace_id);
  select r.category_id, r.snapshot into v_cat_id, v_cat_text from public.expense_category_resolve(p_workspace_id, p_category_id, p_category, v_held) r;
  if p_supply is not null then
    v_qty := (p_supply ->> 'quantity')::int;
    if v_qty is null or v_qty < 1 or v_qty > 9999 then
      raise exception 'supply quantity must be between 1 and 9999';
    end if;
    v_unit := coalesce((p_supply ->> 'unit_price_cents')::int,
                       ceil(p_amount_cents::numeric / v_qty)::int);
    if v_unit < 0 then raise exception 'unit price must not be negative'; end if;
    v_service_id := nullif(p_supply ->> 'service_id', '')::uuid;
    if v_service_id is not null then
      select name into v_name from public.services
        where id = v_service_id and workspace_id = p_workspace_id;
      if v_name is null then raise exception 'unknown service'; end if;
    else
      v_name := trim(coalesce(p_supply ->> 'name', ''));
      if char_length(v_name) between 1 and 80 is not true then
        raise exception 'supply name must be 1–80 characters';
      end if;
    end if;
    v_supply := jsonb_build_object(
      'name', v_name, 'quantity', v_qty, 'unit_price_cents', v_unit,
      'service_id', v_service_id);
  end if;
  -- #2357 — the VAT the expense carried, the share the space deducts and
  -- whether it bought a fixed asset (0413).
  v_vat := public.expense_vat_payload(p_workspace_id, p_vat);
  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
  values (
    p_workspace_id, 'expense', 'submitted', v_actor.id, v_actor.id,
    jsonb_build_object(
      'amount_cents', p_amount_cents,
      'category', v_cat_text,
      'category_id', v_cat_id,
      'note', p_description
    ) || case when v_supply is null then '{}'::jsonb
              else jsonb_build_object('supply', v_supply) end
      || case when v_vat is null then '{}'::jsonb
              else jsonb_build_object('vat', v_vat) end,
    'pending'
  ) returning id into v_event_id;
  return v_event_id;
end;
$function$;
revoke execute on function public.submit_expense(uuid, integer, text, text, jsonb, jsonb, uuid) from public, anon;
grant execute on function public.submit_expense(uuid, integer, text, text, jsonb, jsonb, uuid) to authenticated;

-- restates 0590 (save_purchase_draft_v1)
CREATE OR REPLACE FUNCTION public.save_purchase_draft_v1(p_workspace_id uuid, p_request_id uuid, p_expected_revision integer, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  v_id uuid := nullif(p_payload ->> 'purchase_id', '')::uuid;
  v_kind text;
  v_doc public.purchase_documents;
  v_ws public.workspaces;
  v_supplier uuid := nullif(p_payload ->> 'supplier_id', '')::uuid;
  v_payer text;
  v_payer_member uuid;
  v_manager boolean;
  v_currency text;
  v_original uuid := nullif(p_payload ->> 'original_document_id', '')::uuid;
  v_result jsonb;
  v_cat_given text := nullif(btrim(coalesce(p_payload ->> 'category', '')), '');
  v_cat_id uuid;
  v_cat_text text;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select m.id into v_me from public.members m
   where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active';
  if v_me is null then raise exception 'not an active member'; end if;
  if not public.feature_effective(p_workspace_id, 'purchases') then
    raise exception 'purchases are switched off in this space';
  end if;
  v_digest := md5(auth.uid()::text || coalesce(p_expected_revision, 0)::text || p_payload::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'save', v_digest);
  if v_done is not null then return v_done; end if;

  select * into v_ws from public.workspaces where id = p_workspace_id;
  v_manager := public.has_permission(p_workspace_id, 'managePurchases');
  v_kind := coalesce(nullif(p_payload ->> 'kind', ''), 'member_receipt');
  if v_kind not in ('bill', 'credit_note', 'member_receipt') then
    raise exception 'unknown purchase kind';
  end if;
  if v_kind <> 'member_receipt' and not v_manager then
    raise exception 'not allowed to capture supplier bills';
  end if;
  v_currency := upper(coalesce(nullif(p_payload ->> 'currency', ''), v_ws.currency_code));
  if v_currency !~ '^[A-Z]{3}$' then raise exception 'a currency is three capital letters'; end if;
  if v_currency <> v_ws.currency_code
     and (v_kind = 'member_receipt'
          or not public.feature_effective(p_workspace_id, 'foreignCurrencyPurchases')) then
    raise exception 'a purchase is in the currency of the space';
  end if;
  if v_supplier is not null and not exists (
       select 1 from public.suppliers s
        where s.id = v_supplier and s.workspace_id = p_workspace_id and s.status = 'active') then
    raise exception 'unknown supplier';
  end if;
  if v_original is not null and (v_kind <> 'credit_note' or not exists (
       select 1 from public.purchase_documents o
        where o.id = v_original and o.workspace_id = p_workspace_id and o.kind = 'bill')) then
    raise exception 'a credit note reverses a bill of this space';
  end if;
  if v_original is not null and not exists (
       select 1 from public.purchase_documents o where o.id = v_original and o.currency = v_currency) then
    raise exception 'a credit note is in the currency of its bill';
  end if;
  if v_kind = 'member_receipt' then
    v_payer := 'member';
    v_payer_member := v_me;
  else
    v_payer := coalesce(nullif(p_payload ->> 'payer_kind', ''), 'unpaid');
    if v_payer not in ('workspace', 'member', 'unpaid') then raise exception 'unknown payer'; end if;
    v_payer_member := case when v_payer = 'member'
      then nullif(p_payload ->> 'payer_member_id', '')::uuid end;
    if v_payer = 'member' and not exists (
         select 1 from public.members m
          where m.id = v_payer_member and m.workspace_id = p_workspace_id) then
      raise exception 'unknown payer member';
    end if;
  end if;

  -- #4512: a category named by identity or by its code is one of the business's own; an empty one is a draft not yet categorised
  if v_id is null then
    if coalesce(p_expected_revision, 0) <> 0 then raise exception 'stale revision'; end if;
    if nullif(p_payload ->> 'category_id', '') is not null or v_cat_given is not null then
      select r.category_id, r.snapshot into v_cat_id, v_cat_text from public.expense_category_resolve(p_workspace_id, nullif(p_payload ->> 'category_id', '')::uuid, v_cat_given, null) r;
    end if;
    insert into public.purchase_documents
      (workspace_id, kind, currency, category, category_id, supplier_id, original_reference, original_date,
       received_on, service_from, service_to, due_on, submitter_member_id, payer_kind,
       payer_member_id, original_document_id)
    values
      (p_workspace_id, v_kind, v_currency, coalesce(v_cat_text, ''), v_cat_id,
       v_supplier, left(coalesce(p_payload ->> 'original_reference', ''), 200),
       nullif(p_payload ->> 'original_date', '')::date, nullif(p_payload ->> 'received_on', '')::date,
       nullif(p_payload ->> 'service_from', '')::date, nullif(p_payload ->> 'service_to', '')::date,
       nullif(p_payload ->> 'due_on', '')::date, v_me, v_payer, v_payer_member, v_original)
    returning * into v_doc;
  else
    select * into v_doc from public.purchase_documents
     where id = v_id and workspace_id = p_workspace_id for update;
    if v_doc.id is null then raise exception 'unknown purchase'; end if;
    if v_doc.kind = 'member_receipt' and v_doc.submitter_member_id <> v_me then
      raise exception 'not your purchase';
    end if;
    if v_doc.kind <> 'member_receipt' and not v_manager then
      raise exception 'not allowed to capture supplier bills';
    end if;
    if v_doc.kind <> v_kind then raise exception 'the kind of a purchase does not change'; end if;
    if v_doc.state <> 'draft' then raise exception 'only a draft can be edited'; end if;
    if v_doc.revision <> coalesce(p_expected_revision, 0) then raise exception 'stale revision'; end if;
    if nullif(p_payload ->> 'category_id', '') is not null or v_cat_given is not null then
      -- the draft keeps a category retired since; a new pick is an active one
      select r.category_id, r.snapshot into v_cat_id, v_cat_text from public.expense_category_resolve(p_workspace_id, nullif(p_payload ->> 'category_id', '')::uuid, v_cat_given, v_doc.category_id) r;
    end if;
    update public.purchase_documents set
        revision = revision + 1,
        currency = v_currency,
        category = coalesce(v_cat_text, ''),
        category_id = v_cat_id,
        supplier_id = v_supplier,
        original_reference = left(coalesce(p_payload ->> 'original_reference', ''), 200),
        original_date = nullif(p_payload ->> 'original_date', '')::date,
        received_on = nullif(p_payload ->> 'received_on', '')::date,
        service_from = nullif(p_payload ->> 'service_from', '')::date,
        service_to = nullif(p_payload ->> 'service_to', '')::date,
        due_on = nullif(p_payload ->> 'due_on', '')::date,
        payer_kind = v_payer, payer_member_id = v_payer_member,
        original_document_id = v_original
      where id = v_doc.id
      returning * into v_doc;
  end if;
  perform public.purchase_write_lines(p_workspace_id, v_doc.id, p_payload -> 'lines');
  -- The rate goes with the currency: back in the space's currency, a draft
  -- keeps none.
  if v_currency = v_ws.currency_code then
    delete from public.document_exchange_rates x
     where x.workspace_id = p_workspace_id and x.document_kind = 'purchase' and x.document_id = v_doc.id;
  elsif jsonb_typeof(p_payload -> 'exchange_rate') = 'object' then
    perform public.purchase_exchange_rate_write(p_workspace_id, v_doc.id, v_me, p_payload -> 'exchange_rate');
  else
    delete from public.document_exchange_rates x
     where x.workspace_id = p_workspace_id and x.document_kind = 'purchase'
       and x.document_id = v_doc.id and x.currency <> v_currency;
  end if;
  v_result := jsonb_build_object('purchase_id', v_doc.id, 'revision', v_doc.revision,
                                 'state', v_doc.state);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'save', v_digest, v_result);
end;
$function$;
revoke execute on function public.save_purchase_draft_v1(uuid, uuid, integer, jsonb) from public, anon;

-- restates 0587 (submit_purchase_v1): the purchase names its category by identity
CREATE OR REPLACE FUNCTION public.submit_purchase_v1(p_workspace_id uuid, p_purchase_id uuid, p_revision integer, p_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  v_doc public.purchase_documents;
  v_gross bigint;
  v_net bigint;
  v_tax bigint;
  v_rates int;
  v_unstated int;
  v_unknown int;
  v_assets int;
  v_lines int;
  v_percent numeric;
  v_rec bigint;
  v_unqualified int;
  v_single boolean;
  v_vat_lines boolean := false;
  v_vat jsonb := null;
  v_supply jsonb := null;
  v_desc text;
  v_event uuid;
  v_state text;
  v_result jsonb;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select m.id into v_me from public.members m
   where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active';
  if v_me is null then raise exception 'not an active member'; end if;
  if not public.feature_effective(p_workspace_id, 'purchases') then
    raise exception 'purchases are switched off in this space';
  end if;
  v_digest := md5(auth.uid()::text || p_purchase_id::text || coalesce(p_revision, 0)::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'submit', v_digest);
  if v_done is not null then return v_done; end if;

  select * into v_doc from public.purchase_documents
   where id = p_purchase_id and workspace_id = p_workspace_id for update;
  if v_doc.id is null then raise exception 'unknown purchase'; end if;
  if v_doc.kind = 'credit_note' then
    raise exception 'a credit note is applied to its bill in a later step';
  end if;
  if v_doc.state <> 'draft' then raise exception 'only a draft can be submitted'; end if;
  if v_doc.revision <> coalesce(p_revision, 0) then raise exception 'stale revision'; end if;
  if v_doc.kind = 'bill' then
    -- A supplier bill goes to a second person: the submitter captured it
    -- (managePurchases, checked on the draft), the approver decides it.
    if not public.has_permission(p_workspace_id, 'managePurchases') then
      raise exception 'not allowed to capture supplier bills';
    end if;
    if v_doc.supplier_id is null then raise exception 'a bill needs its supplier'; end if;
    if v_doc.payer_kind <> 'unpaid' then
      raise exception 'only a bill still to be paid goes to approval';
    end if;
    select count(*), coalesce(sum(gross_cents), 0) into v_lines, v_gross
      from public.purchase_lines where purchase_id = v_doc.id;
    if v_lines = 0 or v_gross <= 0 then raise exception 'a bill needs an amount'; end if;
    if v_gross > 2147483647 then raise exception 'the amount of a bill is too large'; end if;
    -- Whoever sends it to approval cannot decide it either: the drafter and
    -- the sender may be two people, and neither is the second person.
    update public.purchase_documents
       set state = 'pending', submitted_by_member_id = v_me where id = v_doc.id;
    v_result := jsonb_build_object('purchase_id', v_doc.id, 'revision', v_doc.revision,
                                   'state', 'pending');
    return public.purchase_request_end(p_workspace_id, p_request_id, 'submit', v_digest, v_result);
  end if;
  if v_doc.submitter_member_id <> v_me then raise exception 'not your purchase'; end if;
  if v_doc.category = '' then raise exception 'a receipt needs a category'; end if;

  -- v_unstated: a line without a stated tax or rate (the one-rate payload
  -- needs both); v_unknown: a line whose tax is not known at all, or taxed
  -- at no stated rate.
  select count(*), coalesce(sum(gross_cents), 0),
         count(*) filter (where tax_cents is null or tax_rate_percent is null),
         count(*) filter (where tax_cents is null or (tax_cents > 0 and coalesce(tax_rate_percent, 0) <= 0)),
         count(distinct tax_rate_percent), count(*) filter (where recognition_kind = 'asset'),
         coalesce(sum(net_cents), 0), coalesce(sum(tax_cents), 0),
         coalesce(sum(recoverable_tax_cents), 0),
         count(*) filter (where tax_cents > 0 and recoverable_tax_cents is null)
    into v_lines, v_gross, v_unstated, v_unknown, v_rates, v_assets, v_net, v_tax, v_rec,
         v_unqualified
    from public.purchase_lines where purchase_id = v_doc.id;
  if v_lines = 0 or v_gross <= 0 then raise exception 'a receipt needs an amount'; end if;
  if v_gross > 2147483647 then raise exception 'the amount of a receipt is too large'; end if;
  v_single := v_unstated = 0 and v_rates = 1 and v_assets in (0, v_lines);
  if v_tax > 0 then
    if v_unknown > 0 then
      raise exception 'state the tax and the rate of every line of a taxed receipt';
    end if;
    if v_unqualified > 0 then
      raise exception 'qualify the deductible tax of every line before submitting';
    end if;
    -- Each rate's lines follow from it: line by line, or as a whole.
    if exists (
         select 1 from (
           select l.tax_rate_percent as r, sum(l.gross_cents)::bigint as g,
                  sum(l.net_cents)::bigint as n,
                  bool_and(l.net_cents = public.vat_split_net(l.gross_cents, l.tax_rate_percent)) as each_ok
             from public.purchase_lines l
            where l.purchase_id = v_doc.id and l.tax_rate_percent > 0
            group by l.tax_rate_percent) x
          where not x.each_ok and x.n <> public.vat_split_net(x.g, x.r)) then
      raise exception 'the tax amounts do not follow from the rate';
    end if;
    if public.feature_effective(p_workspace_id, 'inputVat') then
      if v_single then
        -- One rate and one class: ONE rate and ONE deductible share on the
        -- expense, as before.
        select max(tax_rate_percent) into v_percent
          from public.purchase_lines where purchase_id = v_doc.id;
        v_vat := jsonb_build_object('percent', trim_scale(v_percent),
                   'deductible_pct', trim_scale(round(v_rec::numeric * 100 / v_tax, 4)))
                 || case when v_assets > 0 then jsonb_build_object('asset', true) else '{}'::jsonb end;
      else
        v_vat_lines := true;
      end if;
    end if;
  end if;
  select l.description, l.supply into v_desc, v_supply from public.purchase_lines l
   where l.purchase_id = v_doc.id and l.line_no = 1;
  if v_lines > 1 then v_supply := null; end if;

  perform set_config('deskilo.purchase_bridge', v_doc.id::text, true);
  perform set_config('deskilo.purchase_vat_lines', case when v_vat_lines then 'on' else '' end, true);
  v_event := public.submit_expense(p_workspace_id, v_gross::int, v_doc.category,
                                   coalesce(v_desc, ''), v_supply, v_vat, v_doc.category_id);
  perform set_config('deskilo.purchase_vat_lines', '', true);
  perform set_config('deskilo.purchase_bridge', '', true);

  select d.state into v_state from public.purchase_documents d where d.id = v_doc.id;
  v_result := jsonb_build_object('purchase_id', v_doc.id, 'event_id', v_event,
                                 'revision', v_doc.revision, 'state', v_state);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'submit', v_digest, v_result);
end;
$function$;
revoke execute on function public.submit_purchase_v1(uuid, uuid, integer, uuid) from public, anon;

-- restates 0968 (export_workspace_records): the table joins the export
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
    'workspace_units', 'unit_conversions', 'expense_categories',
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

select public.set_deskilo_schema_version(998);
