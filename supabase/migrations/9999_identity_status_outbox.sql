-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- Additive: five new tables, one sequence, the functions below, one
-- trigger pair on auth.users and one pg_cron job. No existing row is read
-- for anything but the account status and the identity configuration, and
-- none is rewritten.
--
-- #2562 C2b -- a personal home tells the enrolled workspace installations a
-- linked person's identity status, signed, and a workspace installation
-- accepts only a fresh, authentic, first-seen statement about one of its
-- own linked people.
--
-- The personal home (P, the identity authority) side:
--   * A change of a person's account status (suspended by a ban, erased by
--     deletion or soft deletion, active again when a ban is lifted) commits
--     one assertion per linked target IN THE SAME TRANSACTION, into
--     `identity_status_outbox`: issuer, subject, a revision from one
--     monotonic sequence, the status, `issued_at` and `valid_until` =
--     issued_at + `identity.status_assertion_lifetime_seconds`. A target is
--     linked when the person consented, in a native session, to that
--     installation's identity client (Auth's `oauth_consents` row, not
--     revoked), the client is enabled and the installation is enrolled and
--     in force (0292/0567). An unlinked identity is never enumerated.
--   * `identity_status_drain()` -- every minute through pg_cron -- signs
--     each pending assertion and posts it with pg_net to the target's
--     `federation-inbox` Edge function, reads the earlier answers, retries
--     what failed in transit and gives up on what expired. A refusal on
--     content (400/409/421/422) is final; 401, 5xx and silence are retried
--     until `valid_until`, after which any older assertion has lapsed too.
--   * Failing to read the links never blocks a ban or a deletion: it is
--     audited (`identity_status_unissued`) and the target's last assertion
--     still lapses at its own deadline.
--
-- The envelope (purpose-generic: #2563's membership facts reuse it): the
-- headers name protocol 1, the purpose, source and target installation,
-- the event id, the request time (unix seconds), the SHA-256 of the raw
-- body and the key id; `x-deskilo-signature` is HMAC-SHA256 over
-- `federation_signing_input` (method, path and all of the above) with the
-- key of that relationship and direction. Keys live in Vault only;
-- `federation_keys` keeps their id and Vault reference, one in force per
-- (peer, direction, purpose). Rotation retires the old key and deletes its
-- secret, so it verifies nothing any more.
--
-- The workspace installation (W) side: `federation_inbox_accept` is what
-- the Edge function calls with the raw body, as the service role only.
--   * refused before anything is read: a malformed envelope, another
--     target, an unknown installation (no inbound key in force), a retired
--     key, a bad signature (compared through a second HMAC under a random
--     nonce, so the comparison time says nothing), a body that is not the
--     signed digest, a request time ahead of the allowed skew;
--   * the event id is remembered per source: the same id with the same
--     digest is a harmless retry (`duplicate`), with another digest it is
--     tampering (`event_conflict`);
--   * an assertion must name this installation's configured issuer
--     (`identity_authority`, kind oidc) and a subject bound here -- an
--     active binding for `active`, any binding for a tombstone, so a
--     revoked binding cannot shed a suspension;
--   * the deadline is the issuer's `issued_at` plus the shorter of the two
--     lifetimes, never the receipt time; one issued further ahead than the
--     skew, or already past its deadline plus the skew, is refused;
--   * revisions only grow and `erased` is final: a late or replayed active
--     status cannot undo a suspension or a tombstone (`superseded`).
--
-- The local access gates that read `identity_status_assertions`, the
-- reconciliation of linked active subjects and the revocation of W Auth
-- sessions are #2562's next checkpoint; nothing here reads the table for
-- access yet. All five tables are closed to every API role and carry the
-- restrictive personal policies (no workspace_id: personal by the 0564
-- inventory). pgTAP 272 proves both sides in one database.

-- ── the keys ─────────────────────────────────────────────────────────
create table if not exists public.federation_keys (
  peer_installation_id uuid not null,
  direction text not null check (direction in ('outbound', 'inbound')),
  purpose text not null check (purpose in ('identity_status')),
  key_id text not null check (key_id ~ '^[A-Za-z0-9._-]{1,64}$'),
  vault_secret_id uuid not null,
  created_at timestamptz not null default now(),
  retired_at timestamptz,
  primary key (peer_installation_id, direction, purpose, key_id)
);
select public.ensure_system_columns('federation_keys');
create unique index if not exists federation_keys_one_in_force
  on public.federation_keys (peer_installation_id, direction, purpose) where retired_at is null;
comment on table public.federation_keys is
  '#2562 C2b -- the per-relationship, per-direction backchannel keys: their id and '
  'Vault reference, never the secret. Retired, never deleted.';

-- ── the personal home's outbox ───────────────────────────────────────
create sequence if not exists public.identity_status_revision;
revoke all on sequence public.identity_status_revision from public, anon, authenticated, service_role;

create table if not exists public.identity_status_outbox (
  event_id uuid primary key,
  target_installation_id uuid not null
    references public.enrolled_installations (installation_id),
  issuer text not null,
  subject text not null check (length(subject) between 1 and 255),
  revision bigint not null check (revision > 0),
  status text not null check (status in ('active', 'suspended', 'erased')),
  issued_at timestamptz not null,
  valid_until timestamptz not null check (valid_until > issued_at),
  body jsonb not null,
  state text not null default 'pending'
    check (state in ('pending', 'sent', 'delivered', 'refused', 'expired')),
  attempts int not null default 0,
  last_attempt_at timestamptz,
  net_request_id bigint,
  outcome text,
  delivered_at timestamptz
);
select public.ensure_system_columns('identity_status_outbox');
create index if not exists identity_status_outbox_due
  on public.identity_status_outbox (state, issued_at) where state in ('pending', 'sent');
comment on table public.identity_status_outbox is
  '#2562 C2b -- identity status assertions this personal home committed for its '
  'enrolled workspace installations, and how their delivery went.';

-- ── the workspace installation's side ────────────────────────────────
create table if not exists public.federation_inbox_receipts (
  source_installation_id uuid not null,
  event_id uuid not null,
  purpose text not null,
  body_digest text not null check (body_digest ~ '^[0-9a-f]{64}$'),
  outcome text not null,
  received_at timestamptz not null default now(),
  primary key (source_installation_id, event_id)
);
select public.ensure_system_columns('federation_inbox_receipts');
comment on table public.federation_inbox_receipts is
  '#2562 C2b -- every authenticated backchannel event this installation saw, by '
  'source and event id, with the digest that tells a retry from tampering.';

create table if not exists public.identity_status_assertions (
  issuer text not null,
  subject text not null check (length(subject) between 1 and 255),
  revision bigint not null check (revision > 0),
  status text not null check (status in ('active', 'suspended', 'erased')),
  asserted_at timestamptz not null,
  valid_until timestamptz not null check (valid_until > asserted_at),
  source_installation_id uuid not null,
  event_id uuid not null,
  received_at timestamptz not null default now(),
  primary key (issuer, subject)
);
select public.ensure_system_columns('identity_status_assertions');
comment on table public.identity_status_assertions is
  '#2562 C2b -- the latest identity status the trusted authority asserted for a '
  'person bound here. Written only by identity_status_apply; revisions only grow '
  'and an erased status is final.';

-- Closed to every API role; the restrictive personal policies all the same.
alter table public.federation_keys enable row level security;
revoke all on public.federation_keys from public, anon, authenticated, service_role;
drop policy if exists mcp_delegated_deny on public.federation_keys;
create policy mcp_delegated_deny on public.federation_keys
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
drop policy if exists personal_native_session on public.federation_keys;
create policy personal_native_session on public.federation_keys
  as restrictive for all to public
  using ((select public.personal_native_session()))
  with check ((select public.personal_native_session()));
alter table public.identity_status_outbox enable row level security;
revoke all on public.identity_status_outbox from public, anon, authenticated, service_role;
drop policy if exists mcp_delegated_deny on public.identity_status_outbox;
create policy mcp_delegated_deny on public.identity_status_outbox
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
drop policy if exists personal_native_session on public.identity_status_outbox;
create policy personal_native_session on public.identity_status_outbox
  as restrictive for all to public
  using ((select public.personal_native_session()))
  with check ((select public.personal_native_session()));
alter table public.federation_inbox_receipts enable row level security;
revoke all on public.federation_inbox_receipts from public, anon, authenticated, service_role;
drop policy if exists mcp_delegated_deny on public.federation_inbox_receipts;
create policy mcp_delegated_deny on public.federation_inbox_receipts
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
drop policy if exists personal_native_session on public.federation_inbox_receipts;
create policy personal_native_session on public.federation_inbox_receipts
  as restrictive for all to public
  using ((select public.personal_native_session()))
  with check ((select public.personal_native_session()));
alter table public.identity_status_assertions enable row level security;
revoke all on public.identity_status_assertions from public, anon, authenticated, service_role;
drop policy if exists mcp_delegated_deny on public.identity_status_assertions;
create policy mcp_delegated_deny on public.identity_status_assertions
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
drop policy if exists personal_native_session on public.identity_status_assertions;
create policy personal_native_session on public.identity_status_assertions
  as restrictive for all to public
  using ((select public.personal_native_session()))
  with check ((select public.personal_native_session()));

-- History guards: a key and an outbox entry keep what they said, a receipt
-- is kept, an assertion only moves forward.
create or replace function public.protect_federation_history()
returns trigger language plpgsql set search_path = '' as $fn$
begin
  if tg_op = 'DELETE' then
    raise exception '% keeps its history', tg_table_name using errcode = '55000';
  end if;
  -- Each table's fields are read only on its own branch.
  if tg_table_name = 'federation_keys' then
    if row(new.peer_installation_id, new.direction, new.purpose, new.key_id, new.vault_secret_id)
         is distinct from row(old.peer_installation_id, old.direction, old.purpose, old.key_id,
                              old.vault_secret_id)
       or (old.retired_at is not null and new.retired_at is distinct from old.retired_at) then
      raise exception 'a federation key is retired, never rewritten' using errcode = '55000';
    end if;
  elsif tg_table_name = 'identity_status_outbox' then
    if row(new.event_id, new.target_installation_id, new.issuer, new.subject, new.revision,
           new.status, new.issued_at, new.valid_until, new.body)
       is distinct from row(old.event_id, old.target_installation_id, old.issuer, old.subject,
           old.revision, old.status, old.issued_at, old.valid_until, old.body) then
      raise exception 'an issued assertion is never rewritten' using errcode = '55000';
    end if;
  elsif tg_table_name = 'federation_inbox_receipts' then
    raise exception 'a receipt is never rewritten' using errcode = '55000';
  elsif tg_table_name = 'identity_status_assertions' then
    if new.issuer <> old.issuer or new.subject <> old.subject
       or new.revision <= old.revision or old.status = 'erased' then
      raise exception 'an identity status only moves forward, and erased is final'
        using errcode = '55000';
    end if;
  end if;
  return new;
end;
$fn$;
revoke execute on function public.protect_federation_history()
  from public, anon, authenticated, service_role;
drop trigger if exists protect_federation_history on public.federation_keys;
create trigger protect_federation_history before update or delete on public.federation_keys
  for each row execute function public.protect_federation_history();
drop trigger if exists protect_federation_history on public.identity_status_outbox;
create trigger protect_federation_history before update or delete on public.identity_status_outbox
  for each row execute function public.protect_federation_history();
drop trigger if exists protect_federation_history on public.federation_inbox_receipts;
create trigger protect_federation_history before update or delete on public.federation_inbox_receipts
  for each row execute function public.protect_federation_history();
drop trigger if exists protect_federation_history on public.identity_status_assertions;
create trigger protect_federation_history before update or delete on public.identity_status_assertions
  for each row execute function public.protect_federation_history();

-- ── keys: operator functions ─────────────────────────────────────────
create or replace function public.operator_set_federation_key(
  p_peer uuid, p_direction text, p_purpose text, p_key_id text, p_secret text)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_replaced public.federation_keys;
  v_secret_id uuid;
begin
  perform pg_advisory_xact_lock(hashtextextended('federation_keys', 2562));
  if p_peer is null or p_peer = public.installation_id() then
    raise exception 'a federation key names another installation' using errcode = '22023';
  end if;
  if p_direction is null or p_direction not in ('outbound', 'inbound')
     or p_purpose is null or p_purpose not in ('identity_status') then
    raise exception 'a federation key is outbound or inbound, for identity_status'
      using errcode = '22023';
  end if;
  if p_key_id is null or p_key_id !~ '^[A-Za-z0-9._-]{1,64}$' then
    raise exception 'a key id is 1..64 letters, digits, dots, dashes or underscores'
      using errcode = '22023';
  end if;
  -- HMAC-SHA256 wants a key at least as long as its output.
  if p_secret is null or octet_length(p_secret) < 32 then
    raise exception 'a federation key has at least 32 bytes' using errcode = '22023';
  end if;
  if p_direction = 'outbound' and not exists (
       select 1 from public.enrolled_installations
        where installation_id = p_peer and enabled) then
    raise exception 'an outbound status key is for an enrolled installation in force'
      using errcode = '55000';
  end if;
  if p_direction = 'inbound' and not exists (
       select 1 from public.identity_authority where kind = 'oidc') then
    raise exception 'an inbound status key is for the identity authority this installation trusts'
      using errcode = '55000';
  end if;
  if exists (select 1 from public.federation_keys
              where peer_installation_id = p_peer and direction = p_direction
                and purpose = p_purpose and key_id = p_key_id) then
    raise exception 'key id % was used already: rotate to a new id', p_key_id
      using errcode = '23505';
  end if;
  update public.federation_keys set retired_at = now()
   where peer_installation_id = p_peer and direction = p_direction
     and purpose = p_purpose and retired_at is null
  returning * into v_replaced;
  if v_replaced.vault_secret_id is not null then
    delete from vault.secrets where id = v_replaced.vault_secret_id;
  end if;
  v_secret_id := vault.create_secret(p_secret,
    format('deskilo_federation_%s_%s_%s_%s', p_purpose, p_direction, p_peer, p_key_id),
    'DesKilo federation key');
  insert into public.federation_keys
    (peer_installation_id, direction, purpose, key_id, vault_secret_id)
  values (p_peer, p_direction, p_purpose, p_key_id, v_secret_id);
  insert into public.database_authority_audit (installation_id, action, actor, detail)
  values (public.installation_id(), 'federation_key_set', 'operator',
          jsonb_build_object('peer_installation_id', p_peer, 'direction', p_direction,
            'purpose', p_purpose, 'key_id', p_key_id, 'replaced', v_replaced.key_id));
  return jsonb_build_object('key_id', p_key_id, 'replaced', v_replaced.key_id);
end;
$fn$;
revoke execute on function public.operator_set_federation_key(uuid, text, text, text, text)
  from public, anon, authenticated, service_role;

create or replace function public.operator_retire_federation_key(
  p_peer uuid, p_direction text, p_purpose text, p_key_id text)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_key public.federation_keys;
begin
  perform pg_advisory_xact_lock(hashtextextended('federation_keys', 2562));
  select * into v_key from public.federation_keys
   where peer_installation_id = p_peer and direction = p_direction
     and purpose = p_purpose and key_id = p_key_id;
  if v_key.key_id is null then
    raise exception 'no such federation key' using errcode = 'P0002';
  end if;
  if v_key.retired_at is not null then
    return jsonb_build_object('key_id', p_key_id, 'unchanged', true);
  end if;
  update public.federation_keys set retired_at = now()
   where peer_installation_id = p_peer and direction = p_direction
     and purpose = p_purpose and key_id = p_key_id;
  delete from vault.secrets where id = v_key.vault_secret_id;
  insert into public.database_authority_audit (installation_id, action, actor, detail)
  values (public.installation_id(), 'federation_key_retired', 'operator',
          jsonb_build_object('peer_installation_id', p_peer, 'direction', p_direction,
            'purpose', p_purpose, 'key_id', p_key_id));
  return jsonb_build_object('key_id', p_key_id, 'unchanged', false);
end;
$fn$;
revoke execute on function public.operator_retire_federation_key(uuid, text, text, text)
  from public, anon, authenticated, service_role;

-- ── the envelope ─────────────────────────────────────────────────────
create or replace function public.federation_signing_input(
  p_method text, p_path text, p_purpose text, p_source uuid, p_target uuid,
  p_event uuid, p_timestamp bigint, p_digest text, p_key_id text)
returns text language sql immutable set search_path = '' as $fn$
  select concat_ws(E'\n', 'deskilo-federation/1', upper(p_method), p_path, p_purpose,
                   p_source::text, p_target::text, p_event::text, p_timestamp::text,
                   p_digest, p_key_id);
$fn$;
revoke execute on function public.federation_signing_input(text, text, text, uuid, uuid, uuid, bigint, text, text)
  from public, anon, authenticated, service_role;

-- The headers that sign `p_body` exactly as pg_net sends it
-- (`convert_to(body::text, 'UTF8')`) with the outbound key in force.
create or replace function public.federation_envelope_headers(
  p_purpose text, p_target uuid, p_event uuid, p_path text, p_body jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_key public.federation_keys;
  v_secret text;
  v_source uuid := public.installation_id();
  v_digest text := encode(extensions.digest(convert_to(p_body::text, 'UTF8'), 'sha256'), 'hex');
  v_ts bigint := floor(extract(epoch from now()))::bigint;
begin
  select * into v_key from public.federation_keys
   where peer_installation_id = p_target and direction = 'outbound'
     and purpose = p_purpose and retired_at is null;
  select decrypted_secret into v_secret from vault.decrypted_secrets
   where id = v_key.vault_secret_id;
  if v_secret is null then
    raise exception 'no outbound % key for installation %', p_purpose, p_target
      using errcode = 'P0002';
  end if;
  return jsonb_build_object(
    'x-deskilo-protocol', '1', 'x-deskilo-purpose', p_purpose,
    'x-deskilo-source', v_source, 'x-deskilo-target', p_target,
    'x-deskilo-event', p_event, 'x-deskilo-timestamp', v_ts::text,
    'x-deskilo-digest', v_digest, 'x-deskilo-key', v_key.key_id,
    'x-deskilo-signature', encode(extensions.hmac(
      convert_to(public.federation_signing_input('POST', p_path, p_purpose, v_source, p_target,
        p_event, v_ts, v_digest, v_key.key_id), 'UTF8'),
      convert_to(v_secret, 'UTF8'), 'sha256'), 'hex'));
end;
$fn$;
revoke execute on function public.federation_envelope_headers(text, uuid, uuid, text, jsonb)
  from public, anon, authenticated, service_role;

-- Authenticates one received request. Answers `verified` with the source,
-- event and digest, or the reason it was refused.
create or replace function public.federation_verify(
  p_method text, p_path text, p_headers jsonb, p_raw bytea)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  h jsonb := coalesce(p_headers, '{}'::jsonb);
  v_purpose text := h->>'x-deskilo-purpose';
  v_digest text := lower(h->>'x-deskilo-digest');
  v_source uuid;
  v_target uuid;
  v_event uuid;
  v_ts bigint;
  v_given bytea;
  v_key public.federation_keys;
  v_secret text;
  v_expected bytea;
  v_nonce bytea := extensions.gen_random_bytes(32);
  v_skew int := (public.setting_value(null, 'identity.clock_skew_seconds') #>> '{}')::int;
begin
  begin
    v_source := (h->>'x-deskilo-source')::uuid;
    v_target := (h->>'x-deskilo-target')::uuid;
    v_event := (h->>'x-deskilo-event')::uuid;
    v_ts := (h->>'x-deskilo-timestamp')::bigint;
    v_given := decode(h->>'x-deskilo-signature', 'hex');
  exception when others then
    return jsonb_build_object('outcome', 'malformed');
  end;
  if h->>'x-deskilo-protocol' is distinct from '1' or v_purpose is null
     or v_source is null or v_target is null or v_event is null or v_ts is null
     or v_given is null or coalesce(v_digest, '') !~ '^[0-9a-f]{64}$' or p_raw is null then
    return jsonb_build_object('outcome', 'malformed');
  end if;
  if v_target <> public.installation_id() then
    return jsonb_build_object('outcome', 'wrong_target');
  end if;
  select * into v_key from public.federation_keys
   where peer_installation_id = v_source and direction = 'inbound'
     and purpose = v_purpose and retired_at is null;
  if v_key.key_id is null then
    return jsonb_build_object('outcome', 'unknown_installation');
  end if;
  select decrypted_secret into v_secret from vault.decrypted_secrets
   where id = v_key.vault_secret_id;
  if v_secret is null or v_key.key_id is distinct from h->>'x-deskilo-key' then
    return jsonb_build_object('outcome', 'unknown_key');
  end if;
  v_expected := extensions.hmac(convert_to(public.federation_signing_input(p_method, p_path,
      v_purpose, v_source, v_target, v_event, v_ts, v_digest, v_key.key_id), 'UTF8'),
    convert_to(v_secret, 'UTF8'), 'sha256');
  if extensions.hmac(v_expected, v_nonce, 'sha256')
     <> extensions.hmac(v_given, v_nonce, 'sha256') then
    return jsonb_build_object('outcome', 'bad_signature');
  end if;
  if encode(extensions.digest(p_raw, 'sha256'), 'hex') <> v_digest then
    return jsonb_build_object('outcome', 'bad_digest');
  end if;
  if v_ts > extract(epoch from now()) + v_skew then
    return jsonb_build_object('outcome', 'future_request');
  end if;
  return jsonb_build_object('outcome', 'verified', 'purpose', v_purpose, 'source', v_source,
    'event', v_event, 'digest', v_digest, 'timestamp', v_ts);
end;
$fn$;
revoke execute on function public.federation_verify(text, text, jsonb, bytea)
  from public, anon, authenticated, service_role;

-- ── P: issue ─────────────────────────────────────────────────────────
-- The enrolled installations a person consented to, in a native session,
-- through their identity client. Auth owns `oauth_consents`, so it is read
-- dynamically: an Auth without the OAuth server links nobody.
create or replace function public.identity_status_linked_targets(p_user uuid)
returns setof uuid language plpgsql stable security definer set search_path = public as $fn$
begin
  if to_regclass('auth.oauth_consents') is null then
    return;
  end if;
  return query execute
    'select distinct c.target_installation_id
       from auth.oauth_consents oc
       join public.identity_federation_clients c on c.client_id::text = oc.client_id::text
       join public.enrolled_installations e on e.installation_id = c.target_installation_id
      where oc.user_id = $1 and oc.revoked_at is null and c.enabled and e.enabled'
    using p_user;
end;
$fn$;
revoke execute on function public.identity_status_linked_targets(uuid)
  from public, anon, authenticated, service_role;

create or replace function public.identity_status_issue(p_user uuid, p_status text)
returns int language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_issuer text;
  v_lifetime int := (public.setting_value(null,
    'identity.status_assertion_lifetime_seconds') #>> '{}')::int;
  v_until timestamptz := now() + make_interval(secs => v_lifetime);
  v_target uuid;
  v_event uuid;
  v_revision bigint;
  v_count int := 0;
begin
  if p_user is null or p_status is null or p_status not in ('active', 'suspended', 'erased') then
    raise exception 'an identity status names a person and active, suspended or erased'
      using errcode = '22023';
  end if;
  -- Only the authority of a person's identity asserts their status.
  select issuer into v_issuer from public.identity_authority where kind = 'native';
  if v_issuer is null then
    return 0;
  end if;
  for v_target in select t from public.identity_status_linked_targets(p_user) t loop
    v_event := gen_random_uuid();
    v_revision := nextval('public.identity_status_revision');
    insert into public.identity_status_outbox (event_id, target_installation_id, issuer,
      subject, revision, status, issued_at, valid_until, body)
    values (v_event, v_target, v_issuer, p_user::text, v_revision, p_status, now(), v_until,
      jsonb_build_object('protocol', 1, 'kind', 'identity_status', 'event_id', v_event,
        'source_installation_id', public.installation_id(),
        'target_installation_id', v_target, 'issuer', v_issuer, 'subject', p_user::text,
        'revision', v_revision, 'status', p_status, 'issued_at', now(),
        'valid_until', v_until));
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$fn$;
revoke execute on function public.identity_status_issue(uuid, text)
  from public, anon, authenticated, service_role;

-- A status change commits its assertions with the account change itself.
create or replace function public.identity_status_on_account_change()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_user uuid;
  v_old text;
  v_new text;
begin
  if tg_op = 'DELETE' then
    v_user := old.id;
    v_new := 'erased';
  else
    v_user := new.id;
    v_old := case when old.deleted_at is not null then 'erased'
                  when old.banned_until > now() then 'suspended' else 'active' end;
    v_new := case when new.deleted_at is not null then 'erased'
                  when new.banned_until > now() then 'suspended' else 'active' end;
    if v_old = v_new then
      return new;
    end if;
  end if;
  begin
    perform public.identity_status_issue(v_user, v_new);
  exception when others then
    insert into public.database_authority_audit
      (installation_id, action, actor, target_user_id, detail)
    values (public.installation_id(), 'identity_status_unissued', 'system', v_user,
            jsonb_build_object('status', v_new, 'sqlstate', sqlstate));
  end;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$fn$;
revoke execute on function public.identity_status_on_account_change()
  from public, anon, authenticated, service_role;
drop trigger if exists identity_status_on_account_change on auth.users;
create trigger identity_status_on_account_change
  after update of banned_until, deleted_at on auth.users
  for each row execute function public.identity_status_on_account_change();
-- Before the row goes: the consents that name the targets go with it.
drop trigger if exists identity_status_on_account_erasure on auth.users;
create trigger identity_status_on_account_erasure
  before delete on auth.users
  for each row execute function public.identity_status_on_account_change();

-- ── P: deliver ───────────────────────────────────────────────────────
create or replace function public.identity_status_drain()
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_row public.identity_status_outbox;
  v_target public.enrolled_installations;
  v_code int;
  v_content text;
  v_timed_out boolean;
  v_found int;
  v_outcome text;
  v_headers jsonb;
  v_sent int := 0;
  v_settled int := 0;
begin
  -- 1. the answers to earlier attempts
  if to_regclass('net._http_response') is not null then
    for v_row in select * from public.identity_status_outbox
                  where state = 'sent' order by issued_at for update skip locked loop
      execute 'select status_code, content, timed_out from net._http_response where id = $1'
        into v_code, v_content, v_timed_out using v_row.net_request_id;
      get diagnostics v_found = row_count;
      begin
        v_outcome := v_content::jsonb->>'outcome';
      exception when others then
        v_outcome := null;
      end;
      if v_found = 0 then
        -- No answer yet; pg_net answers or times out well within a minute.
        if v_row.last_attempt_at < now() - interval '2 minutes' then
          update public.identity_status_outbox set state = 'pending', outcome = 'no_answer'
           where event_id = v_row.event_id;
        end if;
        continue;
      end if;
      if v_code between 200 and 299 then
        update public.identity_status_outbox
           set state = 'delivered', delivered_at = now(), outcome = coalesce(v_outcome, 'delivered')
         where event_id = v_row.event_id;
      elsif v_code in (400, 409, 421, 422) then
        update public.identity_status_outbox
           set state = 'refused', outcome = coalesce(v_outcome, 'http_' || v_code)
         where event_id = v_row.event_id;
      else
        update public.identity_status_outbox
           set state = 'pending',
               outcome = coalesce(v_outcome, case when coalesce(v_timed_out, false)
                                                  then 'timeout' else 'http_' || v_code end)
         where event_id = v_row.event_id;
      end if;
      v_settled := v_settled + 1;
    end loop;
  end if;
  -- 2. what lapsed undelivered: every older assertion has lapsed with it
  update public.identity_status_outbox set state = 'expired'
   where state in ('pending', 'sent') and valid_until <= now();
  -- 3. send
  if to_regprocedure('net.http_post(text, jsonb, jsonb, jsonb, integer)') is null then
    return jsonb_build_object('settled', v_settled, 'sent', 0, 'transport', 'unavailable');
  end if;
  for v_row in select * from public.identity_status_outbox
                where state = 'pending' order by issued_at limit 200 for update skip locked loop
    select * into v_target from public.enrolled_installations
     where installation_id = v_row.target_installation_id;
    if not coalesce(v_target.enabled, false) then
      update public.identity_status_outbox set state = 'refused', outcome = 'target_revoked'
       where event_id = v_row.event_id;
      continue;
    end if;
    begin
      v_headers := public.federation_envelope_headers('identity_status',
        v_row.target_installation_id, v_row.event_id, '/federation-inbox', v_row.body);
    exception when sqlstate 'P0002' then
      update public.identity_status_outbox set outcome = 'no_outbound_key'
       where event_id = v_row.event_id;
      continue;
    end;
    update public.identity_status_outbox
       set state = 'sent', attempts = attempts + 1, last_attempt_at = now(),
           net_request_id = net.http_post(
             url := v_target.origin || '/functions/v1/federation-inbox',
             body := v_row.body,
             headers := v_headers || jsonb_build_object('Content-Type', 'application/json',
                                                        'apikey', v_target.publishable_key),
             timeout_milliseconds := 10000)
     where event_id = v_row.event_id;
    v_sent := v_sent + 1;
  end loop;
  return jsonb_build_object('settled', v_settled, 'sent', v_sent);
end;
$fn$;
revoke execute on function public.identity_status_drain()
  from public, anon, authenticated, service_role;

-- ── W: receive ───────────────────────────────────────────────────────
create or replace function public.identity_status_apply(
  p_body jsonb, p_source uuid, p_event uuid, p_request_ts bigint)
returns text language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_skew interval := make_interval(secs =>
    (public.setting_value(null, 'identity.clock_skew_seconds') #>> '{}')::int);
  v_lifetime interval := make_interval(secs =>
    (public.setting_value(null, 'identity.status_assertion_lifetime_seconds') #>> '{}')::int);
  v_issuer text;
  v_subject text;
  v_status text;
  v_revision bigint;
  v_issued timestamptz;
  v_until timestamptz;
  v_current public.identity_status_assertions;
begin
  begin
    v_issuer := p_body->>'issuer';
    v_subject := p_body->>'subject';
    v_status := p_body->>'status';
    v_revision := (p_body->>'revision')::bigint;
    v_issued := (p_body->>'issued_at')::timestamptz;
    v_until := (p_body->>'valid_until')::timestamptz;
  exception when others then
    return 'malformed';
  end;
  if p_body->>'kind' is distinct from 'identity_status' or p_body->>'protocol' is distinct from '1'
     or p_body->>'event_id' is distinct from p_event::text
     or p_body->>'source_installation_id' is distinct from p_source::text
     or p_body->>'target_installation_id' is distinct from public.installation_id()::text
     or v_issuer is null or coalesce(v_subject, '') = '' or length(v_subject) > 255
     or v_status is null or v_status not in ('active', 'suspended', 'erased')
     or coalesce(v_revision, 0) < 1 or v_issued is null or v_until is null
     or v_until <= v_issued then
    return 'malformed';
  end if;
  if not exists (select 1 from public.identity_authority
                  where kind = 'oidc' and issuer = v_issuer) then
    return 'wrong_issuer';
  end if;
  if v_issued > now() + v_skew or to_timestamp(p_request_ts) < v_issued - v_skew then
    return 'future_assertion';
  end if;
  -- The issuer's clock sets the deadline; a shorter lifetime here shortens it.
  v_until := least(v_until, v_issued + v_lifetime);
  if v_until + v_skew <= now() then
    return 'expired_assertion';
  end if;
  if not exists (select 1 from public.identity_bindings b
                  where b.installation_id = public.installation_id()
                    and b.issuer = v_issuer and b.subject = v_subject
                    and (b.status = 'active' or v_status <> 'active')) then
    return 'unlinked_subject';
  end if;
  select * into v_current from public.identity_status_assertions
   where issuer = v_issuer and subject = v_subject for update;
  if v_current.revision is not null
     and (v_current.status = 'erased' or v_current.revision >= v_revision) then
    return 'superseded';
  end if;
  insert into public.identity_status_assertions as a (issuer, subject, revision, status,
    asserted_at, valid_until, source_installation_id, event_id)
  values (v_issuer, v_subject, v_revision, v_status, v_issued, v_until, p_source, p_event)
  on conflict (issuer, subject) do update
    set revision = excluded.revision, status = excluded.status,
        asserted_at = excluded.asserted_at, valid_until = excluded.valid_until,
        source_installation_id = excluded.source_installation_id,
        event_id = excluded.event_id, received_at = now();
  return 'applied';
end;
$fn$;
revoke execute on function public.identity_status_apply(jsonb, uuid, uuid, bigint)
  from public, anon, authenticated, service_role;

-- What `federation-inbox` calls with the request's raw body (base64).
create or replace function public.federation_inbox_accept(
  p_method text, p_path text, p_headers jsonb, p_body_b64 text)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_raw bytea;
  v_verified jsonb;
  v_body jsonb;
  v_receipt public.federation_inbox_receipts;
  v_outcome text;
begin
  if p_method is distinct from 'POST' or p_path is distinct from '/federation-inbox' then
    return jsonb_build_object('outcome', 'malformed');
  end if;
  begin
    v_raw := decode(p_body_b64, 'base64');
  exception when others then
    return jsonb_build_object('outcome', 'malformed');
  end;
  if coalesce(octet_length(v_raw), 0) not between 1 and 16384 then
    return jsonb_build_object('outcome', 'malformed');
  end if;
  v_verified := public.federation_verify(p_method, p_path, p_headers, v_raw);
  if v_verified->>'outcome' <> 'verified' then
    return jsonb_build_object('outcome', v_verified->>'outcome');
  end if;
  perform pg_advisory_xact_lock(hashtextextended(
    'federation_inbox:' || (v_verified->>'source') || ':' || (v_verified->>'event'), 2562));
  select * into v_receipt from public.federation_inbox_receipts
   where source_installation_id = (v_verified->>'source')::uuid
     and event_id = (v_verified->>'event')::uuid;
  if v_receipt.event_id is not null then
    if v_receipt.body_digest = v_verified->>'digest' then
      return jsonb_build_object('outcome', 'duplicate', 'first_outcome', v_receipt.outcome);
    end if;
    return jsonb_build_object('outcome', 'event_conflict');
  end if;
  begin
    v_body := convert_from(v_raw, 'UTF8')::jsonb;
  exception when others then
    v_outcome := 'malformed';
  end;
  if v_outcome is null and v_verified->>'purpose' = 'identity_status'
     and jsonb_typeof(v_body) = 'object' then
    v_outcome := public.identity_status_apply(v_body, (v_verified->>'source')::uuid,
      (v_verified->>'event')::uuid, (v_verified->>'timestamp')::bigint);
  end if;
  v_outcome := coalesce(v_outcome, 'malformed');
  insert into public.federation_inbox_receipts
    (source_installation_id, event_id, purpose, body_digest, outcome)
  values ((v_verified->>'source')::uuid, (v_verified->>'event')::uuid,
          v_verified->>'purpose', v_verified->>'digest', v_outcome);
  return jsonb_build_object('outcome', v_outcome);
end;
$fn$;
revoke execute on function public.federation_inbox_accept(text, text, jsonb, text)
  from public, anon, authenticated;
grant execute on function public.federation_inbox_accept(text, text, jsonb, text) to service_role;

-- ── the delivery tick ────────────────────────────────────────────────
do $cron$
begin
  create extension if not exists pg_cron;
  perform cron.unschedule('deskilo-identity-status-drain')
    where exists (select 1 from cron.job where jobname = 'deskilo-identity-status-drain');
  perform cron.schedule('deskilo-identity-status-drain', '* * * * *',
    $job$select public.identity_status_drain()$job$);
exception when others then
  raise notice 'pg_cron unavailable (%): an operator runs identity_status_drain() instead', sqlerrm;
end
$cron$;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(9999);
