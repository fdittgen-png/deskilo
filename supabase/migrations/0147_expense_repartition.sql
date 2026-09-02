-- SPDX-License-Identifier: 0BSD
-- 0147 — #828: a shared expense DISTRIBUTED over the members, and the
-- reverse — charges given back as credit notes.
--
--  * expense_repartitions — the distribution as a record: title, signed
--    amount (negative = a reversal), method, the period it lands on,
--    the shares (member, amount, weight), and its decision.
--  * distribute_expense(...) — files it through the validation
--    framework as an `expense_repartition` event: pending when a policy
--    row exists for the type, confirmed and APPLIED at once otherwise.
--  * apply_expense_repartition(id) — books one ledger row per share:
--    a CHARGE of category 'adjustment' for a cost, a CREDIT for a
--    reversal. invoice_lines_for (0109) already turns both into lines
--    of the period's USAGE invoice (0142), a credit netting the charges
--    and a month in credit deriving a credit note (0102). Nothing else
--    to teach the invoice engine.
--  * a trigger on events applies a later confirmation and records a
--    rejection or expiry.

create table if not exists public.expense_repartitions (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  title text not null,
  amount_cents int not null check (amount_cents <> 0),
  method text not null check (method in ('equal','subscription','usage','custom')),
  period text not null check (period ~ '^[0-9]{4}-[0-9]{2}$'),
  shares jsonb not null,
  source_event_id uuid references public.events(id) on delete set null,
  event_id uuid references public.events(id) on delete set null,
  status text not null default 'pending'
    check (status in ('pending','confirmed','rejected','expired')),
  created_by uuid references public.members(id) on delete set null,
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  applied_at timestamptz
);
create index if not exists expense_repartitions_workspace_idx
  on public.expense_repartitions (workspace_id, created_at desc);

alter table public.expense_repartitions enable row level security;
drop policy if exists expense_repartitions_select on public.expense_repartitions;
create policy expense_repartitions_select on public.expense_repartitions
  for select using (public.is_admin_of(workspace_id));

-- The event type, for the feed and for a validation rule on it.
alter table public.events drop constraint if exists events_type_check;
alter table public.events add constraint events_type_check check (type in
  ('reservation','payment','expense','adjustment','service_charge',
   'quota','role_change','member_join','space_reservation',
   'invoice_payment','reservation_delete','invoice_writeoff',
   'invoice_reminder','price_negotiation','expense_schedule',
   'expense_repartition'));
alter table public.validation_policies
  drop constraint if exists validation_policies_event_type_check;
alter table public.validation_policies
  add constraint validation_policies_event_type_check check (event_type in
  ('reservation','payment','expense','adjustment','service_charge',
   'quota','role_change','member_join','space_reservation',
   'invoice_payment','reservation_delete','invoice_writeoff',
   'invoice_reminder','price_negotiation','expense_schedule',
   'expense_repartition'));

-- Books the shares. Idempotent: a repartition applies once.
create or replace function public.apply_expense_repartition(p_id uuid)
returns void language plpgsql security definer
set search_path = public as $$
declare v_r public.expense_repartitions; v_share jsonb;
begin
  select * into v_r from public.expense_repartitions where id = p_id for update;
  if v_r.id is null or v_r.applied_at is not null then return; end if;
  for v_share in select * from jsonb_array_elements(v_r.shares) loop
    insert into public.ledger_entries
      (workspace_id, member_id, kind, category, amount_cents, description,
       period, event_id)
    values
      (v_r.workspace_id,
       (v_share->>'member_id')::uuid,
       case when v_r.amount_cents > 0 then 'charge' else 'credit' end,
       'adjustment',
       abs((v_share->>'amount_cents')::int),
       v_r.title,
       v_r.period,
       v_r.event_id);
  end loop;
  update public.expense_repartitions
     set applied_at = now(), status = 'confirmed',
         decided_at = coalesce(decided_at, now())
   where id = p_id;
end;
$$;
revoke execute on function public.apply_expense_repartition(uuid) from public, anon, authenticated;

create or replace function public.distribute_expense(
  p_workspace_id uuid,
  p_title text,
  p_amount_cents int,
  p_method text,
  p_period text,
  p_shares jsonb,
  p_source_event_id uuid default null
) returns uuid language plpgsql security definer
set search_path = public as $$
declare
  v_me public.members;
  v_share jsonb;
  v_sum int := 0;
  v_count int := 0;
  v_member uuid;
  v_amount int;
  v_id uuid;
  v_event_id uuid;
  v_has_policy boolean;
  v_title text := btrim(coalesce(p_title, ''));
