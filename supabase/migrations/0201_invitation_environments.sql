-- SPDX-License-Identifier: 0BSD
-- 0201 — #1119: whoever invites somebody chooses whether that person
-- reaches production.
--
-- ── the decision this encodes ──────────────────────────────────────
--
-- The issue left a product question open, and it has to be answered
-- before any of this makes sense: does "choose the environments"
-- include PROD-ONLY?
--
-- It does not. This is option B — **dev, or dev and prod** — for three
-- reasons:
--
--   * 0185 states the invariant `prod ⊆ dev` and means it: the dev twin
--     is where an admin rehearses, and somebody who exists in prod but
--     not in dev cannot be rehearsed against. `members_mirror_to_dev`
--     enforces it on every write.
--   * No live row is in exactly one environment. The model already
--     permits dev-only; prod-only has never happened because the paths
--     that add people add them to both.
--   * The real question an admin is asking is not "which of two parallel
--     worlds" — it is "does this person touch production". Two options
--     answer that; three would invent a state nobody wants and drop an
--     invariant introduced eight migrations ago to get it.
--
-- So the invitation carries ONE boolean, and the UI asks one question.
--
-- ── and the hole it must not open ──────────────────────────────────
--
-- `members_prod_access_guard` refuses a prod member whose ROLE does not
-- hold `accessProd`. An invitation that could put somebody in prod
-- regardless would make the invitation a way around the role matrix —
-- the same class as #1080, where a deployment was a way around the
-- permissions.
--
-- It is checked TWICE on purpose. At creation, so an admin is told
-- immediately rather than discovering it when the person redeems; and
-- again at redemption, because the matrix can change in between. The
-- second check does not refuse the join — the person still becomes a
-- member of the dev side, and the event payload records that the prod
-- half was dropped and why. Refusing the whole join would punish the
-- invitee for a decision somebody else changed.

alter table public.invitations
  add column if not exists also_prod boolean not null default false;

comment on column public.invitations.also_prod is
  'Whether redeeming this invitation also makes the person a member of '
  'the prod twin (#1119). Never bypasses members_prod_access_guard.';

-- ── creating one ───────────────────────────────────────────────────
-- The old five-argument signature is DROPPED rather than left beside
-- the new one. An overload whose extra parameter has a default is
-- ambiguous against an exact-arity sibling — PostgreSQL treats both as
-- equally good matches and refuses the call — so leaving it would break
-- every existing five-argument caller, which is the whole client.
drop function if exists public.create_invitation(uuid, boolean, text, text, uuid);

create or replace function public.create_invitation(
  p_workspace_id uuid,
  p_is_admin boolean,
  p_first_name text default '',
  p_last_name text default '',
  p_member_id uuid default null,
  p_also_prod boolean default false
) returns text language plpgsql security definer set search_path = public as $fn$
declare
  v_code text;
  v_member public.members;
  v_ws public.workspaces;
  v_role text;
  v_also boolean := coalesce(p_also_prod, false);
  v_first text := left(coalesce(p_first_name, ''), 120);
  v_last text := left(coalesce(p_last_name, ''), 120);
begin
  if p_is_admin then
    if not public.is_owner_of(p_workspace_id) then
      raise exception 'only owners may invite admins';
    end if;
  elsif not public.is_admin_of(p_workspace_id) then
    raise exception 'only admins may invite members';
  end if;
  if p_member_id is not null then
    select * into v_member from public.members
     where id = p_member_id and workspace_id = p_workspace_id;
    if not found then raise exception 'member not found'; end if;
    if v_member.user_id is not null then raise exception 'profile already claimed'; end if;
    if p_is_admin then raise exception 'a handover grants membership, not admin'; end if;
    if not public.can_manage_managed_profile(p_member_id) then
      raise exception 'not allowed to manage this profile';
    end if;
    if v_first = '' then v_first := left(coalesce((select mi.identity->>'first_name' from public.managed_identities mi where mi.member_id = p_member_id), ''), 120); end if;
    if v_last = '' then v_last := left(coalesce((select mi.identity->>'last_name' from public.managed_identities mi where mi.member_id = p_member_id), ''), 120); end if;
    delete from public.invitations where member_id = p_member_id and redeemed_at is null;
  end if;

  -- The environment half. Only a DEV workspace that has a twin can
  -- offer it: joining a prod workspace already reaches production, and
  -- the mirror adds the dev side by itself.
  if v_also then
    select * into v_ws from public.workspaces where id = p_workspace_id;
    if v_ws.pair_id is null or v_ws.environment <> 'dev' then
      raise exception 'this workspace has no production twin to join';
    end if;
    v_role := case when p_is_admin then 'admin' else 'member' end;
    -- The invitation may not grant what the role matrix withholds.
    if not public.role_holds(
         (select id from public.workspaces
           where pair_id = v_ws.pair_id and environment = 'prod'
             and id <> v_ws.id limit 1),
         v_role, 'accessProd') then
      raise exception
        'the % role has no access to the production workspace', v_role;
    end if;
  end if;

  insert into public.invitations
    (workspace_id, is_admin, invited_first_name, invited_last_name,
     created_by, member_id, also_prod)
  values (p_workspace_id, p_is_admin, v_first, v_last, auth.uid(),
          p_member_id, v_also)
  returning code into v_code;
  return v_code;
