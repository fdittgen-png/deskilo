-- SPDX-License-Identifier: 0BSD
--
-- #731 SUPPLIES — an expense that puts something on the shelf. A member
-- buys vacuum bags or coffee capsules for the space, submits the expense
-- as usual, and says WHAT it is and HOW MANY: once the expense is
-- validated, the reimbursement credits the buyer (as before) AND the
-- item becomes (or restocks) a consumable service with a unit price, so
-- the members who use it pay for it through "Add a consumption". Stock
-- counts down with every confirmed consumption; at zero the item cannot
-- be consumed until the next supply.
--
-- #732 VALIDATOR SCOPES — who validates, by role or by person. The rule
-- (0017) knew the owner, "admins" (optionally a listed subset) and the
-- count. Now a rule names its SCOPE:
--   admins   — the owner and the admins (the listed subset when set);
--   listed   — the owner and exactly the listed persons, whatever their
--              role (a member can be a validator);
--   members  — the owner and every active member.
-- Count and owner sign-off keep their meaning; "nobody validates their
-- own event" (0086) keeps its meaning. respond_to_event is patched IN
-- PLACE (pg_get_functiondef + replace, asserted) so every later
-- amendment of that function stays in force.

-- ---------------------------------------------------------------- stock
alter table public.services
  add column if not exists stock int
    check (stock is null or stock >= 0);
comment on column public.services.stock is
  '#731 — units on the shelf; null = not tracked (a service, not a supply).';

-- ---------------------------------------------------------------- scope
alter table public.validation_policies
  add column if not exists validator_scope text not null default 'admins'
    check (validator_scope in ('admins','listed','members'));

