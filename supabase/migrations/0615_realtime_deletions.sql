-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (one table, published and filtered per workspace; one statement-level
-- AFTER DELETE trigger on each workspace-scoped table the app renders)
--
-- 0615 (#3101, PERF-4 of the performance audit) -- a delete reaches only
-- its own workspace. Supabase Realtime cannot filter DELETE events (the
-- old row carries only its key), so the app bound an UNFILTERED delete
-- listener on 19 tables: a delete in any tenant woke every connected
-- client. Now each deleting statement leaves one row per (workspace,
-- table) in realtime_deletions, which clients subscribe to as an INSERT
-- filtered by workspace_id, the same shape as every other scoped table.
-- The rows are a signal, not a record: each deletion statement removes
-- signals older than ten minutes.

create table public.realtime_deletions (
  id bigint generated always as identity primary key,
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  table_name text not null,
  signalled_at timestamptz not null default now()
);
select public.ensure_system_columns('realtime_deletions');
create index realtime_deletions_signalled_idx on public.realtime_deletions (signalled_at);

alter table public.realtime_deletions enable row level security;
create policy realtime_deletions_select on public.realtime_deletions
  for select to authenticated using (public.is_member_of(workspace_id));
create policy mcp_delegated_deny on public.realtime_deletions as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
-- written only by the trigger below
revoke insert, update, delete on public.realtime_deletions from anon, authenticated;

create or replace function public.realtime_deletion_signal()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  insert into public.realtime_deletions (workspace_id, table_name)
  select distinct o.workspace_id, tg_table_name
    from old_rows o
   where o.workspace_id is not null
     and exists (select 1 from public.workspaces w where w.id = o.workspace_id);
  delete from public.realtime_deletions where signalled_at < now() - interval '10 minutes';
  return null;
end;
$fn$;
revoke execute on function public.realtime_deletion_signal() from public, anon, authenticated;

do $t$
declare
  v_table text;
begin
  foreach v_table in array array[
    'reservations', 'levels', 'offices', 'desks', 'seats', 'plan_images',
    'events', 'event_decisions', 'ledger_entries', 'payment_intents', 'invoices',
    'services', 'accessories', 'seat_accessories', 'closure_days',
    'quota_extensions', 'fee_bands', 'packages', 'validation_policies'
  ] loop
    execute format('drop trigger if exists realtime_deletion_signal on public.%I', v_table);
    execute format(
      'create trigger realtime_deletion_signal after delete on public.%I '
      'referencing old table as old_rows for each statement '
      'execute function public.realtime_deletion_signal()', v_table);
  end loop;
end
$t$;

alter publication supabase_realtime add table public.realtime_deletions;

select public.set_deskilo_schema_version(615);
