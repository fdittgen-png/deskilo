-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0361 (#2137) -- a permission given through a role works.
--
-- Since #2085 everyone is a member and what they can do comes from their
-- roles. Several doors still asked "is this the owner?" (or read the raw
-- admin flag) where the catalogue already names the permission, so a
-- member given the permission -- through a role, or the Administrator's
-- row of the matrix -- was shown the screen and refused by the database.
-- Each door below now asks the permission. The owner keeps every door
-- (`is_owner_of` stays in each), and nothing is opened to anybody who
-- does not hold the permission.
--
--   * services, packages, credit products -- manageServices (the
--     accessories table has asked it since 0216);
--   * closure days, and generating or importing them -- workspaceSettings
--     (the Availability screen's permission);
--   * the document library -- manageDocuments, and a document reserved
--     to administrators is read by whoever manages the library;
--   * inviting a member -- manageMembers (an Administrator invitation
--     stays the owner's);
--   * the workspace row -- its settings columns for workspaceSettings,
--     its billing columns for manageBilling, the payment instructions for
--     manageIntegrations (the screen's permission). Every other column (the
--     matrix, the features, the code, the identity...) stays the owner's
--     or a definer's: a trigger refuses a delegated update that touches
--     anything outside the caller's columns, because a policy cannot
--     limit columns.

-- ── catalogue tables ───────────────────────────────────────────────────
drop policy if exists services_write_permitted on public.services;
create policy services_write_permitted on public.services
  for all
  using (workspace_id in (select public.workspaces_permitting(array['manageServices'])))
  with check (workspace_id in (select public.workspaces_permitting(array['manageServices'])));

drop policy if exists packages_write_permitted on public.packages;
create policy packages_write_permitted on public.packages
  for all
  using (workspace_id in (select public.workspaces_permitting(array['manageServices'])))
  with check (workspace_id in (select public.workspaces_permitting(array['manageServices'])));

drop policy if exists credit_products_write_permitted on public.credit_products;
create policy credit_products_write_permitted on public.credit_products
  for all
  using (workspace_id in (select public.workspaces_permitting(array['manageServices'])))
  with check (workspace_id in (select public.workspaces_permitting(array['manageServices'])));

drop policy if exists closure_days_write_permitted on public.closure_days;
create policy closure_days_write_permitted on public.closure_days
  for all
  using (workspace_id in (select public.workspaces_permitting(array['workspaceSettings'])))
  with check (workspace_id in (select public.workspaces_permitting(array['workspaceSettings'])));

-- ── the document library ───────────────────────────────────────────────
drop policy if exists workspace_documents_write on public.workspace_documents;
create policy workspace_documents_write on public.workspace_documents
  for all
  using (workspace_id in (select public.workspaces_permitting(array['manageDocuments'])))
  with check (workspace_id in (select public.workspaces_permitting(array['manageDocuments'])));

drop policy if exists workspace_documents_select_managers on public.workspace_documents;
create policy workspace_documents_select_managers on public.workspace_documents
  for select
  using (min_role = 'admin'
         and workspace_id in (select public.workspaces_permitting(array['manageDocuments'])));

-- ── the workspace row ──────────────────────────────────────────────────
drop policy if exists workspaces_update_delegated on public.workspaces;
create policy workspaces_update_delegated on public.workspaces
  for update
  using (id in (select public.workspaces_permitting(array['workspaceSettings', 'manageBilling', 'manageIntegrations'])))
  with check (id in (select public.workspaces_permitting(array['workspaceSettings', 'manageBilling', 'manageIntegrations'])));

-- Which columns a delegate may write, by permission. The owner and every
-- definer (current_user is then the function's owner, not
-- `authenticated`) are not limited here.
-- SECURITY INVOKER on purpose: `current_user` must be the caller's role,
-- so a definer's own update is told apart from a client's.
create or replace function public.workspaces_delegated_columns()
returns trigger
language plpgsql set search_path = public as $fn$
declare
  v_changed text[];
  v_allowed text[] := '{}';
  v_col text;
begin
  if current_user <> 'authenticated' or public.is_owner_of(old.id) then
    return new;
  end if;
  select coalesce(array_agg(n.key), '{}') into v_changed
    from jsonb_each(to_jsonb(new)) n
    join jsonb_each(to_jsonb(old)) o on o.key = n.key
   where n.value is distinct from o.value
     and not (n.key = any(public.system_column_names()));
  if public.has_permission(old.id, 'workspaceSettings') then
    v_allowed := v_allowed || array['timezone', 'country_code', 'currency_code',
      'default_locale', 'invitation_template', 'invitation_templates',
      'address', 'whatsapp_group', 'desk_opacity'];
  end if;
  if public.has_permission(old.id, 'manageBilling') then
    v_allowed := v_allowed || array['subscription_vat_rate_id',
      'subscription_levels'];
  end if;
  if public.has_permission(old.id, 'manageIntegrations') then
    v_allowed := v_allowed || array['payment_instructions', 'whatsapp_group'];
  end if;
  foreach v_col in array v_changed loop
    if not (v_col = any(v_allowed)) then
      raise exception 'only the owner changes % of a workspace', v_col
        using errcode = '42501';
    end if;
  end loop;
  return new;
end $fn$;

revoke execute on function public.workspaces_delegated_columns()
  from public, anon, authenticated;

drop trigger if exists workspaces_delegated_columns on public.workspaces;
create trigger workspaces_delegated_columns
  before update on public.workspaces
  for each row execute function public.workspaces_delegated_columns();

-- ── inviting a member ──────────────────────────────────────────────────
create or replace function public.create_invitation(p_workspace_id uuid, p_is_admin boolean, p_first_name text DEFAULT ''::text, p_last_name text DEFAULT ''::text, p_member_id uuid DEFAULT NULL::uuid, p_also_prod boolean DEFAULT false)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_code text;
  v_member public.members;
  v_ws public.workspaces;
  v_role text;
  v_also boolean := coalesce(p_also_prod, false);
  v_first text := left(coalesce(p_first_name, ''), 120);
  v_last text := left(coalesce(p_last_name, ''), 120);
begin
  if p_is_admin then
    if not public.is_owner_of(p_workspace_id) then
      raise exception 'only owners may invite admins';
    end if;
  -- #2137 -- whoever manages the members invites one.
  elsif not (public.is_admin_of(p_workspace_id)
             or public.has_permission(p_workspace_id, 'manageMembers')) then
    raise exception 'only admins may invite members';
  end if;
  if p_member_id is not null then
    select * into v_member from public.members
     where id = p_member_id and workspace_id = p_workspace_id;
    if not found then raise exception 'member not found'; end if;
    if v_member.user_id is not null then raise exception 'profile already claimed'; end if;
    if p_is_admin then raise exception 'a handover grants membership, not admin'; end if;
    if not public.can_manage_managed_profile(p_member_id) then
      raise exception 'not allowed to manage this profile';
    end if;
    if v_first = '' then v_first := left(coalesce((select mi.identity->>'first_name' from public.managed_identities mi where mi.member_id = p_member_id), ''), 120); end if;
    if v_last = '' then v_last := left(coalesce((select mi.identity->>'last_name' from public.managed_identities mi where mi.member_id = p_member_id), ''), 120); end if;
    delete from public.invitations where member_id = p_member_id and redeemed_at is null;
  end if;

  if v_also then
    select * into v_ws from public.workspaces where id = p_workspace_id;
    if v_ws.pair_id is null or v_ws.environment <> 'dev' then
      raise exception 'this workspace has no production twin to join';
    end if;
    v_role := case when p_is_admin then 'admin' else 'member' end;
    if not public.role_holds(
         (select id from public.workspaces
           where pair_id = v_ws.pair_id and environment = 'prod'
             and id <> v_ws.id limit 1),
         v_role, 'accessProd') then
      raise exception
        'the % role has no access to the production workspace', v_role;
    end if;
  end if;

  insert into public.invitations
    (workspace_id, is_admin, invited_first_name, invited_last_name,
     created_by, member_id, also_prod)
  values (p_workspace_id, p_is_admin, v_first, v_last, auth.uid(),
          p_member_id, v_also)
  returning code into v_code;
  return v_code;
end;
$function$;

revoke execute on function public.create_invitation(uuid, boolean, text, text, uuid, boolean)
  from public, anon;
grant execute on function public.create_invitation(uuid, boolean, text, text, uuid, boolean)
  to authenticated;

-- ── closure days, generated and imported ───────────────────────────────
create or replace function public.generate_closure_days(p_workspace_id uuid, p_country text, p_year integer, p_apply boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_locked text[]; v_created int := 0; v_days jsonb;
begin
  -- #2137 -- the Availability screen's permission, as closure_days asks.
  if not (public.is_owner_of(p_workspace_id)
          or public.has_permission(p_workspace_id, 'workspaceSettings')) then
    raise exception 'only an owner may generate closure days'
      using errcode = '42501';
  end if;

  select coalesce(array_agg(distinct i.period), '{}')
    into v_locked
    from public.invoices i
   where i.workspace_id = p_workspace_id
     and i.period in (select distinct to_char(h.day, 'YYYY-MM')
                        from public.public_holidays(p_country, p_year) h);

  select coalesce(jsonb_agg(jsonb_build_object(
           'day', h.day, 'key', h.key,
           'locked', to_char(h.day, 'YYYY-MM') = any (v_locked),
           'present', exists (select 1 from public.closure_days c
                               where c.workspace_id = p_workspace_id
                                 and c.day = h.day)
         ) order by h.day), '[]'::jsonb)
    into v_days
    from public.public_holidays(p_country, p_year) h;

  if p_apply then
    insert into public.closure_days (workspace_id, day, reason)
    select p_workspace_id, h.day, h.key
      from public.public_holidays(p_country, p_year) h
     where not (to_char(h.day, 'YYYY-MM') = any (v_locked))
       and not exists (select 1 from public.closure_days c
                        where c.workspace_id = p_workspace_id
                          and c.day = h.day);
    get diagnostics v_created = row_count;
  end if;

  return jsonb_build_object('days', v_days,
                            'locked_months', to_jsonb(v_locked),
                            'created', v_created);
end
$function$;

revoke execute on function public.generate_closure_days(uuid, text, integer, boolean)
  from public, anon;
grant execute on function public.generate_closure_days(uuid, text, integer, boolean)
  to authenticated;

create or replace function public.import_closure_days(p_workspace_id uuid, p_days jsonb, p_apply boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_dates date[]; v_names text[]; v_locked text[];
  v_created int := 0; v_days jsonb;
begin
  -- Exactly the rule `closure_days` writes carry: the owner, or whoever
  -- holds workspaceSettings (#2137).
  if not (public.is_owner_of(p_workspace_id)
          or public.has_permission(p_workspace_id, 'workspaceSettings')) then
    raise exception 'only an owner may import closure days'
      using errcode = '42501';
  end if;
  if not public.feature_effective(p_workspace_id, 'holidayImport') then
    raise exception 'holiday import is not enabled for this workspace'
      using errcode = '42501';
  end if;
  if jsonb_typeof(p_days) is distinct from 'array'
     or jsonb_array_length(p_days) > 400 then
    raise exception 'p_days must be a list of at most 400 days'
      using errcode = '22023';
  end if;

  -- One row per date (closure_days is unique per workspace and day); a
  -- malformed date is refused by the cast, never guessed.
  select coalesce(array_agg(x.day order by x.day), '{}'),
         coalesce(array_agg(x.name order by x.day), '{}')
    into v_dates, v_names
    from (select distinct on ((e->>'day')::date)
                 (e->>'day')::date as day,
                 left(btrim(coalesce(e->>'name', '')), 200) as name
            from jsonb_array_elements(p_days) e
           order by (e->>'day')::date) x;

  -- Invoiced months are SKIPPED and NAMED, voided invoices included
  -- (#1274): an import never changes a bill already issued.
  select coalesce(array_agg(distinct i.period), '{}')
    into v_locked
    from public.invoices i
   where i.workspace_id = p_workspace_id
     and i.period in (select distinct to_char(d, 'YYYY-MM')
                        from unnest(v_dates) d);

  select coalesce(jsonb_agg(jsonb_build_object(
           'day', h.day, 'key', h.name,
           'locked', to_char(h.day, 'YYYY-MM') = any (v_locked),
           'present', exists (select 1 from public.closure_days c
                               where c.workspace_id = p_workspace_id
                                 and c.day = h.day)
         ) order by h.day), '[]'::jsonb)
    into v_days
    from unnest(v_dates, v_names) as h(day, name);

  if p_apply then
    insert into public.closure_days (workspace_id, day, reason)
    select p_workspace_id, h.day, h.name
      from unnest(v_dates, v_names) as h(day, name)
     where not (to_char(h.day, 'YYYY-MM') = any (v_locked))
    on conflict (workspace_id, day) do nothing;
    get diagnostics v_created = row_count;
  end if;

  return jsonb_build_object('days', v_days,
                            'locked_months', to_jsonb(v_locked),
                            'created', v_created);
end
$function$;

revoke execute on function public.import_closure_days(uuid, jsonb, boolean)
  from public, anon;
grant execute on function public.import_closure_days(uuid, jsonb, boolean)
  to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(358);
