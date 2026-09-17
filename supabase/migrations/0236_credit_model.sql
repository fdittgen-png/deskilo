-- SPDX-License-Identifier: 0BSD
-- risk: additive
--
-- 0236 (#1279 S2) — carnets: prepaid half-days that outlive the month.
--
-- A spontaneous visitor with no subscription (0235) buys a carnet of ten
-- half-days and spends it over any number of months. It is charged ONCE,
-- at the sale; spending it (S3) posts nothing.
--
--   * `credit_products` — what a workspace sells: name, half-days (1..500),
--     price, validity in months (null = never expires — the proposal to the
--     responsable), active, VAT rate. Readable like `packages`: by whoever
--     manages services, and — active ones — by every active member.
--   * `member_credits` — one sale (or gift, or compensation): how many
--     half-days, when, until when, at what price, and the ledger entry that
--     charged it. No client write policy: only `sell_credit` writes, the
--     `quota_extensions` precedent.
--   * `member_credit_uses` — a reservation drawing half-days from a credit;
--     `released_at` when the reservation stops counting (S3). One live use
--     per (reservation, credit): a retried booking cannot consume twice.
--
-- The sale posts a ledger CHARGE in the existing `package` category — a
-- prepaid pack of days is what that category already means — so
-- `invoice_lines_for`, `member_statement` and the reconciliation read it
-- exactly as they read a day package today, with no new category to teach
-- them.

create table if not exists public.credit_products (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  name text not null check (btrim(name) <> ''),
  half_days int not null check (half_days between 1 and 500),
  price_cents int not null default 0 check (price_cents >= 0),
  validity_months int check (validity_months is null or validity_months between 1 and 120),
  active boolean not null default true,
  vat_rate_id uuid references public.vat_rates(id) on delete set null,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);
select public.ensure_system_columns('credit_products');
create unique index if not exists credit_products_workspace_name
  on public.credit_products (workspace_id, name);

alter table public.credit_products enable row level security;
drop policy if exists credit_products_select on public.credit_products;
create policy credit_products_select on public.credit_products
  for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['manageServices']))
         or (active and exists (select 1 from public.members m
                                 where m.workspace_id = credit_products.workspace_id
                                   and m.user_id = auth.uid() and m.status = 'active')));
drop policy if exists credit_products_write on public.credit_products;
create policy credit_products_write on public.credit_products
  for all to authenticated
  using (public.is_owner_of(workspace_id))
  with check (public.is_owner_of(workspace_id));
revoke all on table public.credit_products from anon;
grant select, insert, update, delete on table public.credit_products to authenticated;

create table if not exists public.member_credits (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete cascade,
  product_id uuid references public.credit_products(id) on delete set null,
  half_days int not null check (half_days between 1 and 500),
  purchased_at timestamptz not null default now(),
  expires_at timestamptz,
  source text not null default 'carnet' check (source in ('carnet', 'gift', 'compensation')),
  price_cents int not null default 0 check (price_cents >= 0),
  vat_rate_id uuid references public.vat_rates(id) on delete set null,
  ledger_entry_id uuid references public.ledger_entries(id) on delete set null,
  check (expires_at is null or expires_at > purchased_at)
);
select public.ensure_system_columns('member_credits');
create index if not exists member_credits_member on public.member_credits (member_id, expires_at);

alter table public.member_credits enable row level security;
drop policy if exists member_credits_select on public.member_credits;
create policy member_credits_select on public.member_credits
  for select to authenticated
  using (exists (select 1 from public.members m
                  where m.id = member_credits.member_id and m.user_id = auth.uid())
         or public.has_permission(workspace_id, 'viewFinances'));
revoke all on table public.member_credits from anon, authenticated;
grant select on table public.member_credits to authenticated;

create table if not exists public.member_credit_uses (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  credit_id uuid not null references public.member_credits(id) on delete cascade,
  reservation_id uuid not null references public.reservations(id) on delete cascade,
  half_days int not null check (half_days between 1 and 500),
  created_at timestamptz not null default now(),
  released_at timestamptz
);
select public.ensure_system_columns('member_credit_uses');
create unique index if not exists member_credit_uses_live
  on public.member_credit_uses (reservation_id, credit_id) where released_at is null;

