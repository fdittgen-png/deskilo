-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0674 (#3307, PR A) -- the space's purchase orders to its suppliers.
--
--   * `purchase_orders`: one order to one supplier of the space, numbered by
--     its own series (`year` and `number`, counted per space and year by
--     `purchase_order_counters`, the reference `YYYY-NNNN`), in a currency,
--     with an expected delivery date, a note, the address it is e-mailed to
--     and a revision. State: draft -> sent -> partly_received -> received,
--     or cancelled from draft, sent or partly received; the transitions are
--     the guard's, whoever writes. A sent order keeps how it left
--     (`sent_via` print or email) and when.
--   * `purchase_order_lines`: an item of the catalogue (a service of the
--     space) or free text, the quantity (above zero), the unit, the unit
--     price in minor units and the VAT rate. Frozen once the order is no
--     longer a draft, except what was received of it (the goods receipt,
--     PR C).
--   * `save_purchase_order_v1`: creates or edits a draft; managePurchases
--     while `purchases` and `purchaseOrders` are on; the supplier is an
--     active one of the space; a request id replays its answer; a stale
--     revision is refused.
--   * `mark_purchase_order_sent_v1`: a draft printed and handed over is sent
--     (`sent_via` print). E-mailing goes through the send function (PR B).
--   * `cancel_purchase_order_v1`: with a reason.
--   * Read by RLS: managePurchases or viewFinances in the space; nothing is
--     written directly; a delegated assistant reads and writes nothing.

create table public.purchase_order_counters (
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  year int not null check (year between 2000 and 2999),
  last_number int not null default 0 check (last_number >= 0),
  primary key (workspace_id, year)
);
select public.ensure_system_columns('purchase_order_counters');

create table public.purchase_orders (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  year int not null check (year between 2000 and 2999),
  number int not null check (number >= 1),
  reference text generated always as (year::text || '-' || lpad(number::text, 4, '0')) stored,
  supplier_id uuid not null references public.suppliers(id),
  state text not null default 'draft'
    check (state in ('draft', 'sent', 'partly_received', 'received', 'cancelled')),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  expected_on date,
  note text not null default '' check (char_length(note) <= 1000),
  recipient_email text not null default '' check (char_length(recipient_email) <= 254),
  revision int not null default 1 check (revision >= 1),
  created_by_member_id uuid not null,
  sent_at timestamptz,
  sent_via text check (sent_via in ('print', 'email')),
  cancelled_at timestamptz,
  cancel_reason text not null default '' check (char_length(cancel_reason) <= 300),
  unique (workspace_id, year, number),
  foreign key (workspace_id, created_by_member_id) references public.members (workspace_id, id),
  check ((state = 'draft') = (sent_at is null and cancelled_at is null)
         or state = 'cancelled'),
  check ((sent_at is null) = (sent_via is null)),
  check ((state = 'cancelled') = (cancelled_at is not null))
);
select public.ensure_system_columns('purchase_orders');
create index purchase_orders_workspace on public.purchase_orders (workspace_id, state);
create index purchase_orders_supplier on public.purchase_orders (supplier_id);

create table public.purchase_order_lines (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  order_id uuid not null references public.purchase_orders(id) on delete cascade,
  line_no int not null check (line_no >= 1),
  service_id uuid references public.services(id) on delete set null,
  description text not null default '' check (char_length(description) <= 500),
  quantity numeric not null check (quantity > 0 and quantity <= 1000000),
  unit text not null default '' check (char_length(unit) <= 20),
  unit_price_cents bigint not null check (unit_price_cents >= 0 and unit_price_cents <= 100000000000),
  vat_rate_percent numeric check (vat_rate_percent is null or (vat_rate_percent >= 0 and vat_rate_percent < 100)),
  received_quantity numeric not null default 0 check (received_quantity >= 0),
  unique (order_id, line_no),
  check (service_id is not null or btrim(description) <> '')
);
select public.ensure_system_columns('purchase_order_lines');
create index purchase_order_lines_order on public.purchase_order_lines (order_id);
create index purchase_order_lines_service on public.purchase_order_lines (service_id)
  where service_id is not null;

alter table public.purchase_order_counters enable row level security;
alter table public.purchase_orders enable row level security;
alter table public.purchase_order_lines enable row level security;
revoke all on public.purchase_order_counters, public.purchase_orders, public.purchase_order_lines
  from public, anon, authenticated;
grant select on public.purchase_orders, public.purchase_order_lines to authenticated;
create policy purchase_orders_select on public.purchase_orders for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['managePurchases', 'viewFinances'])));
create policy purchase_order_lines_select on public.purchase_order_lines for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['managePurchases', 'viewFinances'])));
create policy mcp_delegated_deny on public.purchase_order_counters as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create policy mcp_delegated_deny on public.purchase_orders as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create policy mcp_delegated_deny on public.purchase_order_lines as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- The transitions, whoever writes: a cancelled or received order is final;
-- a draft is the only state whose content moves.
create or replace function public.purchase_orders_guard()
returns trigger language plpgsql set search_path = public as $fn$
begin
  if new.workspace_id is distinct from old.workspace_id
     or new.year is distinct from old.year or new.number is distinct from old.number then
    raise exception 'a purchase order keeps its space and its number';
  end if;
  if old.state in ('received', 'cancelled') then
    raise exception 'a % purchase order is final', old.state;
  end if;
  if new.state is distinct from old.state and not (
       (old.state = 'draft' and new.state in ('sent', 'cancelled'))
    or (old.state = 'sent' and new.state in ('partly_received', 'received', 'cancelled'))
    or (old.state = 'partly_received' and new.state in ('received', 'cancelled'))) then
    raise exception 'a purchase order does not go from % to %', old.state, new.state;
  end if;
  if old.state <> 'draft' and (
       new.supplier_id is distinct from old.supplier_id or new.currency is distinct from old.currency
    or new.expected_on is distinct from old.expected_on or new.note is distinct from old.note) then
    raise exception 'only a draft purchase order is edited';
  end if;
  return new;
