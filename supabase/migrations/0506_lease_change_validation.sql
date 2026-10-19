-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0506 (#2569) -- the `lease_change` validation domain.
--
-- Two writes on a premises lease can be held for a second person: GIVING
-- NOTICE (it ends the lease) and CHANGING THE RENT (a new rent term that
-- supersedes the one in force). Nothing is held by default: a space turns it on
-- by giving the domain a policy (`validation_policies`), and a policy's
-- minimum amount spares small rent changes (the amount is the change itself:
-- the new rent less the rent in force); notice is held whenever a policy
-- exists. Creating a lease, other charges, service-charge advances and
-- settlements are never held.
--
-- A held write becomes a pending `lease_change` event carrying exactly what was
-- asked; the request is answered "pending" and replays as such under the same
-- request id. The confirmation applies it through an AFTER UPDATE trigger on
-- events (the 0151 idiom) by calling the same function again, as the
-- requester, against the lease as it stands: if it no longer fits (a term was
-- added meanwhile) the decision fails with the function's own reason and
-- nothing is applied. A rejection applies nothing.
--
-- The two functions are patched at asserted anchors (their live bodies are the
-- replay's), each anchor occurring exactly once.

alter table public.events drop constraint if exists events_type_check;
alter table public.events add constraint events_type_check check (type = any (array[
  'reservation','payment','expense','adjustment','service_charge','quota','role_change','member_join','space_reservation',
  'invoice_payment','reservation_delete','invoice_writeoff','invoice_reminder','price_negotiation','expense_schedule',
  'expense_repartition','usage_correction','usage_record_delete','payment_terms_change',
  'invoice_issue','invoice_void','refund','member_status_change','subscription_change','matrix_change','lease_change']));
alter table public.validation_policies drop constraint if exists validation_policies_event_type_check;
alter table public.validation_policies add constraint validation_policies_event_type_check check (event_type is null or event_type = any (array[
  'reservation','payment','expense','adjustment','service_charge','quota','role_change','member_join','space_reservation',
  'invoice_payment','reservation_delete','invoice_writeoff','invoice_reminder','price_negotiation','expense_schedule',
  'expense_repartition','usage_correction','usage_record_delete','payment_terms_change',
  'invoice_issue','invoice_void','refund','member_status_change','subscription_change','matrix_change','lease_change']));

-- Who sees a lease change in their validation feed: whoever manages the lease
-- or reads the finances.
create or replace function public.event_type_view_permissions(p_type text)
returns text[]
language sql
immutable
set search_path = public
as $fn$
  select case
    when p_type in ('payment', 'adjustment', 'service_charge', 'invoice_payment',
                    'invoice_writeoff', 'invoice_reminder', 'invoice_issue',
                    'invoice_void', 'refund', 'usage_correction', 'usage_record_delete')
      then array['viewFinances', 'issueInvoices']
    when p_type in ('expense', 'expense_schedule', 'expense_repartition')
      then array['approveExpenses', 'viewFinances']
    when p_type in ('reservation', 'space_reservation', 'reservation_delete')
      then array['manageReservations']
    when p_type = 'quota'
      then array['manageReservations', 'viewFinances', 'issueInvoices']
    when p_type in ('member_join', 'member_status_change', 'subscription_change', 'role_change')
      then array['manageMembers']
    when p_type = 'matrix_change'
      then array['manageRoles', 'manageMembers']
    when p_type = 'price_negotiation'
      then array['viewNegotiations']
    when p_type = 'payment_terms_change'
      then array['paymentTermsEdit', 'viewNegotiations']
    when p_type = 'lease_change'
      then array['manageLease', 'viewFinances']
    else array['manageConfiguration']
  end;
$fn$;
revoke execute on function public.event_type_view_permissions(text) from public, anon;
grant execute on function public.event_type_view_permissions(text) to authenticated;

-- Is any lease change held in this space at all?
create or replace function public.lease_notice_held(p_workspace_id uuid)
returns boolean language sql stable security definer set search_path = public as $fn$
  select exists (select 1 from public.validation_policies vp
                  where vp.workspace_id = p_workspace_id and vp.event_type = 'lease_change');
$fn$;
revoke execute on function public.lease_notice_held(uuid) from public, anon, authenticated;

create or replace function pg_temp.patch_function(p_proc regprocedure, p_old text[], p_new text[])
returns void language plpgsql as $f$
declare
  v_def text := pg_get_functiondef(p_proc);
  i int;
begin
  for i in 1 .. cardinality(p_old) loop
    if (length(v_def) - length(replace(v_def, p_old[i], ''))) <> length(p_old[i]) then
      raise exception '0506: anchor % is not present exactly once in %', i, p_proc;
    end if;
    v_def := replace(v_def, p_old[i], p_new[i]);
  end loop;
  execute v_def;
end
$f$;
revoke execute on function pg_temp.patch_function(regprocedure, text[], text[]) from public;

-- ── a rent change: held when it replaces a rent in force ─────────────────
select pg_temp.patch_function(
  'public.add_lease_term_v1(uuid, uuid, integer, text, text, integer, integer, date, uuid)'::regprocedure,
  array[
    $a$  v_result jsonb;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  v_me := public.lease_actor(p_workspace_id, true);$a$,
    $a$    update public.lease_terms set effective_to = p_effective_from - 1 where id = v_prev.id;$a$],
  array[
    $a$  v_result jsonb;
  v_apply boolean := coalesce(current_setting('deskilo.lease_apply', true), '') <> '';
  v_event uuid;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  -- Applying a confirmed change acts as the member who asked for it.
  if v_apply then
    v_me := current_setting('deskilo.lease_apply_actor')::uuid;
  else
    v_me := public.lease_actor(p_workspace_id, true);
  end if;$a$,
    $a$    if not v_apply and p_kind = 'rent'
       and public.validation_requires(p_workspace_id, 'lease_change', abs(p_amount_cents - v_prev.amount_cents)) then
      insert into public.events (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
      values (p_workspace_id, 'lease_change', 'submitted', v_me, v_me,
              jsonb_build_object('fn', 'add_term', 'lease_id', l.id, 'premises', l.premises, 'kind', p_kind,
                                 'label', v_label, 'amount_cents', abs(p_amount_cents - v_prev.amount_cents),
                                 'new_amount_cents', p_amount_cents, 'previous_amount_cents', v_prev.amount_cents,
                                 'every_months', coalesce(p_every_months, 1), 'effective_from', p_effective_from),
              'pending')
      returning id into v_event;
      v_result := jsonb_build_object('pending', true, 'event_id', v_event);
      return public.purchase_request_end(p_workspace_id, p_request_id, 'lease_term', v_digest, v_result);
    end if;
    update public.lease_terms set effective_to = p_effective_from - 1 where id = v_prev.id;$a$]);

-- ── notice: held whenever the space has a policy ─────────────────────────
select pg_temp.patch_function(
  'public.give_lease_notice_v1(uuid, uuid, integer, date, date, text, uuid)'::regprocedure,
  array[
    $a$  v_result jsonb;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  v_me := public.lease_actor(p_workspace_id, true);$a$,
    $a$  update public.expense_schedules es
     set ends_on = least(coalesce(es.ends_on, p_effective_end), p_effective_end)$a$],
  array[
    $a$  v_result jsonb;
  v_apply boolean := coalesce(current_setting('deskilo.lease_apply', true), '') <> '';
  v_event uuid;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if v_apply then
    v_me := current_setting('deskilo.lease_apply_actor')::uuid;
  else
    v_me := public.lease_actor(p_workspace_id, true);
  end if;$a$,
    $a$  if not v_apply and public.lease_notice_held(p_workspace_id) then
    insert into public.events (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
    values (p_workspace_id, 'lease_change', 'submitted', v_me, v_me,
            jsonb_build_object('fn', 'notice', 'lease_id', l.id, 'premises', l.premises,
                               'notice_given_on', p_notice_given_on, 'effective_end', p_effective_end,
                               'reason', left(btrim(p_reason), 500), 'amount_cents', 0),
            'pending')
    returning id into v_event;
    v_result := jsonb_build_object('pending', true, 'event_id', v_event);
    return public.purchase_request_end(p_workspace_id, p_request_id, 'lease_notice', v_digest, v_result);
  end if;
  update public.expense_schedules es
     set ends_on = least(coalesce(es.ends_on, p_effective_end), p_effective_end)$a$]);

-- ── the confirmation applies it ───────────────────────────────────────────
create or replace function public.lease_change_apply()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare v_rev int;
begin
  if new.type <> 'lease_change' or new.status <> 'confirmed' or old.status = 'confirmed' then
    return new;
  end if;
  select revision into v_rev from public.premises_leases
   where id = (new.payload ->> 'lease_id')::uuid and workspace_id = new.workspace_id;
  if v_rev is null then raise exception 'the lease no longer exists'; end if;
  perform set_config('deskilo.lease_apply', '1', true);
  perform set_config('deskilo.lease_apply_actor', new.actor_member_id::text, true);
  if new.payload ->> 'fn' = 'add_term' then
    perform public.add_lease_term_v1(new.workspace_id, (new.payload ->> 'lease_id')::uuid, v_rev,
      new.payload ->> 'kind', new.payload ->> 'label', (new.payload ->> 'new_amount_cents')::int,
      (new.payload ->> 'every_months')::int, (new.payload ->> 'effective_from')::date, gen_random_uuid());
  elsif new.payload ->> 'fn' = 'notice' then
    perform public.give_lease_notice_v1(new.workspace_id, (new.payload ->> 'lease_id')::uuid, v_rev,
      (new.payload ->> 'notice_given_on')::date, (new.payload ->> 'effective_end')::date,
      new.payload ->> 'reason', gen_random_uuid());
  end if;
  perform set_config('deskilo.lease_apply', '', true);
  perform set_config('deskilo.lease_apply_actor', '', true);
  return new;
end;
$fn$;
revoke execute on function public.lease_change_apply() from public, anon, authenticated;
drop trigger if exists events_lease_change_apply on public.events;
create trigger events_lease_change_apply after update on public.events
  for each row execute function public.lease_change_apply();

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(506);
