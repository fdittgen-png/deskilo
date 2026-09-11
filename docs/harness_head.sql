do $harness$
declare
  v text := '';
  a  uuid := '04009918-b896-40e5-8fd0-10e86cc10885';  -- owner of wa
  wa uuid := '5ffea179-71ed-4f1e-801f-5106b5ac0dc5';
  b  uuid := '568c956f-5cfd-4bad-a41f-2f5f236efeb9';  -- owner of wb, no rights on wa
  wb uuid := '53d816ea-8543-4862-beae-1dd8f8be11c4';
  c  uuid := 'bd057128-159c-4e89-91ad-8178c9890f09';  -- member of NEITHER workspace
  tpl uuid; n int; plan jsonb; src jsonb; pols int;
begin
  execute $mig$
-- SPDX-License-Identifier: 0BSD
-- 0198 — #1120: the template library, written so that a grant can never
-- be the thing that proves access.
--
-- 0196 shipped `workspace_templates` with the `visibility` column
-- already in place and a read policy that admits only `builtin` and
-- `public`, so a private row is refused from the day the value exists.
-- This migration adds the rows a person can own — a template made from
-- their own floor plan — and the invitations that let somebody else use
-- one. That is the moment the table stops being a catalog and becomes a
-- sharing surface, and it is the shape that has to be got right first.
--
-- ── the failure this migration is written against ──────────────────
--
-- A security review of a sibling app (Sparkilo 6.0.5, F-Droid !42093)
-- found a share table whose insert policy read, in effect,
-- `owner_id = auth.uid()`. That predicate proves who WROTE the grant
-- row. It proves nothing about the resource the row points at. Anyone
-- holding a trip id could write a formally valid grant naming
-- themselves as both owner and recipient, and the shared-read policy —
-- which matched on trip id and recipient and never compared the trip's
-- real owner — then evaluated to true.
--
-- Two rules come out of it, and both are structural here rather than
-- careful:
--
--   1. There is NO client insert, update or delete policy on the grant
--      table. Not a narrow one — none. Grants are created by definer
--      functions that check ownership of the TEMPLATE before they write
--      anything. `test/lint/grant_table_policy_test.dart` fails the
--      build if a later migration adds one.
--   2. Nothing is readable because a grant row says so. Every read goes
--      through `workspace_template_readable`, which starts from the
--      template, reads its owner and its visibility, and only then asks
--      whether a grant exists. A stale grant on a template whose owner
--      set it back to private grants nothing.
--
-- ── and the disclosure that is not about policies ──────────────────
--
-- Publishing a template publishes a snapshot of a real workspace. The
-- export carries the owner's prices, the storage paths of their plan
-- background and plan images, and the name of their site — which in
-- this product is frequently a street address. None of that is what a
-- template is for. `strip_template_plan` removes all of it before the
-- row is written, so an owner cannot publish those by accident, and the
-- stripping happens server-side where a client cannot skip it.

-- ── who owns a template ────────────────────────────────────────────
alter table public.workspace_templates
  add column if not exists owner_workspace_id uuid
    references public.workspaces(id) on delete cascade;

-- `builtin` ships with the product and belongs to nobody; everything
-- else belongs to exactly one workspace. Stated as an equivalence so
-- that neither half can drift: an owned builtin and an ownerless private
-- template are both refused.
alter table public.workspace_templates
  drop constraint if exists workspace_templates_ownership;
alter table public.workspace_templates
  add constraint workspace_templates_ownership check (
    (visibility = 'builtin') = (owner_workspace_id is null));

-- The key was globally unique, which was right while every row was a
-- builtin and is wrong the moment two owners both call their template
-- 'studio'. A builtin key stays globally unique because the client asks
-- for 'tiny' by name.
alter table public.workspace_templates
  drop constraint if exists workspace_templates_key_key;
create unique index if not exists workspace_templates_builtin_key
  on public.workspace_templates (key) where owner_workspace_id is null;
create unique index if not exists workspace_templates_owner_key
  on public.workspace_templates (owner_workspace_id, key)
  where owner_workspace_id is not null;

