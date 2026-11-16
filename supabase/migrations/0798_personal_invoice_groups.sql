-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- #3556 (part 2) — a person's own groups of invoices ("2026 taxes", "To
-- reimburse"), across businesses, installations and currencies. A group is
-- the person's filing on their personal home: it never changes an invoice
-- and no business sees it. It names each invoice by reference (the
-- installation-qualified workspace, `<installation>:<workspace>`, as Me's
-- workspace references do, and the invoice's id) and keeps the invoice's
-- number as last seen, so an invoice that cannot be read later is still
-- named. It stores no amount: amounts are read from the invoice's own host
-- each time, with that host's state. Nothing here is deleted on another
-- host, and an invoice deleted or out of reach there leaves its reference.
--
-- Read and written by the person directly, under row security: their own
-- rows only, never through a delegated assistant session (mcp_delegated_deny)
-- and only in a native personal session (personal_native_session). Deleting
-- the account deletes the groups (on delete cascade); the personal export
-- carries them.

create table if not exists public.personal_invoice_groups (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null
    constraint personal_invoice_groups_name_shape
      check (name = btrim(name) and char_length(name) between 1 and 80),
  constraint personal_invoice_groups_owner unique (id, user_id)
);
select public.ensure_system_columns('personal_invoice_groups');
create unique index if not exists personal_invoice_groups_name_once
  on public.personal_invoice_groups (user_id, lower(name));

create table if not exists public.personal_invoice_group_items (
  group_id uuid not null,
  user_id uuid not null default auth.uid(),
  network_id text not null
    constraint personal_invoice_group_items_network_id
      check (network_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'),
  invoice_id uuid not null,
  -- the invoice's number as it was last seen; a name, never an amount
  label text not null default ''
    constraint personal_invoice_group_items_label check (char_length(label) <= 80),
  primary key (group_id, network_id, invoice_id),
  -- an item belongs to its group's owner, and goes with the group
  constraint personal_invoice_group_items_group
    foreign key (group_id, user_id)
    references public.personal_invoice_groups (id, user_id) on delete cascade
);
select public.ensure_system_columns('personal_invoice_group_items');
create index if not exists personal_invoice_group_items_user
  on public.personal_invoice_group_items (user_id);

alter table public.personal_invoice_groups enable row level security;
alter table public.personal_invoice_group_items enable row level security;
-- Exactly the commands a policy allows: a reference is filed or removed,
-- never changed.
revoke all on public.personal_invoice_groups from anon, authenticated;
revoke all on public.personal_invoice_group_items from anon, authenticated;
grant select, insert, update, delete on public.personal_invoice_groups to authenticated;
grant select, insert, delete on public.personal_invoice_group_items to authenticated;

drop policy if exists personal_invoice_groups_own_select on public.personal_invoice_groups;
create policy personal_invoice_groups_own_select on public.personal_invoice_groups
  for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists personal_invoice_groups_own_write on public.personal_invoice_groups;
create policy personal_invoice_groups_own_write on public.personal_invoice_groups
  for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists personal_invoice_groups_own_update on public.personal_invoice_groups;
create policy personal_invoice_groups_own_update on public.personal_invoice_groups
  for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
drop policy if exists personal_invoice_groups_own_delete on public.personal_invoice_groups;
create policy personal_invoice_groups_own_delete on public.personal_invoice_groups
  for delete to authenticated using (user_id = (select auth.uid()));
drop policy if exists mcp_delegated_deny on public.personal_invoice_groups;
create policy mcp_delegated_deny on public.personal_invoice_groups as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
drop policy if exists personal_native_session on public.personal_invoice_groups;
create policy personal_native_session on public.personal_invoice_groups as restrictive for all to public
  using ((select public.personal_native_session()))
  with check ((select public.personal_native_session()));

drop policy if exists personal_invoice_group_items_own_select on public.personal_invoice_group_items;
create policy personal_invoice_group_items_own_select on public.personal_invoice_group_items
  for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists personal_invoice_group_items_own_write on public.personal_invoice_group_items;
create policy personal_invoice_group_items_own_write on public.personal_invoice_group_items
  for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists personal_invoice_group_items_own_delete on public.personal_invoice_group_items;
create policy personal_invoice_group_items_own_delete on public.personal_invoice_group_items
  for delete to authenticated using (user_id = (select auth.uid()));
drop policy if exists mcp_delegated_deny on public.personal_invoice_group_items;
create policy mcp_delegated_deny on public.personal_invoice_group_items as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
drop policy if exists personal_native_session on public.personal_invoice_group_items;
create policy personal_native_session on public.personal_invoice_group_items as restrictive for all to public
  using ((select public.personal_native_session()))
  with check ((select public.personal_native_session()));

-- The personal export carries the groups, appended to the whole export with
-- || (jsonb_build_object takes at most 100 arguments, #3123), as 0670 did.
create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
declare
  v_pattern text;
  v_out text;
begin
  if position(p_old in p_def) > 0 then
    return replace(p_def, p_old, p_new);
  end if;
  v_pattern := regexp_replace(btrim(p_old, E' \t\n'), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
  v_pattern := regexp_replace(v_pattern, '\s+', '\\s*', 'g');
  v_out := regexp_replace(p_def, v_pattern, replace(btrim(p_new, E' \t\n'), '\', '\\'), 'g');
  return case when v_out = p_def then null else v_out end;
end
$f$;

revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $migration$
declare
  v_def text;
begin
  select pg_get_functiondef('public.export_my_personal_data_v1()'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$'restored only by the operator; ask the controller'))));$a$,
    $a$'restored only by the operator; ask the controller'))))
    || jsonb_build_object('invoice_groups', (select coalesce(jsonb_agg(jsonb_build_object(
         'name', g.name,
         'created', g.created_datetime,
         'invoices', (select coalesce(jsonb_agg(jsonb_build_object(
                         'workspace_network_id', i.network_id,
                         'invoice_id', i.invoice_id,
                         'number', i.label,
                         'added', i.created_datetime) order by i.created_datetime), '[]'::jsonb)
                        from public.personal_invoice_group_items i
                       where i.group_id = g.id and i.user_id = v_me))
         order by g.name), '[]'::jsonb)
       from public.personal_invoice_groups g where g.user_id = v_me));$a$);
  if v_def is null then raise exception '0798: export_my_personal_data_v1 coverage anchor missing'; end if;
  execute v_def;
end
$migration$;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(798);
