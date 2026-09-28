-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- #1791: people survive credentials; membership and financial IDs do not move.
-- profiles remains the backwards-compatible account projection. Private managed
-- identities keep their existing per-member access rules; no public directory.
create table public.directory_people (
  id uuid primary key default gen_random_uuid(),
  preferences jsonb not null default '{}'::jsonb,
  merged_into uuid references public.directory_people(id),
  check (merged_into is distinct from id)
);
select public.ensure_system_columns('directory_people');
create index directory_people_merged_idx on public.directory_people(merged_into)
  where merged_into is not null;
alter table public.directory_people enable row level security;
revoke all on public.directory_people from public, anon, authenticated;
create policy mcp_delegated_deny on public.directory_people
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

alter table public.profiles add column person_id uuid
  references public.directory_people(id);
alter table public.members add column person_id uuid
  references public.directory_people(id);
alter table public.members add column preferred_locale_override text;

-- No email matching: every existing account and every unclaimed member gets
-- its own identity. Claims are the existing proof-of-control invitation flow.
alter table public.profiles disable trigger user;
alter table public.members disable trigger user;
do $backfill$
declare r record; v_person uuid;
begin
  for r in select id from public.profiles order by id loop
    insert into public.directory_people default values returning id into v_person;
    update public.profiles set person_id = v_person where id = r.id;
  end loop;
  -- Existing membership triggers concern roles/status, not this new key.
  update public.members m set person_id = p.person_id
    from public.profiles p where p.id = m.user_id;
  for r in select id from public.members where person_id is null order by id loop
    insert into public.directory_people default values returning id into v_person;
    update public.members set person_id = v_person where id = r.id;
  end loop;
end;
$backfill$;
alter table public.profiles enable trigger user;
alter table public.members enable trigger user;
alter table public.profiles alter column person_id set not null;
alter table public.members alter column person_id set not null;
create unique index profiles_person_idx on public.profiles(person_id);
create index members_person_idx on public.members(person_id);

create table public.member_preference_overrides (
  member_id uuid primary key references public.members(id) on delete cascade,
  preferences jsonb not null default '{}'::jsonb
);
select public.ensure_system_columns('member_preference_overrides');
alter table public.member_preference_overrides enable row level security;
revoke all on public.member_preference_overrides from public, anon, authenticated;
create policy mcp_delegated_deny on public.member_preference_overrides
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- The new key is always server-derived, including writes by older clients.
create function public.profile_directory_person() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    insert into public.directory_people default values returning id into new.person_id;
  elsif new.person_id is distinct from old.person_id then
    raise exception 'person identity is immutable';
  end if;
  return new;
end;
$$;
revoke execute on function public.profile_directory_person() from public, anon, authenticated;
create trigger profiles_directory_person before insert or update on public.profiles
  for each row execute function public.profile_directory_person();

create function public.member_directory_person() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_person uuid;
begin
  if tg_op = 'UPDATE' then
    if new.person_id is distinct from old.person_id then
      raise exception 'person identity is server managed';
    end if;
    if old.user_id is not null and new.user_id is not null
       and old.user_id <> new.user_id then
      raise exception 'membership account cannot be reassigned';
    end if;
  end if;
  if new.user_id is not null then
    select person_id into strict v_person from public.profiles where id = new.user_id;
    if tg_op = 'UPDATE' and old.user_id is null then
      -- The caller claims their own member; a workspace owner cannot attach
      -- another account by editing its public membership row.
      if auth.uid() is distinct from new.user_id then
        raise exception 'membership must be claimed by its account';
      end if;
      update public.directory_people set merged_into = v_person
        where id = old.person_id and id <> v_person
          and not exists (select 1 from public.members other
            where other.person_id=old.person_id and other.id<>old.id);
    end if;
    new.person_id := v_person;
  elsif tg_op = 'INSERT' then
    insert into public.directory_people default values returning id into new.person_id;
  end if;
  new.preferred_locale_override := (select preferences->>'preferred_locale'
    from public.member_preference_overrides where member_id=new.id);
  return new;
end;
$$;
revoke execute on function public.member_directory_person() from public, anon, authenticated;
create trigger members_directory_person before insert or update on public.members
  for each row execute function public.member_directory_person();

-- A credential deletion must not cascade into membership, reservations or
-- accounting. Personal data still lives under the existing profile/managed
-- access controls; this independent row carries no contact data or credentials.
alter table public.members drop constraint members_user_id_fkey;
alter table public.members add constraint members_user_id_fkey
  foreign key (user_id) references auth.users(id) on delete set null;
alter table public.members drop constraint members_managed_has_admin;

-- Only the caller's identity is returned. No directory enumeration, email
-- lookup, membership grant or account linking is exposed by this endpoint.
create function public.my_directory_person() returns uuid
language plpgsql stable security definer set search_path = public as $$
declare v_person uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  select person_id into v_person from public.profiles where id = auth.uid();
  return v_person;
end;
$$;
revoke execute on function public.my_directory_person() from public, anon;
grant execute on function public.my_directory_person() to authenticated;

-- Personal preferences are private and independent of membership authority.


