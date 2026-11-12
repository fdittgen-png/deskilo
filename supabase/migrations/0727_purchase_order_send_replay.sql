-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (one function restated whole: its answer gains two keys; no table, policy
--  or grant changes)
--
-- #3774 -- a purchase order's send attempt left pending (the function
-- stopped before recording the outcome) and retried later with the same id
-- could leave twice: `begin_purchase_order_send_v1` (0683) answered the
-- stored attempt and `send-purchase-order` sent whenever it was pending,
-- relying on the provider's idempotency key, which the provider keeps for a
-- limited time. The reminder e-mail (0726) closed the same gap; this is the
-- purchase order's.
--
-- The answer now says whether this call opened the attempt (`opened`) and
-- whether it may still be sent (`sendable`): by the call that opened it, or
-- by a pending replay younger than the bound after which a person decides
-- the attempt by hand (resolve_purchase_order_send_v1, the same 10 minutes).
-- The function sends nothing for an attempt that is not sendable.
--
-- Restated whole from 0683, otherwise unchanged: the buyer's rights are
-- checked before the replay (purchase_order_actor), as before.

create or replace function public.begin_purchase_order_send_v1(
  p_workspace_id uuid, p_order_id uuid, p_revision int, p_attempt_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_order public.purchase_orders;
  v_send public.purchase_order_sends;
  -- A technical bound, not a business value: far beyond any live attempt;
  -- resolve_purchase_order_send_v1 decides by hand after the same bound.
  c_stuck constant interval := interval '10 minutes';
begin
  v_me := public.purchase_order_actor(p_workspace_id);
  if p_attempt_id is null then raise exception 'an attempt id is required' using errcode = '22023'; end if;
  select * into v_send from public.purchase_order_sends where id = p_attempt_id;
  if v_send.id is not null then
    if v_send.workspace_id <> p_workspace_id or v_send.order_id <> p_order_id then
      raise exception 'this attempt id was already used for another order' using errcode = '22023';
    end if;
    -- A replay: sendable only while it is pending and younger than the
    -- bound after which a person decides it.
    return public.purchase_order_send_json(v_send.id) || jsonb_build_object(
      'opened', false,
      'sendable', v_send.state = 'pending' and v_send.created_datetime >= now() - c_stuck);
  end if;
  select * into v_order from public.purchase_orders
   where id = p_order_id and workspace_id = p_workspace_id for update;
  if v_order.id is null then raise exception 'unknown purchase order' using errcode = '22023'; end if;
  if v_order.state <> 'draft' then
    raise exception 'only a draft purchase order is sent' using errcode = '22023';
  end if;
  if v_order.revision <> coalesce(p_revision, -1) then
    raise exception 'stale revision' using errcode = '40001';
  end if;
  if v_order.recipient_email !~ '^[^\s@<>",;()\[\]\\]+@[^\s@<>",;()\[\]\\]+\.[^\s@<>",;()\[\]\\]+$' or v_order.recipient_email ~ '[\r\n]' then
    raise exception 'the order names no address to e-mail it to' using errcode = '22023';
  end if;
  if not exists (select 1 from public.purchase_order_mail_settings m
                  where m.workspace_id = p_workspace_id and m.has_api_key) then
    raise exception 'this space has not configured how it e-mails its orders' using errcode = '22023';
  end if;
  if exists (select 1 from public.purchase_order_sends s
              where s.order_id = p_order_id and s.state in ('pending', 'unconfirmed')) then
    raise exception 'an earlier send of this order has no confirmed outcome: check before sending again'
      using errcode = '55000';
  end if;
  insert into public.purchase_order_sends (id, workspace_id, order_id, recipient, actor_member_id)
  values (p_attempt_id, p_workspace_id, p_order_id, btrim(v_order.recipient_email), v_me)
  returning * into v_send;
  return public.purchase_order_send_json(v_send.id)
    || jsonb_build_object('opened', true, 'sendable', true);
end;
$fn$;
revoke execute on function public.begin_purchase_order_send_v1(uuid, uuid, int, uuid) from public, anon;
grant execute on function public.begin_purchase_order_send_v1(uuid, uuid, int, uuid) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(727);
