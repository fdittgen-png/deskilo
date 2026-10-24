-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- Additive: three new tables, one sequence, the functions below, two
-- triggers (members, identity_bindings), one pg_cron job; the purpose check
-- of federation_keys admits a second purpose. Three existing functions are
-- restated whole (operator_set_federation_key, federation_inbox_accept,
-- account_field_visible_to) and one reader (my_personal_workspace_refs_v1).
-- No existing row is rewritten.
--
-- #2563 C2 (first checkpoint) -- verified membership facts, so a personal
-- home (P) that hosts no workspace can still decide "my spaces" and
-- "chosen spaces" for a workspace on another installation (W).
--
-- The workspace installation (W) side -- the producer:
--   * a committed change of a membership (insert, status, user, deletion)
--     or of an identity binding derives, per person bound to the trusted
--     identity authority, the relationship `(issuer, subject, network_id)`
--     and its status (active, paused, pending, exited, or tombstone when no
--     membership is left or the binding is revoked). A change takes a new
--     revision from one monotonic sequence and keeps it in
--     `membership_fact_state`, the high-water that survives the member's
--     deletion: a rejoin is a newer revision, never a reset;
--   * the assertion is committed IN THE SAME TRANSACTION into
--     `membership_fact_outbox`, for the personal home this installation
--     names (0565 `endpoint`) and holds the outbound `membership_fact` key
--     for; the source is this database, never a device;
--   * `membership_fact_reconcile()` re-derives every bound relationship
--     (so a missed trigger heals), tombstones a relationship whose binding
--     is gone, and re-asserts a quiet one at the SAME revision every
--     `identity.status_reconcile_seconds`, so it never lapses while true;
--   * `membership_fact_drain()` signs and posts each pending assertion with
--     #2562's envelope (`federation_envelope_headers`, purpose
--     `membership_fact`, the per-relationship key in Vault) to the home's
--     `federation-inbox`: one channel, a second purpose. Settled rows are
--     purged once their own deadline passed: they can authorize nothing.
--
-- The personal home (P) side -- the receiver, behind the same inbox:
--   * `federation_inbox_accept` (restated) dispatches the purpose
--     `membership_fact` to `membership_fact_apply`, after the envelope, key,
--     signature, digest, request time and event id checks of #2562;
--   * a fact must name this home's own native issuer, a subject that is a
--     person here and consented to the SOURCE installation (#2562's link:
--     the Auth consent, the enabled client, the enrolment in force), and a
--     workspace OF the source (`network_id` starts with its installation
--     id): W-A cannot assert a W-B membership. A tombstone narrows only, so
--     it is accepted for an existing fact even after the link went;
--   * the deadline is the source's `asserted_at` plus the shorter of the two
--     lifetimes (`identity.status_assertion_lifetime_seconds`), never the
--     receipt time; revisions only grow; the same revision renews the
--     deadline only with the same status and a genuinely newer assertion,
--     and with another status it is refused (`revision_conflict`);
--   * a fact is in force while its deadline plus the allowed skew has not
--     passed AND the source's enrolment is the one it was received under
--     (`enrolment_epoch` = enrolled_at, enabled).
--
-- The policy (`account_field_visible_to`, 0387, restated whole): my_spaces
-- and chosen_spaces hold through a local membership pair, as before, OR
-- through two facts in force naming the same network id, with the same
-- purpose-specific statuses (active, paused). Everything that asks the
-- evaluator follows: visible_account, search_available_accounts, the
-- projections, send_account_message. A missing or stale fact authorizes
-- nothing; an accepted conversation and the blocks stay P-local.
--
-- `my_personal_workspace_refs_v1` (restated) lists the workspaces my facts
-- name and says `verified` (in force) or `stale` (held, lapsed) instead of
-- `unavailable`. The three tables are closed to every API role and carry
-- the restrictive personal policies.

-- ── a second purpose on the one channel ──────────────────────────────
alter table public.federation_keys drop constraint if exists federation_keys_purpose_check;
alter table public.federation_keys add constraint federation_keys_purpose_check
  check (purpose in ('identity_status', 'membership_fact'));

-- ── W: the high-water and the outbox ─────────────────────────────────
create sequence if not exists public.membership_fact_revision;
revoke all on sequence public.membership_fact_revision from public, anon, authenticated, service_role;

