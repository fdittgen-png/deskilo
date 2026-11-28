-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
--
-- #4454 (E03A, slice 2) -- a paired till board sells as a cashier who authorized it, never as itself. The board asks
-- for an operator with a lease token it made (only the token's sha256 reaches the server); a cashier who may sell in the
-- business, signed in to Deskilo in their own session, attaches themselves to that request; from then on every command
-- the board sends is checked here (the board, its lease, the cashier still a member, their sign-in still alive) before
-- the embedded-till edge function forwards it to the till's existing functions with the cashier's own access token,
-- which keep checking the cashier's rights and the features as for any person.
--
--   till_terminal_leases   one request per board: asked (no operator yet), then held by one cashier until it expires
--                          or is revoked. It keeps the sha256 of the board's lease token, never the token, and the
--                          cashier's access token encrypted by the edge function (AES-GCM, a key only the function
--                          holds; the binding -- board, till, member, sign-in -- is its additional data). No client
--                          role reads it; the ciphertext is erased when the lease ends.
--   A lease expires at the earlier of the cashier's access token's expiry and counter.terminal_operator_minutes after
--   it was granted. A new request of the board ends its earlier ones; a revoked board ends its leases.
--
-- Settings: counter.terminal_operator_minutes (30, 1..60).
-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('counter.terminal_operator_minutes', 'int', '30'::jsonb, 1, 60, 'minutes', 'business', array['workspace'], 'workspaceSettings', null, true, null, 'till boards (#4454)', 'How long a cashier who authorized a till board may sell on it before authorizing it again, in minutes; never longer than their own sign-in lasts. A change applies to the next authorization, never to one already given.')
on conflict (key) do nothing;
-- END GENERATED SEED

create table public.till_terminal_leases (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  terminal_id uuid not null references public.till_terminals (id) on delete cascade,
  till_id uuid not null,
  lease_hash text not null unique check (lease_hash ~ '^[0-9a-f]{64}$'),
  requested_at timestamptz not null default now(),
  request_expires_at timestamptz not null,
  member_id uuid references public.members (id) on delete cascade,
  user_id uuid,
  auth_session_id uuid,
  token_ciphertext bytea,
  token_nonce bytea,
  granted_at timestamptz,
  expires_at timestamptz,
  revoked_at timestamptz,
  revoked_reason text check (revoked_reason in ('replaced', 'device_revoked', 'by_operator', 'by_owner', 'expired')),
  last_used_at timestamptz,
  foreign key (workspace_id, till_id) references public.counter_tills (workspace_id, id) on delete cascade,
  check ((granted_at is null) = (member_id is null)),
  check (granted_at is null or (user_id is not null and auth_session_id is not null and expires_at is not null)),
  check ((token_ciphertext is null) = (token_nonce is null))
);
select public.ensure_system_columns('till_terminal_leases');
create index till_terminal_leases_terminal on public.till_terminal_leases (terminal_id, requested_at desc);
create index till_terminal_leases_member on public.till_terminal_leases (member_id) where member_id is not null;

comment on table public.till_terminal_leases is
  '#4454 -- who sells on a till board: the sha256 of the board''s lease token and the cashier''s access token, encrypted by the edge function; no client reads it.';

alter table public.till_terminal_leases enable row level security;
revoke all on public.till_terminal_leases from public, anon, authenticated;
create policy mcp_delegated_deny on public.till_terminal_leases as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- The board, by its id and secret (the hex the board keeps): its paired row, or the refusal's reason. Called only by
-- the board's own definer functions below, so it runs with their rights.
create or replace function public.till_terminal_proven(p_device_id uuid, p_secret text, out terminal public.till_terminals, out reason text)
language plpgsql stable set search_path = '' as $fn$
begin
  if p_device_id is null or coalesce(p_secret, '') !~ '^[0-9a-fA-F]{64}$' then
    reason := 'pair_proof_invalid';
    return;
  end if;
  select * into terminal from public.till_terminals t
   where t.device_id = p_device_id
     and t.secret_hash = encode(extensions.digest(decode(lower(p_secret), 'hex'), 'sha256'), 'hex')
   order by (t.status = 'paired') desc, t.claimed_at desc
   limit 1;
  if terminal.id is null then reason := 'pair_proof_invalid';
  elsif terminal.status = 'revoked' then reason := 'device_revoked';
  elsif terminal.status <> 'paired' then reason := 'pair_pending';
  elsif not public.feature_effective(terminal.workspace_id, 'counterEmbeddedTerminal') then reason := 'feature_off';
  end if;
end;
$fn$;
revoke execute on function public.till_terminal_proven(uuid, text) from public, anon, authenticated;

-- ── the board asks ──────────────────────────────────────────────────────────────────────────────────────────────
-- The board, proven, asks for an operator with the sha256 of a lease token it made. Its earlier requests and leases end
-- (replaced): a board sells for one cashier at a time. Answers {ok, request_expires_at} or {ok: false, reason}.
create or replace function public.till_terminal_lease_request_v1(p_device_id uuid, p_secret text, p_lease_hash text)
returns jsonb language plpgsql volatile security definer set search_path = '' as $fn$
declare
  v_proof record;
  v_until timestamptz;
