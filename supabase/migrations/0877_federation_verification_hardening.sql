-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (federation_verify and finalize_identity_binding are patched at asserted anchors; two operator
--  functions lose one more grant; no stored data moves)
--
-- Federation: the operator functions, the verification of a request, the binding of an identity.
--
--   * `operator_set_personal_home` and `operator_set_installation_roles` are executed by the operator
--     alone: no API role holds the privilege, `service_role` included, as for the other operator
--     functions of the backchannel.
--   * A request that cannot be authenticated (an unknown installation, an unknown or retired key, a
--     wrong target, a signature that does not verify) is answered with one refusal, `unauthorized`,
--     whichever of the four it is; the inbox answers it with one status. A request whose signature
--     verifies is also refused when its timestamp is older than the assertion lifetime plus the clock
--     skew (`stale_request`), as it is when it is newer than the skew allows.
--   * Binding an identity from the configured sign-in provider requires the configured issuer: the
--     one the identity record names or, when the record names none, the one the provider's own
--     record in Auth names. Neither, or another one, is `issuer_mismatch`. Only the configured provider
--     is read here; the built-in sign-in methods (email, Google, Apple) bind through the native
--     authority, which reads no identity record.

revoke execute on function public.operator_set_personal_home(text, text, text, uuid)
  from public, anon, authenticated, service_role;
revoke execute on function public.operator_set_installation_roles(text[], uuid)
  from public, anon, authenticated, service_role;

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

-- the number of times p_old occurs in p_def
create or replace function pg_temp.occurrences(p_def text, p_old text)
returns int language sql as $f$
  select (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old)
$f$;
revoke execute on function pg_temp.occurrences(text, text) from public, anon, authenticated;

-- restates 0568
do $patch$
declare
  v_def text := pg_get_functiondef('public.federation_verify(text, text, jsonb, bytea)'::regprocedure);
  v_next text := v_def;
  v_one text;
  v_ones text[] := array['wrong_target', 'unknown_installation', 'unknown_key', 'bad_signature'];
begin
  foreach v_one in array v_ones loop
    if pg_temp.occurrences(v_next, 'jsonb_build_object(''outcome'', ''' || v_one || ''')') <> 1 then
      raise exception '0877: the refusal % of federation_verify is not found exactly once', v_one using errcode = 'P0001';
    end if;
    v_next := replace(v_next, 'jsonb_build_object(''outcome'', ''' || v_one || ''')', 'jsonb_build_object(''outcome'', ''unauthorized'')');
  end loop;
  if pg_temp.occurrences(v_next, 'return jsonb_build_object(''outcome'', ''future_request'');') <> 1 then
    raise exception '0877: the future bound of federation_verify is not found exactly once' using errcode = 'P0001';
  end if;
  v_next := replace(v_next, 'return jsonb_build_object(''outcome'', ''future_request'');
  end if;', 'return jsonb_build_object(''outcome'', ''future_request'');
  end if;
  if v_ts < extract(epoch from now()) - v_skew
            - (public.setting_value(null, ''identity.status_assertion_lifetime_seconds'') #>> ''{}'')::int then
    return jsonb_build_object(''outcome'', ''stale_request'');
  end if;');
  if pg_temp.occurrences(v_next, 'stale_request') <> 1 then
    raise exception '0877: the anchor of the past bound is not found' using errcode = 'P0001';
  end if;
  execute v_next;
end
$patch$;

-- The issuer the Auth record of a custom sign-in provider names (null when there is none).
create or replace function public.identity_provider_issuer(p_provider text)
returns text language plpgsql stable security definer set search_path = public, auth as $fn$
declare
  v_issuer text;
begin
  if p_provider is null or to_regclass('auth.custom_oauth_providers') is null then
    return null;
  end if;
  execute 'select nullif(issuer, '''') from auth.custom_oauth_providers
            where identifier in ($1, regexp_replace($1, ''^custom:'', '''')) limit 1'
    into v_issuer using p_provider;
  return v_issuer;
end;
$fn$;
revoke execute on function public.identity_provider_issuer(text) from public, anon, authenticated, service_role;

-- restates 0269
do $patch$
declare
  v_def text := pg_get_functiondef('public.finalize_identity_binding()'::regprocedure);
  v_next text;
begin
  if pg_temp.occurrences(v_def, 'v_identity ? ''iss'' and v_identity->>''iss'' <> v_authority.issuer') <> 1 then
    raise exception '0877: the issuer check of finalize_identity_binding is not found exactly once' using errcode = 'P0001';
  end if;
  v_next := replace(v_def, 'v_identity ? ''iss'' and v_identity->>''iss'' <> v_authority.issuer',
                    'coalesce(v_identity->>''iss'', public.identity_provider_issuer(v_authority.oidc_provider)) is distinct from v_authority.issuer');
  execute v_next;
end
$patch$;

select public.set_deskilo_schema_version(877);
