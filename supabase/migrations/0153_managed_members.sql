-- SPDX-License-Identifier: 0BSD
-- 0153 — #887: managed profiles — a member an admin runs until the
-- person claims it with a bound invitation.
--
-- An association onboards people before they have the app: the admin
-- creates the member, books and invoices for them, manages their
-- subscription. Until now a member could not exist without an account
-- (members.user_id NOT NULL). From here a member may be MANAGED: no
-- user, the identity (the PersonalInfo wire keys of 0152) held in
-- managed_identity, created by an admin. The handover is a personal
-- invitation BOUND to that member: when the person — with an account
-- they may have created a minute ago — redeems the code,
-- join_workspace sets user_id, copies the identity into the EMPTY
-- fields of their own profile (the user owns the data from then on),
-- clears the managed copy, and raises the ordinary member_join
-- validation. Reservations, invoices, subscriptions and documents were
-- always keyed by the member id, so nothing moves.

-- 1. A member may exist without an account — but never without an admin.
alter table public.members alter column user_id drop not null;
alter table public.members
  add column if not exists managed_identity jsonb not null default '{}'::jsonb,
  add column if not exists managed_by uuid references auth.users(id) on delete set null,
  add column if not exists claimed_at timestamptz;
alter table public.members drop constraint if exists members_managed_has_admin;
alter table public.members add constraint members_managed_has_admin
  check (user_id is not null or managed_by is not null);

-- 2. An invitation may be bound to the member it hands over; one open
--    handover per member at a time.
alter table public.invitations
  add column if not exists member_id uuid references public.members(id) on delete cascade;
create unique index if not exists invitations_open_handover_idx
  on public.invitations (member_id) where member_id is not null and redeemed_at is null;

-- 3. Only the PersonalInfo keys survive, trimmed, blanks dropped.
create or replace function public.managed_identity_clean(p jsonb) returns jsonb
language sql immutable as $$
  select coalesce((
    select jsonb_object_agg(key, left(btrim(value), 254))
      from jsonb_each_text(coalesce(p, '{}'::jsonb))
     where key in ('first_name','last_name','company','street','postal_code',
                   'city','country_code','phone','email','vat_id','legal_id')
       and btrim(value) <> ''), '{}'::jsonb);
$$;

-- 4. The admin creates the member — active at once: the admin books
--    and invoices for them from the first day.
create or replace function public.create_managed_member(p_workspace_id uuid, p_identity jsonb)
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
  if coalesce(v_identity->>'first_name', '') = ''
     and coalesce(v_identity->>'last_name', '') = ''
     and coalesce(v_identity->>'company', '') = '' then
    raise exception 'a managed profile needs a name';
  end if;
  insert into public.members
    (workspace_id, user_id, is_admin, status, managed_identity, managed_by)
  values (p_workspace_id, null, false, 'active', v_identity, auth.uid())
  returning id into v_id;
  return v_id;
end;
$$;

