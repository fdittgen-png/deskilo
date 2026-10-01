-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0324 (#1851) -- switching a feature off stops NEW business; it does not
-- abandon the work already under way.
--
-- Every gated operation belongs to one class:
--   * accept_new       -- a new commitment (start an inquiry). Open only
--                         while the feature is effective.
--   * service_existing -- answering, reading or closing what already
--                         exists. Allowed whatever the flag says; the
--                         caller still checks who may do it.
--   * suspended        -- an old path judged unsafe. Never open.
-- `feature_operation_allowed` is the server half of
-- lib/features/workspace/domain/feature_operation.dart; the two answer
-- the same matrix (pgTAP 110 and feature_operation_test.dart).
--
-- The representative feature is spaceInquiries (#1824). Before this
-- migration, an owner who switched it off also silenced the open
-- conversations: the hosts could no longer answer, and the inquiries left
-- their inbox, so nobody could find them to close them.
--   * start_space_inquiry   -- accept_new (behaviour unchanged).
--   * send_inquiry_message  -- service_existing: an OPEN inquiry can still
--                              be answered by its requester and its hosts.
--                              A closed one stays closed.
--   * my_inbox              -- the hosts' existing inquiries stay listed,
--                              so they can be read and closed.
-- Flags, maturity and pilots never widen who may act: inquiry_role and
-- inquiry_host are untouched.

create or replace function public.feature_operation_allowed(
  p_workspace uuid, p_feature text, p_operation text
) returns boolean
language plpgsql stable security definer set search_path = public as $$
begin
  return case p_operation
    when 'accept_new' then public.feature_effective(p_workspace, p_feature)
    when 'service_existing' then true
    when 'suspended' then false
    else null
  end;
end;
$$;
revoke execute on function public.feature_operation_allowed(uuid, text, text) from public, anon;
grant execute on function public.feature_operation_allowed(uuid, text, text) to authenticated;

do $patch$
declare
  v_def text;
  v_old text;
begin
  -- start_space_inquiry: the same gate, named by its class.
  select pg_get_functiondef('public.start_space_inquiry(uuid, text)'::regprocedure) into v_def;
  v_old := $a$or not public.feature_effective(p_workspace, 'spaceInquiries') then$a$;
  if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then
    raise exception '0324: start_space_inquiry anchor';
  end if;
  execute replace(v_def, v_old,
    $a$or not public.feature_operation_allowed(p_workspace, 'spaceInquiries', 'accept_new') then$a$);

  -- send_inquiry_message: answering an open inquiry is servicing it.
  select pg_get_functiondef('public.send_inquiry_message(uuid, text)'::regprocedure) into v_def;
  v_old := $a$if not public.feature_effective(v_inquiry.workspace_id, 'spaceInquiries') then$a$;
  if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then
    raise exception '0324: send_inquiry_message anchor';
  end if;
  execute replace(v_def, v_old,
    $a$if not public.feature_operation_allowed(v_inquiry.workspace_id, 'spaceInquiries', 'service_existing') then$a$);

  -- my_inbox: the hosts keep seeing the inquiries they must still answer.
  select pg_get_functiondef('public.my_inbox()'::regprocedure) into v_def;
  v_old := $a$and public.feature_effective(i.workspace_id, 'spaceInquiries')$a$;
  if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then
    raise exception '0324: my_inbox anchor';
  end if;
  execute replace(v_def, v_old,
    $a$and public.feature_operation_allowed(i.workspace_id, 'spaceInquiries', 'service_existing')$a$);
end;
$patch$;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(324);
