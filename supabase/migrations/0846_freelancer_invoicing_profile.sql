-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- #4168 -- the freelancer's reviewed profile (0834) switched on billing
-- customers and quotes but not the standalone customer invoice they lead to:
-- converting an accepted quote and invoicing a customer both need
-- `standaloneInvoicing` (0826). A flow that cannot end in its invoice is not
-- ready, so the freelancer proposes it too. The change is a new version of the
-- profile (the trigger of 0834 raises `profile_version` and recomputes the
-- digest): a proposal reviewed on the earlier one is out of date and is
-- reviewed again. The generic `service` kind is untouched.

update public.business_kinds
   set feature_profile = feature_profile || '{"standaloneInvoicing": true}'::jsonb
 where code = 'freelancer';

select public.set_deskilo_schema_version(846);
