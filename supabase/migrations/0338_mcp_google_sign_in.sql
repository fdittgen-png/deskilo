-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0338 (MCP) -- an assistant acts only for someone who signs in with Google.
--
-- Owner decision (2026-10-02): the MCP uses the authentication already
-- configured in the person's profile, which is Google. An account with a
-- linked Google identity authenticates assistants with it and nothing
-- else; an account without one cannot use the MCP.
--
--   * `mcp_has_google_identity()` -- the caller's account has a Google
--     identity in Supabase Auth;
--   * `mcp_google_session()`      -- and this session was opened with an
--     OAuth provider (`amr` method `oauth`). Google is the only OAuth
--     provider this installation configures, so that sign-in IS Google;
--     a second provider would need its own check here;
--   * `mcp_google_status()`       -- both facts for the app's checklist.
--
-- Where they apply, by anchored patch:
--   * asking for database approval needs the Google identity;
--   * consenting to an assistant (prepare / finalize, in the app) needs a
--     Google sign-in -- the grant the assistant receives comes from it;
--   * every facade call needs the Google identity to still be linked
--     (unlinking Google ends assistant access): code `no_google_identity`.

create or replace function public.mcp_has_google_identity()
returns boolean language sql stable security definer set search_path = public, auth as $fn$
  select auth.uid() is not null and exists (
    select 1 from auth.identities i
     where i.user_id = auth.uid() and i.provider = 'google');
$fn$;
revoke execute on function public.mcp_has_google_identity() from public, anon;
grant execute on function public.mcp_has_google_identity() to authenticated;

create or replace function public.mcp_google_session()
returns boolean language sql stable security definer set search_path = public, auth as $fn$
  select auth.uid() is not null
     and public.mcp_has_google_identity()
     and coalesce(auth.jwt()->'amr', '[]'::jsonb) @> '[{"method": "oauth"}]'::jsonb;
$fn$;
revoke execute on function public.mcp_google_session() from public, anon;
grant execute on function public.mcp_google_session() to authenticated;

create or replace function public.mcp_google_status()
returns jsonb language sql stable security definer set search_path = public, auth as $fn$
  select jsonb_build_object(
    'google_linked', auth.uid() is not null and public.mcp_has_google_identity(),
    'google_session', public.mcp_google_session());
$fn$;
revoke execute on function public.mcp_google_status() from public, anon;
grant execute on function public.mcp_google_status() to authenticated;

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

do $migration$
declare
  v_step record;
  v_def text;
  v_next text;
begin
  for v_step in
    select * from (values
      ('request_mcp_eligibility', '',
       $a$if v_binding is null then raise exception 'no verified identity binding'; end if;$a$,
       $b$if v_binding is null then raise exception 'no verified identity binding'; end if;
  if not public.mcp_has_google_identity() then
    raise exception 'link your Google account first: assistants use your Google sign-in';
  end if;$b$),
      ('mcp_prepare_connection', 'p_client_id text, p_authorization_id text, p_scopes jsonb',
       $a$perform public.mcp_require_native();
  if public.my_database_capabilities()->>'mcp_eligibility' <> 'eligible' then$a$,
       $b$perform public.mcp_require_native();
  if not public.mcp_google_session() then
    raise exception 'sign in with Google to connect an assistant';
  end if;
  if public.my_database_capabilities()->>'mcp_eligibility' <> 'eligible' then$b$),
      ('mcp_finalize_connection', 'p_authorization_id text',
       $a$perform public.mcp_require_native();
  select * into v_prep from public.mcp_connection_preparations$a$,
       $b$perform public.mcp_require_native();
  if not public.mcp_google_session() then
    raise exception 'sign in with Google to connect an assistant';
  end if;
  select * into v_prep from public.mcp_connection_preparations$b$),
      ('mcp_execute_v1', 'p_installation_id uuid, p_workspace_id uuid, p_operation text, p_arguments jsonb, p_request_id uuid',
       $a$  if v_binding is null then
    return public.mcp_usage_note(v_spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'denied', null, 'no_identity'));
  end if;$a$,
       $b$  if v_binding is null then
    return public.mcp_usage_note(v_spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'denied', null, 'no_identity'));
  end if;
  if not public.mcp_has_google_identity() then
    return public.mcp_usage_note(v_spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'denied', null, 'no_google_identity'));
  end if;$b$)
    ) as t(fn, args, old_text, new_text)
  loop
    select pg_get_functiondef(p.oid) into v_def
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = v_step.fn
       and pg_get_function_identity_arguments(p.oid) = v_step.args;
    if v_def is null then
      raise exception '0338: % not found', v_step.fn;
    end if;
    if position('mcp_has_google_identity' in v_def) > 0
       or position('mcp_google_session' in v_def) > 0 then
      raise exception '0338: % already asks for Google', v_step.fn;
    end if;
    v_next := pg_temp.anchor_replace(v_def, v_step.old_text, v_step.new_text);
    if v_next is null then
      raise exception '0338: anchor missing in %', v_step.fn;
    end if;
    execute v_next;
  end loop;
end
$migration$;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(338);
