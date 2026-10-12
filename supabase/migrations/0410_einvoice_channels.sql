-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (moves the e-invoice credentials' secret values out of
-- einvoice_credentials.config into Supabase Vault; the backfill is in this
-- file and keeps every value — config holds a marker where a secret was)
--
-- #2358 — the national e-invoicing channels.
--
-- 1. einvoice_credentials.provider names the connector the send-e-invoice
--    function uses: 'generic' (any HTTP upload, 0071) and now 'peppol' (an
--    access point), 'fr_pa' (a French plateforme agréée, AFNOR flow API),
--    'it_sdi' (the SdI through an intermediary), 'pl_ksef' (KSeF 2.0) and
--    'ro_efactura' (ANAF e-Factura). Nothing could set it before: the
--    'provider' key of set_einvoice_credentials landed in config, where no
--    reader looked. It now sets the column, and only to a known connector.
-- 2. Secrets leave the jsonb. A token stored in plain JSONB was readable by
--    anyone with a database dump or the service role's SQL console; Vault
--    keeps it encrypted at rest and decrypts only through
--    vault.decrypted_secrets, which only the service role may read. config
--    keeps the key with the marker "vault" so einvoice_status still reports
--    which secrets are SET, and the function resolves them through
--    einvoice_credentials_resolved(), which no client role can call.
-- 3. invoice_transmissions records what left (the syntax) and what came
--    back (the provider's receipt: a Peppol evidence, the PA lifecycle, the
--    SdI notifications, the KSeF number and UPO, the ANAF answer).

-- ── 1. the connectors ─────────────────────────────────────────────────
alter table public.einvoice_credentials
  drop constraint if exists einvoice_credentials_provider_check;
alter table public.einvoice_credentials
  add constraint einvoice_credentials_provider_check
  check (provider in ('generic', 'peppol', 'fr_pa', 'it_sdi', 'pl_ksef', 'ro_efactura'));

-- ── 2. what is public and what is a secret ────────────────────────────
-- Public: where to send and who the space is on the network. Everything
-- else stays a secret by default, as in 0071 — an unknown key is never
-- echoed back.
create or replace function public.einvoice_config_is_secret(p_key text)
returns boolean language sql immutable as $$
  select p_key !~ ('^(customer_)?(endpoint|auth_header|field_name|provider'
                   '|base_url|token_url|login_url|scope|legal_entity_id'
                   '|client_id|username|nip|cif)(_uat|_dev)?$');
$$;
revoke execute on function public.einvoice_config_is_secret(text) from public, anon;

create or replace function public.einvoice_secret_name(p_workspace_id uuid, p_key text)
returns text language sql immutable as $$
  select 'einvoice:' || p_workspace_id::text || ':' || p_key;
$$;
revoke execute on function public.einvoice_secret_name(uuid, text) from public, anon;

-- Stores one secret in Vault (created or replaced) and returns the marker
-- config keeps in its place.
create or replace function public.einvoice_store_secret(
  p_workspace_id uuid, p_key text, p_value text
) returns jsonb
language plpgsql security definer set search_path = public, vault as $$
declare
  v_name text := public.einvoice_secret_name(p_workspace_id, p_key);
  v_id uuid;
begin
  select id into v_id from vault.secrets where name = v_name;
  if v_id is null then
    perform vault.create_secret(p_value, v_name, 'DesKilo e-invoice credential');
  else
    perform vault.update_secret(v_id, p_value);
  end if;
  return to_jsonb('vault'::text);
end;
$$;
revoke execute on function public.einvoice_store_secret(uuid, text, text)
  from public, anon, authenticated;

