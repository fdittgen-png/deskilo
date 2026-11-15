-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (one column; seven functions; one trigger; one anchored patch)
--
-- #4008 (decision 0052, point 7) -- a member of one house asks to join
-- another house of the same organisation, without a code and without
-- entering who they are: the identity is the person's profile, shared by
-- all their memberships.
--
-- * request_house_membership(house): a person active in one house of the
--   organisation asks another. It creates the member row an invitation
--   creates (the house's defaults for a new member, its own member number)
--   and the same join decision, naming the house the person comes from. A
--   member already there, or already asking, gets the state they are in. An
--   exited member asks again and the house always decides, whatever its
--   welcome.
-- * A person who left a business and comes back is a new member of it, on
--   every way of coming back: asking a house of the organisation, joining
--   with the business's code, or accepting a new invitation. One function,
--   member_return_as_new, makes the returning row what a first-time member
--   of that business gets: every right and term back to a new member's, the
--   role rows cleared, the business's defaults for a new member. It keeps
--   who the person is and their history (the row, its number, the documents
--   that hang on it), as house_member_return_columns() names them; pgTAP 437
--   fails when a column of members is in neither list. The join then goes
--   through the business's decision exactly as a first-time join does on
--   that path.
-- * The welcome is each HOUSE's own, never the head's: an owner of a house
--   says whether members of the organisation's other houses are welcome
--   there (off by default). When on, the request is accepted at once with
--   the house's defaults, and the join decision is written already decided
--   (`by: house_welcome`, no person as decider), so the house's journal
--   says who came and from where. When off, the house decides as it decides
--   any join.
-- * The welcoming houses are kept on the organisation
--   (`welcoming_houses`), written only by set_house_members_welcome and by
--   a house leaving: when a business leaves an organisation its welcome
--   there goes with it, so a house added again welcomes no one until its
--   owner says so anew.
-- * my_organisation_houses_v1(): for a member, the other houses of their
--   organisations they may ask to join, and the state of a request.
-- Nothing here touches a plan, a quota or a statement: each house bills its
-- own use in its own currency. A development twin is no house of its own.
-- An assistant's token is refused.

-- ── 1. each house's welcome ──────────────────────────────────────────────
alter table public.organisations
  add column if not exists welcoming_houses uuid[] not null default '{}';
comment on column public.organisations.welcoming_houses is
  '#4008 -- the houses whose owners welcome the members of the other houses at once; a listed id counts only while that house is in this organisation';

-- A business that leaves an organisation (taken out, its twin moving with
-- it, or any later path) leaves its welcome there behind it.
create or replace function public.workspaces_organisation_welcome_leaves()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  if old.organisation_id is not null and new.organisation_id is distinct from old.organisation_id then
    update public.organisations o set welcoming_houses = array_remove(o.welcoming_houses, old.id)
     where o.id = old.organisation_id and old.id = any (o.welcoming_houses);
  end if;
  return new;
end;
$fn$;
revoke execute on function public.workspaces_organisation_welcome_leaves() from public, anon, authenticated;
drop trigger if exists workspaces_organisation_welcome_leaves on public.workspaces;
create trigger workspaces_organisation_welcome_leaves after update of organisation_id on public.workspaces
  for each row when (old.organisation_id is distinct from new.organisation_id)
  execute function public.workspaces_organisation_welcome_leaves();

-- Whether [p_house] welcomes the members of its organisation's other houses.
create or replace function public.house_welcomes_members(p_house uuid)
returns boolean language sql stable security definer set search_path = public as $fn$
  select exists (
    select 1 from public.workspaces w
      join public.organisations o on o.id = w.organisation_id
     where w.id = p_house and w.id = any (o.welcoming_houses));
$fn$;
revoke execute on function public.house_welcomes_members(uuid) from public, anon, authenticated;

create or replace function public.set_house_members_welcome(p_house uuid, p_on boolean)
returns void language plpgsql security definer set search_path = public as $fn$
declare
  v_org uuid;
begin
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception 'only an owner of this business may do this' using errcode = '42501';
  end if;
  perform public.organisation_owner_check(p_house);
  select w.organisation_id into v_org from public.workspaces w where w.id = p_house;
  if v_org is null then
    raise exception 'this business is in no organisation' using errcode = '22023';
  end if;
  perform public.organisation_feature_check(p_house);
  update public.organisations o
     set welcoming_houses = case when coalesce(p_on, false)
           then array(select distinct x from unnest(o.welcoming_houses || p_house) x order by x)
           else array_remove(o.welcoming_houses, p_house) end
   where o.id = v_org
     and (p_house = any (o.welcoming_houses)) is distinct from coalesce(p_on, false);
end;
$fn$;
revoke execute on function public.set_house_members_welcome(uuid, boolean) from public, anon;
grant execute on function public.set_house_members_welcome(uuid, boolean) to authenticated;

-- ── 2. asking to join a house ────────────────────────────────────────────
-- What a member who returns to a house keeps, and what goes back to a new
-- member's: kept, who the person is and their history; reset, every right
-- and term (to the column's default; status to pending, the terms to the
-- house's defaults for a new member). Every column of members is in one
-- list: pgTAP 437 fails on a column in neither.
create or replace function public.house_member_return_columns()
returns jsonb language sql immutable set search_path = public as $fn$
  select '{"kept": ["id", "workspace_id", "user_id", "joined_at", "member_number", "origin", "person_id",
                    "managed_identity", "managed_name", "claimed_at", "preferred_locale_override",
                    "customer_capacity", "vies_vat_id", "vies_status", "vies_consultation",
                    "vies_checked_at", "vies_detail", "einvoice_endpoint_id",
                    "einvoice_endpoint_scheme", "billing_subdivision",
                    "created_datetime", "modified_datetime", "company_id", "site_id",
                    "created_by_user", "modified_by_user"],
           "reset": ["status", "is_admin", "is_owner", "co_owner", "managed_access", "managed_by",
                     "plan_id", "subscription_pct", "overage_policy", "is_kiosk",
                     "max_active_reservations", "max_simultaneous_reservations",
                     "can_reserve_level", "payment_terms", "home_site_id",
                     "vat_treatment", "vat_exemption_reason"]}'::jsonb