-- ── the invitations ────────────────────────────────────────────────
-- By ADDRESS, not by user id, for two reasons. An owner inviting a
-- colleague knows their e-mail and not their uuid; and resolving an
-- address to an account inside the function would answer "is there an
-- account at this address?" for anyone willing to create a workspace,
-- which is an enumeration oracle we would be building on purpose. The
-- grant is written whether or not anybody holds that address today, and
-- it starts working when they sign up.
create table if not exists public.workspace_template_grants (
  id            uuid primary key default gen_random_uuid(),
  template_id   uuid not null
                references public.workspace_templates(id) on delete cascade,
  -- Stored lower-cased; compared lower-cased. Addresses are handed over
  -- verbally and typed with capitals.
  grantee_email text not null
                check (grantee_email = lower(grantee_email)
                       and position('@' in grantee_email) > 1
                       and char_length(grantee_email) <= 320),
  unique (template_id, grantee_email)
);
select public.ensure_system_columns('workspace_template_grants');
alter table public.workspace_template_grants enable row level security;

-- ── the one predicate ──────────────────────────────────────────────
-- Definer, so that it reads `workspace_templates` without re-entering
-- that table's own policy — and so that the policy and the RPCs share
-- ONE definition of "may read this template". Two copies of an access
-- rule is the drift 0195 spent a migration removing from the permission
-- catalog; an access rule is a worse thing to keep two copies of.
--
-- Note the ORDER of the clauses. It starts from the template — its
-- owner, its visibility — and reaches a grant last, and only for a
-- template whose owner has said `shared`. A grant row on its own is
-- never a reason for anything.
create or replace function public.holds_template_grant(p_template_id uuid)
returns boolean language sql stable security definer set search_path = public as $fn$
  select exists (
    select 1
      from public.workspace_template_grants g
     where g.template_id = p_template_id
       and g.grantee_email <> ''
       and g.grantee_email in (
             lower(coalesce(auth.email(), '')),
             lower(coalesce((select p.email from public.profiles p
                              where p.id = auth.uid()), ''))
           )
  );
$fn$;
revoke execute on function public.holds_template_grant(uuid) from public, anon;

create or replace function public.workspace_template_readable(p_template_id uuid)
returns boolean language sql stable security definer set search_path = public as $fn$
  select exists (
    select 1 from public.workspace_templates t
     where t.id = p_template_id
       and auth.uid() is not null
       and (
         t.visibility in ('builtin', 'public')
         or (t.owner_workspace_id is not null
             and public.is_owner_of(t.owner_workspace_id))
         or (t.visibility = 'shared' and public.holds_template_grant(t.id))
       ));
$fn$;
revoke execute on function public.workspace_template_readable(uuid) from public, anon;

create or replace function public.owns_workspace_template(p_template_id uuid)
returns boolean language sql stable security definer set search_path = public as $fn$
  select exists (
    select 1 from public.workspace_templates t
     where t.id = p_template_id
       and t.owner_workspace_id is not null
       and public.is_owner_of(t.owner_workspace_id));
$fn$;
revoke execute on function public.owns_workspace_template(uuid) from public, anon;

-- ── the policies ───────────────────────────────────────────────────
drop policy if exists workspace_templates_read on public.workspace_templates;
create policy workspace_templates_read on public.workspace_templates
  for select to authenticated
  using (public.workspace_template_readable(id));

-- A grant row is visible to the person it names and to the template's
-- owner. It is NOT visible to the other people invited to the same
-- template: who else an owner shared with is the owner's business.
drop policy if exists workspace_template_grants_read
  on public.workspace_template_grants;
create policy workspace_template_grants_read
  on public.workspace_template_grants
  for select to authenticated
  using (
    grantee_email in (
      lower(coalesce(auth.email(), '')),
      lower(coalesce((select p.email from public.profiles p
                       where p.id = auth.uid()), ''))
    )
    or public.owns_workspace_template(template_id)
  );
-- There is deliberately no insert, update or delete policy. See the
-- header, and `test/lint/grant_table_policy_test.dart`.

