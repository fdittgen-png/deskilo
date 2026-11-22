-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (membership_fact_produce is patched at an asserted anchor; no stored data moves)
--
-- #4326 -- one membership fact per subject and business.
--
-- `membership_fact_produce` read every binding row of the person, revoked ones included, in no stated
-- order, and wrote one fact per row. After a person unlinks their account and links it again the
-- same subject has a revoked row and an active row: each run wrote a tombstone and then an active
-- fact for the same relationship (two revisions and two outbox events with one assertion time), and
-- when the scan returned the revoked row last the personal home kept the person as a former member.
--
-- Now the loop reads ONE row per subject, in the order of the subject: the active binding, and the
-- revoked one only when no active one exists. A revoked row of a subject that another local person
-- holds active is not this person's to tombstone (the holder's own run asserts it). A second run
-- with nothing changed writes nothing.

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

-- restates 0569
do $patch$
declare
  v_def text := pg_get_functiondef('public.membership_fact_produce(uuid, uuid)'::regprocedure);
  v_old text := $o$for v_binding in select b.subject, b.status from public.identity_bindings b
                    where b.installation_id = public.installation_id()
                      and b.local_user_id = p_user and b.issuer = v_issuer loop$o$;
  v_next text;
begin
  if (length(v_def) - length(replace(v_def, 'for v_binding in select b.subject, b.status', ''))) / length('for v_binding in select b.subject, b.status') <> 1 then
    raise exception '0875: the binding loop of membership_fact_produce is not found exactly once' using errcode = 'P0001';
  end if;
  v_next := pg_temp.anchor_replace(v_def, v_old,
    $n$for v_binding in select distinct on (b.subject) b.subject, b.status from public.identity_bindings b
                    where b.installation_id = public.installation_id()
                      and b.local_user_id = p_user and b.issuer = v_issuer
                      and (b.status = 'active'
                           or not exists (select 1 from public.identity_bindings a
                                           where a.installation_id = b.installation_id and a.issuer = b.issuer
                                             and a.subject = b.subject and a.status = 'active'))
                    order by b.subject, (b.status = 'active') desc, b.bound_at desc, b.id loop$n$);
  if v_next is null then raise exception '0875: the anchor of membership_fact_produce is not found' using errcode = 'P0001'; end if;
  execute v_next;
end
$patch$;

select public.set_deskilo_schema_version(875);
