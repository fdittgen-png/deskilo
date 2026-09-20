-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0249 (#1288 S3) — erasure reaches the answers, and stops there.
--
-- A member who leaves has their PERSONAL answers erased and their
-- non-personal ones kept. That is what `workspace_field_definitions
-- .personal_data` is for: an emergency contact goes, a shirt size for
-- the association's next order stays, because the second is the
-- workspace's operational data and not a fact about a person.
--
-- The flag is the owner's decision, made when the question is defined,
-- and it is the ONE switch that drives export, erasure, the retention
-- matrix and what may be logged. A question wrongly marked
-- non-personal therefore survives erasure, which is why
-- `set_workspace_field` defaults it to TRUE: the safe answer is the
-- default, and saying otherwise is a deliberate act.
--
-- Erasure stays what PRIVACY.md says it is. It now touches six tables
-- instead of four, and `privacy_claims_test` and the retention matrix
-- change in the same commit — the pair that stops the promise and the
-- code drifting apart.
create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
begin
  if position(p_old in p_def) = 0 then return null; end if;
  return replace(p_def, p_old, p_new);
end
$f$;

revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $migration$
declare
  v_def text;
  v_patched text;
begin
  v_def := pg_get_functiondef('public.erase_my_membership(uuid)'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    $a$  update public.members set status = 'exited', is_admin = false$a$,
    $a$  -- #1288 S3 — the answers this member gave to the workspace's own
  -- questions, where the question is personal data. The junction
  -- first: its rows point at the values about to go.
  delete from public.workspace_field_value_options vo
   using public.workspace_field_values v
    join public.workspace_field_definitions d on d.id = v.definition_id
   where vo.value_id = v.id and v.member_id = v_me.id and d.personal_data;
  delete from public.workspace_field_values v
   using public.workspace_field_definitions d
   where d.id = v.definition_id and v.member_id = v_me.id and d.personal_data;
  update public.members set status = 'exited', is_admin = false$a$);
  if v_patched is null then
    raise exception '0249: the erase_my_membership anchor did not match';
  end if;
  execute v_patched;
end
$migration$;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(249);
