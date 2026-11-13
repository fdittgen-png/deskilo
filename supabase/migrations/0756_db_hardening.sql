-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0756 (#3902) -- workspace pairing, badge sign-in and e-invoice
-- credentials.
--
--   1. The pair, the environment and the creator of a workspace are set by
--      the server: the API roles cannot change them. A member joins the twin
--      of a workspace only when both sides share an owner, and the twin is
--      chosen in a fixed order.
--   2. A badge opens its own workspace: an account that owns or administers
--      another workspace (outside its own pair) signs in with its password.
--   3. At a kiosk, a badge tag armed in several workspaces opens the kiosk's
--      own workspace first.
--   4. Moving an e-invoice connection to another host forgets the stored
--      secrets that were not sent with the move: they are entered again.

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

-- ── 1. the pair of a workspace ────────────────────────────────────────
-- Invoker on purpose: `current_user` is the caller's role (as 0361).
create or replace function public.workspaces_pair_immutable()
returns trigger language plpgsql set search_path = public as $fn$
begin
  if current_user in ('authenticated', 'anon')
     and (new.pair_id is distinct from old.pair_id
       or new.environment is distinct from old.environment
       or new.created_by is distinct from old.created_by) then
    raise exception 'the pair, environment and creator of a workspace are set by the server'
      using errcode = '42501';
  end if;
  return new;
end;
$fn$;

revoke execute on function public.workspaces_pair_immutable() from public, anon, authenticated;

drop trigger if exists workspaces_pair_immutable on public.workspaces;
create trigger workspaces_pair_immutable
  before update of pair_id, environment, created_by on public.workspaces
  for each row execute function public.workspaces_pair_immutable();

-- The membership mirror (0379, restated whole): the twin is the other
-- workspace of the pair, in a fixed order, and only one whose owner also
-- owns this workspace.
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
  select * into v_twin from public.workspaces
   where pair_id = v_ws.pair_id and id <> v_ws.id order by id limit 1;
  if v_twin.id is null then return new; end if;
  if not exists (
    select 1 from public.members a
      join public.members b on b.user_id = a.user_id
     where a.workspace_id = v_ws.id and a.is_owner and a.status = 'active'
       and b.workspace_id = v_twin.id and b.is_owner and b.status = 'active') then
    return new;
  end if;
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

revoke execute on function public.members_mirror_to_twin() from public, anon, authenticated;

-- ── 2 and 3. badge sign-in ────────────────────────────────────────────
do $migration$
declare
  v_def text;
begin
  select pg_get_functiondef('public.badge_auth_verify(text,text,text,uuid,text)'::regprocedure) into v_def;
  -- Applied once: a second run leaves the function as it is.
  if position('signs in with its password' in v_def) > 0 then return; end if;
  -- 3: the kiosk's own workspace first.
  v_def := pg_temp.anchor_replace(v_def,
    $a$   where token_hash = v_hash and revoked_at is null and auth_enabled
   order by created_at, id limit 1;
  v_on_kiosk$a$,
    $a$   where token_hash = v_hash and revoked_at is null and auth_enabled
   order by (workspace_id is not distinct from v_kiosk) desc, created_at, id limit 1;
  v_on_kiosk$a$);
  if v_def is null or position('(workspace_id is not distinct from v_kiosk) desc' in v_def) = 0 then
    raise exception '0756: badge_auth_verify badge anchor missing' using errcode = 'P0001';
  end if;
  -- 2: a badge opens its own workspace.
  v_def := pg_temp.anchor_replace(v_def,
    $a$  if v_badge.id is null or v_member.id is null or not coalesce(v_enabled,false)$a$,
    $a$  -- A badge opens its own workspace. An account that owns or administers
  -- another one signs in with its password. Answered like an unknown badge
  -- and counted for the tag only, as the kiosks-only refusal is: it never
  -- counts toward the business's pause or its owners' alert.
  if v_member.id is not null and exists (
       select 1 from public.members o
         join public.workspaces ow on ow.id = o.workspace_id
         join public.workspaces bw on bw.id = v_member.workspace_id
        where o.user_id = v_member.user_id and o.status = 'active'
          and o.workspace_id <> v_member.workspace_id
          and (ow.pair_id is null or ow.pair_id is distinct from bw.pair_id)
          and (o.is_owner or o.is_admin or o.co_owner = 'active')) then
    perform public.record_badge_auth_failure(v_hash, null, v_place, v_badge.workspace_id);
    return jsonb_build_object('ok',false,'reason','refused');
  end if;
  if v_badge.id is null or v_member.id is null or not coalesce(v_enabled,false)$a$);
  if v_def is null or position('signs in with its password' in v_def) = 0 then
    raise exception '0756: badge_auth_verify refusal anchor missing' using errcode = 'P0001';
  end if;
  execute v_def;
end
$migration$;

-- ── 4. e-invoice credentials ──────────────────────────────────────────
do $migration$
declare
  v_def text;
begin
  select pg_get_functiondef('public.set_einvoice_credentials(uuid,jsonb)'::regprocedure) into v_def;
  -- Applied once: a second run leaves the function as it is.
  if position('keeps no secret it was not sent' in v_def) > 0 then return; end if;
  v_def := pg_temp.anchor_replace(v_def,
    $a$  v_entry record;
begin$a$,
    $a$  v_entry record;
  v_old jsonb;
  v_key text;
begin$a$);
  if v_def is null or position('v_old jsonb;' in v_def) = 0 then
    raise exception '0756: set_einvoice_credentials declare anchor missing' using errcode = 'P0001';
  end if;
  v_def := pg_temp.anchor_replace(v_def,
    $a$  insert into public.einvoice_credentials
    (workspace_id, provider, config, updated_at)$a$,
    $a$  -- A connection moved to another host keeps no secret it was not sent
  -- with: the secrets are entered again for the new host.
  select config into v_old from public.einvoice_credentials where workspace_id = p_workspace_id for update;
  if v_old is not null and exists (
       select 1 from jsonb_each(v_stored) n
        where n.key ~ '^(customer_)?(endpoint|base_url|token_url|login_url)(_uat|_dev)?$'
          and n.value is distinct from v_old -> n.key) then
    for v_key in select key from jsonb_each(v_old) loop
      if public.einvoice_config_is_secret(v_key) and not (v_stored ? v_key) then
        delete from vault.secrets where name = public.einvoice_secret_name(p_workspace_id, v_key);
        update public.einvoice_credentials set config = config - v_key where workspace_id = p_workspace_id;
      end if;
    end loop;
  end if;
  insert into public.einvoice_credentials
    (workspace_id, provider, config, updated_at)$a$);
  if v_def is null or position('keeps no secret it was not sent' in v_def) = 0 then
    raise exception '0756: set_einvoice_credentials insert anchor missing' using errcode = 'P0001';
  end if;
  execute v_def;
end
$migration$;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(756);
