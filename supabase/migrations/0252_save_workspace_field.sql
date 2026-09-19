-- SPDX-License-Identifier: 0BSD
-- risk: additive
--
-- 0252 (#1532) — a question and its choices are saved together, or not.
--
-- The questions screen called `set_workspace_field` and then, for a
-- choice question, `set_workspace_field_options`. Two server calls, one
-- button, and one message. When the second failed the owner read
--
--     The question was not saved.
--
-- which was false: the question WAS saved. It was live for members, and
-- it was a choice question with no choices — the one state the editor
-- has no way to show and no way to reach on purpose.
--
-- `set_workspace_field_options` refuses a malformed choice key, and
-- refuses removing a choice somebody has already made. Both are right,
-- and both used to arrive after the question had already landed.
--
-- So this is the composite the screen should have been calling. A
-- plpgsql function is one transaction: if the choices are refused, the
-- definition goes back with them. It adds no authority of its own — both
-- inner functions are definers that check `is_owner_of` for themselves,
-- and they still do.
--
-- The two are kept. `set_workspace_field` is still the right call for a
-- question that has no choices, the pgTAP file pins its validation
-- directly, and `field_definitions_import` has its own path. What
-- changes is that no CLIENT composes two writes and calls the result one
-- save — the rule #1449 checkpoint 3 states and `save_workspace_settings`
-- already follows.

create or replace function public.save_workspace_field(
  p_workspace_id uuid,
  p_key text,
  p_type text,
  p_labels jsonb,
  p_required boolean default false,
  p_personal_data boolean default true,
  p_visibility text default 'self',
  p_contexts text[] default array['profile']::text[],
  p_group_key text default 'general',
  p_sort_order int default 0,
  p_validation jsonb default '{}'::jsonb,
  p_active boolean default true,
  p_options jsonb default null
) returns uuid
language plpgsql security definer set search_path = public as $fn$
declare
  v_id uuid;
begin
  -- Its own guard, not only its callees'. A definer a client can call
  -- checks for itself: delegating the question to two other definers
  -- makes this one correct today and one refactor away from being a way
  -- in. It is the same refusal, in the same words.
  if auth.uid() is null or not public.is_owner_of(p_workspace_id) then
    raise exception 'only an owner defines the questions of a workspace';
  end if;

  v_id := public.set_workspace_field(p_workspace_id, p_key, p_type, p_labels,
    p_required, p_personal_data, p_visibility, p_contexts, p_group_key,
    p_sort_order, p_validation, p_active);
  -- null means "this question has no choices", which is not the same as
  -- `[]` — an empty array asks for every existing choice to be removed,
  -- and `set_workspace_field_options` refuses that when somebody has
  -- already chosen one.
  if p_options is not null then
    perform public.set_workspace_field_options(v_id, p_options);
  end if;
  return v_id;
end $fn$;

revoke execute on function public.save_workspace_field(
  uuid, text, text, jsonb, boolean, boolean, text, text[], text, int,
  jsonb, boolean, jsonb) from public, anon;
grant execute on function public.save_workspace_field(
  uuid, text, text, jsonb, boolean, boolean, text, text[], text, int,
  jsonb, boolean, jsonb) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(252);
