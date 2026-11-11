-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (the feature registry with reminderEmail; the business's e-mail sender as
--  neutral functions, the purchase-order ones delegating to them)
--
-- #3673 (first pull request) -- one e-mail sender per business. The space's
-- Resend sender, so far configured for its purchase orders only (0683), is
-- the business's sender: purchase orders use it, and reminders by e-mail
-- (the `reminderEmail` feature, under dunning) will.
--
--  * No rename and no second store: `purchase_order_mail_settings` and its
--    Vault secret stay as they are.
--  * `business_mail_sender_v1` reads it (configured, the sender address and
--    name, the revision; never the key), `save_business_mail_sender_v1`
--    writes it (manageBilling, when purchase orders OR reminders by e-mail
--    are on), `business_mail_key_resolved` hands the key to the service role
--    only. The purchase-order functions of 0683 delegate to them, so an app
--    that still calls the old names keeps working.

create or replace function public.feature_registry()
returns jsonb
language sql
immutable
set search_path = public
as $registry$
  select '{
    "calendarTab": {"parent": null, "default": true, "core": true},
    "eventsTab": {"parent": null, "default": true, "core": true},
    "moneyTab": {"parent": null, "default": true, "core": true},
    "services": {"parent": "moneyTab", "default": true, "core": true},
    "accessorySupplements": {"parent": "moneyTab", "default": false, "core": false},
    "onlinePayments": {"parent": "moneyTab", "default": false, "core": false},
    "invoicing": {"parent": "moneyTab", "default": true, "core": true},
    "adminInvoicing": {"parent": "invoicing", "default": false, "core": false},
    "pdfExport": {"parent": null, "default": true, "core": true},
    "seriesBooking": {"parent": null, "default": true, "core": true},
    "bookForOthers": {"parent": null, "default": true, "core": true},
    "pushNotifications": {"parent": null, "default": true, "core": true},
    "adminSeatBlocking": {"parent": "placeBooking", "default": false, "core": false},
    "levelBooking": {"parent": "placeBooking", "default": false, "core": false},
    "adminLevelAssign": {"parent": "levelBooking", "default": false, "core": false},
    "kioskMode": {"parent": "placeBooking", "default": true, "core": false},
    "nfcBadges": {"parent": "kioskMode", "default": true, "core": false},
    "membersDirectory": {"parent": null, "default": true, "core": true},
    "whatsappIntegration": {"parent": "membersDirectory", "default": true, "core": false},
    "spaceQrCodes": {"parent": "placeBooking", "default": true, "core": true},
    "coOwner": {"parent": null, "default": true, "core": false},
    "autoCheckInOut": {"parent": "placeBooking", "default": false, "core": false},
    "dataExport": {"parent": null, "default": true, "core": true},
    "workingHours": {"parent": null, "default": true, "core": true},
    "invoicePdfTemplate": {"parent": "invoicing", "default": true, "core": false},
    "invoiceAddressWindow": {"parent": "invoicing", "default": true, "core": false},
    "memberNotifications": {"parent": null, "default": true, "core": true},
    "documents": {"parent": null, "default": true, "core": true},
    "dunning": {"parent": "invoicing", "default": true, "core": false},
    "memberReports": {"parent": "moneyTab", "default": true, "core": false},
    "deletionRequests": {"parent": null, "default": true, "core": true},
    "roleManagement": {"parent": null, "default": true, "core": true},
    "vatManagement": {"parent": "invoicing", "default": true, "core": false},
    "vatDeclarations": {"parent": "vatManagement", "default": true, "core": false},
    "einvoiceCustomerDelivery": {"parent": "invoicing", "default": true, "core": false},
    "planObjectDelete": {"parent": "placeBooking", "default": true, "core": true},
    "notificationGrouping": {"parent": "eventsTab", "default": true, "core": true},
    "bookingPolicies": {"parent": null, "default": true, "core": true},
    "bookingGate": {"parent": "bookingPolicies", "default": true, "core": true},
    "nfcSeatTags": {"parent": "placeBooking", "default": true, "core": false},
    "qrBadges": {"parent": "kioskMode", "default": true, "core": false},
    "kioskMemberPhotos": {"parent": "kioskMode", "default": true, "core": false},
    "subscriptionInvoices": {"parent": "invoicing", "default": true, "core": false},
    "usageInvoices": {"parent": "invoicing", "default": true, "core": false},
    "invoiceSettlement": {"parent": "invoicing", "default": true, "core": false},
    "invoiceJourney": {"parent": "invoicing", "default": true, "core": false},
    "messageGestures": {"parent": null, "default": true, "core": true},
    "uniqueMonograms": {"parent": null, "default": true, "core": true},
    "planMemberPhotos": {"parent": "placeBooking", "default": true, "core": false},
    "regionalFormats": {"parent": null, "default": true, "core": true},
    "calendarHub": {"parent": "calendarTab", "default": true, "core": true},
    "calendarViews": {"parent": "calendarHub", "default": true, "core": true},
    "messagesHub": {"parent": null, "default": true, "core": true},
    "reportDesigner": {"parent": "invoicePdfTemplate", "default": true, "core": false},
    "memberPage": {"parent": "membersDirectory", "default": true, "core": true},
    "invoicingWizard": {"parent": "invoicing", "default": true, "core": false},
    "expenseRepartition": {"parent": "invoicing", "default": true, "core": false},
    "settlementFold": {"parent": "invoiceSettlement", "default": true, "core": false},
    "configurationTransfer": {"parent": "dataExport", "default": true, "core": false},
    "navigationStyle": {"parent": null, "default": true, "core": true},
    "demoMode": {"parent": null, "default": true, "core": false},
    "instanceWizard": {"parent": null, "default": true, "core": false},
    "dataAccessLog": {"parent": "moneyTab", "default": true, "core": false},
    "memberDataExport": {"parent": null, "default": true, "core": true},
    "financeFaces": {"parent": "moneyTab", "default": true, "core": true},
    "paymentReminders": {"parent": "dunning", "default": true, "core": false},
    "supplyExpenses": {"parent": "services", "default": true, "core": false},
    "validationScopes": {"parent": null, "default": true, "core": false},
    "validationChain": {"parent": null, "default": true, "core": false},
    "richMessageRefs": {"parent": "memberNotifications", "default": true, "core": true},
    "calendarValidations": {"parent": "calendarHub", "default": true, "core": false},
    "usageRecords": {"parent": "invoicing", "default": true, "core": false},
    "reportDesignExchange": {"parent": "reportDesigner", "default": true, "core": false},
    "reportLayouts": {"parent": "reportDesigner", "default": true, "core": false},
    "personalInfo": {"parent": null, "default": true, "core": true},
    "managedProfiles": {"parent": "membersDirectory", "default": true, "core": false},
    "numberSequences": {"parent": "invoicing", "default": false, "core": false},
    "workspaceStatus": {"parent": "invoicing", "default": false, "core": false},
    "expenseRepartitionWizard": {"parent": "expenseRepartition", "default": false, "core": false},
    "multiSite": {"parent": "placeBooking", "default": false, "core": false},
    "siteDocuments": {"parent": "multiSite", "default": false, "core": false},
    "vatGroups": {"parent": "vatManagement", "default": false, "core": false},
    "vatRateHistory": {"parent": "vatManagement", "default": false, "core": false},
    "vatCounterparty": {"parent": "vatManagement", "default": false, "core": false},
    "environmentPairs": {"parent": null, "default": true, "core": false},
    "deployments": {"parent": "environmentPairs", "default": true, "core": false},
    "managedProfileAccess": {"parent": "managedProfiles", "default": false, "core": false},
    "seatDayTimeline": {"parent": "placeBooking", "default": true, "core": true},
    "memberPaymentTerms": {"parent": "invoicing", "default": true, "core": false},
    "usageReport": {"parent": "usageRecords", "default": true, "core": false},
    "reportTexts": {"parent": "reportDesigner", "default": true, "core": false},
    "letterStandard": {"parent": "reportLayouts", "default": true, "core": false},
    "vatReport": {"parent": "vatDeclarations", "default": true, "core": false},
    "priceNegotiations": {"parent": "moneyTab", "default": true, "core": false},
    "scheduledExpenses": {"parent": "moneyTab", "default": true, "core": false},
    "badgeSignIn": {"parent": "nfcBadges", "default": false, "core": false},
    "formHelpHints": {"parent": null, "default": true, "core": true},
    "uiAnimations": {"parent": null, "default": true, "core": true},
    "memberOrigin": {"parent": "membersDirectory", "default": false, "core": false},
    "memberEnvironments": {"parent": "environmentPairs", "default": false, "core": false},
    "workspaceLibrary": {"parent": null, "default": false, "core": false},
    "singleRoomLevelNames": {"parent": "placeBooking", "default": true, "core": true},
    "publicHolidays": {"parent": null, "default": false, "core": false},
    "workspaceVocabulary": {"parent": null, "default": false, "core": false},
    "carnets": {"parent": "invoicing", "default": false, "core": false},
    "publicListings": {"parent": null, "default": false, "core": true},
    "workspaceBranding": {"parent": null, "default": false, "core": false},
    "customRoles": {"parent": null, "default": false, "core": false},
    "customFields": {"parent": null, "default": false, "core": false},
    "decisionSurface": {"parent": null, "default": false, "core": false},
    "recordingPrivacy": {"parent": null, "default": false, "core": false},
    "memberAccountMenu": {"parent": null, "default": false, "core": false},
    "mcpAccess": {"parent": null, "default": false, "core": false},
    "calendarFileExport": {"parent": null, "default": true, "core": true},
    "memberGettingStarted": {"parent": null, "default": true, "core": true},
    "placeFeedback": {"parent": "placeBooking", "default": true, "core": true},
    "spaceInquiries": {"parent": null, "default": true, "core": true},
    "messageForwarding": {"parent": "memberNotifications", "default": true, "core": true},
    "captureProtection": {"parent": "memberNotifications", "default": true, "core": true},
    "holidayImport": {"parent": "publicHolidays", "default": false, "core": false},
    "capacityKpi": {"parent": "placeBooking", "default": false, "core": false},
    "accountingBook": {"parent": "invoicing", "default": false, "core": false},
    "roleAssignment": {"parent": "roleManagement", "default": true, "core": true},
    "taskRecorder": {"parent": null, "default": false, "core": false},
    "guestParticipation": {"parent": "placeBooking", "default": false, "core": true},
    "messageMentions": {"parent": "memberNotifications", "default": true, "core": true},
    "supplyClassification": {"parent": "vatManagement", "default": true, "core": false},
    "viesVerification": {"parent": "supplyClassification", "default": true, "core": false},
    "recapitulativeStatement": {"parent": "vatDeclarations", "default": true, "core": false, "countries": ["@eu"]},
    "inputVat": {"parent": "vatDeclarations", "default": true, "core": false},
    "configurableSettings": {"parent": null, "default": true, "core": false},
    "salesTax": {"parent": "invoicing", "default": true, "core": false},
    "meetingRooms": {"parent": "placeBooking", "default": false, "core": false},
    "parking": {"parent": "placeBooking", "default": false, "core": false},
    "webMcp": {"parent": "mcpAccess", "default": false, "core": false},
    "purchases": {"parent": "moneyTab", "default": false, "core": false},
    "premisesLease": {"parent": "scheduledExpenses", "default": false, "core": false},
    "assetRegister": {"parent": "purchases", "default": false, "core": false},
    "externalRooms": {"parent": "levelBooking", "default": false, "core": false},
    "accountingPeriods": {"parent": "accountingBook", "default": false, "core": false},
    "biReportDesigner": {"parent": null, "default": false, "core": false},
    "purchaseAnalytics": {"parent": "purchases", "default": false, "core": false},
    "workspaceOverview": {"parent": null, "default": false, "core": false},
    "setupGuide": {"parent": null, "default": true, "core": true},
    "dataReport": {"parent": "dataExport", "default": true, "core": true},
    "personalShell": {"parent": null, "default": false, "core": false},
    "foreignCurrencyPurchases": {"parent": "purchases", "default": false, "core": false},
    "accountingConnectors": {"parent": "accountingBook", "default": false, "core": false},
    "bankImport": {"parent": "invoicing", "default": false, "core": false},
    "planDecor": {"parent": "placeBooking", "default": true, "core": true},
    "mtdSubmission": {"parent": "vatDeclarations", "default": false, "core": false, "countries": ["GB"]},
    "purchaseOrders": {"parent": "purchases", "default": false, "core": false},
    "guestPasses": {"parent": "invoicing", "default": false, "core": false},
    "placeBooking": {"parent": null, "default": true, "core": true},
    "reminderEmail": {"parent": "dunning", "default": false, "core": false}
  }'::jsonb