begin
  -- The person who issues invoices distributes what they carry.
  v_me := public.issuing_member(p_workspace_id);
  if length(v_title) < 1 or length(v_title) > 120 then
    raise exception 'title must be 1-120 characters';
  end if;
  if coalesce(p_amount_cents, 0) = 0 then raise exception 'amount must not be zero'; end if;
  if p_method not in ('equal','subscription','usage','custom') then
    raise exception 'unknown method';
  end if;
  if p_period !~ '^[0-9]{4}-[0-9]{2}$' then raise exception 'period must be YYYY-MM'; end if;
  if p_shares is null or jsonb_typeof(p_shares) <> 'array'
     or jsonb_array_length(p_shares) = 0 then
    raise exception 'no shares';
  end if;
  for v_share in select * from jsonb_array_elements(p_shares) loop
    v_member := (v_share->>'member_id')::uuid;
    v_amount := (v_share->>'amount_cents')::int;
    if v_amount = 0 or sign(v_amount) <> sign(p_amount_cents) then
      raise exception 'a share must carry the sign of the amount';
    end if;
    if not exists (select 1 from public.members m
                    where m.id = v_member and m.workspace_id = p_workspace_id
                      and m.status = 'active' and not m.is_kiosk) then
      raise exception 'share for a member who is not active here';
    end if;
    v_sum := v_sum + v_amount;
    v_count := v_count + 1;
  end loop;
  if v_sum <> p_amount_cents then
    raise exception 'shares must add up to the amount';
  end if;
  if (select count(distinct s->>'member_id') from jsonb_array_elements(p_shares) s) <> v_count then
    raise exception 'a member appears twice';
  end if;
  if p_source_event_id is not null and not exists (
      select 1 from public.events e
       where e.id = p_source_event_id and e.workspace_id = p_workspace_id
         and e.type = 'expense') then
    raise exception 'unknown source expense';
  end if;

  insert into public.expense_repartitions
    (workspace_id, title, amount_cents, method, period, shares,
     source_event_id, created_by)
  values (p_workspace_id, v_title, p_amount_cents, p_method, p_period,
          p_shares, p_source_event_id, v_me.id)
  returning id into v_id;

  -- Pending iff a rule exists for the type; else decided by the issuer.
  v_has_policy := exists (
    select 1 from public.validation_policies vp
     where vp.workspace_id = p_workspace_id
       and vp.event_type = 'expense_repartition');
  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id,
     payload, status, decided_at)
  values
    (p_workspace_id, 'expense_repartition', 'submitted', v_me.id, v_me.id,
     jsonb_build_object(
       'repartition_id', v_id,
       'title', v_title,
       'amount_cents', p_amount_cents,
       'method', p_method,
       'period', p_period,
       'member_count', v_count),
     case when v_has_policy then 'pending' else 'confirmed' end,
     case when v_has_policy then null else now() end)
  returning id into v_event_id;
  update public.expense_repartitions set event_id = v_event_id where id = v_id;
  if not v_has_policy then
    perform public.apply_expense_repartition(v_id);
  end if;
  return v_id;
end;
$$;
revoke execute on function public.distribute_expense(uuid, text, int, text, text, jsonb, uuid)
  from public, anon;
grant execute on function public.distribute_expense(uuid, text, int, text, text, jsonb, uuid)
  to authenticated;

-- A decision reached later through the quorum applies (or closes) it.
create or replace function public.apply_expense_repartition_decision()
returns trigger language plpgsql security definer
set search_path = public as $$
begin
  if new.type <> 'expense_repartition' or new.status = old.status then
    return new;
  end if;
  if new.status = 'confirmed' then
    perform public.apply_expense_repartition(
      (new.payload->>'repartition_id')::uuid);
  elsif new.status in ('rejected','expired') then
    update public.expense_repartitions
       set status = new.status, decided_at = now()
     where id = (new.payload->>'repartition_id')::uuid;
  end if;
  return new;
end;
$$;
drop trigger if exists events_apply_expense_repartition on public.events;
create trigger events_apply_expense_repartition
  after update on public.events
  for each row execute function public.apply_expense_repartition_decision();

notify pgrst, 'reload schema';
