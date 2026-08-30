-- SPDX-License-Identifier: 0BSD
--
-- #744 PRICE NEGOTIATIONS v2 — the deal reaches the two things #739 left
-- at the catalogue: the OCCUPATION (the member's subscription percentage,
-- negotiated together with its monthly price — the tariff IS
-- percentage × price) and the ITEMS (a unit price per service and per
-- package). Items apply where the price is fixed — record_service_charge
-- and buy_package take the member's active deal into account — so the
-- ledger, the bill and the invoice carry the negotiated amount without
-- any of them knowing why. The percentage is applied to the member on
-- validation, the previous one kept on the deal for the comparison.

alter table public.price_negotiations
  add column if not exists subscription_pct int
    check (subscription_pct is null or subscription_pct between 1 and 100),
  add column if not exists previous_subscription_pct int,
  add column if not exists items jsonb not null default '{}'::jsonb;

alter table public.price_negotiations
  drop constraint if exists price_negotiations_check;
alter table public.price_negotiations add constraint price_negotiations_check
  check (fee_cents is not null or overage_fee_cents is not null
         or discount_percent is not null or subscription_pct is not null
         or items <> '{}'::jsonb);

-- The unit price of [p_item] ('services'/'packages' × id) for a member:
-- the active deal's, or null.
create or replace function public.negotiated_item_price(
  p_member_id uuid, p_kind text, p_item_id uuid
) returns int language sql stable security definer set search_path = public as $$
  select (n.items -> p_kind ->> p_item_id::text)::int
    from public.price_negotiations n
   where n.member_id = p_member_id and n.status = 'active'
     and n.valid_from <= current_date
   limit 1;
$$;
revoke execute on function public.negotiated_item_price(uuid, text, uuid) from public, anon;
grant execute on function public.negotiated_item_price(uuid, text, uuid) to authenticated;

