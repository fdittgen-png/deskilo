-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (one table; one nullable column on workspaces, written by the server only;
-- the guard of the workspace's pair restated whole with it; six functions)
--
-- #4004 (decision 0052) -- the organisation of a customer's businesses. A
-- business stays one issuer; a customer's businesses form an organisation
-- with one head. Another country or another currency is a house: a business
-- of its own in the organisation.
--
-- * organisations: a name and the head business. Readable by the members of
--   its houses: its name and head only.
-- * workspaces.organisation_id: the organisation a business is a house of;
--   null for none. Only the server writes it: the guard of the pair covers
--   it for the API roles. A development twin follows its business into and
--   out of the organisation.
-- * Commands, each a definer that checks the caller house by house:
--   create_organisation (an owner of the head), add_business_to_organisation
--   (an owner of the head and of the business; never a business already in
--   one), remove_business_from_organisation (an owner of the head or of the
--   business; the head leaves last), rename_organisation and
--   set_organisation_head (an owner of the head, and of the new head).
-- * my_organisations_v1: the caller's businesses with their organisation,
--   and per house the caller is a member of: its name, country, currency
--   and the caller's role there. A house the caller is not a member of is
--   not listed.
-- No authority flows between houses: no trigger gives a role in one house
-- because of a role in another, and the twin's member mirror is untouched.
-- An assistant's token is refused on the table and on every command.

-- ── 1. the organisation ──────────────────────────────────────────────────
create table if not exists public.organisations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(btrim(name)) between 1 and 200),
  head_workspace_id uuid not null references public.workspaces(id) on delete cascade
);
select public.ensure_system_columns('organisations');
comment on table public.organisations is
  '#4004 -- the organisation of a customer''s businesses: its name and its head business (decision 0052)';
create unique index if not exists organisations_head_uq on public.organisations (head_workspace_id);

alter table public.workspaces
  add column if not exists organisation_id uuid references public.organisations(id) on delete set null;
comment on column public.workspaces.organisation_id is
  '#4004 -- the organisation this business is a house of; null for none. Written by the server only.';
create index if not exists workspaces_organisation_idx on public.workspaces (organisation_id)
  where organisation_id is not null;

alter table public.organisations enable row level security;
-- an organisation is read by the members of its houses
drop policy if exists organisations_select on public.organisations;
create policy organisations_select on public.organisations for select using (
  exists (select 1 from public.workspaces w
           where w.organisation_id = organisations.id and public.is_member_of(w.id)));
drop policy if exists mcp_delegated_deny on public.organisations;
create policy mcp_delegated_deny on public.organisations as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
revoke insert, update, delete on public.organisations from anon, authenticated;

-- ── 2. the server writes the organisation of a business ──────────────────
-- 0756's guard, restated whole with the organisation. Invoker on purpose:
-- `current_user` is the caller's role.
create or replace function public.workspaces_pair_immutable()
returns trigger language plpgsql set search_path = public as $fn$
begin
  if current_user in ('authenticated', 'anon')
     and (new.pair_id is distinct from old.pair_id
       or new.environment is distinct from old.environment
       or new.created_by is distinct from old.created_by
       or new.organisation_id is distinct from old.organisation_id) then
    raise exception 'the pair, environment, creator and organisation of a workspace are set by the server'
      using errcode = '42501';
  end if;
  return new;
end;
$fn$;
revoke execute on function public.workspaces_pair_immutable() from public, anon, authenticated;

drop trigger if exists workspaces_pair_immutable on public.workspaces;
create trigger workspaces_pair_immutable
  before update of pair_id, environment, created_by, organisation_id on public.workspaces
  for each row execute function public.workspaces_pair_immutable();

-- A business made by a caller is in no organisation, unless it is the twin
-- of one that is: the twin carries its business's organisation.
create or replace function public.workspaces_organisation_at_birth()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  new.organisation_id := case when new.pair_id is null then null else
    (select w.organisation_id from public.workspaces w
      where w.pair_id = new.pair_id and w.id <> new.id order by w.id limit 1) end;
  return new;
end;
$fn$;
revoke execute on function public.workspaces_organisation_at_birth() from public, anon, authenticated;

drop trigger if exists workspaces_organisation_at_birth on public.workspaces;
create trigger workspaces_organisation_at_birth
  before insert on public.workspaces
  for each row execute function public.workspaces_organisation_at_birth();