$fn$;
revoke execute on function public.house_member_return_columns() from public, anon, authenticated;

-- A row that was exited comes back as a first-time member's: pending, the
-- business's terms for a new member, every other right and term back to the
-- column's default, the role rows cleared. A row that is not exited is left
-- as it is.
create or replace function public.member_return_as_new(p_member uuid)
returns void language plpgsql security definer set search_path = public as $fn$
declare
  v_ws uuid;
  v_defaults jsonb;
begin
  select m.workspace_id into v_ws from public.members m where m.id = p_member and m.status = 'exited';
  if v_ws is null then return; end if;
  select coalesce(w.billing_rules->'new_member_defaults', '{}'::jsonb)
    into v_defaults from public.workspaces w where w.id = v_ws;
  -- in one statement: pending, the business's terms for a new member, and
  -- every other right and term back to the column's default
  execute format('update public.members set status = %L, subscription_pct = $2, overage_policy = $3%s where id = $1',
    'pending',
    (select coalesce(string_agg(format(', %I = default', c), ''), '')
       from jsonb_array_elements_text(public.house_member_return_columns()->'reset') c
      where c not in ('status', 'subscription_pct', 'overage_policy')))
    using p_member, coalesce((v_defaults->>'subscription_pct')::int, 100),
          coalesce(v_defaults->>'overage_policy', 'blocked');
  delete from public.workspace_role_members where member_id = p_member;
end;
$fn$;
revoke execute on function public.member_return_as_new(uuid) from public, anon, authenticated;

create or replace function public.request_house_membership(p_house uuid)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_house public.workspaces;
  v_from public.workspaces;
  v_member public.members;
  v_head uuid;
  v_welcome boolean;
  v_defaults jsonb;
  v_id uuid;
  v_status text;
