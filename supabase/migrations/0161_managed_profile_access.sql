-- SPDX-License-Identifier: 0BSD
-- 0161 — #914/#915: who may administer a managed profile, and what the
-- person sees when they take it over.
--
-- An admin-managed profile (#887) holds a real person's identity — name,
-- address, telephone, e-mail, tax identifiers — before that person has
-- an account. Two things were wrong with where it lived.
--
-- FIRST, `members_select` (0002) is row-agnostic: every member of the
-- workspace could read the row, so a co-member could read contact and
-- tax details of someone who never agreed to show them. The interface
-- only ever showed them to admins, which is why nobody noticed. Row-level
-- security cannot fix that in place — the same row must stay readable by
-- everyone, because the members list needs the name. So the identity
-- moves to its own table behind a predicate, and the row keeps only the
-- name, which is what a co-member legitimately sees.
--
-- SECOND, ANY admin could read, edit and hand over any managed profile.
-- Each profile now carries its own rule: roles, named people, or both.
-- '{}' is the rule nobody has narrowed — owner and admin, exactly what
-- #887 shipped — so nothing changes until someone narrows it.
--
-- The rule gates the personal data and the handover. Booking a seat and
-- issuing an invoice stay ordinary workspace bookkeeping: gating those
-- would block everyday work in ways nobody could diagnose.
--
-- The workspace OWNER may always CHANGE a rule — a profile must never
-- become unadministrable when its only named admin leaves — but is only
-- an administrator of the person's data when the rule says so. Governance
-- of the rule and access to the data are separate powers, and every
-- change of either is written to the access log the person reads once
-- they claim the profile.

-- 1. The rule, and the public projection of the name.
alter table public.members
  add column if not exists managed_access jsonb not null default '{}'::jsonb,
  add column if not exists managed_name text not null default '';

-- 2. The identity leaves the widely-readable row.
create table if not exists public.managed_identities (
  member_id uuid primary key references public.members(id) on delete cascade,
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  identity jsonb not null default '{}'::jsonb
);
create index if not exists managed_identities_workspace_idx
  on public.managed_identities (workspace_id);
alter table public.managed_identities enable row level security;

-- 3. The addressee line, derived — company first (0159), else the person.
create or replace function public.managed_identity_name(p jsonb)
returns text language sql immutable as $$
  select coalesce(
    nullif(btrim(coalesce(p->>'company', '')), ''),
    nullif(case
      when btrim(coalesce(p->>'first_name','')) = ''
        then upper(btrim(coalesce(p->>'last_name','')))
      when btrim(coalesce(p->>'last_name','')) = ''
        then btrim(coalesce(p->>'first_name',''))
      else btrim(coalesce(p->>'first_name','')) || ' ' ||
           upper(btrim(coalesce(p->>'last_name','')))
    end, ''),
    '');
$$;

-- 4. Carry what exists across, then empty the exposed column.
-- What a CO-MEMBER may legitimately see: who this is. The members
-- list, the plan and every reservation row need a name, so the name
-- stays on the widely-readable row. The contact and tax fields do not
-- belong there and move behind the rule.
--
-- Keeping the public half in place also means a client that has not
-- been updated yet still shows managed members by name instead of
-- blanking them: the migration removes the exposure without breaking
-- the app in the window before the new build ships.
create or replace function public.managed_identity_public(p jsonb)
returns jsonb language sql immutable as $$
  select coalesce((
    select jsonb_object_agg(key, value)
      from jsonb_each_text(coalesce(p, '{}'::jsonb))
     where key in ('courtesy','first_name','last_name','company','country_code')
       and btrim(value) <> ''), '{}'::jsonb);
$$;

insert into public.managed_identities (member_id, workspace_id, identity)
select m.id, m.workspace_id, m.managed_identity
  from public.members m
 where m.user_id is null and m.managed_identity <> '{}'::jsonb
on conflict (member_id) do nothing;
update public.members m
   set managed_name = public.managed_identity_name(m.managed_identity)
 where m.user_id is null and m.managed_name = '';
update public.members m
   set managed_identity = public.managed_identity_public(m.managed_identity)
 where m.managed_identity <> '{}'::jsonb;

-- 5. WHO may administer one profile.
--
-- '{}' means the rule nobody has narrowed: owner and admin, which is
-- exactly what #887 shipped. A rule names roles, member ids, or both.
-- The workspace OWNER may always CHANGE a rule (a profile must never
-- become unadministrable when its only named admin leaves) but is only
-- an administrator of the person's data when the rule says so.
create or replace function public.can_manage_managed_profile(p_member_id uuid)
returns boolean language sql stable security definer
set search_path = public as $$
  select exists (
    select 1
      from public.members target
      join public.members me
        on me.workspace_id = target.workspace_id
       and me.user_id = auth.uid()
       and me.status = 'active'
     where target.id = p_member_id
       and (
         case when coalesce(target.managed_access->'roles', 'null'::jsonb) = 'null'::jsonb
              then (me.is_owner or me.co_owner = 'active' or me.is_admin)
              else ((target.managed_access->'roles' ? 'owner'
                     and (me.is_owner or me.co_owner = 'active'))
                 or (target.managed_access->'roles' ? 'admin' and me.is_admin))
         end
         or coalesce(target.managed_access->'members', '[]'::jsonb) ? me.id::text
       )
  );
$$;
revoke execute on function public.can_manage_managed_profile(uuid) from public, anon;
grant execute on function public.can_manage_managed_profile(uuid) to authenticated;

-- 6. Reading the identity is an ACCESS: gated, and written down.
drop policy if exists managed_identities_select on public.managed_identities;
create policy managed_identities_select on public.managed_identities
  for select using (
    public.can_manage_managed_profile(member_id)
    or exists (select 1 from public.members m
                where m.id = member_id and m.user_id = auth.uid())
  );
-- No insert/update/delete policy: the definer functions below own writes.

create or replace function public.managed_identity_of(p_member_id uuid)
returns jsonb language plpgsql volatile security definer
set search_path = public as $$
declare
  v_member public.members;
  v_me public.members;
  v_identity jsonb;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  select * into v_member from public.members where id = p_member_id;
  if not found then raise exception 'member not found'; end if;
  if not public.can_manage_managed_profile(p_member_id) then
    raise exception 'not allowed to read this profile';
  end if;
  select identity into v_identity
    from public.managed_identities where member_id = p_member_id;
  select * into v_me from public.members
   where workspace_id = v_member.workspace_id and user_id = auth.uid();
  if v_me.id is not null and v_me.id <> p_member_id then
    insert into public.data_access_log
      (workspace_id, actor_member_id, subject_member_id, category)
    values (v_member.workspace_id, v_me.id, p_member_id, 'profile');
  end if;
  return coalesce(v_identity, '{}'::jsonb);
end;
$$;
revoke execute on function public.managed_identity_of(uuid) from public, anon;
grant execute on function public.managed_identity_of(uuid) to authenticated;

-- 7. The log learns the word.
alter table public.data_access_log drop constraint if exists data_access_log_category_check;
alter table public.data_access_log add constraint data_access_log_category_check
  check (category in ('finances', 'messages', 'export', 'negotiations', 'profile'));

-- 8. Creating, editing and handing over all obey the rule.
-- The 2-arg overload is dropped rather than kept beside it: two
-- candidates make a two-argument call ambiguous, and PostgREST
-- resolves the named-parameter call against this one, so a client
-- that does not send p_access still lands on the default rule.
drop function if exists public.create_managed_member(uuid, jsonb);
create or replace function public.create_managed_member(
  p_workspace_id uuid, p_identity jsonb, p_access jsonb default '{}'::jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_identity jsonb;
  v_id uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.is_admin_of(p_workspace_id) then
    raise exception 'only admins may add managed profiles';
  end if;
  v_identity := public.managed_identity_clean(p_identity);
  if public.managed_identity_name(v_identity) = '' then
    raise exception 'a managed profile needs a name';
  end if;
  insert into public.members
    (workspace_id, user_id, is_admin, status, managed_identity, managed_by,
     managed_access, managed_name)
  values (p_workspace_id, null, false, 'active',
          public.managed_identity_public(v_identity), auth.uid(),
          coalesce(p_access, '{}'::jsonb),
          public.managed_identity_name(v_identity))
  returning id into v_id;
  insert into public.managed_identities (member_id, workspace_id, identity)
  values (v_id, p_workspace_id, v_identity);
  insert into public.data_access_log
    (workspace_id, actor_member_id, subject_member_id, category)
  select p_workspace_id, me.id, v_id, 'profile' from public.members me
   where me.workspace_id = p_workspace_id and me.user_id = auth.uid();
  return v_id;
end;
$$;

create or replace function public.update_managed_identity(p_member_id uuid, p_identity jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_member public.members;
  v_identity jsonb;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  select * into v_member from public.members where id = p_member_id;
  if not found then raise exception 'member not found'; end if;
  if v_member.user_id is not null then raise exception 'profile already claimed'; end if;
  if not public.can_manage_managed_profile(p_member_id) then
    raise exception 'not allowed to manage this profile';
  end if;
  v_identity := public.managed_identity_clean(p_identity);
  insert into public.managed_identities (member_id, workspace_id, identity)
  values (p_member_id, v_member.workspace_id, v_identity)
  on conflict (member_id) do update set identity = excluded.identity;
  update public.members
     set managed_name = public.managed_identity_name(v_identity),
         managed_identity = public.managed_identity_public(v_identity)
   where id = p_member_id;
  insert into public.data_access_log
    (workspace_id, actor_member_id, subject_member_id, category)
  select v_member.workspace_id, me.id, p_member_id, 'profile'
    from public.members me
   where me.workspace_id = v_member.workspace_id and me.user_id = auth.uid();
end;
$$;

-- 9. The rule itself: changed by anyone the rule already allows, and
--    ALWAYS by the workspace owner — otherwise a profile whose only
--    named admin leaves can never be administered again.
create or replace function public.set_managed_access(p_member_id uuid, p_access jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare v_member public.members;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  select * into v_member from public.members where id = p_member_id;
  if not found then raise exception 'member not found'; end if;
  if v_member.user_id is not null then raise exception 'profile already claimed'; end if;
  if not (public.is_owner_of(v_member.workspace_id)
          or public.can_manage_managed_profile(p_member_id)) then
    raise exception 'not allowed to manage this profile';
  end if;
  update public.members set managed_access = coalesce(p_access, '{}'::jsonb)
   where id = p_member_id;
  insert into public.data_access_log
    (workspace_id, actor_member_id, subject_member_id, category)
  select v_member.workspace_id, me.id, p_member_id, 'profile'
    from public.members me
   where me.workspace_id = v_member.workspace_id and me.user_id = auth.uid();
end;
$$;
revoke execute on function public.set_managed_access(uuid, jsonb) from public, anon;
grant execute on function public.set_managed_access(uuid, jsonb) to authenticated;

-- 10. The handover is administering the profile too.
create or replace function public.revoke_handover(p_member_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_member public.members;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  select * into v_member from public.members where id = p_member_id;
  if not found then raise exception 'member not found'; end if;
  if not public.can_manage_managed_profile(p_member_id) then
    raise exception 'not allowed to manage this profile';
  end if;
  delete from public.invitations
   where member_id = p_member_id and redeemed_at is null;
end;
$$;

-- 11. create_invitation: the handover obeys the rule, and reads the
--     name from where the identity now lives.
do $patch$
declare v_def text;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'create_invitation';
  if v_def is null then raise exception '0161: create_invitation not found'; end if;
  if position(E'    if p_is_admin then raise exception ''a handover grants membership, not admin''; end if;\n' in v_def) = 0
    then raise exception '0161: invitation anchor A missing'; end if;
  v_def := replace(v_def,
    E'    if p_is_admin then raise exception ''a handover grants membership, not admin''; end if;\n',
    E'    if p_is_admin then raise exception ''a handover grants membership, not admin''; end if;\n'
 || E'    if not public.can_manage_managed_profile(p_member_id) then\n'
 || E'      raise exception ''not allowed to manage this profile'';\n'
 || E'    end if;\n');
  if position(E'v_member.managed_identity->>''first_name''' in v_def) = 0
    then raise exception '0161: invitation anchor B missing'; end if;
  v_def := replace(v_def, E'v_member.managed_identity->>''first_name''',
    E'(select mi.identity->>''first_name'' from public.managed_identities mi where mi.member_id = p_member_id)');
  v_def := replace(v_def, E'v_member.managed_identity->>''last_name''',
    E'(select mi.identity->>''last_name'' from public.managed_identities mi where mi.member_id = p_member_id)');
  execute v_def;
end
$patch$;

-- 12. join_workspace: the claim copies the identity from its new home,
--     then removes it — the person owns the data from that moment.
do $patch$
declare v_def text;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'join_workspace';
  if v_def is null then raise exception '0161: join_workspace not found'; end if;
  if position(E'    v_mi := v_target.managed_identity;\n' in v_def) = 0
    then raise exception '0161: join anchor A missing'; end if;
  v_def := replace(v_def, E'    v_mi := v_target.managed_identity;\n',
       E'    select coalesce(mi.identity, ''{}''::jsonb) into v_mi\n'
    || E'      from public.managed_identities mi where mi.member_id = v_bound;\n'
    || E'    v_mi := coalesce(v_mi, ''{}''::jsonb);\n'
    || E'    delete from public.managed_identities where member_id = v_bound;\n');
  if position(E'           managed_identity = ''{}''::jsonb, status = ''pending''\n' in v_def) = 0
    then raise exception '0161: join anchor B missing'; end if;
  v_def := replace(v_def,
    E'           managed_identity = ''{}''::jsonb, status = ''pending''\n',
    E'           managed_identity = ''{}''::jsonb, managed_name = '''',\n'
 || E'           managed_access = ''{}''::jsonb, status = ''pending''\n');
  execute v_def;
end
$patch$;

-- 13. create_invoice names a managed member from the identity's new
--     home. It is SECURITY DEFINER and the caller already passed the
--     invoicing gate: issuing is workspace bookkeeping, not a reading
--     of the person's contact details.
do $patch$
declare v_def text;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'create_invoice';
  if v_def is null then raise exception '0161: create_invoice not found'; end if;
  if position(E'                    v_subject.managed_identity)) pr;\n' in v_def) = 0
    then raise exception '0161: invoice anchor missing'; end if;
  v_def := replace(v_def, E'                    v_subject.managed_identity)) pr;\n',
    E'                    coalesce((select mi.identity from public.managed_identities mi\n'
 || E'                               where mi.member_id = v_subject.id), ''{}''::jsonb))) pr;\n');
  execute v_def;
end
$patch$;

-- 14. "Who can see this" learns to answer for the profile too.
do $patch$
declare
  v_def text;
  v_anchor text := E'    ''reservations'', ''all_members'',\n';
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'who_can_access_me';
  if v_def is null then raise exception '0161: who_can_access_me missing'; end if;
  if position(v_anchor in v_def) = 0 then raise exception '0161: access anchor missing'; end if;
  v_def := replace(v_def, v_anchor,
       E'    ''profile'', (\n'
    || E'      select coalesce(jsonb_agg(m.id), ''[]''::jsonb) from public.members m\n'
    || E'       where m.workspace_id = p_workspace_id and m.status = ''active''\n'
    || E'         and m.id <> v_me.id\n'
    || E'         and public.can_manage_managed_profile(v_me.id)\n'
    || E'         and (case when coalesce((select t.managed_access->''roles'' from public.members t where t.id = v_me.id), ''null''::jsonb) = ''null''::jsonb\n'
    || E'                   then (m.is_owner or m.co_owner = ''active'' or m.is_admin)\n'
    || E'                   else true end)\n'
    || E'    ),\n'
    || v_anchor);
  execute v_def;
end
$patch$;
