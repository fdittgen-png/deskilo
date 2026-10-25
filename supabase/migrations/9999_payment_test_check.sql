-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- #2871 — the online-payments step's test: what a member's checkout would
-- do with the keys this space holds, without making a payment. It reads
-- the stored provider rows and says, per provider, whether the key is a
-- test key (the provider takes no real money), a live key (it charges a
-- real card), a key that does not say, or a field this space does not
-- hold (the installation's own setting decides, which the database cannot
-- read). It also says whether the space takes payments at all: a
-- development space never opens an order (create-payment-order, #917).
--
-- The test never calls a provider, never opens a payment intent, never
-- writes a ledger entry or an invoice, and never returns a secret: only a
-- mode word per provider. Whether the provider accepts the keys and tells
-- DesKilo a payment arrived is not something it can prove; the step says
-- so beside the answer.
--
-- Key shapes are the providers' own: Stripe secret and restricted keys
-- start sk_/rk_ then test_/live_; Mollie keys (Wero rides Mollie) start
-- test_/live_; PayPal's environment is the `env` field, and the order
-- handler uses the sandbox unless it reads `live` (_shared/providers.ts).

create or replace function public.payment_test_check(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_environment text;
  v_row public.payment_credentials;
  v_key text;
  v_mode text;
  v_providers jsonb := '[]'::jsonb;
begin
  if not public.is_owner_of(p_workspace_id) then
    raise exception 'only an owner of this workspace tests its online payments'
      using errcode = '42501';
  end if;
  if not public.feature_effective(p_workspace_id, 'onlinePayments') then
    raise exception 'online payments are switched off in this workspace'
      using errcode = '42501';
  end if;
  select environment into v_environment from public.workspaces where id = p_workspace_id;

  for v_row in
    select * from public.payment_credentials
     where workspace_id = p_workspace_id order by provider
  loop
    if v_row.provider = 'paypal' then
      v_mode := case coalesce(v_row.config->>'env', '')
                  when 'live' then 'live'
                  when 'sandbox' then 'test'
                  else 'installation' end;
    else
      v_key := coalesce(case v_row.provider when 'stripe' then v_row.config->>'secret_key'
                                            else v_row.config->>'api_key' end, '');
      v_mode := case
        when v_key = '' then 'installation'
        when v_row.provider = 'stripe' and v_key ~ '^(sk|rk)_test_' then 'test'
        when v_row.provider = 'stripe' and v_key ~ '^(sk|rk)_live_' then 'live'
        when v_row.provider <> 'stripe' and v_key ~ '^test_' then 'test'
        when v_row.provider <> 'stripe' and v_key ~ '^live_' then 'live'
        else 'unknown' end;
    end if;
    v_providers := v_providers || jsonb_build_array(
      jsonb_build_object('provider', v_row.provider, 'mode', v_mode));
  end loop;

  return jsonb_build_object(
    'charged', false,
    'takes_payments', coalesce(v_environment, 'dev') = 'prod',
    'providers', v_providers,
    'verdict', case
      when jsonb_array_length(v_providers) = 0 then 'no_provider'
      when exists (select 1 from jsonb_array_elements(v_providers) p
                    where p->>'mode' = 'live') then 'live_keys'
      when not exists (select 1 from jsonb_array_elements(v_providers) p
                        where p->>'mode' <> 'test') then 'test_keys'
      else 'unverified' end);
end;
$fn$;
revoke execute on function public.payment_test_check(uuid) from public, anon;
grant execute on function public.payment_test_check(uuid) to authenticated;

select public.set_deskilo_schema_version(9999);