begin
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception 'only a person asks to join a house' using errcode = '42501';
  end if;
  select * into v_house from public.workspaces where id = p_house;
  if v_house.id is null or v_house.organisation_id is null
     or (v_house.pair_id is not null and v_house.environment <> 'prod') then
    raise exception 'this business is no house of an organisation' using errcode = '22023';
  end if;
  select o.head_workspace_id into v_head from public.organisations o where o.id = v_house.organisation_id;
  v_welcome := public.house_welcomes_members(p_house);
  -- the house the person comes from: one where they are active, the head first
  select w.* into v_from
    from public.workspaces w
    join public.members m on m.workspace_id = w.id and m.user_id = auth.uid() and m.status = 'active'
   where w.organisation_id = v_house.organisation_id and w.id <> v_house.id
     and not (w.pair_id is not null and w.environment <> 'prod')
   order by w.id = v_head desc, lower(w.name), w.id
   limit 1;
  if v_from.id is null then
    raise exception 'only a member of a house of this organisation asks to join another' using errcode = '42501';
  end if;

  select * into v_member from public.members where workspace_id = p_house and user_id = auth.uid();
  if v_member.id is not null and v_member.status <> 'exited' then
    -- already there, or already asking: nothing is asked twice
    return jsonb_build_object('workspace_id', p_house, 'status', v_member.status,
                              'from_workspace_id', v_from.id);
  end if;

  select coalesce(billing_rules->'new_member_defaults', '{}'::jsonb)
    into v_defaults from public.workspaces where id = p_house;
  if v_member.id is not null then
    -- an exited member returns as a new member would, never with the role
    -- or the terms they had, and the house decides: its welcome is for
    -- members new to it, not for someone it let go
    v_status := 'pending';
    v_id := v_member.id;
    perform public.member_return_as_new(v_id);
  else
    v_status := case when v_welcome then 'active' else 'pending' end;
    insert into public.members (workspace_id, user_id, is_admin, status, origin,
                                subscription_pct, overage_policy)
    values (p_house, auth.uid(), false, v_status, 'invited',
            coalesce((v_defaults->>'subscription_pct')::int, 100),
            coalesce(v_defaults->>'overage_policy', 'blocked'))
    returning id into v_id;
  end if;
  update public.members set member_number = public.next_document_number(p_house, 'member')
   where id = v_id and member_number = '';

  if v_status = 'pending' and not exists (
       select 1 from public.events
        where subject_member_id = v_id and type = 'member_join' and status = 'pending') then
    insert into public.events
      (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
    values (p_house, 'member_join', 'submitted', v_id, v_id,
            jsonb_build_object('as_admin', false, 'claimed', false,
              'from_workspace_id', v_from.id, 'from_workspace_name', v_from.name),
            'pending');
  elsif v_status = 'active' then
    -- the house's welcome decided it: the journal says who came and from where
    insert into public.events
      (workspace_id, type, action, actor_member_id, subject_member_id, payload, status, decided_at)
    values (p_house, 'member_join', 'approved', v_id, v_id,
            jsonb_build_object('as_admin', false, 'claimed', false,
              'from_workspace_id', v_from.id, 'from_workspace_name', v_from.name,
              'by', 'house_welcome'),
            'confirmed', now());
  end if;
  return jsonb_build_object('workspace_id', p_house, 'status', v_status,
                            'from_workspace_id', v_from.id);
end;
$fn$;
revoke execute on function public.request_house_membership(uuid) from public, anon;
grant execute on function public.request_house_membership(uuid) to authenticated;

-- ── 3. the houses a member may ask to join ──────────────────────────────
create or replace function public.my_organisation_houses_v1()
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
begin
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception 'only a person reads the houses they may join' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'organisation_id', o.id, 'organisation_name', o.name,
             'workspace_id', w.id, 'name', w.name,
             'country_code', w.country_code, 'currency_code', w.currency_code,
             'request', case when m.status = 'pending' then 'pending' end,
             'welcome', w.id = any (o.welcoming_houses))
           order by o.name, w.id = o.head_workspace_id desc, lower(w.name), w.id)
      from public.organisations o
      join public.workspaces w on w.organisation_id = o.id
       and not (w.pair_id is not null and w.environment <> 'prod')
      left join public.members m on m.workspace_id = w.id and m.user_id = auth.uid()
     where coalesce(m.status, 'exited') not in ('active', 'paused')
       and exists (select 1 from public.workspaces x
                     join public.members mx on mx.workspace_id = x.id
                      and mx.user_id = auth.uid() and mx.status = 'active'
                    where x.organisation_id = o.id)), '[]'::jsonb);
end;
$fn$;
revoke execute on function public.my_organisation_houses_v1() from public, anon;
grant execute on function public.my_organisation_houses_v1() to authenticated;

-- ── 4. joining with a code or an invitation, after having left ─────────
do $migration$
declare
  v_def text := pg_get_functiondef('public.join_workspace(text)'::regprocedure);
  v_old text;
  v_new text;
begin
  if position('member_return_as_new' in v_def) = 0 then
    for v_old, v_new in select * from (values
      ($a$  v_defaults jsonb;
begin$a$, $a$  v_defaults jsonb;
  v_returning uuid;
begin$a$),
      ($a$    select coalesce(billing_rules->'new_member_defaults', '{}'::jsonb)
      into v_defaults from public.workspaces where id = ws_id;$a$,
       $a$    select coalesce(billing_rules->'new_member_defaults', '{}'::jsonb)
      into v_defaults from public.workspaces where id = ws_id;
    -- #4008: a person who left this business and comes back is a new member
    -- of it, with what this way of joining gives a first-time member
    select m.id into v_returning from public.members m
     where m.workspace_id = ws_id and m.user_id = auth.uid() and m.status = 'exited';
    if v_returning is not null then
      perform public.member_return_as_new(v_returning);
      update public.members set is_admin = v_admin where id = v_returning;
    end if;$a$)) v(o, n)
    loop
      if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then
        raise exception 'join_workspace no longer has the shape 0781 extends: %', left(v_old, 60) using errcode = 'P0001';
      end if;
      v_def := replace(v_def, v_old, v_new);
    end loop;
    execute v_def;
  end if;
end
$migration$;

select public.set_deskilo_schema_version(781);