-- ---------------------------------------------------------------- propose v2
drop function if exists public.propose_price_negotiation(uuid, int, int, numeric, text, date);
create or replace function public.propose_price_negotiation(
  p_member_id uuid,
  p_fee_cents int default null,
  p_overage_fee_cents int default null,
  p_discount_percent numeric default null,
  p_note text default '',
  p_valid_from date default null,
  p_subscription_pct int default null,
  p_items jsonb default '{}'::jsonb
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_member public.members;
  v_actor public.members;
  v_valid_from date;
  v_event_id uuid;
  v_id uuid;
  v_items jsonb := coalesce(p_items, '{}'::jsonb);
  v_kind text;
  v_key text;
  v_val jsonb;
begin
  select * into v_member from public.members where id = p_member_id;
  if v_member.id is null then raise exception 'unknown member'; end if;
  select * into v_actor from public.members
    where workspace_id = v_member.workspace_id and user_id = auth.uid() and status = 'active';
  if v_actor.id is null then raise exception 'not an active member'; end if;
  if not (v_actor.is_owner or public.has_permission(v_member.workspace_id, 'viewFinances')) then
    raise exception 'only the owner or a finance admin may propose a deal';
  end if;
  if v_actor.id = v_member.id then
    raise exception 'a deal is proposed for someone else';
  end if;
  if not coalesce((select w.feature_flags ->> 'priceNegotiations' from public.workspaces w
                    where w.id = v_member.workspace_id)::boolean, true) then
    raise exception 'price negotiations are off in this workspace';
  end if;
  if p_subscription_pct is not null and p_subscription_pct not between 1 and 100 then
    raise exception 'occupation must be between 1 and 100 percent';
  end if;
  -- Items: only services/packages of this workspace, whole non-negative cents.
  for v_kind, v_val in select * from jsonb_each(v_items) loop
    if v_kind not in ('services', 'packages') then
      raise exception 'unknown item kind %', v_kind;
    end if;
    for v_key in select jsonb_object_keys(v_val) loop
      if (v_val ->> v_key) !~ '^\d+$' then
        raise exception 'item price must be whole cents';
      end if;
      if v_kind = 'services' and not exists (select 1 from public.services s
           where s.id = v_key::uuid and s.workspace_id = v_member.workspace_id) then
        raise exception 'unknown service %', v_key;
      end if;
      if v_kind = 'packages' and not exists (select 1 from public.packages p
           where p.id = v_key::uuid and p.workspace_id = v_member.workspace_id) then
        raise exception 'unknown package %', v_key;
      end if;
    end loop;
  end loop;
  if p_fee_cents is null and p_overage_fee_cents is null and p_discount_percent is null
     and p_subscription_pct is null and v_items = '{}'::jsonb then
    raise exception 'nothing negotiated';
  end if;
  if exists (select 1 from public.price_negotiations
              where member_id = p_member_id and status = 'pending') then
    raise exception 'a proposal is already awaiting validation';
  end if;
  v_valid_from := coalesce(p_valid_from, date_trunc('month', now())::date);

  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
  values (
    v_member.workspace_id, 'price_negotiation', 'submitted', v_actor.id, v_member.id,
    jsonb_build_object(
      'fee_cents', p_fee_cents,
      'overage_fee_cents', p_overage_fee_cents,
      'discount_percent', p_discount_percent,
      'subscription_pct', p_subscription_pct,
      'previous_subscription_pct', v_member.subscription_pct,
      'items', v_items,
      'item_count', (select count(*) from jsonb_each(coalesce(v_items -> 'services', '{}'::jsonb)))
                  + (select count(*) from jsonb_each(coalesce(v_items -> 'packages', '{}'::jsonb))),
      'note', coalesce(p_note, ''),
      'valid_from', v_valid_from,
      'default', public.default_tariff_of(p_member_id)),
    'pending')
  returning id into v_event_id;

  insert into public.price_negotiations
    (workspace_id, member_id, fee_cents, overage_fee_cents, discount_percent,
     subscription_pct, previous_subscription_pct, items,
     note, valid_from, status, event_id, proposed_by)
  values (v_member.workspace_id, v_member.id, p_fee_cents, p_overage_fee_cents,
          p_discount_percent, p_subscription_pct, v_member.subscription_pct, v_items,
          coalesce(p_note, ''), v_valid_from, 'pending', v_event_id, v_actor.id)
  returning id into v_id;
  return v_id;
end;
$$;
revoke execute on function public.propose_price_negotiation(uuid, int, int, numeric, text, date, int, jsonb) from public, anon;
grant execute on function public.propose_price_negotiation(uuid, int, int, numeric, text, date, int, jsonb) to authenticated;

-- ---------------------------------------------------------------- decide → activate (+ occupation)
create or replace function public.apply_negotiation_on_decision()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_deal public.price_negotiations;
begin
  if new.type <> 'price_negotiation' or new.status = old.status then return new; end if;
  if new.status = 'confirmed' then
    update public.price_negotiations set status = 'superseded', decided_at = now()
     where member_id = new.subject_member_id and status = 'active';
    update public.price_negotiations set status = 'active', decided_at = now()
     where event_id = new.id and status = 'pending'
     returning * into v_deal;
    -- #744 — the occupation is part of the deal: applied on validation,
    -- the previous value kept for the comparison.
    if v_deal.id is not null and v_deal.subscription_pct is not null then
      update public.price_negotiations
         set previous_subscription_pct = (select subscription_pct from public.members where id = v_deal.member_id)
       where id = v_deal.id;
      update public.members set subscription_pct = v_deal.subscription_pct
       where id = v_deal.member_id;
    end if;
  elsif new.status in ('rejected', 'expired') then
    update public.price_negotiations set status = 'rejected', decided_at = now()
     where event_id = new.id and status = 'pending';
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------- items applied where the price is fixed
do $$
declare
  v_def text;
  v_old_decl text := $o$  v_service public.services;$o$;
  v_new_decl text := $n$  v_service public.services;
  v_unit int;$n$;
  v_old_price text := $o$      'price_cents', v_service.price_cents,
      'quantity', p_quantity,
      'amount_cents', v_service.price_cents * p_quantity,$o$;
  v_new_price text := $n$      'price_cents', v_unit,
      'catalogue_price_cents', v_service.price_cents,
      'quantity', p_quantity,
      'amount_cents', v_unit * p_quantity,$n$;
  v_old_period text := $o$  v_period := coalesce(p_period, to_char(now(), 'YYYY-MM'));$o$;
  v_new_period text := $n$  -- #744 — the member's negotiated unit price, the catalogue otherwise.
  v_unit := coalesce(public.negotiated_item_price(p_subject_member_id, 'services', v_service.id),
                     v_service.price_cents);
  v_period := coalesce(p_period, to_char(now(), 'YYYY-MM'));$n$;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'record_service_charge';
  if v_def is null then raise exception 'record_service_charge missing'; end if;
  if position(v_old_decl in v_def) = 0 then raise exception 'declare anchor not found'; end if;
  if position(v_old_price in v_def) = 0 then raise exception 'price anchor not found'; end if;
  if position(v_old_period in v_def) = 0 then raise exception 'period anchor not found'; end if;
  v_def := replace(v_def, v_old_decl, v_new_decl);
  v_def := replace(v_def, v_old_price, v_new_price);
  v_def := replace(v_def, v_old_period, v_new_period);
  execute v_def;
end $$;

do $$
declare
  v_def text;
  v_old_decl text := $o$  v_vat numeric;$o$;
  v_new_decl text := $n$  v_vat numeric;
  v_unit int;$n$;
  v_old_ins text := $o$    p_workspace_id, v_member.id, 'charge', 'package', v_pkg.price_cents,$o$;
  v_new_ins text := $n$    p_workspace_id, v_member.id, 'charge', 'package', v_unit,$n$;
  v_old_tz text := $o$  select timezone into v_tz from public.workspaces where id = p_workspace_id;$o$;
  v_new_tz text := $n$  -- #744 — the member's negotiated package price, the catalogue otherwise.
  v_unit := coalesce(public.negotiated_item_price(v_member.id, 'packages', v_pkg.id),
                     v_pkg.price_cents);
  select timezone into v_tz from public.workspaces where id = p_workspace_id;$n$;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'buy_package';
  if v_def is null then raise exception 'buy_package missing'; end if;
  if position(v_old_decl in v_def) = 0 then raise exception 'buy_package declare anchor not found'; end if;
  if position(v_old_ins in v_def) = 0 then raise exception 'buy_package insert anchor not found'; end if;
  if position(v_old_tz in v_def) = 0 then raise exception 'buy_package tz anchor not found'; end if;
  v_def := replace(v_def, v_old_decl, v_new_decl);
  v_def := replace(v_def, v_old_ins, v_new_ins);
  v_def := replace(v_def, v_old_tz, v_new_tz);
  execute v_def;
end $$;