end;
$fn$;
revoke execute on function public.purchase_orders_guard() from public, anon, authenticated;
create trigger purchase_orders_guard before update on public.purchase_orders
  for each row execute function public.purchase_orders_guard();

create or replace function public.purchase_order_lines_guard()
returns trigger language plpgsql set search_path = public as $fn$
declare
  v_state text;
begin
  select o.state into v_state from public.purchase_orders o
   where o.id = coalesce(new.order_id, old.order_id);
  if v_state is null or v_state = 'draft' then return coalesce(new, old); end if;
  -- After the draft, only what was received moves (the goods receipt).
  if tg_op = 'UPDATE'
     and (new.order_id, new.line_no, new.service_id, new.description, new.quantity, new.unit,
          new.unit_price_cents, new.vat_rate_percent)
         is not distinct from
         (old.order_id, old.line_no, old.service_id, old.description, old.quantity, old.unit,
          old.unit_price_cents, old.vat_rate_percent) then
    return new;
  end if;
  raise exception 'the lines of a sent purchase order are frozen';
end;
$fn$;
revoke execute on function public.purchase_order_lines_guard() from public, anon, authenticated;
create trigger purchase_order_lines_guard before insert or update or delete on public.purchase_order_lines
  for each row execute function public.purchase_order_lines_guard();

-- Who may order: an active member holding managePurchases, while the
-- purchases and their orders are on, never a delegated assistant.
create or replace function public.purchase_order_actor(p_workspace_id uuid)
returns uuid language plpgsql stable security definer set search_path = public as $fn$
declare
  v_me uuid;
begin
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception 'not allowed to order for this space' using errcode = '42501';
  end if;
  if not (public.feature_effective(p_workspace_id, 'purchases')
          and public.feature_effective(p_workspace_id, 'purchaseOrders')) then
    raise exception 'purchase orders are switched off in this space' using errcode = '42501';
  end if;
  select m.id into v_me from public.members m
   where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active';
  if v_me is null or not public.has_permission(p_workspace_id, 'managePurchases') then
    raise exception 'not allowed to order for this space' using errcode = '42501';
  end if;
  return v_me;
end;
$fn$;
revoke execute on function public.purchase_order_actor(uuid) from public, anon, authenticated;

create or replace function public.purchase_order_json(p_order uuid)
returns jsonb language sql stable security definer set search_path = public as $fn$
  select jsonb_build_object(
    'id', o.id, 'reference', o.reference, 'year', o.year, 'number', o.number,
    'supplier_id', o.supplier_id, 'supplier_name', s.name, 'state', o.state,
    'currency', o.currency, 'expected_on', o.expected_on, 'note', o.note,
    'recipient_email', o.recipient_email, 'revision', o.revision,
    'sent_at', o.sent_at, 'sent_via', o.sent_via, 'cancelled_at', o.cancelled_at,
    'cancel_reason', o.cancel_reason, 'created_at', o.created_datetime,
    'lines', coalesce((select jsonb_agg(jsonb_build_object(
               'line_no', l.line_no, 'service_id', l.service_id, 'description', l.description,
               'quantity', l.quantity, 'unit', l.unit, 'unit_price_cents', l.unit_price_cents,
               'vat_rate_percent', l.vat_rate_percent, 'received_quantity', l.received_quantity)
             order by l.line_no) from public.purchase_order_lines l where l.order_id = o.id), '[]'::jsonb))
    from public.purchase_orders o join public.suppliers s on s.id = o.supplier_id
   where o.id = p_order;
