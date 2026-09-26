-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0269 (#1647) -- one canonical Deskilo identity, bound to the local
-- users of this installation.
--
-- A person registers once. The standard deployment and a bring-your-own
-- Supabase each keep their own `auth.users` row for them, with its own
-- UUID; existing roles, members, decisions and invoices keep using that
-- local UUID. What was missing is the fact that two local accounts are the
-- same person -- and matching e-mail strings or copying UUIDs is exactly
-- how that fact must NOT be established.
--
--   * `installation_identity` -- this database's own id, one row.
--   * `identity_authority`    -- the operator's statement of which issuer
--     is canonical here: `native` (this installation's own Auth IS the
--     authority; the local subject maps directly) or `oidc` (an operator-
--     configured OIDC provider in this project's Auth). No row = no
--     authority configured = no binding, status `unavailable`.
--   * `identity_bindings`     -- (installation, local user) -> (issuer,
--     subject), with how it was proved and an immutable history: a binding
--     is revoked, never rewritten.
--
-- The subject comes from TRUSTED Auth records only: `auth.uid()` for a
-- native authority, `auth.identities` written by Auth for the configured
-- provider for OIDC. `raw_user_meta_data` and anything the caller sends
-- are never read. A binding confers nothing: no membership, no role, no
-- MCP eligibility (#1608/#1611 consume it). Unlink invalidates whatever a
-- later leaf attaches to it (#1631); this file attaches nothing.
--
-- No client may write any of the three tables. The caller reads and
-- finalizes ITS OWN binding through the two definer functions below.

create table if not exists public.installation_identity (
  singleton boolean primary key default true check (singleton),
  installation_id uuid not null default gen_random_uuid() unique
);
select public.ensure_system_columns('installation_identity');
insert into public.installation_identity (singleton) values (true)
on conflict (singleton) do nothing;
alter table public.installation_identity enable row level security;
revoke all on table public.installation_identity from anon, authenticated;
comment on table public.installation_identity is
  '#1647 -- this database''s own installation id. One row, never copied '
  'between installations: a restored or cloned project keeps the id only '
  'when it IS the same installation.';

create table if not exists public.identity_authority (
  singleton boolean primary key default true check (singleton),
  kind text not null check (kind in ('native', 'oidc')),
  issuer text not null check (issuer ~ '^https://[^\s/]+(/\S*)?$'),
  -- The Auth provider name that carries the OIDC identity (e.g.
  -- `keycloak`, `custom:deskilo`). Required for `oidc`, absent for native.
  oidc_provider text,
  check ((kind = 'oidc') = (oidc_provider is not null))
);
select public.ensure_system_columns('identity_authority');
alter table public.identity_authority enable row level security;
revoke all on table public.identity_authority from anon, authenticated;
comment on table public.identity_authority is
  '#1647 -- the operator''s statement of the canonical identity issuer '
  'for this installation. Written by the operator (service role or SQL), '
  'never by a client, never carried by a template or an export.';

create table if not exists public.identity_bindings (
  id uuid primary key default gen_random_uuid(),
  installation_id uuid not null
    references public.installation_identity (installation_id),
  local_user_id uuid not null references auth.users (id) on delete cascade,
  issuer text not null,
  subject text not null check (length(subject) between 1 and 255),
  verified_via text not null check (verified_via in ('native_authority', 'oidc_identity')),
  status text not null default 'active' check (status in ('active', 'revoked')),
  bound_at timestamptz not null default now(),
  revoked_at timestamptz,
  check ((status = 'revoked') = (revoked_at is not null))
);
select public.ensure_system_columns('identity_bindings');
-- One current canonical identity per local user, and one current local
-- user per canonical identity in this installation.
create unique index if not exists identity_bindings_one_per_local_user
  on public.identity_bindings (local_user_id) where status = 'active';
create unique index if not exists identity_bindings_one_per_subject
  on public.identity_bindings (installation_id, issuer, subject) where status = 'active';
alter table public.identity_bindings enable row level security;
revoke all on table public.identity_bindings from anon, authenticated;
comment on table public.identity_bindings is
  '#1647 -- which canonical (issuer, subject) a local Auth user of this '
  'installation is. History is kept: a binding is revoked, never '
  'rewritten, and confers no membership, role or MCP eligibility.';

-- History is immutable: the only change a binding may undergo is
-- active -> revoked.
create or replace function public.identity_bindings_immutable()
returns trigger language plpgsql set search_path = public as $fn$
begin
  if new.installation_id <> old.installation_id
     or new.local_user_id <> old.local_user_id
     or new.issuer <> old.issuer
     or new.subject <> old.subject
     or new.verified_via <> old.verified_via
     or new.bound_at <> old.bound_at then
    raise exception 'an identity binding is revoked, never rewritten';
  end if;
  if old.status = 'revoked' and new.status <> 'revoked' then
    raise exception 'a revoked identity binding stays revoked';
  end if;
  return new;
end;
$fn$;
revoke execute on function public.identity_bindings_immutable() from public, anon, authenticated;
drop trigger if exists identity_bindings_immutable on public.identity_bindings;
create trigger identity_bindings_immutable
  before update on public.identity_bindings
  for each row execute function public.identity_bindings_immutable();

-- The caller's own status. No subject, no raw Auth payload, no other user.
create or replace function public.my_identity_status()
returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_caller uuid := auth.uid();
  v_installation uuid;
  v_authority public.identity_authority;
  v_binding public.identity_bindings;
begin
  if v_caller is null then
    raise exception 'not authenticated';
  end if;
  select installation_id into v_installation from public.installation_identity;
  select * into v_authority from public.identity_authority;
  select * into v_binding from public.identity_bindings
   where local_user_id = v_caller and status = 'active';
  if v_binding.id is not null then
    return jsonb_build_object(
      'status', 'verified', 'installation_id', v_installation,
      'issuer', v_binding.issuer, 'verified_via', v_binding.verified_via,
      'bound_at', v_binding.bound_at);
  end if;
  if v_authority.kind is null then
    return jsonb_build_object('status', 'unavailable',
      'installation_id', v_installation, 'reason', 'no_authority');
  end if;
  return jsonb_build_object('status', 'unlinked',
    'installation_id', v_installation, 'issuer', v_authority.issuer);
end;
$fn$;
revoke execute on function public.my_identity_status() from public, anon;
grant execute on function public.my_identity_status() to authenticated;

-- Binds the CALLER, from trusted Auth records only. Idempotent for the
-- same identity; a different identity for an already-bound user, or an
-- identity already bound to another local user, is a conflict and
-- changes nothing -- relinking needs the explicit proof flow of #1648.
create or replace function public.finalize_identity_binding()
returns jsonb
language plpgsql volatile security definer set search_path = public, auth as $fn$
declare
  v_caller uuid := auth.uid();
  v_installation uuid;
  v_authority public.identity_authority;
  v_user auth.users;
  v_subject text;
  v_via text;
  v_existing public.identity_bindings;
  v_identity jsonb;
begin
  if v_caller is null then
    raise exception 'not authenticated';
  end if;
  select installation_id into v_installation from public.installation_identity;
  select * into v_authority from public.identity_authority;
  if v_authority.kind is null then
    return jsonb_build_object('status', 'unavailable',
      'installation_id', v_installation, 'reason', 'no_authority');
  end if;

  select * into v_user from auth.users where id = v_caller;
  if v_user.id is null or v_user.deleted_at is not null
     or coalesce(v_user.is_anonymous, false)
     or coalesce(v_user.banned_until > now(), false) then
    return jsonb_build_object('status', 'ineligible',
      'installation_id', v_installation, 'reason', 'account');
  end if;

  if v_authority.kind = 'native' then
    if v_user.email_confirmed_at is null and v_user.phone_confirmed_at is null then
      return jsonb_build_object('status', 'ineligible',
        'installation_id', v_installation, 'reason', 'unverified');
    end if;
    v_subject := v_caller::text;
    v_via := 'native_authority';
  else
    -- The identity Auth itself recorded for the configured provider.
    select identity_data into v_identity from auth.identities
     where user_id = v_caller and provider = v_authority.oidc_provider
     order by created_at limit 1;
    if v_identity is null then
      return jsonb_build_object('status', 'ineligible',
        'installation_id', v_installation, 'reason', 'no_provider_identity');
    end if;
    if v_identity ? 'iss' and v_identity->>'iss' <> v_authority.issuer then
      return jsonb_build_object('status', 'ineligible',
        'installation_id', v_installation, 'reason', 'issuer_mismatch');
    end if;
    v_subject := nullif(v_identity->>'sub', '');
    if v_subject is null then
      return jsonb_build_object('status', 'ineligible',
        'installation_id', v_installation, 'reason', 'no_subject');
    end if;
    v_via := 'oidc_identity';
  end if;

  -- Serialise every attempt on this canonical subject: two first bindings
  -- at once make one.
  perform pg_advisory_xact_lock(hashtextextended(
    v_installation::text || '|' || v_authority.issuer || '|' || v_subject, 1647));
  perform pg_advisory_xact_lock(hashtextextended(v_caller::text, 1647));

  select * into v_existing from public.identity_bindings
   where local_user_id = v_caller and status = 'active';
  if v_existing.id is not null then
    if v_existing.issuer = v_authority.issuer and v_existing.subject = v_subject then
      return jsonb_build_object('status', 'verified',
        'installation_id', v_installation, 'issuer', v_existing.issuer,
        'verified_via', v_existing.verified_via, 'bound_at', v_existing.bound_at);
    end if;
    return jsonb_build_object('status', 'conflict',
      'installation_id', v_installation, 'reason', 'local_user_bound_elsewhere');
  end if;
  if exists (select 1 from public.identity_bindings
              where installation_id = v_installation and issuer = v_authority.issuer
                and subject = v_subject and status = 'active') then
    return jsonb_build_object('status', 'conflict',
      'installation_id', v_installation, 'reason', 'subject_bound_to_another_user');
  end if;

  insert into public.identity_bindings
    (installation_id, local_user_id, issuer, subject, verified_via)
  values (v_installation, v_caller, v_authority.issuer, v_subject, v_via)
  returning * into v_existing;
  return jsonb_build_object('status', 'verified',
    'installation_id', v_installation, 'issuer', v_existing.issuer,
    'verified_via', v_existing.verified_via, 'bound_at', v_existing.bound_at);
end;
$fn$;
revoke execute on function public.finalize_identity_binding() from public, anon;
grant execute on function public.finalize_identity_binding() to authenticated;

-- The caller unlinks ITS OWN binding. What depends on it (#1611 eligibility,
-- #1615 sessions) is invalidated by those leaves' own triggers on revoke.
create or replace function public.revoke_my_identity_binding()
returns jsonb
language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_caller uuid := auth.uid();
  v_count int;
begin
  if v_caller is null then
    raise exception 'not authenticated';
  end if;
  update public.identity_bindings
     set status = 'revoked', revoked_at = now()
   where local_user_id = v_caller and status = 'active';
  get diagnostics v_count = row_count;
  return public.my_identity_status() || jsonb_build_object('revoked', v_count > 0);
end;
$fn$;
revoke execute on function public.revoke_my_identity_binding() from public, anon;
grant execute on function public.revoke_my_identity_binding() to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(269);
