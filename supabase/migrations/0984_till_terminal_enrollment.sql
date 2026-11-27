-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
--
-- #4454 (E03A, slice 1) -- a till board is connected to a business. The owner scans the board's QR code in
-- Settings › Devices and is given a code for one till; the board presents that code with its own id and the hash of
-- its secret; the board then waits for the owner, who approves it when the fingerprint the board shows is the one
-- the app shows. Revoking a board ends it. Nothing here sells: what an approved board may do for a cashier comes with
-- the operator authorization (slice 2).
--
--   till_terminal_codes   a code given for one board and one till: bound to the board's id and to the sha256 of its
--                         secret, both read from its QR code, so a board that only saw the QR cannot use it; kept as
--                         the sha256 of its 12 characters, single use, valid counter.terminal_pair_minutes, spent
--                         after counter.terminal_pair_attempts presentations with the wrong board or proof.
--   till_terminals        a board of a business: pending_approval, paired or revoked. The sha256 of its secret is
--                         kept, never the secret; one paired board per device id in a business (a new approval of
--                         the same board revokes the earlier one).
--   No client role reads either table: the owner's functions answer without hashes, and the board's two functions
--   (claim, status) are the service role's only, called by the embedded-till edge function.
--
-- Settings: counter.terminal_pair_minutes (5, 1..15) and counter.terminal_pair_attempts (5, 1..10).
-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('counter.terminal_pair_minutes', 'int', '5'::jsonb, 1, 15, 'minutes', 'business', array['workspace'], 'workspaceSettings', null, true, null, 'till boards (#4454)', 'How long the code that connects a till board to the business is valid, in minutes. A board that has not used it by then needs a new code. A change applies to the next code, never to one already given.'),
('counter.terminal_pair_attempts', 'int', '5'::jsonb, 1, 10, '', 'business', array['workspace'], 'workspaceSettings', null, true, null, 'till boards (#4454)', 'How many times a board may present a connection code with the wrong board or the wrong proof before the code is used up. The board that the code was made for then needs a new code.')
on conflict (key) do nothing;
-- END GENERATED SEED

-- ── the codes ───────────────────────────────────────────────────────────────────────────────────────────────────
create table public.till_terminal_codes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  till_id uuid not null,
  code_hash text not null unique check (code_hash ~ '^[0-9a-f]{64}$'),
  device_id uuid not null,
  board_profile text not null check (board_profile in ('lcdwiki_e32r40t_v1', 'ideaspark_st7789_v1')),
  secret_hash text not null check (secret_hash ~ '^[0-9a-f]{64}$'),
  fingerprint text not null check (fingerprint ~ '^[0-9A-F]{4}-[0-9A-F]{4}$'),
  created_by uuid references public.members (id) on delete set null,
  expires_at timestamptz not null,
  attempts_left integer not null check (attempts_left >= 0),
  claimed_at timestamptz,
  claim_request_id uuid,
  claim_secret_hash text check (claim_secret_hash ~ '^[0-9a-f]{64}$'),
  terminal_id uuid,
  cancelled_at timestamptz,
  foreign key (workspace_id, till_id) references public.counter_tills (workspace_id, id) on delete cascade
);
select public.ensure_system_columns('till_terminal_codes');
create index till_terminal_codes_device on public.till_terminal_codes (workspace_id, device_id);

comment on table public.till_terminal_codes is
  '#4454 -- the codes that connect a till board to a business: the sha256 of each code, never the code; single use and expiring.';

alter table public.till_terminal_codes enable row level security;
revoke all on public.till_terminal_codes from public, anon, authenticated;
create policy mcp_delegated_deny on public.till_terminal_codes as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── the boards ──────────────────────────────────────────────────────────────────────────────────────────────────
create table public.till_terminals (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  till_id uuid not null,
  device_id uuid not null,
  board_profile text not null check (board_profile in ('lcdwiki_e32r40t_v1', 'ideaspark_st7789_v1')),
  fingerprint text not null check (fingerprint ~ '^[0-9A-F]{4}-[0-9A-F]{4}$'),
  firmware text not null check (firmware ~ '^[!-~]{1,40}$'),
  protocol text not null check (protocol ~ '^v[0-9]{1,3}$'),
  secret_hash text not null check (secret_hash ~ '^[0-9a-f]{64}$'),
  status text not null default 'pending_approval' check (status in ('pending_approval', 'paired', 'revoked')),
  code_id uuid references public.till_terminal_codes (id) on delete set null,
  claimed_at timestamptz not null default now(),
  approved_by uuid references public.members (id) on delete set null,
  approved_at timestamptz,
  revoked_by uuid references public.members (id) on delete set null,
  revoked_at timestamptz,
  last_seen_at timestamptz,
  foreign key (workspace_id, till_id) references public.counter_tills (workspace_id, id) on delete cascade,
  check ((status = 'paired') = (approved_at is not null and revoked_at is null)),
  check ((status = 'revoked') = (revoked_at is not null))
);
select public.ensure_system_columns('till_terminals');
create unique index till_terminals_one_paired on public.till_terminals (workspace_id, device_id) where status = 'paired';
create index till_terminals_device on public.till_terminals (device_id, secret_hash);
create index till_terminals_workspace on public.till_terminals (workspace_id, claimed_at desc);

