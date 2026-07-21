-- SPDX-License-Identifier: 0BSD
-- Day packages (epic: subscription over-consumption). NOT YET applied to
-- the hosted reference project — the orchestrator applies it after review.
--
-- Completes migration 0041's 'package' over-consumption policy: the owner
-- pre-defines packages (a number of days for a price); a member whose
-- policy is 'package' buys one self-service once their monthly days run
-- out. Buying is immediate — it raises the member's cap for the current
-- period (a quota_extensions row of days x 2 half-days) and posts the
-- price as a ledger charge on their bill. No approval step: defining the
-- packages IS the owner's approval.

-- 1. the 'package' ledger category, so a purchase has an honest bill line
alter table public.ledger_entries drop constraint ledger_entries_category_check;
alter table public.ledger_entries add constraint ledger_entries_category_check
  check (category in ('subscription','overage','expense','payment','adjustment','service','package'));

-- 2. owner-defined packages
create table public.packages (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 80),
  days int not null check (days between 1 and 365),
  price_cents int not null check (price_cents >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create index packages_workspace_idx on public.packages (workspace_id);

alter table public.packages enable row level security;
-- members read active packages (the buy sheet); admins/owners read all
-- (the editor). Only owners write.
create policy packages_select on public.packages
  for select using (
    public.is_admin_of(workspace_id)
    or (active and exists (
      select 1 from public.members m
      where m.workspace_id = packages.workspace_id
        and m.user_id = auth.uid() and m.status = 'active'))
  );
create policy packages_write on public.packages
  for all using (public.is_owner_of(workspace_id))
  with check (public.is_owner_of(workspace_id));

-- 3. buy a package: raises the member's cap and charges the price. Only a
-- member whose over-consumption policy is 'package' may buy — that is the
-- gate the owner set in 0041. Self-service and immediate.
create or replace function public.buy_package(
  p_workspace_id uuid, p_package_id uuid
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_member public.members;
  v_pkg public.packages;
  v_tz text;
  v_period text;
  v_ext_id uuid;
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

  -- raise the cap for the current period (days x 2 half-days). Reuses the
  -- quota_extensions machinery the guard already reads (0031/0041).
  insert into public.quota_extensions
    (workspace_id, member_id, period, half_days)
  values (p_workspace_id, v_member.id, v_period, v_pkg.days * 2)
  returning id into v_ext_id;

  -- and post the price as a charge on this period's bill
  insert into public.ledger_entries
    (workspace_id, member_id, kind, category, amount_cents, description, period)
  values (
    p_workspace_id, v_member.id, 'charge', 'package', v_pkg.price_cents,
    v_pkg.name || ' (' || v_pkg.days || 'd)', v_period
  );

  return v_ext_id;
end;
$$;
revoke execute on function public.buy_package(uuid, uuid) from public, anon;
