-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0318 (#1829) -- the instance owner is visible, and can delegate.
--
-- Some decisions are about the whole installation, not one workspace: this
-- database is shared by every workspace on it. Someone must answer for it,
-- and everyone on it should be able to see who.
--
--   * The INSTANCE OWNER is the account that operates the deployment: the
--     platform owner of 0166 (`platform_admins`). Nothing changes for that
--     role: it keeps the cross-workspace overview and is the only one that
--     delegates.
--   * A DELEGATE is an existing account (confirmed e-mail) the owner names.
--     A delegate may run the installation-wide setup steps (#1827) and is
--     NOT a platform owner: no overview of other workspaces, and they can
--     delegate to nobody.
--   * `is_instance_operator()` is the one check those steps use: owner or
--     active delegate, on a native session (a delegated assistant token is
--     never an operator).
--   * `instance_responsibles()` tells every signed-in person who is
--     responsible: name and e-mail of the owner(s) and the delegates.
--   * A NEW instance has nobody. Its creator's e-mail is recorded as a
--     pending claim by the operator's own tooling; only a confirmed-email
--     account matching it can claim ownership, and only while no owner
--     exists.
--
-- Every change is written to the append-only `database_authority_audit`.
-- No client may write the two tables: they change only through the
-- functions below.

create table if not exists public.instance_delegates (
  user_id uuid primary key references auth.users (id) on delete cascade,
  status text not null default 'active' check (status in ('active', 'withdrawn')),
  granted_by uuid references auth.users (id) on delete set null,
  granted_at timestamptz not null default now(),
  withdrawn_at timestamptz,
  check ((status = 'withdrawn') = (withdrawn_at is not null))
);
select public.ensure_system_columns('instance_delegates');
alter table public.instance_delegates enable row level security;
revoke all on table public.instance_delegates from anon, authenticated;
drop policy if exists mcp_delegated_deny on public.instance_delegates;
create policy mcp_delegated_deny on public.instance_delegates as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

create table if not exists public.instance_owner_claims (
  email text primary key check (email = lower(email) and email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  created_at timestamptz not null default now()
);
select public.ensure_system_columns('instance_owner_claims');
alter table public.instance_owner_claims enable row level security;
revoke all on table public.instance_owner_claims from anon, authenticated;
drop policy if exists mcp_delegated_deny on public.instance_owner_claims;
create policy mcp_delegated_deny on public.instance_owner_claims as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- The operator's own tooling records who created a new instance. Not
-- callable by any client.
create or replace function public.operator_record_instance_owner_claim(p_email text)
returns void language plpgsql volatile security definer set search_path = public as $fn$
begin
  insert into public.instance_owner_claims (email) values (lower(btrim(p_email)))
  on conflict (email) do nothing;
end;
$fn$;
revoke execute on function public.operator_record_instance_owner_claim(text) from public, anon, authenticated;

-- Owner or active delegate, on a native session.
create or replace function public.is_instance_operator()
returns boolean language sql stable security definer set search_path = public as $fn$
  select auth.uid() is not null
     and not public.mcp_is_delegated()
     and (exists (select 1 from public.platform_admins where user_id = auth.uid())
          or exists (select 1 from public.instance_delegates
                      where user_id = auth.uid() and status = 'active'));
$fn$;
revoke execute on function public.is_instance_operator() from public, anon;
grant execute on function public.is_instance_operator() to authenticated;

-- Who is responsible, for anyone signed in. The account ids are only
-- shown to the owner, who needs them to withdraw a delegation.
create or replace function public.instance_responsibles()
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_me uuid := auth.uid();
  v_owner boolean;
  v_delegate boolean;
  v_claimable boolean;
  v_owners jsonb;
  v_delegates jsonb;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if public.mcp_is_delegated() then raise exception 'the instance owner is shown in the Deskilo app'; end if;
  v_owner := exists (select 1 from public.platform_admins where user_id = v_me);
  v_delegate := exists (select 1 from public.instance_delegates where user_id = v_me and status = 'active');
  v_claimable := not exists (select 1 from public.platform_admins)
    and exists (select 1 from auth.users u
                  join public.instance_owner_claims c on c.email = lower(u.email)
                 where u.id = v_me and u.email_confirmed_at is not null);

  select coalesce(jsonb_agg(jsonb_build_object(
           'name', coalesce(nullif(public.profile_full_name(p), ''), nullif(p.display_name, ''), split_part(u.email, '@', 1)),
           'email', u.email)
         order by pa.added_at), '[]'::jsonb)
    into v_owners
    from public.platform_admins pa
    join auth.users u on u.id = pa.user_id
    left join public.profiles p on p.id = pa.user_id;

  select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
           'user_id', case when v_owner then d.user_id end,
           'name', coalesce(nullif(public.profile_full_name(p), ''), nullif(p.display_name, ''), split_part(u.email, '@', 1)),
           'email', u.email,
           'since', d.granted_at))
         order by d.granted_at), '[]'::jsonb)
    into v_delegates
    from public.instance_delegates d
    join auth.users u on u.id = d.user_id
    left join public.profiles p on p.id = d.user_id
   where d.status = 'active';

  return jsonb_build_object(
    'installation_id', public.installation_id(),
    'you', case when v_owner then 'owner' when v_delegate then 'delegate' end,
    'claimable', v_claimable,
    'owners', v_owners,
    'delegates', v_delegates);