-- Keep old clients' profile writes authoritative for their existing defaults.
create function public.sync_person_preferences() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update public.directory_people set preferences = preferences ||
    jsonb_build_object('format_locale',new.format_locale,'clock',new.clock,
      'time_zone_mode',new.time_zone_mode,'preferred_locale',new.preferred_locale)
    where id = new.person_id;
  return new;
end;
$$;
revoke execute on function public.sync_person_preferences() from public, anon, authenticated;
create trigger profiles_person_preferences after insert or update of
  format_locale,clock,time_zone_mode,preferred_locale on public.profiles
  for each row execute function public.sync_person_preferences();
update public.directory_people d set preferences = jsonb_build_object(
  'format_locale',p.format_locale,'clock',p.clock,
  'time_zone_mode',p.time_zone_mode,'preferred_locale',p.preferred_locale)
  from public.profiles p where p.person_id=d.id;

create function public.my_personal_preferences(p_workspace_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_defaults jsonb; v_overrides jsonb := '{}'::jsonb; v_member uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  perform public.mcp_require_native();
  select d.preferences into v_defaults from public.directory_people d
    join public.profiles p on p.person_id=d.id where p.id=auth.uid();
  if p_workspace_id is not null then
    select id into v_member from public.members where workspace_id=p_workspace_id
      and user_id=auth.uid() and status in ('active','paused','pending');
    if v_member is null then raise exception 'membership unavailable'; end if;
    select preferences into v_overrides from public.member_preference_overrides where member_id=v_member;
  end if;
  return jsonb_build_object('defaults',coalesce(v_defaults,'{}'::jsonb),
    'overrides',coalesce(v_overrides,'{}'::jsonb));
end;
$$;
revoke execute on function public.my_personal_preferences(uuid) from public, anon;
grant execute on function public.my_personal_preferences(uuid) to authenticated;

-- A patch changes only named keys. JSON null removes an override so the next
-- read inherits the latest personal default. No permissions/billing keys exist.
create function public.set_personal_preferences(p_patch jsonb, p_workspace_id uuid default null, p_expected_account uuid default null)
returns void language plpgsql security definer set search_path = public as $$
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
    if k not in ('format_locale','clock','time_zone_mode','preferred_locale','ui_locale','theme') then
      raise exception 'unknown preference';
    end if;
    if v='null'::jsonb and p_workspace_id is not null then continue; end if;
    if jsonb_typeof(v)<>'string' then raise exception 'invalid preference value'; end if;
    if (k='clock' and v #>> '{}' not in ('auto','12h','24h'))
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
$$;
revoke execute on function public.set_personal_preferences(jsonb,uuid,uuid) from public, anon;
grant execute on function public.set_personal_preferences(jsonb,uuid,uuid) to authenticated;

-- The existing subject-access export includes both defaults and overrides.
do $export$
declare v_def text; v_anchor text := $a$    'exported_at', now(),$a$;
begin
  v_def := pg_get_functiondef('public.export_my_data(uuid)'::regprocedure);
  if position(v_anchor in v_def)=0 then raise exception '0299: export anchor missing'; end if;
  execute replace(v_def,v_anchor,$a$    'exported_at', now(),
    'personal_preferences', (select preferences from public.directory_people where id=v_me.person_id),
    'workspace_preferences', (select preferences from public.member_preference_overrides where member_id=v_me.id),$a$);
end;
$export$;

-- Before sign-in the app needs only routing metadata, never operator settings,
-- Removing or changing the provider proof withdraws identity-derived trust;
-- ordinary workspace membership and the remaining native credentials survive.
create function public.directory_identity_unlinked() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'UPDATE' and new.user_id = old.user_id and new.provider = old.provider
     and new.identity_data->>'sub' is not distinct from old.identity_data->>'sub'
     and new.identity_data->>'iss' is not distinct from old.identity_data->>'iss' then
    return new;
  end if;
  update public.identity_bindings b set status='revoked', revoked_at=now()
    from public.identity_authority a
    where a.kind='oidc' and a.oidc_provider=old.provider
      and b.local_user_id=old.user_id and b.issuer=a.issuer
      and b.subject=old.identity_data->>'sub' and b.status='active';
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;
revoke execute on function public.directory_identity_unlinked() from public, anon, authenticated;
create trigger directory_identity_unlinked after delete or update on auth.identities
  for each row execute function public.directory_identity_unlinked();

-- Before sign-in the app needs only routing metadata, never operator settings,
-- client secrets, local users or directory contents. No configured authority
-- keeps ordinary standalone/native sign-in unchanged.
create function public.public_identity_authority() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if public.mcp_is_delegated() then raise exception 'native client required'; end if;
  return (select jsonb_build_object('installation_id', i.installation_id,
    'kind', a.kind, 'issuer', a.issuer, 'provider', a.oidc_provider)
    from public.installation_identity i cross join public.identity_authority a
    where a.kind = 'oidc' and a.oidc_provider = 'custom:deskilo');
end;
$$;
revoke execute on function public.public_identity_authority() from public;
grant execute on function public.public_identity_authority() to anon, authenticated;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(299);
