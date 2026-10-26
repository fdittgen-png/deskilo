-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0607 (#3074) -- the real room on the plan: a plan image may be a drawn
-- symbol instead of a photo. `kind` names the symbol (wall, door, window,
-- pillar, table, couch, wc, kitchen), `quarter_turns` rotates it; a symbol
-- has no storage object. A photo keeps its storage_path and no kind. The
-- rect, the RLS, the realtime publication, the reset and the exports of
-- plan_images carry the symbols unchanged.

alter table public.plan_images
  alter column storage_path drop not null,
  add column kind text,
  add column quarter_turns smallint not null default 0;

alter table public.plan_images
  add constraint plan_images_kind_check check (
    kind is null or kind in
      ('wall', 'door', 'window', 'pillar', 'table', 'couch', 'wc', 'kitchen')),
  add constraint plan_images_quarter_turns_check check (quarter_turns between 0 and 3),
  add constraint plan_images_photo_or_symbol check ((storage_path is null) = (kind is not null));

select public.set_deskilo_schema_version(607);
