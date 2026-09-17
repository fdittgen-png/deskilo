-- SPDX-License-Identifier: 0BSD
-- risk: additive
--
-- 0243 (#1453, second checkpoint) — the relations that are not money: who
-- booked, who acted on an event and about whom, who wrote a note, who
-- holds a badge. Same pattern and same reasoning as 0242: a composite
-- foreign key `(workspace_id, <ref>)` → parent `(workspace_id, id)` next to
-- the existing key, following its deletion rule (`set null (<ref>)` for a
-- link the existing key releases).
--
-- | child . column | parent | on delete |
-- |---|---|---|
-- | reservations . member_id | members | restrict |
-- | events . actor_member_id | members | restrict |
-- | events . subject_member_id | members | restrict |
-- | member_badges . member_id | members | cascade |
-- | invitations . member_id | members | cascade |
-- | member_notes . from_member_id | members | cascade |
-- | member_notes . to_member_id | members | cascade |
-- | conversations . created_by | members | cascade |
-- | data_access_log . actor_member_id | members | cascade |
-- | data_access_log . subject_member_id | members | cascade |
-- | price_negotiations . member_id | members | cascade |
-- | price_negotiations . proposed_by | members | set null |
-- | expense_schedules . member_id | members | cascade |
-- | expense_occurrences . member_id | members | cascade |
-- | expense_occurrences . schedule_id | expense_schedules | cascade |
-- | expense_repartitions . created_by | members | set null |
-- | managed_identities . member_id | members | cascade |
-- | reservation_requests . member_id | members | cascade |
--
-- Measured on the dev project before writing: no existing row violates any
-- of them. Members and reservations already carry their `(workspace_id, id)`
-- key from 0242; expense schedules gain theirs here.

do $keys$
begin
  if not exists (select 1 from pg_constraint
                  where conname = 'expense_schedules_workspace_id_id_key'
                    and conrelid = 'public.expense_schedules'::regclass) then
    alter table public.expense_schedules
      add constraint expense_schedules_workspace_id_id_key unique (workspace_id, id);
  end if;
  if not exists (select 1 from pg_constraint
                  where conname = 'members_workspace_id_id_key'
                    and conrelid = 'public.members'::regclass) then
    alter table public.members add constraint members_workspace_id_id_key unique (workspace_id, id);
  end if;
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

select pg_temp.tenant_fk('reservations', 'member_id', 'members', 'restrict');
select pg_temp.tenant_fk('events', 'actor_member_id', 'members', 'restrict');
select pg_temp.tenant_fk('events', 'subject_member_id', 'members', 'restrict');
select pg_temp.tenant_fk('member_badges', 'member_id', 'members', 'cascade');
select pg_temp.tenant_fk('invitations', 'member_id', 'members', 'cascade');
select pg_temp.tenant_fk('member_notes', 'from_member_id', 'members', 'cascade');
select pg_temp.tenant_fk('member_notes', 'to_member_id', 'members', 'cascade');
select pg_temp.tenant_fk('conversations', 'created_by', 'members', 'cascade');
select pg_temp.tenant_fk('data_access_log', 'actor_member_id', 'members', 'cascade');
select pg_temp.tenant_fk('data_access_log', 'subject_member_id', 'members', 'cascade');
select pg_temp.tenant_fk('price_negotiations', 'member_id', 'members', 'cascade');
select pg_temp.tenant_fk('price_negotiations', 'proposed_by', 'members', 'set null');
select pg_temp.tenant_fk('expense_schedules', 'member_id', 'members', 'cascade');
select pg_temp.tenant_fk('expense_occurrences', 'member_id', 'members', 'cascade');
select pg_temp.tenant_fk('expense_occurrences', 'schedule_id', 'expense_schedules', 'cascade');
select pg_temp.tenant_fk('expense_repartitions', 'created_by', 'members', 'set null');
select pg_temp.tenant_fk('managed_identities', 'member_id', 'members', 'cascade');
select pg_temp.tenant_fk('reservation_requests', 'member_id', 'members', 'cascade');

select public.set_deskilo_schema_version(243);
