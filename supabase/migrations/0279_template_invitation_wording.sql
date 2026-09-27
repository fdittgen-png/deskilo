-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0279 (#1656, group 4) -- an owner may publish the space's invitation
-- texts, deliberately, once they no longer name the space.
--
-- 0229 never published invitation texts: they name the source space and
-- its people. A text written with the placeholders the app fills in
-- ({workspaceName}, {firstName}, {inviteLink}, ...) names nobody, and is
-- worth reusing. So invitations are now publishable on explicit opt-in
-- only: the save must name the 'invitation_texts' choice, never implied
-- by publishing everything. And every text is checked before it leaves:
-- one that still contains the space's own name, address, legal or VAT
-- identifier, WhatsApp link, invitation code, or a member's name or
-- e-mail refuses the save, naming the language to fix. The check is a
-- guard, not the permission: the opt-in is.

-- The texts the save would publish still name the source: refuse.
create or replace function public.template_wording_check(p_workspace_id uuid, p_config jsonb)
returns void language plpgsql stable security definer set search_path = public as $fn$
declare
  w public.workspaces;
  v_texts jsonb := '{}'::jsonb;
  v_lang text;
  v_text text;
  v_needle text;
  v_needles text[];
begin
  select * into w from public.workspaces where id = p_workspace_id;
  if coalesce(p_config->'workspace'->>'invitation_template', '') <> '' then
    v_texts := jsonb_build_object('default', p_config->'workspace'->>'invitation_template');
  end if;
  if jsonb_typeof(p_config->'workspace'->'invitation_templates') = 'object' then
    v_texts := v_texts || (p_config->'workspace'->'invitation_templates');
  end if;
  if v_texts = '{}'::jsonb then
    return;
  end if;
  v_needles := array(
    select distinct lower(trim(n)) from unnest(array[
      w.name, w.street, w.city, w.postal_code, w.address, w.legal_id, w.vat_id,
      w.whatsapp_group, w.invite_code]) n
     where char_length(trim(coalesce(n, ''))) >= 3
    union
    select distinct lower(trim(v)) from public.members m
      left join public.profiles p on p.id = m.user_id
      left join auth.users u on u.id = m.user_id,
      lateral unnest(array[m.managed_name, p.display_name, u.email::text]) v
     where m.workspace_id = p_workspace_id and char_length(trim(coalesce(v, ''))) >= 3);
  for v_lang, v_text in select key, value #>> '{}' from jsonb_each(v_texts) loop
    foreach v_needle in array v_needles loop
      if position(v_needle in lower(coalesce(v_text, ''))) > 0 then
        raise exception using errcode = 'P0001',
          message = format('the %s invitation text still names this space or its people; use placeholders such as {workspaceName} before publishing it', v_lang);
      end if;
    end loop;
  end loop;
end;
$fn$;
revoke execute on function public.template_wording_check(uuid, jsonb) from public, anon, authenticated;

-- Invitations: publishable, on opt-in only.
do $rules$
declare
  v_def text := pg_get_functiondef('public.template_publication_rules()'::regprocedure);
  v_old text := $a$'invitations', jsonb_build_object('allowed', false,$a$;
  v_new text := $a$'invitations', jsonb_build_object('allowed', true, 'opt_in', true,$a$;
begin
  if position(v_new in v_def) > 0 then return; end if;
  if position(v_old in v_def) = 0 then
    raise exception 'template_publication_rules no longer has the invitations rule 0279 opens';
  end if;
  execute replace(replace(v_def, v_old, v_new),
    $a$'reason', 'invitation texts name the source space and its people'),$a$,
    $a$'reason', 'on explicit opt-in only, and never while a text still names the source space or its people (0279)'),$a$);
end
$rules$;

-- The save honours the opt-in and checks the texts.
do $save$
declare
  v_def text := pg_get_functiondef('public.save_workspace_as_template(uuid,text,text,text,text,text[],text[])'::regprocedure);
  v_old_filter text := $a$where (r.v->>'allowed')::boolean$a$;
  v_new_filter text := $a$where (r.v->>'allowed')::boolean
     and (not coalesce((r.v->>'opt_in')::boolean, false)
          or 'invitation_texts' = any (coalesce(p_groups, '{}')))$a$;
  v_old_check text := $a$if jsonb_array_length(v_config->'entities') = 0 then$a$;
  v_new_check text := $a$if 'invitations' = any (v_publishable) then
    perform public.template_wording_check(p_workspace_id, v_config);
  end if;
  if jsonb_array_length(v_config->'entities') = 0 then$a$;
begin
  if position('template_wording_check' in v_def) > 0 then return; end if;
  if position(v_old_filter in v_def) = 0 or position(v_old_check in v_def) = 0 then
    raise exception 'save_workspace_as_template no longer has the shape 0279 patches';
  end if;
  execute replace(replace(v_def, v_old_filter, v_new_filter), v_old_check, v_new_check);
end
$save$;

-- The registry says what the texts now do.
do $registry$
declare
  v_def text := pg_get_functiondef('public.template_field_registry()'::regprocedure);
  v_old text := $a$"type":"text","portability":"never","absent":"inherit","reason":"names the source space and its people"$a$;
  v_new text := $a$"type":"text","portability":"literal","absent":"inherit","reason":"on explicit opt-in only; a text naming the source space or its people refuses the save (0279)"$a$;
begin
  if position(v_new in v_def) > 0 then return; end if;
  if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 2 then
    raise exception 'template_field_registry no longer has the two invitation entries 0279 reclassifies';
  end if;
  execute replace(v_def, v_old, v_new);
end
$registry$;

select public.set_deskilo_schema_version(279);