$registry$;

revoke execute on function public.feature_registry() from public, anon;

create or replace function public.save_business_mail_sender_v1(
  p_workspace_id uuid, p_sender_email text, p_sender_name text, p_api_key text, p_revision int
) returns jsonb language plpgsql security definer set search_path = public, vault as $fn$
declare
  v_email text := btrim(coalesce(p_sender_email, ''));
  v_name text := btrim(coalesce(p_sender_name, ''));
  v_key text := nullif(btrim(coalesce(p_api_key, '')), '');
  v_row public.purchase_order_mail_settings;
  v_secret uuid;
  v_secret_name text := public.purchase_order_mail_secret_name(p_workspace_id);
begin
  if auth.uid() is null or public.mcp_is_delegated()
     or not public.has_permission(p_workspace_id, 'manageBilling') then
    raise exception 'not allowed to configure how this business sends its e-mail' using errcode = '42501';
  end if;
  if not (public.feature_effective(p_workspace_id, 'purchaseOrders')
          or public.feature_effective(p_workspace_id, 'reminderEmail')) then
    raise exception 'nothing in this business sends e-mail' using errcode = '42501';
  end if;
  if v_email !~ '^[^\s@<>",;()\[\]\\]+@[^\s@<>",;()\[\]\\]+\.[^\s@<>",;()\[\]\\]+$' or v_email ~ '[\r\n]' or char_length(v_email) > 254 then
    raise exception 'the sender is not an e-mail address' using errcode = '22023';
  end if;
  if v_name ~ '[\r\n<>"]' or char_length(v_name) > 120 then
    raise exception 'the sender''s name holds characters a mail header cannot carry' using errcode = '22023';
  end if;
  if v_key is not null and (v_key !~ '^[A-Za-z0-9_\-]{8,200}$') then
    raise exception 'this is not an API key' using errcode = '22023';
  end if;
  select * into v_row from public.purchase_order_mail_settings
   where workspace_id = p_workspace_id for update;
  if v_row.workspace_id is not null and v_row.revision <> coalesce(p_revision, -1) then
    raise exception 'stale revision' using errcode = '40001';
  end if;
  if v_row.workspace_id is null and v_key is null then
    raise exception 'the first configuration brings its API key' using errcode = '22023';
  end if;
  if v_key is not null then
    select id into v_secret from vault.secrets where name = v_secret_name;
    if v_secret is null then
      perform vault.create_secret(v_key, v_secret_name, 'DesKilo business mail API key');
    else
      perform vault.update_secret(v_secret, v_key);
    end if;
  end if;
  insert into public.purchase_order_mail_settings (workspace_id, sender_email, sender_name, has_api_key)
  values (p_workspace_id, v_email, v_name, true)
  on conflict (workspace_id) do update
    set sender_email = excluded.sender_email, sender_name = excluded.sender_name,
        has_api_key = true, revision = public.purchase_order_mail_settings.revision + 1
  returning * into v_row;
  return jsonb_build_object('sender_email', v_row.sender_email, 'sender_name', v_row.sender_name,
                            'has_api_key', v_row.has_api_key, 'revision', v_row.revision);
