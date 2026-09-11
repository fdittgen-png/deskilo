-- SPDX-License-Identifier: 0BSD
-- 0200 — #1110: how each member got here, recorded once, at the moment
-- it is known.
--
-- Three paths create a membership and all three work. None of them
-- writes down which one it was:
--
--   founder    `create_workspace` inserts the owner alongside the space
--   invited    `join_workspace` redeems a code, unbound branch
--   delegated  `create_managed_member` (#887/0153) makes a row with no
--              user_id, which a person later claims through a bound
--              invitation
--
-- The distinction outlives the join. Somebody an admin created arrived
-- with data another person typed about them; somebody who founded the
-- space is not a joiner at all. Today it is only inferrable, and the
-- inference is lossy: `claimed_at is not null` finds a claimed
-- delegation, but a founder and an invited admin are indistinguishable
-- once both are `is_admin`.
--
-- Recording it at creation rather than deriving it later is the whole
-- point. The fact is known exactly once — when the row is written — and
-- never again.

alter table public.members
  add column if not exists origin text not null default 'invited';
alter table public.members drop constraint if exists members_origin_known;
alter table public.members
  add constraint members_origin_known
  check (origin in ('founder', 'invited', 'delegated'));

comment on column public.members.origin is
  'How this membership began: founder, invited or delegated (#1110). '
  'Written by the path that creates the row, never derived afterwards.';

-- ── the backfill, honest about what it cannot know ─────────────────
-- Two of the three are recoverable from rows that already exist. The
-- third is a guess, and saying so here is the point: a migration that
-- pretends to know is worse than one that admits a default.
update public.members m
   set origin = case
     -- A managed row, or one that was claimed through a bound
     -- invitation. Both are the delegated path, before and after the
     -- handover.
     when m.managed_by is not null or m.claimed_at is not null
       then 'delegated'
     -- The person who created the workspace. `create_workspace` sets
     -- `workspaces.created_by`, so this one is exact.
     when exists (select 1 from public.workspaces w
                   where w.id = m.workspace_id and w.created_by = m.user_id)
       then 'founder'
     -- Everything else. Most of these really were invited; some may be
     -- founders of a workspace whose `created_by` was lost to an early
     -- migration. There is no way to tell from here, and 'invited' is
     -- the honest default rather than the true answer.
     else 'invited'
   end;

-- ── founder ────────────────────────────────────────────────────────
create or replace function public.create_workspace(
  p_name text, p_country_code text, p_currency_code text, p_timezone text,
  p_environment text default 'dev', p_with_twin boolean default true
) returns uuid language plpgsql security definer set search_path = public as $fn$
declare
  ws_id uuid;
  twin_id uuid;
  v_pair uuid;
  v_other text;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.user_has_email(auth.uid()) then raise exception 'an owner must have an e-mail address'; end if;
  if coalesce(p_environment, 'dev') not in ('dev', 'prod') then
    raise exception 'unknown environment %', p_environment;
  end if;
  v_pair := case when p_with_twin then gen_random_uuid() else null end;
  insert into public.workspaces
    (name, country_code, currency_code, timezone, created_by, environment, pair_id)
  values (p_name, upper(p_country_code), upper(p_currency_code), p_timezone,
          auth.uid(), coalesce(p_environment, 'dev'), v_pair)
  returning id into ws_id;
  insert into public.members (workspace_id, user_id, is_admin, is_owner, origin)
  values (ws_id, auth.uid(), true, true, 'founder');
  update public.members set member_number = public.next_document_number(ws_id, 'member')
    where workspace_id = ws_id and user_id = auth.uid();
  if p_with_twin then
    v_other := case when coalesce(p_environment, 'dev') = 'dev' then 'prod' else 'dev' end;
    insert into public.workspaces
      (name, country_code, currency_code, timezone, created_by, environment, pair_id)
    values (p_name, upper(p_country_code), upper(p_currency_code), p_timezone,
            auth.uid(), v_other, v_pair)
    returning id into twin_id;
    -- The twin's owner founded it too: one act, two rows.
    insert into public.members (workspace_id, user_id, is_admin, is_owner, origin)
    values (twin_id, auth.uid(), true, true, 'founder');
    update public.members set member_number = public.next_document_number(twin_id, 'member')
      where workspace_id = twin_id and user_id = auth.uid();
  end if;
  return ws_id;
end;
$fn$;
revoke execute on function
  public.create_workspace(text, text, text, text, text, boolean) from public, anon;

-- ── delegated ──────────────────────────────────────────────────────
create or replace function public.create_managed_member(
  p_workspace_id uuid, p_identity jsonb, p_access jsonb default '{}'::jsonb
) returns uuid language plpgsql security definer set search_path = public as $fn$
declare
  v_identity jsonb;
  v_id uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.has_permission(p_workspace_id, 'manageMembers') then
    raise exception 'only admins may add managed profiles';
  end if;
  v_identity := public.managed_identity_clean(p_identity);
  if public.managed_identity_name(v_identity) = '' then
    raise exception 'a managed profile needs a name';
  end if;
  -- `delegated` is stamped HERE, when the admin creates the row, not
  -- when the person claims it. Somebody handed a profile still reads as
  -- delegated afterwards, which is the fact worth keeping — `claimed_at`
  -- says when, `origin` says how.
  insert into public.members
    (workspace_id, user_id, is_admin, status, managed_identity, managed_by,
     managed_access, managed_name, origin)
  values (p_workspace_id, null, false, 'active',
          public.managed_identity_public(v_identity), auth.uid(),
          coalesce(p_access, '{}'::jsonb),
          public.managed_identity_name(v_identity), 'delegated')
  returning id into v_id;
  update public.members set member_number = public.next_document_number(p_workspace_id, 'member')
    where id = v_id and member_number = '';
  insert into public.managed_identities (member_id, workspace_id, identity)
  values (v_id, p_workspace_id, v_identity);
  insert into public.data_access_log
    (workspace_id, actor_member_id, subject_member_id, category)
  select p_workspace_id, me.id, v_id, 'profile' from public.members me
   where me.workspace_id = p_workspace_id and me.user_id = auth.uid();
  return v_id;
end;
$fn$;
revoke execute on function
  public.create_managed_member(uuid, jsonb, jsonb) from public, anon;

-- ── invited ────────────────────────────────────────────────────────
-- Only the UNBOUND branch writes `invited`. The bound branch claims a
-- row that `create_managed_member` already stamped `delegated`, and it
-- must leave that alone — which is why the update below names every
-- column it clears and does not touch this one.
create or replace function public.join_workspace(p_invite_code text)
returns uuid language plpgsql security definer set search_path = public as $fn$
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
    select coalesce(mi.identity, '{}'::jsonb) into v_mi
      from public.managed_identities mi where mi.member_id = v_bound;
    v_mi := coalesce(v_mi, '{}'::jsonb);
    delete from public.managed_identities where member_id = v_bound;
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
    -- `origin` is deliberately absent: the row is already `delegated`
    -- and claiming it does not change how it began.
    update public.members
       set user_id = auth.uid(), claimed_at = now(),
           managed_identity = '{}'::jsonb, managed_name = '',
           managed_access = '{}'::jsonb, status = 'pending'
     where id = v_bound
    returning id into v_member_id;
  else
    insert into public.members (workspace_id, user_id, is_admin, status, origin)
    values (ws_id, auth.uid(), v_admin, 'pending', 'invited')
    on conflict (workspace_id, user_id) do update
      set status = case when public.members.status = 'exited'
                        then 'pending' else public.members.status end,
          is_admin = public.members.is_admin or excluded.is_admin
    returning id into v_member_id;
    -- A re-join of an EXITED membership keeps the origin it already
    -- had: somebody who founded the space and left did not become an
    -- invitee by coming back.
    update public.members set member_number = public.next_document_number(ws_id, 'member')
      where id = v_member_id and member_number = '';
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
$fn$;
revoke execute on function public.join_workspace(text) from public, anon;

-- ── the mirror carries it across ───────────────────────────────────
-- 0185 makes every prod member a dev member. Without this the mirrored
-- row would take the column default and a founder would read as invited
-- on the dev side of their own space.
create or replace function public.members_mirror_to_dev()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_ws public.workspaces;
  v_dev uuid;
begin
  if new.user_id is null then return new; end if;
  select * into v_ws from public.workspaces where id = new.workspace_id;
  if v_ws.environment <> 'prod' or v_ws.pair_id is null then return new; end if;
  select id into v_dev from public.workspaces where pair_id = v_ws.pair_id and environment = 'dev' and id <> v_ws.id limit 1;
  if v_dev is null then return new; end if;
  if exists (select 1 from public.members where workspace_id = v_dev and user_id = new.user_id) then
    update public.members
       set is_admin = new.is_admin, co_owner = new.co_owner, status = new.status
     where workspace_id = v_dev and user_id = new.user_id
       and (is_admin, co_owner, status) is distinct from (new.is_admin, new.co_owner, new.status)
       and not is_owner;
  else
    insert into public.members (workspace_id, user_id, is_admin, is_owner, co_owner, status, subscription_pct, origin)
    values (v_dev, new.user_id, new.is_admin, false, new.co_owner, new.status, new.subscription_pct, new.origin);
  end if;
  return new;
end;
$fn$;
revoke execute on function public.members_mirror_to_dev() from public, anon;
