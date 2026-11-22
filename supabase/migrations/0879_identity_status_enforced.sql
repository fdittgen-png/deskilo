-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (identity_status_apply, protect_federation_history and federation_outcome_refused are patched at asserted anchors; one column
--  with a default is added to identity_status_assertions; one function and one trigger are added;
--  no stored row is rewritten)
--
-- A workspace host enforces the identity status its personal home asserts.
--
--   * Applying a `suspended` assertion for a person bound here bans that person's account at this
--     host until the assertion's deadline plus the clock skew; an `erased` assertion bans it for good.
--     An `active` assertion lifts the ban this enforcement set, and only that one: a ban set any other
--     way is left as it is. The ban is the account's own `banned_until`, so every way in (sign-in,
--     refresh, the API) refuses with it.
--   * `identity_status_enforce` is the only writer. It takes an account only when it has no ban in
--     force or holds the one it set, and touches `banned_until` of the accounts
--     actively bound to the subject, nothing else of the account, records each change in
--     `database_authority_audit` (`identity_status_enforced`, `identity_status_lifted`) and is
--     reachable by no API role.
--   * An assertion that arrives for a subject not bound yet is kept when it is `suspended` or
--     `erased` and comes from the installation registered as this host's personal home, answered
--     `held`, and enforced when the binding is made. An `active` one, or one from any other
--     installation, for an unbound subject is refused as before. Revoking a binding does not lift a ban the
--     status still holds the account out with; it lifts the ban this enforcement set once the
--     status no longer does.
--   * Behaviour when the home falls silent: a suspension is enforced for the lifetime the home
--     gave it (plus the clock skew) and lapses with it, so a host never holds a person out on the
--     strength of a home it no longer hears; the home re-asserts every non-active status each
--     refresh period, which keeps a suspension in force for as long as the home holds it. An
--     erasure is final and never lapses.

-- audience: all row readers (the table is closed to every API role and read by definer functions)
alter table public.identity_status_assertions add column if not exists enforced_until timestamptz;

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