comment on table public.till_terminals is
  '#4454 -- the till boards of a business: pending approval, paired or revoked. Only the sha256 of a board''s secret is kept.';

alter table public.till_terminals enable row level security;
revoke all on public.till_terminals from public, anon, authenticated;
create policy mcp_delegated_deny on public.till_terminals as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── the code's form ─────────────────────────────────────────────────────────────────────────────────────────────
-- 12 Crockford base-32 characters (60 random bits; 32 = 2^5, so each character is unbiased), shown as XXXX-XXXX-XXXX.
create or replace function public.till_terminal_new_code()
returns text language plpgsql volatile set search_path = '' as $fn$
declare
  v_alphabet constant text := '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  v_bytes bytea := extensions.gen_random_bytes(12);
  v_code text := '';
begin
  for i in 0..11 loop
    v_code := v_code || substr(v_alphabet, (get_byte(v_bytes, i) & 31) + 1, 1);
  end loop;
  return v_code;
end;
$fn$;
revoke execute on function public.till_terminal_new_code() from public, anon, authenticated;

-- A code as typed or sent: case, spaces and dashes ignored, O read as 0 and I or L as 1 (Crockford); null for
-- anything that is not 12 such characters.
create or replace function public.till_terminal_code_normal(p_code text)
returns text language sql immutable set search_path = '' as $fn$
  select case when v ~ '^[0-9A-HJKMNP-TV-Z]{12}$' then v end
    from (select translate(upper(regexp_replace(coalesce(p_code, ''), '[\s-]', '', 'g')), 'OIL', '011') as v) t;
$fn$;
revoke execute on function public.till_terminal_code_normal(text) from public, anon, authenticated;

-- The fingerprint a board shows for the sha256 (hex) of its secret: its first four bytes, AB12-CD34.
create or replace function public.till_terminal_fingerprint(p_secret_hash text)
returns text language sql immutable set search_path = '' as $fn$
  select upper(substr(p_secret_hash, 1, 4) || '-' || substr(p_secret_hash, 5, 4));
$fn$;
revoke execute on function public.till_terminal_fingerprint(text) from public, anon, authenticated;

