-- SPDX-License-Identifier: 0BSD
-- 0196 — #1120: a new workspace no longer starts empty.
--
-- A workspace created through onboarding had 0 levels, 0 offices, 0
-- desks and 0 seats. The app's central action — tap a seat, book it —
-- was impossible until the owner drew a floor plan from an empty canvas,
-- and every other surface (plan, calendar, scan, kiosk) was empty with
-- it. The QR scanner correctly refused every code, because no space
-- existed to match one.
--
-- A template is the DEPLOYMENT ENGINE pointed at a stored snapshot
-- instead of a sibling workspace. `merge_floor_plan` (0188) already
-- merges a tree by name and never wipes the target; reusing it means a
-- template cannot drift from what a deployment considers part of a
-- configuration, and a new entity kind is learned once rather than
-- twice.
--
-- The snapshot is stored in exactly the shape `export_floor_plan`
-- produces, so an owner's own space can become a template later with no
-- schema change — the reason these are rows and not code.

create table if not exists public.workspace_templates (
  id          uuid primary key default gen_random_uuid(),
  key         text not null unique check (key ~ '^[a-z][a-z0-9_]{0,39}$'),
  name        text not null check (char_length(name) between 1 and 80),
  description text not null default '',
  sort_order  int  not null default 0,
  -- Who may read this row (#1120). The column exists from the FIRST
  -- migration, though only 'builtin' rows are written yet, so the read
  -- policy is never once `using (true)`. A policy that is correct only
  -- while a table holds a single kind of row is a landmine set for the
  -- migration that adds the second kind — and here the second kind is a
  -- template made from a real workspace's floor plan.
  visibility  text not null default 'builtin'
              check (visibility in ('builtin','private','shared','public')),
  -- `export_floor_plan` shape: levels → offices → desks → seats.
  floor_plan  jsonb not null default '[]'::jsonb
);
select public.ensure_system_columns('workspace_templates');

alter table public.workspace_templates enable row level security;
drop policy if exists workspace_templates_read on public.workspace_templates;
-- Only what is meant to be seen. `builtin` ships with the product and
-- describes nobody's space; `public` is what an owner deliberately put
-- in the library. `private` and `shared` are unreadable here and gain
-- their owner and grant clauses with the sharing step — so a private
-- template is refused by this policy from the day the value exists,
-- rather than being exposed until somebody remembers to narrow it.
--
-- There is no insert or update policy: rows arrive through migrations
-- and, later, through a definer function that decides what an owner may
-- publish.
create policy workspace_templates_read on public.workspace_templates
  for select to authenticated
  using (visibility in ('builtin', 'public'));

-- ── the tiny space ─────────────────────────────────────────────────
-- Two levels, one room each, two desks per room, two seats per desk:
-- 4 desks and 8 seats. Small enough to read on a phone, complete enough
-- that every surface has something real in it — a whole-desk booking,
-- a second level to switch between, and seats to scan.
insert into public.workspace_templates (key, name, description, sort_order, visibility, floor_plan)
values (
  'tiny',
  'A tiny space',
  'Two levels, four desks, eight seats — enough to book, scan and browse from the first minute.',
  0,
  'builtin',
  $tpl$[
    {
      "name": "Ground floor", "sort_order": 0,
      "bookable_as_whole": false, "price_cents": 0,
      "background_path": "", "site": null, "images": [],
      "offices": [
        {
          "name": "Main room", "color": 0, "bookable_as_whole": true,
          "price_cents": 0, "x": 0, "y": 0, "w": 40, "h": 24,
          "desks": [
            {
              "name": "Desk 1", "x": 2, "y": 2, "w": 14, "h": 8,
              "bookable_as_whole": true, "price_cents": 0,
              "seats": [
                {"name": "A1", "x": 4,  "y": 4, "orientation": "n", "chair": "standard", "amenities": [], "accessories": []},
                {"name": "A2", "x": 12, "y": 4, "orientation": "n", "chair": "standard", "amenities": [], "accessories": []}
              ]
            },
            {
              "name": "Desk 2", "x": 22, "y": 2, "w": 14, "h": 8,
              "bookable_as_whole": true, "price_cents": 0,
              "seats": [
                {"name": "B1", "x": 24, "y": 4, "orientation": "n", "chair": "standard", "amenities": [], "accessories": []},
                {"name": "B2", "x": 32, "y": 4, "orientation": "n", "chair": "standard", "amenities": [], "accessories": []}
              ]
            }
          ]
        }
      ]
    },
    {
      "name": "First floor", "sort_order": 1,
      "bookable_as_whole": false, "price_cents": 0,
      "background_path": "", "site": null, "images": [],
      "offices": [
        {
          "name": "Upper room", "color": 0, "bookable_as_whole": true,
          "price_cents": 0, "x": 0, "y": 0, "w": 40, "h": 24,
          "desks": [
            {
              "name": "Desk 3", "x": 2, "y": 2, "w": 14, "h": 8,
              "bookable_as_whole": true, "price_cents": 0,
              "seats": [
                {"name": "C1", "x": 4,  "y": 4, "orientation": "n", "chair": "standard", "amenities": [], "accessories": []},
                {"name": "C2", "x": 12, "y": 4, "orientation": "n", "chair": "standard", "amenities": [], "accessories": []}
              ]
            },
            {
              "name": "Desk 4", "x": 22, "y": 2, "w": 14, "h": 8,
              "bookable_as_whole": true, "price_cents": 0,
              "seats": [
                {"name": "D1", "x": 24, "y": 4, "orientation": "n", "chair": "standard", "amenities": [], "accessories": []},
                {"name": "D2", "x": 32, "y": 4, "orientation": "n", "chair": "standard", "amenities": [], "accessories": []}
              ]
            }
          ]
        }
      ]
    }
  ]$tpl$::jsonb
)
on conflict (key) do update
  set name = excluded.name,
      description = excluded.description,
      sort_order = excluded.sort_order,
      visibility = excluded.visibility,
      floor_plan = excluded.floor_plan;

-- ── applying one ───────────────────────────────────────────────────
-- Owner-only, and it MERGES: a space that already has a plan keeps it,
-- because the template is an offer, never a reset. `merge_floor_plan`
-- carries that guarantee already (#1004) — it adds and updates by name
-- and reports what only the target has.
create or replace function public.apply_workspace_template(
  p_workspace_id uuid, p_key text
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare v_tpl public.workspace_templates;
begin
  if auth.uid() is null or not public.is_owner_of(p_workspace_id) then
    raise exception 'only an owner configures a workspace from a template';
  end if;
  select * into v_tpl from public.workspace_templates where key = p_key;
  if not found then raise exception 'unknown template %', p_key; end if;
  return public.merge_floor_plan(p_workspace_id, v_tpl.floor_plan);
end $fn$;
revoke execute on function public.apply_workspace_template(uuid, text) from public, anon;

-- ── the workspaces that are empty today ────────────────────────────
-- A space with no level at all cannot do the one thing the app is for.
-- Every such workspace gets the tiny template, which is a strict
-- improvement: `merge_floor_plan` adds and updates by name and removes
-- nothing, so a space that already has a plan is untouched — and the
-- condition below excludes it anyway.
--
-- On the live project this is exactly the two halves of one twin whose
-- owner created it through onboarding and found nothing to book.
do $backfill$
declare r record; v_tpl jsonb;
begin
  select floor_plan into v_tpl from public.workspace_templates where key = 'tiny';
  for r in
    select w.id from public.workspaces w
     where not exists (select 1 from public.levels l where l.workspace_id = w.id)
  loop
    perform public.merge_floor_plan(r.id, v_tpl);
  end loop;
end
$backfill$;
