-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0757 (#3905) -- a payment the provider reverses (a dispute, a refund made
-- at the provider, a chargeback) is recorded on its online payment: the
-- payment becomes `reversed`, with when and why, and a person corrects the
-- ledger. No entry is posted on its own. A reversed payment is never credited
-- again by a late capture event.

alter table public.payment_intents drop constraint if exists payment_intents_status_check;
alter table public.payment_intents add constraint payment_intents_status_check
  check (status in ('created', 'captured', 'failed', 'reversed'));
alter table public.payment_intents add column if not exists reversed_at timestamptz;
alter table public.payment_intents add column if not exists reversal_reason text;

comment on column public.payment_intents.reversed_at is
  '#3905 -- when the provider reported the payment reversed (a dispute, a refund at the provider, a chargeback).';
comment on column public.payment_intents.reversal_reason is
  '#3905 -- the provider''s kind of reversal, as it named it.';

-- The provider reports a captured payment reversed. Idempotent, and it never
-- touches a payment that was not captured.
create or replace function public.mark_payment_reversed(p_provider text, p_order_id text, p_reason text)
returns void language sql security definer set search_path = public as $fn$
  update public.payment_intents
     set status = 'reversed', reversed_at = now(), reversal_reason = left(coalesce(p_reason, ''), 200)
   where provider = p_provider and order_id = p_order_id and status = 'captured';
$fn$;

revoke execute on function public.mark_payment_reversed(text, text, text) from public, anon, authenticated;
grant execute on function public.mark_payment_reversed(text, text, text) to service_role;

-- A capture event of a reversed payment credits nothing.
create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
begin
  if (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old) <> 1 then
    return null;
  end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public, anon, authenticated;

do $migration$
declare
  v_def text;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'settle_online_payment';
  -- Applied once: a second run leaves the function as it is.
  if position($a$v_intent.status in ('captured', 'reversed')$a$ in v_def) > 0 then return; end if;
  v_def := pg_temp.anchor_replace(v_def,
    $a$  if v_intent.status = 'captured' then return; end if;$a$,
    $a$  if v_intent.status in ('captured', 'reversed') then return; end if;$a$);
  if v_def is null then
    raise exception 'an anchor of #3905 was not found in settle_online_payment' using errcode = 'P0001';
  end if;
  execute v_def;
end
$migration$;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(757);
