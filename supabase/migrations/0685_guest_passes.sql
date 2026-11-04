-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0685 (#3308) -- guest passes: a day or hourly pass sold at the desk to a
-- guest who is not a member, with its booking, its charge, its invoice and
-- (when the money was taken) its recorded payment.
--
-- `guestPasses` (platform, default OFF, under invoicing) joins the
-- server's registry. The space lists its passes (`guest_pass_offers`: a
-- name, a unit -- a day or an hour -- a price per unit and a VAT rate),
-- edited by whoever holds manageServices.
--
-- The guest is not a member. Invoices and bookings are keyed by a
-- customer record, so each sale writes one for its guest (an invoice is
-- one record's month, so a pass is its own record and invoice): a
-- MANAGED profile (#887/0153: no account, the identity an admin typed)
-- whose origin is 'guest' -- it carries no subscription (0 %, so no fee
-- band and no overage), no role, and nobody can sign in as it. Its
-- identity is the managed identity of 0153, so a guest's data follows the
-- managed profiles' privacy rules (export, erasure, the purpose groups);
-- what the invoice froze stays with the invoice for as long as the law
-- keeps it.
--
-- `sell_guest_pass` does the whole sale in one transaction, under the
-- seller's own rights: issueInvoices for the charge and the invoice, the
-- booking rights of admin_create_reservation_for for the place, and the
-- payment through record_payment (a pending payment, decided as every
-- other one). The price is the server's: units x the offer's price, the
-- units being the window's started hours (an hourly pass, one day) or the
-- pass's number of days (a day pass: one booking per day, the same local
-- window each day). A retry with the same request id returns the same sale.

-- ── the feature registry knows it (dart run tool/build_feature_registry_sql.dart) ──
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
    "adminSeatBlocking": {"parent": null, "default": false, "core": false},
    "levelBooking": {"parent": null, "default": false, "core": false},
    "adminLevelAssign": {"parent": "levelBooking", "default": false, "core": false},
    "kioskMode": {"parent": null, "default": true, "core": false},
    "nfcBadges": {"parent": "kioskMode", "default": true, "core": false},
    "membersDirectory": {"parent": null, "default": true, "core": true},
    "whatsappIntegration": {"parent": "membersDirectory", "default": true, "core": false},
    "spaceQrCodes": {"parent": null, "default": true, "core": true},
    "coOwner": {"parent": null, "default": true, "core": false},
    "autoCheckInOut": {"parent": null, "default": false, "core": false},
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
    "planObjectDelete": {"parent": null, "default": true, "core": true},
    "notificationGrouping": {"parent": "eventsTab", "default": true, "core": true},
    "bookingPolicies": {"parent": null, "default": true, "core": true},
    "bookingGate": {"parent": "bookingPolicies", "default": true, "core": true},
    "nfcSeatTags": {"parent": null, "default": true, "core": false},
    "qrBadges": {"parent": "kioskMode", "default": true, "core": false},
    "kioskMemberPhotos": {"parent": "kioskMode", "default": true, "core": false},
    "subscriptionInvoices": {"parent": "invoicing", "default": true, "core": false},
    "usageInvoices": {"parent": "invoicing", "default": true, "core": false},
    "invoiceSettlement": {"parent": "invoicing", "default": true, "core": false},
    "invoiceJourney": {"parent": "invoicing", "default": true, "core": false},
    "messageGestures": {"parent": null, "default": true, "core": true},
    "uniqueMonograms": {"parent": null, "default": true, "core": true},
    "planMemberPhotos": {"parent": null, "default": true, "core": false},
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
    "multiSite": {"parent": null, "default": false, "core": false},
    "siteDocuments": {"parent": "multiSite", "default": false, "core": false},
    "vatGroups": {"parent": "vatManagement", "default": false, "core": false},
    "vatRateHistory": {"parent": "vatManagement", "default": false, "core": false},
    "vatCounterparty": {"parent": "vatManagement", "default": false, "core": false},
    "environmentPairs": {"parent": null, "default": true, "core": false},
    "deployments": {"parent": "environmentPairs", "default": true, "core": false},
    "managedProfileAccess": {"parent": "managedProfiles", "default": false, "core": false},
    "seatDayTimeline": {"parent": null, "default": true, "core": true},
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
    "singleRoomLevelNames": {"parent": null, "default": true, "core": true},
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
    "placeFeedback": {"parent": null, "default": true, "core": true},
    "spaceInquiries": {"parent": null, "default": true, "core": true},
    "messageForwarding": {"parent": "memberNotifications", "default": true, "core": true},
    "captureProtection": {"parent": "memberNotifications", "default": true, "core": true},
    "holidayImport": {"parent": "publicHolidays", "default": false, "core": false},
    "capacityKpi": {"parent": null, "default": false, "core": false},
    "accountingBook": {"parent": "invoicing", "default": false, "core": false},
    "roleAssignment": {"parent": "roleManagement", "default": true, "core": true},
    "taskRecorder": {"parent": null, "default": false, "core": false},
    "guestParticipation": {"parent": null, "default": false, "core": true},
    "messageMentions": {"parent": "memberNotifications", "default": true, "core": true},
    "supplyClassification": {"parent": "vatManagement", "default": true, "core": false},
    "viesVerification": {"parent": "supplyClassification", "default": true, "core": false},
    "recapitulativeStatement": {"parent": "vatDeclarations", "default": true, "core": false, "countries": ["@eu"]},
    "inputVat": {"parent": "vatDeclarations", "default": true, "core": false},
    "configurableSettings": {"parent": null, "default": true, "core": false},
    "salesTax": {"parent": "invoicing", "default": true, "core": false},
    "meetingRooms": {"parent": null, "default": false, "core": false},
    "parking": {"parent": null, "default": false, "core": false},
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
    "planDecor": {"parent": null, "default": true, "core": true},
    "mtdSubmission": {"parent": "vatDeclarations", "default": false, "core": false, "countries": ["GB"]},
    "purchaseOrders": {"parent": "purchases", "default": false, "core": false},
    "guestPasses": {"parent": "invoicing", "default": false, "core": false}
  }'::jsonb
