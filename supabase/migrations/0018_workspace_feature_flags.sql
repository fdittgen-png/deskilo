-- SPDX-License-Identifier: MIT
-- DesKilo per-workspace feature management (issue #146). The owner turns
-- features on/off for the whole workspace; every member's client applies
-- the flags on connect. Keys are the Dart WorkspaceFeature enum names;
-- absent key = the feature's registry default (ON). Owner-write comes
-- from the existing workspaces_update RLS policy.

alter table public.workspaces add column feature_flags jsonb not null default '{}'::jsonb;
