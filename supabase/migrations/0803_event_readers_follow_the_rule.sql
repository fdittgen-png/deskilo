-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (may_validate_event_type, event_readable, mcp_read_v1 and
--  can_discuss_workspace_application are restated whole; export_my_data, respond_to_event and
--  my_workspace_applications are patched at asserted anchors of their live
--  definitions; effective_validation_policy is new)
--
-- #4143 -- the assistant's validation reads, the personal export and the
-- admission desk follow each event type's reading rule (event_readable and
-- event_type_restriction_holds, 0802), and a validator's rule is read as the
-- decision reads it:
--   * the validation rule in force for a type is the type's own rule, else
--     the business's general rule (effective_validation_policy) -- the one
--     respond_to_event decides by, and the one may_validate_event_type now
--     asks. A rule names its validators in the scopes 'members' and
--     'listed', and, in the scope 'admins', the administrators it lists;
--   * the assistant's list of pending validations and its read of one show
--     the caller's own requests under each type's restrictive rule, and,
--     wide, the events the caller may read;
--   * a member's own export carries their own events as the events table
--     shows them: each type's restrictive rule applies (the notices of
--     payments not checked stay out of it, 0802);
--   * an application to join is read, discussed and decided by whoever may
--     read it as its reviewer: the right to manage the members, or a
--     validation rule that names them; the applicant (the account that
--     applied) reads and discusses their own, and the account that decided
--     it can continue that thread.

-- ── the validation rule in force ─────────────────────────────────────────
-- [p_type]'s own rule in [p_workspace_id], else the general one (none when
-- the business has neither: respond_to_event then takes the defaults). Plain
-- SQL, every name qualified, so the functions that ask it inline it.
create or replace function public.effective_validation_policy(p_workspace_id uuid, p_type text)
returns setof public.validation_policies language sql stable as $fn$
  select vp.* from public.validation_policies vp
   where vp.workspace_id = p_workspace_id and (vp.event_type = p_type or vp.event_type is null)
   order by vp.event_type is null, vp.id
   limit 1;
$fn$;
revoke execute on function public.effective_validation_policy(uuid, text) from public, anon, authenticated;

-- Whether the rule in force for [p_type] names the caller as a validator.
create or replace function public.may_validate_event_type(p_workspace_id uuid, p_type text)
returns boolean language sql stable security definer set search_path to 'public' as $function$
  select exists (
    select 1
      from public.effective_validation_policy(p_workspace_id, p_type) vp
      join public.members m
        on m.workspace_id = vp.workspace_id and m.user_id = auth.uid() and m.status = 'active'
     where vp.validator_scope = 'members'
        or (vp.validator_scope = 'listed' and m.id = any(vp.eligible_admin_ids))
        or (vp.validator_scope = 'admins' and cardinality(vp.eligible_admin_ids) > 0
            and m.is_admin and vp.admins_may_validate and m.id = any(vp.eligible_admin_ids)));
$function$;
revoke execute on function public.may_validate_event_type(uuid, text) from public, anon;
grant execute on function public.may_validate_event_type(uuid, text) to authenticated;

-- Whether the caller may read an event of [p_type] in [p_workspace_id] whose
-- actor and subject are [p_actor] and [p_subject]. Restated whole from 0802
-- with the same rule, asked per type: the type's reading right (any of
-- event_type_view_permissions, as event_types_in_view grants it through
-- has_permission), their own event, a validator's rule (the rule in force),
-- and the type's restrictive rule -- without building every type's view of
-- every business for each event asked.
create or replace function public.event_readable(p_workspace_id uuid, p_type text, p_actor uuid, p_subject uuid)
returns boolean language sql stable security definer set search_path = public as $fn$
  select public.event_type_restriction_holds(p_workspace_id, p_type)
     and (exists (select 1 from unnest(public.event_type_view_permissions(p_type)) perm
                   where public.has_permission(p_workspace_id, perm))
          or exists (select 1 from public.members m
                      where m.user_id = auth.uid() and m.id in (p_actor, p_subject))
          or public.may_validate_event_type(p_workspace_id, p_type));
$fn$;
revoke execute on function public.event_readable(uuid, text, uuid, uuid) from public, anon, authenticated;

