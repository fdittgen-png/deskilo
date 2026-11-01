-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (three function bodies patched at one asserted anchor each; three
-- restrictive write policies; one column trigger on workspaces)
--
-- 0640 (#2521, step 3 of #2519's F2) -- a functionality that is switched off
-- is refused by the server, not only hidden by the app. The client gates of
-- /money/repartition-wizard, /payment-methods and /billing merged in #3038;
-- these are the writes behind those screens that still went through with the
-- feature off:
--
--   expenseRepartition  distribute_expense, set_repartition_rule (definer RPCs)
--   moneyTab            replace_fee_bands (definer RPC); direct writes to
--                       fee_bands and packages; the workspaces columns
--                       payment_instructions, subscription_levels and
--                       subscription_vat_rate_id
--   carnets             direct writes to credit_products (the carnets editor
--                       is shown on that key, as sell_credit already gates it)
--
-- expenseRepartition, not expenseRepartitionWizard: the one-expense sheet of
-- the invoices screen calls the same RPC and is shown on the parent key.
-- feature_effective follows the parents, so a switched-off ancestor
-- (invoicing, moneyTab) refuses as well.
--
-- Refusal: errcode 55000 ("functionality switched off"), the code
-- create_subscription_level (0637) already uses.
--
-- Who is NOT caught: server-side writers running as the table owner (the
-- template import, workspace creation's seeding, the assistant's commands,
-- which gate themselves, 0637/0638/0639). The policies are RESTRICTIVE and
-- cover insert, update and delete only, so reading a configuration stays
-- possible after the feature is switched off. The workspaces trigger fires
-- only for a direct update by a signed-in user, the owner included: the
-- delegated-column guard (0361) lets the owner straight through, so a branch
-- inside it would not have been enough.

-- ── 1. the three RPCs ────────────────────────────────────────────────
create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
begin
  -- An anchor names one place: it occurs exactly once, or nothing is patched.
  if (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old) <> 1 then
    return null;
  end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public, anon, authenticated;

do $migration$
declare
  v_def text;
  v_new text;
begin
  -- distribute_expense: right after the issuing member is resolved.
  select pg_get_functiondef('public.distribute_expense(uuid, text, integer, text, text, jsonb, uuid)'::regprocedure)
    into v_def;
  if position('feature_effective(p_workspace_id, ''expenseRepartition'')' in v_def) = 0 then
    v_new := pg_temp.anchor_replace(v_def,
      $a$  v_me := public.issuing_member(p_workspace_id);$a$,
      $a$  v_me := public.issuing_member(p_workspace_id);
  if not public.feature_effective(p_workspace_id, 'expenseRepartition') then
    raise exception 'expense repartition is switched off in this space' using errcode = '55000';
  end if;$a$);
    if v_new is null then
      raise exception '0640: distribute_expense anchor missing or not unique';
    end if;
    execute v_new;
  end if;

  -- set_repartition_rule: right after its permission check.
  select pg_get_functiondef('public.set_repartition_rule(uuid, jsonb)'::regprocedure) into v_def;
  if position('feature_effective(p_workspace_id, ''expenseRepartition'')' in v_def) = 0 then
    v_new := pg_temp.anchor_replace(v_def,
      $a$raise exception 'admins only'; end if;$a$,
      $a$raise exception 'admins only'; end if;
  if not public.feature_effective(p_workspace_id, 'expenseRepartition') then
    raise exception 'expense repartition is switched off in this space' using errcode = '55000';
  end if;$a$);
    if v_new is null then
      raise exception '0640: set_repartition_rule anchor missing or not unique';
    end if;
    execute v_new;
  end if;

  -- replace_fee_bands: right after its permission check.
  select pg_get_functiondef('public.replace_fee_bands(uuid, jsonb)'::regprocedure) into v_def;
  if position('feature_effective(p_workspace_id, ''moneyTab'')' in v_def) = 0 then
    v_new := pg_temp.anchor_replace(v_def,
      $a$    raise exception 'only the owner may edit fee bands';
  end if;$a$,
      $a$    raise exception 'only the owner may edit fee bands';
  end if;
  if not public.feature_effective(p_workspace_id, 'moneyTab') then
    raise exception 'money is switched off in this space' using errcode = '55000';
  end if;$a$);
    if v_new is null then
      raise exception '0640: replace_fee_bands anchor missing or not unique';
    end if;
    execute v_new;
  end if;
end
$migration$;

-- ── 2. direct writes: restrictive policies (insert, update, delete) ──
-- A restrictive policy is ANDed with the permissive ones, so it narrows the
-- owner and the delegated policies alike without restating them.
drop policy if exists fee_bands_feature_insert on public.fee_bands;
drop policy if exists fee_bands_feature_update on public.fee_bands;
drop policy if exists fee_bands_feature_delete on public.fee_bands;
create policy fee_bands_feature_insert on public.fee_bands as restrictive for insert to authenticated
  with check (public.feature_effective(workspace_id, 'moneyTab'));
create policy fee_bands_feature_update on public.fee_bands as restrictive for update to authenticated
  using (public.feature_effective(workspace_id, 'moneyTab'))
  with check (public.feature_effective(workspace_id, 'moneyTab'));
create policy fee_bands_feature_delete on public.fee_bands as restrictive for delete to authenticated
  using (public.feature_effective(workspace_id, 'moneyTab'));

drop policy if exists packages_feature_insert on public.packages;
drop policy if exists packages_feature_update on public.packages;
drop policy if exists packages_feature_delete on public.packages;
create policy packages_feature_insert on public.packages as restrictive for insert to authenticated
  with check (public.feature_effective(workspace_id, 'moneyTab'));
create policy packages_feature_update on public.packages as restrictive for update to authenticated
  using (public.feature_effective(workspace_id, 'moneyTab'))
  with check (public.feature_effective(workspace_id, 'moneyTab'));
create policy packages_feature_delete on public.packages as restrictive for delete to authenticated
  using (public.feature_effective(workspace_id, 'moneyTab'));

drop policy if exists credit_products_feature_insert on public.credit_products;
drop policy if exists credit_products_feature_update on public.credit_products;
drop policy if exists credit_products_feature_delete on public.credit_products;
create policy credit_products_feature_insert on public.credit_products as restrictive for insert to authenticated
  with check (public.feature_effective(workspace_id, 'carnets'));
create policy credit_products_feature_update on public.credit_products as restrictive for update to authenticated
  using (public.feature_effective(workspace_id, 'carnets'))
  with check (public.feature_effective(workspace_id, 'carnets'));
create policy credit_products_feature_delete on public.credit_products as restrictive for delete to authenticated
  using (public.feature_effective(workspace_id, 'carnets'));

-- ── 3. the money columns of workspaces ───────────────────────────────
create or replace function public.workspaces_money_feature_guard()
returns trigger language plpgsql set search_path = public as $fn$
begin
  -- Only a direct update by a signed-in user: definer commands (the import,
  -- the assistant's operations) run as the table owner and gate themselves.
  if current_user <> 'authenticated' then
    return new;
  end if;
  if (new.payment_instructions is distinct from old.payment_instructions
      or new.subscription_levels is distinct from old.subscription_levels
      or new.subscription_vat_rate_id is distinct from old.subscription_vat_rate_id)
     and not public.feature_effective(new.id, 'moneyTab') then
    raise exception 'money is switched off in this space' using errcode = '55000';
  end if;
  return new;
end
$fn$;
revoke execute on function public.workspaces_money_feature_guard() from public, anon, authenticated;

drop trigger if exists workspaces_money_feature_guard on public.workspaces;
create trigger workspaces_money_feature_guard
  before update of payment_instructions, subscription_levels, subscription_vat_rate_id
  on public.workspaces
  for each row execute function public.workspaces_money_feature_guard();

select public.set_deskilo_schema_version(640);
