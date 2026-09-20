-- SPDX-License-Identifier: AGPL-3.0-or-later
-- 0212 — #1229: the ledger stops rewriting its own history.
--
-- The A+ analysis proposed `Σ debits = Σ credits` as the financial
-- invariant. **That invariant cannot be written against this schema**,
-- and saying why is half the value of this migration.
--
-- `ledger_entries` is one row per movement: a `kind` of 'charge' or
-- 'credit', a positive `amount_cents`, and no pairing column, no journal
-- id, no link from a charge to the credit that offsets it. It is a
-- running member account, which is the right shape for a coworking
-- statement and is not double-entry. There is nothing for the sums to
-- balance against.
--
-- What this ledger CAN carry is the invariant it was always assumed to
-- have and never had:
--
--   a posted amount never changes, and a row leaves only by the one
--   route that was always meant to remove it.
--
-- The client could never write it — there is only a `ledger_select`
-- policy, so RLS refuses every client INSERT, UPDATE and DELETE. What
-- was unguarded is the SERVER: seven functions insert, and two delete.
--
-- The two deleters are both legitimate and both narrow:
--
--   release_invoice_payment  a payment match awaiting validation books a
--                            PROVISIONAL credit; rejecting or expiring
--                            the request takes it back. The credit is
--                            recognisable while it is provisional —
--                            invoice_matches / invoice_match_payments
--                            still point at it — and stops being
--                            deletable the moment the match is gone.
--
--   reset_workspace          the development affordance that empties a
--                            workspace. It announces itself.
--
-- So the rule below is not "nothing may be deleted"; it is "only a
-- provisional credit may be deleted, and only while it is provisional".
-- A settled payment, a subscription charge, an expense share: none of
-- them can be removed by anything, including a future function written
-- by somebody who did not read this file.
--
-- ## Why a trigger and not a `post_ledger_entry()` funnel
--
-- #1229 suggested funnelling the seven writers through one function so
-- the invariant has one place to live. A funnel is a convention: the
-- eighth writer is one `insert into public.ledger_entries` away from
-- bypassing it, and nothing fails when they do. A trigger is not
-- bypassable from inside the database at all. The invariant belongs to
-- the table.

create or replace function public.ledger_entries_append_only()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  o jsonb;
  n jsonb;
begin
  if tg_op = 'UPDATE' then
    -- The six technical columns (#992) are bookkeeping ABOUT the row,
    -- not the money in it, so a touch trigger may move them.
    o := to_jsonb(old) - public.system_column_names();
    n := to_jsonb(new) - public.system_column_names();
    if o = n then return new; end if;
    raise exception 'a ledger entry is never edited: post a new one';
  end if;

  -- DELETE.
  if coalesce(current_setting('deskilo.ledger_reset', true), '') = tg_relid::text then
    return old;
  end if;
  if old.kind = 'credit' and old.category = 'payment' and (
       exists (select 1 from public.invoice_matches m
                where m.credit_ledger_id = old.id)
    or exists (select 1 from public.invoice_match_payments p
                where p.credit_ledger_id = old.id)) then
    return old;
  end if;
  raise exception
    'a ledger entry is never deleted: only a payment credit still awaiting '
    'validation may be released';
end;
$fn$;
revoke execute on function public.ledger_entries_append_only() from public, anon, authenticated;

drop trigger if exists ledger_entries_no_rewrite on public.ledger_entries;
create trigger ledger_entries_no_rewrite
before update or delete on public.ledger_entries
for each row execute function public.ledger_entries_append_only();

-- reset_workspace says who it is. The setting is transaction-local and
-- carries the table's own oid, so it cannot be left switched on and
-- cannot be aimed at another table.
create or replace function public.reset_workspace(p_workspace_id uuid)
returns void language plpgsql security definer set search_path = public as $fn$
begin
  if not public.has_permission(p_workspace_id, 'manageConfiguration') then
    raise exception 'only owners may reset the workspace';
  end if;

  delete from public.event_decisions d
    using public.events e
    where d.event_id = e.id and e.workspace_id = p_workspace_id;
  delete from public.events where workspace_id = p_workspace_id;

  -- #1229 — the one place the append-only rule is deliberately stood
  -- down, for the one operation whose whole purpose is to empty the
  -- workspace. `true` makes it local to this transaction.
  perform set_config('deskilo.ledger_reset',
                     'public.ledger_entries'::regclass::oid::text, true);
  delete from public.ledger_entries where workspace_id = p_workspace_id;
  perform set_config('deskilo.ledger_reset', '', true);

  delete from public.quota_extensions where workspace_id = p_workspace_id;
  delete from public.reservations where workspace_id = p_workspace_id;

  delete from public.plan_images where workspace_id = p_workspace_id;
  delete from public.seat_accessories where workspace_id = p_workspace_id;
  delete from public.seats where workspace_id = p_workspace_id;
  delete from public.desks where workspace_id = p_workspace_id;
  delete from public.offices where workspace_id = p_workspace_id;
  delete from public.levels where workspace_id = p_workspace_id;
end;
$fn$;
revoke execute on function public.reset_workspace(uuid) from public, anon;