create table if not exists public.membership_fact_state (
  issuer text not null,
  subject text not null check (length(subject) between 1 and 255),
  network_id text not null check (network_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'),
  revision bigint not null check (revision > 0),
  status text not null check (status in ('active', 'paused', 'pending', 'exited', 'tombstone')),
  last_asserted_at timestamptz,
  primary key (issuer, subject, network_id)
);
select public.ensure_system_columns('membership_fact_state');
comment on table public.membership_fact_state is
  '#2563 C2 -- per relationship (issuer, subject, workspace network id) the latest '
  'revision and status this workspace installation asserted. Kept after the '
  'membership goes: a rejoin is a newer revision.';

create table if not exists public.membership_fact_outbox (
  event_id uuid primary key,
  target_installation_id uuid not null,
  issuer text not null,
  subject text not null check (length(subject) between 1 and 255),
  network_id text not null,
  revision bigint not null check (revision > 0),
  status text not null check (status in ('active', 'paused', 'pending', 'exited', 'tombstone')),
  asserted_at timestamptz not null,
  valid_until timestamptz not null check (valid_until > asserted_at),
  body jsonb not null,
  state text not null default 'pending'
    check (state in ('pending', 'sent', 'delivered', 'refused', 'expired')),
  attempts int not null default 0,
  last_attempt_at timestamptz,
  net_request_id bigint,
  outcome text,
  delivered_at timestamptz
);
select public.ensure_system_columns('membership_fact_outbox');
create index if not exists membership_fact_outbox_due
  on public.membership_fact_outbox (state, asserted_at) where state in ('pending', 'sent');
comment on table public.membership_fact_outbox is
  '#2563 C2 -- membership facts this workspace installation committed for its '
  'personal home, and how their delivery went.';

-- ── P: the verified facts ────────────────────────────────────────────
create table if not exists public.membership_facts (
  user_id uuid not null references auth.users (id) on delete cascade,
  network_id text not null check (network_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'),
  issuer text not null,
  source_installation_id uuid not null,
  revision bigint not null check (revision > 0),
  status text not null check (status in ('active', 'paused', 'pending', 'exited', 'tombstone')),
  asserted_at timestamptz not null,
  valid_until timestamptz not null,
  enrolment_epoch timestamptz not null,
  event_id uuid not null,
  received_at timestamptz not null default now(),
  primary key (user_id, network_id),
  constraint membership_facts_deadline check (valid_until > asserted_at),
  constraint membership_facts_own_workspace
    check (split_part(network_id, ':', 1) = source_installation_id::text)
);
select public.ensure_system_columns('membership_facts');
comment on table public.membership_facts is
  '#2563 C2 -- the latest verified membership fact per person and workspace '
  'network id, as the workspace''s own installation signed it. Written only by '
  'membership_fact_apply; read only by the policy evaluator and the caller''s '
  'own reference list.';

alter table public.membership_fact_state enable row level security;
revoke all on public.membership_fact_state from public, anon, authenticated, service_role;
drop policy if exists mcp_delegated_deny on public.membership_fact_state;
create policy mcp_delegated_deny on public.membership_fact_state
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
drop policy if exists personal_native_session on public.membership_fact_state;
create policy personal_native_session on public.membership_fact_state
  as restrictive for all to public
  using ((select public.personal_native_session()))
  with check ((select public.personal_native_session()));
alter table public.membership_fact_outbox enable row level security;
revoke all on public.membership_fact_outbox from public, anon, authenticated, service_role;
drop policy if exists mcp_delegated_deny on public.membership_fact_outbox;
create policy mcp_delegated_deny on public.membership_fact_outbox
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
drop policy if exists personal_native_session on public.membership_fact_outbox;
create policy personal_native_session on public.membership_fact_outbox
  as restrictive for all to public
  using ((select public.personal_native_session()))
  with check ((select public.personal_native_session()));
alter table public.membership_facts enable row level security;
revoke all on public.membership_facts from public, anon, authenticated, service_role;
drop policy if exists mcp_delegated_deny on public.membership_facts;
create policy mcp_delegated_deny on public.membership_facts
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
drop policy if exists personal_native_session on public.membership_facts;
create policy personal_native_session on public.membership_facts
  as restrictive for all to public
  using ((select public.personal_native_session()))
  with check ((select public.personal_native_session()));

-- History guards: the high-water is kept and only moves forward; a fact
-- only moves forward, and the same revision only renews. A fact goes with
-- its person (auth.users cascade).
create or replace function public.protect_membership_fact()
returns trigger language plpgsql set search_path = '' as $fn$
begin
  if tg_table_name = 'membership_fact_state' then
    if tg_op = 'DELETE' then
      raise exception 'a relationship high-water is kept' using errcode = '55000';
    end if;
    if row(new.issuer, new.subject, new.network_id) is distinct from row(old.issuer, old.subject, old.network_id)
       or new.revision < old.revision
       or (new.revision = old.revision and new.status <> old.status) then
      raise exception 'a relationship only moves forward' using errcode = '55000';
    end if;
  elsif tg_table_name = 'membership_facts' then
    if row(new.user_id, new.network_id) is distinct from row(old.user_id, old.network_id)
       or new.revision < old.revision
       or (new.revision = old.revision
           and (new.status <> old.status or new.source_installation_id <> old.source_installation_id
                or new.asserted_at <= old.asserted_at)) then
      raise exception 'a membership fact only moves forward' using errcode = '55000';
    end if;
  end if;
  return new;
end;
$fn$;
revoke execute on function public.protect_membership_fact()
  from public, anon, authenticated, service_role;
drop trigger if exists protect_membership_fact on public.membership_fact_state;
create trigger protect_membership_fact before update or delete on public.membership_fact_state
  for each row execute function public.protect_membership_fact();
drop trigger if exists protect_membership_fact on public.membership_facts;
create trigger protect_membership_fact before update on public.membership_facts
  for each row execute function public.protect_membership_fact();

-- ── keys: one operator function, two purposes (C2b's, restated whole) ─
-- identity_status: P -> W (outbound to an enrolled installation, inbound
-- from the trusted authority). membership_fact: W -> P (outbound to the
-- personal home this installation names, inbound from an enrolled one).
create or replace function public.operator_set_federation_key(
  p_peer uuid, p_direction text, p_purpose text, p_key_id text, p_secret text)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_replaced public.federation_keys;
  v_secret_id uuid;
  v_to_enrolled boolean;
begin
  perform pg_advisory_xact_lock(hashtextextended('federation_keys', 2562));
  if p_peer is null or p_peer = public.installation_id() then
    raise exception 'a federation key names another installation' using errcode = '22023';
  end if;
  if p_direction is null or p_direction not in ('outbound', 'inbound')
     or p_purpose is null or p_purpose not in ('identity_status', 'membership_fact') then
    raise exception 'a federation key is outbound or inbound, for identity_status or membership_fact'
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
  -- The peer is an enrolled workspace installation when P talks to it:
  -- statuses out, facts in. Otherwise the peer is this installation's
  -- personal home: statuses in, facts out.
  v_to_enrolled := (p_purpose = 'identity_status') = (p_direction = 'outbound');
  if v_to_enrolled and not exists (
       select 1 from public.enrolled_installations
        where installation_id = p_peer and enabled) then
    raise exception 'this key is for an enrolled installation in force' using errcode = '55000';
  end if;
  if not v_to_enrolled and not exists (
       select 1 from public.identity_authority where kind = 'oidc') then
    raise exception 'this key is for the identity authority this installation trusts'
      using errcode = '55000';
  end if;
  if p_purpose = 'membership_fact' and p_direction = 'outbound' then
    if not exists (select 1 from public.installation_identity where personal_home_kind = 'endpoint') then
      raise exception 'membership facts go to a personal home this installation names'
        using errcode = '55000';
    end if;
    if exists (select 1 from public.federation_keys
                where direction = 'outbound' and purpose = 'membership_fact'
                  and retired_at is null and peer_installation_id <> p_peer) then
      raise exception 'membership facts go to one personal home: retire the other key first'
        using errcode = '55000';
    end if;
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

-- ── W: produce ───────────────────────────────────────────────────────
-- The personal home membership facts go to: the peer of the outbound key
-- in force, at the endpoint this installation declares.
create or replace function public.membership_fact_home()
returns table (home_installation_id uuid, home_origin text, home_key text)
language sql stable security definer set search_path = public as $fn$
  select k.peer_installation_id, i.personal_home_url, i.personal_home_key
    from public.federation_keys k
   cross join public.installation_identity i
   where k.direction = 'outbound' and k.purpose = 'membership_fact' and k.retired_at is null
     and i.personal_home_kind = 'endpoint'
   limit 1;
$fn$;
revoke execute on function public.membership_fact_home()
  from public, anon, authenticated, service_role;

-- Commits one assertion of a relationship's current state, when a home is
-- configured; without one the state waits for the reconcile.
create or replace function public.membership_fact_enqueue(p_state public.membership_fact_state)
returns int language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_home record;
  v_event uuid := gen_random_uuid();
  v_until timestamptz := now() + make_interval(secs =>
    (public.setting_value(null, 'identity.status_assertion_lifetime_seconds') #>> '{}')::int);
begin
  select * into v_home from public.membership_fact_home();
  if v_home.home_installation_id is null then
    return 0;
  end if;
  insert into public.membership_fact_outbox (event_id, target_installation_id, issuer, subject,
    network_id, revision, status, asserted_at, valid_until, body)
  values (v_event, v_home.home_installation_id, p_state.issuer, p_state.subject, p_state.network_id,
    p_state.revision, p_state.status, now(), v_until,
    jsonb_build_object('protocol', 1, 'kind', 'membership_fact', 'event_id', v_event,
      'source_installation_id', public.installation_id(),
      'target_installation_id', v_home.home_installation_id,
      'issuer', p_state.issuer, 'subject', p_state.subject, 'network_id', p_state.network_id,
      'revision', p_state.revision, 'status', p_state.status,
      'asserted_at', now(), 'valid_until', v_until));
  update public.membership_fact_state set last_asserted_at = now()
   where issuer = p_state.issuer and subject = p_state.subject and network_id = p_state.network_id;
  return 1;
end;
$fn$;
revoke execute on function public.membership_fact_enqueue(public.membership_fact_state)
  from public, anon, authenticated, service_role;

-- Derives the relationship of one local person with one local workspace,
-- per binding of that person to the trusted authority, and asserts it when
-- it changed. Idempotent: an unchanged relationship asserts nothing.
create or replace function public.membership_fact_produce(p_workspace uuid, p_user uuid)
returns int language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_issuer text;
  v_ref text;
  v_member text;
  v_status text;
  v_binding record;
  v_state public.membership_fact_state;
  v_count int := 0;
begin
  if p_workspace is null or p_user is null then
    return 0;
  end if;
  select issuer into v_issuer from public.identity_authority where kind = 'oidc';
  if v_issuer is null then
    return 0;
  end if;
  -- A workspace deleted in this transaction is still named by its birth record.
  v_ref := coalesce((select w.network_id from public.workspaces w where w.id = p_workspace),
                    public.installation_id()::text || ':' || p_workspace::text);
  select m.status into v_member from public.members m
   where m.workspace_id = p_workspace and m.user_id = p_user
   order by case m.status when 'active' then 0 when 'paused' then 1 when 'pending' then 2 else 3 end
   limit 1;
  for v_binding in select b.subject, b.status from public.identity_bindings b
                    where b.installation_id = public.installation_id()
                      and b.local_user_id = p_user and b.issuer = v_issuer loop
    v_status := case when v_binding.status = 'active' then coalesce(v_member, 'tombstone')
                     else 'tombstone' end;
    perform pg_advisory_xact_lock(hashtextextended(
      'membership_fact:' || v_binding.subject || ':' || v_ref, 2563));
    select * into v_state from public.membership_fact_state
     where issuer = v_issuer and subject = v_binding.subject and network_id = v_ref for update;
    if v_state.revision is null then
      if v_status = 'tombstone' then
        continue;
      end if;
      insert into public.membership_fact_state (issuer, subject, network_id, revision, status)
      values (v_issuer, v_binding.subject, v_ref, nextval('public.membership_fact_revision'), v_status)
      returning * into v_state;
    elsif v_state.status = v_status then
      continue;
    else
      update public.membership_fact_state
         set revision = nextval('public.membership_fact_revision'), status = v_status,
             last_asserted_at = null
       where issuer = v_issuer and subject = v_binding.subject and network_id = v_ref
      returning * into v_state;
    end if;
    v_count := v_count + public.membership_fact_enqueue(v_state);
  end loop;
  return v_count;
end;
$fn$;
revoke execute on function public.membership_fact_produce(uuid, uuid)
  from public, anon, authenticated, service_role;

-- A membership change commits its facts with the change itself. A failure
-- never blocks the business commit: it is audited, and the reconcile
-- re-derives the relationship within a tick.
create or replace function public.membership_fact_on_member_change()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  begin
    if tg_op in ('UPDATE', 'DELETE') then
      perform public.membership_fact_produce(old.workspace_id, old.user_id);
    end if;
    if tg_op in ('INSERT', 'UPDATE') then
      perform public.membership_fact_produce(new.workspace_id, new.user_id);
    end if;
  exception when others then
    insert into public.database_authority_audit (installation_id, action, actor, detail)
    values (public.installation_id(), 'membership_fact_unissued', 'system',
            jsonb_build_object('sqlstate', sqlstate));
  end;
  return null;
end;
$fn$;
revoke execute on function public.membership_fact_on_member_change()
  from public, anon, authenticated, service_role;
drop trigger if exists membership_fact_on_member_change on public.members;
create trigger membership_fact_on_member_change
  after insert or update of status, user_id, workspace_id or delete on public.members
  for each row execute function public.membership_fact_on_member_change();

create or replace function public.membership_fact_on_binding_change()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_ws uuid;
begin
  begin
    for v_ws in select m.workspace_id from public.members m where m.user_id = new.local_user_id
                union
                select split_part(s.network_id, ':', 2)::uuid from public.membership_fact_state s
                 where s.issuer = new.issuer and s.subject = new.subject loop
      perform public.membership_fact_produce(v_ws, new.local_user_id);
    end loop;
  exception when others then
    insert into public.database_authority_audit
      (installation_id, action, actor, target_user_id, detail)
    values (public.installation_id(), 'membership_fact_unissued', 'system', new.local_user_id,
            jsonb_build_object('sqlstate', sqlstate));
  end;
  return null;
end;
$fn$;
revoke execute on function public.membership_fact_on_binding_change()
  from public, anon, authenticated, service_role;
drop trigger if exists membership_fact_on_binding_change on public.identity_bindings;
create trigger membership_fact_on_binding_change
  after insert or update of status, local_user_id on public.identity_bindings
  for each row execute function public.membership_fact_on_binding_change();

-- Heals and keeps warm: re-derives every bound relationship, tombstones
-- one whose binding is gone, and re-asserts a quiet one at the same
-- revision before the home lets it lapse.
create or replace function public.membership_fact_reconcile()
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_issuer text;
  v_every interval := make_interval(secs =>
    (public.setting_value(null, 'identity.status_reconcile_seconds') #>> '{}')::int);
  v_pair record;
  v_state public.membership_fact_state;
  v_changed int := 0;
  v_renewed int := 0;
begin
  select issuer into v_issuer from public.identity_authority where kind = 'oidc';
  if v_issuer is null then
    return jsonb_build_object('changed', 0, 'renewed', 0, 'authority', 'native');
  end if;
  for v_pair in
    select m.workspace_id, m.user_id from public.members m
      join public.identity_bindings b on b.local_user_id = m.user_id
       and b.installation_id = public.installation_id() and b.issuer = v_issuer
    union
    select split_part(s.network_id, ':', 2)::uuid, b.local_user_id
      from public.membership_fact_state s
      join public.identity_bindings b on b.issuer = s.issuer and b.subject = s.subject
       and b.installation_id = public.installation_id()
     where s.issuer = v_issuer and s.status <> 'tombstone' loop
    v_changed := v_changed + public.membership_fact_produce(v_pair.workspace_id, v_pair.user_id);
  end loop;
  for v_state in select s.* from public.membership_fact_state s
                  where s.status <> 'tombstone'
                    and not exists (select 1 from public.identity_bindings b
                                     where b.issuer = s.issuer and b.subject = s.subject
                                       and b.installation_id = public.installation_id()) loop
    update public.membership_fact_state
       set revision = nextval('public.membership_fact_revision'), status = 'tombstone',
           last_asserted_at = null
     where issuer = v_state.issuer and subject = v_state.subject and network_id = v_state.network_id
    returning * into v_state;
    v_changed := v_changed + public.membership_fact_enqueue(v_state);
  end loop;
  for v_state in select s.* from public.membership_fact_state s
                  where (s.status <> 'tombstone'
                         and (s.last_asserted_at is null or s.last_asserted_at <= now() - v_every))
                     or (s.status = 'tombstone' and s.last_asserted_at is null) loop
    v_renewed := v_renewed + public.membership_fact_enqueue(v_state);
  end loop;
  return jsonb_build_object('changed', v_changed, 'renewed', v_renewed);
end;
$fn$;
revoke execute on function public.membership_fact_reconcile()
  from public, anon, authenticated, service_role;

-- ── W: deliver (identity_status_drain's shape, to the personal home) ──
create or replace function public.membership_fact_drain()
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_row public.membership_fact_outbox;
  v_home record;
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
    for v_row in select * from public.membership_fact_outbox
                  where state = 'sent' order by asserted_at for update skip locked loop
      execute 'select status_code, content, timed_out from net._http_response where id = $1'
        into v_code, v_content, v_timed_out using v_row.net_request_id;
      get diagnostics v_found = row_count;
      begin
        v_outcome := v_content::jsonb->>'outcome';
      exception when others then
        v_outcome := null;
      end;
      if v_found = 0 then
        if v_row.last_attempt_at < now() - interval '2 minutes' then
          update public.membership_fact_outbox set state = 'pending', outcome = 'no_answer'
           where event_id = v_row.event_id;
        end if;
        continue;
      end if;
      if v_code between 200 and 299 then
        update public.membership_fact_outbox
           set state = 'delivered', delivered_at = now(), outcome = coalesce(v_outcome, 'delivered')
         where event_id = v_row.event_id;
      elsif v_code in (400, 409, 421, 422) then
        update public.membership_fact_outbox
           set state = 'refused', outcome = coalesce(v_outcome, 'http_' || v_code)
         where event_id = v_row.event_id;
      else
        update public.membership_fact_outbox
           set state = 'pending',
               outcome = coalesce(v_outcome, case when coalesce(v_timed_out, false)
                                                  then 'timeout' else 'http_' || v_code end)
         where event_id = v_row.event_id;
      end if;
      v_settled := v_settled + 1;
    end loop;
  end if;
  -- 2. what lapsed undelivered, and what can no longer matter
  update public.membership_fact_outbox set state = 'expired'
   where state in ('pending', 'sent') and valid_until <= now();
  delete from public.membership_fact_outbox
   where state in ('delivered', 'refused', 'expired') and valid_until <= now();
  -- 3. send
  if to_regprocedure('net.http_post(text, jsonb, jsonb, jsonb, integer)') is null then
    return jsonb_build_object('settled', v_settled, 'sent', 0, 'transport', 'unavailable');
  end if;
  select * into v_home from public.membership_fact_home();
  for v_row in select * from public.membership_fact_outbox
                where state = 'pending' order by asserted_at limit 200 for update skip locked loop
    if v_row.target_installation_id is distinct from v_home.home_installation_id then
      update public.membership_fact_outbox set state = 'refused', outcome = 'home_changed'
       where event_id = v_row.event_id;
      continue;
    end if;
    begin
      v_headers := public.federation_envelope_headers('membership_fact',
        v_row.target_installation_id, v_row.event_id, '/federation-inbox', v_row.body);
    exception when sqlstate 'P0002' then
      update public.membership_fact_outbox set outcome = 'no_outbound_key'
       where event_id = v_row.event_id;
      continue;
    end;
    update public.membership_fact_outbox
       set state = 'sent', attempts = attempts + 1, last_attempt_at = now(),
           net_request_id = net.http_post(
             url := v_home.home_origin || '/functions/v1/federation-inbox',
             body := v_row.body,
             headers := v_headers || jsonb_build_object('Content-Type', 'application/json',
                                                        'apikey', v_home.home_key),
             timeout_milliseconds := 10000)
     where event_id = v_row.event_id;
    v_sent := v_sent + 1;
  end loop;
  return jsonb_build_object('settled', v_settled, 'sent', v_sent);
end;
$fn$;
revoke execute on function public.membership_fact_drain()
  from public, anon, authenticated, service_role;

-- ── P: receive ───────────────────────────────────────────────────────
create or replace function public.membership_fact_apply(
  p_body jsonb, p_source uuid, p_event uuid, p_request_ts bigint)
returns text language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_skew interval := make_interval(secs =>
    (public.setting_value(null, 'identity.clock_skew_seconds') #>> '{}')::int);
  v_lifetime interval := make_interval(secs =>
    (public.setting_value(null, 'identity.status_assertion_lifetime_seconds') #>> '{}')::int);
  v_issuer text;
  v_user uuid;
  v_ref text;
  v_status text;
  v_revision bigint;
  v_issued timestamptz;
  v_until timestamptz;
  v_epoch timestamptz;
  v_current public.membership_facts;
begin
  begin
    v_issuer := p_body->>'issuer';
    v_user := (p_body->>'subject')::uuid;
    v_ref := p_body->>'network_id';
    v_status := p_body->>'status';
    v_revision := (p_body->>'revision')::bigint;
    v_issued := (p_body->>'asserted_at')::timestamptz;
    v_until := (p_body->>'valid_until')::timestamptz;
  exception when others then
    return 'malformed';
  end;
  if p_body->>'kind' is distinct from 'membership_fact' or p_body->>'protocol' is distinct from '1'
     or p_body->>'event_id' is distinct from p_event::text
     or p_body->>'source_installation_id' is distinct from p_source::text
     or p_body->>'target_installation_id' is distinct from public.installation_id()::text
     or v_issuer is null or v_user is null
     or v_status is null or v_status not in ('active', 'paused', 'pending', 'exited', 'tombstone')
     or coalesce(v_revision, 0) < 1 or v_issued is null or v_until is null or v_until <= v_issued
     or not coalesce(public.workspace_network_ref_valid(v_ref), false) then
    return 'malformed';
  end if;
  -- A workspace installation speaks for its own workspaces only.
  if split_part(v_ref, ':', 1) <> p_source::text then
    return 'foreign_workspace';
  end if;
  -- The subject is a person of THIS home's own identity.
  if not exists (select 1 from public.identity_authority
                  where kind = 'native' and issuer = v_issuer) then
    return 'wrong_issuer';
  end if;
  if v_issued > now() + v_skew or to_timestamp(p_request_ts) < v_issued - v_skew then
    return 'future_assertion';
  end if;
  v_until := least(v_until, v_issued + v_lifetime);
  if v_until + v_skew <= now() then
    return 'expired_assertion';
  end if;
  select enrolled_at into v_epoch from public.enrolled_installations
   where installation_id = p_source and enabled;
  if v_epoch is null then
    return 'unenrolled_source';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('membership_fact:' || v_user || ':' || v_ref, 2563));
  select * into v_current from public.membership_facts
   where user_id = v_user and network_id = v_ref for update;
  -- Linked: the person consented to the source. A tombstone only narrows,
  -- so it also lands on a fact already held.
  if not exists (select 1 from auth.users u where u.id = v_user)
     or (not (p_source in (select t from public.identity_status_linked_targets(v_user) t))
         and (v_status <> 'tombstone' or v_current.revision is null)) then
    return 'unlinked_subject';
  end if;
  if v_current.revision is null then
    insert into public.membership_facts (user_id, network_id, issuer, source_installation_id,
      revision, status, asserted_at, valid_until, enrolment_epoch, event_id)
    values (v_user, v_ref, v_issuer, p_source, v_revision, v_status, v_issued, v_until, v_epoch,
      p_event);
    return 'applied';
  end if;
  if v_revision < v_current.revision then
    return 'superseded';
  end if;
  if v_revision = v_current.revision then
    if v_status <> v_current.status or p_source <> v_current.source_installation_id then
      return 'revision_conflict';
    end if;
    if v_issued <= v_current.asserted_at then
      return 'superseded';
    end if;
    update public.membership_facts
       set asserted_at = v_issued, valid_until = v_until, enrolment_epoch = v_epoch,
           event_id = p_event, received_at = now()
     where user_id = v_user and network_id = v_ref;
    return 'renewed';
  end if;
  update public.membership_facts
     set issuer = v_issuer, source_installation_id = p_source, revision = v_revision,
         status = v_status, asserted_at = v_issued, valid_until = v_until,
         enrolment_epoch = v_epoch, event_id = p_event, received_at = now()
   where user_id = v_user and network_id = v_ref;
  return 'applied';
end;
$fn$;
revoke execute on function public.membership_fact_apply(jsonb, uuid, uuid, bigint)
  from public, anon, authenticated, service_role;

-- What `federation-inbox` calls with the request's raw body (base64). C2b's,
-- restated whole: the purpose decides the apply function.
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
  if v_outcome is null and jsonb_typeof(v_body) = 'object' then
    if v_verified->>'purpose' = 'identity_status' then
      v_outcome := public.identity_status_apply(v_body, (v_verified->>'source')::uuid,
        (v_verified->>'event')::uuid, (v_verified->>'timestamp')::bigint);
    elsif v_verified->>'purpose' = 'membership_fact' then
      v_outcome := public.membership_fact_apply(v_body, (v_verified->>'source')::uuid,
        (v_verified->>'event')::uuid, (v_verified->>'timestamp')::bigint);
    end if;
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

-- ── P: the policy ────────────────────────────────────────────────────
-- A person's verified relationship with a workspace, in one of the given
-- statuses: received under the source's enrolment in force, and its
-- source-issued deadline plus the allowed skew not passed.
create or replace function public.membership_fact_in_force(
  p_user uuid, p_ref text, p_statuses text[])
returns boolean language sql stable security definer set search_path = public as $fn$
  select exists (
    select 1 from public.membership_facts f
      join public.enrolled_installations e
        on e.installation_id = f.source_installation_id and e.enabled
       and e.enrolled_at = f.enrolment_epoch
     where f.user_id = p_user and f.network_id = p_ref and f.status = any (p_statuses)
       and f.valid_until + make_interval(secs =>
             (public.setting_value(null, 'identity.clock_skew_seconds') #>> '{}')::int) > now());
$fn$;
revoke execute on function public.membership_fact_in_force(uuid, text, text[])
  from public, anon, authenticated, service_role;

-- 0387's evaluator, restated whole: the same audiences, block precedence
-- and statuses; a shared space is a local membership pair OR two verified
-- facts in force for the same network id.
create or replace function public.account_field_visible_to(
  p_owner uuid, p_field text, p_viewer uuid
) returns boolean language plpgsql stable security definer set search_path = public as $$
declare v_audience text;
begin
  if p_owner is null or p_viewer is null then return false; end if;
  if p_owner = p_viewer then return true; end if;
  -- #2211: a block, either way, removes every field and the reachability.
  if public.account_blocked_between(p_owner, p_viewer) then return false; end if;
  v_audience := public.account_audience_of(p_owner, p_field);
  if v_audience = 'signed_in' then return true; end if;
  if v_audience = 'my_spaces' then
    return exists (
      select 1 from public.members a
        join public.members b on b.workspace_id = a.workspace_id
       where a.user_id = p_owner and b.user_id = p_viewer
         and a.status in ('active', 'paused')
         and b.status in ('active', 'paused'))
      or exists (
      select 1 from public.membership_facts f
       where f.user_id = p_owner and f.status in ('active', 'paused')
         and public.membership_fact_in_force(p_owner, f.network_id, array['active', 'paused'])
         and public.membership_fact_in_force(p_viewer, f.network_id, array['active', 'paused']));
  end if;
  if v_audience = 'chosen_spaces' then
    return exists (
      select 1 from public.account_field_audience_spaces s
        join public.members a on a.workspace_id = s.workspace_id
         and a.user_id = p_owner and a.status in ('active', 'paused')
        join public.members b on b.workspace_id = s.workspace_id
         and b.user_id = p_viewer and b.status in ('active', 'paused')
       where s.user_id = p_owner and s.field = p_field)
      or exists (
      select 1 from public.account_field_audience_spaces s
       where s.user_id = p_owner and s.field = p_field and s.workspace_id is null
         and public.membership_fact_in_force(p_owner, s.workspace_network_id, array['active', 'paused'])
         and public.membership_fact_in_force(p_viewer, s.workspace_network_id, array['active', 'paused']));
  end if;
  return false;
end;
$$;
revoke execute on function public.account_field_visible_to(uuid, text, uuid)
  from public, anon, authenticated, service_role;

-- ── P: my references say how they are known ──────────────────────────
-- 0566's reader, restated whole: the workspaces my facts name join the
-- list; a reference to another installation is `verified` while its fact
-- is in force, `stale` once it lapsed, `unavailable` without one. A
-- tombstone reads as no relationship. Never a role or a permission.
create or replace function public.my_personal_workspace_refs_v1()
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_me uuid := auth.uid();
  v_home text := public.installation_id()::text;
begin
  perform public.mcp_require_native();
  return jsonb_build_object(
    'home', public.personal_home_descriptor(),
    'refs', coalesce((
      select jsonb_agg(jsonb_build_object(
               'network_id', x.ref,
               'installation_id', split_part(x.ref, ':', 1),
               'workspace_id', split_part(x.ref, ':', 2),
               'hosted_here', split_part(x.ref, ':', 1) = v_home,
               'label', case when m.status is not null or w.visibility_set_at is not null
                             then w.name end,
               'status', coalesce(m.status, nullif(f.status, 'tombstone')),
               'freshness', case when split_part(x.ref, ':', 1) = v_home then 'local'
                                 when f.status is null then 'unavailable'
                                 when public.membership_fact_in_force(v_me, x.ref, array[f.status])
                                   then 'verified'
                                 else 'stale' end,
               'is_default', x.ref = (select p.default_workspace_network_id
                                        from public.profiles p where p.id = v_me),
               'is_favorite', exists (select 1 from public.workspace_favorites f2
                                       where f2.user_id = v_me and f2.workspace_network_id = x.ref),
               'audience_fields', coalesce((select jsonb_agg(s.field order by s.field)
                                              from public.account_field_audience_spaces s
                                             where s.user_id = v_me
                                               and s.workspace_network_id = x.ref), '[]'::jsonb))
             order by x.ref)
        from (select w0.network_id as ref
                from public.members m0 join public.workspaces w0 on w0.id = m0.workspace_id
               where m0.user_id = v_me
              union
              select f0.network_id from public.membership_facts f0
               where f0.user_id = v_me and f0.status <> 'tombstone'
              union
              select f1.workspace_network_id from public.workspace_favorites f1 where f1.user_id = v_me
              union
              select s.workspace_network_id from public.account_field_audience_spaces s where s.user_id = v_me
              union
              select p.default_workspace_network_id from public.profiles p
               where p.id = v_me and p.default_workspace_network_id is not null) x
        left join public.workspaces w on w.network_id = x.ref
        left join public.membership_facts f on f.user_id = v_me and f.network_id = x.ref
        left join lateral (select m1.status from public.members m1
                            where m1.workspace_id = w.id and m1.user_id = v_me
                            order by case m1.status when 'active' then 0 when 'paused' then 1
                                                    when 'pending' then 2 else 3 end
                            limit 1) m on true), '[]'::jsonb));
end;
$fn$;
revoke execute on function public.my_personal_workspace_refs_v1() from public, anon;
grant execute on function public.my_personal_workspace_refs_v1() to authenticated;

-- ── the tick ─────────────────────────────────────────────────────────
do $cron$
begin
  create extension if not exists pg_cron;
  perform cron.unschedule('deskilo-membership-fact-tick')
    where exists (select 1 from cron.job where jobname = 'deskilo-membership-fact-tick');
  perform cron.schedule('deskilo-membership-fact-tick', '* * * * *',
    $job$select public.membership_fact_reconcile(); select public.membership_fact_drain()$job$);
exception when others then
  raise notice 'pg_cron unavailable (%): an operator runs membership_fact_reconcile() and membership_fact_drain() instead', sqlerrm;
end
$cron$;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(9998);
