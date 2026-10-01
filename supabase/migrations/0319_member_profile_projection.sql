-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0319 (#1833, checkpoint A) -- what one member reads of another inside
-- a space is a purpose-specific projection, not the `profiles` row.
--
-- The app read a space mate with `select * from profiles`, so every
-- member of a space received every co-member's postal address, VAT id,
-- legal id, phone, identity e-mail, document language and badge PIN hash
-- along with the name and photo the directory actually shows. This adds
-- the projection the app reads instead (field matrix:
-- docs/security/IDENTITY_PROJECTIONS.md):
--
--   community   -- display name, photo path, WhatsApp, status line, last
--                  seen: what the directory, the plans and the kiosk show.
--                  For a current (active/paused) member of the SAME space
--                  as the subject, as profiles_select already allowed.
--   operational -- the identity documents print (PersonalInfo + the
--                  legacy address) and the document language. Only for a
--                  holder of viewPersonalData or issueInvoices IN that
--                  space; membership alone never reaches it.
--   (self)      -- the subject reads both groups of themselves; no
--                  membership is needed for that.
--
-- Never projected: the badge PIN hash, privacy consent, preferences,
-- default space, system columns, person/company/site ids. A column added
-- to `profiles` later is projected by nobody until it is classified here.
--
-- The groups are keyed by purpose, so a client can only take an address
-- out of `operational` -- a field outside its group is not read.
--
-- The badge sign-in PIN hash is the one secret on that row; it moves to
-- its own unreadable table at the end of this file.
--
-- The `profiles_select` table policy is NOT narrowed here: released
-- clients still read the table, and closing it together with the
-- remaining readers (member names, Realtime, old clients) is checkpoint B.

-- ── internal: which purposes the caller may read of [p_subject] ─────
create or replace function public.member_profile_purposes(p_workspace uuid, p_subject uuid)
returns text[] language plpgsql stable security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_purposes text[] := '{}';
begin
  if v_me is null or p_subject is null then return v_purposes; end if;
  if p_subject = v_me then return array['community', 'operational']; end if;
  if p_workspace is null then return v_purposes; end if;
  if not exists (select 1 from public.members m
                  where m.workspace_id = p_workspace and m.user_id = v_me
                    and m.status in ('active', 'paused'))
     or not exists (select 1 from public.members m
                     where m.workspace_id = p_workspace and m.user_id = p_subject
                       and m.status in ('active', 'paused')) then
    return v_purposes;
  end if;
  v_purposes := array['community'];
  if public.has_permission(p_workspace, 'viewPersonalData')
     or public.has_permission(p_workspace, 'issueInvoices') then
    v_purposes := array_append(v_purposes, 'operational');
  end if;
  return v_purposes;
end;
$$;
revoke execute on function public.member_profile_purposes(uuid, uuid)
  from public, anon, authenticated;

-- ── internal: the projection of [p_subject] for [p_purposes] ─────────
-- A purpose not listed is ABSENT from the answer, never null.
create or replace function public.member_profile_projection(p_subject uuid, p_purposes text[])
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('id', p.id, 'purposes', to_jsonb(p_purposes))
    || case when 'community' = any(p_purposes) then jsonb_build_object('community',
         jsonb_build_object(
           'display_name', coalesce(p.display_name, ''),
           'avatar_path', p.avatar_path,
           'whatsapp', coalesce(p.whatsapp, ''),
           'status_text', coalesce(p.status_text, ''),
           'last_seen_at', p.last_seen_at)) else '{}'::jsonb end
    || case when 'operational' = any(p_purposes) then jsonb_build_object('operational',
         jsonb_build_object(
           'courtesy', coalesce(p.courtesy, ''),
           'first_name', coalesce(p.first_name, ''),
           'last_name', coalesce(p.last_name, ''),
           'company', coalesce(p.company, ''),
           'street', coalesce(p.street, ''),
           'postal_code', coalesce(p.postal_code, ''),
           'city', coalesce(p.city, ''),
           'country_code', coalesce(p.country_code, ''),
           'phone', coalesce(p.phone, ''),
           'email', coalesce(p.email, ''),
           'vat_id', coalesce(p.vat_id, ''),
           'legal_id', coalesce(p.legal_id, ''),
           'address', coalesce(p.address, ''),
           'preferred_locale', coalesce(p.preferred_locale, ''))) else '{}'::jsonb end
  from public.profiles p
  where p.id = p_subject;
$$;
revoke execute on function public.member_profile_projection(uuid, text[])
  from public, anon, authenticated;

-- ── client RPC: the space mates the caller may read ──────────────────
-- [p_user_ids] the caller wants; an id the caller may not read is left
-- out of the answer, exactly as the table's policy left its row out.
create or replace function public.member_profiles(p_workspace_id uuid, p_user_ids uuid[])
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public.mcp_require_native();
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if coalesce(cardinality(p_user_ids), 0) > 5000 then raise exception 'too many profiles'; end if;
  return coalesce((
    select jsonb_agg(public.member_profile_projection(s.id, s.purposes) order by s.id)
      from (select u.id, public.member_profile_purposes(p_workspace_id, u.id) as purposes
              from (select distinct x as id from unnest(p_user_ids) x where x is not null) u) s
      join public.profiles p on p.id = s.id
     where cardinality(s.purposes) > 0), '[]'::jsonb);
end;
$$;
revoke execute on function public.member_profiles(uuid, uuid[]) from public, anon;
grant execute on function public.member_profiles(uuid, uuid[]) to authenticated;

-- ── client RPC: what a space mate / an authorized administrator sees
-- of ME -- the same projection function, so the preview cannot differ
-- from what they actually read. Needs no membership.
create or replace function public.preview_my_member_profile(p_as text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public.mcp_require_native();
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if p_as is null or p_as not in ('space_mate', 'personal_data') then
    raise exception 'unknown audience';
  end if;
  return public.member_profile_projection(auth.uid(), case p_as
    when 'space_mate' then array['community']
    else array['community', 'operational'] end);
end;
$$;
revoke execute on function public.preview_my_member_profile(text) from public, anon;
grant execute on function public.preview_my_member_profile(text) to authenticated;

-- ── the badge sign-in PIN hash leaves `profiles` ─────────────────────
-- 0123 stored the bcrypt hash of the badge PIN (#662) on `profiles` and
-- wrote that "no RLS policy exposes" it. profiles_select does: every
-- space mate could select it, and Realtime pushed it to their devices
-- with every row change. A 4-to-8-digit PIN under bcrypt is guessable
-- offline, around the five-attempt lockout. The hash now lives in a
-- table no client can read; the column stays (released clients
-- `select *` the row) and is held empty.
create table public.account_badge_pins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  pin_hash text not null check (pin_hash <> ''),
  pin_set_at timestamptz not null default now()
);
select public.ensure_system_columns('account_badge_pins');
alter table public.account_badge_pins enable row level security;
revoke all on public.account_badge_pins from public, anon, authenticated;
create policy mcp_delegated_deny on public.account_badge_pins as restrictive for all to authenticated
 using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

insert into public.account_badge_pins (user_id, pin_hash, pin_set_at)
select p.id, p.pin_hash, coalesce(p.pin_set_at, now())
  from public.profiles p
 where p.pin_hash <> '';
update public.profiles set pin_hash = '', pin_set_at = null
 where pin_hash <> '' or pin_set_at is not null;
alter table public.profiles add constraint profiles_pin_hash_retired
  check (pin_hash = '' and pin_set_at is null);

create or replace function public.set_badge_pin(p_pin text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  -- 4 to 8 digits. Short enough to type at a door, long enough that the
  -- lockout does the rest of the work.
  if p_pin !~ '^[0-9]{4,8}$' then
    -- the client pins this substring
    raise exception 'the PIN must be 4 to 8 digits';
  end if;
  if p_pin in ('0000','1111','2222','3333','4444','5555','6666','7777',
               '8888','9999','1234','12345','123456','1234567','12345678',
               '4321','0123') then
    -- the client pins this substring
    raise exception 'that PIN is too easy to guess';
  end if;
  insert into public.account_badge_pins (user_id, pin_hash, pin_set_at)
  values (auth.uid(), extensions.crypt(p_pin, extensions.gen_salt('bf', 10)), now())
  on conflict (user_id) do update
    set pin_hash = excluded.pin_hash, pin_set_at = excluded.pin_set_at;
end;
$$;
revoke execute on function public.set_badge_pin(text) from public, anon;
grant execute on function public.set_badge_pin(text) to authenticated;

create or replace function public.clear_badge_pin()
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  delete from public.account_badge_pins where user_id = auth.uid();
  -- Without a PIN nothing may sign in with a tag: clearing the PIN
  -- disarms every badge at once.
  update public.member_badges b
     set auth_enabled = false
    from public.members m
   where b.member_id = m.id and m.user_id = auth.uid()
     and b.auth_enabled;
end;
$$;
revoke execute on function public.clear_badge_pin() from public, anon;
grant execute on function public.clear_badge_pin() to authenticated;

-- Whether the CALLER has a PIN -- a boolean, never the hash.
create or replace function public.has_badge_pin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.account_badge_pins where user_id = auth.uid());
$$;
revoke execute on function public.has_badge_pin() from public, anon;
grant execute on function public.has_badge_pin() to authenticated;

-- badge_auth_verify (service role only) compares against the new table.
do $badge$
declare
  v_def text := pg_get_functiondef('public.badge_auth_verify(text, text)'::regprocedure);
  v_anchor text := $a$  if coalesce(v_profile.pin_hash, '') = ''
     or v_profile.pin_hash <> extensions.crypt(p_pin, v_profile.pin_hash) then$a$;
begin
  if (length(v_def) - length(replace(v_def, v_anchor, ''))) / length(v_anchor) <> 1 then
    raise exception '0319: badge_auth_verify anchor must occur exactly once';
  end if;
  execute replace(v_def, v_anchor, $a$  if coalesce((select k.pin_hash from public.account_badge_pins k where k.user_id = v_member.user_id), '') = ''
     or (select k.pin_hash from public.account_badge_pins k where k.user_id = v_member.user_id)
        <> extensions.crypt(p_pin, (select k.pin_hash from public.account_badge_pins k where k.user_id = v_member.user_id)) then$a$);
end;
$badge$;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(319);