-- An owner of the business, in their own session (never an assistant's), with the till boards switched on.
create or replace function public.may_manage_till_terminals(p_workspace_id uuid)
returns boolean language sql stable security definer set search_path = '' as $fn$
  select auth.uid() is not null and not public.mcp_is_delegated() and public.is_owner_of(p_workspace_id)
     and public.feature_effective(p_workspace_id, 'counterEmbeddedTerminal');
$fn$;
revoke execute on function public.may_manage_till_terminals(uuid) from public, anon, authenticated;

create or replace function public.till_terminal_member(p_workspace_id uuid)
returns uuid language sql stable security definer set search_path = '' as $fn$
  select m.id from public.members m where m.workspace_id = p_workspace_id and m.user_id = auth.uid() limit 1;
$fn$;
revoke execute on function public.till_terminal_member(uuid) from public, anon, authenticated;

-- ── the owner's side ────────────────────────────────────────────────────────────────────────────────────────────
-- A code for the board the QR named (its id, profile and the sha256 of its secret), for one active till of the
-- business. The code is answered once; an earlier code for the same board, not yet used, is cancelled.
create or replace function public.till_terminal_code_create_v1(
  p_workspace_id uuid, p_till_id uuid, p_device_id uuid, p_board_profile text, p_secret_hash text)
returns jsonb language plpgsql volatile security definer set search_path = '' as $fn$
declare
  v_code text;
  v_minutes int;
  v_attempts int;
  v_row public.till_terminal_codes;
begin
  if not public.may_manage_till_terminals(p_workspace_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if not exists (select 1 from public.counter_tills t
                  where t.workspace_id = p_workspace_id and t.id = p_till_id and t.active) then
    raise exception 'scope_mismatch: not an active till of this business' using errcode = '22023';
  end if;
  if p_device_id is null or p_board_profile is null
     or p_board_profile not in ('lcdwiki_e32r40t_v1', 'ideaspark_st7789_v1')
     or coalesce(p_secret_hash, '') !~ '^[0-9a-f]{64}$' then
    raise exception 'protocol_unsupported: not a till board''s QR code' using errcode = '22023';
  end if;
  v_minutes := least(15, greatest(1, coalesce((public.setting_value(p_workspace_id, 'counter.terminal_pair_minutes') #>> '{}')::int, 5)));
  v_attempts := least(10, greatest(1, coalesce((public.setting_value(p_workspace_id, 'counter.terminal_pair_attempts') #>> '{}')::int, 5)));
  update public.till_terminal_codes c
     set cancelled_at = now()
   where c.workspace_id = p_workspace_id and c.device_id = p_device_id
     and c.claimed_at is null and c.cancelled_at is null and c.expires_at > now();
  v_code := public.till_terminal_new_code();
  insert into public.till_terminal_codes
    (workspace_id, till_id, code_hash, device_id, board_profile, secret_hash, fingerprint, created_by, expires_at,
     attempts_left)
  values (p_workspace_id, p_till_id, encode(extensions.digest(v_code, 'sha256'), 'hex'), p_device_id,
          p_board_profile, p_secret_hash, public.till_terminal_fingerprint(p_secret_hash),
          public.till_terminal_member(p_workspace_id),
          now() + make_interval(mins => v_minutes), v_attempts)
  returning * into v_row;
  return jsonb_build_object(
    'code_id', v_row.id,
    'code', substr(v_code, 1, 4) || '-' || substr(v_code, 5, 4) || '-' || substr(v_code, 9, 4),
    'expires_at', v_row.expires_at);
end;
$fn$;
revoke execute on function public.till_terminal_code_create_v1(uuid, uuid, uuid, text, text) from public, anon;
grant execute on function public.till_terminal_code_create_v1(uuid, uuid, uuid, text, text) to authenticated;

-- A code withdrawn before a board used it: false when it was used, cancelled or expired already.
create or replace function public.till_terminal_code_cancel_v1(p_code_id uuid)
returns boolean language plpgsql volatile security definer set search_path = '' as $fn$
declare
  v_row public.till_terminal_codes;
begin
  select * into v_row from public.till_terminal_codes where id = p_code_id for update;
  if v_row.id is null or not public.may_manage_till_terminals(v_row.workspace_id) then
    raise exception 'unknown code' using errcode = '42501';
  end if;
  if v_row.claimed_at is not null or v_row.cancelled_at is not null or v_row.expires_at <= now() then
    return false;
  end if;
  update public.till_terminal_codes set cancelled_at = now() where id = p_code_id;
  return true;
end;
$fn$;
revoke execute on function public.till_terminal_code_cancel_v1(uuid) from public, anon;
grant execute on function public.till_terminal_code_cancel_v1(uuid) to authenticated;

-- A board waiting for approval is approved when the fingerprint the owner read on it is the one its secret gives.
-- An earlier paired enrollment of the same board in this business is revoked: one paired board per device.
create or replace function public.till_terminal_approve_v1(p_terminal_id uuid, p_fingerprint text)
returns jsonb language plpgsql volatile security definer set search_path = '' as $fn$
declare
  v_row public.till_terminals;
  v_member uuid;
begin
  select * into v_row from public.till_terminals where id = p_terminal_id for update;
  if v_row.id is null or not public.may_manage_till_terminals(v_row.workspace_id) then
    raise exception 'unknown board' using errcode = '42501';
  end if;
  if v_row.status <> 'pending_approval' then
    raise exception 'pair_used: this board is not waiting for approval' using errcode = '22023';
  end if;
  if upper(btrim(coalesce(p_fingerprint, ''))) <> v_row.fingerprint then
    raise exception 'pair_proof_invalid: the fingerprint is not this board''s' using errcode = '22023';
  end if;
  v_member := public.till_terminal_member(v_row.workspace_id);
  update public.till_terminals
     set status = 'revoked', revoked_at = now(), revoked_by = v_member
   where workspace_id = v_row.workspace_id and device_id = v_row.device_id and status = 'paired';
  update public.till_terminals
     set status = 'paired', approved_at = now(), approved_by = v_member
   where id = p_terminal_id
  returning * into v_row;
  return jsonb_build_object('id', v_row.id, 'status', v_row.status, 'approved_at', v_row.approved_at);
end;
$fn$;
revoke execute on function public.till_terminal_approve_v1(uuid, text) from public, anon;
grant execute on function public.till_terminal_approve_v1(uuid, text) to authenticated;

-- A board revoked, waiting or paired: it is no board of the business from now on. false when it was revoked already.
create or replace function public.till_terminal_revoke_v1(p_terminal_id uuid)
returns boolean language plpgsql volatile security definer set search_path = '' as $fn$
declare
  v_row public.till_terminals;
begin
  select * into v_row from public.till_terminals where id = p_terminal_id for update;
  if v_row.id is null or not public.may_manage_till_terminals(v_row.workspace_id) then
    raise exception 'unknown board' using errcode = '42501';
  end if;
  if v_row.status = 'revoked' then
    return false;
  end if;
  update public.till_terminals
     set status = 'revoked', revoked_at = now(), revoked_by = public.till_terminal_member(v_row.workspace_id)
   where id = p_terminal_id;
  return true;
end;
$fn$;
revoke execute on function public.till_terminal_revoke_v1(uuid) from public, anon;
grant execute on function public.till_terminal_revoke_v1(uuid) to authenticated;

-- The boards of a business that are waiting or paired, newest first, without any hash: for whoever may open the
-- business's settings (Settings › Devices), in their own session; connecting, approving and revoking stay the owner's.
create or replace function public.till_terminals_v1(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $fn$
begin
  if auth.uid() is null or public.mcp_is_delegated() or not public.has_permission(p_workspace_id, 'workspaceSettings')
     or not public.feature_effective(p_workspace_id, 'counterEmbeddedTerminal') then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', d.id, 'till_id', d.till_id, 'till_name', t.name, 'device_id', d.device_id,
             'board_profile', d.board_profile, 'fingerprint', d.fingerprint, 'firmware', d.firmware,
             'status', d.status, 'claimed_at', d.claimed_at, 'approved_at', d.approved_at,
             'last_seen_at', d.last_seen_at) order by d.claimed_at desc, d.id)
      from public.till_terminals d
      join public.counter_tills t on t.workspace_id = d.workspace_id and t.id = d.till_id
     where d.workspace_id = p_workspace_id and d.status <> 'revoked'), '[]'::jsonb);
end;
$fn$;
revoke execute on function public.till_terminals_v1(uuid) from public, anon;
grant execute on function public.till_terminals_v1(uuid) to authenticated;

-- ── the board's side (the embedded-till edge function, as the service role) ─────────────────────────────────────
-- The board presents its code with its id, the sha256 of its secret, its firmware, its protocol and a request id of
-- its own. The same presentation again (a lost answer) answers the same; another board, another proof or another
-- request is refused. A presentation with the wrong board or proof spends one attempt. Refusals are answers, never
-- errors: { ok: false, reason }.
create or replace function public.till_terminal_claim_v1(
  p_code text, p_device_id uuid, p_secret_hash text, p_firmware text, p_protocol text, p_claim_request_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = '' as $fn$
declare
  v_code text := public.till_terminal_code_normal(p_code);
  v_row public.till_terminal_codes;
  v_terminal public.till_terminals;
begin
  if p_protocol is distinct from 'v1' then
    return jsonb_build_object('ok', false, 'reason', 'protocol_unsupported');
  end if;
  if v_code is null or p_device_id is null or p_claim_request_id is null
     or coalesce(p_secret_hash, '') !~ '^[0-9a-f]{64}$' or coalesce(p_firmware, '') !~ '^[!-~]{1,40}$' then
    return jsonb_build_object('ok', false, 'reason', 'pair_proof_invalid');
  end if;
  select * into v_row from public.till_terminal_codes
   where code_hash = encode(extensions.digest(v_code, 'sha256'), 'hex') for update;
  if v_row.id is null then
    return jsonb_build_object('ok', false, 'reason', 'pair_proof_invalid');
  end if;
  if v_row.claimed_at is not null then
    if v_row.claim_request_id = p_claim_request_id and v_row.claim_secret_hash = p_secret_hash
       and v_row.device_id = p_device_id then
      select * into v_terminal from public.till_terminals where id = v_row.terminal_id;
      return jsonb_build_object('ok', true, 'status', coalesce(v_terminal.status, 'revoked'), 'terminal_id', v_row.terminal_id);
    end if;
    return jsonb_build_object('ok', false, 'reason', 'pair_used');
  end if;
  if v_row.cancelled_at is not null or v_row.expires_at <= now() then
    return jsonb_build_object('ok', false, 'reason', 'pair_expired');
  end if;
  if v_row.attempts_left = 0 then
    return jsonb_build_object('ok', false, 'reason', 'pair_used');
  end if;
  if v_row.device_id <> p_device_id or p_secret_hash <> v_row.secret_hash then
    update public.till_terminal_codes set attempts_left = attempts_left - 1 where id = v_row.id;
    return jsonb_build_object('ok', false, 'reason', 'pair_proof_invalid');
  end if;
  if not public.feature_effective(v_row.workspace_id, 'counterEmbeddedTerminal') then
    return jsonb_build_object('ok', false, 'reason', 'feature_off');
  end if;
  if not exists (select 1 from public.counter_tills t
                  where t.workspace_id = v_row.workspace_id and t.id = v_row.till_id and t.active) then
    return jsonb_build_object('ok', false, 'reason', 'scope_mismatch');
  end if;
  insert into public.till_terminals
    (workspace_id, till_id, device_id, board_profile, fingerprint, firmware, protocol, secret_hash, code_id)
  values (v_row.workspace_id, v_row.till_id, p_device_id, v_row.board_profile, v_row.fingerprint, p_firmware,
          p_protocol, v_row.secret_hash, v_row.id)
  returning * into v_terminal;
  update public.till_terminal_codes
     set claimed_at = now(), claim_request_id = p_claim_request_id, claim_secret_hash = p_secret_hash,
         terminal_id = v_terminal.id
   where id = v_row.id;
  return jsonb_build_object('ok', true, 'status', v_terminal.status, 'terminal_id', v_terminal.id);
end;
$fn$;
revoke execute on function public.till_terminal_claim_v1(text, uuid, text, text, text, uuid) from public, anon, authenticated;
grant execute on function public.till_terminal_claim_v1(text, uuid, text, text, text, uuid) to service_role;

-- The board asks where it stands, proving its secret (64 hex characters; the server keeps only its sha256). The scope
-- is the server's record, never the board's word. { ok: true, status: pending_approval | paired, ... } or a refusal.
create or replace function public.till_terminal_status_v1(p_device_id uuid, p_secret text)
returns jsonb language plpgsql volatile security definer set search_path = '' as $fn$
declare
  v_hash text;
  v_row public.till_terminals;
begin
  if p_device_id is null or coalesce(p_secret, '') !~ '^[0-9a-fA-F]{64}$' then
    return jsonb_build_object('ok', false, 'reason', 'pair_proof_invalid');
  end if;
  v_hash := encode(extensions.digest(decode(lower(p_secret), 'hex'), 'sha256'), 'hex');
  select * into v_row from public.till_terminals
   where device_id = p_device_id and secret_hash = v_hash
   order by (status = 'paired') desc, (status = 'pending_approval') desc, claimed_at desc
   limit 1 for update;
  if v_row.id is null then
    return jsonb_build_object('ok', false, 'reason', 'pair_proof_invalid');
  end if;
  if v_row.status = 'revoked' then
    return jsonb_build_object('ok', false, 'reason', 'device_revoked');
  end if;
  if not public.feature_effective(v_row.workspace_id, 'counterEmbeddedTerminal') then
    return jsonb_build_object('ok', false, 'reason', 'feature_off');
  end if;
  update public.till_terminals set last_seen_at = now() where id = v_row.id;
  return jsonb_build_object('ok', true, 'status', v_row.status, 'terminal_id', v_row.id,
                            'workspace_id', v_row.workspace_id, 'till_id', v_row.till_id);
end;
$fn$;
revoke execute on function public.till_terminal_status_v1(uuid, text) from public, anon, authenticated;
grant execute on function public.till_terminal_status_v1(uuid, text) to service_role;

select public.set_deskilo_schema_version(984);