end;
$fn$;
revoke execute on function public.save_business_mail_sender_v1(uuid, text, text, text, int) from public, anon;
grant execute on function public.save_business_mail_sender_v1(uuid, text, text, text, int) to authenticated;

-- What the business's sender is, for whoever may see the finances: never the key.
create or replace function public.business_mail_sender_v1(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare v_row public.purchase_order_mail_settings;
begin
  if auth.uid() is null or not (public.has_permission(p_workspace_id, 'manageBilling')
                                or public.has_permission(p_workspace_id, 'viewFinances')) then
    raise exception 'not allowed to read this business''s e-mail sender' using errcode = '42501';
  end if;
  select * into v_row from public.purchase_order_mail_settings where workspace_id = p_workspace_id;
  if v_row.workspace_id is null then return null; end if;
  return jsonb_build_object('sender_email', v_row.sender_email, 'sender_name', v_row.sender_name,
                            'has_api_key', v_row.has_api_key, 'revision', v_row.revision);
end;
$fn$;
revoke execute on function public.business_mail_sender_v1(uuid) from public, anon;
grant execute on function public.business_mail_sender_v1(uuid) to authenticated;

-- The key and the sender, for the send functions only.
create or replace function public.business_mail_key_resolved(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public, vault as $fn$
declare
  v_row public.purchase_order_mail_settings;
  v_key text;
begin
  select * into v_row from public.purchase_order_mail_settings where workspace_id = p_workspace_id;
  if v_row.workspace_id is null or not v_row.has_api_key then return null; end if;
  select decrypted_secret into v_key from vault.decrypted_secrets
   where name = public.purchase_order_mail_secret_name(p_workspace_id);
  if v_key is null then return null; end if;
  return jsonb_build_object('api_key', v_key, 'sender_email', v_row.sender_email,
                            'sender_name', v_row.sender_name);
end;
$fn$;
revoke execute on function public.business_mail_key_resolved(uuid) from public, anon, authenticated;
grant execute on function public.business_mail_key_resolved(uuid) to service_role;

-- The purchase-order names of 0683, kept for an app that still calls them.
create or replace function public.save_purchase_order_mail_settings_v1(
  p_workspace_id uuid, p_sender_email text, p_sender_name text, p_api_key text, p_revision int
) returns jsonb language sql security definer set search_path = public as $fn$
  select public.save_business_mail_sender_v1(p_workspace_id, p_sender_email, p_sender_name, p_api_key, p_revision)
$fn$;
revoke execute on function public.save_purchase_order_mail_settings_v1(uuid, text, text, text, int) from public, anon;
grant execute on function public.save_purchase_order_mail_settings_v1(uuid, text, text, text, int) to authenticated;

create or replace function public.purchase_order_mail_key_resolved(p_workspace_id uuid)
returns jsonb language sql stable security definer set search_path = public as $fn$
  select public.business_mail_key_resolved(p_workspace_id)
$fn$;
revoke execute on function public.purchase_order_mail_key_resolved(uuid) from public, anon, authenticated;
grant execute on function public.purchase_order_mail_key_resolved(uuid) to service_role;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(724);