-- ── what a published snapshot may contain ──────────────────────────
-- Geometry, names, seat amenities and accessory names. Not money, not
-- the owner's storage paths, not their site.
--
-- The images matter more than they look. `merge_floor_plan` rewrites a
-- stored path's first segment to the TARGET workspace and returns the
-- pair as a copy job, so a template that kept its images would have the
-- applying workspace ask the storage layer to copy files out of a
-- stranger's prefix. Emptying them here means that job is never
-- produced.
create or replace function public.strip_template_plan(p_tree jsonb)
returns jsonb language plpgsql immutable as $fn$
declare
  v_out jsonb := '[]'::jsonb;
  v_l jsonb; v_o jsonb; v_d jsonb;
  v_offices jsonb; v_desks jsonb;
begin
  if p_tree is null or jsonb_typeof(p_tree) <> 'array' then
    return '[]'::jsonb;
  end if;
  for v_l in select value from jsonb_array_elements(p_tree) loop
    v_offices := '[]'::jsonb;
    for v_o in select value
                 from jsonb_array_elements(coalesce(v_l->'offices', '[]'::jsonb)) loop
      v_desks := '[]'::jsonb;
      for v_d in select value
                   from jsonb_array_elements(coalesce(v_o->'desks', '[]'::jsonb)) loop
        v_desks := v_desks
          || jsonb_build_array(v_d || jsonb_build_object('price_cents', 0));
      end loop;
      v_offices := v_offices || jsonb_build_array(
        (v_o - 'desks')
        || jsonb_build_object('price_cents', 0, 'desks', v_desks));
    end loop;
    v_out := v_out || jsonb_build_array(
      (v_l - 'offices' - 'images' - 'site' - 'background_path')
      || jsonb_build_object(
           'price_cents', 0,
           'background_path', '',
           'images', '[]'::jsonb,
           'offices', v_offices));
  end loop;
  return v_out;
end $fn$;

-- ── publishing ─────────────────────────────────────────────────────
create or replace function public.save_workspace_as_template(
  p_workspace_id uuid,
  p_key          text,
  p_name         text,
  p_description  text default '',
  p_visibility   text default 'private'
) returns uuid language plpgsql security definer set search_path = public as $fn$
declare v_plan jsonb; v_id uuid;
begin
  if auth.uid() is null or not public.is_owner_of(p_workspace_id) then
    raise exception 'only an owner publishes a template from a workspace';
  end if;
  -- `builtin` is the product's own catalog and is not for sale here.
  if p_visibility not in ('private', 'shared', 'public') then
    raise exception 'a workspace cannot publish a % template', p_visibility;
  end if;
  if p_key !~ '^[a-z][a-z0-9_]{0,39}$' then
    raise exception 'a template key is lower-case letters, digits and underscores';
  end if;
  if coalesce(trim(p_name), '') = '' then
    raise exception 'a template needs a name';
  end if;

  v_plan := public.strip_template_plan(public.export_floor_plan(p_workspace_id));
  if jsonb_array_length(v_plan) = 0 then
    raise exception 'there is no floor plan to publish yet';
  end if;

  insert into public.workspace_templates
    (key, name, description, visibility, owner_workspace_id, floor_plan)
  values
    (p_key, left(trim(p_name), 80), left(coalesce(p_description, ''), 400),
     p_visibility, p_workspace_id, v_plan)
  on conflict (owner_workspace_id, key) where owner_workspace_id is not null
  do update set name        = excluded.name,
                description = excluded.description,
                visibility  = excluded.visibility,
                floor_plan  = excluded.floor_plan
  returning id into v_id;
  return v_id;
end $fn$;
revoke execute on function
  public.save_workspace_as_template(uuid, text, text, text, text)
  from public, anon;

create or replace function public.set_workspace_template_visibility(
  p_template_id uuid, p_visibility text
) returns void language plpgsql security definer set search_path = public as $fn$
begin
  if not public.owns_workspace_template(p_template_id) then
    raise exception 'only the owner of a template changes who may see it';
  end if;
  if p_visibility not in ('private', 'shared', 'public') then
    raise exception 'unknown visibility %', p_visibility;
  end if;
  update public.workspace_templates
     set visibility = p_visibility
   where id = p_template_id;
end $fn$;
revoke execute on function
  public.set_workspace_template_visibility(uuid, text) from public, anon;