-- ── 3. writing the configuration ──────────────────────────────────────
create or replace function public.set_einvoice_credentials(
  p_workspace_id uuid, p_config jsonb
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_clean jsonb;
  v_stored jsonb := '{}'::jsonb;
  v_provider text;
  v_entry record;
begin
  if not public.has_permission(p_workspace_id, 'manageIntegrations') then
    raise exception 'not the owner of this workspace';
  end if;
  select coalesce(jsonb_object_agg(key, value), '{}'::jsonb) into v_clean
    from jsonb_each(coalesce(p_config, '{}'::jsonb))
    where value is not null and trim(both '"' from value::text) <> '';
  if v_clean = '{}'::jsonb then return; end if;

  -- #2358 — the connector is a column, never a config value.
  v_provider := v_clean ->> 'provider';
  v_clean := v_clean - 'provider';
  if v_provider is not null and v_provider not in
       ('generic', 'peppol', 'fr_pa', 'it_sdi', 'pl_ksef', 'ro_efactura') then
    raise exception 'unknown e-invoice provider %', v_provider
      using errcode = '22023';
  end if;

  for v_entry in select key, value from jsonb_each(v_clean) loop
    if public.einvoice_config_is_secret(v_entry.key) then
      v_stored := v_stored || jsonb_build_object(v_entry.key,
        public.einvoice_store_secret(p_workspace_id, v_entry.key,
                                     v_entry.value #>> '{}'));
    else
      v_stored := v_stored || jsonb_build_object(v_entry.key, v_entry.value);
    end if;
  end loop;

  insert into public.einvoice_credentials
    (workspace_id, provider, config, updated_at)
  values (p_workspace_id, coalesce(v_provider, 'generic'), v_stored, now())
  on conflict (workspace_id) do update
    set config = public.einvoice_credentials.config || v_stored,
        provider = coalesce(v_provider, public.einvoice_credentials.provider),
        updated_at = now();
end;
$$;
revoke execute on function public.set_einvoice_credentials(uuid, jsonb) from public, anon;

create or replace function public.clear_einvoice_credentials(p_workspace_id uuid)
returns void language plpgsql security definer set search_path = public, vault as $$
begin
  if not public.has_permission(p_workspace_id, 'manageIntegrations') then
    raise exception 'not the owner of this workspace';
  end if;
  delete from vault.secrets
   where name like public.einvoice_secret_name(p_workspace_id, '') || '%';
  delete from public.einvoice_credentials where workspace_id = p_workspace_id;
end;
$$;
revoke execute on function public.clear_einvoice_credentials(uuid) from public, anon;

-- The status read-back names the connector too, so the screen opens on
-- the provider the space actually uses.
create or replace function public.einvoice_status(p_workspace_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_row public.einvoice_credentials%rowtype;
  v_public jsonb;
  v_secrets text[];
begin
  if not public.has_permission(p_workspace_id, 'manageIntegrations') then
    raise exception 'not the owner of this workspace';
  end if;
  select * into v_row from public.einvoice_credentials
    where workspace_id = p_workspace_id;
  if v_row.workspace_id is null then
    return jsonb_build_object('configured', false, 'provider', 'generic',
      'fields', '{}'::jsonb, 'secrets_set', '[]'::jsonb);
  end if;
  select coalesce(jsonb_object_agg(key, value), '{}'::jsonb) into v_public
    from jsonb_each(v_row.config)
    where not public.einvoice_config_is_secret(key);
  select coalesce(array_agg(key), '{}') into v_secrets
    from jsonb_each(v_row.config)
    where public.einvoice_config_is_secret(key);
  return jsonb_build_object(
    'configured', true,
    'provider', v_row.provider,
    'fields', v_public,
    'secrets_set', to_jsonb(v_secrets));
end;
$$;
revoke execute on function public.einvoice_status(uuid) from public, anon;

-- ── 4. reading it back, for the function only ─────────────────────────
-- The provider and the whole configuration with every Vault marker
-- replaced by its decrypted value. Service role only: no client role can
-- call it, and its result is the only place a secret is plain text.
create or replace function public.einvoice_credentials_resolved(p_workspace_id uuid)
returns jsonb
language plpgsql security definer set search_path = public, vault as $$
declare
  v_row public.einvoice_credentials%rowtype;
  v_config jsonb := '{}'::jsonb;
  v_entry record;
  v_secret text;
begin
  select * into v_row from public.einvoice_credentials
    where workspace_id = p_workspace_id;
  if v_row.workspace_id is null then return null; end if;
  for v_entry in select key, value from jsonb_each(v_row.config) loop
    if v_entry.value = to_jsonb('vault'::text) then
      select decrypted_secret into v_secret from vault.decrypted_secrets
       where name = public.einvoice_secret_name(p_workspace_id, v_entry.key);
      v_config := v_config || jsonb_build_object(v_entry.key, coalesce(v_secret, ''));
    else
      v_config := v_config || jsonb_build_object(v_entry.key, v_entry.value);
    end if;
  end loop;
  return jsonb_build_object('provider', v_row.provider, 'config', v_config);
end;
$$;
revoke execute on function public.einvoice_credentials_resolved(uuid)
  from public, anon, authenticated;
grant execute on function public.einvoice_credentials_resolved(uuid) to service_role;

-- ── 5. the backfill: every plain secret moves into Vault ──────────────
do $backfill$
declare
  v_row record;
  v_entry record;
  v_config jsonb;
begin
  for v_row in select workspace_id, config from public.einvoice_credentials loop
    v_config := '{}'::jsonb;
    for v_entry in select key, value from jsonb_each(v_row.config) loop
      if v_entry.key = 'provider' then
        continue;
      elsif public.einvoice_config_is_secret(v_entry.key)
            and v_entry.value <> to_jsonb('vault'::text) then
        v_config := v_config || jsonb_build_object(v_entry.key,
          public.einvoice_store_secret(v_row.workspace_id, v_entry.key,
                                       v_entry.value #>> '{}'));
      else
        v_config := v_config || jsonb_build_object(v_entry.key, v_entry.value);
      end if;
    end loop;
    update public.einvoice_credentials
       set config = v_config
     where workspace_id = v_row.workspace_id;
  end loop;
end
$backfill$;

-- ── 6. what left, and what came back ──────────────────────────────────
alter table public.invoice_transmissions
  add column if not exists format text not null default '',
  add column if not exists receipt jsonb not null default '{}'::jsonb,
  add column if not exists receipt_at timestamptz;

comment on column public.invoice_transmissions.format is
  '#2358 — the syntax that left (facturX, peppolBis, xrechnung, en16931Cii, fatturaPa, ksefFa3, ciusRo); '''' before #2358';
comment on column public.invoice_transmissions.receipt is
  '#2358 — the provider''s answer about the document: Peppol evidence, PA lifecycle, SdI notifications, KSeF number and UPO, ANAF state';

select public.set_deskilo_schema_version(410);