end;
$fn$;
revoke execute on function
  public.create_invitation(uuid, boolean, text, text, uuid, boolean)
  from public, anon;

-- ── honouring it on redemption ─────────────────────────────────────
-- An ANCHORED patch, not a re-creation. 0200 already re-created this
-- function once (from the live definition, deliberately); doing it
-- again would be the #1092 shape twice in two migrations, and there is
-- a clean anchor to cut at.
do $patch$
declare v_def text; v_new text; v_anchor text;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'join_workspace';
  if v_def is null then raise exception '0201: join_workspace not found'; end if;

  v_anchor := E'  if exists (select 1 from public.members\n              where id = v_member_id and status = ''pending'')';
  if position(v_anchor in v_def) = 0 then
    raise exception '0201: join_workspace pending-event anchor missing';
  end if;

  v_new := replace(v_def, v_anchor,
    E'  -- #1119 — the environment half of the invitation.\n'
    '  if v_also_prod and v_member_id is not null then\n'
    '    select * into v_ws from public.workspaces where id = ws_id;\n'
    '    if v_ws.pair_id is not null and v_ws.environment = ''dev'' then\n'
    '      select id into v_prod from public.workspaces\n'
    '       where pair_id = v_ws.pair_id and environment = ''prod''\n'
    '         and id <> v_ws.id limit 1;\n'
    '      if v_prod is not null then\n'
    '        -- Re-checked here because the matrix can have changed since\n'
    '        -- the invitation was written. If it no longer holds, the\n'
    '        -- person still joins the dev side and the event says the\n'
    '        -- prod half was dropped — refusing the whole join would\n'
    '        -- punish them for somebody else''s later decision.\n'
    '        if public.role_holds(v_prod,\n'
    '             case when v_admin then ''admin'' else ''member'' end,\n'
    '             ''accessProd'')\n'
    '           and not exists (select 1 from public.members\n'
    '                            where workspace_id = v_prod\n'
    '                              and user_id = auth.uid()) then\n'
    '          insert into public.members\n'
    '            (workspace_id, user_id, is_admin, status, origin)\n'
    '          values (v_prod, auth.uid(), v_admin, ''pending'', ''invited'');\n'
    '          update public.members\n'
    '             set member_number = public.next_document_number(v_prod, ''member'')\n'
    '           where workspace_id = v_prod and user_id = auth.uid()\n'
    '             and member_number = '''';\n'
    '          v_prod_joined := true;\n'
    '        end if;\n'
    '      end if;\n'
    '    end if;\n'
    '  end if;\n'
    '\n' || v_anchor);
  if v_new = v_def then
    raise exception '0201: the join_workspace patch changed nothing';
  end if;

  -- The declarations the inserted block needs.
  v_new := replace(v_new,
    E'  v_target public.members;\n  v_mi jsonb;',
    E'  v_target public.members;\n  v_mi jsonb;\n'
    '  v_also_prod boolean := false;\n'
    '  v_ws public.workspaces;\n'
    '  v_prod uuid;\n'
    '  v_prod_joined boolean := false;');
  if position('v_also_prod boolean' in v_new) = 0 then
    raise exception '0201: the declaration block was not extended';
  end if;

  -- Read the flag off the invitation as it is redeemed.
  v_new := replace(v_new,
    'returning workspace_id, is_admin, member_id into ws_id, v_admin, v_bound;',
    'returning workspace_id, is_admin, member_id, also_prod'
    ' into ws_id, v_admin, v_bound, v_also_prod;');
  if position('v_also_prod;' in v_new) = 0 then
    raise exception '0201: the redemption did not start reading also_prod';
  end if;

  -- And say, in the join event, which environments were actually given.
  v_new := replace(v_new,
    E'jsonb_build_object(''as_admin'', v_admin, ''claimed'', v_bound is not null)',
    E'jsonb_build_object(''as_admin'', v_admin, ''claimed'', v_bound is not null,\n'
    '              ''also_prod_asked'', v_also_prod,\n'
    '              ''also_prod_given'', v_prod_joined)');
  if position('also_prod_given' in v_new) = 0 then
    raise exception '0201: the join event did not learn about the environments';
  end if;

  execute v_new;
end
$patch$;
revoke execute on function public.join_workspace(text) from public, anon;
