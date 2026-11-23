-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (one column with a default is added; membership_fact_enqueue, membership_fact_apply,
--  my_personal_message_directory_v1 and personal_directory_relationships are patched at asserted
--  anchors; no stored row is rewritten)
--
-- The directory lists the people and businesses of another installation only when that business
-- keeps its members directory on.
--
--   * A membership fact carries, with every fact that is not a tombstone, whether the business keeps
--     its members directory on (`members_directory`, a boolean the business's own installation
--     asserts); the personal home stores it with the fact (`membership_facts.members_directory`,
--     false until a fact says otherwise). A renewal re-asserts the current value, and changing the
--     setting of the business marks its facts for re-assertion, so the home follows within one
--     `identity.status_reconcile_seconds`.
--   * The personal home lists a remote business, and the people it holds by fact, only while the
--     fact says the directory is on: the rule a business of the home's own installation already
--     follows.

-- audience: all row readers (the table is read by the definer functions of the home alone: no API role holds it)
alter table public.membership_facts add column if not exists members_directory boolean not null default false;

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

-- restates 0574
do $patch$
declare
  v_def text := pg_get_functiondef('public.membership_fact_enqueue(public.membership_fact_state)'::regprocedure);
  v_old text := $o$|| case when v_name is not null then jsonb_build_object('workspace_name', v_name)
            else '{}'::jsonb end);$o$;
  v_next text;
