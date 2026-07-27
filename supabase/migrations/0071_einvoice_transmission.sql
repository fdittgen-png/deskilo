-- SPDX-License-Identifier: 0BSD
-- Direct submission: the app stops handing out a file and SENDS it.
--
-- France has no free public channel any more (the PPF was cut back to a
-- directory in October 2024), so a workspace under the mandate works
-- through a plateforme agréée; elsewhere it is a Peppol access point or a
-- clearance platform's upload API. All of them come down to the same
-- shape: an endpoint, a credential, a document, and an id to track it by.
--
-- SECURITY mirrors 0047 (payment_credentials): the credentials table has
-- RLS enabled with NO policies — anon and authenticated are denied
-- entirely. Only the owner-gated SECURITY DEFINER RPCs below (which never
-- return a secret's value, just whether it is set) and the Edge Function
-- via the service role ever touch it.
--
-- NOT YET applied to the hosted reference project.

-- 1. Per-workspace platform credentials.
create table public.einvoice_credentials (
  workspace_id uuid primary key references public.workspaces(id)
    on delete cascade,
  -- 'generic' = any platform that accepts an HTTP upload with a bearer or
  -- basic credential. Named adapters join this list as they are written.
  provider text not null default 'generic'
    check (provider in ('generic')),
  -- endpoint, auth_header, auth_value, field_name, extra headers…
  -- Read only by the service role.
  config jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.einvoice_credentials enable row level security;
-- Intentionally NO policies: deny-all to client roles.

-- Which config fields may be echoed back to the owner UI. Everything else
-- is reported as PRESENT, never returned.
create or replace function public.einvoice_config_is_secret(p_key text)
returns boolean language sql immutable as $$
  select p_key not in ('endpoint', 'auth_header', 'field_name', 'provider');
$$;

-- 2. What was sent, and what came back. The audit trail beside the
-- immutable document — an invoice can be submitted more than once (a
-- platform outage, a rejected first attempt), so this is a LOG, not a
-- state column on the invoice.
create table public.invoice_transmissions (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id)
    on delete cascade,
  invoice_id uuid not null references public.invoices(id) on delete cascade,
  provider text not null,
  -- accepted = the platform took it; rejected = it answered no; failed =
  -- it could not be reached.
  status text not null check (status in ('accepted', 'rejected', 'failed')),
  -- The platform's own id for the document, when it returns one: the only
  -- handle for asking about it later.
  external_id text not null default '',
  -- SHA-256 of the bytes that left, so a later question ("which version
  -- did they get?") has an answer.
  document_hash text not null default '',
  detail text not null default '',
  sent_at timestamptz not null default now(),
  by_name text not null default ''
);
create index invoice_transmissions_invoice_idx
  on public.invoice_transmissions (invoice_id, sent_at desc);

alter table public.invoice_transmissions enable row level security;
-- Readable by the people who invoice; written only by the Edge Function
-- (service role) — a client cannot claim an invoice was sent.
create policy invoice_transmissions_select on public.invoice_transmissions
  for select using (public.is_admin_of(workspace_id));

-- 3. Owner-only: MERGE the config. Blank fields keep their stored value,
-- so the endpoint can change without re-typing a token nobody can read.
create or replace function public.set_einvoice_credentials(
  p_workspace_id uuid, p_config jsonb
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_clean jsonb;
begin
  if not public.is_owner_of(p_workspace_id) then
    raise exception 'not the owner of this workspace';
  end if;
  select coalesce(jsonb_object_agg(key, value), '{}'::jsonb) into v_clean
    from jsonb_each(coalesce(p_config, '{}'::jsonb))
    where value is not null and trim(both '"' from value::text) <> '';
  if v_clean = '{}'::jsonb then return; end if;

  insert into public.einvoice_credentials
    (workspace_id, config, updated_at)
  values (p_workspace_id, v_clean, now())
  on conflict (workspace_id) do update
    set config = public.einvoice_credentials.config || v_clean,
        updated_at = now();
end;
$$;
revoke execute on function
  public.set_einvoice_credentials(uuid, jsonb) from public, anon;

-- 4. Owner-only: forget the platform entirely.
create or replace function public.clear_einvoice_credentials(
  p_workspace_id uuid
) returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_owner_of(p_workspace_id) then
    raise exception 'not the owner of this workspace';
  end if;
  delete from public.einvoice_credentials where workspace_id = p_workspace_id;
end;
$$;
revoke execute on function
  public.clear_einvoice_credentials(uuid) from public, anon;

-- 5. Owner-only status read-back: the non-secret fields as they are, and
-- the NAMES of the secrets that are set. A token never comes back out.
create or replace function public.einvoice_status(p_workspace_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_config jsonb;
  v_public jsonb;
  v_secrets text[];
begin
  if not public.is_owner_of(p_workspace_id) then
    raise exception 'not the owner of this workspace';
  end if;
  select config into v_config from public.einvoice_credentials
    where workspace_id = p_workspace_id;
  if v_config is null then
    return jsonb_build_object('configured', false, 'fields',
      '{}'::jsonb, 'secrets_set', '[]'::jsonb);
  end if;
  select coalesce(jsonb_object_agg(key, value), '{}'::jsonb) into v_public
    from jsonb_each(v_config)
    where not public.einvoice_config_is_secret(key);
  select coalesce(array_agg(key), '{}') into v_secrets
    from jsonb_each(v_config)
    where public.einvoice_config_is_secret(key);
  return jsonb_build_object(
    'configured', true,
    'fields', v_public,
    'secrets_set', to_jsonb(v_secrets));
end;
$$;
revoke execute on function public.einvoice_status(uuid) from public, anon;