$registry$;
revoke execute on function public.feature_registry() from public, anon;
grant execute on function public.feature_registry() to authenticated;

-- ── the setup level catalogue carries it (dart run tool/build_setup_steps.dart) ──
create or replace function public.setup_level_catalogue()
returns jsonb language sql immutable set search_path = public as $fn$
  select $json${"processes":[{"process":"bookings","levels":[{"level":"simple","features":["seriesBooking","bookForOthers","spaceQrCodes","workingHours","planObjectDelete","bookingPolicies","seatDayTimeline","bookingGate","calendarFileExport","planDecor"],"needs":[]},{"level":"resources","features":["adminSeatBlocking","levelBooking","adminLevelAssign","multiSite","publicHolidays","holidayImport","meetingRooms","parking","externalRooms"],"needs":[]},{"level":"measured","features":["kioskMode","nfcBadges","autoCheckInOut","nfcSeatTags","qrBadges","kioskMemberPhotos","badgeSignIn","capacityKpi"],"needs":[]}]},{"process":"community","levels":[{"level":"basic","features":["calendarTab","eventsTab","pushNotifications","membersDirectory","memberNotifications","deletionRequests","roleManagement","notificationGrouping","calendarHub","richMessageRefs","personalInfo","messageGestures","calendarViews","messagesHub","memberPage","messageForwarding","captureProtection","roleAssignment","messageMentions"],"needs":[]},{"level":"organised","features":["whatsappIntegration","coOwner","validationScopes","validationChain","calendarValidations","managedProfiles","managedProfileAccess","memberOrigin","customRoles","customFields","guestParticipation"],"needs":[]}]},{"process":"money","levels":[{"level":"none","features":[],"needs":[]},{"level":"statements","features":["moneyTab","services","accessorySupplements","memberReports","dataAccessLog","financeFaces","priceNegotiations"],"needs":[]},{"level":"invoices","features":["invoicing","adminInvoicing","invoicePdfTemplate","invoiceAddressWindow","dunning","paymentReminders","usageRecords","reportDesignExchange","reportLayouts","numberSequences","workspaceStatus","memberPaymentTerms","reportTexts","usageReport","letterStandard","subscriptionInvoices","usageInvoices","invoiceSettlement","invoiceJourney","reportDesigner","invoicingWizard","settlementFold","carnets","guestPasses"],"needs":[]}]},{"process":"payments","levels":[{"level":"off","features":[],"needs":[]},{"level":"online","features":["onlinePayments"],"needs":[{"process":"money","level":"statements"}]}]},{"process":"tax","levels":[{"level":"none","features":[],"needs":[]},{"level":"vat","features":["vatManagement","vatDeclarations","vatGroups","vatRateHistory","vatCounterparty","vatReport","supplyClassification","viesVerification","recapitulativeStatement","inputVat","salesTax"],"needs":[{"process":"money","level":"invoices"}]},{"level":"books","features":["einvoiceCustomerDelivery","accountingBook","accountingPeriods","accountingConnectors","bankImport","mtdSubmission"],"needs":[{"process":"money","level":"invoices"}]}]},{"process":"purchases","levels":[{"level":"none","features":[],"needs":[]},{"level":"expenses","features":["supplyExpenses","expenseRepartitionWizard","scheduledExpenses","expenseRepartition"],"needs":[{"process":"money","level":"invoices"}]},{"level":"full","features":["purchases","premisesLease","assetRegister","purchaseAnalytics","foreignCurrencyPurchases","purchaseOrders"],"needs":[{"process":"money","level":"invoices"}]}]},{"process":"presentation","levels":[{"level":"basic","features":["planMemberPhotos","uniqueMonograms","singleRoomLevelNames"],"needs":[]},{"level":"branded","features":["workspaceVocabulary","workspaceBranding"],"needs":[]},{"level":"public","features":["publicListings","spaceInquiries"],"needs":[]}]},{"process":"operations","levels":[{"level":"basic","features":["pdfExport","dataExport","documents","formHelpHints","uiAnimations","regionalFormats","memberDataExport","navigationStyle","demoMode","memberAccountMenu","memberGettingStarted","placeFeedback","setupGuide","dataReport"],"needs":[]},{"level":"insight","features":["decisionSurface","biReportDesigner","workspaceOverview"],"needs":[]},{"level":"advanced","features":["environmentPairs","deployments","configurationTransfer","instanceWizard","memberEnvironments","workspaceLibrary","configurableSettings"],"needs":[]}]},{"process":"assistant","levels":[{"level":"off","features":[],"needs":[]},{"level":"on","features":["recordingPrivacy","mcpAccess","taskRecorder","webMcp"],"needs":[]}]}],"presets":[{"preset":"essentiel","levels":[{"process":"bookings","level":"simple"},{"process":"community","level":"basic"},{"process":"money","level":"statements"},{"process":"payments","level":"off"},{"process":"tax","level":"none"},{"process":"purchases","level":"none"},{"process":"presentation","level":"basic"},{"process":"operations","level":"basic"},{"process":"assistant","level":"off"}]},{"preset":"standard","levels":[{"process":"bookings","level":"resources"},{"process":"community","level":"organised"},{"process":"money","level":"invoices"},{"process":"payments","level":"off"},{"process":"tax","level":"none"},{"process":"purchases","level":"expenses"},{"process":"presentation","level":"branded"},{"process":"operations","level":"insight"},{"process":"assistant","level":"off"}]},{"preset":"complet","levels":[{"process":"bookings","level":"measured"},{"process":"community","level":"organised"},{"process":"money","level":"invoices"},{"process":"payments","level":"online"},{"process":"tax","level":"books"},{"process":"purchases","level":"full"},{"process":"presentation","level":"public"},{"process":"operations","level":"advanced"},{"process":"assistant","level":"off"}]}]}$json$::jsonb;
