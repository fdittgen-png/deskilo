-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Synthetic migrations for tool/feature_audit.dart.
create or replace function public.gate_old(p uuid) returns boolean
language sql as $fn$ select public.feature_effective(p, 'oldKey') $fn$;

create or replace function public.gate_old(p uuid) returns boolean
language sql as $fn$ select public.feature_effective(p, 'alpha') $fn$;

create or replace function public.gate_stray(p uuid) returns boolean
language sql as $fn$ select public.feature_effective(p, 'unregistered') $fn$;

create policy p on public.t using (public.feature_effective(workspace_id, 'beta'));
