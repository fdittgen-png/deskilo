-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4169 (0838): the stockLots feature is in the server's registries: the feature registry (under the goods ledger, off by default), the setup levels and the template field registry.
begin;
select plan(4);
select is(public.feature_registry() -> 'stockLots' ->> 'parent', 'stockManagement', 'the server registry names stockLots under the goods ledger');
select is((public.feature_registry() -> 'stockLots' ->> 'default')::boolean, false, 'and it is off by default');
select ok(public.setup_level_catalogue()::text like '%stockLots%', 'the setup levels name it');
select ok(public.template_field_registry()::text like '%feature_flags.stockLots%', 'the template field registry names it');
select * from finish();
rollback;