begin
  select * into v_proof from public.till_terminal_proven(p_device_id, p_secret);
  if v_proof.reason is not null then return jsonb_build_object('ok', false, 'reason', v_proof.reason); end if;
  if coalesce(p_lease_hash, '') !~ '^[0-9a-f]{64}$' then return jsonb_build_object('ok', false, 'reason', 'pair_proof_invalid'); end if;
  update public.till_terminal_leases
     set revoked_at = now(), revoked_reason = 'replaced', token_ciphertext = null, token_nonce = null
   where terminal_id = (v_proof.terminal).id and revoked_at is null;
  v_until := now() + make_interval(mins => least(15, greatest(1, coalesce((public.setting_value((v_proof.terminal).workspace_id, 'counter.terminal_pair_minutes') #>> '{}')::int, 5))));
  insert into public.till_terminal_leases (workspace_id, terminal_id, till_id, lease_hash, request_expires_at)
  values ((v_proof.terminal).workspace_id, (v_proof.terminal).id, (v_proof.terminal).till_id, p_lease_hash, v_until);
  return jsonb_build_object('ok', true, 'request_expires_at', v_until);
exception when unique_violation then
  return jsonb_build_object('ok', false, 'reason', 'pair_used');
end;
$fn$;
revoke execute on function public.till_terminal_lease_request_v1(uuid, text, text) from public, anon, authenticated;
grant execute on function public.till_terminal_lease_request_v1(uuid, text, text) to service_role;

-- ── the cashier authorizes ──────────────────────────────────────────────────────────────────────────────────────
-- The cashier signed in (their own session, never an assistant's), who may sell in the business, attaches themselves
-- to the board's open request. Their sign-in is the verified token's own session; the edge function passes the token
-- encrypted, never in clear. The lease runs to the earlier of the token's expiry and the operator minutes.
create or replace function public.till_terminal_lease_grant_v1(
  p_terminal_id uuid, p_token_ciphertext bytea, p_token_nonce bytea, p_token_expires_at timestamptz
) returns jsonb language plpgsql volatile security definer set search_path = '' as $fn$
declare
  v_terminal public.till_terminals;
  v_me uuid;
  v_session uuid;
  v_lease public.till_terminal_leases;
  v_until timestamptz;
begin
  select * into v_terminal from public.till_terminals where id = p_terminal_id;
  if v_terminal.id is null then
    perform public.refuse('DKL02', '{"reason": "terminal"}'::jsonb, 'no such till board');
  end if;
  v_me := public.command_actor(v_terminal.workspace_id, 'issueInvoices', 'counterEmbeddedTerminal',
    'only who sells in this business sells on its till boards', 'till boards are off in this business');
  if v_terminal.status <> 'paired' then
    perform public.refuse('DKL02', jsonb_build_object('reason', case v_terminal.status when 'revoked' then 'device_revoked' else 'pair_pending' end),
      'the till board is not connected');
  end if;
  v_session := nullif(auth.jwt() ->> 'session_id', '')::uuid;
  if v_session is null or p_token_ciphertext is null or p_token_nonce is null or p_token_expires_at is null
     or octet_length(p_token_nonce) <> 12 or p_token_expires_at <= now() then
    perform public.refuse('DKL02', '{"reason": "operator_token"}'::jsonb, 'the sign-in cannot be handed to the board');
  end if;
  select * into v_lease from public.till_terminal_leases
   where terminal_id = v_terminal.id and revoked_at is null and granted_at is null and request_expires_at > now()
   order by requested_at desc limit 1 for update;
  if v_lease.id is null then
    perform public.refuse('DKL02', '{"reason": "no_request"}'::jsonb, 'the till board has not asked for a cashier');
  end if;
  v_until := least(p_token_expires_at,
    now() + make_interval(mins => least(60, greatest(1, coalesce((public.setting_value(v_terminal.workspace_id, 'counter.terminal_operator_minutes') #>> '{}')::int, 30)))));
  update public.till_terminal_leases
     set member_id = v_me, user_id = auth.uid(), auth_session_id = v_session, token_ciphertext = p_token_ciphertext,
         token_nonce = p_token_nonce, granted_at = now(), expires_at = v_until
   where id = v_lease.id;
  return jsonb_build_object('lease_id', v_lease.id, 'terminal_id', v_terminal.id, 'till_id', v_terminal.till_id,
                            'member_id', v_me, 'expires_at', v_until);
end;
$fn$;
revoke execute on function public.till_terminal_lease_grant_v1(uuid, bytea, bytea, timestamptz) from public, anon;
grant execute on function public.till_terminal_lease_grant_v1(uuid, bytea, bytea, timestamptz) to authenticated;

-- ── every command of the board ──────────────────────────────────────────────────────────────────────────────────
-- The board, proven, and its lease token's sha256: the lease's binding and the encrypted token, while the lease is
-- granted, unexpired and unrevoked, its cashier still an active member and their sign-in still alive. An expired lease
-- loses its ciphertext here. Answers {ok, ...} or {ok: false, reason}.
create or replace function public.till_terminal_lease_resolve_v1(p_device_id uuid, p_secret text, p_lease_hash text)
returns jsonb language plpgsql volatile security definer set search_path = '' as $fn$
declare
  v_proof record;
  v_lease public.till_terminal_leases;
begin
  select * into v_proof from public.till_terminal_proven(p_device_id, p_secret);
  if v_proof.reason is not null then return jsonb_build_object('ok', false, 'reason', v_proof.reason); end if;
  select * into v_lease from public.till_terminal_leases where lease_hash = coalesce(p_lease_hash, '') for update;
  if v_lease.id is null or v_lease.terminal_id <> (v_proof.terminal).id or v_lease.till_id <> (v_proof.terminal).till_id
     or v_lease.workspace_id <> (v_proof.terminal).workspace_id then
    return jsonb_build_object('ok', false, 'reason', 'scope_mismatch');
  end if;
  if v_lease.revoked_at is not null then
    return jsonb_build_object('ok', false, 'reason', case when v_lease.revoked_reason = 'expired' then 'operator_expired' else 'operator_revoked' end);
  end if;
  if v_lease.granted_at is null then
    return jsonb_build_object('ok', false, 'reason', case when v_lease.request_expires_at > now() then 'operator_pending' else 'operator_expired' end);
  end if;
  if v_lease.expires_at <= now() then
    update public.till_terminal_leases set revoked_at = now(), revoked_reason = 'expired', token_ciphertext = null, token_nonce = null
     where id = v_lease.id;
    return jsonb_build_object('ok', false, 'reason', 'operator_expired');
  end if;
  if not exists (select 1 from public.members m where m.id = v_lease.member_id and m.user_id = v_lease.user_id and m.status = 'active')
     or not exists (select 1 from auth.sessions s where s.id = v_lease.auth_session_id and s.user_id = v_lease.user_id
                     and (s.not_after is null or s.not_after > now())) then
    update public.till_terminal_leases set revoked_at = now(), revoked_reason = 'by_owner', token_ciphertext = null, token_nonce = null
     where id = v_lease.id;
    return jsonb_build_object('ok', false, 'reason', 'operator_revoked');
  end if;
  update public.till_terminal_leases set last_used_at = now() where id = v_lease.id;
  return jsonb_build_object('ok', true, 'lease_id', v_lease.id, 'workspace_id', v_lease.workspace_id,
    'terminal_id', v_lease.terminal_id, 'till_id', v_lease.till_id, 'member_id', v_lease.member_id,
    'user_id', v_lease.user_id, 'auth_session_id', v_lease.auth_session_id, 'expires_at', v_lease.expires_at,
    'token_ciphertext', encode(v_lease.token_ciphertext, 'base64'), 'token_nonce', encode(v_lease.token_nonce, 'base64'));
end;
$fn$;
revoke execute on function public.till_terminal_lease_resolve_v1(uuid, text, text) from public, anon, authenticated;
grant execute on function public.till_terminal_lease_resolve_v1(uuid, text, text) to service_role;

-- ── ending a lease ──────────────────────────────────────────────────────────────────────────────────────────────
-- The cashier ends their own lease, or the owner ends any lease of the business. Answers whether one ended.
create or replace function public.till_terminal_lease_revoke_v1(p_lease_id uuid)
returns boolean language plpgsql volatile security definer set search_path = '' as $fn$
declare
  v_lease public.till_terminal_leases;
  v_reason text;
begin
  select * into v_lease from public.till_terminal_leases where id = p_lease_id for update;
  if v_lease.id is null then return false; end if;
  if v_lease.user_id is not null and v_lease.user_id = auth.uid() and not public.mcp_is_delegated() then
    v_reason := 'by_operator';
  else
    perform public.till_terminal_owner(v_lease.workspace_id);
    v_reason := 'by_owner';
  end if;
  if v_lease.revoked_at is not null then return false; end if;
  update public.till_terminal_leases set revoked_at = now(), revoked_reason = v_reason, token_ciphertext = null, token_nonce = null
   where id = v_lease.id;
  return true;
end;
$fn$;
revoke execute on function public.till_terminal_lease_revoke_v1(uuid) from public, anon;
grant execute on function public.till_terminal_lease_revoke_v1(uuid) to authenticated;

-- A revoked board ends its leases, with their tokens.
create or replace function public.till_terminal_leases_end()
returns trigger language plpgsql security definer set search_path = '' as $fn$
begin
  if new.status = 'revoked' and old.status is distinct from 'revoked' then
    update public.till_terminal_leases set revoked_at = now(), revoked_reason = 'device_revoked', token_ciphertext = null, token_nonce = null
     where terminal_id = new.id and revoked_at is null;
  end if;
  return new;
end;
$fn$;
revoke execute on function public.till_terminal_leases_end() from public, anon, authenticated;
drop trigger if exists till_terminals_leases_end on public.till_terminals;
create trigger till_terminals_leases_end after update of status on public.till_terminals
  for each row execute function public.till_terminal_leases_end();

select public.set_deskilo_schema_version(995);
