-- SPDX-License-Identifier: 0BSD
-- 0185 — #987/#989: environment pairs, and the permissions to deploy
-- and to enter the production side.
--
-- A workspace is created together with its twin: the dev and the prod
-- share a pair_id, the same name, country, currency and timezone, and
-- the creator owns both. A lone workspace gets its twin on demand, with
-- its configuration copied once. Three permissions join the matrix:
-- deployToProd (implies deployToDev), deployToDev, accessProd. Owner
-- and co-owner hold all three by default, admin holds deployToDev and
-- accessProd, member holds none. A member of the prod is always a
-- member of the dev (a trigger mirrors the row), and a role enters the
-- prod only while it holds accessProd.

alter table public.workspaces add column if not exists pair_id uuid;
create index if not exists workspaces_pair_idx on public.workspaces (pair_id);

-- ── the matrix ──────────────────────────────────────────────────────
create or replace function public.has_permission_raw(ws uuid, perm text)
returns boolean language sql stable security definer set search_path = public as $fn$
  select exists (
    select 1 from public.members m join public.workspaces w on w.id = ws
    where m.workspace_id = ws and m.user_id = auth.uid() and m.status = 'active'
      and ( m.is_owner
        or (m.co_owner = 'active' and (case when w.role_permissions ? 'co_owner' then w.role_permissions->'co_owner' ? perm else true end))
        or (m.is_admin and (
             (case when w.role_permissions ? 'admin' then w.role_permissions->'admin' ? perm
                   else perm in ('manageMembers','manageDocuments','manageServices','approveExpenses',
                                 'viewFinances','viewNegotiations','manageNegotiations','paymentTermsEdit',
                                 'manageSites','manageReservations','operateKiosk','exportData','viewPersonalData',
                                 'deployToDev','accessProd') end)
             or (perm = 'issueInvoices' and coalesce(w.feature_flags -> 'adminInvoicing' = to_jsonb(true), false))))
        or (not m.is_admin and not m.is_owner and m.co_owner <> 'active' and w.role_permissions ? 'member' and w.role_permissions->'member' ? perm)));
$fn$;

-- deployToProd implies deployToDev: whoever may push to the real side
-- may always refresh the working one.
create or replace function public.has_permission(ws uuid, perm text)
returns boolean language sql stable security definer set search_path = public as $fn$
  select public.has_permission_raw(ws, perm)
      or (perm = 'deployToDev' and public.has_permission_raw(ws, 'deployToProd'));
$fn$;

create or replace function public.member_has_permission(p_member_id uuid, perm text)
returns boolean language sql stable security definer set search_path = public as $fn$
  select exists (select 1 from public.members m join public.workspaces w on w.id = m.workspace_id
    where m.id = p_member_id and m.status = 'active'
      and ( m.is_owner
        or (m.co_owner = 'active' and (case when w.role_permissions ? 'co_owner' then w.role_permissions->'co_owner' ? perm else true end))
        or (m.is_admin and (case when w.role_permissions ? 'admin' then w.role_permissions->'admin' ? perm
              else perm in ('manageMembers','manageDocuments','manageServices','approveExpenses','viewFinances','viewNegotiations','manageNegotiations',
                            'manageSites','manageReservations','operateKiosk','exportData','viewPersonalData','deployToDev','accessProd') end))
        or (not m.is_admin and not m.is_owner and m.co_owner <> 'active' and w.role_permissions ? 'member' and w.role_permissions->'member' ? perm)))
    or (perm = 'deployToDev' and public.member_has_permission(p_member_id, 'deployToProd'));
$fn$;

-- What a ROLE holds in a workspace — for a row that is not a member yet.
create or replace function public.role_holds(ws uuid, p_role text, perm text)
returns boolean language sql stable security definer set search_path = public as $fn$
  select case p_role
    when 'owner' then true
    when 'co_owner' then (case when w.role_permissions ? 'co_owner' then w.role_permissions->'co_owner' ? perm else true end)
    when 'admin' then (case when w.role_permissions ? 'admin' then w.role_permissions->'admin' ? perm
                            else perm in ('manageMembers','manageDocuments','manageServices','approveExpenses','viewFinances',
                                          'viewNegotiations','manageNegotiations','paymentTermsEdit','manageSites','manageReservations',
                                          'operateKiosk','exportData','viewPersonalData','deployToDev','accessProd') end)
    else (w.role_permissions ? 'member' and w.role_permissions->'member' ? perm) end
  from public.workspaces w where w.id = ws;
$fn$;