-- ---------------------------------------------------------------- expense v2
create or replace function public.submit_expense(
  p_workspace_id uuid,
  p_amount_cents int,
  p_category text,
  p_description text default '',
  p_supply jsonb default null
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_actor public.members;
  v_event_id uuid;
  v_supply jsonb := null;
  v_qty int;
  v_unit int;
  v_name text;
  v_service_id uuid;
begin
  select * into v_actor from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid() and status = 'active';
  if v_actor.id is null then raise exception 'not an active member'; end if;
  if p_amount_cents <= 0 then raise exception 'amount must be positive'; end if;
  if p_supply is not null then
    v_qty := (p_supply ->> 'quantity')::int;
    if v_qty is null or v_qty < 1 or v_qty > 9999 then
      raise exception 'supply quantity must be between 1 and 9999';
    end if;
    v_unit := coalesce((p_supply ->> 'unit_price_cents')::int,
                       ceil(p_amount_cents::numeric / v_qty)::int);
    if v_unit < 0 then raise exception 'unit price must not be negative'; end if;
    v_service_id := nullif(p_supply ->> 'service_id', '')::uuid;
    if v_service_id is not null then
      select name into v_name from public.services
        where id = v_service_id and workspace_id = p_workspace_id;
      if v_name is null then raise exception 'unknown service'; end if;
    else
      v_name := trim(coalesce(p_supply ->> 'name', ''));
      if char_length(v_name) between 1 and 80 is not true then
        raise exception 'supply name must be 1–80 characters';
      end if;
    end if;
    v_supply := jsonb_build_object(
      'name', v_name, 'quantity', v_qty, 'unit_price_cents', v_unit,
      'service_id', v_service_id);
  end if;
  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
  values (
    p_workspace_id, 'expense', 'submitted', v_actor.id, v_actor.id,
    jsonb_build_object(
      'amount_cents', p_amount_cents,
      'category', p_category,
      'note', p_description
    ) || case when v_supply is null then '{}'::jsonb
              else jsonb_build_object('supply', v_supply) end,
    'pending'
  ) returning id into v_event_id;
  return v_event_id;
end;
$$;
revoke execute on function public.submit_expense(uuid, int, text, text, jsonb) from public, anon;
grant execute on function public.submit_expense(uuid, int, text, text, jsonb) to authenticated;

-- ---------------------------------------------------------------- stock on confirm
-- The shelf follows the events: a confirmed supply expense restocks (or
-- creates) its service; a confirmed consumption takes from it.
create or replace function public.apply_stock_on_confirm()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_supply jsonb;
  v_service_id uuid;
  v_qty int;
begin
  if new.status <> 'confirmed' or old.status = 'confirmed' then return new; end if;
  if new.type = 'expense' and new.payload ? 'supply' then
    v_supply := new.payload -> 'supply';
    v_qty := coalesce((v_supply ->> 'quantity')::int, 0);
    v_service_id := nullif(v_supply ->> 'service_id', '')::uuid;
    if v_service_id is null then
      select id into v_service_id from public.services
        where workspace_id = new.workspace_id
          and lower(name) = lower(v_supply ->> 'name')
        limit 1;
    end if;
    if v_service_id is null then
      insert into public.services (workspace_id, name, price_cents, active, stock)
      values (new.workspace_id, v_supply ->> 'name',
              coalesce((v_supply ->> 'unit_price_cents')::int, 0), true, v_qty)
      returning id into v_service_id;
    else
      update public.services
         set stock = coalesce(stock, 0) + v_qty,
             active = true,
             price_cents = coalesce((v_supply ->> 'unit_price_cents')::int, price_cents)
       where id = v_service_id;
    end if;
    -- Remember which service the supply landed on (audit, the feed link).
    update public.events
       set payload = payload || jsonb_build_object('supply',
             v_supply || jsonb_build_object('service_id', v_service_id))
     where id = new.id;
  elsif new.type = 'service_charge' then
    update public.services
       set stock = greatest(0, stock - coalesce((new.payload ->> 'quantity')::int, 0))
     where id = nullif(new.payload ->> 'service_id', '')::uuid
       and stock is not null;
  end if;
  return new;
end;
$$;
drop trigger if exists events_apply_stock on public.events;
create trigger events_apply_stock
  after update of status on public.events
  for each row execute function public.apply_stock_on_confirm();

-- A consumption may not take what is not on the shelf.
do $$
declare
  v_def text;
  v_old text := $old$  if not v_service.active then raise exception 'service is inactive'; end if;$old$;
  v_new text := $new$  if not v_service.active then raise exception 'service is inactive'; end if;
  if v_service.stock is not null and v_service.stock < p_quantity then
    raise exception 'out of stock: % left', v_service.stock;
  end if;$new$;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'record_service_charge';
  if v_def is null then raise exception 'record_service_charge missing'; end if;
  -- The quantity check comes AFTER this line in 0016; the stock check
  -- must run once p_quantity is known valid, so it is placed after both.
  if position(v_old in v_def) = 0 then raise exception 'anchor not found in record_service_charge'; end if;
  v_def := replace(v_def, v_old, v_new);
  execute v_def;
end $$;

-- ---------------------------------------------------------------- pool by scope
do $$
declare
  v_def text;
  v_old_m text := $o$(m.is_owner or (m.is_admin and v_policy.admins_may_validate
           and (cardinality(v_policy.eligible_admin_ids) = 0
                or m.id = any(v_policy.eligible_admin_ids))))$o$;
  v_new_m text := $n$(m.is_owner
           or (coalesce(v_policy.validator_scope, 'admins') = 'members')
           or (coalesce(v_policy.validator_scope, 'admins') = 'listed'
               and m.id = any(v_policy.eligible_admin_ids))
           or (coalesce(v_policy.validator_scope, 'admins') = 'admins'
               and m.is_admin and v_policy.admins_may_validate
               and (cardinality(v_policy.eligible_admin_ids) = 0
                    or m.id = any(v_policy.eligible_admin_ids))))$n$;
  v_old_c text := $o$(v_caller.is_owner or (v_caller.is_admin and v_policy.admins_may_validate
                and (cardinality(v_policy.eligible_admin_ids) = 0
                     or v_caller.id = any(v_policy.eligible_admin_ids))))$o$;
  v_new_c text := $n$(v_caller.is_owner
                or (coalesce(v_policy.validator_scope, 'admins') = 'members')
                or (coalesce(v_policy.validator_scope, 'admins') = 'listed'
                    and v_caller.id = any(v_policy.eligible_admin_ids))
                or (coalesce(v_policy.validator_scope, 'admins') = 'admins'
                    and v_caller.is_admin and v_policy.admins_may_validate
                    and (cardinality(v_policy.eligible_admin_ids) = 0
                         or v_caller.id = any(v_policy.eligible_admin_ids))))$n$;
  v_old_solo text := $o$(v_caller.is_owner or (v_caller.is_admin and v_policy.admins_may_validate)) then$o$;
  v_new_solo text := $n$(v_caller.is_owner
         or coalesce(v_policy.validator_scope, 'admins') = 'members'
         or (coalesce(v_policy.validator_scope, 'admins') = 'listed'
             and v_caller.id = any(v_policy.eligible_admin_ids))
         or (v_caller.is_admin and v_policy.admins_may_validate)) then$n$;
  v_old_default text := $o$false as owner_required
      into v_policy;$o$;
  v_new_default text := $n$false as owner_required, 'admins'::text as validator_scope
      into v_policy;$n$;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'respond_to_event';
  if v_def is null then raise exception 'respond_to_event missing'; end if;
  if position(v_old_m in v_def) = 0 then raise exception 'pool anchor (m) not found'; end if;
  if position(v_old_c in v_def) = 0 then raise exception 'pool anchor (caller) not found'; end if;
  if position(v_old_solo in v_def) = 0 then raise exception 'solo anchor not found'; end if;
  if position(v_old_default in v_def) = 0 then raise exception 'default-policy anchor not found'; end if;
  v_def := replace(v_def, v_old_m, v_new_m);
  v_def := replace(v_def, v_old_c, v_new_c);
  v_def := replace(v_def, v_old_solo, v_new_solo);
  v_def := replace(v_def, v_old_default, v_new_default);
  execute v_def;
end $$;