$fn$;
revoke execute on function public.purchase_order_json(uuid) from public, anon, authenticated;

create or replace function public.save_purchase_order_v1(
  p_workspace_id uuid, p_request_id uuid, p_expected_revision int, p_payload jsonb
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  v_order public.purchase_orders;
  v_id uuid := nullif(p_payload ->> 'order_id', '')::uuid;
  v_supplier uuid := nullif(p_payload ->> 'supplier_id', '')::uuid;
  v_currency text;
  v_tz text;
  v_year int;
  v_number int;
  v_email text := btrim(coalesce(p_payload ->> 'recipient_email', ''));
  e jsonb;
  n int := 0;
  v_item uuid;
  v_desc text;
  v_qty numeric;
  v_price bigint;
  v_rate numeric;
begin
  v_me := public.purchase_order_actor(p_workspace_id);
  if p_request_id is null or p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise exception 'an order and a request id are required' using errcode = '22023';
  end if;
  v_digest := md5(p_payload::text || coalesce(p_expected_revision, 0)::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'order_save', v_digest);
  if v_done is not null then return v_done; end if;

  if v_supplier is null or not exists (
       select 1 from public.suppliers s
        where s.id = v_supplier and s.workspace_id = p_workspace_id and s.status = 'active') then
    raise exception 'an order goes to an active supplier of the space' using errcode = '22023';
  end if;
  select upper(w.currency_code), coalesce(nullif(w.timezone, ''), 'UTC') into v_currency, v_tz
    from public.workspaces w where w.id = p_workspace_id;
  v_currency := upper(coalesce(nullif(btrim(p_payload ->> 'currency'), ''), v_currency));
  if v_currency !~ '^[A-Z]{3}$' then
    raise exception 'unknown currency' using errcode = '22023';
  end if;
  if v_email <> '' and (v_email !~ '^[^\s@]+@[^\s@]+\.[^\s@]+$' or v_email ~ '[\r\n]') then
    raise exception 'the address the order is e-mailed to is not an e-mail address' using errcode = '22023';
  end if;
  if jsonb_typeof(p_payload -> 'lines') <> 'array'
     or jsonb_array_length(p_payload -> 'lines') not between 1 and 200 then
    raise exception 'an order has between 1 and 200 lines' using errcode = '22023';
  end if;

  if v_id is null then
    if coalesce(p_expected_revision, 0) <> 0 then
      raise exception 'a new order has no revision yet' using errcode = '40001';
    end if;
    v_year := extract(year from (now() at time zone v_tz))::int;
    insert into public.purchase_order_counters (workspace_id, year, last_number)
    values (p_workspace_id, v_year, 1)
    on conflict (workspace_id, year) do update
      set last_number = public.purchase_order_counters.last_number + 1
    returning last_number into v_number;
    insert into public.purchase_orders
      (workspace_id, year, number, supplier_id, currency, expected_on, note, recipient_email,
       created_by_member_id)
    values (p_workspace_id, v_year, v_number, v_supplier, v_currency,
            nullif(p_payload ->> 'expected_on', '')::date,
            left(coalesce(p_payload ->> 'note', ''), 1000), v_email, v_me)
    returning * into v_order;
  else
    select * into v_order from public.purchase_orders
     where id = v_id and workspace_id = p_workspace_id for update;
    if v_order.id is null then raise exception 'unknown purchase order' using errcode = '22023'; end if;
    if v_order.state <> 'draft' then
      raise exception 'only a draft purchase order is edited' using errcode = '22023';
    end if;
    if v_order.revision <> coalesce(p_expected_revision, -1) then
      raise exception 'stale revision' using errcode = '40001';
    end if;
    update public.purchase_orders set
        revision = revision + 1, supplier_id = v_supplier, currency = v_currency,
        expected_on = nullif(p_payload ->> 'expected_on', '')::date,
        note = left(coalesce(p_payload ->> 'note', ''), 1000), recipient_email = v_email
      where id = v_order.id
      returning * into v_order;
    delete from public.purchase_order_lines where order_id = v_order.id;
  end if;

  for e in select value from jsonb_array_elements(p_payload -> 'lines') loop
    n := n + 1;
    v_item := nullif(e ->> 'service_id', '')::uuid;
    if v_item is not null and not exists (
         select 1 from public.services s where s.id = v_item and s.workspace_id = p_workspace_id) then
      raise exception 'unknown item' using errcode = '22023';
    end if;
    v_desc := btrim(coalesce(e ->> 'description', ''));
    if v_desc = '' and v_item is not null then
      select s.name into v_desc from public.services s where s.id = v_item;
    end if;
    if v_desc = '' then
      raise exception 'a line names an item or describes what is ordered' using errcode = '22023';
    end if;
    v_qty := nullif(e ->> 'quantity', '')::numeric;
    if v_qty is null or v_qty <= 0 then
      raise exception 'a line is ordered in a quantity above zero' using errcode = '22023';
    end if;
    v_price := nullif(e ->> 'unit_price_cents', '')::bigint;
    if v_price is null or v_price < 0 then
      raise exception 'a line has a unit price' using errcode = '22023';
    end if;
    v_rate := nullif(e ->> 'vat_rate_percent', '')::numeric;
    insert into public.purchase_order_lines
      (workspace_id, order_id, line_no, service_id, description, quantity, unit,
       unit_price_cents, vat_rate_percent)
    values (p_workspace_id, v_order.id, n, v_item, left(v_desc, 500), v_qty,
            left(btrim(coalesce(e ->> 'unit', '')), 20), v_price, v_rate);
  end loop;

  return public.purchase_request_end(p_workspace_id, p_request_id, 'order_save', v_digest,
                                     public.purchase_order_json(v_order.id));
end;
$fn$;
revoke execute on function public.save_purchase_order_v1(uuid, uuid, int, jsonb) from public, anon;
grant execute on function public.save_purchase_order_v1(uuid, uuid, int, jsonb) to authenticated;

create or replace function public.mark_purchase_order_sent_v1(
  p_workspace_id uuid, p_order_id uuid, p_revision int, p_request_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_digest text := md5(p_order_id::text || coalesce(p_revision, 0)::text);
  v_done jsonb;
  v_order public.purchase_orders;
begin
  perform public.purchase_order_actor(p_workspace_id);
  if p_request_id is null then raise exception 'a request id is required' using errcode = '22023'; end if;
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'order_sent', v_digest);
  if v_done is not null then return v_done; end if;
  select * into v_order from public.purchase_orders
   where id = p_order_id and workspace_id = p_workspace_id for update;
  if v_order.id is null then raise exception 'unknown purchase order' using errcode = '22023'; end if;
  if v_order.state <> 'draft' then
    raise exception 'only a draft purchase order is sent' using errcode = '22023';
  end if;
  if v_order.revision <> coalesce(p_revision, -1) then
    raise exception 'stale revision' using errcode = '40001';
  end if;
  update public.purchase_orders
     set state = 'sent', sent_at = now(), sent_via = 'print', revision = revision + 1
   where id = v_order.id;
  return public.purchase_request_end(p_workspace_id, p_request_id, 'order_sent', v_digest,
                                     public.purchase_order_json(v_order.id));
end;
$fn$;
revoke execute on function public.mark_purchase_order_sent_v1(uuid, uuid, int, uuid) from public, anon;
grant execute on function public.mark_purchase_order_sent_v1(uuid, uuid, int, uuid) to authenticated;

create or replace function public.cancel_purchase_order_v1(
  p_workspace_id uuid, p_order_id uuid, p_revision int, p_reason text, p_request_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_reason text := btrim(coalesce(p_reason, ''));
  v_digest text := md5(p_order_id::text || coalesce(p_revision, 0)::text || v_reason);
  v_done jsonb;
  v_order public.purchase_orders;
begin
  perform public.purchase_order_actor(p_workspace_id);
  if p_request_id is null then raise exception 'a request id is required' using errcode = '22023'; end if;
  if v_reason = '' or char_length(v_reason) > 300 then
    raise exception 'a cancelled order says why' using errcode = '22023';
  end if;
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'order_cancel', v_digest);
  if v_done is not null then return v_done; end if;
  select * into v_order from public.purchase_orders
   where id = p_order_id and workspace_id = p_workspace_id for update;
  if v_order.id is null then raise exception 'unknown purchase order' using errcode = '22023'; end if;
  if v_order.state not in ('draft', 'sent', 'partly_received') then
    raise exception 'a % purchase order is not cancelled', v_order.state using errcode = '22023';
  end if;
  if v_order.revision <> coalesce(p_revision, -1) then
    raise exception 'stale revision' using errcode = '40001';
  end if;
  update public.purchase_orders
     set state = 'cancelled', cancelled_at = now(), cancel_reason = v_reason, revision = revision + 1
   where id = v_order.id;
  return public.purchase_request_end(p_workspace_id, p_request_id, 'order_cancel', v_digest,
                                     public.purchase_order_json(v_order.id));
end;
$fn$;
revoke execute on function public.cancel_purchase_order_v1(uuid, uuid, int, text, uuid) from public, anon;
grant execute on function public.cancel_purchase_order_v1(uuid, uuid, int, text, uuid) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(674);
