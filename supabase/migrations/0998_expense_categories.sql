-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
-- (one table with its rows seeded; purchase_documents.category_id; submit_expense, save_purchase_draft_v1, submit_purchase_v1 and
--  export_workspace_records patched at asserted anchors of their live definitions)
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
-- Patched at asserted anchors of their live definitions (each digest equals the replay's on r22: submit_expense 8896fc904a9c,
-- save_purchase_draft_v1 68d6e1c38dc4, submit_purchase_v1 6ef3046564a5, export_workspace_records 1d45cb25b602), so what
-- 0413, 0590, 0587 and 0968 built is carried unchanged.
create or replace function pg_temp.anchor_once(p_def text, p_old text, p_new text, p_what text)
returns text
language plpgsql
as $f$
begin
  if (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old) <> 1 then
    raise exception '0998: % is not found exactly once', p_what using errcode = 'P0001';
  end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_once(text, text, text, text) from public;

-- submit_expense (0413): a new defaulted parameter, so the old signature goes
do $patch$
declare
  v_def text := pg_get_functiondef('public.submit_expense(uuid, integer, text, text, jsonb, jsonb)'::regprocedure);
begin
  v_def := pg_temp.anchor_once(v_def,
    $o$p_supply jsonb DEFAULT NULL::jsonb, p_vat jsonb DEFAULT NULL::jsonb)$o$,
    $n$p_supply jsonb DEFAULT NULL::jsonb, p_vat jsonb DEFAULT NULL::jsonb, p_category_id uuid DEFAULT NULL::uuid)$n$, 'the signature');
  v_def := pg_temp.anchor_once(v_def,
    $o$  v_service_id uuid;
begin
$o$,
    $n$  v_service_id uuid;
  v_cat_id uuid;
  v_cat_text text;
  v_held uuid;
begin
$n$, 'the variables');
  v_def := pg_temp.anchor_once(v_def,
    $o$  if p_amount_cents <= 0 then raise exception 'amount must be positive'; end if;
$o$,
    $o$  if p_amount_cents <= 0 then raise exception 'amount must be positive'; end if;
$o$ || $n$  -- #4512: the category is one of the business's own, by identity or by the code it names; the event keeps its label.
  -- A purchase submitted through here keeps the category it holds even if it was retired since.
  v_held := (select d.category_id from public.purchase_documents d
              where d.id = nullif(current_setting('deskilo.purchase_bridge', true), '')::uuid and d.workspace_id = p_workspace_id);
  select r.category_id, r.snapshot into v_cat_id, v_cat_text
    from public.expense_category_resolve(p_workspace_id, p_category_id, p_category, v_held) r;
$n$, 'the amount check');
  v_def := pg_temp.anchor_once(v_def,
    $o$      'category', p_category,
$o$,
    $n$      'category', v_cat_text,
      'category_id', v_cat_id,
$n$, 'the event payload');
  execute v_def;
end
$patch$;
drop function public.submit_expense(uuid, integer, text, text, jsonb, jsonb);
revoke execute on function public.submit_expense(uuid, integer, text, text, jsonb, jsonb, uuid) from public, anon;
grant execute on function public.submit_expense(uuid, integer, text, text, jsonb, jsonb, uuid) to authenticated;

-- save_purchase_draft_v1 (0590): the draft names its category by identity or by code
do $patch$
declare
  v_def text := pg_get_functiondef('public.save_purchase_draft_v1(uuid, uuid, integer, jsonb)'::regprocedure);
begin
  v_def := pg_temp.anchor_once(v_def,
    $o$  v_result jsonb;
begin
$o$,
    $n$  v_result jsonb;
  v_cat_given text := nullif(btrim(coalesce(p_payload ->> 'category', '')), '');
  v_cat_id uuid;
  v_cat_text text;
begin
$n$, 'the variables');
  v_def := pg_temp.anchor_once(v_def,
    $o$    insert into public.purchase_documents
      (workspace_id, kind, currency, category, supplier_id,$o$,
    $n$    -- #4512: a category named by identity or by its code is one of the business's own; none is a draft not yet categorised
    if nullif(p_payload ->> 'category_id', '') is not null or v_cat_given is not null then
      select r.category_id, r.snapshot into v_cat_id, v_cat_text
        from public.expense_category_resolve(p_workspace_id, nullif(p_payload ->> 'category_id', '')::uuid, v_cat_given, null) r;
    end if;
    insert into public.purchase_documents
      (workspace_id, kind, currency, category, category_id, supplier_id,$n$, 'the insert columns');
  v_def := pg_temp.anchor_once(v_def,
    $o$(p_workspace_id, v_kind, v_currency, left(coalesce(p_payload ->> 'category', ''), 80),$o$,
    $n$(p_workspace_id, v_kind, v_currency, coalesce(v_cat_text, ''), v_cat_id,$n$, 'the insert values');
  v_def := pg_temp.anchor_once(v_def,
    $o$    update public.purchase_documents set
        revision = revision + 1,
        currency = v_currency,
        category = left(coalesce(p_payload ->> 'category', ''), 80),
$o$,
    $n$    if nullif(p_payload ->> 'category_id', '') is not null or v_cat_given is not null then
      -- the draft keeps a category retired since; a new pick is an active one
      select r.category_id, r.snapshot into v_cat_id, v_cat_text
        from public.expense_category_resolve(p_workspace_id, nullif(p_payload ->> 'category_id', '')::uuid, v_cat_given, v_doc.category_id) r;
    end if;
    update public.purchase_documents set
        revision = revision + 1,
        currency = v_currency,
        category = coalesce(v_cat_text, ''),
        category_id = v_cat_id,
$n$, 'the update');
  execute v_def;
end
$patch$;
revoke execute on function public.save_purchase_draft_v1(uuid, uuid, integer, jsonb) from public, anon;

-- submit_purchase_v1 (0587): the purchase names its category by identity
do $patch$
declare
  v_def text := pg_get_functiondef('public.submit_purchase_v1(uuid, uuid, integer, uuid)'::regprocedure);
begin
  v_def := pg_temp.anchor_once(v_def,
    $o$coalesce(v_desc, ''), v_supply, v_vat);$o$,
    $n$coalesce(v_desc, ''), v_supply, v_vat, v_doc.category_id);$n$, 'the expense call');
  execute v_def;
end
$patch$;
revoke execute on function public.submit_purchase_v1(uuid, uuid, integer, uuid) from public, anon;

-- export_workspace_records (0968): the table joins the export
do $patch$
declare
  v_def text := pg_get_functiondef('public.export_workspace_records(uuid)'::regprocedure);
begin
  v_def := pg_temp.anchor_once(v_def,
    $o$'workspace_units', 'unit_conversions',$o$,
    $n$'workspace_units', 'unit_conversions', 'expense_categories',$n$, 'the export list');
  execute v_def;
end
$patch$;
revoke execute on function public.export_workspace_records(uuid) from public, anon;

select public.set_deskilo_schema_version(998);
