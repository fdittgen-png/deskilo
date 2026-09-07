-- SPDX-License-Identifier: 0BSD
-- 0181 — #982: six validation domains and an amount threshold.
--
-- Issuing an invoice, cancelling one, a refund, pausing or ending a
-- membership, changing a subscription and editing the permission
-- matrix had no policy at all. Each now goes through a request
-- function that applies at once when no policy of that type exists
-- (recording an applied event for the audit trail) and creates a
-- pending event when one does; the confirmation applies it through a
-- trigger, as payment-terms changes do (0154). A policy's
-- min_amount_cents spares small money acts. Harnessed live: a policed
-- invoice issue waited and produced the invoice on the owner's
-- confirmation; an unpoliced subscription change applied at once,
-- audited; a void below the threshold applied at once; a plain member
-- was refused.
alter table public.validation_policies add column if not exists min_amount_cents integer not null default 0;
alter table public.validation_policies drop constraint if exists validation_policies_min_amount_check;
alter table public.validation_policies add constraint validation_policies_min_amount_check check (min_amount_cents >= 0);
alter table public.events drop constraint if exists events_type_check;
alter table public.events add constraint events_type_check check (type = any (array[
  'reservation','payment','expense','adjustment','service_charge','quota','role_change','member_join','space_reservation',
  'invoice_payment','reservation_delete','invoice_writeoff','invoice_reminder','price_negotiation','expense_schedule',
  'expense_repartition','usage_correction','usage_record_delete','payment_terms_change',
  'invoice_issue','invoice_void','refund','member_status_change','subscription_change','matrix_change']));
alter table public.validation_policies drop constraint if exists validation_policies_event_type_check;
alter table public.validation_policies add constraint validation_policies_event_type_check check (event_type is null or event_type = any (array[
  'reservation','payment','expense','adjustment','service_charge','quota','role_change','member_join','space_reservation',
  'invoice_payment','reservation_delete','invoice_writeoff','invoice_reminder','price_negotiation','expense_schedule',
  'expense_repartition','usage_correction','usage_record_delete','payment_terms_change',
  'invoice_issue','invoice_void','refund','member_status_change','subscription_change','matrix_change']));
create or replace function public.validation_requires(p_workspace_id uuid, p_type text, p_amount_cents integer)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.validation_policies vp
    where vp.workspace_id = p_workspace_id and vp.event_type = p_type
      and (vp.min_amount_cents = 0 or coalesce(p_amount_cents, 0) >= vp.min_amount_cents));