begin
  if pg_temp.occurrences(v_def, '''workspace_name'', v_name') <> 1 then
    raise exception '0878: the name of membership_fact_enqueue is not found exactly once' using errcode = 'P0001';
  end if;
  v_next := pg_temp.anchor_replace(v_def, v_old, $n$|| case when v_name is not null then jsonb_build_object('workspace_name', v_name)
            else '{}'::jsonb end
    || case when p_state.status <> 'tombstone' then jsonb_build_object('members_directory', coalesce((
         select public.feature_effective(w.id, 'membersDirectory') from public.workspaces w
          where w.network_id = p_state.network_id), false)) else '{}'::jsonb end);$n$);
  if v_next is null then raise exception '0878: the anchor of membership_fact_enqueue is not found' using errcode = 'P0001'; end if;
  execute v_next;
end
$patch$;

-- restates 0574
do $patch$
declare
  v_def text := pg_get_functiondef('public.membership_fact_apply(jsonb, uuid, uuid, bigint)'::regprocedure);
  v_next text;
begin
  v_next := pg_temp.anchor_replace(v_def, $o$  v_name text;
  v_current public.membership_facts;$o$, $n$  v_name text;
  v_directory boolean := false;
  v_current public.membership_facts;$n$);
  if v_next is null then raise exception '0878: the declarations of membership_fact_apply are not found' using errcode = 'P0001'; end if;
  v_def := v_next;
  v_next := pg_temp.anchor_replace(v_def, $o$  if p_body->>'kind' is distinct from 'membership_fact' or p_body->>'protocol' is distinct from '1'$o$,
$n$  -- Whether the business keeps its directory on: a boolean, or absent (off).
  if coalesce(jsonb_typeof(p_body->'members_directory'), 'null') <> 'null' then
    if jsonb_typeof(p_body->'members_directory') <> 'boolean' then
      return 'malformed';
    end if;
    v_directory := (p_body->>'members_directory')::boolean;
  end if;
  if p_body->>'kind' is distinct from 'membership_fact' or p_body->>'protocol' is distinct from '1'$n$);
  if v_next is null then raise exception '0878: the kind check of membership_fact_apply is not found' using errcode = 'P0001'; end if;
  v_def := v_next;
  v_next := pg_temp.anchor_replace(v_def, $o$  if v_status = 'tombstone' then
    v_name := null;
  end if;$o$, $n$  if v_status = 'tombstone' then
    v_name := null;
    v_directory := false;
  end if;$n$);
  if v_next is null then raise exception '0878: the tombstone rule of membership_fact_apply is not found' using errcode = 'P0001'; end if;
  v_def := v_next;
  v_next := pg_temp.anchor_replace(v_def, $o$event_id, workspace_name)
    values (v_user, v_ref, v_issuer, p_source, v_revision, v_status, v_issued, v_until, v_epoch,
      p_event, v_name);$o$, $n$event_id, workspace_name, members_directory)
    values (v_user, v_ref, v_issuer, p_source, v_revision, v_status, v_issued, v_until, v_epoch,
      p_event, v_name, v_directory);$n$);
  if v_next is null then raise exception '0878: the insert of membership_fact_apply is not found' using errcode = 'P0001'; end if;
  v_def := v_next;
  v_next := pg_temp.anchor_replace(v_def, $o$event_id = p_event, received_at = now(), workspace_name = v_name
     where user_id = v_user and network_id = v_ref;
    return 'renewed';$o$, $n$event_id = p_event, received_at = now(), workspace_name = v_name,
           members_directory = v_directory
     where user_id = v_user and network_id = v_ref;
    return 'renewed';$n$);
  if v_next is null then raise exception '0878: the renewal of membership_fact_apply is not found' using errcode = 'P0001'; end if;
  v_def := v_next;
  v_next := pg_temp.anchor_replace(v_def, $o$         workspace_name = v_name
   where user_id = v_user and network_id = v_ref;
  return 'applied';$o$, $n$         workspace_name = v_name, members_directory = v_directory
   where user_id = v_user and network_id = v_ref;
  return 'applied';$n$);
  if v_next is null then raise exception '0878: the update of membership_fact_apply is not found' using errcode = 'P0001'; end if;
  execute v_next;
end
$patch$;

-- restates 0570
do $patch$
declare
  v_def text := pg_get_functiondef('public.my_personal_message_directory_v1(text, text, text, text)'::regprocedure);
  v_next text;
begin
  v_next := pg_temp.anchor_replace(v_def, $o$where f.network_id = p_workspace_network_id and f.status = 'active'$o$,
    $n$where f.network_id = p_workspace_network_id and f.status = 'active' and f.members_directory$n$);
  if v_next is null then raise exception '0878: the fact branch of my_personal_message_directory_v1 is not found' using errcode = 'P0001'; end if;
  execute v_next;
end
$patch$;

-- restates 0575
do $patch$
declare
  v_def text := pg_get_functiondef('public.personal_directory_relationships(uuid)'::regprocedure);
  v_next text;
begin
  v_next := pg_temp.anchor_replace(v_def, $o$where f.user_id = p_user and f.status = 'active'$o$,
    $n$where f.user_id = p_user and f.status = 'active' and f.members_directory$n$);
  if v_next is null then raise exception '0878: the fact branch of personal_directory_relationships is not found' using errcode = 'P0001'; end if;
  execute v_next;
end
$patch$;

-- Changing whether a business keeps its directory on marks its facts for re-assertion: the next
-- reconcile re-asserts each, with the current value.
create or replace function public.membership_fact_directory_changed()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  if new.network_id is not null then
    -- what waits to be sent says the old value: it is withdrawn and asserted again
    update public.membership_fact_outbox set state = 'expired'
     where network_id = new.network_id and state = 'pending' and status <> 'tombstone';
    update public.membership_fact_state set last_asserted_at = null
     where network_id = new.network_id and status <> 'tombstone';
  end if;
  return null;
end;
$fn$;
revoke execute on function public.membership_fact_directory_changed() from public, anon, authenticated, service_role;
drop trigger if exists membership_fact_directory_changed on public.workspaces;
create trigger membership_fact_directory_changed
  after update of feature_flags on public.workspaces
  for each row when (old.feature_flags is distinct from new.feature_flags)
  execute function public.membership_fact_directory_changed();

select public.set_deskilo_schema_version(878);
