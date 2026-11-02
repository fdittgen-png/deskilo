-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (one read function restated whole; it is 0649's own and has one definition)
--
-- 0651 (#2470) -- the VAT returns screen keeps "awaiting your check at HMRC".
--
-- A submission whose outcome is unknown stays `unconfirmed` in
-- hmrc_submissions (the claim was released without a receipt). The screen
-- must keep "Submit" off for that return after a reload or on another device
-- until the person says they checked at HMRC, so hmrc_connection_v1 now also
-- returns the ids of this workspace's unconfirmed returns -- ids only, no
-- receipt or figure. Same gate as before (hmrc_actor).

create or replace function public.hmrc_connection_v1(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  c public.accounting_connections;
  v_vrn text;
  v_unconfirmed jsonb;
begin
  perform public.hmrc_actor(p_workspace_id);
  select public.hmrc_vrn(w.vat_id) into v_vrn from public.workspaces w where w.id = p_workspace_id;
  select * into c from public.accounting_connections x
   where x.workspace_id = p_workspace_id and x.target_id = 'hmrc_mtd' and x.revoked_at is null
   order by x.created_datetime desc limit 1;
  select coalesce(jsonb_agg(s.declaration_id order by s.declaration_id), '[]'::jsonb) into v_unconfirmed
    from public.hmrc_submissions s
   where s.workspace_id = p_workspace_id and s.state = 'unconfirmed';
  return jsonb_build_object(
    'vrn', v_vrn,
    'unconfirmed_declaration_ids', v_unconfirmed,
    'connection', case when c.id is null then null else jsonb_build_object(
      'id', c.id, 'issuer_site_id', c.issuer_site_id, 'status', c.status,
      'status_detail', c.status_detail, 'remote_tenant_id', c.remote_tenant_id,
      'display_name', c.display_name, 'connected_at', c.connected_at,
      'token_expires_at', c.token_expires_at) end);
end;
$fn$;
revoke execute on function public.hmrc_connection_v1(uuid) from public, anon;
grant execute on function public.hmrc_connection_v1(uuid) to authenticated;

select public.set_deskilo_schema_version(651);
