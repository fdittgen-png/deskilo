-- SPDX-License-Identifier: 0BSD
-- Wero as an online-payment provider. NOT YET applied to the hosted
-- reference project — the orchestrator applies it after review.
--
-- Wero (the European wallet) has no broadly-available direct merchant API,
-- so DesKilo offers it THROUGH Mollie, which lists Wero as a checkout
-- method. A 'wero' payment is a Mollie payment created with method='wero';
-- its config is a Mollie API key + return URL (Wero must be enabled in the
-- workspace's Mollie account). Settlement rides the existing Mollie webhook
-- — it now matches intents of provider 'mollie' OR 'wero'.

alter table public.payment_intents drop constraint payment_intents_provider_check;
alter table public.payment_intents add constraint payment_intents_provider_check
  check (provider in ('paypal','stripe','mollie','wero'));

alter table public.payment_credentials drop constraint payment_credentials_provider_check;
alter table public.payment_credentials add constraint payment_credentials_provider_check
  check (provider in ('paypal','stripe','mollie','wero'));

-- set_payment_credentials: allow the new provider (body = 0047 verbatim +
-- 'wero' in the guard).
create or replace function public.set_payment_credentials(
  p_workspace_id uuid, p_provider text, p_config jsonb
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_clean jsonb;
begin
  if not public.is_owner_of(p_workspace_id) then
    raise exception 'not the owner of this workspace';
  end if;
  if p_provider not in ('paypal','stripe','mollie','wero') then
    raise exception 'unknown provider';
  end if;
  select coalesce(jsonb_object_agg(key, value), '{}'::jsonb) into v_clean
    from jsonb_each(coalesce(p_config, '{}'::jsonb))
    where value is not null and trim(both '"' from value::text) <> '';
  if v_clean = '{}'::jsonb then return; end if;

  insert into public.payment_credentials (workspace_id, provider, config, updated_at)
  values (p_workspace_id, p_provider, v_clean, now())
  on conflict (workspace_id, provider)
    do update set config = public.payment_credentials.config || v_clean,
                  updated_at = now();
end;
$$;
revoke execute on function public.set_payment_credentials(uuid, text, jsonb) from public, anon;
