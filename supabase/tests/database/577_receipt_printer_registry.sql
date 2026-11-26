-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4368 (0969): the receipt printer is a feature under till sessions, off until a business turns it on; the setup levels
-- and the builtin association template name it, the template off. Rolled back.
begin;
select plan(4);

select is((select parent from public.feature_registry_entries where feature_key = 'counterReceiptPrinter'), 'counterTillSessions',
          'the receipt printer sits under till sessions');
select is((select default_on from public.feature_registry_entries where feature_key = 'counterReceiptPrinter'), false,
          'and is off by default');
select is(public.setup_level_catalogue()::text like '%"counterReceiptPrinter"%', true, 'the setup levels name it');
select is((select configuration #>> '{workspace,feature_flags,counterReceiptPrinter}' from public.workspace_templates where key = 'association_fr'),
          'false', 'the builtin association template keeps it off');

select * from finish();
rollback;