-- The organisation of [p_workspace_id] and of its twin.
create or replace function public.organisation_place(p_workspace_id uuid, p_organisation_id uuid)
returns void language sql security definer set search_path = public as $fn$
  update public.workspaces w
     set organisation_id = p_organisation_id
   where w.id = p_workspace_id
      or (w.pair_id is not null
          and w.pair_id = (select x.pair_id from public.workspaces x where x.id = p_workspace_id));
$fn$;
revoke execute on function public.organisation_place(uuid, uuid) from public, anon, authenticated;

-- A business paired with its twin after both exist: the pair shares the
-- organisation of whichever of the two is in one.
create or replace function public.workspaces_organisation_of_pair()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_org uuid;
begin
  if new.pair_id is null then return new; end if;
  v_org := coalesce(new.organisation_id,
    (select w.organisation_id from public.workspaces w
      where w.pair_id = new.pair_id and w.id <> new.id and w.organisation_id is not null
      order by w.id limit 1));
  if v_org is not null then
    perform public.organisation_place(new.id, v_org);
  end if;
  return new;
end;
$fn$;
revoke execute on function public.workspaces_organisation_of_pair() from public, anon, authenticated;

drop trigger if exists workspaces_organisation_of_pair on public.workspaces;
create trigger workspaces_organisation_of_pair
  after update of pair_id on public.workspaces
  for each row when (new.pair_id is distinct from old.pair_id)
  execute function public.workspaces_organisation_of_pair();

-- ── 3. the commands ──────────────────────────────────────────────────────
-- Whether the caller owns [p_workspace_id] and its twin: a command moves
-- both halves of a pair, so it asks the owner of both.
create or replace function public.organisation_owns(p_workspace_id uuid)
returns boolean language sql stable security definer set search_path = public as $fn$
  select p_workspace_id is not null
     and not public.mcp_is_delegated()
     and not exists (
       select 1 from public.workspaces w
        where (w.id = p_workspace_id
               or (w.pair_id is not null
                   and w.pair_id = (select x.pair_id from public.workspaces x where x.id = p_workspace_id)))
          and not coalesce(public.is_owner_of(w.id), false))
     and exists (select 1 from public.workspaces where id = p_workspace_id);
$fn$;
revoke execute on function public.organisation_owns(uuid) from public, anon, authenticated;

-- Refuses an assistant's token and anyone who does not own [p_workspace_id]
-- and its twin.
create or replace function public.organisation_owner_check(p_workspace_id uuid)
returns void language plpgsql stable security definer set search_path = public as $fn$
begin
  if not public.organisation_owns(p_workspace_id) then
    raise exception 'only an owner of this business may do this' using errcode = '42501';
  end if;
end;
$fn$;
revoke execute on function public.organisation_owner_check(uuid) from public, anon, authenticated;

create or replace function public.create_organisation(p_head uuid, p_name text)
returns uuid language plpgsql security definer set search_path = public as $fn$
declare
  v_id uuid;
begin
  perform public.organisation_owner_check(p_head);
  if length(btrim(coalesce(p_name, ''))) not between 1 and 200 then
    raise exception 'an organisation needs a name' using errcode = '22023';
  end if;
  if (select organisation_id from public.workspaces where id = p_head) is not null then
    raise exception 'this business is already in an organisation' using errcode = '22023';
  end if;
  insert into public.organisations (name, head_workspace_id) values (btrim(p_name), p_head)
  returning id into v_id;
  perform public.organisation_place(p_head, v_id);
  return v_id;
end;
$fn$;
revoke execute on function public.create_organisation(uuid, text) from public, anon;
grant execute on function public.create_organisation(uuid, text) to authenticated;

create or replace function public.add_business_to_organisation(p_organisation uuid, p_business uuid)
returns void language plpgsql security definer set search_path = public as $fn$
declare
  v_head uuid;
begin
  select head_workspace_id into v_head from public.organisations where id = p_organisation;
  perform public.organisation_owner_check(v_head);
  perform public.organisation_owner_check(p_business);
  if (select organisation_id from public.workspaces where id = p_business) is not null then
    raise exception 'this business is already in an organisation' using errcode = '22023';
  end if;
  perform public.organisation_place(p_business, p_organisation);
end;
$fn$;
revoke execute on function public.add_business_to_organisation(uuid, uuid) from public, anon;
grant execute on function public.add_business_to_organisation(uuid, uuid) to authenticated;

