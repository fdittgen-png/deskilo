-- SPDX-License-Identifier: 0BSD
-- risk: additive
--
-- 0254 (#1550) — a space that HAS a twin is shown as having one.
--
-- Since #1063 a workspace is born Core-only: every Platform feature is
-- written `false` explicitly at creation, so that "nobody has chosen
-- yet" and "chosen off" stay distinguishable. `environmentPairs` is a
-- Platform feature, and it is also the feature that SHOWS a pair — so
-- every space created with its twin since 2026-09-11 was created with
-- the only place the couple appears as a couple switched off. On the
-- Profiles screen the two sides showed as two unrelated spaces with the
-- same name.
--
-- The client stops writing that (`defaultFeatureFlagsForNewWorkspace`
-- takes the twin into account now). This repairs the rows that were
-- already written.
--
-- Deliberately narrow. It touches only rows that
--   * carry a `pair_id`,
--   * have a twin that still exists,
--   * say `false` EXPLICITLY (a row that never chose is left alone —
--     it resolves to the registry default, which is on), and
--   * were created on or after 2026-09-11, the day #1063 landed.
-- The date is the whole point: before it, a stored `false` is a person
-- who switched the couple off and meant it, and this migration has no
-- business overruling them. After it, a stored `false` is this bug.

update public.workspaces as w
   set feature_flags =
         jsonb_set(w.feature_flags, '{environmentPairs}', 'true'::jsonb, true)
 where w.pair_id is not null
   and w.feature_flags ->> 'environmentPairs' = 'false'
   and w.created_at >= timestamptz '2026-09-11 00:00:00+00'
   and exists (
         select 1
           from public.workspaces as t
          where t.pair_id = w.pair_id
            and t.id <> w.id
       );

select public.set_deskilo_schema_version(254);