-- ── the assistant's validation reads ─────────────────────────────────────
-- Restated whole from the live definition (0745's, as dev holds it).
CREATE OR REPLACE FUNCTION public.mcp_read_v1(p_workspace_id uuid, p_member members, p_operation text, p_args jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_readable text[];
  v_limit integer := least(greatest(coalesce((p_args->>'limit')::integer, 25), 1), 100);
  v_from timestamptz;
  v_to timestamptz;
  v_after_at timestamptz;
  v_after_id uuid;
  v_rows jsonb;
  v_count integer;
  v_last jsonb;
  v_event public.events;
  v_can boolean;
  v_reason text;
  v_level uuid;
  v_office uuid;
  v_kind text;
  v_page jsonb;
  v_more boolean;
  -- #2391 — beyond her own rows only when her consent reaches the
  -- workspace (the facade always says which; a direct definer call is the
  -- service role's).
  v_wide boolean := coalesce(p_args->>'_ceiling', 'workspace') = 'workspace';
begin
  select at, id into v_after_at, v_after_id
    from public.mcp_cursor_position(p_args->>'cursor', p_operation, p_workspace_id);

  if p_operation in ('get_availability', 'list_my_reservations') then
    v_from := public.mcp_time_arg(p_args, case when p_operation = 'get_availability' then 'starts_at' else 'from' end);
    v_to := public.mcp_time_arg(p_args, case when p_operation = 'get_availability' then 'ends_at' else 'to' end);
    if v_to <= v_from or v_to - v_from > make_interval(days => (public.setting_value(null, 'mcp.read_range_days') #>> '{}')::int) then
      return jsonb_build_object('refused', 'validation_error', 'code', 'window');
    end if;
  end if;

  if p_operation = 'list_my_reservations' then
    select coalesce(jsonb_agg(r order by (r->>'starts_at')::timestamptz, r->>'reservation_id'), '[]'::jsonb) into v_rows
      from (
        select jsonb_build_object('reservation_id', x.id, 'seat_id', x.seat_id, 'desk_id', x.desk_id,
                 'office_id', x.office_id, 'level_id', x.level_id,
                 'label', public.mcp_place_label(x.seat_id, x.desk_id, x.office_id, x.level_id),
                 'starts_at', x.starts_at, 'ends_at', x.ends_at, 'status', x.status) as r
          from public.reservations x
         where x.workspace_id = p_workspace_id and x.member_id = p_member.id
           and x.starts_at < v_to and x.ends_at > v_from
           and (v_after_at is null or (x.starts_at, x.id) > (v_after_at, v_after_id))
         order by x.starts_at, x.id
         limit v_limit + 1) q;
    v_count := jsonb_array_length(v_rows);
    if v_count > v_limit then
      v_rows := v_rows - v_limit;
      v_last := v_rows->(v_limit - 1);
      return jsonb_build_object('items', v_rows, 'next_cursor',
        public.mcp_cursor(p_operation, p_workspace_id, (v_last->>'starts_at')::timestamptz, (v_last->>'reservation_id')::uuid));
    end if;
    return jsonb_build_object('items', v_rows, 'next_cursor', null);
  end if;

  if p_operation = 'get_availability' then
    -- #2145 — optionally one level or one office; #2391 — every kind the app
    -- books (seats, and desks, offices and levels booked as a whole),
    -- optionally one kind. A page is the next place ids in order; it is
    -- shown by label, and the cursor follows the ids it paged by. "free" is
    -- the booking engine's own verdict (0345), asked only for this page.
    v_level := public.mcp_uuid_arg(p_args, 'level_id', false);
    v_office := public.mcp_uuid_arg(p_args, 'office_id', false);
    v_kind := nullif(p_args->>'kind', '');
    if v_kind is not null and v_kind not in ('seat', 'desk', 'office', 'level', 'room', 'parking') then
      raise exception using errcode = '22023', message = 'kind';
    end if;
    select coalesce(jsonb_agg(to_jsonb(q) order by q.id), '[]'::jsonb) into v_page
      from (select p.*
              from (select s.resource_kind as kind, s.id, s.id as seat_id, d.id as desk_id, o.id as office_id,
                           o.level_id, s.name
                      from public.seats s
                      join public.desks d on d.id = s.desk_id
                      join public.offices o on o.id = d.office_id
                     where s.workspace_id = p_workspace_id
                       and public.resource_kind_enabled(p_workspace_id, s.resource_kind)
                    union all
                    select 'desk', d.id, null, d.id, o.id, o.level_id, d.name
                      from public.desks d
                      join public.offices o on o.id = d.office_id
                     where d.workspace_id = p_workspace_id and d.bookable_as_whole
                    union all
                    select 'office', o.id, null, null, o.id, o.level_id, o.name
                      from public.offices o
                     where o.workspace_id = p_workspace_id and o.bookable_as_whole
                    union all
                    select 'level', l.id, null, null, null, l.id, l.name
                      from public.levels l
                     where l.workspace_id = p_workspace_id and l.bookable_as_whole) p
             where public.place_visible_to(p_member.id, p.office_id, case when p.kind = 'level' then p.level_id end)
               and (v_kind is null or p.kind = v_kind)
               and (v_level is null or p.level_id = v_level)
               and (v_office is null or p.office_id = v_office)
               and (v_after_id is null or p.id > v_after_id)
             order by p.id
             limit v_limit + 1) q;
    v_more := jsonb_array_length(v_page) > v_limit;
    if v_more then
      v_page := v_page - v_limit;
    end if;
    select coalesce(jsonb_agg(r order by r->>'label', r->>'kind', coalesce(r->>'seat_id', r->>'desk_id',
                                 r->>'office_id', r->>'level_id')), '[]'::jsonb) into v_rows
      from (
        select jsonb_build_object('kind', x.kind, 'seat_id', x.seat_id, 'desk_id', x.desk_id,
                 'office_id', x.office_id, 'level_id', x.level_id,
                 'label', public.mcp_place_label(x.seat_id,
                            case when x.kind = 'desk' then x.desk_id end,
                            case when x.kind = 'office' then x.office_id end,
                            case when x.kind = 'level' then x.level_id end),
                 'name', x.name,
                 'free', public.mcp_place_bookable(p_workspace_id, x.seat_id,
                            case when x.kind = 'desk' then x.desk_id end,
                            case when x.kind = 'office' then x.office_id end,
                            case when x.kind = 'level' then x.level_id end, v_from, v_to) is null) as r
          from jsonb_to_recordset(v_page) as x(kind text, id uuid, seat_id uuid, desk_id uuid,
                                               office_id uuid, level_id uuid, name text)) q;
    return jsonb_build_object('window', jsonb_build_object('starts_at', v_from, 'ends_at', v_to),
      'observed_at', now(), 'items', v_rows,
      'next_cursor', case when v_more then
        public.mcp_cursor(p_operation, p_workspace_id, now(),
          (v_page->(jsonb_array_length(v_page) - 1)->>'id')::uuid) end,
      'not_checked', jsonb_build_array('price', 'approval'));
  end if;

  if p_operation = 'list_my_invoices' then
    select coalesce(jsonb_agg(r order by (r->>'issued_at')::timestamptz desc, r->>'invoice_id' desc), '[]'::jsonb) into v_rows
      from (
        select jsonb_build_object('invoice_id', i.id, 'number', i.number, 'period', i.period,
                 'kind', i.kind, 'total_cents', i.total_cents, 'currency', i.currency,
                 'issued_at', i.issued_at, 'voided', i.voided_at is not null) as r
          from public.invoices i
         where i.workspace_id = p_workspace_id and i.member_id = p_member.id
           and (v_after_at is null or (i.issued_at, i.id) < (v_after_at, v_after_id))
         order by i.issued_at desc, i.id desc
         limit v_limit + 1) q;
    v_count := jsonb_array_length(v_rows);
    if v_count > v_limit then
      v_rows := v_rows - v_limit;
      v_last := v_rows->(v_limit - 1);
      return jsonb_build_object('items', v_rows, 'next_cursor',
        public.mcp_cursor(p_operation, p_workspace_id, (v_last->>'issued_at')::timestamptz, (v_last->>'invoice_id')::uuid));
    end if;
    return jsonb_build_object('items', v_rows, 'next_cursor', null);
  end if;

  if p_operation = 'list_pending_validations' then
    -- #4143 -- of the types waiting in this business, those the caller may
    -- read (event_readable), asked once per type, not per row.
    v_readable := array(select x.t from (select distinct e.type as t from public.events e
                                          where e.workspace_id = p_workspace_id and e.status = 'pending') x
                         where public.event_readable(p_workspace_id, x.t, null, null));
    -- Pending events the caller authored or is the subject of; under a
    -- workspace ceiling also the ones she may answer.
    select coalesce(jsonb_agg(r order by (r->>'requested_at')::timestamptz, r->>'event_id'), '[]'::jsonb) into v_rows
      from (
        select jsonb_build_object('event_id', e.id, 'type', e.type, 'requested_at', e.created_at,
                 'mine', e.actor_member_id = p_member.id or e.subject_member_id = p_member.id) as r
          from public.events e
         where e.workspace_id = p_workspace_id and e.status = 'pending'
           and (((e.actor_member_id = p_member.id or e.subject_member_id = p_member.id)
                 and public.event_type_restriction_holds(e.workspace_id, e.type))
                or (v_wide and e.type = any(v_readable)))
           and (v_after_at is null or (e.created_at, e.id) > (v_after_at, v_after_id))
         order by e.created_at, e.id
         limit v_limit + 1) q;
    v_count := jsonb_array_length(v_rows);
    if v_count > v_limit then
      v_rows := v_rows - v_limit;
      v_last := v_rows->(v_limit - 1);
      return jsonb_build_object('items', v_rows, 'next_cursor',
        public.mcp_cursor(p_operation, p_workspace_id, (v_last->>'requested_at')::timestamptz, (v_last->>'event_id')::uuid));
    end if;
    return jsonb_build_object('items', v_rows, 'next_cursor', null);
  end if;

  if p_operation = 'get_validation' then
    select * into v_event from public.events
     where id = public.mcp_uuid_arg(p_args, 'event_id') and workspace_id = p_workspace_id;
    if v_event.id is null
       or not (((v_event.actor_member_id = p_member.id or v_event.subject_member_id = p_member.id)
                and public.event_type_restriction_holds(v_event.workspace_id, v_event.type))
               or (v_wide and public.event_readable(v_event.workspace_id, v_event.type,
                                                    v_event.actor_member_id, v_event.subject_member_id))) then
      return jsonb_build_object('refused', 'not_found', 'code', 'not_found');
    end if;
    v_can := false;
    if v_event.status = 'pending' then
      begin
        perform public.respond_to_event(v_event.id, true);
        raise exception using errcode = 'P0002', message = 'mcp preview';
      exception
        when no_data_found then
          v_can := sqlerrm = 'mcp preview';
        when raise_exception
      -- #3810: a booking refusal carries its DKK code (0739).
      or sqlstate 'DKK01' or sqlstate 'DKK02' or sqlstate 'DKK03' or sqlstate 'DKK04' or sqlstate 'DKK05' or sqlstate 'DKK06' or sqlstate 'DKK07' or sqlstate 'DKK08' or sqlstate 'DKK09' or sqlstate 'DKK10' or sqlstate 'DKK11' or sqlstate 'DKK12' or sqlstate 'DKK13' or sqlstate 'DKK15' or sqlstate 'DKK16' or sqlstate 'DKK17' or sqlstate 'DKK18' or sqlstate 'DKK19' or sqlstate 'DKK20' or sqlstate 'DKK21' or sqlstate 'DKK22' or sqlstate 'DKK23' or sqlstate 'DKK25' or sqlstate 'DKK26' or sqlstate 'DKK27' or sqlstate 'DKK28' or sqlstate 'DKK29' or sqlstate 'DKK30' or sqlstate 'DKK31' or sqlstate 'DKK32' or sqlstate 'DKK33' or sqlstate 'DKK34' or sqlstate 'DKK35' or sqlstate 'DKK36'
      -- #3811: an invoicing refusal carries its code (0742).
      or sqlstate 'DKI01' or sqlstate 'DKI03' or sqlstate 'DKI04' or sqlstate 'DKI05' or sqlstate 'DKI06' or sqlstate 'DKI07' or sqlstate 'DKD01'
      -- #3821: a permission refusal carries its code (0745).
      or sqlstate 'DKN01' then
          v_reason := left(sqlerrm, 120);
        when others then
          v_reason := 'unavailable';
      end;
    end if;
    return jsonb_build_object(
      'event_id', v_event.id, 'type', v_event.type, 'status', v_event.status,
      'requested_at', v_event.created_at,
      'decisions', (select count(*) from public.event_decisions d where d.event_id = v_event.id),
      'can_respond', v_can, 'reason', v_reason);
  end if;

  if p_operation = 'list_my_favorites' then
    return public.mcp_favorites_v1(p_workspace_id);
  end if;
  if p_operation = 'get_place' then
    return public.mcp_place_v1(p_workspace_id, p_member, p_args);
  end if;

  return jsonb_build_object('refused', 'validation_error', 'code', 'unknown_operation');
end;
$function$;
revoke execute on function public.mcp_read_v1(uuid, public.members, text, jsonb) from public, anon, authenticated;

-- ── the personal export ──────────────────────────────────────────────────
-- Each type's restrictive rule applies to the member's own events. The
-- exclusion of the notices of payments not checked (0802) stays beside it:
-- the owner holds viewFinances and is each notice's actor and subject, so the
-- restrictive rule alone would put every notice into the owner's own export,
-- and the notices name other members' payments.
do $patch$
declare
  v_def text := pg_get_functiondef('public.export_my_data(uuid)'::regprocedure);
  v_old constant text := $a$                  and e.type <> 'payment_attempt_unreadable'),$a$;
begin
  if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then
    raise exception 'export_my_data: the anchor of its events is not there exactly once' using errcode = 'P0001';
  end if;
  execute replace(v_def, v_old, $a$                  and e.type <> 'payment_attempt_unreadable'
                  and public.event_type_restriction_holds(e.workspace_id, e.type)),$a$);
end;
$patch$;

-- ── deciding: the rule in force, and requests to join ────────────────────
-- respond_to_event, at two asserted anchors: the rule it decides by comes
-- from effective_validation_policy; a request to join is decided by whoever
-- may read it as its reviewer.
do $patch$
declare
  v_def text := pg_get_functiondef('public.respond_to_event(uuid, boolean)'::regprocedure);
  v_policy constant text := $a$  select * into v_policy from public.validation_policies
    where workspace_id = v_event.workspace_id and event_type = v_event.type;
  if v_policy is null then
    select * into v_policy from public.validation_policies
      where workspace_id = v_event.workspace_id and event_type is null;
  end if;$a$;
  v_decisions constant text := $a$  if exists (select 1 from public.event_decisions d$a$;
begin
  if (length(v_def) - length(replace(v_def, v_policy, ''))) / length(v_policy) <> 1
     or (length(v_def) - length(replace(v_def, v_decisions, ''))) / length(v_decisions) <> 1 then
    raise exception 'respond_to_event: an anchor of its rule is not there exactly once' using errcode = 'P0001';
  end if;
  v_def := replace(v_def, v_policy,
    $a$  select * into v_policy from public.effective_validation_policy(v_event.workspace_id, v_event.type);$a$);
  v_def := replace(v_def, v_decisions, $a$  -- #4143 -- a request to join is decided by whoever may read it as its
  -- reviewer, never by being its member.
  if v_event.type = 'member_join'
     and public.event_readable(v_event.workspace_id, v_event.type, null, null) is not true then
    raise exception 'you are not an eligible validator for this event' using errcode = 'DKN01';
  end if;
$a$ || v_decisions);
  execute v_def;
end;
$patch$;

-- ── the admission desk ───────────────────────────────────────────────────
-- Reading and discussing an application: its applicant (the account that
-- applied, not whoever holds the member row later), the account that decided
-- it, or whoever may read the request as its reviewer -- by the type's right
-- or a validator rule, never by being its member. The cheap ways first.
create or replace function public.can_discuss_workspace_application(p_event_id uuid)
returns boolean language sql stable security definer set search_path to 'public' as $function$
  select auth.uid() is not null and not public.mcp_is_delegated() and exists (
    select 1 from public.events e join public.workspace_applications applicant on applicant.event_id=e.id
    where e.id=p_event_id and e.type='member_join' and (
      case when applicant.applicant_user_id = auth.uid() then true
           when exists (select 1 from public.workspace_application_messages message
                         where message.event_id=e.id and message.author_user_id=auth.uid()
                           and message.kind in ('accepted','refused')) then true
           else coalesce(public.event_readable(e.workspace_id, e.type, null, null), false)
      end
    ));
$function$;
revoke execute on function public.can_discuss_workspace_application(uuid) from public, anon;
grant execute on function public.can_discuss_workspace_application(uuid) to authenticated;

-- The caller's applications: only those they applied for, decided, or that
-- wait in a business they are an active member of, before the question.
do $patch$
declare
  v_def text := pg_get_functiondef('public.my_workspace_applications(timestamptz, uuid)'::regprocedure);
  v_old constant text := $a$    where e.type='member_join' and public.can_discuss_workspace_application(e.id)$a$;
begin
  if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then
    raise exception 'my_workspace_applications: the anchor of its rows is not there exactly once' using errcode = 'P0001';
  end if;
  execute replace(v_def, v_old, $a$    where e.type='member_join'
      and (application.applicant_user_id=auth.uid()
           or e.workspace_id in (select mm.workspace_id from public.members mm
                                  where mm.user_id=auth.uid() and mm.status='active')
           or exists (select 1 from public.workspace_application_messages decided
                       where decided.event_id=e.id and decided.author_user_id=auth.uid()
                         and decided.kind in ('accepted','refused')))
      and public.can_discuss_workspace_application(e.id)$a$);
end;
$patch$;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(803);