create or replace function public.delete_workspace_template(p_template_id uuid)
returns void language plpgsql security definer set search_path = public as $fn$
begin
  if not public.owns_workspace_template(p_template_id) then
    raise exception 'only the owner of a template removes it';
  end if;
  delete from public.workspace_templates where id = p_template_id;
end $fn$;
revoke execute on function
  public.delete_workspace_template(uuid) from public, anon;

-- ── the invitations, written only by the template's owner ──────────
create or replace function public.grant_workspace_template(
  p_template_id uuid, p_email text
) returns uuid language plpgsql security definer set search_path = public as $fn$
declare v_email text; v_id uuid;
begin
  -- The ownership check comes FIRST and it is about the TEMPLATE, not
  -- about the row being written. This is the whole point of the
  -- migration.
  if not public.owns_workspace_template(p_template_id) then
    raise exception 'only the owner of a template invites people to it';
  end if;
  v_email := lower(trim(coalesce(p_email, '')));
  if position('@' in v_email) < 2 or char_length(v_email) > 320 then
    raise exception 'that is not an e-mail address';
  end if;
  insert into public.workspace_template_grants (template_id, grantee_email)
  values (p_template_id, v_email)
  on conflict (template_id, grantee_email) do update
     set grantee_email = excluded.grantee_email
  returning id into v_id;
  return v_id;
end $fn$;
revoke execute on function
  public.grant_workspace_template(uuid, text) from public, anon;

create or replace function public.revoke_workspace_template_grant(
  p_template_id uuid, p_email text
) returns void language plpgsql security definer set search_path = public as $fn$
begin
  if not public.owns_workspace_template(p_template_id) then
    raise exception 'only the owner of a template withdraws an invitation';
  end if;
  delete from public.workspace_template_grants
   where template_id = p_template_id
     and grantee_email = lower(trim(coalesce(p_email, '')));
end $fn$;
revoke execute on function
  public.revoke_workspace_template_grant(uuid, text) from public, anon;

