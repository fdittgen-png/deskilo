-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (set_accounting_token_v1 restated whole from 0595 with one condition)
--
-- 9999 (#2370, the number is taken at push time) -- a routine token
-- rotation keeps the connection. Once a connection had delivered, any new
-- token was refused (DKA02) and the manager had to revoke and connect
-- again, which starts with no mappings: every expiring API token meant
-- mapping everything again. Now a new token for the company the
-- connection recorded (remote_tenant_id, non-empty and the same) replaces
-- the old one; the connection, its maps and its deliveries stay. Without a
-- recorded company, or for another one, it is still refused: another
-- company is a new connection.

create or replace function public.set_accounting_token_v1(
  p_connection_id uuid, p_token text, p_remote_tenant_id text
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  c public.accounting_connections;
  v_me uuid;
begin
  select * into c from public.accounting_connections where id = p_connection_id for update;
  if c.id is null then raise exception 'unknown connection' using errcode = 'P0002'; end if;
  v_me := public.accounting_connector_actor(c.workspace_id, 'manageBilling');
  if c.revoked_at is not null then raise exception 'this connection was revoked' using errcode = 'DKA02'; end if;
  if c.auth_kind <> 'token' then
    raise exception 'this target is connected by signing in to it, not by a token' using errcode = 'DKA03';
  end if;
  -- The company of a token is the one the manager named: once the
  -- connection delivered, a token for another company could reach it under
  -- the same label. Only a token for the recorded company replaces it
  -- (#2370); another one is revoked and connected again, which finds its
  -- deliveries again when the company is the same.
  if exists (select 1 from public.accounting_deliveries d where d.connection_id = c.id)
     and (btrim(coalesce(c.remote_tenant_id, '')) = ''
          or btrim(coalesce(p_remote_tenant_id, '')) <> btrim(c.remote_tenant_id)) then
    raise exception 'this connection has delivered: revoke it and connect again' using errcode = 'DKA02';
  end if;
  if char_length(btrim(coalesce(p_token, ''))) not between 8 and 4000 then
    raise exception 'paste the whole token' using errcode = 'DKA03';
  end if;
  perform public.accounting_store_secret(c.id, 'access_token', btrim(p_token));
  update public.accounting_connections
     set status = 'connected', status_detail = '', connected_at = now(), connected_by_member_id = v_me,
         remote_tenant_id = coalesce(nullif(btrim(coalesce(p_remote_tenant_id, '')), ''), c.remote_tenant_id)
   where id = c.id
  returning * into c;
  return public.accounting_connection_json(c);
end;
$fn$;
revoke execute on function public.set_accounting_token_v1(uuid, text, text) from public, anon;
grant execute on function public.set_accounting_token_v1(uuid, text, text) to authenticated;

select public.set_deskilo_schema_version(9999);