end;
$fn$;
revoke execute on function public.instance_responsibles() from public, anon;
grant execute on function public.instance_responsibles() to authenticated;

-- The owner names a delegate by e-mail. A refusal is an answer, not an
-- error, so the screen can say why.
create or replace function public.delegate_instance_role(p_email text)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_email text := lower(btrim(coalesce(p_email, '')));
  v_target auth.users;
  v_existing public.instance_delegates;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if public.mcp_is_delegated() then raise exception 'instance roles are managed in the Deskilo app'; end if;
  if not exists (select 1 from public.platform_admins where user_id = auth.uid()) then
    raise exception 'only the instance owner delegates';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('instance_delegates', 1829));
  select * into v_target from auth.users where lower(email) = v_email and deleted_at is null;
  if v_target.id is null then
    return jsonb_build_object('status', 'refused', 'reason', 'no_account');
  end if;
  if v_target.email_confirmed_at is null or coalesce(v_target.is_anonymous, false)
     or coalesce(v_target.banned_until > now(), false) then
    return jsonb_build_object('status', 'refused', 'reason', 'unconfirmed');
  end if;
  if v_target.id = auth.uid() or exists (select 1 from public.platform_admins where user_id = v_target.id) then
    return jsonb_build_object('status', 'refused', 'reason', 'already_owner');
  end if;
  select * into v_existing from public.instance_delegates where user_id = v_target.id;
  if v_existing.user_id is not null and v_existing.status = 'active' then
    return jsonb_build_object('status', 'unchanged');
  end if;
  insert into public.instance_delegates (user_id, status, granted_by, granted_at, withdrawn_at)
  values (v_target.id, 'active', auth.uid(), now(), null)
  on conflict (user_id) do update
    set status = 'active', granted_by = auth.uid(), granted_at = now(), withdrawn_at = null;
  insert into public.database_authority_audit (installation_id, action, actor, target_user_id)
  values (public.installation_id(), 'instance_delegate_granted', 'owner:' || auth.uid(), v_target.id);
  return jsonb_build_object('status', 'delegated');
end;
$fn$;
revoke execute on function public.delegate_instance_role(text) from public, anon;
grant execute on function public.delegate_instance_role(text) to authenticated;

create or replace function public.withdraw_instance_delegation(p_user uuid)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_count int;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if public.mcp_is_delegated() then raise exception 'instance roles are managed in the Deskilo app'; end if;
  if not exists (select 1 from public.platform_admins where user_id = auth.uid()) then
    raise exception 'only the instance owner withdraws a delegation';
  end if;
  update public.instance_delegates set status = 'withdrawn', withdrawn_at = now()
   where user_id = p_user and status = 'active';
  get diagnostics v_count = row_count;
  if v_count > 0 then
    insert into public.database_authority_audit (installation_id, action, actor, target_user_id)
    values (public.installation_id(), 'instance_delegate_withdrawn', 'owner:' || auth.uid(), p_user);
  end if;
  return jsonb_build_object('status', case when v_count > 0 then 'withdrawn' else 'unchanged' end);
end;
$fn$;
revoke execute on function public.withdraw_instance_delegation(uuid) from public, anon;
grant execute on function public.withdraw_instance_delegation(uuid) to authenticated;

-- A new instance has no owner. The account whose confirmed e-mail matches
-- the creator's recorded claim becomes the owner, once.
create or replace function public.claim_instance_ownership()
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_email text;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if public.mcp_is_delegated() then raise exception 'instance roles are managed in the Deskilo app'; end if;
  perform pg_advisory_xact_lock(hashtextextended('instance_ownership', 1829));
  if exists (select 1 from public.platform_admins) then
    return jsonb_build_object('status', 'refused', 'reason', 'owner_exists');
  end if;
  select lower(u.email) into v_email from auth.users u
   where u.id = auth.uid() and u.email_confirmed_at is not null;
  if v_email is null or not exists (select 1 from public.instance_owner_claims where email = v_email) then
    return jsonb_build_object('status', 'refused', 'reason', 'no_claim');
  end if;
  insert into public.platform_admins (user_id) values (auth.uid());
  delete from public.instance_owner_claims where email = v_email;
  insert into public.database_authority_audit (installation_id, action, actor, target_user_id)
  values (public.installation_id(), 'instance_ownership_claimed', 'claim:' || auth.uid(), auth.uid());
  return jsonb_build_object('status', 'claimed');
end;
$fn$;
revoke execute on function public.claim_instance_ownership() from public, anon;
grant execute on function public.claim_instance_ownership() to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(318);