alter table public.member_credit_uses enable row level security;
drop policy if exists member_credit_uses_select on public.member_credit_uses;
create policy member_credit_uses_select on public.member_credit_uses
  for select to authenticated
  using (exists (select 1 from public.member_credits c
                   join public.members m on m.id = c.member_id
                  where c.id = member_credit_uses.credit_id and m.user_id = auth.uid())
         or public.has_permission(workspace_id, 'viewFinances'));
revoke all on table public.member_credit_uses from anon, authenticated;
grant select on table public.member_credit_uses to authenticated;

-- ── what is left to spend ──────────────────────────────────────────────
-- The arithmetic, for the booking path (S3) to call inside its own checks;
-- no client may call it directly.
create or replace function public.member_credit_balance_of(p_member_id uuid, p_at timestamptz default now())
returns int
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(sum(c.half_days - coalesce((
           select sum(u.half_days) from public.member_credit_uses u
            where u.credit_id = c.id and u.released_at is null), 0)), 0)::int
    from public.member_credits c
   where c.member_id = p_member_id
     and (c.expires_at is null or c.expires_at > p_at);
$$;

revoke execute on function public.member_credit_balance_of(uuid, timestamptz)
  from public, anon, authenticated;

-- What a person may ask: their own balance, or anyone's if they see the
-- workspace's finances or sell carnets.
create or replace function public.member_credit_balance(p_member_id uuid, p_at timestamptz default now())
returns int
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not exists (
       select 1 from public.members m
        where m.id = p_member_id
          and (m.user_id = auth.uid()
               or public.has_permission(m.workspace_id, 'viewFinances')
               or public.has_permission(m.workspace_id, 'issueInvoices'))) then
    raise exception 'not allowed to read this member''s carnets';
  end if;
  return public.member_credit_balance_of(p_member_id, p_at);
end;
$$;

revoke execute on function public.member_credit_balance(uuid, timestamptz) from public, anon;
grant execute on function public.member_credit_balance(uuid, timestamptz) to authenticated;