create or replace function public.remove_business_from_organisation(p_business uuid)
returns void language plpgsql security definer set search_path = public as $fn$
declare
  v_org public.organisations;
  v_pair uuid;
begin
  select o.* into v_org from public.organisations o
    join public.workspaces w on w.organisation_id = o.id
   where w.id = p_business;
  if v_org.id is null then
    raise exception 'this business is in no organisation' using errcode = '22023';
  end if;
  select pair_id into v_pair from public.workspaces where id = v_org.head_workspace_id;
  if p_business = v_org.head_workspace_id
     or (v_pair is not null and p_business in (select id from public.workspaces where pair_id = v_pair)) then
    -- the head and its twin leave last, by an owner of the head
    perform public.organisation_owner_check(v_org.head_workspace_id);
    if exists (select 1 from public.workspaces w
                where w.organisation_id = v_org.id and w.id <> v_org.head_workspace_id
                  and (v_pair is null or w.pair_id is distinct from v_pair)) then
      raise exception 'the head leaves last' using errcode = '22023';
    end if;
    perform public.organisation_place(v_org.head_workspace_id, null);
    delete from public.organisations where id = v_org.id;
    return;
  end if;
  -- a house leaves by an owner of the head, or by an owner of the house
  if not (public.organisation_owns(v_org.head_workspace_id) or public.organisation_owns(p_business)) then
    raise exception 'only an owner of this business may do this' using errcode = '42501';
  end if;
  perform public.organisation_place(p_business, null);
end;
$fn$;
revoke execute on function public.remove_business_from_organisation(uuid) from public, anon;
grant execute on function public.remove_business_from_organisation(uuid) to authenticated;

create or replace function public.rename_organisation(p_organisation uuid, p_name text)
returns void language plpgsql security definer set search_path = public as $fn$
begin
  perform public.organisation_owner_check(
    (select head_workspace_id from public.organisations where id = p_organisation));
  if length(btrim(coalesce(p_name, ''))) not between 1 and 200 then
    raise exception 'an organisation needs a name' using errcode = '22023';
  end if;
  update public.organisations set name = btrim(p_name) where id = p_organisation;
end;
$fn$;
revoke execute on function public.rename_organisation(uuid, text) from public, anon;
grant execute on function public.rename_organisation(uuid, text) to authenticated;

create or replace function public.set_organisation_head(p_organisation uuid, p_head uuid)
returns void language plpgsql security definer set search_path = public as $fn$
begin
  perform public.organisation_owner_check(
    (select head_workspace_id from public.organisations where id = p_organisation));
  perform public.organisation_owner_check(p_head);
  if (select organisation_id from public.workspaces where id = p_head) is distinct from p_organisation then
    raise exception 'the new head is not a house of this organisation' using errcode = '22023';
  end if;
  update public.organisations set head_workspace_id = p_head where id = p_organisation;
end;
$fn$;
revoke execute on function public.set_organisation_head(uuid, uuid) from public, anon;
grant execute on function public.set_organisation_head(uuid, uuid) to authenticated;

-- ── 4. the caller's organisations ────────────────────────────────────────
-- Per organisation the caller has a house in: its name and head, and the
-- houses the caller is a member of, each with its name, country, currency
-- and the caller's role there.
create or replace function public.my_organisations_v1()
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
begin
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', o.id, 'name', o.name, 'head_workspace_id', o.head_workspace_id,
             'houses', (
               select jsonb_agg(jsonb_build_object(
                        'workspace_id', w.id, 'name', w.name, 'country_code', w.country_code,
                        'currency_code', w.currency_code,
                        'role', case when m.is_owner then 'owner'
                                     when m.co_owner = 'active' then 'co_owner'
                                     when m.is_admin then 'admin' else 'member' end)
                      order by w.id = o.head_workspace_id desc, w.name)
                 from public.workspaces w
                 join public.members m on m.workspace_id = w.id
                  and m.user_id = auth.uid() and m.status = 'active'
                where w.organisation_id = o.id))
           order by o.name)
      from public.organisations o
     where exists (select 1 from public.workspaces w
                     join public.members m on m.workspace_id = w.id
                      and m.user_id = auth.uid() and m.status = 'active'
                    where w.organisation_id = o.id)), '[]'::jsonb);
end;
$fn$;
revoke execute on function public.my_organisations_v1() from public, anon;
grant execute on function public.my_organisations_v1() to authenticated;

select public.set_deskilo_schema_version(773);