-- ── applying one ───────────────────────────────────────────────────
-- 0196's version took a key and looked it up with no visibility check
-- at all — it is a definer, so RLS did not apply, and once owned rows
-- exist that would have applied anybody's private template to your own
-- workspace by guessing its key. Two things change: the key form now
-- only ever finds a BUILTIN, and there is an id form that asks
-- `workspace_template_readable` — the same predicate the select policy
-- uses, so the two cannot disagree about what you may see.
create or replace function public.apply_workspace_template(
  p_workspace_id uuid, p_key text
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare v_tpl public.workspace_templates;
begin
  if auth.uid() is null or not public.is_owner_of(p_workspace_id) then
    raise exception 'only an owner configures a workspace from a template';
  end if;
  select * into v_tpl from public.workspace_templates
   where key = p_key and owner_workspace_id is null;
  if not found then raise exception 'unknown template %', p_key; end if;
  return public.merge_floor_plan(p_workspace_id, v_tpl.floor_plan);
end $fn$;
revoke execute on function
  public.apply_workspace_template(uuid, text) from public, anon;

create or replace function public.apply_workspace_template(
  p_workspace_id uuid, p_template_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare v_tpl public.workspace_templates;
begin
  if auth.uid() is null or not public.is_owner_of(p_workspace_id) then
    raise exception 'only an owner configures a workspace from a template';
  end if;
  -- Readable, and not merely existing. A template id is a uuid and is
  -- not guessable in practice, but "you would have to guess it" has
  -- never been an authorization rule.
  if not public.workspace_template_readable(p_template_id) then
    raise exception 'unknown template';
  end if;
  select * into v_tpl from public.workspace_templates where id = p_template_id;
  return public.merge_floor_plan(p_workspace_id, v_tpl.floor_plan);
end $fn$;
revoke execute on function
  public.apply_workspace_template(uuid, uuid) from public, anon;

-- ── what an owner can see of their own library ─────────────────────
-- The grants of one template, for the sharing sheet. It exists so the
-- screen does not have to read the grants table and get the predicate
-- subtly different from the policy.
create or replace function public.workspace_template_grantees(p_template_id uuid)
returns setof text language plpgsql security definer set search_path = public as $fn$
begin
  if not public.owns_workspace_template(p_template_id) then
    raise exception 'only the owner of a template sees who it was shared with';
  end if;
  return query
    select g.grantee_email from public.workspace_template_grants g
     where g.template_id = p_template_id
     order by g.grantee_email;
end $fn$;
revoke execute on function
  public.workspace_template_grantees(uuid) from public, anon;
  $mig$;

  -- The source really does carry what we claim to strip, or the strip
  -- assertions below prove nothing. Everything here is rolled back with
  -- the rest of the harness.
  update public.levels set price_cents = 12345, background_path = wa::text || '/bg.png'
   where workspace_id = wa;
  update public.offices set price_cents = 6789
   where level_id in (select id from public.levels where workspace_id = wa);
  update public.desks set price_cents = 4242
   where office_id in (select o.id from public.offices o
                        join public.levels l on l.id = o.level_id
                       where l.workspace_id = wa);
  insert into public.plan_images (workspace_id, level_id, x, y, w, h, storage_path)
  select wa, l.id, 1, 1, 10, 10, wa::text || '/logo.png'
    from public.levels l where l.workspace_id = wa limit 1;
  src := public.export_floor_plan(wa);
  v := v || format('source levels=%s priced=%s imaged=%s bg=%s; ',
        jsonb_array_length(src),
        (select count(*) from jsonb_array_elements(src) l
          where (l->>'price_cents')::int <> 0
             or exists (select 1 from jsonb_array_elements(coalesce(l->'offices','[]'::jsonb)) o
                         where (o->>'price_cents')::int <> 0
                            or exists (select 1 from jsonb_array_elements(coalesce(o->'desks','[]'::jsonb)) d
                                        where (d->>'price_cents')::int <> 0))),
        (select count(*) from jsonb_array_elements(src) l
          where jsonb_array_length(coalesce(l->'images','[]'::jsonb)) > 0),
        (select count(*) from jsonb_array_elements(src) l
          where coalesce(l->>'background_path','') <> ''));

  -- ── A publishes a PRIVATE template from A's own workspace ────────
  perform set_config('request.jwt.claims',
    json_build_object('sub', a::text, 'email', 'a@harness.test')::text, true);
  perform set_config('role', 'authenticated', true);
  tpl := public.save_workspace_as_template(wa, 'harness_tpl', 'Harness', '', 'private');
  v := v || format('A published=%s; ', tpl is not null);

  select count(*) into n from public.workspace_templates where id = tpl;
  v := v || format('A reads own private=%s(want 1); ', n);

  -- ── B, a stranger to wa, holding the template id ─────────────────
  perform set_config('request.jwt.claims',
    json_build_object('sub', b::text, 'email', 'b@harness.test')::text, true);
  select count(*) into n from public.workspace_templates where id = tpl;
  v := v || format('B reads A private=%s(want 0); ', n);

  -- THE S01 SEQUENCE: B writes a grant naming B, pointing at A's row.
  begin
    insert into public.workspace_template_grants (template_id, grantee_email)
    values (tpl, 'b@harness.test');
    v := v || 'B DIRECT INSERT ALLOWED(BAD); ';
  exception when others then
    v := v || format('B direct insert refused ok (%s); ', left(SQLERRM, 40));
  end;
  select count(*) into n from public.workspace_templates where id = tpl;
  v := v || format('B reads after insert attempt=%s(want 0); ', n);

  begin
    perform public.apply_workspace_template(wb, tpl);
    v := v || 'B APPLIED A PRIVATE TEMPLATE(BAD); ';
  exception when others then
    v := v || format('B apply refused ok (%s); ', left(SQLERRM, 30));
  end;
  begin
    perform public.grant_workspace_template(tpl, 'b@harness.test');
    v := v || 'B GRANTED ITSELF(BAD); ';
  exception when others then
    v := v || format('B self-grant refused ok (%s); ', left(SQLERRM, 30));
  end;
  begin
    perform public.set_workspace_template_visibility(tpl, 'public');
    v := v || 'B PUBLISHED A STRANGER TEMPLATE(BAD); ';
  exception when others then
    v := v || format('B visibility refused ok; ');
  end;
  begin
    perform public.delete_workspace_template(tpl);
    v := v || 'B DELETED A STRANGER TEMPLATE(BAD); ';
  exception when others then
    v := v || format('B delete refused ok; ');
  end;

  -- ── A invites B, but the template is still PRIVATE ───────────────
  perform set_config('request.jwt.claims',
    json_build_object('sub', a::text, 'email', 'a@harness.test')::text, true);
  perform public.grant_workspace_template(tpl, 'B@Harness.TEST');

  perform set_config('request.jwt.claims',
    json_build_object('sub', b::text, 'email', 'b@harness.test')::text, true);
  select count(*) into n from public.workspace_templates where id = tpl;
  v := v || format('B reads granted-but-private=%s(want 0); ', n);

  -- ── A sets it to SHARED ──────────────────────────────────────────
  perform set_config('request.jwt.claims',
    json_build_object('sub', a::text, 'email', 'a@harness.test')::text, true);
  perform public.set_workspace_template_visibility(tpl, 'shared');

  perform set_config('request.jwt.claims',
    json_build_object('sub', b::text, 'email', 'b@harness.test')::text, true);
  select count(*) into n from public.workspace_templates where id = tpl;
  v := v || format('B reads shared+granted=%s(want 1); ', n);
  begin
    perform public.apply_workspace_template(wb, tpl);
    v := v || 'B applies when invited ok; ';
  exception when others then
    v := v || format('B APPLY REFUSED WHEN INVITED(BAD %s); ', left(SQLERRM, 30));
  end;

  -- ── C was never invited ──────────────────────────────────────────
  perform set_config('request.jwt.claims',
    json_build_object('sub', c::text, 'email', 'c@harness.test')::text, true);
  select count(*) into n from public.workspace_templates where id = tpl;
  v := v || format('C reads shared=%s(want 0); ', n);

  -- ── A withdraws the invitation ───────────────────────────────────
  perform set_config('request.jwt.claims',
    json_build_object('sub', a::text, 'email', 'a@harness.test')::text, true);
  perform public.revoke_workspace_template_grant(tpl, 'b@harness.test');
  perform set_config('request.jwt.claims',
    json_build_object('sub', b::text, 'email', 'b@harness.test')::text, true);
  select count(*) into n from public.workspace_templates where id = tpl;
  v := v || format('B reads after revoke=%s(want 0); ', n);

  -- ── the builtin still works for anybody ──────────────────────────
  begin
    perform public.apply_workspace_template(wb, 'tiny');
    v := v || 'builtin by key ok; ';
  exception when others then
    v := v || format('BUILTIN BROKE(%s); ', left(SQLERRM, 40));
  end;
  begin
    perform public.apply_workspace_template(wb, 'harness_tpl');
    v := v || 'OWNED TEMPLATE REACHED BY KEY(BAD); ';
  exception when others then
    v := v || 'owned template not reachable by key ok; ';
  end;

  -- ── what was published ───────────────────────────────────────────
  perform set_config('role', 'postgres', true);
  select floor_plan into plan from public.workspace_templates where id = tpl;
  v := v || format('published levels=%s prices=%s images=%s bg=%s site=%s; ',
    jsonb_array_length(plan),
    (select count(*) from jsonb_array_elements(plan) l
      where (l->>'price_cents')::int <> 0
         or exists (select 1 from jsonb_array_elements(coalesce(l->'offices','[]'::jsonb)) o
                     where (o->>'price_cents')::int <> 0
                        or exists (select 1 from jsonb_array_elements(coalesce(o->'desks','[]'::jsonb)) d
                                    where (d->>'price_cents')::int <> 0))),
    (select count(*) from jsonb_array_elements(plan) l
      where jsonb_array_length(coalesce(l->'images','[]'::jsonb)) > 0),
    (select count(*) from jsonb_array_elements(plan) l
      where coalesce(l->>'background_path','') <> ''),
    (select count(*) from jsonb_array_elements(plan) l
      where l ? 'site'));

  -- ── the structural guarantee, read back from the catalog ─────────
  select count(*) into pols from pg_policies
   where schemaname='public' and tablename='workspace_template_grants'
     and cmd in ('INSERT','UPDATE','DELETE','ALL');
  v := v || format('grant write policies=%s(want 0); ', pols);

  raise exception 'HARNESS_RESULTS %', v;
end
$harness$;
