-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0517 (#2365) -- the posting roles of the book chart, as the posting
-- contract names them: a base and an optional qualifier.
--
--   * bases: customers, suppliers, revenue, bank, vat_output, vat_input,
--     vat_pending, expenses, write_off, cash_discount, clearing, fees;
--   * qualifier: `revenue:<rate group>`, `vat_output:<rate group>`,
--     `vat_input:<rate group>` (the tax-reference rate groups: standard,
--     reduced, super_reduced, zero, exempt, ...), `clearing:<provider>`,
--     `fees:<provider>`. A posting resolves a qualified role first and falls
--     back to its base; a base with no mapping blocks with the role named.
--   * `book_role_account_type`: the account type each base books to, the one
--     place `save_book_mapping` reads it (it was a literal list there, 0338
--     and 0408).
--
-- Every existing mapping is a bare base and stays valid; nothing is moved.

alter table public.book_mappings drop constraint if exists book_mappings_role_check;
alter table public.book_mappings add constraint book_mappings_role_check check (role ~
  '^(customers|suppliers|revenue|bank|vat_output|vat_input|vat_pending|expenses|write_off|cash_discount|clearing|fees)(:[A-Za-z0-9_.-]{1,40})?$');

-- The account type a role books to, or null for an unknown role.
create or replace function public.book_role_account_type(p_role text)
returns text language sql immutable set search_path = public as $fn$
  select case when p_role ~ '^[a-z_]+(:[A-Za-z0-9_.-]{1,40})?$' then
    case split_part(p_role, ':', 1)
      when 'customers' then 'asset'
      when 'bank' then 'asset'
      when 'vat_input' then 'asset'
      when 'clearing' then 'asset'
      when 'suppliers' then 'liability'
      when 'vat_output' then 'liability'
      when 'vat_pending' then 'liability'
      when 'revenue' then 'income'
      when 'expenses' then 'expense'
      when 'write_off' then 'expense'
      when 'cash_discount' then 'expense'
      when 'fees' then 'expense'
    end
  end;
$fn$;
revoke execute on function public.book_role_account_type(text) from public, anon;
grant execute on function public.book_role_account_type(text) to authenticated;

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
  v_type := public.book_role_account_type(p_role);
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

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(517);
