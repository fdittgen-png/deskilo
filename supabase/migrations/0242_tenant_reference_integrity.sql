-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0242 (#1453) — a financial record and the record it points at belong to
-- the same workspace, at the write boundary.
--
-- Every child below already carried `workspace_id` and a foreign key on the
-- parent's id. Neither says the two workspaces agree: a writer that pairs
-- workspace A with workspace B's member, invoice, ledger row or credit
-- produced a row that only `reconcile_workspace` (0213) noticed, after the
-- fact. RLS does not help — a SECURITY DEFINER function or a privileged
-- writer is exactly what it does not see.
--
-- So each relation gains a COMPOSITE foreign key `(workspace_id, <ref>)` →
-- parent `(workspace_id, id)`, next to the existing one. It follows the
-- existing key's deletion rule; a nullable reference that the existing key
-- sets null uses `on delete set null (<ref>)`, so the child's workspace is
-- never nulled with it. MATCH SIMPLE leaves a null reference unchecked,
-- which is what an optional link means.
--
-- | child . column                          | parent          | on delete        |
-- |-----------------------------------------|-----------------|------------------|
-- | ledger_entries . member_id              | members         | restrict         |
-- | invoices . member_id                    | members         | restrict         |
-- | invoices . issuer_member_id             | members         | restrict         |
-- | invoices . replaces_invoice_id          | invoices        | restrict         |
-- | invoices . settled_by_invoice_id        | invoices        | restrict         |
-- | invoice_matches . invoice_id            | invoices        | cascade          |
-- | invoice_matches . payment_ledger_id     | ledger_entries  | restrict         |
-- | invoice_matches . credit_ledger_id      | ledger_entries  | set null (col)   |
-- | invoice_match_payments . invoice_id     | invoices        | cascade          |
-- | invoice_match_payments . payment_ledger_id | ledger_entries | cascade        |
-- | invoice_match_payments . credit_ledger_id  | ledger_entries | set null (col) |
-- | invoice_reminders . invoice_id          | invoices        | cascade          |
-- | invoice_transmissions . invoice_id      | invoices        | cascade          |
-- | payment_intents . member_id             | members         | cascade          |
-- | payment_intents . ledger_entry_id       | ledger_entries  | no action        |
-- | member_credits . member_id              | members         | cascade          |
-- | member_credits . product_id             | credit_products | set null (col)   |
-- | member_credits . ledger_entry_id        | ledger_entries  | set null (col)   |
-- | member_credit_uses . credit_id          | member_credits  | cascade          |
-- | member_credit_uses . reservation_id     | reservations    | cascade          |
-- | quota_extensions . member_id            | members         | cascade          |
-- | usage_records . member_id               | members         | cascade          |
--
-- Measured on the dev project before writing: no existing row violates any
-- of them, so each is added VALID. On an instance where one does, the
-- migration stops at that constraint with Postgres naming it — nothing is
-- reassigned or deleted to make history fit; `reconcile_workspace` names
-- the rows.

-- The parents' composite keys the children reference.
do $keys$
declare
  t text;
begin
  foreach t in array array['members', 'invoices', 'ledger_entries', 'credit_products',
                           'member_credits', 'reservations'] loop
    if not exists (select 1 from pg_constraint
                    where conname = t || '_workspace_id_id_key'
                      and conrelid = ('public.' || t)::regclass) then
      execute format('alter table public.%I add constraint %I unique (workspace_id, id)',
                     t, t || '_workspace_id_id_key');
    end if;
  end loop;
end $keys$;

create or replace function pg_temp.tenant_fk(
  p_child text, p_column text, p_parent text, p_on_delete text)
returns void
language plpgsql
as $f$
declare
  v_name text := left(p_child || '_' || p_column || '_same_workspace', 63);
begin
  if exists (select 1 from pg_constraint
              where conname = v_name and conrelid = ('public.' || p_child)::regclass) then
    return;
  end if;
  execute format(
    'alter table public.%I add constraint %I foreign key (workspace_id, %I) '
    'references public.%I (workspace_id, id) on delete %s',
    p_child, v_name, p_column, p_parent,
    case when p_on_delete = 'set null' then format('set null (%I)', p_column)
         else p_on_delete end);
end
$f$;

revoke execute on function pg_temp.tenant_fk(text, text, text, text) from public;

select pg_temp.tenant_fk('ledger_entries', 'member_id', 'members', 'restrict');
select pg_temp.tenant_fk('invoices', 'member_id', 'members', 'restrict');
select pg_temp.tenant_fk('invoices', 'issuer_member_id', 'members', 'restrict');
select pg_temp.tenant_fk('invoices', 'replaces_invoice_id', 'invoices', 'restrict');
select pg_temp.tenant_fk('invoices', 'settled_by_invoice_id', 'invoices', 'restrict');
select pg_temp.tenant_fk('invoice_matches', 'invoice_id', 'invoices', 'cascade');
select pg_temp.tenant_fk('invoice_matches', 'payment_ledger_id', 'ledger_entries', 'restrict');
select pg_temp.tenant_fk('invoice_matches', 'credit_ledger_id', 'ledger_entries', 'set null');
select pg_temp.tenant_fk('invoice_match_payments', 'invoice_id', 'invoices', 'cascade');
select pg_temp.tenant_fk('invoice_match_payments', 'payment_ledger_id', 'ledger_entries', 'cascade');
select pg_temp.tenant_fk('invoice_match_payments', 'credit_ledger_id', 'ledger_entries', 'set null');
select pg_temp.tenant_fk('invoice_reminders', 'invoice_id', 'invoices', 'cascade');
select pg_temp.tenant_fk('invoice_transmissions', 'invoice_id', 'invoices', 'cascade');
select pg_temp.tenant_fk('payment_intents', 'member_id', 'members', 'cascade');
select pg_temp.tenant_fk('payment_intents', 'ledger_entry_id', 'ledger_entries', 'no action');
select pg_temp.tenant_fk('member_credits', 'member_id', 'members', 'cascade');
select pg_temp.tenant_fk('member_credits', 'product_id', 'credit_products', 'set null');
select pg_temp.tenant_fk('member_credits', 'ledger_entry_id', 'ledger_entries', 'set null');
select pg_temp.tenant_fk('member_credit_uses', 'credit_id', 'member_credits', 'cascade');
select pg_temp.tenant_fk('member_credit_uses', 'reservation_id', 'reservations', 'cascade');
select pg_temp.tenant_fk('quota_extensions', 'member_id', 'members', 'cascade');
select pg_temp.tenant_fk('usage_records', 'member_id', 'members', 'cascade');

select public.set_deskilo_schema_version(242);