-- 5. The admin edits the identity — only while nobody owns it.
create or replace function public.update_managed_identity(p_member_id uuid, p_identity jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare v_member public.members;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  select * into v_member from public.members where id = p_member_id;
  if not found then raise exception 'member not found'; end if;
  if v_member.user_id is not null then raise exception 'profile already claimed'; end if;
  if not public.is_admin_of(v_member.workspace_id) then
    raise exception 'only admins may edit managed profiles';
  end if;
  update public.members
     set managed_identity = public.managed_identity_clean(p_identity)
   where id = p_member_id;
end;
$$;

-- 6. create_invitation gains the member it hands over. A new defaulted
--    parameter would leave the old overload beside it and make every
--    four-argument call ambiguous, so the old one goes first.
drop function if exists public.create_invitation(uuid, boolean, text, text);
create function public.create_invitation(
  p_workspace_id uuid, p_is_admin boolean,
  p_first_name text default '', p_last_name text default '',
  p_member_id uuid default null
) returns text language plpgsql security definer set search_path = public as $$
declare
  v_code text;
  v_member public.members;
  v_first text := left(coalesce(p_first_name, ''), 120);
  v_last text := left(coalesce(p_last_name, ''), 120);
begin
  if p_is_admin then
    if not public.is_owner_of(p_workspace_id) then
      raise exception 'only owners may invite admins';
    end if;
  elsif not public.is_admin_of(p_workspace_id) then
    raise exception 'only admins may invite members';
  end if;
  if p_member_id is not null then
    select * into v_member from public.members
     where id = p_member_id and workspace_id = p_workspace_id;
    if not found then raise exception 'member not found'; end if;
    if v_member.user_id is not null then raise exception 'profile already claimed'; end if;
    if p_is_admin then raise exception 'a handover grants membership, not admin'; end if;
    if v_first = '' then v_first := left(coalesce(v_member.managed_identity->>'first_name', ''), 120); end if;
    if v_last = '' then v_last := left(coalesce(v_member.managed_identity->>'last_name', ''), 120); end if;
    -- a fresh handover retires the previous open one: one code is live.
    delete from public.invitations where member_id = p_member_id and redeemed_at is null;
  end if;
  insert into public.invitations
    (workspace_id, is_admin, invited_first_name, invited_last_name, created_by, member_id)
  values (p_workspace_id, p_is_admin, v_first, v_last, auth.uid(), p_member_id)
  returning code into v_code;
  return v_code;
end;
$$;

-- 7. The admin takes a handover back while it is unredeemed.
create or replace function public.revoke_handover(p_member_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_member public.members;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  select * into v_member from public.members where id = p_member_id;
  if not found then raise exception 'member not found'; end if;
  if not public.is_admin_of(v_member.workspace_id) then
    raise exception 'only admins may revoke a handover';
  end if;
  delete from public.invitations where member_id = p_member_id and redeemed_at is null;
end;
$$;

-- 8. join_workspace: a bound code claims the member instead of
--    inserting a new one — the identity becomes the person's, the
--    membership goes through the ordinary member_join validation.
create or replace function public.join_workspace(p_invite_code text)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  ws_id uuid;
  v_code text;
  v_admin boolean := false;
  v_member_id uuid;
  v_bound uuid;
  v_target public.members;
  v_mi jsonb;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  v_code := upper(trim(p_invite_code));
  select id into ws_id from public.workspaces where invite_code = v_code;
  if ws_id is null then
    update public.invitations
       set redeemed_by = auth.uid(), redeemed_at = now()
     where code = v_code
       and redeemed_at is null
       and expires_at > now()
    returning workspace_id, is_admin, member_id into ws_id, v_admin, v_bound;
  end if;
  if ws_id is null then raise exception 'invalid invite code'; end if;

  if v_bound is not null then
    select * into v_target from public.members where id = v_bound for update;
    if not found then raise exception 'invalid invite code'; end if;
    if v_target.user_id is not null then raise exception 'profile already claimed'; end if;
    if exists (select 1 from public.members
                where workspace_id = ws_id and user_id = auth.uid()) then
      raise exception 'already a member of this workspace';
    end if;
    -- #887 — the person owns the data: it lands in the EMPTY fields of
    -- their profile; what they already wrote about themselves wins.
    v_mi := v_target.managed_identity;
    update public.profiles p set
      first_name   = case when coalesce(p.first_name, '') = ''   then coalesce(v_mi->>'first_name', '')   else p.first_name end,
      last_name    = case when coalesce(p.last_name, '') = ''    then coalesce(v_mi->>'last_name', '')    else p.last_name end,
      company      = case when coalesce(p.company, '') = ''      then coalesce(v_mi->>'company', '')      else p.company end,
      street       = case when coalesce(p.street, '') = ''       then coalesce(v_mi->>'street', '')       else p.street end,
      postal_code  = case when coalesce(p.postal_code, '') = ''  then coalesce(v_mi->>'postal_code', '')  else p.postal_code end,
      city         = case when coalesce(p.city, '') = ''         then coalesce(v_mi->>'city', '')         else p.city end,
      country_code = case when coalesce(p.country_code, '') = '' then coalesce(v_mi->>'country_code', '') else p.country_code end,
      phone        = case when coalesce(p.phone, '') = ''        then coalesce(v_mi->>'phone', '')        else p.phone end,
      email        = case when coalesce(p.email, '') = ''        then coalesce(v_mi->>'email', '')        else p.email end,
      vat_id       = case when coalesce(p.vat_id, '') = ''       then coalesce(v_mi->>'vat_id', '')       else p.vat_id end,
      legal_id     = case when coalesce(p.legal_id, '') = ''     then coalesce(v_mi->>'legal_id', '')     else p.legal_id end
    where p.id = auth.uid();
    update public.members
       set user_id = auth.uid(), claimed_at = now(),
           managed_identity = '{}'::jsonb, status = 'pending'
     where id = v_bound
    returning id into v_member_id;
  else
    insert into public.members (workspace_id, user_id, is_admin, status)
    values (ws_id, auth.uid(), v_admin, 'pending')
    on conflict (workspace_id, user_id) do update
      set status = case when public.members.status = 'exited'
                        then 'pending' else public.members.status end,
          is_admin = public.members.is_admin or excluded.is_admin
    returning id into v_member_id;
  end if;

  if exists (select 1 from public.members
              where id = v_member_id and status = 'pending')
     and not exists (
       select 1 from public.events
       where subject_member_id = v_member_id
         and type = 'member_join' and status = 'pending') then
    insert into public.events
      (workspace_id, type, action, actor_member_id, subject_member_id,
       payload, status)
    values (ws_id, 'member_join', 'submitted', v_member_id, v_member_id,
            jsonb_build_object('as_admin', v_admin, 'claimed', v_bound is not null),
            'pending');
  end if;
  return ws_id;
end;
$$;

-- 9. create_invoice names a managed member from managed_identity: the
--    profile row (as jsonb) or the managed copy, poured into ONE
--    profiles-shaped record so profile_full_name / profile_postal_block
--    (0152) serve both. Patched at the 0152 anchor; a silent no-op
--    would invoice a managed member as nobody.
do $patch$
declare
  v_def text;
  v_anchor text;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'create_invoice';
  if v_def is null then raise exception '0153: create_invoice not found'; end if;
  v_anchor := E'    from public.profiles pr where pr.id = v_subject.user_id;\n';
  if position(v_anchor in v_def) = 0 then raise exception '0153: anchor missing'; end if;
  v_def := replace(v_def, v_anchor,
       E'    from jsonb_populate_record(null::public.profiles,\n'
    || E'           coalesce((select to_jsonb(p) from public.profiles p where p.id = v_subject.user_id),\n'
    || E'                    v_subject.managed_identity)) pr;\n');
  execute v_def;
end
$patch$;
