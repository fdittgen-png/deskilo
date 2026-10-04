-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0367 -- a workspace is public or private, and its licence follows from it.
--
-- The aim is to have as many workspaces as possible operationally listed,
-- so the model rewards openness:
--
--   * `workspaces.visibility` -- `public` or `private`. EVERY workspace
--     whose owner has chosen is LISTED: its name and its address are the
--     workspace's own (the address is never typed twice and never
--     overridden on the public card). A public workspace is also open to
--     outsiders and may show its page (description, contacts, plans); a
--     private one is listed by name and address only -- findable, so
--     people can ask to join, but nothing else about it is shown.
--     `visibility_set_at` is null until the owner chooses, so no existing
--     workspace becomes listed by a migration: a workspace with a
--     published page is public (what it already was), every other one
--     stays unlisted until its owner decides.
--
--   * `licence_plans` -- the catalogue of what a workspace may be on, as
--     DATA: who is eligible (public only, non-profit only), the limits
--     (users, subscribers), the price, and a free-until date for a
--     promotion. Seeded with today's offer:
--        public_launch    public, any size, free until 2027-12-31
--        community        public, up to 8 users and 5 subscribers, free
--        association      public, verified non-profit, up to 12 users, free
--        public_standard  public above those limits, from 30.00 EUR/month
--        private          private, from 30.00 EUR/month
--     The first plan (by `sort`) a workspace qualifies for is its plan.
--
--   * `workspace_licences` -- the per-workspace facts a plan cannot
--     derive: whether the non-profit status was verified, an optional
--     negotiated plan, and a paid-until date for the billing to come.
--     Only the platform writes it.
--
--   * `workspace_licence_status(workspace, on)` -- the evaluation, as one
--     answer: the plan, whether it is paid, its price, and the counts it
--     was judged on. It is a READ: nothing here blocks a workspace. The
--     result carries `enforced: false` so the day the licence is enforced
--     is a decision, not a surprise.
--
-- A "user" is an active, non-kiosk member; a "subscriber" is such a
-- member who is on a plan.

alter table public.workspaces
  add column if not exists visibility text not null default 'private'
    check (visibility in ('public', 'private')),
  add column if not exists visibility_set_at timestamptz;

comment on column public.workspaces.visibility is
  'public = listed, open to outsiders, may show its page; private = listed '
  'by name and address only. Meaningful once visibility_set_at is set.';

-- A workspace that already published its page IS public. The user triggers
-- stamp system columns; the backfill is a data fix, not a user edit.
alter table public.workspaces disable trigger user;
update public.workspaces w
   set visibility = 'public', visibility_set_at = now()
 where exists (select 1 from public.workspace_public_pages p
                where p.workspace_id = w.id and p.published);
alter table public.workspaces enable trigger user;

-- ── the catalogue ──────────────────────────────────────────────────────
create table public.licence_plans (
  code text primary key check (code ~ '^[a-z][a-z0-9_]{2,40}$'),
  label text not null check (length(label) between 1 and 80),
  paid boolean not null,
  requires_public boolean not null default false,
  requires_nonprofit boolean not null default false,
  max_users int check (max_users is null or max_users > 0),
  max_subscribers int check (max_subscribers is null or max_subscribers >= 0),
  free_until date,
  monthly_price_cents int not null default 0 check (monthly_price_cents >= 0),
  currency text not null default 'EUR' check (currency ~ '^[A-Z]{3}$'),
  sort int not null unique,
  check (paid = (monthly_price_cents > 0))
);
select public.ensure_system_columns('licence_plans');
alter table public.licence_plans enable row level security;
revoke all on public.licence_plans from public, anon, authenticated;
grant select on public.licence_plans to authenticated;
create policy licence_plans_read on public.licence_plans
  for select to authenticated using (true);
create policy mcp_delegated_deny on public.licence_plans as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

