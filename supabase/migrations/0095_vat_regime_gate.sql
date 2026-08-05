-- SPDX-License-Identifier: 0BSD
-- VAT follows the DECLARED REGIME (#484): only a workspace declared
-- vat_registered ever stamps a rate onto a charge. Before this, VAT was
-- driven purely by whether rates existed — an exempt workspace (a
-- French association under art. 261-7-1° / 293 B CGI, a franchise en
-- base business…) with leftover rates would still tax its members. Now
-- the regime gates every chokepoint: statement-derived invoice lines
-- (via workspace_default_vat_percent), service charges and package
-- purchases (their per-item rate lookup). Already-issued invoices keep
-- their signed snapshots untouched.

-- 1. True only for a workspace that declared it charges VAT.
create or replace function public.workspace_charges_vat(
  p_workspace_id uuid
) returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.workspaces
    where id = p_workspace_id and vat_regime = 'vat_registered');
$$;
revoke execute on function public.workspace_charges_vat(uuid)
  from public, anon;

-- 2. workspace_default_vat_percent v2: 0 unless the regime charges VAT.
create or replace function public.workspace_default_vat_percent(
  p_workspace_id uuid
) returns numeric language sql stable security definer set search_path = public as $$
  select case when public.workspace_charges_vat(p_workspace_id) then
    coalesce(
      (select percent from public.vat_rates
        where workspace_id = p_workspace_id and is_default and active
        limit 1), 0)
  else 0 end;
$$;

-- 3. record_service_charge v4: the 0072 body, the service's own rate
-- honored only under a VAT-charging regime.
create or replace function public.record_service_charge(
  p_workspace_id uuid,
  p_subject_member_id uuid,
  p_service_id uuid,
  p_quantity int,
  p_period text default null
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_actor public.members;
  v_service public.services;
  v_period text;
  v_event_id uuid;
  v_vat numeric;
begin
  select * into v_actor from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid() and status = 'active';
  if v_actor.id is null then raise exception 'not an active member'; end if;
  if v_actor.id <> p_subject_member_id and not (v_actor.is_admin or v_actor.is_owner) then
    raise exception 'only admins may add services for other members';
  end if;
  if not exists (
    select 1 from public.members
    where id = p_subject_member_id and workspace_id = p_workspace_id and status = 'active'
  ) then raise exception 'unknown subject member'; end if;

  select * into v_service from public.services
    where id = p_service_id and workspace_id = p_workspace_id;
  if v_service.id is null then raise exception 'unknown service'; end if;
  if not v_service.active then raise exception 'service is inactive'; end if;
  if p_quantity is null or p_quantity < 1 or p_quantity > 999 then
    raise exception 'quantity must be between 1 and 999';
  end if;
  v_period := coalesce(p_period, to_char(now(), 'YYYY-MM'));
  if v_period !~ '^\d{4}-\d{2}$' then raise exception 'period must be YYYY-MM'; end if;

  -- The service's own rate, else the workspace default — and 0 whenever
  -- the declared regime charges no VAT (0095).
  if public.workspace_charges_vat(p_workspace_id) then
    select coalesce(
        (select percent from public.vat_rates
          where id = v_service.vat_rate_id and active),
        public.workspace_default_vat_percent(p_workspace_id))
      into v_vat;
  else
    v_vat := 0;
  end if;

  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
  values (
    p_workspace_id, 'service_charge', 'submitted', v_actor.id, p_subject_member_id,
    jsonb_build_object(
      'service_id', v_service.id,
      'name', v_service.name,
      'price_cents', v_service.price_cents,
      'quantity', p_quantity,
      'amount_cents', v_service.price_cents * p_quantity,
      'vat_percent', v_vat,
      'period', v_period
    ),
    'pending'
  ) returning id into v_event_id;
  return v_event_id;
end;
$$;
revoke execute on function
  public.record_service_charge(uuid, uuid, uuid, int, text) from public, anon;

-- 4. buy_package v3: same gate on the package's rate.
create or replace function public.buy_package(
  p_workspace_id uuid, p_package_id uuid
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_member public.members;
  v_pkg public.packages;
  v_tz text;
  v_period text;
  v_ext_id uuid;
  v_vat numeric;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  select * into v_member from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid() and status = 'active';
  if v_member.id is null then raise exception 'not an active member'; end if;
  if coalesce(v_member.overage_policy, 'blocked') <> 'package' then
    raise exception 'member is not on the package plan';
  end if;

  select * into v_pkg from public.packages
    where id = p_package_id and workspace_id = p_workspace_id and active;
  if v_pkg.id is null then raise exception 'unknown or inactive package'; end if;

  select timezone into v_tz from public.workspaces where id = p_workspace_id;
  v_period := to_char(now() at time zone v_tz, 'YYYY-MM');

  insert into public.quota_extensions
    (workspace_id, member_id, period, half_days)
  values (p_workspace_id, v_member.id, v_period, v_pkg.days * 2)
  returning id into v_ext_id;

  if public.workspace_charges_vat(p_workspace_id) then
    select coalesce(
        (select percent from public.vat_rates
          where id = v_pkg.vat_rate_id and active),
        public.workspace_default_vat_percent(p_workspace_id))
      into v_vat;
  else
    v_vat := 0;
  end if;

  insert into public.ledger_entries
    (workspace_id, member_id, kind, category, amount_cents, description,
     period, vat_percent)
  values (
    p_workspace_id, v_member.id, 'charge', 'package', v_pkg.price_cents,
    v_pkg.name || ' (' || v_pkg.days || 'd)', v_period, v_vat
  );

  return v_ext_id;
end;
$$;
revoke execute on function public.buy_package(uuid, uuid) from public, anon;
