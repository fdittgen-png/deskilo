-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
--
-- #4517 (E04B step 4) -- a cashier authorizes a till board from the app: what the app reads of the boards' cashier
-- leases (0995), which no client role reads directly.
--   * till_terminals_v1        (restates 0984) the owner's list of the boards also says, of each, whether it asks for a
--                              cashier now and who sells on it until when: the lease's id, the member's display name
--                              and its end. Same caller rules. Never a token, a nonce or a hash.
--   * till_terminal_cashier_boards_v1
--                              the paired boards of the business for whom may sell: whether each asks for a cashier,
--                              whether the caller sells on it (their lease's id and end), or the display name of who
--                              does. Where till boards are on.
-- audience: all row readers (the owner's list as before; the cashiers' list to whom may sell, display names only)

-- The current lease of a board: granted, not revoked, not past its end.
create or replace function public.till_terminal_current_lease(p_terminal_id uuid)
returns public.till_terminal_leases language sql stable security definer set search_path = '' as $fn$
  select l.* from public.till_terminal_leases l
   where l.terminal_id = p_terminal_id and l.granted_at is not null and l.revoked_at is null and l.expires_at > now()
   order by l.granted_at desc limit 1
$fn$;
revoke execute on function public.till_terminal_current_lease(uuid) from public, anon, authenticated;

-- Whether a board asks for a cashier now: a request not granted, not revoked, not past its end.
create or replace function public.till_terminal_cashier_asked(p_terminal_id uuid)
returns boolean language sql stable security definer set search_path = '' as $fn$
  select exists (select 1 from public.till_terminal_leases l
                  where l.terminal_id = p_terminal_id and l.granted_at is null and l.revoked_at is null
                    and l.request_expires_at > now())
$fn$;
revoke execute on function public.till_terminal_cashier_asked(uuid) from public, anon, authenticated;

-- A lease as the app reads it: its id, its end, and the display name of who sells.
create or replace function public.till_terminal_lease_shown(p_lease public.till_terminal_leases)
returns jsonb language sql stable security definer set search_path = '' as $fn$
  select case when p_lease.id is null then null else jsonb_build_object(
    'id', p_lease.id, 'expires_at', p_lease.expires_at, 'member_id', p_lease.member_id,
    'member_name', coalesce((select nullif(btrim(p.display_name), '') from public.profiles p where p.id = p_lease.user_id), '')) end
$fn$;
revoke execute on function public.till_terminal_lease_shown(public.till_terminal_leases) from public, anon, authenticated;

create or replace function public.till_terminals_v1(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $fn$
begin
  perform public.command_actor(p_workspace_id, 'workspaceSettings', 'counterEmbeddedTerminal',
    'not allowed to see the till boards', 'till boards are off in this business');
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', d.id, 'till_id', d.till_id, 'till_name', t.name, 'device_id', d.device_id,
             'board_profile', d.board_profile, 'fingerprint', d.fingerprint, 'firmware', d.firmware,
             'status', d.status, 'claimed_at', d.claimed_at, 'approved_at', d.approved_at,
             'last_seen_at', d.last_seen_at,
             'cashier_asked', d.status = 'paired' and public.till_terminal_cashier_asked(d.id),
             'lease', public.till_terminal_lease_shown(public.till_terminal_current_lease(d.id))) order by d.claimed_at desc, d.id)
      from public.till_terminals d
      join public.counter_tills t on t.workspace_id = d.workspace_id and t.id = d.till_id
     where d.workspace_id = p_workspace_id and d.status <> 'revoked'), '[]'::jsonb);
end;
$fn$;
revoke execute on function public.till_terminals_v1(uuid) from public, anon;
grant execute on function public.till_terminals_v1(uuid) to authenticated;

create or replace function public.till_terminal_cashier_boards_v1(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $fn$
declare
  v_me uuid;
begin
  v_me := public.command_actor(p_workspace_id, 'issueInvoices', 'counterEmbeddedTerminal',
    'only who sells in this business sells on its till boards', 'till boards are off in this business');
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', d.id, 'till_id', d.till_id, 'till_name', t.name, 'device_id', d.device_id,
             'fingerprint', d.fingerprint,
             'cashier_asked', public.till_terminal_cashier_asked(d.id),
             'lease', public.till_terminal_lease_shown(l),
             'mine', l.id is not null and l.member_id = v_me) order by t.name, d.id)
      from public.till_terminals d
      join public.counter_tills t on t.workspace_id = d.workspace_id and t.id = d.till_id
      left join lateral (select * from public.till_terminal_current_lease(d.id)) l on true
     where d.workspace_id = p_workspace_id and d.status = 'paired'), '[]'::jsonb);
end;
$fn$;
revoke execute on function public.till_terminal_cashier_boards_v1(uuid) from public, anon;
grant execute on function public.till_terminal_cashier_boards_v1(uuid) to authenticated;

select public.set_deskilo_schema_version(1002);
