-- SPDX-License-Identifier: 0BSD
-- 0154 — #881: payment conditions — the workspace's default, a member's
-- own, changed only through validation with a permission.
--
-- The conditions printed on an invoice (payment terms, early-payment
-- discount, late penalty, recovery indemnity) lived only on
-- workspaces.invoice_legal. A member may now carry an OVERRIDE
-- (members.payment_terms, null = inherit). The member sees theirs and
-- cannot change them; an admin holding the paymentTermsEdit permission
-- REQUESTS a change, which is a validation event
-- (payment_terms_change) decided like every other domain; the decision
-- applies through an AFTER UPDATE trigger on events — never a branch in
-- respond_to_event (the 0151 idiom).

-- 1. The override.
alter table public.members
  add column if not exists payment_terms jsonb;

-- 2. The domain, on both check constraints.
alter table public.events drop constraint if exists events_type_check;
alter table public.events add constraint events_type_check
  check (type = any (array[
    'reservation', 'payment', 'expense', 'adjustment', 'service_charge',
    'quota', 'role_change', 'member_join', 'space_reservation',
    'invoice_payment', 'reservation_delete', 'invoice_writeoff',
    'invoice_reminder', 'price_negotiation', 'expense_schedule',
    'expense_repartition', 'usage_correction', 'usage_record_delete',
    'payment_terms_change']));
alter table public.validation_policies
  drop constraint if exists validation_policies_event_type_check;
alter table public.validation_policies
  add constraint validation_policies_event_type_check
  check (event_type is null or event_type = any (array[
    'reservation', 'payment', 'expense', 'adjustment', 'service_charge',
    'quota', 'role_change', 'member_join', 'space_reservation',
    'invoice_payment', 'reservation_delete', 'invoice_writeoff',
    'invoice_reminder', 'price_negotiation', 'expense_schedule',
    'expense_repartition', 'usage_correction', 'usage_record_delete',
    'payment_terms_change']));

-- 3. The policy row: the owner decides, admins may validate, one
--    decision — seeded where absent so the domain is never ungoverned.
insert into public.validation_policies
  (workspace_id, event_type, required_count, admins_may_validate,
   owner_required, validator_scope, sequential)
select w.id, 'payment_terms_change', 1, true, true, 'admins', false
  from public.workspaces w
 where not exists (select 1 from public.validation_policies p
                    where p.workspace_id = w.id
                      and p.event_type = 'payment_terms_change');

-- 4. Only the condition keys survive, trimmed; '{}' means "inherit".
create or replace function public.payment_terms_clean(p jsonb) returns jsonb
language sql immutable as $$
  select coalesce((
    select jsonb_object_agg(key, left(btrim(value), 2000))
      from jsonb_each_text(coalesce(p, '{}'::jsonb))
     where key in ('payment_terms', 'escompte', 'late_penalty', 'recovery_indemnity')
       and btrim(value) <> ''), '{}'::jsonb);
$$;

-- 5. What a member's documents print: the workspace's conditions, the
--    member's keys on top, `source` saying whether anything is theirs.
create or replace function public.effective_payment_terms(p_member_id uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select public.payment_terms_clean(w.invoice_legal)
         || coalesce(m.payment_terms, '{}'::jsonb)
         || jsonb_build_object('source',
              case when m.payment_terms is not null then 'member' else 'workspace' end)
    from public.members m join public.workspaces w on w.id = m.workspace_id
   where m.id = p_member_id;
$$;

-- 6. The permission: admins hold it by default, like the other
--    finance delegations; the matrix may take it away.
do $patch$
declare v_def text; v_anchor text;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'has_permission';
  if v_def is null then raise exception '0154: has_permission not found'; end if;
  v_anchor := E'''manageNegotiations'') end)';
  if position(v_anchor in v_def) = 0 then raise exception '0154: anchor missing'; end if;
  execute replace(v_def, v_anchor, E'''manageNegotiations'',''paymentTermsEdit'') end)');
end
$patch$;

-- 7. The request: a validation event carrying before/after.
create or replace function public.request_payment_terms_change(
  p_member_id uuid, p_terms jsonb, p_reason text default ''
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_member public.members;
  v_actor public.members;
  v_after jsonb;
  v_before jsonb;
  v_id uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  select * into v_member from public.members where id = p_member_id;
  if v_member.id is null then raise exception 'member not found'; end if;
  select * into v_actor from public.members
   where workspace_id = v_member.workspace_id and user_id = auth.uid()
     and status = 'active';
  if v_actor.id is null then raise exception 'not an active member'; end if;
  if not public.has_permission(v_member.workspace_id, 'paymentTermsEdit') then
    raise exception 'payment conditions are changed by an authorised admin';
  end if;
  v_after := public.payment_terms_clean(p_terms);
  v_before := public.effective_payment_terms(p_member_id) - 'source';
  -- Supersede: one open request per member.
  update public.events set status = 'expired'
   where type = 'payment_terms_change' and status = 'pending'
     and subject_member_id = p_member_id;
  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
  values (v_member.workspace_id, 'payment_terms_change', 'submitted',
          v_actor.id, p_member_id,
          jsonb_build_object('member_id', p_member_id, 'before', v_before,
                             'after', v_after, 'inherit', v_after = '{}'::jsonb,
                             'reason', left(coalesce(p_reason, ''), 300)),
          'pending')
  returning id into v_id;
  return v_id;
end;
$$;

-- 8. Apply on confirm — the trigger, never a respond_to_event branch.
create or replace function public.apply_payment_terms_decision()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = old.status then return new; end if;
  if new.type = 'payment_terms_change' and new.status = 'confirmed' then
    update public.members
       set payment_terms = case when public.payment_terms_clean(new.payload->'after') = '{}'::jsonb
                                then null
                                else public.payment_terms_clean(new.payload->'after') end
     where id = (new.payload->>'member_id')::uuid;
  end if;
  return new;
end;
$$;
drop trigger if exists events_apply_payment_terms on public.events;
create trigger events_apply_payment_terms
  after update on public.events
  for each row execute function public.apply_payment_terms_decision();
