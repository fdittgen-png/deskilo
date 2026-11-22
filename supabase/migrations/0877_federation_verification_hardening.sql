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
--   * Binding an identity from an OpenID provider requires the identity record to name the configured
--     issuer; a record that names none is refused as one that names another (`issuer_mismatch`).

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
                    'v_identity->>''iss'' is distinct from v_authority.issuer');
  execute v_next;
end
$patch$;

select public.set_deskilo_schema_version(877);
