-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- #3553 (1b) -- the installation says it can narrow the directory search to
-- one business kind: its descriptor advertises the `kind_filter` capability.
-- A client asks a kind only of a source that advertises it; a source that
-- does not is reported as not covered by that search, never as having no
-- result (an older installation's cards carry no kinds, and a filter on them
-- would answer an empty page).

-- ── the descriptor (0559, restated whole) ─────────────────────────────────
-- Generated from contracts/public_network/operations.json
-- (renderPublicNetworkDescriptorSql; test/tool/public_network_contract_test.dart
-- pins it).
create or replace function public.public_network_descriptor()
returns jsonb
language sql
stable
set search_path = public
as $descriptor$
  select $json${"protocol":"deskilo.public-network","protocol_versions":[1],"capabilities":["kind_filter","operation_header"],"operations":[{"id":"network.descriptor.read","versions":[1],"requires":[]},{"id":"directory.sources.list","versions":[1],"requires":[]},{"id":"directory.workspaces.search","versions":[1],"requires":[]},{"id":"directory.workspaces.detail","versions":[1],"requires":[]},{"id":"directory.sources.register","versions":[1],"requires":[],"unlabelled":1},{"id":"workspace.profile.request","versions":[1],"requires":[],"unlabelled":1}]}$json$::jsonb
    || jsonb_build_object(
         'roles', to_jsonb(i.roles),
         'role_capabilities', coalesce((
           select jsonb_agg(c.capability order by c.ordinal)
             from (values (1, 'personal_home', 'personal@1'), (2, 'workspace_host', 'workspace@1')) as c (ordinal, role, capability)
            where c.role = any (i.roles)), '[]'::jsonb))
    from public.installation_identity i
$descriptor$;
revoke execute on function public.public_network_descriptor() from public;
grant execute on function public.public_network_descriptor() to anon, authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(793);
