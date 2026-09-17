-- SPDX-License-Identifier: 0BSD
-- risk: transforming
--
-- 0240 (#1452) — a captured payment names the ledger credit it posted.
--
-- `reconcile_workspace` (0213) accepted ANY credit with the same workspace,
-- member, amount and period as proof that a captured intent was posted.
-- Two captured payments of 25 € in one month with only one credit both
-- "found" that credit, and the missing posting stayed invisible.
--
-- Now:
--
--   * `payment_intents.ledger_entry_id` references the posting, and a
--     partial unique index makes one posting belong to at most one intent;
--   * `payment_intents_ledger_matches` refuses an association to a row that
--     is not a payment credit of the same workspace, member and amount —
--     even from a privileged writer;
--   * `settle_online_payment` posts the credit and records the association
--     in the same transaction (restated whole: 9 lines, its hosted body and
--     0205's file agree);
--   * reconciliation reports a captured intent whose association is absent
--     or no longer agrees with its posting — history that could not be
--     associated stays visible instead of guessed;
--   * existing captured intents are associated only when exactly one
--     credit matches and that credit matches exactly one intent.

alter table public.payment_intents
  add column if not exists ledger_entry_id uuid references public.ledger_entries(id);

create unique index if not exists payment_intents_ledger_entry_once
  on public.payment_intents (ledger_entry_id) where ledger_entry_id is not null;

create or replace function public.payment_intents_ledger_matches()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  l public.ledger_entries;
begin
  if new.ledger_entry_id is null then
    return new;
  end if;
  select * into l from public.ledger_entries where id = new.ledger_entry_id;
  if l.id is null
     or l.workspace_id <> new.workspace_id
     or l.member_id <> new.member_id
     or l.kind <> 'credit' or l.category <> 'payment'
     or l.amount_cents <> new.amount_cents then
    raise exception 'a payment intent is associated only with its own payment credit (same workspace, member and amount)';
  end if;
  return new;
end $$;

revoke execute on function public.payment_intents_ledger_matches() from public, anon, authenticated;

drop trigger if exists payment_intents_ledger_matches on public.payment_intents;
create trigger payment_intents_ledger_matches
  before insert or update of ledger_entry_id, workspace_id, member_id, amount_cents
  on public.payment_intents
  for each row execute function public.payment_intents_ledger_matches();

-- Unambiguous history only: one candidate credit for the intent, and that
-- credit a candidate for no other intent.
with cand as (
  select pi.id as intent_id, l.id as ledger_id
    from public.payment_intents pi
    join public.ledger_entries l
      on l.workspace_id = pi.workspace_id and l.member_id = pi.member_id
     and l.kind = 'credit' and l.category = 'payment'
     and l.amount_cents = pi.amount_cents and l.period = pi.period
   where pi.status = 'captured' and pi.ledger_entry_id is null
     and not exists (select 1 from public.payment_intents o where o.ledger_entry_id = l.id)
), per_intent as (
  select intent_id from cand group by intent_id having count(*) = 1
), per_ledger as (
  select ledger_id from cand group by ledger_id having count(*) = 1
)
update public.payment_intents pi
   set ledger_entry_id = c.ledger_id
  from cand c
  join per_intent a on a.intent_id = c.intent_id
  join per_ledger b on b.ledger_id = c.ledger_id
 where pi.id = c.intent_id;

create or replace function public.settle_online_payment(p_provider text, p_order_id text, p_capture_id text, p_amount_cents integer)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_intent public.payment_intents;
  v_ledger uuid;
begin
  select * into v_intent from public.payment_intents
    where provider = p_provider and order_id = p_order_id
    for update;
  if v_intent.id is null then
    raise exception 'unknown payment intent %/%', p_provider, p_order_id;
  end if;
  if v_intent.status = 'captured' then return; end if;
  if p_amount_cents is not null and p_amount_cents <> v_intent.amount_cents then
    raise exception 'captured amount % does not match the intent (%)', p_amount_cents, v_intent.amount_cents;
  end if;
  insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period)
  values (v_intent.workspace_id, v_intent.member_id, 'credit', 'payment', v_intent.amount_cents,
          p_provider || ' online payment', v_intent.period)
  returning id into v_ledger;
  -- #1452 — the capture names its posting, in the same transaction.
  update public.payment_intents
     set status = 'captured', capture_id = p_capture_id, ledger_entry_id = v_ledger
   where public.payment_intents.id = v_intent.id;
end;
$$;

revoke execute on function public.settle_online_payment(text, text, text, integer) from public, anon, authenticated;

create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
declare
  v_pattern text;
  v_out text;
begin
  if position(p_old in p_def) > 0 then
    return replace(p_def, p_old, p_new);
  end if;
  v_pattern := regexp_replace(btrim(p_old, E' \t\n'), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
  v_pattern := regexp_replace(v_pattern, '\s+', '\\s*', 'g');
  v_out := regexp_replace(p_def, v_pattern, replace(btrim(p_new, E' \t\n'), '\', '\\'), 'g');
  return case when v_out = p_def then null else v_out end;
end
$f$;

revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $migration$
declare
  v_def text;
  v_patched text;
begin
  v_def := pg_get_functiondef('public.reconcile_workspace(uuid)'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    $a$format('%s intent %s captured %s for %s, no matching ledger credit',
                pi.provider, pi.reference, pi.amount_cents, pi.period)
    from public.payment_intents pi
   where pi.workspace_id = p_workspace_id
     and pi.status = 'captured'
     and not exists (
       select 1 from public.ledger_entries l
        where l.workspace_id = pi.workspace_id
          and l.member_id = pi.member_id
          and l.kind = 'credit' and l.category = 'payment'
          and l.amount_cents = pi.amount_cents
          and l.period = pi.period)$a$,
    $a$format('%s intent %s captured %s for %s, %s',
                pi.provider, pi.reference, pi.amount_cents, pi.period,
                case when pi.ledger_entry_id is null
                     then 'no ledger credit is associated with it'
                     else 'its associated ledger credit does not match it' end)
    from public.payment_intents pi
   where pi.workspace_id = p_workspace_id
     and pi.status = 'captured'
     and not exists (
       select 1 from public.ledger_entries l
        where l.id = pi.ledger_entry_id
          and l.workspace_id = pi.workspace_id
          and l.member_id = pi.member_id
          and l.kind = 'credit' and l.category = 'payment'
          and l.amount_cents = pi.amount_cents
          and l.period = pi.period)$a$);
  if v_patched is null then
    raise exception '0240: anchor missing in reconcile_workspace (captured_payment_uncredited)';
  end if;
  execute v_patched;
end $migration$;

select public.set_deskilo_schema_version(240);
