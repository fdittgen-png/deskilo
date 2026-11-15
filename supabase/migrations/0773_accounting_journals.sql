-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0773 (#3470) -- the business's accounting journals: the code and label of
-- its sales, bank, purchases and miscellaneous journals, as its accountant's
-- software knows them. Every accounting export the app writes reads them;
-- '{}' keeps the country add-on's defaults. A value is whole or refused whole:
-- all four journals, each with a code and a label, no control character
-- (line break, tab) and no pipe in either, and no code used twice. It is
-- never cleaned into another journal. The owners write it, as they write the
-- business's other export setting (the VAT account), through
-- set_accounting_journals; the column's check holds the same rules for any
-- other write.

-- What is wrong with [p] (null: nothing): 'shape', 'code', 'label',
-- 'character' or 'duplicate', with the journal it is about.
create or replace function public.accounting_journals_problem(p jsonb)
returns jsonb language plpgsql immutable set search_path = public as $fn$
declare
  v_role text;
  v_entry jsonb;
  v_codes text[] := '{}';
  v_code text;
  v_label text;
begin
  if p is null or jsonb_typeof(p) <> 'object' then
    return jsonb_build_object('problem', 'shape');
  end if;
  if p = '{}'::jsonb then return null; end if;
  if (select array_agg(k order by k) from jsonb_object_keys(p) k)
     <> array['bank', 'misc', 'purchases', 'sales'] then
    return jsonb_build_object('problem', 'shape');
  end if;
  foreach v_role in array array['sales', 'bank', 'purchases', 'misc'] loop
    v_entry := p -> v_role;
    if jsonb_typeof(v_entry) <> 'object'
       or jsonb_typeof(v_entry -> 'code') is distinct from 'string'
       or jsonb_typeof(v_entry -> 'label') is distinct from 'string' then
      return jsonb_build_object('problem', 'shape', 'role', v_role);
    end if;
    v_code := v_entry ->> 'code';
    v_label := v_entry ->> 'label';
    if btrim(v_code) = '' then
      return jsonb_build_object('problem', 'code', 'role', v_role);
    end if;
    if btrim(v_label) = '' then
      return jsonb_build_object('problem', 'label', 'role', v_role);
    end if;
    if v_code ~ '[[:cntrl:]|]' or v_label ~ '[[:cntrl:]|]' then
      return jsonb_build_object('problem', 'character', 'role', v_role);
    end if;
    if v_code = any(v_codes) then
      return jsonb_build_object('problem', 'duplicate', 'role', v_role);
    end if;
    v_codes := v_codes || v_code;
  end loop;
  return null;
end;
$fn$;

alter table public.workspaces
  add column if not exists accounting_journals jsonb not null default '{}'::jsonb;
alter table public.workspaces
  drop constraint if exists workspaces_accounting_journals_whole;
alter table public.workspaces
  add constraint workspaces_accounting_journals_whole
  check (public.accounting_journals_problem(accounting_journals) is null);

create or replace function public.set_accounting_journals(p_workspace_id uuid, p_journals jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_problem jsonb;
  v jsonb;
begin
  if auth.uid() is null or public.mcp_is_delegated()
     or not public.is_owner_of(p_workspace_id) then
    raise exception 'only an owner sets the accounting journals' using errcode = '42501';
  end if;
  v_problem := public.accounting_journals_problem(coalesce(p_journals, '{}'::jsonb));
  if v_problem is not null then
    raise exception 'the accounting journals are not whole'
      using errcode = '22023', detail = v_problem::text;
  end if;
  update public.workspaces set accounting_journals = coalesce(p_journals, '{}'::jsonb)
   where id = p_workspace_id
  returning accounting_journals into v;
  if v is null then
    raise exception 'no such workspace' using errcode = '42501';
  end if;
  return v;
end;
$fn$;
revoke execute on function public.set_accounting_journals(uuid, jsonb) from public, anon;
grant execute on function public.set_accounting_journals(uuid, jsonb) to authenticated;
-- The check runs on every update of a workspace row, by whoever updates it.
revoke execute on function public.accounting_journals_problem(jsonb) from public, anon;
grant execute on function public.accounting_journals_problem(jsonb) to authenticated, service_role;

select public.set_deskilo_schema_version(773);
