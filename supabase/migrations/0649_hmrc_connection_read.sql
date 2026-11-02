-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (one read function; the accounting connection list is restated whole from
-- 0595 with one added condition)
--
-- 0649 (#2470) -- the client slice of the HMRC MTD VAT submission.
--
-- 1. hmrc_connection_v1(p_workspace_id): what the VAT returns screen needs to
--    know before it offers "Submit through MTD": the workspace's UK VAT number
--    (the nine digits the connection must be bound to) and its live HMRC
--    connection, if any. Same gate as every HMRC door (hmrc_actor: owner or
--    co-owner, mtdSubmission and vatDeclarations on, a GB space), so it is
--    not readable through accountingConnectors.
-- 2. The accounting connections list no longer lists the HMRC connection: it
--    is a tax authority's service with its own doors, not a software the
--    books are kept in.

create or replace function public.hmrc_connection_v1(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  c public.accounting_connections;
  v_vrn text;
begin
  perform public.hmrc_actor(p_workspace_id);
  select public.hmrc_vrn(w.vat_id) into v_vrn from public.workspaces w where w.id = p_workspace_id;
  select * into c from public.accounting_connections x
   where x.workspace_id = p_workspace_id and x.target_id = 'hmrc_mtd' and x.revoked_at is null
   order by x.created_datetime desc limit 1;
  return jsonb_build_object(
    'vrn', v_vrn,
    'connection', case when c.id is null then null else jsonb_build_object(
      'id', c.id, 'issuer_site_id', c.issuer_site_id, 'status', c.status,
      'status_detail', c.status_detail, 'remote_tenant_id', c.remote_tenant_id,
      'display_name', c.display_name, 'connected_at', c.connected_at,
      'token_expires_at', c.token_expires_at) end);
end;
$fn$;
revoke execute on function public.hmrc_connection_v1(uuid) from public, anon;
grant execute on function public.hmrc_connection_v1(uuid) to authenticated;

-- ── anchored patch (pg_temp.anchor_replace, exactly one occurrence) ───────
create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
declare
  v_count integer;
begin
  v_count := (char_length(p_def) - char_length(replace(p_def, p_old, ''))) / greatest(char_length(p_old), 1);
  if v_count <> 1 then
    raise exception 'anchor occurs % times: %', v_count, left(p_old, 80);
  end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $migration$
declare
  v_def text;
begin
  select pg_get_functiondef('public.accounting_connections_v1(uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$from public.accounting_connections c where c.workspace_id = p_workspace_id)$a$,
    $a$from public.accounting_connections c
                     where c.workspace_id = p_workspace_id and c.target_id <> 'hmrc_mtd')$a$);
  execute v_def;
end
$migration$;

select public.set_deskilo_schema_version(649);
