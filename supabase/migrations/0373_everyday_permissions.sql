-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0373 -- the everyday features are permissions too.
--
-- A member held the messenger, the reservations, the calendar, the
-- directory, their own account and the shared documents just by being a
-- member. They are now six permissions of the catalogue, held only through
-- the role matrix or a role the workspace defined: a treasurer who was
-- never given the messenger has no messages. Owners and active co-owners
-- hold the whole catalogue as always; nobody else gets them by default, so
-- an owner grants them explicitly.

create or replace function public.role_permission_catalog()
returns text[] language sql immutable as $$
  select array[
    'manageRoles','manageMembers','manageValidation','workspaceSettings',
    'issueInvoices','viewFinances','manageDocuments','manageServices',
    'approveExpenses','viewNegotiations','manageNegotiations','paymentTermsEdit',
    'manageSites','manageBilling','manageReservations','operateKiosk','exportData',
    'designDocuments','viewPersonalData','manageIntegrations','manageConfiguration',
    'deployToProd','deployToDev','accessProd','viewAnalytics',
    'useMessages','makeReservations','viewCalendar','viewDirectory',
    'viewMyMoney','viewDocuments'];
$$;
revoke execute on function public.role_permission_catalog() from public, anon;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(373);