-- Enforces the status held for a subject on the accounts bound to it. The ban fields only.
-- A ban is taken over only when the account has none, when it has expired, or when it is the one
-- this enforcement set; a ban set any other way is neither extended nor lifted. The account and the
-- audit are written on a change of state, and a ban this enforcement holds is extended only when
-- less than one refresh period of it remains.
create or replace function public.identity_status_enforce(p_issuer text, p_subject text)
returns int language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_skew interval := make_interval(secs =>
    (public.setting_value(null, 'identity.clock_skew_seconds') #>> '{}')::int);
  v_every interval := make_interval(secs =>
    (public.setting_value(null, 'identity.status_reconcile_seconds') #>> '{}')::int);
  v_row public.identity_status_assertions;
  v_user uuid;
  v_until timestamptz;
  v_changed int := 0;
  v_ban timestamptz;
  v_ours boolean;
  v_record timestamptz;
begin
  select * into v_row from public.identity_status_assertions
   where issuer = p_issuer and subject = p_subject for update;
  if v_row.revision is null then
    return 0;
  end if;
  v_until := case v_row.status
               when 'erased' then timestamptz '2999-12-31 00:00:00+00'
               when 'suspended' then v_row.valid_until + v_skew
               else null end;
  -- A suspension whose deadline has passed enforces nothing.
  if v_until is not null and v_until <= now() then
    v_until := null;
  end if;
  v_record := v_row.enforced_until;
  for v_user in select b.local_user_id from public.identity_bindings b
                 where b.installation_id = public.installation_id()
                   and b.issuer = p_issuer and b.subject = p_subject and b.status = 'active' loop
    select u.banned_until into v_ban from auth.users u where u.id = v_user for update;
    v_ours := v_row.enforced_until is not null and v_ban is not distinct from v_row.enforced_until;
    if v_until is not null then
      if v_ban is null or v_ban <= now() then
        -- no ban in force: this enforcement takes the account
        update auth.users set banned_until = v_until where id = v_user;
        insert into public.database_authority_audit (installation_id, action, actor, target_user_id, detail)
        values (public.installation_id(), 'identity_status_enforced', 'system', v_user,
                jsonb_build_object('status', v_row.status, 'until', v_until));
        v_record := v_until;
        v_changed := v_changed + 1;
      elsif v_row.status = 'erased' then
        -- an erasure always holds the account out, whoever set the ban in force; a ban is never shortened
        if v_ban < v_until then
          update auth.users set banned_until = v_until where id = v_user;
          insert into public.database_authority_audit (installation_id, action, actor, target_user_id, detail)
          values (public.installation_id(), 'identity_status_enforced', 'system', v_user,
                  jsonb_build_object('status', v_row.status, 'until', v_until));
          v_changed := v_changed + 1;
        end if;
        v_record := v_until;
      elsif v_ours then
        -- its own ban: extended only when less than one refresh period of it remains
        if v_ban < v_until and v_ban < now() + v_every + v_skew then
          update auth.users set banned_until = v_until where id = v_user;
          v_record := v_until;
          v_changed := v_changed + 1;
        end if;
      else
        -- a ban set another way stays as it is, and is not this enforcement's
        v_record := null;
      end if;
    elsif v_ours then
      -- the status no longer holds an account out: lift the ban this enforcement set
      update auth.users set banned_until = null where id = v_user;
      insert into public.database_authority_audit (installation_id, action, actor, target_user_id, detail)
      values (public.installation_id(), 'identity_status_lifted', 'system', v_user,
              jsonb_build_object('status', v_row.status));
      v_record := null;
      v_changed := v_changed + 1;
    else
      v_record := null;
    end if;
  end loop;
  update public.identity_status_assertions set enforced_until = v_record
   where issuer = p_issuer and subject = p_subject and enforced_until is distinct from v_record;
  return v_changed;
end;
$fn$;
revoke execute on function public.identity_status_enforce(text, text) from public, anon, authenticated, service_role;

-- restates 0568
do $patch$
declare
  v_def text := pg_get_functiondef('public.identity_status_apply(jsonb, uuid, uuid, bigint)'::regprocedure);
  v_next text;
begin
  -- 1. a suspended or erased assertion for a subject not bound yet is kept
  v_next := pg_temp.anchor_replace(v_def, $o$                    and (b.status = 'active' or v_status <> 'active')) then
    return 'unlinked_subject';
  end if;$o$, $n$                    and (b.status = 'active' or v_status <> 'active')) then
    -- a status for a subject not bound yet is kept only when the home says it
    if v_status = 'active'
       or p_source is distinct from (select h.home_installation_id from public.membership_fact_home() h) then
      return 'unlinked_subject';
    end if;
    v_held := true;
  end if;$n$);
  if v_next is null then raise exception '0879: the binding check of identity_status_apply is not found' using errcode = 'P0001'; end if;
  v_def := v_next;
  v_next := pg_temp.anchor_replace(v_def, $o$  v_current public.identity_status_assertions;
begin$o$, $n$  v_current public.identity_status_assertions;
  v_held boolean := false;
begin$n$);
  if v_next is null then raise exception '0879: the declarations of identity_status_apply are not found' using errcode = 'P0001'; end if;
  v_def := v_next;
  -- 2. what was applied is enforced
  v_next := pg_temp.anchor_replace(v_def, $o$        event_id = excluded.event_id, received_at = now();
  return 'applied';$o$, $n$        event_id = excluded.event_id, received_at = now();
  perform public.identity_status_enforce(v_issuer, v_subject);
  return case when v_held then 'held' else 'applied' end;$n$);
  if v_next is null then raise exception '0879: the end of identity_status_apply is not found' using errcode = 'P0001'; end if;
  execute v_next;
end
$patch$;

-- restates 0576
do $patch$
declare
  v_def text := pg_get_functiondef('public.protect_federation_history()'::regprocedure);
  v_next text;
begin
  v_next := pg_temp.anchor_replace(v_def, $o$    if new.issuer <> old.issuer or new.subject <> old.subject
       or new.revision <= old.revision or old.status = 'erased' then$o$, $n$    if (new.issuer <> old.issuer or new.subject <> old.subject
        or new.revision <= old.revision or old.status = 'erased')
       and row(new.issuer, new.subject, new.revision, new.status, new.asserted_at, new.valid_until,
               new.source_installation_id, new.event_id)
           is distinct from row(old.issuer, old.subject, old.revision, old.status, old.asserted_at,
               old.valid_until, old.source_installation_id, old.event_id) then$n$);
  if v_next is null then raise exception '0879: the status guard of protect_federation_history is not found' using errcode = 'P0001'; end if;
  execute v_next;
end
$patch$;

-- restates 0579
create or replace function public.federation_outcome_refused(p_outcome text)
returns boolean language sql immutable set search_path = public as $fn$
  select p_outcome is not null
     and p_outcome not in ('applied', 'renewed', 'staged', 'reconciled', 'duplicate', 'superseded', 'held');
$fn$;
revoke execute on function public.federation_outcome_refused(text)
  from public, anon, authenticated, service_role;

-- The binding is made: what the home asserted before it is enforced now. The binding is revoked:
-- the ban this enforcement set on its account is lifted.
create or replace function public.identity_status_on_binding()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_row public.identity_status_assertions;
  v_ban timestamptz;
begin
  if new.status = 'active' then
    perform public.identity_status_enforce(new.issuer, new.subject);
  elsif tg_op = 'UPDATE' and old.status = 'active' then
    -- Unlinking never lifts a status that still holds the account out: the ban is lifted here
    -- only when the assertion no longer does (active, or a suspension past its deadline).
    select * into v_row from public.identity_status_assertions
     where issuer = new.issuer and subject = new.subject for update;
    if v_row.enforced_until is not null
       and (v_row.status = 'active'
            or (v_row.status = 'suspended'
                and v_row.valid_until + make_interval(secs =>
                    (public.setting_value(null, 'identity.clock_skew_seconds') #>> '{}')::int) <= now())) then
      select u.banned_until into v_ban from auth.users u where u.id = new.local_user_id for update;
      if v_ban is not distinct from v_row.enforced_until then
        update auth.users set banned_until = null where id = new.local_user_id;
        insert into public.database_authority_audit (installation_id, action, actor, target_user_id, detail)
        values (public.installation_id(), 'identity_status_lifted', 'system', new.local_user_id,
                jsonb_build_object('status', v_row.status, 'reason', 'binding_revoked'));
      end if;
      update public.identity_status_assertions set enforced_until = null
       where issuer = new.issuer and subject = new.subject;
    end if;
  end if;
  return null;
end;
$fn$;
revoke execute on function public.identity_status_on_binding() from public, anon, authenticated, service_role;
drop trigger if exists identity_status_on_binding on public.identity_bindings;
create trigger identity_status_on_binding
  after insert or update of status on public.identity_bindings
  for each row execute function public.identity_status_on_binding();

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(879);
