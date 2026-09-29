-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0315 (#1823) -- who sees what of an account, and who may start a
-- conversation with it.
--
-- A person decides, field by field, which audience reads it:
--   identity         -- name and photo            (default my_spaces)
--   about            -- profession and bio        (default nobody)
--   contact_channels -- WhatsApp and e-mail       (default nobody)
--   presence         -- last seen and status text (default nobody)
-- and, separately, `reachability`: who may START an account conversation
-- (default my_spaces).
--
-- Audiences: nobody | my_spaces (anyone sharing an active or paused
-- membership) | chosen_spaces (members of the spaces listed, which must
-- be the person's own) | signed_in (anyone signed in).
--
-- The legacy switch of 0305 stays readable and writable. A stored
-- `account_contact_settings.available` with no audience row keeps the
-- meaning it had when it was chosen: true is `signed_in`, false is
-- `nobody` -- an explicit "not available" is never widened to the new
-- default. Writing it now (`set_contact_availability`) records an
-- audience: true is `signed_in`, false is the default `my_spaces`. `set_visibility('reachability', ...)` keeps `available`
-- in step, so the public page's contact list says the same thing.
--
-- Profession and bio live in `account_about`, not on `profiles`: every
-- space mate may `select *` a profile row (0002), so a column there could
-- never be "nobody". Nothing reads `account_about` directly; the RPCs
-- below project it through the audience.
--
-- The audiences govern what one ACCOUNT reads of another through
-- `visible_account`, the account search and the account messenger.
-- Inside a space, the member directory keeps reading `profiles` under
-- 0002's shared-workspace policy, as before.

create table public.account_field_audience (
  user_id uuid not null references auth.users(id) on delete cascade,
  field text not null check (field in
    ('identity', 'about', 'contact_channels', 'presence', 'reachability')),
  audience text not null check (audience in
    ('nobody', 'my_spaces', 'chosen_spaces', 'signed_in')),
  primary key (user_id, field)
);
select public.ensure_system_columns('account_field_audience');
alter table public.account_field_audience enable row level security;
revoke all on public.account_field_audience from public, anon, authenticated;
create policy mcp_delegated_deny on public.account_field_audience as restrictive for all to authenticated
 using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

create table public.account_field_audience_spaces (
  user_id uuid not null references auth.users(id) on delete cascade,
  field text not null check (field in
    ('identity', 'about', 'contact_channels', 'presence', 'reachability')),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  primary key (user_id, field, workspace_id)
);
select public.ensure_system_columns('account_field_audience_spaces');
alter table public.account_field_audience_spaces enable row level security;
revoke all on public.account_field_audience_spaces from public, anon, authenticated;
create policy mcp_delegated_deny on public.account_field_audience_spaces as restrictive for all to authenticated
 using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create index account_field_audience_spaces_workspace_idx
  on public.account_field_audience_spaces (workspace_id);

create table public.account_about (
  user_id uuid primary key references auth.users(id) on delete cascade,
  profession text not null default '' check (length(profession) <= 120),
  bio text not null default '' check (length(bio) <= 1000)
);
select public.ensure_system_columns('account_about');
alter table public.account_about enable row level security;
revoke all on public.account_about from public, anon, authenticated;
create policy mcp_delegated_deny on public.account_about as restrictive for all to authenticated
 using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── internal helpers (never granted to a client) ─────────────────────

create or replace function public.account_audience_of(p_user uuid, p_field text)
returns text language sql stable security definer set search_path = public as $$
  select coalesce(
    (select a.audience from public.account_field_audience a
      where a.user_id = p_user and a.field = p_field),
    case when p_field = 'reachability' then
      (select case when s.available then 'signed_in' else 'nobody' end
         from public.account_contact_settings s where s.user_id = p_user) end,
    case p_field when 'identity' then 'my_spaces'
                 when 'reachability' then 'my_spaces'
                 else 'nobody' end);
$$;
revoke execute on function public.account_audience_of(uuid, text)
  from public, anon, authenticated;

-- May [p_viewer] read [p_field] of [p_owner]? The owner always may.
create or replace function public.account_field_visible_to(
  p_owner uuid, p_field text, p_viewer uuid
) returns boolean language plpgsql stable security definer set search_path = public as $$
declare v_audience text;
begin
  if p_owner is null or p_viewer is null then return false; end if;
  if p_owner = p_viewer then return true; end if;
  v_audience := public.account_audience_of(p_owner, p_field);
  if v_audience = 'signed_in' then return true; end if;
  if v_audience = 'my_spaces' then
    return exists (
      select 1 from public.members a
        join public.members b on b.workspace_id = a.workspace_id
       where a.user_id = p_owner and b.user_id = p_viewer
         and a.status in ('active', 'paused')
         and b.status in ('active', 'paused'));
  end if;
  if v_audience = 'chosen_spaces' then
    return exists (
      select 1 from public.account_field_audience_spaces s
        join public.members a on a.workspace_id = s.workspace_id
         and a.user_id = p_owner and a.status in ('active', 'paused')
        join public.members b on b.workspace_id = s.workspace_id
         and b.user_id = p_viewer and b.status in ('active', 'paused')
       where s.user_id = p_owner and s.field = p_field);
  end if;
  return false;
end;
$$;
revoke execute on function public.account_field_visible_to(uuid, text, uuid)
  from public, anon, authenticated;

-- The projection of [p_user] restricted to the field names in
-- [p_fields]; a hidden field is ABSENT, never null.
create or replace function public.account_projection(p_user uuid, p_fields text[])
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('user_id', p_user)
    || case when 'identity' = any(p_fields) then jsonb_build_object('identity',
         jsonb_build_object('name', coalesce(p.display_name, ''),
                            'avatar_path', p.avatar_path)) else '{}'::jsonb end
    || case when 'about' = any(p_fields) then jsonb_build_object('about',
         jsonb_build_object('profession', coalesce(a.profession, ''),
                            'bio', coalesce(a.bio, ''))) else '{}'::jsonb end
    || case when 'contact_channels' = any(p_fields) then jsonb_build_object('contact_channels',
         jsonb_build_object('whatsapp', coalesce(p.whatsapp, ''),
                            'email', coalesce(p.email, ''))) else '{}'::jsonb end
    || case when 'presence' = any(p_fields) then jsonb_build_object('presence',
         jsonb_build_object('last_seen_at', p.last_seen_at,
                            'status_text', coalesce(p.status_text, ''))) else '{}'::jsonb end
  from (select 1) one
  left join public.profiles p on p.id = p_user
  left join public.account_about a on a.user_id = p_user;
$$;
revoke execute on function public.account_projection(uuid, text[])
  from public, anon, authenticated;

-- Writes one audience; `available` follows reachability.
create or replace function public.write_account_audience(
  p_user uuid, p_field text, p_audience text, p_workspaces uuid[]
) returns void language plpgsql security definer set search_path = public as $$
begin
  if p_user is null or p_user is distinct from auth.uid() then
    raise exception 'not authenticated';
  end if;
  insert into public.account_field_audience (user_id, field, audience)
  values (p_user, p_field, p_audience)
  on conflict (user_id, field) do update set audience = excluded.audience;
  delete from public.account_field_audience_spaces
   where user_id = p_user and field = p_field;
  if p_audience = 'chosen_spaces' then
    insert into public.account_field_audience_spaces (user_id, field, workspace_id)
    select distinct p_user, p_field, w from unnest(p_workspaces) w;
  end if;
  if p_field = 'reachability' then
    insert into public.account_contact_settings (user_id, available)
    values (p_user, p_audience = 'signed_in')
    on conflict (user_id) do update set available = excluded.available
     where public.account_contact_settings.available is distinct from excluded.available;
  end if;
end;
$$;
revoke execute on function public.write_account_audience(uuid, text, text, uuid[])
  from public, anon, authenticated;

-- ── client RPCs ─────────────────────────────────────────────────────

create or replace function public.my_visibility()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_me uuid := auth.uid();
begin
  perform public.mcp_require_native();
  return jsonb_build_object(
    'fields', (select jsonb_object_agg(f, jsonb_build_object(
                 'audience', public.account_audience_of(v_me, f),
                 'workspaces', coalesce((select jsonb_agg(s.workspace_id order by s.workspace_id)
                                           from public.account_field_audience_spaces s
                                          where s.user_id = v_me and s.field = f), '[]'::jsonb)))
                 from unnest(array['identity', 'about', 'contact_channels', 'presence']) f),
    'reachability', jsonb_build_object(
                 'audience', public.account_audience_of(v_me, 'reachability'),
                 'workspaces', coalesce((select jsonb_agg(s.workspace_id order by s.workspace_id)
                                           from public.account_field_audience_spaces s
                                          where s.user_id = v_me and s.field = 'reachability'), '[]'::jsonb)),
    'about', coalesce((select jsonb_build_object('profession', a.profession, 'bio', a.bio)
                         from public.account_about a where a.user_id = v_me),
                      jsonb_build_object('profession', '', 'bio', '')));
end;
$$;
revoke execute on function public.my_visibility() from public, anon;
grant execute on function public.my_visibility() to authenticated;

create or replace function public.set_visibility(
  p_field text, p_audience text, p_workspaces uuid[] default null
) returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.mcp_require_native();
  if p_field is null or p_field not in
     ('identity', 'about', 'contact_channels', 'presence', 'reachability') then
    raise exception 'unknown field';
  end if;
  if p_audience is null or p_audience not in
     ('nobody', 'my_spaces', 'chosen_spaces', 'signed_in') then
    raise exception 'unknown audience';
  end if;
  if p_audience = 'chosen_spaces' then
    if coalesce(cardinality(p_workspaces), 0) = 0 then
      raise exception 'choose at least one space';
    end if;
    if cardinality(p_workspaces) > 200 or exists (
         select 1 from unnest(p_workspaces) w
          where w is null or not exists (
            select 1 from public.members m
             where m.workspace_id = w and m.user_id = auth.uid()
               and m.status in ('active', 'paused'))) then
      raise exception 'choose spaces you belong to';
    end if;
  end if;
  perform public.write_account_audience(auth.uid(), p_field, p_audience, p_workspaces);
end;
$$;
revoke execute on function public.set_visibility(text, text, uuid[]) from public, anon;
grant execute on function public.set_visibility(text, text, uuid[]) to authenticated;

create or replace function public.set_my_about(p_profession text, p_bio text)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.mcp_require_native();
  if length(btrim(coalesce(p_profession, ''))) > 120
     or length(btrim(coalesce(p_bio, ''))) > 1000 then
    raise exception 'about text too long';
  end if;
  insert into public.account_about (user_id, profession, bio)
  values (auth.uid(), btrim(coalesce(p_profession, '')), btrim(coalesce(p_bio, '')))
  on conflict (user_id) do update
    set profession = excluded.profession, bio = excluded.bio;
end;
$$;
revoke execute on function public.set_my_about(text, text) from public, anon;
grant execute on function public.set_my_about(text, text) to authenticated;

create or replace function public.visible_account(p_user_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_fields text[];
begin
  perform public.mcp_require_native();
  if p_user_id is null then raise exception 'account unavailable'; end if;
  select coalesce(array_agg(f), '{}') into v_fields
    from unnest(array['identity', 'about', 'contact_channels', 'presence']) f
   where public.account_field_visible_to(p_user_id, f, auth.uid());
  return public.account_projection(p_user_id, v_fields)
    || jsonb_build_object('can_message',
         p_user_id <> auth.uid()
         and (public.account_field_visible_to(p_user_id, 'reachability', auth.uid())
              or exists (select 1 from public.account_conversations c
                          where c.user_a = least(auth.uid(), p_user_id)
                            and c.user_b = greatest(auth.uid(), p_user_id))));
end;
$$;
revoke execute on function public.visible_account(uuid) from public, anon;
grant execute on function public.visible_account(uuid) to authenticated;

-- What an audience would see of ME: `signed_in` = a stranger who signed
-- in; `my_spaces` = a member of a space the field is shared with;
-- `nobody` = what only I see (everything).
create or replace function public.preview_my_account(p_as text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_seen text[];
  v_fields text[];
begin
  perform public.mcp_require_native();
  if p_as is null or p_as not in ('my_spaces', 'signed_in', 'nobody') then
    raise exception 'unknown audience';
  end if;
  v_seen := case p_as
    when 'signed_in' then array['signed_in']
    when 'my_spaces' then array['my_spaces', 'chosen_spaces', 'signed_in']
    else array['nobody', 'my_spaces', 'chosen_spaces', 'signed_in'] end;
  select coalesce(array_agg(f), '{}') into v_fields
    from unnest(array['identity', 'about', 'contact_channels', 'presence']) f
   where public.account_audience_of(v_me, f) = any(v_seen);
  return public.account_projection(v_me, v_fields)
    || jsonb_build_object('can_message',
         p_as <> 'nobody'
         and public.account_audience_of(v_me, 'reachability') = any(v_seen));
end;
$$;
revoke execute on function public.preview_my_account(text) from public, anon;
grant execute on function public.preview_my_account(text) to authenticated;

-- ── 0305's account RPCs honour reachability ─────────────────────────

create or replace function public.my_contact_availability() returns boolean
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.mcp_require_native();
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  return public.account_audience_of(auth.uid(), 'reachability') = 'signed_in';
end;
$$;

create or replace function public.set_contact_availability(p_available boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public.mcp_require_native();
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  perform public.write_account_audience(auth.uid(), 'reachability',
    case when coalesce(p_available, false) then 'signed_in' else 'my_spaces' end, null);
end;
$$;

create or replace function public.search_available_accounts(p_query text, p_before uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public.mcp_require_native();
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if p_query is null or length(btrim(p_query)) not between 2 and 100 then return '[]'::jsonb; end if;
  return coalesce((select jsonb_agg(x) from (
    select p.id, p.display_name as name
      from public.profiles p
     where p.id <> auth.uid()
       and position(lower(btrim(p_query)) in lower(p.display_name)) > 0
       and (p_before is null or p.id > p_before)
       and public.account_field_visible_to(p.id, 'reachability', auth.uid())
     order by p.id limit 50) x), '[]'::jsonb);
end;
$$;

create or replace function public.send_account_message(p_recipient uuid, p_body text, p_expected_account uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_a uuid; v_b uuid;
begin
  perform public.mcp_require_native();
  if auth.uid() is null or p_expected_account is distinct from auth.uid() then raise exception 'account changed'; end if;
  if p_recipient is null or p_recipient = auth.uid() or p_body is null
     or length(btrim(p_body)) not between 1 and 4000 then raise exception 'invalid message'; end if;
  v_a := least(auth.uid(), p_recipient); v_b := greatest(auth.uid(), p_recipient);
  perform pg_advisory_xact_lock(hashtextextended(v_a::text || v_b::text, 1791));
  select id into v_id from public.account_conversations where user_a = v_a and user_b = v_b;
  if v_id is null then
    -- #1823: the recipient's reachability audience decides who may START.
    if not public.account_field_visible_to(p_recipient, 'reachability', auth.uid()) then
      raise exception 'recipient unavailable';
    end if;
    insert into public.account_conversations (user_a, user_b) values (v_a, v_b) returning id into v_id;
  end if;
  -- Bounded native inbox traffic. No public listing or messaging role grants.
  if (select count(*) from public.account_messages
       where author_id = auth.uid() and created_at > now() - interval '1 minute') >= 30 then
    raise exception 'message limit reached';
  end if;
  insert into public.account_messages (conversation_id, author_id, body) values (v_id, auth.uid(), btrim(p_body));
  update public.account_conversations set updated_at = now() where id = v_id;
  return v_id;
end;
$$;

-- CREATE OR REPLACE keeps 0305's grants; restated here all the same so
-- the file that creates a body is the file that says who may call it.
revoke execute on function public.my_contact_availability() from public, anon;
grant execute on function public.my_contact_availability() to authenticated;
revoke execute on function public.set_contact_availability(boolean) from public, anon;
grant execute on function public.set_contact_availability(boolean) to authenticated;
revoke execute on function public.search_available_accounts(text, uuid) from public, anon;
grant execute on function public.search_available_accounts(text, uuid) to authenticated;
revoke execute on function public.send_account_message(uuid, text, uuid) from public, anon;
grant execute on function public.send_account_message(uuid, text, uuid) to authenticated;

-- ── the subject-access export carries the choices ───────────────────
do $export$
declare
  v_def text;
  v_anchor text := $a$    'exported_at', now(),$a$;
begin
  v_def := pg_get_functiondef('public.export_my_data(uuid)'::regprocedure);
  if position(v_anchor in v_def) = 0 then raise exception '0315: export anchor missing'; end if;
  execute replace(v_def, v_anchor, $a$    'exported_at', now(),
    'account_field_audience', (select coalesce(jsonb_agg(to_jsonb(a)), '[]'::jsonb) from public.account_field_audience a where a.user_id = auth.uid()),
    'account_field_audience_spaces', (select coalesce(jsonb_agg(to_jsonb(s)), '[]'::jsonb) from public.account_field_audience_spaces s where s.user_id = auth.uid()),
    'account_about', (select to_jsonb(a) from public.account_about a where a.user_id = auth.uid()),$a$);
end;
$export$;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(315);
