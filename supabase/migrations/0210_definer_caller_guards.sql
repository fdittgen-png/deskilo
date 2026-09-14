-- SPDX-License-Identifier: 0BSD
-- #1228 — three client-reachable SECURITY DEFINER functions never
-- checked their caller.
--
-- Of 241 definer functions, 57 are granted to `authenticated` and so
-- callable straight from a device. Fifty-four check who is asking.
-- These three did not, and each takes a member id as a PARAMETER, so
-- each answered for any member of any workspace to anyone signed in:
--
--   default_tariff_of        the member's fee band — their subscription
--                            price, i.e. a competitor's commercial terms
--   negotiated_item_price    a price negotiated privately with them
--   document_site_for_member which site they belong to
--
-- Verified before and after against the live dev project with a
-- rolled-back harness: calling `default_tariff_of` on a member of
-- another workspace returned `{"fee_cents": 10000}` before the guard and
-- the zero default after; `document_site_for_member` returned a site row
-- before and null after. The caller's OWN workspace is unaffected.
--
-- The guard is `is_member_of` on the workspace the member belongs to,
-- which is the same shape the other 54 use. A non-member now gets the
-- function's empty answer rather than an error, deliberately: these are
-- lookups on a pricing path, and an exception would turn a disclosure
-- bug into an oracle that still confirms the member exists.

create or replace function public.default_tariff_of(p_member_id uuid)
returns jsonb language sql stable security definer set search_path to 'public' as $$
  select coalesce((select jsonb_build_object('fee_cents', b.fee_cents, 'overage_fee_cents', b.overage_fee_cents)
       from public.members m join public.fee_bands b on b.workspace_id = m.workspace_id
        and b.from_pct < coalesce(m.subscription_pct, 100) and coalesce(m.subscription_pct, 100) <= b.to_pct
      where m.id = p_member_id
        and public.is_member_of(m.workspace_id)
      limit 1), jsonb_build_object('fee_cents', 0, 'overage_fee_cents', 0));
$$;

create or replace function public.negotiated_item_price(p_member_id uuid, p_kind text, p_item_id uuid)
returns integer language sql stable security definer set search_path to 'public' as $$
  select (n.items -> p_kind ->> p_item_id::text)::int
    from public.price_negotiations n
    join public.members m on m.id = n.member_id
   where n.member_id = p_member_id and n.status = 'active' and n.valid_from <= current_date
     and public.is_member_of(m.workspace_id)
   limit 1;
$$;

create or replace function public.document_site_for_member(p_member_id uuid)
returns public.sites language sql stable security definer set search_path to 'public' as $$
  select coalesce(
    (select s from public.sites s
       join public.members m on m.home_site_id = s.id
      where m.id = p_member_id and public.is_member_of(m.workspace_id)),
    (select public.default_site(m.workspace_id) from public.members m
      where m.id = p_member_id and public.is_member_of(m.workspace_id)));
$$;

revoke execute on function public.default_tariff_of(uuid) from public, anon;
revoke execute on function public.negotiated_item_price(uuid, text, uuid) from public, anon;
revoke execute on function public.document_site_for_member(uuid) from public, anon;
grant execute on function public.default_tariff_of(uuid) to authenticated;
grant execute on function public.negotiated_item_price(uuid, text, uuid) to authenticated;
grant execute on function public.document_site_for_member(uuid) to authenticated;

-- And a FOURTH, found by the lint this migration ships with — worse
-- than the three above, because it WRITES.
--
-- `open_payment_intent` inserted a payment intent for any p_member_id in
-- any p_workspace_id, with no caller check of any kind. An authenticated
-- user could open a payment attributed to somebody else in a workspace
-- they have nothing to do with, and burn a number from that workspace's
-- payment sequence doing it.
--
-- The rule is the obvious one: you open a payment for yourself, or you
-- are whoever issues the invoices. Harnessed both ways on the live dev
-- project — a cross-workspace call now raises 'not a member of this
-- workspace', and a member paying their own bill still gets their
-- reference (PAY-2026-0001).
create or replace function public.open_payment_intent(p_workspace_id uuid, p_member_id uuid, p_provider text, p_period text, p_amount_cents integer, p_currency text)
returns table(id uuid, reference text) language plpgsql security definer set search_path to 'public' as $$
declare v_id uuid := gen_random_uuid(); v_ref text; v_ws_currency text; v_me public.members;
begin
  v_me := public.my_active_member(p_workspace_id);
  if p_member_id <> v_me.id and not public.has_permission(p_workspace_id, 'issueInvoices') then
    raise exception 'a payment is opened for yourself, or by whoever issues the invoices';
  end if;
  select upper(currency_code) into v_ws_currency from public.workspaces where public.workspaces.id = p_workspace_id;
  if v_ws_currency is null then raise exception 'unknown workspace'; end if;
  if upper(coalesce(p_currency, '')) <> v_ws_currency then
    raise exception 'a payment is taken in the workspace currency (%), not %', v_ws_currency, p_currency;
  end if;
  if p_amount_cents is null or p_amount_cents <= 0 then
    raise exception 'a payment intent needs a positive amount';
  end if;
  v_ref := public.next_document_number(p_workspace_id, 'payment');
  insert into public.payment_intents (id, workspace_id, member_id, provider, order_id, period, amount_cents, currency, reference)
  values (v_id, p_workspace_id, p_member_id, p_provider, 'pending:' || v_id::text, p_period, p_amount_cents, v_ws_currency, v_ref);
  return query select v_id, v_ref;
end;
$$;

revoke execute on function public.open_payment_intent(uuid, uuid, text, text, integer, text) from public, anon;
grant execute on function public.open_payment_intent(uuid, uuid, text, text, integer, text) to authenticated;