insert into public.licence_plans
  (code, label, paid, requires_public, requires_nonprofit, max_users,
   max_subscribers, free_until, monthly_price_cents, sort)
values
  ('public_launch', 'Public launch offer', false, true, false, null, null, date '2027-12-31', 0, 10),
  ('community', 'Community', false, true, false, 8, 5, null, 0, 20),
  ('association', 'Association', false, true, true, 12, null, null, 0, 30),
  ('public_standard', 'Public workspace', true, true, false, null, null, null, 3000, 40),
  ('private', 'Private workspace', true, false, false, null, null, null, 3000, 50);

-- ── the per-workspace facts ────────────────────────────────────────────
create table public.workspace_licences (
  workspace_id uuid primary key references public.workspaces(id) on delete cascade,
  nonprofit_verified boolean not null default false,
  nonprofit_verified_at timestamptz,
  plan_override text references public.licence_plans(code),
  paid_until date,
  external_ref text check (external_ref is null or length(external_ref) <= 200)
);
select public.ensure_system_columns('workspace_licences');
alter table public.workspace_licences enable row level security;
revoke all on public.workspace_licences from public, anon, authenticated;
create policy mcp_delegated_deny on public.workspace_licences as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── the evaluation ─────────────────────────────────────────────────────
create or replace function public.workspace_licence_status(
  p_workspace uuid, p_on date default current_date
) returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_ws public.workspaces;
  v_lic public.workspace_licences;
  v_users int;
  v_subscribers int;
  v_nonprofit boolean;
  v_plan public.licence_plans;
  v_override boolean := false;
begin
  if auth.uid() is null
     or not (public.is_owner_of(p_workspace) or public.is_admin_of(p_workspace)) then
    raise exception 'not allowed to read the licence';
  end if;
  select * into v_ws from public.workspaces where id = p_workspace;
  if v_ws.id is null then raise exception 'unknown workspace'; end if;
  select * into v_lic from public.workspace_licences where workspace_id = p_workspace;

  select count(*), count(*) filter (where m.plan_id is not null)
    into v_users, v_subscribers
    from public.members m
   where m.workspace_id = p_workspace and m.status = 'active' and not m.is_kiosk;
  v_nonprofit := coalesce(v_lic.nonprofit_verified, false)
    and coalesce(v_ws.invoice_legal ->> 'seller_kind', '') = 'association';

  if v_lic.plan_override is not null then
    select * into v_plan from public.licence_plans where code = v_lic.plan_override;
    v_override := v_plan.code is not null;
  end if;
  if v_plan.code is null then
    select * into v_plan
      from public.licence_plans lp
     where (not lp.requires_public or v_ws.visibility = 'public')
       and (not lp.requires_nonprofit or v_nonprofit)
       and (lp.max_users is null or v_users <= lp.max_users)
       and (lp.max_subscribers is null or v_subscribers <= lp.max_subscribers)
       and (lp.free_until is null or p_on <= lp.free_until)
     order by lp.sort
     limit 1;
  end if;
  return jsonb_build_object(
    'plan', v_plan.code,
    'label', v_plan.label,
    'paid', v_plan.paid,
    'monthly_price_cents', v_plan.monthly_price_cents,
    'currency', v_plan.currency,
    'free_until', v_plan.free_until,
    'visibility', v_ws.visibility,
    'visibility_set', v_ws.visibility_set_at is not null,
    'users', v_users,
    'subscribers', v_subscribers,
    'nonprofit_verified', v_nonprofit,
    'override', v_override,
    'paid_until', v_lic.paid_until,
    'evaluated_on', p_on,
    'enforced', false);
end;
$fn$;

revoke execute on function public.workspace_licence_status(uuid, date) from public, anon;
grant execute on function public.workspace_licence_status(uuid, date) to authenticated;