$$;
create or replace function public.record_applied_event(p_workspace_id uuid, p_type text, p_actor uuid, p_subject uuid, p_payload jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  insert into public.events (workspace_id, type, action, actor_member_id, subject_member_id, payload, status, decided_at)
  values (p_workspace_id, p_type, 'created', p_actor, p_subject, p_payload, 'applied', now()) returning id into v_id;
  return v_id;
end $$;
revoke execute on function public.record_applied_event(uuid, text, uuid, uuid, jsonb) from public, anon, authenticated;
create or replace function public.request_invoice_issue(p_workspace_id uuid, p_member_id uuid, p_period text, p_kind text default 'full', p_detailed boolean default false, p_allow_zero boolean default false, p_buyer_reference text default null, p_purchase_order text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_actor public.members; v_amount int; v_id uuid; v_payload jsonb;
begin
  v_actor := public.my_active_member(p_workspace_id);
  if not public.has_permission(p_workspace_id, 'issueInvoices') then raise exception 'not allowed to issue invoices'; end if;
  select coalesce(sum((l->>'amount_cents')::int), 0) into v_amount from jsonb_array_elements(public.invoice_lines_for(p_member_id, p_period, p_kind)) l;
  v_payload := jsonb_build_object('member_id', p_member_id, 'period', p_period, 'kind', p_kind, 'detailed', p_detailed, 'allow_zero', p_allow_zero,
    'buyer_reference', p_buyer_reference, 'purchase_order', p_purchase_order, 'amount_cents', v_amount);
  if public.validation_requires(p_workspace_id, 'invoice_issue', v_amount) then
    insert into public.events (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
    values (p_workspace_id, 'invoice_issue', 'submitted', v_actor.id, p_member_id, v_payload, 'pending') returning id into v_id;
    return jsonb_build_object('pending', true, 'event_id', v_id);
  end if;
  v_id := public.create_invoice(p_workspace_id, p_member_id, p_period, null, p_detailed, p_kind, p_allow_zero, p_buyer_reference, p_purchase_order);
  perform public.record_applied_event(p_workspace_id, 'invoice_issue', v_actor.id, p_member_id, v_payload || jsonb_build_object('invoice_id', v_id));
  return jsonb_build_object('pending', false, 'invoice_id', v_id);
end $$;
create or replace function public.request_invoice_void(p_invoice_id uuid, p_reason text default '')
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_inv public.invoices; v_actor public.members; v_id uuid; v_payload jsonb;
begin
  select * into v_inv from public.invoices where id = p_invoice_id;
  if v_inv.id is null then raise exception 'unknown invoice'; end if;
  v_actor := public.my_active_member(v_inv.workspace_id);
  if not public.has_permission(v_inv.workspace_id, 'issueInvoices') then raise exception 'not allowed to void invoices'; end if;
  v_payload := jsonb_build_object('invoice_id', p_invoice_id, 'number', v_inv.number, 'amount_cents', abs(v_inv.total_cents), 'reason', left(coalesce(p_reason, ''), 300));
  if public.validation_requires(v_inv.workspace_id, 'invoice_void', abs(v_inv.total_cents)) then
    insert into public.events (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
    values (v_inv.workspace_id, 'invoice_void', 'submitted', v_actor.id, v_inv.member_id, v_payload, 'pending') returning id into v_id;
    return jsonb_build_object('pending', true, 'event_id', v_id);
  end if;
  perform public.void_invoice(p_invoice_id);
  perform public.record_applied_event(v_inv.workspace_id, 'invoice_void', v_actor.id, v_inv.member_id, v_payload);
  return jsonb_build_object('pending', false);
end $$;
create or replace function public.request_refund(p_invoice_id uuid, p_note text default '')
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_inv public.invoices; v_actor public.members; v_id uuid; v_payload jsonb;
begin
  select * into v_inv from public.invoices where id = p_invoice_id;
  if v_inv.id is null then raise exception 'unknown invoice'; end if;
  v_actor := public.my_active_member(v_inv.workspace_id);
  if not public.has_permission(v_inv.workspace_id, 'issueInvoices') then raise exception 'not allowed to refund'; end if;
  v_payload := jsonb_build_object('invoice_id', p_invoice_id, 'number', v_inv.number, 'amount_cents', abs(v_inv.total_cents), 'note', left(coalesce(p_note, ''), 300));
  if public.validation_requires(v_inv.workspace_id, 'refund', abs(v_inv.total_cents)) then
    insert into public.events (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
    values (v_inv.workspace_id, 'refund', 'submitted', v_actor.id, v_inv.member_id, v_payload, 'pending') returning id into v_id;
    return jsonb_build_object('pending', true, 'event_id', v_id);
  end if;
  perform public.settle_credit_invoice(p_invoice_id, p_note);
  perform public.record_applied_event(v_inv.workspace_id, 'refund', v_actor.id, v_inv.member_id, v_payload);
  return jsonb_build_object('pending', false);
end $$;
create or replace function public.request_member_status_change(p_member_id uuid, p_status text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_m public.members; v_actor public.members; v_id uuid; v_payload jsonb;
begin
  select * into v_m from public.members where id = p_member_id;
  if v_m.id is null then raise exception 'unknown member'; end if;
  if p_status not in ('active', 'paused', 'exited') then raise exception 'unknown status'; end if;
  v_actor := public.my_active_member(v_m.workspace_id);
  if not public.has_permission(v_m.workspace_id, 'manageMembers') then raise exception 'not allowed to change memberships'; end if;
  if v_m.is_owner then raise exception 'an owner hands the workspace over first'; end if;
  v_payload := jsonb_build_object('member_id', p_member_id, 'before', v_m.status, 'after', p_status);
  if public.validation_requires(v_m.workspace_id, 'member_status_change', 0) then
    insert into public.events (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
    values (v_m.workspace_id, 'member_status_change', 'submitted', v_actor.id, p_member_id, v_payload, 'pending') returning id into v_id;
    return jsonb_build_object('pending', true, 'event_id', v_id);
  end if;
  update public.members set status = p_status where id = p_member_id;
  perform public.record_applied_event(v_m.workspace_id, 'member_status_change', v_actor.id, p_member_id, v_payload);
  return jsonb_build_object('pending', false);
end $$;
create or replace function public.request_subscription_change(p_member_id uuid, p_pct integer)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_m public.members; v_actor public.members; v_id uuid; v_payload jsonb;
begin
  select * into v_m from public.members where id = p_member_id;
  if v_m.id is null then raise exception 'unknown member'; end if;
  if p_pct < 1 or p_pct > 100 then raise exception 'pct out of range'; end if;
  v_actor := public.my_active_member(v_m.workspace_id);
  if not public.has_permission(v_m.workspace_id, 'manageMembers') then raise exception 'not allowed to change subscriptions'; end if;
  v_payload := jsonb_build_object('member_id', p_member_id, 'before', v_m.subscription_pct, 'after', p_pct);
  if public.validation_requires(v_m.workspace_id, 'subscription_change', 0) then
    insert into public.events (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
    values (v_m.workspace_id, 'subscription_change', 'submitted', v_actor.id, p_member_id, v_payload, 'pending') returning id into v_id;
    return jsonb_build_object('pending', true, 'event_id', v_id);
  end if;
  update public.members set subscription_pct = p_pct where id = p_member_id;
  perform public.record_applied_event(v_m.workspace_id, 'subscription_change', v_actor.id, p_member_id, v_payload);
  return jsonb_build_object('pending', false);
end $$;
create or replace function public.request_matrix_change(p_workspace_id uuid, p_role text, p_permissions text[])
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_actor public.members; v_id uuid; v_payload jsonb; v_before jsonb;
begin
  v_actor := public.my_active_member(p_workspace_id);
  if not public.has_permission(p_workspace_id, 'manageRoles') then raise exception 'only role managers may edit permissions'; end if;
  select role_permissions -> p_role into v_before from public.workspaces where id = p_workspace_id;
  v_payload := jsonb_build_object('role', p_role, 'before', coalesce(v_before, 'null'::jsonb), 'after', to_jsonb(p_permissions));
  if public.validation_requires(p_workspace_id, 'matrix_change', 0) then
    insert into public.events (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
    values (p_workspace_id, 'matrix_change', 'submitted', v_actor.id, v_actor.id, v_payload, 'pending') returning id into v_id;
    return jsonb_build_object('pending', true, 'event_id', v_id);
  end if;
  perform public.set_role_permissions(p_workspace_id, p_role, p_permissions);
  perform public.record_applied_event(p_workspace_id, 'matrix_change', v_actor.id, v_actor.id, v_payload);
  return jsonb_build_object('pending', false);
end $$;
create or replace function public.apply_validated_decision_0181()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_inv uuid; v_perms text[];
begin
  if new.status = old.status or new.status <> 'confirmed' then return new; end if;
  case new.type
    when 'invoice_issue' then
      v_inv := public.create_invoice(new.workspace_id, (new.payload->>'member_id')::uuid, new.payload->>'period', null,
        coalesce((new.payload->>'detailed')::boolean, false), coalesce(new.payload->>'kind', 'full'),
        coalesce((new.payload->>'allow_zero')::boolean, false), new.payload->>'buyer_reference', new.payload->>'purchase_order');
      update public.events set payload = payload || jsonb_build_object('invoice_id', v_inv) where id = new.id;
    when 'invoice_void' then perform public.void_invoice((new.payload->>'invoice_id')::uuid);
    when 'refund' then perform public.settle_credit_invoice((new.payload->>'invoice_id')::uuid, coalesce(new.payload->>'note', ''));
    when 'member_status_change' then update public.members set status = new.payload->>'after' where id = (new.payload->>'member_id')::uuid;
    when 'subscription_change' then update public.members set subscription_pct = (new.payload->>'after')::int where id = (new.payload->>'member_id')::uuid;
    when 'matrix_change' then
      select array_agg(x) into v_perms from jsonb_array_elements_text(new.payload->'after') x;
      update public.workspaces set role_permissions = jsonb_set(coalesce(role_permissions, '{}'::jsonb), array[new.payload->>'role'], coalesce(to_jsonb(v_perms), '[]'::jsonb)) where id = new.workspace_id;
    else null;
  end case;
  return new;
end $$;
drop trigger if exists events_apply_validated_0181 on public.events;
create trigger events_apply_validated_0181 after update on public.events for each row execute function public.apply_validated_decision_0181();
