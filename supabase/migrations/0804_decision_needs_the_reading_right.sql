-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (member_has_permission, event_type_restriction_holds, event_readable and
--  mcp_target are restated whole; respond_to_event is patched at one asserted
--  anchor of its live definition; member_permission_raw, may_validate_by, event_type_restriction
--  and event_readable_by are new)
--
-- #4146 -- a decision on an event needs the right to read it
-- (GHSA-f33x-v5jc-fvp4), for every event type and through every door: the
-- app, the assistant and the admission desk all decide through
-- respond_to_event.
--   * respond_to_event refuses (DKN01) a caller to whom the events' reading
--     rule would not show the event; the owner always decides. Under the
--     rules "listed validators" and "the members decide", the validator's
--     rule is itself a way to read, so those keep deciding as they do.
--   * The pool of eligible validators and the number of validations
--     required are unchanged (#840); a quorum that can no longer be reached
--     ends by the sweep, as before.
--   * The reading rule is one rule for the caller and for any member:
--     event_readable_by(member, ...) holds it, event_readable(...) asks it
--     for the caller's member; a validator's rule names a member through
--     member_validator_types (0803), for the types that can wait for a
--     decision.
--     A member's rights come from member_permission_raw, has_permission_raw's
--     body keyed by member, so member_has_permission now answers as
--     has_permission does; no client asks another member's rights.
--   * The types with a restrictive rule of their own are listed once
--     (event_type_restriction).
--   * The assistant's target of a validation it answers is given only for an
--     event the caller may read.

-- ── a member's rights, as has_permission answers them ────────────────────
-- has_permission_raw's body (the live definition), keyed by member instead
-- of the caller. pgTAP 457 compares the two live bodies line for line once
-- the keyed lines are put back, and their answers for every right and every
-- state of a member.
create or replace function public.member_permission_raw(p_member_id uuid, perm text)
returns boolean language sql stable security definer set search_path to 'public' as $function$

  select exists (
    select 1 from public.members m join public.workspaces w on w.id = m.workspace_id
     where m.id = p_member_id and m.status = 'active'
       and public.feature_effective_in(w.feature_flags, 'customRoles')
       and perm = any(public.member_custom_permissions(m.id)))
  or exists (
    select 1 from public.members m join public.workspaces w on w.id = m.workspace_id
    where m.id = p_member_id and m.status = 'active'
      and ( m.is_owner
        or (m.co_owner = 'active' and (case when w.role_permissions ? 'co_owner' then w.role_permissions->'co_owner' ? perm else true end))
        or (m.is_admin and (
             (case when w.role_permissions ? 'admin' then w.role_permissions->'admin' ? perm
                   else perm in ('manageMembers','manageDocuments','manageServices','approveExpenses',
                                 'viewFinances','viewNegotiations','manageNegotiations','paymentTermsEdit',
                                 'manageSites','manageReservations','operateKiosk','exportData','viewPersonalData',
                                 'deployToDev','accessProd','viewAnalytics') end)
             or (perm = 'issueInvoices' and public.feature_effective_in(w.feature_flags, 'adminInvoicing'))))
        or (not m.is_admin and not m.is_owner and m.co_owner <> 'active' and w.role_permissions ? 'member' and w.role_permissions->'member' ? perm)));

$function$;
revoke execute on function public.member_permission_raw(uuid, text) from public, anon, authenticated;
grant execute on function public.member_permission_raw(uuid, text) to service_role;

-- Another member's rights are the server's to ask (its functions and the
-- service role), never a client's.
create or replace function public.member_has_permission(p_member_id uuid, perm text)
returns boolean language sql stable security definer set search_path to 'public' as $function$
  select public.member_permission_raw(p_member_id, perm)
      or (perm = 'deployToDev' and public.member_permission_raw(p_member_id, 'deployToProd'));
$function$;
revoke execute on function public.member_has_permission(uuid, text) from public, anon, authenticated;
grant execute on function public.member_has_permission(uuid, text) to service_role;

-- ── the types with a restrictive rule of their own, listed once ─────────
create or replace function public.event_type_restriction(p_type text)
returns text language sql immutable as $fn$
  select case p_type
    when 'privacy_incident' then 'managePrivacy'
    when 'payment_attempt_unreadable' then 'viewFinances'
  end;
$fn$;
revoke execute on function public.event_type_restriction(text) from public, anon;
grant execute on function public.event_type_restriction(text) to authenticated;

-- Restated whole from 0802 over the one list; still inlined into the events
-- table's policy (no search_path, every name qualified).
create or replace function public.event_type_restriction_holds(p_workspace_id uuid, p_type text)
returns boolean language sql stable as $fn$
  select public.event_type_restriction(p_type) is null
      or public.has_permission(p_workspace_id, public.event_type_restriction(p_type));
$fn$;
revoke execute on function public.event_type_restriction_holds(uuid, text) from public, anon;
grant execute on function public.event_type_restriction_holds(uuid, text) to authenticated;

-- ── a validator's rule, for a member ─────────────────────────────────────
-- Whether the rule in force for [p_type] names member [p_member_id] (0803's
-- member_validator_types, the one place a validator's rule is read).
create or replace function public.may_validate_by(p_member_id uuid, p_workspace_id uuid, p_type text)
returns boolean language sql stable security definer set search_path = public as $fn$
  select exists (select 1 from public.members m
                  where m.id = p_member_id and m.workspace_id = p_workspace_id)
     and p_type in (select public.member_validator_types(p_member_id));
$fn$;
revoke execute on function public.may_validate_by(uuid, uuid, text) from public, anon, authenticated;

-- ── the reading rule, for a member ───────────────────────────────────────
-- Whether member [p_member_id] may read an event of [p_type] in
-- [p_workspace_id] whose actor and subject are [p_actor] and [p_subject]:
-- their own event, the type's reading right, a validator's rule that names
-- them, under the type's restrictive rule. Yes or no, never unknown.
create or replace function public.event_readable_by(
  p_member_id uuid, p_workspace_id uuid, p_type text, p_actor uuid, p_subject uuid)
returns boolean language sql stable security definer set search_path = public as $fn$
  select exists (select 1 from public.members m
                  where m.id = p_member_id and m.workspace_id = p_workspace_id)
     and (public.event_type_restriction(p_type) is null
          or public.member_has_permission(p_member_id, public.event_type_restriction(p_type)))
     and (coalesce(p_member_id in (p_actor, p_subject), false)
          or exists (select 1 from unnest(public.event_type_view_permissions(p_type)) perm
                      where public.member_has_permission(p_member_id, perm))
          or public.may_validate_by(p_member_id, p_workspace_id, p_type));
$fn$;
revoke execute on function public.event_readable_by(uuid, uuid, text, uuid, uuid) from public, anon, authenticated;

-- Restated whole from 0803: the same rule, asked for the caller's member.
create or replace function public.event_readable(p_workspace_id uuid, p_type text, p_actor uuid, p_subject uuid)
returns boolean language sql stable security definer set search_path = public as $fn$
  select exists (select 1 from public.members m
                  where m.workspace_id = p_workspace_id and m.user_id = auth.uid()
                    and public.event_readable_by(m.id, p_workspace_id, p_type, p_actor, p_subject));
$fn$;
revoke execute on function public.event_readable(uuid, text, uuid, uuid) from public, anon, authenticated;

-- ── a decision needs the right to read ───────────────────────────────────
-- respond_to_event, at one asserted anchor of its live definition: 0803's
-- check for requests to join becomes the check for every type. The pool of
-- eligible validators and the number required are as they were (#840): a
-- quorum that can no longer be reached ends by the sweep.
do $patch$
declare
  v_def text := pg_get_functiondef('public.respond_to_event(uuid, boolean)'::regprocedure);
  v_join constant text := $a$  -- #4143 -- a request to join is decided by whoever may read it as its
  -- reviewer, never by being its member.
  if v_event.type = 'member_join'
     and public.event_readable(v_event.workspace_id, v_event.type, null, null) is not true then
    raise exception 'you are not an eligible validator for this event' using errcode = 'DKN01';
  end if;
$a$;
begin
  if (length(v_def) - length(replace(v_def, v_join, ''))) / length(v_join) <> 1 then
    raise exception 'respond_to_event: an anchor of its decision rule is not there exactly once' using errcode = 'P0001';
  end if;
  v_def := replace(v_def, v_join, $a$  -- #4146 -- a decision needs the right to read the event; the owner always
  -- decides. A request to join is read as its reviewer, never by being its
  -- member (#4143).
  if not v_caller.is_owner
     and public.event_readable_by(v_caller.id, v_event.workspace_id, v_event.type,
           case when v_event.type = 'member_join' then null else v_event.actor_member_id end,
           case when v_event.type = 'member_join' then null else v_event.subject_member_id end) is not true then
    raise exception 'you are not an eligible validator for this event' using errcode = 'DKN01';
  end if;
$a$);
  execute v_def;
end;
$patch$;

-- ── the assistant's target of a validation ───────────────────────────────
-- Restated whole from the live definition: the target is given only for an
-- event the caller may read, the same answer as for one not found.
CREATE OR REPLACE FUNCTION public.mcp_target(p_workspace_id uuid, p_operation text, p_args jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_invoice public.invoices;
  v_member public.members;
  v_event public.events;
  v_name text;
begin
  -- #1623 — nor a percentage or a status the workflow would refuse.
  if p_operation = 'request_subscription_change'
     and (coalesce(p_args->>'pct', '') !~ '^\d{1,3}$'
          or (p_args->>'pct')::integer not between 0 and 100) then
    raise exception using errcode = '22023', message = 'pct';
  end if;
  if p_operation = 'request_member_status_change'
     and coalesce(p_args->>'status', '') not in ('active', 'paused', 'exited') then
    raise exception using errcode = '22023', message = 'status';
  end if;
  -- #1624 — a decision is yes or no, never something to guess at.
  if p_operation = 'respond_to_validation'
     and coalesce(p_args->>'accept', '') not in ('true', 'false') then
    raise exception using errcode = '22023', message = 'accept';
  end if;
  -- #1622 — a request a person could never approve is not put to them.
  if p_operation = 'request_invoice_issue'
     and coalesce(p_args->>'period', '') !~ '^\d{4}-(0[1-9]|1[0-2])$' then
    raise exception using errcode = '22023', message = 'period';
  end if;
  if p_operation in ('request_invoice_void', 'request_refund') then
    select * into v_invoice from public.invoices
     where id = public.mcp_uuid_arg(p_args, 'invoice_id') and workspace_id = p_workspace_id;
    if v_invoice.id is null then return null; end if;
    return jsonb_build_object('kind', 'invoice', 'id', v_invoice.id, 'number', v_invoice.number,
      'total_cents', v_invoice.total_cents, 'currency', v_invoice.currency, 'period', v_invoice.period,
      'revision', md5(to_jsonb(v_invoice)::text));
  elsif p_operation in ('request_invoice_issue', 'request_member_status_change', 'request_subscription_change') then
    select * into v_member from public.members
     where id = public.mcp_uuid_arg(p_args, 'member_id') and workspace_id = p_workspace_id;
    if v_member.id is null then return null; end if;
    select coalesce(nullif(v_member.managed_name, ''), p.display_name, '') into v_name
      from (select 1) x left join public.profiles p on p.id = v_member.user_id;
    return jsonb_build_object('kind', 'member', 'id', v_member.id, 'name', v_name,
      'status', v_member.status, 'subscription_pct', v_member.subscription_pct,
      'revision', md5(to_jsonb(v_member)::text));
  elsif p_operation = 'respond_to_validation' then
    select * into v_event from public.events
     where id = public.mcp_uuid_arg(p_args, 'event_id') and workspace_id = p_workspace_id;
    -- #4146 -- an event the caller may not read is answered as one not found.
    if v_event.id is null
       or public.event_readable(v_event.workspace_id, v_event.type,
                                v_event.actor_member_id, v_event.subject_member_id) is not true then
      return null;
    end if;
    return jsonb_build_object('kind', 'event', 'id', v_event.id, 'type', v_event.type,
      'status', v_event.status, 'revision', md5(to_jsonb(v_event)::text));
  end if;
  return null;
end;
$function$;
revoke execute on function public.mcp_target(uuid, text, jsonb) from public, anon, authenticated;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(804);
