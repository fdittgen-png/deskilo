-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- Additive: one more accepted key in an existing writer; no table, column,
-- policy or other function changes, and no stored preference is rewritten.
--
-- 9999 (#2552 XPRIV-01) -- whether private values (amounts on compact cards,
-- message previews) are masked until revealed is kept on the personal
-- account as well as on the device.
--
-- `private_values` is 'masked' or 'shown'. It is a personal default only:
-- it hides nothing on the server and is never a workspace override, so a
-- workspace-scoped write of it is refused; the workspace reset (every key
-- null) still passes. Nothing is backfilled: an account that never chose
-- has no key, and the client masks for it; an explicit choice stays.
--
-- `set_personal_preferences` is restated WHOLE (0299, with 0304's
-- `payment_provider`), so the replay and the contract digest own its body.
create or replace function public.set_personal_preferences(p_patch jsonb, p_workspace_id uuid default null, p_expected_account uuid default null)
returns void language plpgsql security definer set search_path = public as $fn$
declare v_person uuid; v_member uuid; k text; v jsonb;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  perform public.mcp_require_native();
  if p_expected_account is not null and p_expected_account <> auth.uid() then
    raise exception 'account changed';
  end if;
  if p_patch is null or jsonb_typeof(p_patch)<>'object' then
    raise exception 'invalid preferences';
  end if;
  for k,v in select * from jsonb_each(p_patch) loop
    if k not in ('format_locale','clock','time_zone_mode','preferred_locale','ui_locale','theme','payment_provider','private_values') then
      raise exception 'unknown preference';
    end if;
    if v='null'::jsonb and p_workspace_id is not null then continue; end if;
    if k='private_values' and p_workspace_id is not null then
      raise exception 'personal preference only';
    end if;
    if jsonb_typeof(v)<>'string' then raise exception 'invalid preference value'; end if;
    if (k='payment_provider' and v #>> '{}' not in ('','paypal','stripe','mollie','wero'))
       or (k='private_values' and v #>> '{}' not in ('masked','shown'))
       or (k='clock' and v #>> '{}' not in ('auto','12h','24h'))
       or (k='time_zone_mode' and v #>> '{}' not in ('workspace','device'))
       or (k='theme' and v #>> '{}' not in ('system','light','dark'))
       or (k in ('ui_locale','preferred_locale') and v #>> '{}' not in ('','en','fr','de','es','it'))
       or (k='format_locale' and v #>> '{}' <> '' and v #>> '{}' !~ '^[a-z]{2}_[A-Z]{2}$') then
      raise exception 'invalid preference value';
    end if;
  end loop;
  select person_id into strict v_person from public.profiles where id=auth.uid() for update;
  if p_workspace_id is null then
    update public.directory_people set preferences=preferences || p_patch where id=v_person;
    -- Compatibility projection, changed only for the keys in this patch.
    update public.profiles set
      format_locale=coalesce(p_patch->>'format_locale',format_locale),
      clock=coalesce(p_patch->>'clock',clock),
      time_zone_mode=coalesce(p_patch->>'time_zone_mode',time_zone_mode),
      preferred_locale=coalesce(p_patch->>'preferred_locale',preferred_locale)
      where id=auth.uid();
  else
    select id into v_member from public.members where workspace_id=p_workspace_id
      and user_id=auth.uid() and status in ('active','paused','pending') for update;
    if v_member is null then raise exception 'membership unavailable'; end if;
    insert into public.member_preference_overrides(member_id,preferences)
      values(v_member,jsonb_strip_nulls(p_patch))
      on conflict(member_id) do update set preferences=
        jsonb_strip_nulls(public.member_preference_overrides.preferences || p_patch);
    -- A public document-language projection, never the private preference map.
    -- The membership trigger derives it so direct edits cannot forge it.
    update public.members set preferred_locale_override=null where id=v_member;
  end if;
end;
$fn$;
revoke execute on function public.set_personal_preferences(jsonb,uuid,uuid) from public, anon;
grant execute on function public.set_personal_preferences(jsonb,uuid,uuid) to authenticated;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(9999);
