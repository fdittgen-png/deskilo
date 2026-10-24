-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- Additive: three columns with defaults on the installation_identity
-- singleton, one operator function. No row is rewritten beyond the
-- defaults; every installation reads `unset`, which is today's behaviour.
--
-- #2561 L3 -- the personal home an installation names, explicitly.
--
-- 0559 told an installation WHAT it is (`roles`). This tells a client where
-- the personal home of its people is, so nothing has to guess it from the
-- last workspace somebody opened:
--
--   unset     nothing declared. An installation that is a personal home
--             (combined or personal_home) keeps today's behaviour: its
--             directory is the reference deployment's. A workspace host
--             that declared nothing is a configuration error the client
--             reports, never a reason to treat the host as a home.
--   self      this installation is the personal home, and its own
--             directory is the one its people read. Only an installation
--             with the personal_home role may say so.
--   endpoint  the personal home is another installation, named by its
--             HTTPS origin and publishable key. Only a workspace host that
--             is NOT a personal home may name another one: a personal home
--             does not delegate to a second.
--
-- The declaration is public in the way the roles are (0559, 0299): column
-- grants under the existing read policy, no definer door. The key is a
-- publishable one by construction: the table refuses anything else, so a
-- secret pasted by mistake is never stored where anonymous readers see it.
-- `operator_set_personal_home` is an operator function in the sense of
-- 0312/0318/0559: SECURITY DEFINER, executable by nobody the API lets in;
-- the instance wizard and the operator's tooling call it through the
-- Management API. Every change is audited. A role change through
-- `operator_set_installation_roles` does not touch the declaration; the
-- doctor and the client name a declaration the roles contradict.

-- ── the declaration ──────────────────────────────────────────────────
alter table public.installation_identity
  add column if not exists personal_home_kind text not null default 'unset',
  add column if not exists personal_home_url text,
  add column if not exists personal_home_key text;

-- Whether p_key is a key a client may send and share: `sb_publishable_...`,
-- or a legacy JWT that declares role anon and names nobody. The same
-- classification as the app's (lib/core/backend/backend_key.dart); it reads
-- the claims and proves nothing about their signature.
create or replace function public.is_publishable_backend_key(p_key text)
returns boolean language plpgsql immutable set search_path = public as $fn$
declare
  v_part text;
  v_claims jsonb;
begin
  if p_key is null or length(p_key) > 4096 or p_key ~ '\s' then return false; end if;
  if left(p_key, 15) = 'sb_publishable_' then return length(p_key) > 20; end if;
  if p_key !~ '^eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*$' then return false; end if;
  v_part := translate(split_part(p_key, '.', 2), '-_', '+/');
  v_part := v_part || repeat('=', (4 - length(v_part) % 4) % 4);
  begin
    v_claims := convert_from(decode(v_part, 'base64'), 'UTF8')::jsonb;
  exception when others then
    return false;
  end;
  return jsonb_typeof(v_claims) = 'object'
     and v_claims->>'role' = 'anon'
     and not (v_claims ? 'sub');
end;
$fn$;
revoke execute on function public.is_publishable_backend_key(text) from public, anon, authenticated;

alter table public.installation_identity
  drop constraint if exists installation_identity_personal_home_check;
alter table public.installation_identity
  add constraint installation_identity_personal_home_check check (
    personal_home_kind in ('unset', 'self', 'endpoint')
    and (personal_home_kind = 'endpoint') = (personal_home_url is not null)
    and (personal_home_url is null) = (personal_home_key is null)
    and (personal_home_url is null
         or personal_home_url ~ '^https://[a-z0-9-]+(\.[a-z0-9-]+)+(:[0-9]{1,5})?$')
    and (personal_home_key is null or public.is_publishable_backend_key(personal_home_key)));
comment on column public.installation_identity.personal_home_kind is
  '#2561 L3 -- unset, self or endpoint: where the personal home of this '
  'installation''s people is. Changed only by operator_set_personal_home.';
comment on column public.installation_identity.personal_home_url is
  '#2561 L3 -- the HTTPS origin of the declared personal home (endpoint only).';
comment on column public.installation_identity.personal_home_key is
  '#2561 L3 -- the publishable key of the declared personal home (endpoint only).';
grant select (personal_home_kind, personal_home_url, personal_home_key)
  on public.installation_identity to anon, authenticated;

-- ── the operator function ────────────────────────────────────────────
create or replace function public.operator_set_personal_home(
  p_kind text, p_url text default null, p_key text default null,
  p_installation_id uuid default null)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_roles text[];
  v_url text := nullif(lower(trim(trailing '/' from trim(coalesce(p_url, '')))), '');
  v_key text := nullif(trim(coalesce(p_key, '')), '');
  v_before jsonb;
  v_after jsonb;
begin
  perform pg_advisory_xact_lock(hashtextextended('installation_roles', 2561));
  if p_installation_id is not null
     and p_installation_id is distinct from public.installation_id() then
    raise exception 'this database is installation %, not %',
      public.installation_id(), p_installation_id using errcode = '55000';
  end if;
  if p_kind is null or p_kind not in ('unset', 'self', 'endpoint') then
    raise exception 'the personal home is unset, self or endpoint' using errcode = '22023';
  end if;
  select roles,
         jsonb_build_object('kind', personal_home_kind, 'url', personal_home_url)
    into v_roles, v_before
    from public.installation_identity;
  if p_kind = 'endpoint' then
    if v_url is null or v_url !~ '^https://[a-z0-9-]+(\.[a-z0-9-]+)+(:[0-9]{1,5})?$' then
      raise exception 'a personal home is named by its HTTPS origin, without a path'
        using errcode = '22023';
    end if;
    if not public.is_publishable_backend_key(v_key) then
      raise exception 'a personal home is named with its publishable key, never a secret one'
        using errcode = '22023';
    end if;
    if 'personal_home' = any (v_roles) then
      raise exception 'this installation is a personal home: it names no other one'
        using errcode = 'DKR03';
    end if;
  else
    if v_url is not null or v_key is not null then
      raise exception 'only an endpoint declaration carries a URL and a key'
        using errcode = '22023';
    end if;
    if p_kind = 'self' and not ('personal_home' = any (v_roles)) then
      raise exception 'this installation is not a personal home: it cannot name itself'
        using errcode = 'DKR03';
    end if;
  end if;
  v_after := jsonb_build_object('kind', p_kind, 'url', v_url);
  if v_before = v_after
     and (p_kind <> 'endpoint'
          or (select personal_home_key from public.installation_identity) = v_key) then
    return v_after || jsonb_build_object('unchanged', true);
  end if;
  update public.installation_identity
     set personal_home_kind = p_kind,
         personal_home_url = case when p_kind = 'endpoint' then v_url end,
         personal_home_key = case when p_kind = 'endpoint' then v_key end;
  insert into public.database_authority_audit (installation_id, action, actor, detail)
  values (public.installation_id(), 'personal_home_set', 'operator',
          jsonb_build_object('from', v_before, 'to', v_after));
  return v_after || jsonb_build_object('unchanged', false);
end;
$fn$;
revoke execute on function public.operator_set_personal_home(text, text, text, uuid)
  from public, anon, authenticated;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(565);
