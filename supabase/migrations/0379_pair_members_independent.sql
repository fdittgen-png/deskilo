-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0379 — both sides of an environment pair hold the SAME people, and each
-- person's access is switched per side.
--
-- Until now a member of the production workspace was mirrored into the dev
-- (role AND status), and nothing flowed the other way. Now:
--   * a person present in one side is present in the other (either
--     direction); a person added to the dev appears in the prod but is not
--     ACTIVE there unless their role holds accessProd;
--   * status is independent per side after that: pausing someone in the prod
--     leaves the dev as it was, and vice versa. Only an exit travels, since
--     leaving a space is leaving it (both sides);
--   * roles follow the production side, as before;
--   * the production guard refuses an ACTIVE membership for a role without
--     accessProd — it no longer refuses to have the person present;
--   * a backfill gives every existing pair the same people on both sides.
-- An applied file never changes; later fixes are new migrations.

create or replace function public.members_prod_access_guard()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_ws public.workspaces;
  v_role text;
begin
  select * into v_ws from public.workspaces where id = new.workspace_id;
  if v_ws.environment <> 'prod' or v_ws.pair_id is null or new.is_owner or new.user_id is null
     or new.status <> 'active' then
    return new;
  end if;
  v_role := case when new.co_owner = 'active' then 'co_owner'
                 when new.is_admin then 'admin' else 'member' end;
  if not public.role_holds(new.workspace_id, v_role, 'accessProd') then
    raise exception 'this role has no access to the production workspace';
  end if;
  return new;
end;
$fn$;
drop trigger if exists members_prod_access_guard on public.members;
create trigger members_prod_access_guard before insert or update of status on public.members
  for each row execute function public.members_prod_access_guard();

create or replace function public.members_mirror_to_twin()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_ws public.workspaces;
  v_twin public.workspaces;
  v_status text;
begin
  if new.user_id is null or pg_trigger_depth() > 1 then return new; end if;
  select * into v_ws from public.workspaces where id = new.workspace_id;
  if v_ws.pair_id is null then return new; end if;
  select * into v_twin from public.workspaces where pair_id = v_ws.pair_id and id <> v_ws.id limit 1;
  if v_twin.id is null then return new; end if;
  if not exists (select 1 from public.members where workspace_id = v_twin.id and user_id = new.user_id) then
    v_status := new.status;
    if v_twin.environment = 'prod' and new.status = 'active' and not new.is_owner
       and not public.role_holds(v_twin.id,
             case when new.co_owner = 'active' then 'co_owner' when new.is_admin then 'admin' else 'member' end,
             'accessProd') then
      v_status := 'paused';
    end if;
    insert into public.members (workspace_id, user_id, is_admin, is_owner, co_owner, status, subscription_pct)
    values (v_twin.id, new.user_id, new.is_admin, false, new.co_owner, v_status, new.subscription_pct);
  elsif tg_op = 'UPDATE' then
    if v_ws.environment = 'prod' then
      update public.members
         set is_admin = new.is_admin, co_owner = new.co_owner
       where workspace_id = v_twin.id and user_id = new.user_id and not is_owner
         and (is_admin, co_owner) is distinct from (new.is_admin, new.co_owner);
    end if;
    if new.status = 'exited' then
      update public.members set status = 'exited'
       where workspace_id = v_twin.id and user_id = new.user_id and not is_owner and status <> 'exited';
    end if;
  end if;
  return new;
end;
$fn$;
revoke execute on function public.members_prod_access_guard() from public, anon;
revoke execute on function public.members_mirror_to_twin() from public, anon;
drop trigger if exists members_mirror_to_dev on public.members;
drop function if exists public.members_mirror_to_dev();
drop trigger if exists members_mirror_to_twin on public.members;
create trigger members_mirror_to_twin after insert or update of is_admin, co_owner, status on public.members
  for each row execute function public.members_mirror_to_twin();

-- Backfill: every pair holds the same people on both sides.
insert into public.members (workspace_id, user_id, is_admin, is_owner, co_owner, status, subscription_pct)
select t.id, m.user_id, m.is_admin, false, m.co_owner,
       case when t.environment = 'prod' and m.status = 'active' and not m.is_owner
                 and not public.role_holds(t.id,
                       case when m.co_owner = 'active' then 'co_owner' when m.is_admin then 'admin' else 'member' end,
                       'accessProd')
            then 'paused' else m.status end,
       m.subscription_pct
  from public.members m
  join public.workspaces w on w.id = m.workspace_id and w.pair_id is not null
  join public.workspaces t on t.pair_id = w.pair_id and t.id <> w.id
 where m.user_id is not null
   and not exists (select 1 from public.members x where x.workspace_id = t.id and x.user_id = m.user_id);

select public.set_deskilo_schema_version(379);
