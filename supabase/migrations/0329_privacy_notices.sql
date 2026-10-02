-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0329 (#1914) — the privacy notice is a versioned record on the server,
-- and an acknowledgment names the notice it acknowledges.
--
-- 0140 accepted ANY non-empty version string through
-- `accept_privacy_policy`, so a client could record acknowledgment of a
-- notice that was never published, and the profile kept only the last
-- one. From here on:
--
--   * `privacy_notices` holds published notices. A row with no
--     `space_id` is the installation's notice, published by its
--     operator (`is_instance_operator`); a row with one is that space's
--     supplement, published by its owner. One notice per scope is
--     current; publishing a new version supersedes the old one, which
--     stays as history.
--   * The manifest is bounded (`privacy_notice_manifest_valid`): the
--     controller and a rights contact, the retention statement, and per
--     recipient its role, purpose, legal basis, data categories, region,
--     transfer mechanism and whether it is essential. A transfer
--     mechanism may be `unknown` — that is visible to the operator as
--     missing evidence, never invented. A key that looks like a
--     credential is refused: a notice is public to every member.
--   * `accept_privacy_policy` records only the CURRENT installation
--     notice, and every acknowledgment is kept in
--     `privacy_notice_acknowledgments`. A space supplement is
--     acknowledged through `acknowledge_workspace_notice`, by a member of
--     that space only. A new version never opts anybody in.
--   * The notice the app has shipped since 2026-09-20 is seeded as the
--     current installation notice, marked `seeded`, with the parts this
--     software cannot know (the operator's identity, regions, transfer
--     mechanisms) recorded as `unknown` for the operator to replace. Every
--     acknowledgment already on a profile becomes a `legacy` history row:
--     evidence that the person saw the text of that day, not consent to
--     anything published later.
--   * Acknowledging a notice is not consent. Optional, purpose-specific
--     consent stays separate and is not created here.

create table if not exists public.privacy_notices (
  id uuid primary key default gen_random_uuid(),
  -- Not `workspace_id`: an installation notice has no space, and the
  -- system columns require a company on every row of a table that has
  -- one (0184).
  space_id uuid references public.workspaces(id) on delete cascade,
  version text not null check (version ~ '^[0-9A-Za-z._-]{1,40}$'),
  manifest jsonb not null,
  status text not null default 'published' check (status in ('published', 'superseded')),
  published_at timestamptz not null default now(),
  published_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
select public.ensure_system_columns('privacy_notices');
create unique index if not exists privacy_notices_version_once
  on public.privacy_notices
  (coalesce(space_id, '00000000-0000-0000-0000-000000000000'::uuid), version);
create unique index if not exists privacy_notices_one_current
  on public.privacy_notices
  (coalesce(space_id, '00000000-0000-0000-0000-000000000000'::uuid))
  where status = 'published';

alter table public.privacy_notices enable row level security;
revoke all on table public.privacy_notices from public, anon, authenticated;
grant select on table public.privacy_notices to authenticated;
drop policy if exists mcp_delegated_deny on public.privacy_notices;
create policy mcp_delegated_deny on public.privacy_notices
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
drop policy if exists privacy_notices_select on public.privacy_notices;
create policy privacy_notices_select on public.privacy_notices
  for select to authenticated
  using (space_id is null or public.is_member_of(space_id));

create table if not exists public.privacy_notice_acknowledgments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  notice_id uuid not null references public.privacy_notices(id) on delete cascade,
  acknowledged_at timestamptz not null default now(),
  legacy boolean not null default false,
  created_at timestamptz not null default now()
);
select public.ensure_system_columns('privacy_notice_acknowledgments');
create unique index if not exists privacy_notice_acknowledgments_once
  on public.privacy_notice_acknowledgments (user_id, notice_id);

alter table public.privacy_notice_acknowledgments enable row level security;
revoke all on table public.privacy_notice_acknowledgments from public, anon, authenticated;
grant select on table public.privacy_notice_acknowledgments to authenticated;
drop policy if exists mcp_delegated_deny on public.privacy_notice_acknowledgments;
create policy mcp_delegated_deny on public.privacy_notice_acknowledgments
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
drop policy if exists privacy_notice_acknowledgments_select
  on public.privacy_notice_acknowledgments;
create policy privacy_notice_acknowledgments_select
  on public.privacy_notice_acknowledgments
  for select to authenticated
  using (user_id = (select auth.uid()));

-- ── what a notice must say, and must not ────────────────────────────
create or replace function public.privacy_notice_manifest_valid(p jsonb)
returns boolean
language sql immutable set search_path = public as $fn$
  select jsonb_typeof(p) = 'object'
     -- No credential-shaped key anywhere: the notice is public.
     and p::text !~* '"[a-z_]*(secret|password|token|api_key|apikey|credential|private_key)[a-z_]*"\s*:'
     and coalesce(btrim(p->'controller'->>'name'), '') <> ''
     and coalesce(btrim(p->'controller'->>'contact'), '') <> ''
     and coalesce(btrim(p->>'rights_contact'), '') <> ''
     and coalesce(btrim(p->>'retention'), '') <> ''
     and jsonb_typeof(p->'recipients') = 'array'
     and not exists (
       select 1 from jsonb_array_elements(p->'recipients') r
        where coalesce(btrim(r->>'name'), '') = ''
           or coalesce(r->>'role', '') not in ('processor', 'sub_processor', 'independent_controller')
           or coalesce(btrim(r->>'purpose'), '') = ''
           or coalesce(r->>'legal_basis', '') not in ('contract', 'legal_obligation',
                'legitimate_interest', 'consent', 'vital_interest', 'public_task')
           or jsonb_typeof(r->'data_categories') is distinct from 'array'
           or coalesce(btrim(r->>'region'), '') = ''
           or coalesce(r->>'transfer_mechanism', '') not in ('none_needed', 'adequacy',
                'scc', 'other', 'unknown')
           or jsonb_typeof(r->'essential') is distinct from 'boolean');
$fn$;

revoke execute on function public.privacy_notice_manifest_valid(jsonb) from public, anon;
grant execute on function public.privacy_notice_manifest_valid(jsonb) to authenticated;

-- ── publishing ───────────────────────────────────────────────────────
create or replace function public.publish_privacy_notice(
  p_workspace_id uuid, p_version text, p_manifest jsonb
) returns jsonb
language plpgsql security definer set search_path = public as $fn$
declare
  v_row public.privacy_notices;
begin
  if p_workspace_id is null then
    if not public.is_instance_operator() then
      raise exception 'only the operator of this installation publishes its privacy notice';
    end if;
  elsif auth.uid() is null or not public.is_owner_of(p_workspace_id) then
    raise exception 'only the owner publishes the privacy notice of a space';
  end if;
  if p_version is null or p_version !~ '^[0-9A-Za-z._-]{1,40}$' then
    raise exception 'a notice version is 1 to 40 letters, digits, dots, dashes or underscores';
  end if;
  if not public.privacy_notice_manifest_valid(p_manifest) then
    raise exception 'a notice names its controller, rights contact, retention and, per recipient, role, purpose, legal basis, data categories, region, transfer mechanism and whether it is essential — and holds no credential';
  end if;
  if exists (select 1 from public.privacy_notices n
              where n.space_id is not distinct from p_workspace_id
                and n.version = p_version) then
    raise exception 'that version was already published; publish a new one';
  end if;
  update public.privacy_notices n set status = 'superseded'
   where n.space_id is not distinct from p_workspace_id and n.status = 'published';
  insert into public.privacy_notices (space_id, version, manifest, published_by)
  values (p_workspace_id, p_version, p_manifest - 'seeded', auth.uid())
  returning * into v_row;
  return to_jsonb(v_row) - 'published_by';
end $fn$;

revoke execute on function public.publish_privacy_notice(uuid, text, jsonb) from public, anon;
grant execute on function public.publish_privacy_notice(uuid, text, jsonb) to authenticated;

-- ── reading the notice that applies ─────────────────────────────────
create or replace function public.current_privacy_notice(p_workspace_id uuid default null)
returns jsonb
language sql stable security definer set search_path = public as $fn$
  select jsonb_build_object(
    'installation', (select jsonb_build_object('id', n.id, 'version', n.version,
                       'published_at', n.published_at, 'manifest', n.manifest)
                       from public.privacy_notices n
                      where n.space_id is null and n.status = 'published'),
    'workspace', case when p_workspace_id is not null and public.is_member_of(p_workspace_id) then
                   (select jsonb_build_object('id', n.id, 'version', n.version,
                       'published_at', n.published_at, 'manifest', n.manifest)
                      from public.privacy_notices n
                     where n.space_id = p_workspace_id and n.status = 'published')
                 end,
    'acknowledged', (select coalesce(jsonb_agg(jsonb_build_object(
                        'version', n.version, 'workspace_id', n.space_id,
                        'acknowledged_at', a.acknowledged_at, 'legacy', a.legacy)
                        order by a.acknowledged_at), '[]'::jsonb)
                       from public.privacy_notice_acknowledgments a
                       join public.privacy_notices n on n.id = a.notice_id
                      where a.user_id = auth.uid()))
   where auth.uid() is not null;
$fn$;

revoke execute on function public.current_privacy_notice(uuid) from public, anon;
grant execute on function public.current_privacy_notice(uuid) to authenticated;

-- ── acknowledging ───────────────────────────────────────────────────
-- Same signature as 0140, so the shipped client keeps working; it now
-- refuses a version that is not the current installation notice.
create or replace function public.accept_privacy_policy(p_version text)
returns void
language plpgsql security definer set search_path = public as $fn$
declare
  v_notice public.privacy_notices;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  select * into v_notice from public.privacy_notices
   where space_id is null and status = 'published';
  if v_notice.id is null or v_notice.version is distinct from btrim(p_version) then
    raise exception 'that is not the current privacy notice of this installation';
  end if;
  insert into public.privacy_notice_acknowledgments (user_id, notice_id)
  values (auth.uid(), v_notice.id)
  on conflict (user_id, notice_id) do nothing;
  update public.profiles
     set privacy_accepted_version = v_notice.version,
         privacy_accepted_at = now()
   where id = auth.uid();
  if not found then
    insert into public.profiles (id, privacy_accepted_version, privacy_accepted_at)
    values (auth.uid(), v_notice.version, now());
  end if;
end $fn$;

revoke execute on function public.accept_privacy_policy(text) from public, anon;
grant execute on function public.accept_privacy_policy(text) to authenticated;

create or replace function public.acknowledge_workspace_notice(
  p_workspace_id uuid, p_version text
) returns void
language plpgsql security definer set search_path = public as $fn$
declare
  v_notice public.privacy_notices;
begin
  if auth.uid() is null or not exists (
       select 1 from public.members
        where workspace_id = p_workspace_id and user_id = auth.uid()) then
    raise exception 'only a member acknowledges the notice of a space';
  end if;
  select * into v_notice from public.privacy_notices
   where space_id = p_workspace_id and status = 'published';
  if v_notice.id is null or v_notice.version is distinct from btrim(p_version) then
    raise exception 'that is not the current privacy notice of this space';
  end if;
  insert into public.privacy_notice_acknowledgments (user_id, notice_id)
  values (auth.uid(), v_notice.id)
  on conflict (user_id, notice_id) do nothing;
end $fn$;

revoke execute on function public.acknowledge_workspace_notice(uuid, text) from public, anon;
grant execute on function public.acknowledge_workspace_notice(uuid, text) to authenticated;

-- ── the notice already shipped, and the acknowledgments already given ─
insert into public.privacy_notices (space_id, version, manifest, status, published_at)
select null, '2026-09-20', $manifest${
  "seeded": true,
  "controller": {"name": "unknown: the operator of this installation has not recorded it",
                 "contact": "unknown: not recorded by the operator"},
  "rights_contact": "the controller above; until recorded, the contact in the shipped privacy policy",
  "retention": "as described in the retention matrix of the shipped privacy policy",
  "recipients": [
    {"name": "Supabase (database, authentication, storage)", "role": "processor",
     "purpose": "running the account and the spaces", "legal_basis": "contract",
     "data_categories": ["account", "membership", "bookings", "ledger", "messages"],
     "region": "unknown: configured by the operator", "transfer_mechanism": "unknown",
     "essential": true},
    {"name": "Firebase Cloud Messaging (push delivery, when the operator configures it)",
     "role": "processor", "purpose": "delivering notifications to your device",
     "legal_basis": "contract", "data_categories": ["device token", "notification text"],
     "region": "unknown: Google infrastructure", "transfer_mechanism": "unknown",
     "essential": false}
  ]
}$manifest$::jsonb, 'published', '2026-09-20 00:00:00+00'
where not exists (select 1 from public.privacy_notices
                   where space_id is null and version = '2026-09-20');

-- Older versions acknowledged on a profile become superseded history.
insert into public.privacy_notices (space_id, version, manifest, status, published_at)
select distinct null::uuid, p.privacy_accepted_version,
       '{"legacy": true, "note": "acknowledged before notices were recorded on the server"}'::jsonb,
       'superseded', min(p.privacy_accepted_at) over (partition by p.privacy_accepted_version)
  from public.profiles p
 where p.privacy_accepted_version is not null
   and p.privacy_accepted_version <> '2026-09-20'
   and p.privacy_accepted_version ~ '^[0-9A-Za-z._-]{1,40}$'
   and not exists (select 1 from public.privacy_notices n
                    where n.space_id is null and n.version = p.privacy_accepted_version);

insert into public.privacy_notice_acknowledgments (user_id, notice_id, acknowledged_at, legacy)
select p.id, n.id, coalesce(p.privacy_accepted_at, now()), true
  from public.profiles p
  join auth.users u on u.id = p.id
  join public.privacy_notices n
    on n.space_id is null and n.version = p.privacy_accepted_version
on conflict (user_id, notice_id) do nothing;

-- The person's own acknowledgments travel in their access export.
do $export$
declare
  v_def text;
  v_anchor text := $a$    'exported_at', now(),$a$;
begin
  v_def := pg_get_functiondef('public.export_my_data(uuid)'::regprocedure);
  if position(v_anchor in v_def) = 0 then raise exception '0329: export anchor missing'; end if;
  execute replace(v_def, v_anchor, $a$    'exported_at', now(),
    'privacy_notice_acknowledgments', (select coalesce(jsonb_agg(jsonb_build_object('version', pn.version, 'space_id', pn.space_id, 'acknowledged_at', pa.acknowledged_at, 'legacy', pa.legacy) order by pa.acknowledged_at), '[]'::jsonb) from public.privacy_notice_acknowledgments pa join public.privacy_notices pn on pn.id = pa.notice_id where pa.user_id = auth.uid()),$a$);
end;
$export$;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(329);
