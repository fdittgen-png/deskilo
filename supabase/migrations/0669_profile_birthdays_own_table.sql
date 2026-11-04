-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- backup: the values move, they are not lost: every birthday stored on
-- profiles by 0668 is copied into profile_birthdays before the column goes.
--
-- #3278 (reviewer finding on #3296): 0668 kept the birthday on public.profiles,
-- but profiles_select (0352: own row, or profile_row_readable) lets a co-member
-- who only issues invoices read the WHOLE row, birthday included, directly or
-- through Realtime; the projection's narrower birthday group did not protect
-- that path. The birthday now lives in its own table, read by its person and
-- by a co-member who holds viewPersonalData or managePrivacy in a workspace
-- they share, and by nobody else. The projection, the export and the erasure
-- read and clear it there. The table is not published to Realtime.

create table if not exists public.profile_birthdays (
  user_id uuid primary key references auth.users(id) on delete cascade,
  birthday date not null
    constraint profile_birthdays_plausible
      check (birthday >= date '1900-01-01' and birthday <= current_date)
);
select public.ensure_system_columns('profile_birthdays');

-- Whether the caller may read [p_subject]'s birthday as a co-member: the right
-- in a workspace both are active members of (the same rule as the projection's
-- birthday group, 0668).
create or replace function public.profile_birthday_readable(p_subject uuid)
returns boolean language sql stable security definer set search_path = public as $fn$
  select exists (
    select 1
      from public.members me
      join public.members them
        on them.workspace_id = me.workspace_id and them.user_id = p_subject
       and them.status = 'active'
     where me.user_id = auth.uid() and me.status = 'active'
       and (public.has_permission(me.workspace_id, 'viewPersonalData')
            or public.has_permission(me.workspace_id, 'managePrivacy')));
$fn$;
revoke execute on function public.profile_birthday_readable(uuid) from public, anon;
grant execute on function public.profile_birthday_readable(uuid) to authenticated;

alter table public.profile_birthdays enable row level security;
revoke all on public.profile_birthdays from anon;
grant select, insert, update, delete on public.profile_birthdays to authenticated;

drop policy if exists profile_birthdays_select on public.profile_birthdays;
create policy profile_birthdays_select on public.profile_birthdays
  for select to authenticated
  using (user_id = (select auth.uid()) or public.profile_birthday_readable(user_id));
drop policy if exists profile_birthdays_own_write on public.profile_birthdays;
create policy profile_birthdays_own_write on public.profile_birthdays
  for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists profile_birthdays_own_update on public.profile_birthdays;
create policy profile_birthdays_own_update on public.profile_birthdays
  for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
drop policy if exists profile_birthdays_own_delete on public.profile_birthdays;
create policy profile_birthdays_own_delete on public.profile_birthdays
  for delete to authenticated using (user_id = (select auth.uid()));
drop policy if exists mcp_delegated_deny on public.profile_birthdays;
create policy mcp_delegated_deny on public.profile_birthdays as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
drop policy if exists personal_native_session on public.profile_birthdays;
create policy personal_native_session on public.profile_birthdays as restrictive for all to public
  using ((select public.personal_native_session()))
  with check ((select public.personal_native_session()));

-- The values move over, then the column goes.
insert into public.profile_birthdays (user_id, birthday)
select p.id, p.birthday
  from public.profiles p
 where p.birthday is not null
   and exists (select 1 from auth.users u where u.id = p.id)
on conflict (user_id) do update set birthday = excluded.birthday;

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
  -- the projection's birthday group reads the new table
  select pg_get_functiondef('public.member_profile_projection(uuid,text[])'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$jsonb_build_object('birthday', p.birthday)$a$,
    $a$jsonb_build_object('birthday',
           (select b.birthday from public.profile_birthdays b where b.user_id = p.id))$a$);
  if v_def is null then raise exception '0669: member_profile_projection anchor missing'; end if;
  execute v_def;

  -- the export carries it, since to_jsonb(profile) no longer does
  select pg_get_functiondef('public.export_my_data(uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$jsonb_build_object('presence', (select to_jsonb(pr) from public.presence pr where pr.user_id = v_me.user_id))$a$,
    $a$jsonb_build_object('presence', (select to_jsonb(pr) from public.presence pr where pr.user_id = v_me.user_id))
      || jsonb_build_object('birthday', (select b.birthday from public.profile_birthdays b where b.user_id = v_me.user_id))$a$);
  if v_def is null then raise exception '0669: export_my_data anchor missing'; end if;
  execute v_def;

  -- the erasure of the last membership removes the row instead of a column
  select pg_get_functiondef('public.erase_my_membership(uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$vat_id = '', avatar_path = null, birthday = null,$a$,
    $a$vat_id = '', avatar_path = null,$a$);
  if v_def is null then raise exception '0669: erase_my_membership column anchor missing'; end if;
  v_def := pg_temp.anchor_replace(v_def,
    $a$phone = '', email = '', legal_id = ''
     where id = v_me.user_id;$a$,
    $a$phone = '', email = '', legal_id = ''
     where id = v_me.user_id;
    delete from public.profile_birthdays where user_id = v_me.user_id;$a$);
  if v_def is null then raise exception '0669: erase_my_membership delete anchor missing'; end if;
  execute v_def;
end
$migration$;

alter table public.profiles drop constraint if exists profiles_birthday_plausible;
alter table public.profiles drop column if exists birthday;

select public.set_deskilo_schema_version(669);
