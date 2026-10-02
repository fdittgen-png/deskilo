-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0338 (#1869 B) -- the chart of accounts of one issuer, and the account
-- each posting role books to.
--
-- Small on purpose: the accounts a coworking issuer touches, reviewed by
-- someone who manages billing. A code is TEXT (leading zeroes kept); an
-- account's type and whether it takes postings are two columns; its
-- origin says whether it was typed in or taken from the suggested
-- national chart (#671) and then reviewed.
--
-- A mapping names, for one issuer and one role (customers, revenue,
-- bank, vat_output, expenses), the account it books to from a date. A
-- role maps only to a POSTING account of the type that fits it, of the
-- same issuer. Mappings are versioned from their date and never rewrite
-- what was booked before; an account a mapping uses cannot be deleted,
-- nor have its code, type or posting flag changed (its name can).
--
-- save_book_profile v2: a local book cannot start before customers,
-- revenue and bank are mapped for its first day.
--
-- Everything goes through definer functions: manageBilling writes with
-- accountingBook accepting new work and the revision the saver read;
-- viewFinances or manageBilling reads, flag or no flag.

create table if not exists public.book_accounts (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  issuer_site_id uuid not null references public.sites (id) on delete restrict,
  code text not null check (code ~ '^[0-9A-Za-z][0-9A-Za-z._-]{0,19}$'),
  name text not null check (char_length(btrim(name)) between 1 and 120),
  account_type text not null check (account_type in ('asset', 'liability', 'equity', 'income', 'expense')),
  is_posting boolean not null default true,
  origin text not null default 'manual' check (origin in ('manual', 'suggested')),
  revision integer not null default 1 check (revision >= 1),
  constraint book_accounts_issuer_code unique (issuer_site_id, code)
);
select public.ensure_system_columns('book_accounts');
create index if not exists book_accounts_workspace_idx on public.book_accounts (workspace_id, issuer_site_id, code);
alter table public.book_accounts enable row level security;
revoke all on table public.book_accounts from anon, authenticated;
drop policy if exists mcp_delegated_deny on public.book_accounts;
create policy mcp_delegated_deny on public.book_accounts
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

create table if not exists public.book_mappings (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  issuer_site_id uuid not null references public.sites (id) on delete restrict,
  role text not null check (role in ('customers', 'revenue', 'bank', 'vat_output', 'expenses')),
  account_id uuid not null references public.book_accounts (id) on delete restrict,
  effective_from date not null,
  revision integer not null default 1 check (revision >= 1),
  constraint book_mappings_issuer_role_version unique (issuer_site_id, role, effective_from)
);
select public.ensure_system_columns('book_mappings');
create index if not exists book_mappings_account_idx on public.book_mappings (account_id);
alter table public.book_mappings enable row level security;
revoke all on table public.book_mappings from anon, authenticated;
drop policy if exists mcp_delegated_deny on public.book_mappings;
create policy mcp_delegated_deny on public.book_mappings
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

create or replace function public.book_chart(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
begin
  if auth.uid() is null or public.mcp_is_delegated()
     or not (public.has_permission(p_workspace_id, 'viewFinances')
             or public.has_permission(p_workspace_id, 'manageBilling')) then
    raise exception 'only someone who reads this workspace''s finances reads its books'
      using errcode = '42501';
  end if;
  return jsonb_build_object(
    'accounts', coalesce((select jsonb_agg(jsonb_build_object(
        'id', a.id, 'workspace_id', a.workspace_id, 'issuer_site_id', a.issuer_site_id,
        'code', a.code, 'name', a.name, 'account_type', a.account_type,
        'is_posting', a.is_posting, 'origin', a.origin, 'revision', a.revision)
      order by a.issuer_site_id, a.code)
      from public.book_accounts a where a.workspace_id = p_workspace_id), '[]'::jsonb),
    'mappings', coalesce((select jsonb_agg(jsonb_build_object(
        'id', m.id, 'workspace_id', m.workspace_id, 'issuer_site_id', m.issuer_site_id,
        'role', m.role, 'account_id', m.account_id,
        'effective_from', to_char(m.effective_from, 'YYYY-MM-DD'), 'revision', m.revision)
      order by m.issuer_site_id, m.role, m.effective_from)
      from public.book_mappings m where m.workspace_id = p_workspace_id), '[]'::jsonb));
end;
$fn$;
revoke execute on function public.book_chart(uuid) from public, anon;
grant execute on function public.book_chart(uuid) to authenticated;

-- The common gate of every write below.
create or replace function public.book_write_gate(p_workspace_id uuid, p_issuer_site_id uuid)
returns void language plpgsql stable security definer set search_path = public as $fn$
begin
  if auth.uid() is null or public.mcp_is_delegated()
     or not public.has_permission(p_workspace_id, 'manageBilling') then
    raise exception 'only someone who manages billing sets the books' using errcode = '42501';
  end if;
  if not public.feature_operation_allowed(p_workspace_id, 'accountingBook', 'accept_new') then
    raise exception 'the accounting book is not switched on' using errcode = '42501';
  end if;
  if not exists (select 1 from public.sites s
                  where s.id = p_issuer_site_id and s.workspace_id = p_workspace_id) then
    raise exception 'the issuer is not a site of this workspace' using errcode = '42501';
  end if;
end;
$fn$;
revoke execute on function public.book_write_gate(uuid, uuid) from public, anon, authenticated;

create or replace function public.save_book_account(
  p_workspace_id uuid, p_issuer_site_id uuid, p_id uuid, p_code text, p_name text,
  p_account_type text, p_is_posting boolean, p_origin text, p_expected_revision int
) returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v public.book_accounts;
begin
  perform public.book_write_gate(p_workspace_id, p_issuer_site_id);
  if p_code is null or p_code !~ '^[0-9A-Za-z][0-9A-Za-z._-]{0,19}$' then
    raise exception 'an account code is 1 to 20 letters, digits, dots, dashes or underscores'
      using errcode = '22023';
  end if;
  if p_name is null or char_length(btrim(p_name)) not between 1 and 120 then
    raise exception 'an account has a name' using errcode = '22023';
  end if;
  if p_account_type is null or p_account_type not in ('asset', 'liability', 'equity', 'income', 'expense') then
    raise exception 'unknown account type' using errcode = '22023';
  end if;
  if p_origin is null or p_origin not in ('manual', 'suggested') then
    raise exception 'unknown account origin' using errcode = '22023';
  end if;
  if p_id is null then
    if coalesce(p_expected_revision, -1) <> 0 then
      raise exception 'stale account' using errcode = '40001';
    end if;
    insert into public.book_accounts (workspace_id, issuer_site_id, code, name, account_type, is_posting, origin)
    values (p_workspace_id, p_issuer_site_id, p_code, btrim(p_name), p_account_type, coalesce(p_is_posting, true), p_origin)
    returning * into v;
  else
    select * into v from public.book_accounts
     where id = p_id and workspace_id = p_workspace_id and issuer_site_id = p_issuer_site_id
     for update;
    if v.id is null then raise exception 'unknown account' using errcode = '42501'; end if;
    if coalesce(p_expected_revision, -1) <> v.revision then
      raise exception 'stale account: someone saved it since you read it' using errcode = '40001';
    end if;
    if exists (select 1 from public.book_mappings m where m.account_id = v.id)
       and (v.code <> p_code or v.account_type <> p_account_type
            or v.is_posting <> coalesce(p_is_posting, true)) then
      raise exception 'a mapped account keeps its code, type and posting flag; add a new account instead'
        using errcode = '55006';
    end if;
    update public.book_accounts
       set code = p_code, name = btrim(p_name), account_type = p_account_type,
           is_posting = coalesce(p_is_posting, true), revision = v.revision + 1
     where id = v.id
     returning * into v;
  end if;
  return jsonb_build_object(
    'id', v.id, 'workspace_id', v.workspace_id, 'issuer_site_id', v.issuer_site_id,
    'code', v.code, 'name', v.name, 'account_type', v.account_type,
    'is_posting', v.is_posting, 'origin', v.origin, 'revision', v.revision);
end;
$fn$;
revoke execute on function public.save_book_account(uuid, uuid, uuid, text, text, text, boolean, text, int) from public, anon;
grant execute on function public.save_book_account(uuid, uuid, uuid, text, text, text, boolean, text, int) to authenticated;

create or replace function public.delete_book_account(p_workspace_id uuid, p_id uuid, p_expected_revision int)
returns void language plpgsql volatile security definer set search_path = public as $fn$
declare
  v public.book_accounts;
begin
  select * into v from public.book_accounts where id = p_id and workspace_id = p_workspace_id for update;
  if v.id is null then
    raise exception 'unknown account' using errcode = '42501';
  end if;
  perform public.book_write_gate(p_workspace_id, v.issuer_site_id);
  if coalesce(p_expected_revision, -1) <> v.revision then
    raise exception 'stale account' using errcode = '40001';
  end if;
  if exists (select 1 from public.book_mappings m where m.account_id = v.id) then
    raise exception 'a mapped account cannot be deleted' using errcode = '55006';
  end if;
  delete from public.book_accounts where id = v.id;
end;
$fn$;
revoke execute on function public.delete_book_account(uuid, uuid, int) from public, anon;
grant execute on function public.delete_book_account(uuid, uuid, int) to authenticated;

create or replace function public.save_book_mapping(
  p_workspace_id uuid, p_issuer_site_id uuid, p_role text, p_account_id uuid,
  p_effective_from date, p_expected_revision int
) returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  a public.book_accounts;
  v public.book_mappings;
  v_type text;
begin
  perform public.book_write_gate(p_workspace_id, p_issuer_site_id);
  v_type := case p_role
    when 'customers' then 'asset' when 'revenue' then 'income' when 'bank' then 'asset'
    when 'vat_output' then 'liability' when 'expenses' then 'expense' end;
  if v_type is null then raise exception 'unknown role' using errcode = '22023'; end if;
  if p_effective_from is null then
    raise exception 'a mapping takes effect from a date' using errcode = '22023';
  end if;
  select * into a from public.book_accounts where id = p_account_id;
  if a.id is null or a.issuer_site_id <> p_issuer_site_id then
    raise exception 'that account is not in this issuer''s chart' using errcode = '42501';
  end if;
  if not a.is_posting then
    raise exception 'a grouping account takes no postings' using errcode = '22023';
  end if;
  if a.account_type <> v_type then
    raise exception 'role % books to a % account, not %', p_role, v_type, a.account_type
      using errcode = '22023';
  end if;
  select * into v from public.book_mappings
   where issuer_site_id = p_issuer_site_id and role = p_role and effective_from = p_effective_from
   for update;
  if v.id is null then
    if coalesce(p_expected_revision, -1) <> 0 then
      raise exception 'stale mapping' using errcode = '40001';
    end if;
    insert into public.book_mappings (workspace_id, issuer_site_id, role, account_id, effective_from)
    values (p_workspace_id, p_issuer_site_id, p_role, p_account_id, p_effective_from)
    returning * into v;
  else
    if coalesce(p_expected_revision, -1) <> v.revision then
      raise exception 'stale mapping: someone saved it since you read it' using errcode = '40001';
    end if;
    update public.book_mappings set account_id = p_account_id, revision = v.revision + 1
     where id = v.id returning * into v;
  end if;
  return jsonb_build_object(
    'id', v.id, 'workspace_id', v.workspace_id, 'issuer_site_id', v.issuer_site_id,
    'role', v.role, 'account_id', v.account_id,
    'effective_from', to_char(v.effective_from, 'YYYY-MM-DD'), 'revision', v.revision);
end;
$fn$;
revoke execute on function public.save_book_mapping(uuid, uuid, text, uuid, date, int) from public, anon;
grant execute on function public.save_book_mapping(uuid, uuid, text, uuid, date, int) to authenticated;

create or replace function public.save_book_profile(
  p_workspace_id uuid, p_issuer_site_id uuid, p_authority_mode text, p_external_system text,
  p_functional_currency text, p_fiscal_year_start_month int, p_fiscal_year_start_day int,
  p_accounting_basis text, p_effective_from date, p_expected_revision int
) returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v public.book_profiles;
begin
  if auth.uid() is null or public.mcp_is_delegated()
     or not public.has_permission(p_workspace_id, 'manageBilling') then
    raise exception 'only someone who manages billing sets the books' using errcode = '42501';
  end if;
  if not public.feature_operation_allowed(p_workspace_id, 'accountingBook', 'accept_new') then
    raise exception 'the accounting book is not switched on' using errcode = '42501';
  end if;
  if not exists (select 1 from public.sites s
                  where s.id = p_issuer_site_id and s.workspace_id = p_workspace_id) then
    raise exception 'the issuer is not a site of this workspace' using errcode = '42501';
  end if;
  if p_authority_mode is null or p_authority_mode not in ('pre_accounting', 'local_book', 'external_book') then
    raise exception 'unknown authority mode' using errcode = '22023';
  end if;
  if p_authority_mode = 'external_book' and btrim(coalesce(p_external_system, '')) = '' then
    raise exception 'an external book names the system that stays authoritative' using errcode = '22023';
  end if;
  if p_functional_currency is null or p_functional_currency !~ '^[A-Z]{3}$' then
    raise exception 'a currency is three capital letters' using errcode = '22023';
  end if;
  if p_accounting_basis is null or p_accounting_basis not in ('accrual', 'cash') then
    raise exception 'unknown accounting basis' using errcode = '22023';
  end if;
  -- A fiscal year starts on a day every year has: never 29 February.
  if p_fiscal_year_start_month is null or p_fiscal_year_start_day is null
     or p_fiscal_year_start_month not between 1 and 12 or p_fiscal_year_start_day < 1
     or p_fiscal_year_start_day > extract(day from (make_date(2026, p_fiscal_year_start_month, 1)
                                                    + interval '1 month - 1 day'))::int then
    raise exception 'a fiscal year starts on a day every year has' using errcode = '22023';
  end if;
  if p_effective_from is null then
    raise exception 'a book profile takes effect from a date' using errcode = '22023';
  end if;
  -- #1869 B: a local book cannot start before the roles it posts to are
  -- mapped for its first day.
  if p_authority_mode = 'local_book' and exists (
       select 1 from unnest(array['customers', 'revenue', 'bank']) r(role)
        where not exists (
          select 1 from public.book_mappings m
           where m.issuer_site_id = p_issuer_site_id and m.role = r.role
             and m.effective_from <= p_effective_from)) then
    raise exception 'map the customers, revenue and bank accounts before the book starts'
      using errcode = '22023';
  end if;

  select * into v from public.book_profiles
   where issuer_site_id = p_issuer_site_id and effective_from = p_effective_from
   for update;
  if v.id is null then
    if coalesce(p_expected_revision, -1) <> 0 then
      raise exception 'stale book profile: it was removed or never saved' using errcode = '40001';
    end if;
    insert into public.book_profiles (workspace_id, issuer_site_id, authority_mode, external_system,
        functional_currency, fiscal_year_start_month, fiscal_year_start_day, accounting_basis, effective_from)
    values (p_workspace_id, p_issuer_site_id, p_authority_mode, btrim(coalesce(p_external_system, '')),
        p_functional_currency, p_fiscal_year_start_month, p_fiscal_year_start_day, p_accounting_basis,
        p_effective_from)
    returning * into v;
  else
    if coalesce(p_expected_revision, -1) <> v.revision then
      raise exception 'stale book profile: someone saved it since you read it' using errcode = '40001';
    end if;
    update public.book_profiles
       set authority_mode = p_authority_mode, external_system = btrim(coalesce(p_external_system, '')),
           functional_currency = p_functional_currency,
           fiscal_year_start_month = p_fiscal_year_start_month,
           fiscal_year_start_day = p_fiscal_year_start_day,
           accounting_basis = p_accounting_basis, revision = v.revision + 1
     where id = v.id
     returning * into v;
  end if;
  return jsonb_build_object(
      'id', v.id, 'workspace_id', v.workspace_id, 'issuer_site_id', v.issuer_site_id,
      'authority_mode', v.authority_mode, 'external_system', v.external_system,
      'functional_currency', v.functional_currency,
      'fiscal_year_start_month', v.fiscal_year_start_month,
      'fiscal_year_start_day', v.fiscal_year_start_day,
      'accounting_basis', v.accounting_basis,
      'effective_from', to_char(v.effective_from, 'YYYY-MM-DD'),
      'revision', v.revision);
end;
$fn$;
revoke execute on function public.save_book_profile(uuid, uuid, text, text, text, int, int, text, date, int) from public, anon;
grant execute on function public.save_book_profile(uuid, uuid, text, text, text, int, int, text, date, int) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(338);