-- ── selling a carnet ───────────────────────────────────────────────────
create or replace function public.sell_credit(
  p_workspace_id uuid, p_member_id uuid, p_product_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_member public.members;
  v_product public.credit_products;
  v_tz text;
  v_period text;
  v_vat numeric;
  v_ledger uuid;
  v_credit uuid;
begin
  if auth.uid() is null or not public.has_permission(p_workspace_id, 'issueInvoices') then
    raise exception 'only someone who issues invoices sells a carnet';
  end if;
  select * into v_member from public.members
   where id = p_member_id and workspace_id = p_workspace_id and status = 'active';
  if v_member.id is null then
    raise exception 'not an active member of this workspace';
  end if;
  select * into v_product from public.credit_products
   where id = p_product_id and workspace_id = p_workspace_id and active;
  if v_product.id is null then
    raise exception 'unknown or inactive carnet';
  end if;

  select timezone into v_tz from public.workspaces where id = p_workspace_id;
  v_period := to_char(now() at time zone v_tz, 'YYYY-MM');
  if public.workspace_charges_vat(p_workspace_id) then
    select coalesce(public.vat_rate_percent_at(v_product.vat_rate_id, current_date),
                    public.workspace_default_vat_percent(p_workspace_id))
      into v_vat;
  else
    v_vat := 0;
  end if;

  insert into public.ledger_entries
    (workspace_id, member_id, kind, category, amount_cents, description, period, vat_percent)
  values (p_workspace_id, p_member_id, 'charge', 'package', v_product.price_cents,
          v_product.name, v_period, v_vat)
  returning id into v_ledger;

  insert into public.member_credits
    (workspace_id, member_id, product_id, half_days, purchased_at, expires_at,
     source, price_cents, vat_rate_id, ledger_entry_id)
  values (p_workspace_id, p_member_id, v_product.id, v_product.half_days, now(),
          case when v_product.validity_months is null then null
               else now() + make_interval(months => v_product.validity_months) end,
          'carnet', v_product.price_cents, v_product.vat_rate_id, v_ledger)
  returning id into v_credit;
  return v_credit;
end $fn$;

revoke execute on function public.sell_credit(uuid, uuid, uuid) from public, anon;
grant execute on function public.sell_credit(uuid, uuid, uuid) to authenticated;

-- ── the subject-access export carries them ─────────────────────────────
-- Restated from 0209 (no migration since has touched it), with the two
-- tables a member's carnets live in.
create or replace function public.export_my_data(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer
set search_path = public as $$
declare
  v_me public.members;
begin
  v_me := public.my_active_member(p_workspace_id);
  return jsonb_build_object(
    'exported_at', now(),
    'member', to_jsonb(v_me) - 'user_id',
    'profile', (select to_jsonb(p) - 'pin_hash' from public.profiles p where p.id = v_me.user_id),
    'reservations', (select coalesce(jsonb_agg(to_jsonb(r)), '[]') from public.reservations r
                      where r.member_id = v_me.id),
    'ledger', (select coalesce(jsonb_agg(to_jsonb(l)), '[]') from public.ledger_entries l
                where l.member_id = v_me.id),
    'invoices', (select coalesce(jsonb_agg(to_jsonb(i)), '[]') from public.invoices i
                  where i.member_id = v_me.id),
    'messages_sent', (select coalesce(jsonb_agg(to_jsonb(n)), '[]') from public.member_notes n
                       where n.from_member_id = v_me.id),
    'events', (select coalesce(jsonb_agg(to_jsonb(e)), '[]') from public.events e
                where e.actor_member_id = v_me.id or e.subject_member_id = v_me.id),
    'access_log', (select coalesce(jsonb_agg(to_jsonb(a)), '[]') from public.data_access_log a
                    where a.subject_member_id = v_me.id),
    -- #1238 — the six added.
    'price_negotiations', (select coalesce(jsonb_agg(to_jsonb(n)), '[]')
                            from public.price_negotiations n
                            where n.member_id = v_me.id),
    'quota_extensions', (select coalesce(jsonb_agg(to_jsonb(q)), '[]')
                          from public.quota_extensions q
                          where q.member_id = v_me.id),
    'usage_records', (select coalesce(jsonb_agg(to_jsonb(u)), '[]')
                       from public.usage_records u
                       where u.member_id = v_me.id),
    'payments', (select coalesce(jsonb_agg(to_jsonb(p)), '[]')
                  from public.payment_intents p
                  where p.member_id = v_me.id),
    'decisions_i_made', (select coalesce(jsonb_agg(to_jsonb(d)), '[]')
                          from public.event_decisions d
                          where d.member_id = v_me.id),
    -- The FACT of a credential, never the credential. A hash in an
    -- export is a hash on somebody's laptop.
    'badges', (select coalesce(jsonb_agg(jsonb_build_object(
                        'id', b.id,
                        'kind', b.kind,
                        'label', b.label,
                        'created_at', b.created_at,
                        'revoked_at', b.revoked_at)), '[]')
                from public.member_badges b
                where b.member_id = v_me.id),
    -- #1279 — the carnets bought or given to them, and what they spent.
    'member_credits', (select coalesce(jsonb_agg(to_jsonb(c)), '[]')
                        from public.member_credits c
                        where c.member_id = v_me.id),
    'member_credit_uses', (select coalesce(jsonb_agg(to_jsonb(u)), '[]')
                            from public.member_credit_uses u
                            join public.member_credits c on c.id = u.credit_id
                            where c.member_id = v_me.id)
  );
end;
$$;

revoke execute on function public.export_my_data(uuid) from public, anon;
grant execute on function public.export_my_data(uuid) to authenticated;

select public.set_deskilo_schema_version(236);
