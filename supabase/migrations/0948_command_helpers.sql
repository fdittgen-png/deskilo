-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
-- (three new internal functions; no table, no existing function and no stored figure moves)
--
-- #4399 -- a new command starts with two calls instead of the copies each command carried.
--
--   * `command_actor(workspace, permission, feature, refusal, off_refusal, off_code)` answers the member who acts, or
--     refuses as every `*_actor` helper does: no signed-in user, or a delegated assistant session, or no active member
--     of the business, or without the permission -> DKN01 with the caller's own words; the feature off -> the
--     caller's own words under `off_code` (DKN01 unless the domain names its own, as the stock commands do with DKG01).
--     Nine helpers were created in one week with a text similarity of 0.84 to 0.97 (`stock_config_actor` 0836,
--     `stock_ops_actor` 0847, ...): each becomes a one-line call of this one as its function is next touched.
--   * `request_begin(workspace, request, operation, digest)` takes the advisory lock of the request and answers the
--     result stored for it, or null when the request is new; a request id already used for another operation or
--     another digest is refused (DKG07). `request_finish(...)` stores the result and answers it. They use the request
--     store the stock and purchase commands already use (`purchase_requests`) under the lock key they use, so an old
--     command and a new one on the same request id serialise against each other. The caller adds its own `replayed`
--     marker where its answer has one.
--
-- A lint from this migration on (`test/lint/command_boilerplate_test.dart`) refuses a new function that carries the
-- inline prelude or the inline idempotency block.

create or replace function public.command_actor(
  p_workspace_id uuid,
  p_permission text,
  p_feature text default null,
  p_refusal text default 'not allowed',
  p_off_refusal text default 'the feature is off',
  p_off_code text default 'DKN01'
) returns uuid language plpgsql stable security definer set search_path = public as $fn$
declare
  v_me uuid;
begin
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception '%', p_refusal using errcode = 'DKN01';
  end if;
  select id into v_me from public.members
   where workspace_id = p_workspace_id and user_id = auth.uid() and status = 'active';
  if v_me is null or not public.has_permission(p_workspace_id, p_permission) then
    raise exception '%', p_refusal using errcode = 'DKN01';
  end if;
  if p_feature is not null and not public.feature_effective(p_workspace_id, p_feature) then
    raise exception '%', p_off_refusal using errcode = p_off_code;
  end if;
  return v_me;
end;
$fn$;
revoke execute on function public.command_actor(uuid, text, text, text, text, text) from public, anon, authenticated;

create or replace function public.request_begin(
  p_workspace_id uuid, p_request_id uuid, p_operation text, p_digest text
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_done public.purchase_requests;
begin
  if p_workspace_id is null or p_request_id is null or coalesce(p_operation, '') = '' or coalesce(p_digest, '') = '' then
    raise exception 'a command names its business, its request id, its operation and its digest' using errcode = 'DKG07';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('purchase_request:' || p_workspace_id::text || p_request_id::text, 0));
  select * into v_done from public.purchase_requests
   where workspace_id = p_workspace_id and request_id = p_request_id;
  if v_done.id is null then
    return null;
  end if;
  if v_done.operation <> p_operation or v_done.digest <> p_digest then
    raise exception 'this request id was already used for a different request' using errcode = 'DKG07';
  end if;
  return v_done.result;
end;
$fn$;
revoke execute on function public.request_begin(uuid, uuid, text, text) from public, anon, authenticated;

create or replace function public.request_finish(
  p_workspace_id uuid, p_request_id uuid, p_operation text, p_digest text, p_result jsonb
) returns jsonb language plpgsql security definer set search_path = public as $fn$
begin
  insert into public.purchase_requests (workspace_id, request_id, operation, digest, result)
  values (p_workspace_id, p_request_id, p_operation, p_digest, p_result);
  return p_result;
end;
$fn$;
revoke execute on function public.request_finish(uuid, uuid, text, text, jsonb) from public, anon, authenticated;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(948);