do $patch$
declare v_def text; v_old text;
begin
  select pg_get_functiondef(p.oid) into v_def from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'set_role_permissions';
  v_old := '''designDocuments'',''viewPersonalData'',''manageIntegrations'',''manageConfiguration''];';
  if position(v_old in v_def) = 0 then raise exception 'catalog anchor missing'; end if;
  v_def := replace(v_def, v_old, '''designDocuments'',''viewPersonalData'',''manageIntegrations'',''manageConfiguration'',' || E'\n' ||
    '    ''deployToProd'',''deployToDev'',''accessProd''];');
  execute v_def;
end;
$patch$;

-- ── the pair ────────────────────────────────────────────────────────
drop function if exists public.create_workspace(text, text, text, text, text);
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
  if coalesce(p_environment, 'dev') not in ('dev', 'prod') then
    raise exception 'unknown environment %', p_environment;
  end if;
  v_pair := case when p_with_twin then gen_random_uuid() else null end;
  insert into public.workspaces
    (name, country_code, currency_code, timezone, created_by, environment, pair_id)
  values (p_name, upper(p_country_code), upper(p_currency_code), p_timezone,
          auth.uid(), coalesce(p_environment, 'dev'), v_pair)
  returning id into ws_id;
  insert into public.members (workspace_id, user_id, is_admin, is_owner)
  values (ws_id, auth.uid(), true, true);
  if p_with_twin then
    v_other := case when coalesce(p_environment, 'dev') = 'dev' then 'prod' else 'dev' end;
    insert into public.workspaces
      (name, country_code, currency_code, timezone, created_by, environment, pair_id)
    values (p_name, upper(p_country_code), upper(p_currency_code), p_timezone,
            auth.uid(), v_other, v_pair)
    returning id into twin_id;
    insert into public.members (workspace_id, user_id, is_admin, is_owner)
    values (twin_id, auth.uid(), true, true);
  end if;
  return ws_id;
end;
$fn$;

-- The twin of a lone workspace, its configuration copied once.
create or replace function public.workspace_twin_id(p_workspace_id uuid)
returns uuid language sql stable security definer set search_path = public as $fn$
  select t.id from public.workspaces w join public.workspaces t
    on t.pair_id = w.pair_id and t.id <> w.id
   where w.id = p_workspace_id and w.pair_id is not null
   limit 1;
$fn$;

create or replace function public.create_workspace_twin(p_workspace_id uuid)
returns uuid language plpgsql security definer set search_path = public as $fn$
declare
  v_ws public.workspaces;
  twin_id uuid;
  v_pair uuid;
begin
  if not public.is_owner_of(p_workspace_id) then
    raise exception 'only owners may create the twin';
  end if;
  select * into v_ws from public.workspaces where id = p_workspace_id;
  if public.workspace_twin_id(p_workspace_id) is not null then
    raise exception 'this workspace already has its twin';
  end if;
  v_pair := coalesce(v_ws.pair_id, gen_random_uuid());
  update public.workspaces set pair_id = v_pair where id = p_workspace_id;
  insert into public.workspaces
    (name, country_code, currency_code, timezone, created_by, environment, pair_id)
  values (v_ws.name, v_ws.country_code, v_ws.currency_code, v_ws.timezone,
          auth.uid(), case when v_ws.environment = 'dev' then 'prod' else 'dev' end, v_pair)
  returning id into twin_id;
  insert into public.members (workspace_id, user_id, is_admin, is_owner)
  values (twin_id, auth.uid(), true, true);
  perform public.import_workspace_configuration(twin_id, public.export_workspace_configuration(p_workspace_id));
  return twin_id;
end;
$fn$;
revoke execute on function public.create_workspace_twin(uuid) from public, anon;

-- ── membership across the pair ──────────────────────────────────────
-- A role enters the production side only while it holds accessProd.
create or replace function public.members_prod_access_guard()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_ws public.workspaces;
  v_role text;
begin
  select * into v_ws from public.workspaces where id = new.workspace_id;
  if v_ws.environment <> 'prod' or v_ws.pair_id is null or new.is_owner or new.user_id is null then
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
create trigger members_prod_access_guard before insert on public.members
  for each row execute function public.members_prod_access_guard();

-- A member of the prod is always a member of the dev: the row is
-- mirrored (same role, same status) and follows role and status changes.
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
    insert into public.members (workspace_id, user_id, is_admin, is_owner, co_owner, status, subscription_pct)
    values (v_dev, new.user_id, new.is_admin, false, new.co_owner, new.status, new.subscription_pct);
  end if;
  return new;
end;
$fn$;
drop trigger if exists members_mirror_to_dev on public.members;
create trigger members_mirror_to_dev after insert or update of is_admin, co_owner, status on public.members
  for each row execute function public.members_mirror_to_dev();
