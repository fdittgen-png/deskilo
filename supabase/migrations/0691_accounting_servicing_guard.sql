-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (accounting_connections_v1, accounting_transfers_v1, revoke_accounting_connection_v1
-- and record_accounting_delivery patched at asserted anchors; the one-argument
-- accounting_connection_manageable_v1 is replaced by a two-argument one whose
-- second argument defaults, so its callers keep working)
--
-- #3336 (slice 1) -- admission of NEW accounting work is split from reading,
-- managing and revoking what already exists.
--
-- Until now one check, the accountingConnectors feature, sat inside
-- accounting_connector_actor and so refused reading the connections,
-- revoking them and recording the outcome of a delivery already admitted, as
-- well as opening a connection or preparing a delivery. Switching the feature
-- off therefore stranded the history and made offboarding impossible.
--
-- The state is DERIVED, not stored: the feature on is `active`; the feature
-- off is `servicing` (new work refused, history, revocation and the late
-- outcome of admitted work allowed). Retire/reopen come with the lifecycle
-- slice. Authority is untouched: every door still requires a signed-in
-- native-token active member with the right permission.
--
--  * accounting_connector_member -- the actor check WITHOUT the feature.
--  * list/transfers (read) and revoke use it.
--  * the manageable door takes a purpose: 'work' (default) keeps the feature,
--    'revoke' (the Edge revocation's preliminary check) does not.
--  * record_accounting_delivery admits only a NEW delivery on the feature; an
--    outcome on an existing delivery records whatever the feature says. The
--    check sits right after the identity lookup, before the relink of a
--    revoked connection's delivery, which is new work too.
-- accounting_connector_actor, set_accounting_credentials and every other
-- caller keep today's behaviour (the refusal text and 0A000 are unchanged).

create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
declare
  v_pattern text;
  v_out text;
begin
  if position(p_old in p_def) > 0 then
    return replace(p_def, p_old, p_new);
  end if;
  v_pattern := regexp_replace(btrim(p_old, E' \t\n'), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
  v_pattern := regexp_replace(v_pattern, '\s+', '\\s*', 'g');
  v_out := regexp_replace(p_def, v_pattern, replace(btrim(p_new, E' \t\n'), '\', '\\'), 'g');
  return case when v_out = p_def then null else v_out end;
end
$f$;

revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

-- Re-appliable: a definition that already carries the new text is left alone.
create or replace function pg_temp.patch(p_def text, p_old text, p_new text, p_done text)
returns text language plpgsql as $f$
begin
  if position(p_done in p_def) > 0 then return p_def; end if;
  return pg_temp.anchor_replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.patch(text, text, text, text) from public;

-- ── the actor check without the feature ──────────────────────────────────
create or replace function public.accounting_connector_member(p_workspace_id uuid, p_permission text)
returns uuid language plpgsql stable security definer set search_path = public as $fn$
declare
  v_me uuid;
begin
  if auth.uid() is null then raise exception 'not signed in' using errcode = '42501'; end if;
  if public.mcp_is_delegated() then
    raise exception 'an assistant may not do this for the books' using errcode = '42501';
  end if;
  select m.id into v_me from public.members m
   where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active';
  if v_me is null then raise exception 'not an active member' using errcode = '42501'; end if;
  if p_permission = 'read' then
    if not public.accounting_reader(p_workspace_id) then
      raise exception 'you may not read the accounting transfers' using errcode = '42501';
    end if;
  elsif not public.has_permission(p_workspace_id, p_permission) then
    raise exception 'you may not do this for the books' using errcode = '42501';
  end if;
  return v_me;
end;
$fn$;
revoke execute on function public.accounting_connector_member(uuid, text) from public, anon, authenticated;

do $migration$
declare
  v_def text;
begin
  -- reading the connections and the transfers is not new work
  select pg_get_functiondef('public.accounting_connections_v1(uuid)'::regprocedure) into v_def;
  v_def := pg_temp.patch(v_def,
    $a$perform public.accounting_connector_actor(p_workspace_id, 'read');$a$,
    $a$perform public.accounting_connector_member(p_workspace_id, 'read');$a$,
    $a$accounting_connector_member(p_workspace_id, 'read')$a$);
  if v_def is null then raise exception '0691: accounting_connections_v1 anchor missing'; end if;
  execute v_def;

  select pg_get_functiondef('public.accounting_transfers_v1(uuid,date,date)'::regprocedure) into v_def;
  v_def := pg_temp.patch(v_def,
    $a$perform public.accounting_connector_actor(p_workspace_id, 'read');$a$,
    $a$perform public.accounting_connector_member(p_workspace_id, 'read');$a$,
    $a$accounting_connector_member(p_workspace_id, 'read')$a$);
  if v_def is null then raise exception '0691: accounting_transfers_v1 anchor missing'; end if;
  execute v_def;

  -- revoking a connection is offboarding, never new work
  select pg_get_functiondef('public.revoke_accounting_connection_v1(uuid)'::regprocedure) into v_def;
  v_def := pg_temp.patch(v_def,
    $a$perform public.accounting_connector_actor(c.workspace_id, 'manageBilling');$a$,
    $a$perform public.accounting_connector_member(c.workspace_id, 'manageBilling');$a$,
    $a$accounting_connector_member(c.workspace_id, 'manageBilling')$a$);
  if v_def is null then raise exception '0691: revoke_accounting_connection_v1 anchor missing'; end if;
  execute v_def;

  -- an outcome on a delivery that exists is recorded whatever the feature
  -- says; only creating a delivery is new work
  select pg_get_functiondef(
    'public.record_accounting_delivery(uuid, text, uuid, date, text, date, date, text, text, jsonb, text, integer)'::regprocedure
  ) into v_def;
  v_def := pg_temp.patch(v_def,
    $a$if not public.feature_effective(c.workspace_id, 'accountingConnectors') then
    raise exception 'accounting connections are switched off in this space' using errcode = '0A000';
  end if;
  if p_status not in$a$,
    $a$if p_status not in$a$,
    $a$if d.id is null and not public.feature_effective$a$);
  if v_def is null then raise exception '0691: record_accounting_delivery early-guard anchor missing'; end if;
  v_def := pg_temp.patch(v_def,
    $a$where workspace_id = c.workspace_id and identity_key = v_identity for update;
  if d.id is null and c.remote_tenant_id <> '' then$a$,
    $a$where workspace_id = c.workspace_id and identity_key = v_identity for update;
  if d.id is null and not public.feature_effective(c.workspace_id, 'accountingConnectors') then
    raise exception 'accounting connections are switched off in this space' using errcode = '0A000';
  end if;
  if d.id is null and c.remote_tenant_id <> '' then$a$,
    $a$if d.id is null and not public.feature_effective$a$);
  if v_def is null then raise exception '0691: record_accounting_delivery admission anchor missing'; end if;
  execute v_def;
end
$migration$;

-- ── the manageable door takes a purpose ──────────────────────────────────
-- 'work' (the default, every existing caller) keeps the feature; 'revoke' is
-- the Edge revocation's preliminary check and does not. The one-argument
-- signature is dropped first, or a one-argument call would match both.
do $migration$
declare
  v_def text;
begin
  if to_regprocedure('public.accounting_connection_manageable_v1(uuid)') is null then
    return; -- already given its purpose
  end if;
  select pg_get_functiondef('public.accounting_connection_manageable_v1(uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$accounting_connection_manageable_v1(p_connection_id uuid)$a$,
    $a$accounting_connection_manageable_v1(p_connection_id uuid, p_purpose text DEFAULT 'work'::text)$a$);
  if v_def is null then raise exception '0691: manageable signature anchor missing'; end if;
  v_def := pg_temp.anchor_replace(v_def,
    $a$perform public.accounting_connector_actor(c.workspace_id, 'manageBilling');$a$,
    $a$if coalesce(p_purpose, 'work') = 'revoke' then
    perform public.accounting_connector_member(c.workspace_id, 'manageBilling');
  else
    perform public.accounting_connector_actor(c.workspace_id, 'manageBilling');
  end if;$a$);
  if v_def is null then raise exception '0691: manageable actor anchor missing'; end if;
  drop function public.accounting_connection_manageable_v1(uuid);
  execute v_def;
end
$migration$;
revoke execute on function public.accounting_connection_manageable_v1(uuid, text) from public, anon;
grant execute on function public.accounting_connection_manageable_v1(uuid, text) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(691);