-- ── the owner's choice ─────────────────────────────────────────────────
create or replace function public.set_workspace_visibility(
  p_workspace uuid, p_visibility text
) returns void
language plpgsql security definer set search_path = public as $fn$
begin
  perform public.mcp_require_native();
  if auth.uid() is null or not public.is_owner_of(p_workspace) then
    raise exception 'owner required';
  end if;
  if p_visibility is null or p_visibility not in ('public', 'private') then
    raise exception 'unknown visibility';
  end if;
  update public.workspaces
     set visibility = p_visibility, visibility_set_at = now()
   where id = p_workspace;
end;
$fn$;

revoke execute on function public.set_workspace_visibility(uuid, text) from public, anon;
grant execute on function public.set_workspace_visibility(uuid, text) to authenticated;

-- ── the listing ────────────────────────────────────────────────────────
-- The address is ALWAYS the workspace's own. A private workspace shows its
-- name and address and nothing else; a public one (or one that published
-- its page) shows the page as before.
create or replace function public.public_workspace_document(p_workspace uuid) returns jsonb
language sql stable security definer set search_path = public as $$
 select case
  when w.visibility = 'private' and not coalesce(page.published, false) then
   jsonb_build_object('name', w.name, 'visibility', 'private',
    'host_type', d ->> 'host_type', 'address', coalesce(d ->> 'address', ''))
  else
   (d || coalesce(page.document, '{}'::jsonb)
    || jsonb_build_object('name', w.name, 'visibility', 'public',
     'address', coalesce(d ->> 'address', ''), 'currency', w.currency_code,
     'booking_unit', coalesce(w.booking_rules ->> 'granularity', 'flexible'),
     'contacts', coalesce((select jsonb_agg(jsonb_build_object('user_id', m.user_id,
       'name', coalesce(p.display_name, m.managed_name, ''), 'owner', m.is_owner,
       'available', coalesce(s.available, false)) order by m.is_owner desc, m.id)
      from public.members m left join public.profiles p on p.id = m.user_id
      left join public.account_contact_settings s on s.user_id = m.user_id
      left join public.member_public_contact c on c.member_id = m.id
      where m.workspace_id = w.id and m.status = 'active' and
       (m.is_owner or (m.is_admin and c.visible))), '[]'::jsonb)))
  end
 from public.workspaces w
 left join public.workspace_public_pages page on page.workspace_id = w.id
 cross join lateral (select public.workspace_public_defaults(w.id) as d) defaults
 where w.id = p_workspace;
$$;
revoke execute on function public.public_workspace_document(uuid) from public, anon, authenticated;

create or replace function public.refresh_public_workspace_card(p_workspace uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
 if public.feature_effective(p_workspace, 'publicListings')
    and exists (select 1 from public.workspaces w
                 where w.id = p_workspace
                   and (w.visibility_set_at is not null
                        or exists (select 1 from public.workspace_public_pages p
                                    where p.workspace_id = w.id and p.published))) then
  insert into public.public_workspace_cards(workspace_id, name, search_text, document)
   select w.id, w.name,
          w.name || ' ' || coalesce(public.public_workspace_document(w.id) ->> 'address', ''),
          public.public_workspace_document(w.id)
     from public.workspaces w where w.id = p_workspace
   on conflict (workspace_id) do update
     set name = excluded.name, search_text = excluded.search_text,
         document = excluded.document, updated_at = now();
 else delete from public.public_workspace_cards where workspace_id = p_workspace; end if;
end;
$$;
revoke execute on function public.refresh_public_workspace_card(uuid) from public, anon, authenticated;

-- A change of visibility reaches the card.
drop trigger if exists refresh_public_workspace on public.workspaces;
create trigger refresh_public_workspace after update of name, feature_flags, booking_rules,
 currency_code, address, street, postal_code, city, invoice_legal, visibility, visibility_set_at
 on public.workspaces for each row execute function public.refresh_public_profile_cards();

-- Cards for the workspaces that are public from the start of this migration.
select public.refresh_public_workspace_card(w.id) from public.workspaces w
 where w.visibility_set_at is not null;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(367);