$fn$;
revoke execute on function public.setup_level_catalogue() from public, anon, authenticated;

-- ── a membership's origin may be a guest pass ──
alter table public.members drop constraint if exists members_origin_known;
alter table public.members
  add constraint members_origin_known
  check (origin in ('founder', 'invited', 'delegated', 'guest'));

-- ── the passes a space sells ──
create table if not exists public.guest_pass_offers (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 120),
  unit text not null check (unit in ('day', 'hour')),
  price_cents integer not null check (price_cents >= 0),
  vat_rate_id uuid references public.vat_rates(id) on delete set null,
  active boolean not null default true,
  unique (workspace_id, id)
);
select public.ensure_system_columns('guest_pass_offers');

-- ── the passes sold ──
create table if not exists public.guest_passes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  offer_id uuid not null,
  member_id uuid not null,
  client_request_id uuid not null,
  unit text not null check (unit in ('day', 'hour')),
  units integer not null check (units between 1 and 31),
  unit_price_cents integer not null check (unit_price_cents >= 0),
  amount_cents integer not null check (amount_cents >= 0),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  -- one booking per day of the pass, the same window each day
  reservation_ids uuid[] not null default '{}',
  invoice_id uuid references public.invoices(id) on delete restrict,
  payment_event_id uuid,
  sold_by uuid,
  sold_at timestamptz not null default now(),
  constraint guest_passes_window check (ends_at > starts_at),
  constraint guest_passes_offer_same_workspace foreign key (workspace_id, offer_id)
    references public.guest_pass_offers(workspace_id, id) on delete restrict,
  constraint guest_passes_member_same_workspace foreign key (workspace_id, member_id)
    references public.members(workspace_id, id) on delete restrict,
  unique (workspace_id, client_request_id)
);
select public.ensure_system_columns('guest_passes');
create index if not exists guest_passes_member_idx on public.guest_passes (member_id);

