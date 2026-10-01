-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: destructive
--
-- 0321 (#1912) — an answer linked to a member is personal data, whatever
-- the question's switch says.
--
-- 0249 erased a leaving member's answers only where the owner had marked
-- the question `personal_data`. A shirt size stored against `member_id`
-- still says something about one identifiable person, so a label cannot
-- take it out of erasure. From here on:
--
--   * classification is a property of the ROW: every
--     `workspace_field_values` row carries a `member_id`, so every answer
--     is personal (`field_answer_is_personal`). The definition's
--     `personal_data` switch stays in the schema and in templates, but it
--     no longer exempts anything from export or erasure;
--   * keeping an answer after erasure needs a documented retention hold,
--     separate from the classification: a statutory basis in words and a
--     period in days (`workspace_field_retention_holds`, set by an owner
--     through `set_workspace_field_retention`). A held answer is stamped
--     with the basis and an expiry, is readable only by whoever holds
--     `viewPersonalData`, and is purged when the hold expires;
--   * the upgrade removes the answers that 0249 left behind for members
--     who already left, unless a hold covers them. No answer is copied
--     into an audit table on the way: the rows are gone, not moved.
--
-- Backup: this migration deletes the surviving answers of exited members
-- (the legacy rows of questions marked not personal). Take a database
-- backup first if an operator still needs those values for a lawful
-- purpose, and define a retention hold for that question before applying.

-- ── the classification, in one place ─────────────────────────────────
create or replace function public.field_answer_is_personal(p_member_id uuid)
returns boolean
language sql immutable set search_path = public as $fn$
  -- An answer is stored against a membership. A membership is a person,
  -- so the answer is about that person; the question's own switch does
  -- not enter into it.
  select p_member_id is not null;
$fn$;

revoke execute on function public.field_answer_is_personal(uuid) from public, anon;
grant execute on function public.field_answer_is_personal(uuid) to authenticated;

-- ── the retention exception, separate from the classification ────────
create table if not exists public.workspace_field_retention_holds (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  definition_id uuid not null
    references public.workspace_field_definitions(id) on delete cascade,
  basis text not null check (char_length(btrim(basis)) between 10 and 500),
  retain_days int not null check (retain_days between 1 and 3650),
  created_at timestamptz not null default now()
);
select public.ensure_system_columns('workspace_field_retention_holds');
create unique index if not exists workspace_field_retention_holds_once
  on public.workspace_field_retention_holds (definition_id);

alter table public.workspace_field_retention_holds enable row level security;
revoke all on table public.workspace_field_retention_holds from public, anon, authenticated;
grant select on table public.workspace_field_retention_holds to authenticated;
drop policy if exists mcp_delegated_deny on public.workspace_field_retention_holds;
create policy mcp_delegated_deny on public.workspace_field_retention_holds
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
drop policy if exists workspace_field_retention_holds_select
  on public.workspace_field_retention_holds;
create policy workspace_field_retention_holds_select
  on public.workspace_field_retention_holds
  for select to authenticated
  using (public.is_owner_of(workspace_id)
         or public.has_permission(workspace_id, 'viewPersonalData'));

-- A held answer says why it is still here and until when; both or
-- neither.
alter table public.workspace_field_values
  add column if not exists held_until timestamptz,
  add column if not exists hold_basis text;
alter table public.workspace_field_values
  drop constraint if exists workspace_field_values_hold_pair;
alter table public.workspace_field_values
  add constraint workspace_field_values_hold_pair
  check ((held_until is null) = (hold_basis is null));

-- ── an owner documents a hold ────────────────────────────────────────
-- The definition is looked up INSIDE the caller's workspace by key, so a
-- definition of another workspace cannot be named, and the workspace id
-- written on the hold is the definition's own. A null basis lifts the
-- hold for future erasures; answers already held keep their stamp.
create or replace function public.set_workspace_field_retention(
  p_workspace_id uuid, p_key text, p_basis text, p_retain_days int
) returns void
language plpgsql security definer set search_path = public as $fn$
declare
  v_definition uuid;
begin
  if auth.uid() is null or not public.is_owner_of(p_workspace_id) then
    raise exception 'only an owner documents a retention hold';
  end if;
  select d.id into v_definition
    from public.workspace_field_definitions d
   where d.workspace_id = p_workspace_id and d.key = p_key;
  if v_definition is null then
    raise exception 'no question % in this workspace', p_key;
  end if;
  if p_basis is null then
    delete from public.workspace_field_retention_holds
     where definition_id = v_definition;
    return;
  end if;
  if char_length(btrim(p_basis)) not between 10 and 500 then
    raise exception 'a retention hold names its legal basis in 10 to 500 characters';
  end if;
  if p_retain_days is null or p_retain_days not between 1 and 3650 then
    raise exception 'a retention hold lasts between 1 and 3650 days';
  end if;
  insert into public.workspace_field_retention_holds
    (workspace_id, definition_id, basis, retain_days)
  values (p_workspace_id, v_definition, btrim(p_basis), p_retain_days)
  on conflict (definition_id) do update
    set basis = excluded.basis, retain_days = excluded.retain_days;
end $fn$;

revoke execute on function public.set_workspace_field_retention(uuid, text, text, int)
  from public, anon;
grant execute on function public.set_workspace_field_retention(uuid, text, text, int)
  to authenticated;

-- ── a held answer is restricted ──────────────────────────────────────
-- The definition's visibility no longer applies to it: an answer kept
-- for a statutory reason is read by whoever holds `viewPersonalData`,
-- and by nobody else — not every member, and not the person who left.
drop policy if exists workspace_field_values_select
  on public.workspace_field_values;
create policy workspace_field_values_select on public.workspace_field_values
  for select to authenticated
  using (case when held_until is null
              then public.member_field_readable(member_id, definition_id)
              else public.has_permission(workspace_id, 'viewPersonalData')
         end);

drop policy if exists workspace_field_value_options_select
  on public.workspace_field_value_options;
create policy workspace_field_value_options_select
  on public.workspace_field_value_options
  for select to authenticated using (exists (
    select 1 from public.workspace_field_values v
     where v.id = value_id
       and case when v.held_until is null
                then public.member_field_readable(v.member_id, v.definition_id)
                else public.has_permission(v.workspace_id, 'viewPersonalData')
           end));

-- ── erasure: every answer goes, unless a documented hold keeps it ────
create or replace function public.erase_my_membership(p_workspace_id uuid)
returns void language plpgsql security definer
set search_path = public as $$
declare
  v_me public.members;
begin
  v_me := public.my_active_member(p_workspace_id);
  if v_me.is_owner then
    raise exception 'an owner must hand the workspace over before leaving';
  end if;
  update public.reservations set status = 'cancelled'
   where member_id = v_me.id and status in ('reserved', 'checked_in');
  delete from public.member_notes where from_member_id = v_me.id;
  -- #1912 — the answers this member gave to the workspace's own
  -- questions. Every one is personal (`field_answer_is_personal`); only
  -- a documented retention hold keeps one, stamped with its basis and
  -- expiry. The junction first: its rows point at the values about to
  -- go.
  update public.workspace_field_values v
     set held_until = now() + make_interval(days => h.retain_days),
         hold_basis = h.basis
    from public.workspace_field_retention_holds h
   where h.definition_id = v.definition_id
     and h.workspace_id = v.workspace_id
     and v.member_id = v_me.id
     and v.held_until is null;
  delete from public.workspace_field_value_options vo
   using public.workspace_field_values v
   where vo.value_id = v.id and v.member_id = v_me.id
     and public.field_answer_is_personal(v.member_id)
     and v.held_until is null;
  delete from public.workspace_field_values v
   where v.member_id = v_me.id
     and public.field_answer_is_personal(v.member_id)
     and v.held_until is null;
  update public.members set status = 'exited', is_admin = false
   where id = v_me.id;
  if not exists (select 1 from public.members
                  where user_id = v_me.user_id and status = 'active') then
    update public.profiles
       set display_name = '', whatsapp = '', status_text = '', address = '',
           vat_id = '', avatar_path = null
     where id = v_me.user_id;
  end if;
end;
$$;

revoke execute on function public.erase_my_membership(uuid) from public, anon;
grant execute on function public.erase_my_membership(uuid) to authenticated;

-- ── an expired hold ends ─────────────────────────────────────────────
create or replace function public.purge_expired_field_answer_holds()
returns int
language plpgsql security definer set search_path = public as $fn$
declare
  v_count int;
begin
  delete from public.workspace_field_values
   where held_until is not null and held_until <= now();
  get diagnostics v_count = row_count;
  return v_count;
end $fn$;

revoke execute on function public.purge_expired_field_answer_holds()
  from public, anon, authenticated;

do $cron$
begin
  create extension if not exists pg_cron;
  perform cron.unschedule('deskilo-field-answer-holds')
    where exists (select 1 from cron.job where jobname = 'deskilo-field-answer-holds');
  perform cron.schedule('deskilo-field-answer-holds', '40 3 * * *',
    $job$select public.purge_expired_field_answer_holds()$job$);
exception when others then
  raise notice 'pg_cron unavailable (%): an operator runs purge_expired_field_answer_holds() instead', sqlerrm;
end
$cron$;

-- ── the upgrade: what 0249 left behind ───────────────────────────────
-- Members who already left kept their answers to questions marked not
-- personal. They go now, junctions with them (on delete cascade), unless
-- a hold documented before this upgrade covers the question.
update public.workspace_field_values v
   set held_until = now() + make_interval(days => h.retain_days),
       hold_basis = h.basis
  from public.workspace_field_retention_holds h, public.members m
 where h.definition_id = v.definition_id
   and m.id = v.member_id and m.status = 'exited'
   and v.held_until is null;
delete from public.workspace_field_values v
 using public.members m
 where m.id = v.member_id and m.status = 'exited'
   and v.held_until is null;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(321);
