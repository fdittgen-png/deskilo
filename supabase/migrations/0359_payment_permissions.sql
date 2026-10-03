-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0362 (#2137) -- a money permission given through a role works.
--
-- Three money doors read the raw admin flag ("is_admin or is_owner") to
-- let somebody act for another member, so a member holding the matching
-- permission through a role was refused:
--
--   * recording a payment for another member -- issueInvoices ("issue
--     invoices, match payments, send reminders");
--   * adding a service to another member's account -- manageServices,
--     the permission of the catalogue it charges from;
--   * asking to delete a usage record -- issueInvoices: the record is
--     what an invoice counts.
--
-- Each door keeps the owner and the Administrator flag it accepted
-- before -- nothing that worked stops working -- and also accepts the
-- permission. The acts themselves are unchanged: a payment or a charge
-- for somebody else is still submitted for validation.
--
-- Whole-function restatements from the live definitions
-- (pg_get_functiondef), the one change marked in each.

CREATE OR REPLACE FUNCTION public.record_payment(p_workspace_id uuid, p_member_id uuid, p_amount_cents integer, p_note text DEFAULT ''::text, p_method text DEFAULT ''::text, p_paid_on date DEFAULT NULL::date, p_period text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_actor public.members;
  v_event_id uuid;
  v_paid_on date := coalesce(p_paid_on, current_date);
  v_period text := coalesce(p_period, to_char(now(), 'YYYY-MM'));
begin
  select * into v_actor from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid() and status = 'active';
  if v_actor.id is null then raise exception 'not an active member'; end if;
  if p_amount_cents <= 0 then raise exception 'amount must be positive'; end if;
  -- #2137 -- or whoever holds issueInvoices, through a role.
  if v_actor.id <> p_member_id and not (v_actor.is_admin or v_actor.is_owner
       or public.has_permission(p_workspace_id, 'issueInvoices')) then
    raise exception 'only admins record payments for others';
  end if;
  -- Free-form-but-bounded method tag; the app sends one of the
  -- PaymentMethod enum wire names ('' = not specified, old clients).
  if length(p_method) > 32 then raise exception 'method too long'; end if;
  if v_period !~ '^[0-9]{4}-[0-9]{2}$' then raise exception 'invalid period'; end if;
  -- Money cannot have moved tomorrow. One day of slack absorbs the gap
  -- between the server's UTC date and a workspace east of it.
  if v_paid_on > current_date + 1 then
    raise exception 'payment date is in the future';
  end if;
  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
  values (
    p_workspace_id, 'payment', 'submitted', v_actor.id, p_member_id,
    jsonb_build_object(
      'amount_cents', p_amount_cents,
      'note', p_note,
      'method', p_method,
      'paid_on', v_paid_on,
      'period', v_period
    ),
    'pending'
  ) returning id into v_event_id;
  return v_event_id;
end;
$function$;

revoke execute on function public.record_payment(uuid, uuid, integer, text, text, date, text)
  from public, anon;
grant execute on function public.record_payment(uuid, uuid, integer, text, text, date, text)
  to authenticated;

CREATE OR REPLACE FUNCTION public.record_service_charge(p_workspace_id uuid, p_subject_member_id uuid, p_service_id uuid, p_quantity integer, p_period text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_actor public.members;
  v_service public.services;
  v_unit int;
  v_period text;
  v_event_id uuid;
  v_vat numeric;
begin
  select * into v_actor from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid() and status = 'active';
  if v_actor.id is null then raise exception 'not an active member'; end if;
  -- #2137 -- or whoever holds manageServices, through a role.
  if v_actor.id <> p_subject_member_id and not (v_actor.is_admin or v_actor.is_owner
       or public.has_permission(p_workspace_id, 'manageServices')) then
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
  if v_service.stock is not null and v_service.stock < p_quantity then
    raise exception 'out of stock: % left', v_service.stock;
  end if;
  if p_quantity is null or p_quantity < 1 or p_quantity > 999 then
    raise exception 'quantity must be between 1 and 999';
  end if;
  v_unit := coalesce(public.negotiated_item_price(p_subject_member_id, 'services', v_service.id), v_service.price_cents);
  v_period := coalesce(p_period, to_char(now(), 'YYYY-MM'));
  if v_period !~ '^\d{4}-\d{2}$' then raise exception 'period must be YYYY-MM'; end if;

  if public.workspace_charges_vat(p_workspace_id) then
    select coalesce(
        public.vat_rate_percent_at(v_service.vat_rate_id, current_date),
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
      'price_cents', v_unit,
      'catalogue_price_cents', v_service.price_cents,
      'quantity', p_quantity,
      'amount_cents', v_unit * p_quantity,
      'vat_percent', v_vat,
      'period', v_period
    ),
    'pending'
  ) returning id into v_event_id;
  return v_event_id;
end;
$function$;

revoke execute on function public.record_service_charge(uuid, uuid, uuid, integer, text)
  from public, anon;
grant execute on function public.record_service_charge(uuid, uuid, uuid, integer, text)
  to authenticated;

CREATE OR REPLACE FUNCTION public.request_usage_record_delete(p_record_id uuid, p_reason text DEFAULT ''::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_rec public.usage_records; v_me public.members;
        v_has_policy boolean; v_event uuid;
begin
  select * into v_rec from public.usage_records where id = p_record_id;
  if v_rec.id is null then raise exception 'unknown usage record'; end if;
  select m.* into v_me from public.members m
   where m.workspace_id = v_rec.workspace_id and m.user_id = auth.uid()
     and m.status = 'active';
  if v_me.id is null then raise exception 'not a member'; end if;
  -- #2137 -- or whoever holds issueInvoices, through a role.
  if not (v_me.is_owner or v_me.is_admin
          or public.has_permission(v_rec.workspace_id, 'issueInvoices')) then
    raise exception 'not allowed';
  end if;
  v_has_policy := exists (
    select 1 from public.validation_policies vp
     where vp.workspace_id = v_rec.workspace_id
       and (vp.event_type = 'usage_record_delete' or vp.event_type is null));
  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id,
     payload, status, decided_at)
  values
    (v_rec.workspace_id, 'usage_record_delete', 'submitted', v_me.id,
     v_rec.member_id,
     jsonb_build_object('record_id', p_record_id,
       'reservation_id', v_rec.reservation_id,
       'counted_minutes', v_rec.counted_minutes,
       'reason', btrim(coalesce(p_reason, ''))),
     case when v_has_policy then 'pending' else 'confirmed' end,
     case when v_has_policy then null else now() end)
  returning id into v_event;
  if not v_has_policy then
    delete from public.usage_records where id = p_record_id;
  end if;
  return v_event;
end;
$function$;

revoke execute on function public.request_usage_record_delete(uuid, text)
  from public, anon;
grant execute on function public.request_usage_record_delete(uuid, text)
  to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(359);