-- Who reads the offers: every active member of the space (they are the
-- space's prices); who reads the sales: who holds viewFinances or
-- issueInvoices, or the owner.
create or replace function public.guest_pass_reader(p_workspace_id uuid)
returns boolean language sql stable security definer set search_path = public as $fn$
  select public.is_owner_of(p_workspace_id)
      or p_workspace_id in (select public.workspaces_permitting(array['viewFinances', 'issueInvoices']));
$fn$;
revoke execute on function public.guest_pass_reader(uuid) from public, anon;
grant execute on function public.guest_pass_reader(uuid) to authenticated;

alter table public.guest_pass_offers enable row level security;
alter table public.guest_passes enable row level security;
revoke all on public.guest_pass_offers, public.guest_passes from public, anon, authenticated;
grant select on public.guest_pass_offers, public.guest_passes to authenticated;
drop policy if exists guest_pass_offers_select on public.guest_pass_offers;
create policy guest_pass_offers_select on public.guest_pass_offers for select to authenticated
  using (public.is_member_of(workspace_id));
drop policy if exists guest_passes_select on public.guest_passes;
create policy guest_passes_select on public.guest_passes for select to authenticated
  using (public.guest_pass_reader(workspace_id));
drop policy if exists mcp_delegated_deny on public.guest_pass_offers;
create policy mcp_delegated_deny on public.guest_pass_offers as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
drop policy if exists mcp_delegated_deny on public.guest_passes;
create policy mcp_delegated_deny on public.guest_passes as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── the space edits its passes ──
create or replace function public.save_guest_pass_offer(
  p_workspace_id uuid, p_id uuid, p_name text, p_unit text,
  p_price_cents integer, p_vat_rate_id uuid, p_active boolean)
returns uuid language plpgsql security definer set search_path = public as $fn$
declare
  v_id uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if public.mcp_is_delegated() then raise exception 'guest passes are managed in the Deskilo app'; end if;
  if not public.feature_effective(p_workspace_id, 'guestPasses') then
    raise exception 'guest passes are off in this space';
  end if;
  if not public.has_permission(p_workspace_id, 'manageServices') then
    raise exception 'not allowed to edit the guest passes' using errcode = '42501';
  end if;
  if p_vat_rate_id is not null and not exists (
    select 1 from public.vat_rates r where r.id = p_vat_rate_id and r.workspace_id = p_workspace_id) then
    raise exception 'unknown VAT rate';
  end if;
  if p_id is null then
    insert into public.guest_pass_offers (workspace_id, name, unit, price_cents, vat_rate_id, active)
    values (p_workspace_id, btrim(p_name), p_unit, p_price_cents, p_vat_rate_id, coalesce(p_active, true))
    returning id into v_id;
  else
    update public.guest_pass_offers
       set name = btrim(p_name), unit = p_unit, price_cents = p_price_cents,
           vat_rate_id = p_vat_rate_id, active = coalesce(p_active, true)
     where id = p_id and workspace_id = p_workspace_id
    returning id into v_id;
    if v_id is null then raise exception 'unknown guest pass'; end if;
  end if;
  return v_id;
end;
$fn$;
revoke execute on function public.save_guest_pass_offer(uuid, uuid, text, text, integer, uuid, boolean) from public, anon;
grant execute on function public.save_guest_pass_offer(uuid, uuid, text, text, integer, uuid, boolean) to authenticated;

-- ── the sale ──
create or replace function public.sell_guest_pass(
  p_workspace_id uuid, p_offer_id uuid, p_guest jsonb, p_seat_id uuid,
  p_starts_at timestamptz, p_ends_at timestamptz, p_request_id uuid,
  p_paid boolean default false, p_method text default '', p_days integer default 1)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_done public.guest_passes;
  v_offer public.guest_pass_offers;
  v_identity jsonb;
  v_member uuid;
  v_units int;
  v_amount int;
  v_period text;
  v_tz text;
  v_vat numeric;
  v_res uuid;
  v_res_ids uuid[] := '{}';
  v_event uuid;
  v_day int;
  v_invoice uuid;
  v_payment uuid;
  v_pass uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if public.mcp_is_delegated() then raise exception 'guest passes are sold in the Deskilo app'; end if;
  if p_request_id is null then raise exception 'a request id is required'; end if;
  select * into v_done from public.guest_passes
   where workspace_id = p_workspace_id and client_request_id = p_request_id;
  if v_done.id is not null then
    return jsonb_build_object('pass_id', v_done.id, 'member_id', v_done.member_id,
      'reservation_ids', to_jsonb(v_done.reservation_ids), 'invoice_id', v_done.invoice_id,
      'payment_event_id', v_done.payment_event_id, 'units', v_done.units,
      'amount_cents', v_done.amount_cents, 'replayed', true);
  end if;
  if not public.feature_effective(p_workspace_id, 'guestPasses') then
    raise exception 'guest passes are off in this space';
  end if;
  if not public.has_permission(p_workspace_id, 'issueInvoices') then
    raise exception 'not allowed to sell a guest pass' using errcode = '42501';
  end if;
  select * into v_offer from public.guest_pass_offers
   where id = p_offer_id and workspace_id = p_workspace_id and active;
  if v_offer.id is null then raise exception 'unknown guest pass'; end if;
  if p_ends_at <= p_starts_at then raise exception 'the pass ends before it starts'; end if;
  if p_ends_at - p_starts_at > interval '1 day' then
    raise exception 'a pass''s window is one day; more days are its number of days';
  end if;
  if coalesce(p_days, 0) < 1 or p_days > 31 then raise exception 'a pass lasts 1 to 31 days'; end if;
  if v_offer.unit = 'hour' and p_days <> 1 then
    raise exception 'an hourly pass is for one day';
  end if;

  v_identity := public.managed_identity_clean(p_guest);
  if public.managed_identity_name(v_identity) = '' then
    raise exception 'a guest needs a name';
  end if;

  v_units := case v_offer.unit when 'hour'
               then ceil(extract(epoch from (p_ends_at - p_starts_at)) / 3600.0)::int
               else p_days end;
  v_amount := v_units * v_offer.price_cents;
  select timezone into v_tz from public.workspaces where id = p_workspace_id;
  v_period := to_char(p_starts_at at time zone v_tz, 'YYYY-MM');

  -- The guest's customer record, one per sale: an invoice covers one
  -- customer record and month (create_invoice), so a guest who comes back
  -- in the same month gets a record, a booking and an invoice per pass.
  -- The passes of one person are found by their e-mail.
  insert into public.members
    (workspace_id, user_id, is_admin, status, managed_identity, managed_by,
     managed_access, managed_name, origin, subscription_pct, overage_policy,
     customer_capacity)
  values (p_workspace_id, null, false, 'active',
          public.managed_identity_public(v_identity), auth.uid(), '{}'::jsonb,
          public.managed_identity_name(v_identity), 'guest', 0, 'blocked',
          -- a guest without a company buys as a consumer; with one, the
          -- capacity is unknown until someone states it, as for a member
          case when coalesce(v_identity->>'company', '') = '' then 'consumer' end)
  returning id into v_member;
  update public.members set member_number = public.next_document_number(p_workspace_id, 'member')
   where id = v_member and member_number = '';
  insert into public.managed_identities (member_id, workspace_id, identity)
  values (v_member, p_workspace_id, v_identity);

  -- The pass is the guest's entitlement: it grants the half-days its window
  -- covers (two per local day, month by month), so the quota a member's
  -- booking is held to lets the sold window through and nothing more.
  insert into public.quota_extensions (workspace_id, member_id, period, half_days)
  select p_workspace_id, v_member, to_char((p_starts_at at time zone v_tz) + make_interval(days => n), 'YYYY-MM'),
         least(100, 2 * count(*))::int
    from generate_series(0, p_days - 1) n
   group by 3;

  -- the place, under the seller's own booking rights and the space's rules
  -- one booking per day, the same local window each day
  for v_day in 0 .. p_days - 1 loop
    v_event := public.admin_create_reservation_for(p_workspace_id, v_member, p_seat_id,
      ((p_starts_at at time zone v_tz) + make_interval(days => v_day)) at time zone v_tz,
      ((p_ends_at at time zone v_tz) + make_interval(days => v_day)) at time zone v_tz, null);
    select reservation_id into v_res from public.events where id = v_event;
    v_res_ids := v_res_ids || v_res;
    -- A booking made for a member waits for that member's yes; a guest has
    -- no account to say it, and bought the pass at the desk: the sale is
    -- the yes, so the booking stands as made.
    update public.events set status = 'applied' where id = v_event and status = 'pending';
  end loop;

  -- the charge and its invoice
  v_vat := case when v_offer.vat_rate_id is null
                then public.workspace_default_vat_percent(p_workspace_id, (p_starts_at at time zone v_tz)::date)
                else public.vat_rate_percent_at(v_offer.vat_rate_id, (p_starts_at at time zone v_tz)::date) end;
  if v_amount > 0 then
    insert into public.ledger_entries
      (workspace_id, member_id, kind, category, amount_cents, description, period,
       occurred_on, vat_percent, supply_class)
    values (p_workspace_id, v_member, 'charge', 'service', v_amount,
            v_offer.name || ' × ' || v_units, v_period,
            (p_starts_at at time zone v_tz)::date, v_vat, 'general');
    v_invoice := public.create_invoice(p_workspace_id, v_member, v_period, null, true, 'full');
    if p_paid then
      v_payment := public.record_payment(p_workspace_id, v_member, v_amount, v_offer.name,
                                         coalesce(p_method, ''), (now() at time zone v_tz)::date, v_period);
    end if;
  end if;

  insert into public.guest_passes
    (workspace_id, offer_id, member_id, client_request_id, unit, units, unit_price_cents,
     amount_cents, starts_at, ends_at, reservation_ids, invoice_id, payment_event_id, sold_by)
  values (p_workspace_id, v_offer.id, v_member, p_request_id, v_offer.unit, v_units,
          v_offer.price_cents, v_amount, p_starts_at,
          ((p_ends_at at time zone v_tz) + make_interval(days => p_days - 1)) at time zone v_tz,
          v_res_ids, v_invoice, v_payment, auth.uid())
  returning id into v_pass;

  return jsonb_build_object('pass_id', v_pass, 'member_id', v_member,
    'reservation_ids', to_jsonb(v_res_ids), 'invoice_id', v_invoice, 'payment_event_id', v_payment,
    'units', v_units, 'amount_cents', v_amount, 'replayed', false);
end;
$fn$;
revoke execute on function public.sell_guest_pass(uuid, uuid, jsonb, uuid, timestamptz, timestamptz, uuid, boolean, text, integer) from public, anon;
grant execute on function public.sell_guest_pass(uuid, uuid, jsonb, uuid, timestamptz, timestamptz, uuid, boolean, text, integer) to authenticated;

-- ── the workspace's records carry the passes (0540 restated; #2860) ──
create or replace function public.export_workspace_records(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_tables text[] := array[
    -- configuration, readable (the XML stays the re-importable copy)
    'sites', 'plans', 'fee_bands', 'packages', 'credit_products', 'vat_rates',
    'accessories', 'seat_accessories', 'closure_days', 'validation_policies',
    'workspace_roles', 'workspace_role_members', 'workspace_field_definitions',
    'workspace_field_values', 'number_sequences', 'charging_stations',
    'plan_images', 'setting_values',
    -- member accounts
    'member_credits', 'member_credit_uses', 'price_negotiations',
    'quota_extensions', 'usage_records', 'invoice_matches', 'invoice_reminders',
    'invoice_dunning_holds', 'tax_exemption_certificates',
    -- purchases, premises, assets, books
    'suppliers', 'purchase_documents', 'purchase_lines', 'purchase_obligations',
    'outgoing_payments', 'expense_schedules', 'expense_occurrences',
    'expense_repartitions', 'premises_leases', 'lease_terms',
    'lease_settlements', 'room_rentals', 'room_rental_fees', 'workspace_assets',
    'asset_valuation_batches', 'asset_valuation_rows', 'book_profiles',
    'book_accounts', 'book_mappings', 'book_periods', 'vat_declarations',
    'einvoice_inbox',
    -- people the space is accountable to
    'guest_participations', 'rights_requests',
    -- #3307 the orders to the suppliers
    'purchase_orders', 'purchase_order_lines', 'purchase_order_sends',
    'purchase_order_receipts', 'purchase_order_receipt_lines',
    -- #3308 the passes the space sells and the passes it sold
    'guest_pass_offers', 'guest_passes'];
  v_left_out text[] := public.system_column_names() || array['workspace_id', 'source_xml'];
  v_table text;
  v_columns text[];
  v_rows jsonb;
  v_out jsonb := '[]'::jsonb;
begin
  if auth.uid() is null or not public.has_permission(p_workspace_id, 'exportData') then
    raise exception 'only someone who may export this workspace''s data reads its records';
  end if;
  foreach v_table in array v_tables loop
    select array_agg(c.column_name::text order by c.ordinal_position) into v_columns
      from information_schema.columns c
     where c.table_schema = 'public' and c.table_name = v_table
       and c.column_name <> all (v_left_out);
    execute format(
      'select coalesce(jsonb_agg(jsonb_build_array(%s) order by created_datetime), ''[]''::jsonb)
         from public.%I where workspace_id = $1',
      (select string_agg(format('%I', c), ', ') from unnest(v_columns) c), v_table)
      into v_rows using p_workspace_id;
    v_out := v_out || jsonb_build_array(jsonb_build_object(
      'table', v_table, 'columns', to_jsonb(v_columns), 'rows', v_rows));
  end loop;
  return v_out;
end;
$fn$;
revoke execute on function public.export_workspace_records(uuid) from public, anon;
grant execute on function public.export_workspace_records(uuid) to authenticated;

select public.set_deskilo_schema_version(685);
