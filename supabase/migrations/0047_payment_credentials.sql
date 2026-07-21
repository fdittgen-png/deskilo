-- SPDX-License-Identifier: MIT
-- Per-workspace online-payment provider credentials, configurable from the
-- owner UI (previously only Edge-Function env secrets). NOT YET applied to
-- the hosted reference project — the orchestrator applies it after review.
--
-- SECURITY: secret keys (PayPal secret, Stripe key, Mollie key…) must never
-- be readable by any client. This table has RLS enabled with NO policies —
-- anon/authenticated are denied entirely. Only:
--   * SECURITY DEFINER RPCs below (owner-gated writes; status read-back that
--     returns key NAMES and non-secret fields, never the values), and
--   * the Edge Functions via the service role (which bypasses RLS),
-- ever touch it. Each community configures its OWN provider account, so a
-- leak is scoped to one workspace at worst — and the design prevents even
-- that. The Edge Functions read this table first and fall back to env, so
-- an existing CLI-secrets deployment keeps working.

create table public.payment_credentials (
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  provider text not null check (provider in ('paypal','stripe','mollie')),
  -- everything for the provider: secret keys + non-secret fields
  -- (return_url, env, webhook_id). Read only by the service role.
  config jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (workspace_id, provider)
);

alter table public.payment_credentials enable row level security;
-- Intentionally NO policies: deny-all to client roles.

-- The non-secret config fields a status read-back may echo back to the
-- owner UI. Everything else (secret, client_secret, api_key…) is a secret
-- and is only ever reported as PRESENT, never returned.
create or replace function public.payment_config_is_secret(p_key text)
returns boolean language sql immutable as $$
  select p_key not in ('return_url', 'env');
$$;

-- Owner-only: MERGE a provider's config. Non-blank fields overwrite;
-- blank/absent fields keep the existing value — so the owner can change
-- the return URL without re-typing secrets they can never read back. Use
-- clear_payment_provider to remove a provider entirely.
create or replace function public.set_payment_credentials(
  p_workspace_id uuid, p_provider text, p_config jsonb
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_clean jsonb;
begin
  if not public.is_owner_of(p_workspace_id) then
    raise exception 'not the owner of this workspace';
  end if;
  if p_provider not in ('paypal','stripe','mollie') then
    raise exception 'unknown provider';
  end if;
  -- drop null/blank entries (blank means "leave unchanged")
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

-- Owner-only: remove a provider's config entirely.
create or replace function public.clear_payment_provider(
  p_workspace_id uuid, p_provider text
) returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_owner_of(p_workspace_id) then
    raise exception 'not the owner of this workspace';
  end if;
  delete from public.payment_credentials
    where workspace_id = p_workspace_id and provider = p_provider;
end;
$$;
revoke execute on function public.clear_payment_provider(uuid, text) from public, anon;

-- Owner-only read-back for the config UI: per provider, whether it is
-- configured, its NON-SECRET fields, and the NAMES of the secret fields
-- that are set (never their values).
create or replace function public.payment_credentials_status(
  p_workspace_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_result jsonb := '{}'::jsonb;
  v_row public.payment_credentials;
  v_public jsonb;
  v_secret_keys text[];
begin
  if not public.is_owner_of(p_workspace_id) then
    raise exception 'not the owner of this workspace';
  end if;
  for v_row in
    select * from public.payment_credentials where workspace_id = p_workspace_id
  loop
    -- non-secret fields, echoed back
    select coalesce(jsonb_object_agg(key, value), '{}'::jsonb) into v_public
      from jsonb_each(v_row.config)
      where not public.payment_config_is_secret(key);
    -- names of the secret fields that are set
    select coalesce(array_agg(key), array[]::text[]) into v_secret_keys
      from jsonb_object_keys(v_row.config) key
      where public.payment_config_is_secret(key);
    v_result := v_result || jsonb_build_object(
      v_row.provider,
      jsonb_build_object(
        'configured', true,
        'public', v_public,
        'secret_keys', to_jsonb(v_secret_keys)
      )
    );
  end loop;
  return v_result;
end;
$$;
revoke execute on function public.payment_credentials_status(uuid) from public, anon;
