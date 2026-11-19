-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (payment_intent_claim_open and payment_claim_resume_state restated whole;
--  hand_payment_intent patched at asserted anchors of its live definition;
--  payment_claim_window dropped once nothing calls it)
--
-- #4217 -- continuing a checkout, with these rules:
--   1. Continue is offered and accepted only while the claim still equals
--      what is owed: every invoice of the claim is open and takes a match,
--      and the sum still due on them equals the claim's amount. Otherwise
--      the claim is 'changed': it cannot be continued, and its member takes
--      it back and pays what is owed now.
--   2. Continue follows the business's online-payment setting: switched off,
--      it is neither offered nor accepted.
--   3. A checkout is sent again under its original request only for as long
--      as its provider keeps that request: the window is the provider's own,
--      a platform setting per provider (payments.resend_window_<provider>_
--      minutes), counted from the first hand-over. A claim never handed over
--      lapses after the same window, counted from its opening.
--   4. A claim handed over before the business last changed that provider's
--      credentials cannot be continued: it is answered as in rule 1.
--   5. A claim handed over whose window has passed is 'awaiting_provider':
--      the provider may still settle it, and it is not called expired.

-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
-- END GENERATED SEED

-- 3: the provider's own window. Wero rides Mollie. A provider without a
-- window has none: nothing of it is sent again.
create or replace function public.payment_resend_window(p_provider text)
returns interval language sql stable security definer set search_path = public as $fn$
  select make_interval(mins => coalesce((public.setting_value(null,
    'payments.resend_window_' || case p_provider when 'wero' then 'mollie' else p_provider end
    || '_minutes') #>> '{}')::int, 0));
$fn$;
revoke execute on function public.payment_resend_window(text) from public, anon, authenticated;

create or replace function public.payment_intent_claim_open(p_intent public.payment_intents)
returns boolean language sql stable set search_path = public as $fn$
  select p_intent.status = 'created'
     and p_intent.claimed_invoice_ids is not null
     and p_intent.claim_withdrawn_at is null
     and (p_intent.handed_at is not null
          or p_intent.created_at > now() - public.payment_resend_window(p_intent.provider));
$fn$;

-- 3: a checkout already handed over is sent again only inside its window,
-- counted from the hand-over; one never handed lapses from its opening.
do $patch$
declare
  v_def text := pg_get_functiondef('public.hand_payment_intent(uuid)'::regprocedure);
  v_handed constant text := $a$if v_intent.handed_at is not null then return true; end if;$a$;
  v_window constant text := $a$if v_intent.created_at <= clock_timestamp() - public.payment_claim_window() then$a$;
begin
  if (length(v_def) - length(replace(v_def, v_handed, ''))) / length(v_handed) <> 1
     or (length(v_def) - length(replace(v_def, v_window, ''))) / length(v_window) <> 1 then
    raise exception 'hand_payment_intent: its anchors are not there exactly once' using errcode = 'P0001';
  end if;
  v_def := replace(v_def, v_handed, $a$if v_intent.handed_at is not null then
    return v_intent.handed_at > clock_timestamp() - public.payment_resend_window(v_intent.provider);
  end if;$a$);
  v_def := replace(v_def, v_window,
    $a$if v_intent.created_at <= clock_timestamp() - public.payment_resend_window(v_intent.provider) then$a$);
  execute v_def;
end;
$patch$;

drop function public.payment_claim_window();

-- 1, 2, 4, 5: what a claim answers about continuing it.
create or replace function public.payment_claim_resume_state(p_intent public.payment_intents)
returns text language sql stable set search_path = public as $fn$
  select case
    when p_intent.id is null then null
    when p_intent.claim_withdrawn_at is not null then 'withdrawn'
    when p_intent.status in ('captured', 'failed', 'reversed') then p_intent.status
    when p_intent.status <> 'created' then 'unavailable'
    -- 5: handed over and past its window: the provider may still settle it
    when p_intent.handed_at is not null
         and p_intent.handed_at <= now() - public.payment_resend_window(p_intent.provider)
      then 'awaiting_provider'
    when not public.payment_intent_claim_open(p_intent) then 'expired'
    when p_intent.request_id is null or coalesce(cardinality(p_intent.claimed_invoice_ids), 0) = 0 then 'unavailable'
    -- 2
    when not public.feature_effective(p_intent.workspace_id, 'onlinePayments') then 'unavailable'
    -- 4
    when p_intent.handed_at is not null and exists (
           select 1 from public.payment_credentials c
            where c.workspace_id = p_intent.workspace_id
              and c.provider = p_intent.provider
              and c.updated_at > p_intent.handed_at)
      then 'changed'
    -- 1
    when exists (select 1 from unnest(p_intent.claimed_invoice_ids) x(id)
                  where public.invoice_match_blocker(x.id) is not null)
         or (select coalesce(sum(public.invoice_still_due_cents(x.id)), 0)
               from unnest(p_intent.claimed_invoice_ids) x(id)) <> p_intent.amount_cents
      then 'changed'
    else 'ready'
  end;
$fn$;
revoke execute on function public.payment_claim_resume_state(public.payment_intents) from public, anon, authenticated;

select public.set_deskilo_schema_version(814);
