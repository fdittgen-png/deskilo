-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (badge_auth_verify takes the kiosk's credential and is restated whole; the
--  old three-argument signature is dropped; businesses that already issued
--  badges keep signing in on any device until their owner switches)
--
-- #3675 (GHSA-9525-vh85-5hjg, step b; second of two files) -- a business
-- enrols the devices it uses as kiosks and decides where badge sign-in
-- works. 0733 carries the two registries; this file the builtin template
-- (supabase/templates/association_fr.json: kioskEnrolment false), the setup
-- step and level catalogues, then:
--
--  * kiosk_devices: an enrolled device of a business. The server keeps the
--    sha256 of the device's credential, never the credential; a revoked
--    device is kept with who revoked it and when. No client reads the table:
--    kiosk_devices_v1 lists it without the hash.
--  * enrol_kiosk_device_v1 / revoke_kiosk_device_v1: a holder of
--    operateKiosk or an owner, in their own session (never an assistant's),
--    with kioskEnrolment on. The credential is answered once, at enrolment.
--    Each enrolment and revocation tells the owners (event kiosk_device).
--  * security.badge_signin_where: enrolled_kiosks (the default) or
--    any_device, in force while kioskEnrolment is on (off: any device, as
--    before). A business that already issued badges is set to any_device
--    here, so nothing changes for it until its owner switches.
--  * badge_auth_verify(uid, pin, source, device_id, device_secret): a device
--    counts only when it is enrolled, not revoked, its credential matches,
--    and it belongs to the business of the tag; otherwise it is exactly no
--    device. On such a kiosk the scan names the person and a paused
--    business answers "locked" for every tag. Without one, no answer tells a
--    tag of a business from an unknown tag, whatever the setting.

-- ── the devices ─────────────────────────────────────────────────────────
create table public.kiosk_devices (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  name text not null check (length(btrim(name)) between 1 and 80),
  secret_hash text not null check (secret_hash ~ '^[0-9a-f]{64}$'),
  enrolled_by uuid references public.members(id) on delete set null,
  enrolled_at timestamptz not null default now(),
  last_used_at timestamptz,
  revoked_at timestamptz,
  revoked_by uuid references public.members(id) on delete set null
);
select public.ensure_system_columns('kiosk_devices');
create index kiosk_devices_workspace on public.kiosk_devices (workspace_id, enrolled_at desc);

comment on table public.kiosk_devices is
  '#3675 -- the devices a business enrolled as kiosks: badge sign-in may be limited to them. Only the sha256 of a device''s credential is kept.';

alter table public.kiosk_devices enable row level security;
revoke all on public.kiosk_devices from public, anon, authenticated;
create policy mcp_delegated_deny on public.kiosk_devices as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── the builtin template carries `kioskEnrolment` ──
insert into public.workspace_templates
  (key, name, description, sort_order, visibility, schema_version, template_version,
   tags, entities, configuration, floor_plan)
values (
  'association_fr',
  'Association de coworking (France)',
  'Pour une association de coworking en France : demi-journées de 7 h à 13 h et de 13 h à 19 h du lundi au vendredi, jours fériés de l''année et de la suivante, cotisations à 50 % et 100 %, deux carnets prépayés pour qui ne cotise pas, les rôles du bureau, un calendrier où se prennent les validations, les mots de l''association, et deux étages prêts à réserver.',
  1,
  'builtin',
  1,
  1,
  array['association', 'coworking', 'france'],
  array['identity', 'tariffs', 'credit_products', 'floor_plan', 'booking_rules', 'closure_days', 'lexicon', 'workspace_roles', 'features'],
  $cfg${
  "workspace": {
    "default_locale": "fr",
    "vat_regime": "not_subject",
    "booking_rules": {
      "granularity": "half_day",
      "open_weekdays": [
        1,
        2,
        3,
        4,
        5
      ],
      "work_start_minutes": 420,
      "half_boundary_minutes": 780,
      "work_end_minutes": 1140,
      "max_series_days": 180,
      "advance_horizon_days": 90,
      "max_duration_minutes": 1440,
      "min_duration_minutes": 30
    },
    "subscription_levels": {
      "allow_custom": false,
      "extra_levels": [],
      "enabled_presets": [
        50,
        100
      ]
    },
    "feature_flags": {
      "accessorySupplements": false,
      "accountingBook": false,
      "accountingConnectors": false,
      "accountingPeriods": false,
      "adminInvoicing": false,
      "adminLevelAssign": false,
      "adminSeatBlocking": false,
      "assetRegister": false,
      "autoCheckInOut": false,
      "badgeSignIn": false,
      "bankImport": false,
      "biReportDesigner": false,
      "bookForOthers": true,
      "bookingGate": true,
      "bookingPolicies": true,
      "calendarFileExport": true,
      "calendarHub": true,
      "calendarTab": true,
      "calendarValidations": true,
      "calendarViews": true,
      "capacityKpi": false,
      "captureProtection": true,
      "carnets": true,
      "coOwner": false,
      "configurableSettings": false,
      "configurationTransfer": false,
      "customFields": false,
      "customRoles": true,
      "dataAccessLog": false,
      "dataExport": true,
      "dataReport": true,
      "decisionSurface": false,
      "deletionRequests": true,
      "demoMode": false,
      "deployments": false,
      "documents": true,
      "dunning": false,
      "einvoiceCustomerDelivery": false,
      "environmentPairs": false,
      "eventsTab": false,
      "expenseRepartition": false,
      "expenseRepartitionWizard": false,
      "externalRooms": false,
      "financeFaces": true,
      "foreignCurrencyPurchases": false,
      "formHelpHints": true,
      "guestParticipation": false,
      "guestPasses": false,
      "holidayImport": false,
      "inputVat": false,
      "instanceWizard": false,
      "invoiceAddressWindow": false,
      "invoiceJourney": false,
      "invoicePdfTemplate": false,
      "invoiceSettlement": false,
      "invoicing": true,
      "invoicingWizard": false,
      "kioskMemberPhotos": false,
      "kioskMode": false,
      "letterStandard": false,
      "levelBooking": false,
      "managedProfileAccess": false,
      "managedProfiles": false,
      "mcpAccess": false,
      "meetingRooms": false,
      "memberAccountMenu": false,
      "memberDataExport": true,
      "memberEnvironments": false,
      "memberGettingStarted": true,
      "memberNotifications": true,
      "memberOrigin": false,
      "memberPage": false,
      "memberPaymentTerms": false,
      "memberReports": false,
      "membersDirectory": false,
      "messageForwarding": true,
      "messageGestures": true,
      "messageMentions": true,
      "messagesHub": true,
      "moneyTab": true,
      "mtdSubmission": false,
      "multiSite": false,
      "navigationStyle": true,
      "nfcBadges": false,
      "nfcSeatTags": false,
      "notificationGrouping": false,
      "numberSequences": false,
      "onlinePayments": false,
      "parking": false,
      "paymentReminders": false,
      "pdfExport": true,
      "personalInfo": true,
      "personalShell": false,
      "placeBooking": true,
      "placeFeedback": true,
      "planDecor": true,
      "planMemberPhotos": false,
      "planObjectDelete": true,
      "premisesLease": false,
      "priceNegotiations": false,
      "publicHolidays": false,
      "publicListings": false,
      "purchaseAnalytics": false,
      "purchaseOrders": false,
      "purchases": false,
      "pushNotifications": true,
      "qrBadges": false,
      "recapitulativeStatement": false,
      "recordingPrivacy": false,
      "regionalFormats": true,
      "reminderEmail": false,
      "invoiceEmail": false,
      "kioskEnrolment": false,
      "reportDesignExchange": false,
      "reportDesigner": false,
      "reportLayouts": false,
      "reportTexts": false,
      "richMessageRefs": true,
      "roleAssignment": true,
      "roleManagement": true,
      "salesTax": false,
      "scheduledExpenses": false,
      "seatDayTimeline": true,
      "seriesBooking": true,
      "services": true,
      "settlementFold": false,
      "setupGuide": true,
      "singleRoomLevelNames": true,
      "siteDocuments": false,
      "spaceInquiries": true,
      "spaceQrCodes": true,
      "subscriptionInvoices": false,
      "supplyClassification": false,
      "supplyExpenses": false,
      "taskRecorder": false,
      "uiAnimations": true,
      "uniqueMonograms": true,
      "usageInvoices": false,
      "usageRecords": false,
      "usageReport": false,
      "validationChain": false,
      "validationScopes": false,
      "vatCounterparty": false,
      "vatDeclarations": false,
      "vatGroups": false,
      "vatManagement": false,
      "vatRateHistory": false,
      "vatReport": false,
      "viesVerification": false,
      "webMcp": false,
      "whatsappIntegration": false,
      "workingHours": true,
      "workspaceBranding": false,
      "workspaceLibrary": false,
      "workspaceOverview": false,
      "workspaceStatus": false,
      "workspaceVocabulary": true
    },
    "lexicon": {
      "fr": {
        "spaceKindSeat": "Place",
        "spaceKindLevel": "Étage",
        "shellReserveButton": "Réservations"
      }
    }
  },
  "tables": {
    "fee_bands": [
      {
        "from_pct": 0,
        "to_pct": 50,
        "fee_cents": 5000,
        "overage_fee_cents": 0
      },
      {
        "from_pct": 50,
        "to_pct": 100,
        "fee_cents": 10000,
        "overage_fee_cents": 0
      }
    ],
    "workspace_roles": [
      {
        "key": "tresorier",
        "names": {
          "fr": "Trésorier·ère",
          "en": "Treasurer",
          "de": "Kassenwart",
          "es": "Tesorero/a",
          "it": "Tesoriere"
        },
        "permissions": [
          "viewFinances",
          "issueInvoices",
          "manageBilling",
          "approveExpenses",
          "exportData"
        ],
        "sort_order": 1,
        "active": true
      },
      {
        "key": "secretaire",
        "names": {
          "fr": "Secrétaire",
          "en": "Secretary",
          "de": "Schriftführer",
          "es": "Secretario/a",
          "it": "Segretario"
        },
        "permissions": [
          "manageMembers",
          "manageDocuments",
          "viewPersonalData"
        ],
        "sort_order": 2,
        "active": true
      },
      {
        "key": "referent_salle",
        "names": {
          "fr": "Référent·e de salle",
          "en": "Room steward",
          "de": "Raumverantwortlicher",
          "es": "Responsable de sala",
          "it": "Referente di sala"
        },
        "permissions": [
          "manageReservations",
          "manageValidation",
          "operateKiosk"
        ],
        "sort_order": 3,
        "active": true
      }
    ],
    "credit_products": [
      {
        "name": "Carnet 10 demi-journées",
        "half_days": 10,
        "price_cents": 5000,
        "validity_months": null,
        "active": true,
        "sort_order": 1
      },
      {
        "name": "Carnet 20 demi-journées",
        "half_days": 20,
        "price_cents": 8000,
        "validity_months": null,
        "active": true,
        "sort_order": 2
      }
    ]
  },
  "holidays": {
    "years": 2
  }
}
$cfg$::jsonb,
  $tpl$[
  {
    "name": "Rez-de-chaussée",
    "sort_order": 0,
    "bookable_as_whole": false,
    "price_cents": 0,
    "background_path": "",
    "site": null,
    "images": [],
    "offices": [
      {
        "name": "Salle principale",
        "color": 0,
        "bookable_as_whole": true,
        "price_cents": 0,
        "x": 0,
        "y": 0,
        "w": 40,
        "h": 24,
        "desks": [
          {
            "name": "Table 1",
            "x": 2,
            "y": 2,
            "w": 14,
            "h": 8,
            "bookable_as_whole": true,
            "price_cents": 0,
            "seats": [
              {
                "name": "A1",
                "x": 4,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              },
              {
                "name": "A2",
                "x": 12,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              }
            ]
          },
          {
            "name": "Table 2",
            "x": 22,
            "y": 2,
            "w": 14,
            "h": 8,
            "bookable_as_whole": true,
            "price_cents": 0,
            "seats": [
              {
                "name": "B1",
                "x": 24,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              },
              {
                "name": "B2",
                "x": 32,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              }
            ]
          }
        ]
      }
    ]
  },
  {
    "name": "Étage",
    "sort_order": 1,
    "bookable_as_whole": false,
    "price_cents": 0,
    "background_path": "",
    "site": null,
    "images": [],
    "offices": [
      {
        "name": "Salle du haut",
        "color": 0,
        "bookable_as_whole": true,
        "price_cents": 0,
        "x": 0,
        "y": 0,
        "w": 40,
        "h": 24,
        "desks": [
          {
            "name": "Table 3",
            "x": 2,
            "y": 2,
            "w": 14,
            "h": 8,
            "bookable_as_whole": true,
            "price_cents": 0,
            "seats": [
              {
                "name": "C1",
                "x": 4,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              },
              {
                "name": "C2",
                "x": 12,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              }
            ]
          },
          {
            "name": "Table 4",
            "x": 22,
            "y": 2,
            "w": 14,
            "h": 8,
            "bookable_as_whole": true,
            "price_cents": 0,
            "seats": [
              {
                "name": "D1",
                "x": 24,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              },
              {
                "name": "D2",
                "x": 32,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              }
            ]
          }
        ]
      }
    ]
  }
]
$tpl$::jsonb
)
on conflict (key) where owner_workspace_id is null do update
  set name = excluded.name,
      description = excluded.description,
      sort_order = excluded.sort_order,
      schema_version = excluded.schema_version,
      template_version = public.workspace_templates.template_version + 1,
      tags = excluded.tags,
      entities = excluded.entities,
      configuration = excluded.configuration,
      floor_plan = excluded.floor_plan;

-- The setup steps and levels name kioskEnrolment (dart run tool/build_setup_steps.dart).
create or replace function public.setup_step_catalogue()
returns jsonb language sql immutable set search_path = public as $fn$
  select $json$[{"id":"basics","group":"open","milestone":"bookable","route":"/setup/step/basics","evidence":"basics","feature":null,"required":true,"depends_on":[],"actor":"owner","estimate_minutes":3,"secret":false},{"id":"hours","group":"open","milestone":"bookable","route":"/setup/step/hours","evidence":"hours","feature":null,"required":true,"depends_on":["basics"],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"places","group":"open","milestone":"bookable","route":"/setup/step/places","evidence":"places","feature":"placeBooking","required":true,"depends_on":["basics"],"actor":"owner","estimate_minutes":10,"secret":false},{"id":"member_rights","group":"open","milestone":"bookable","route":"/setup/step/member_rights","evidence":"member_rights","feature":null,"required":true,"depends_on":[],"actor":"owner","estimate_minutes":1,"secret":false},{"id":"invite","group":"open","milestone":"bookable","route":"/setup/step/invite","evidence":"invite","feature":null,"required":false,"depends_on":["member_rights"],"actor":"owner","estimate_minutes":3,"secret":false},{"id":"pricing","group":"run","milestone":"money","route":"/setup/step/pricing","evidence":"pricing","feature":"moneyTab","required":true,"depends_on":[],"actor":"owner","estimate_minutes":10,"secret":false},{"id":"services","group":"run","milestone":"money","route":"/setup/step/services","evidence":"services","feature":"services","required":false,"depends_on":[],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"payment_methods","group":"run","milestone":"money","route":"/setup/step/payment_methods","evidence":"payment_methods","feature":"moneyTab","required":true,"depends_on":["pricing"],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"online_payments","group":"run","milestone":"money","route":"/setup/step/online_payments","evidence":"online_payments","feature":"onlinePayments","required":true,"depends_on":["payment_methods"],"actor":"operator","estimate_minutes":5,"secret":true},{"id":"approvals","group":"run","milestone":"money","route":"/setup/step/approvals","evidence":"approvals","feature":null,"required":true,"depends_on":["invite"],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"new_members","group":"run","milestone":"live","route":"/setup/step/new_members","evidence":"manual","feature":null,"required":false,"depends_on":[],"actor":"owner","estimate_minutes":3,"secret":false},{"id":"notifications","group":"run","milestone":"live","route":"/setup/step/notifications","evidence":"manual","feature":null,"required":false,"depends_on":[],"actor":"owner","estimate_minutes":3,"secret":false},{"id":"limits","group":"run","milestone":"live","route":"/setup/step/limits","evidence":"manual","feature":"bookingPolicies","required":false,"depends_on":[],"actor":"owner","estimate_minutes":3,"secret":false},{"id":"kiosk","group":"run","milestone":"live","route":"/setup/step/kiosk","evidence":"kiosk","feature":"kioskMode","required":false,"depends_on":[],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"purchases","group":"run","milestone":"money","route":"/setup/step/purchases","evidence":"purchases","feature":"purchases","required":false,"depends_on":[],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"lease","group":"run","milestone":"money","route":"/setup/step/lease","evidence":"lease","feature":"premisesLease","required":false,"depends_on":[],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"assets","group":"run","milestone":"money","route":"/setup/step/assets","evidence":"assets","feature":"assetRegister","required":false,"depends_on":[],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"look","group":"run","milestone":"live","route":"/setup/step/look","evidence":"look","feature":"workspaceBranding","required":false,"depends_on":[],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"public_page","group":"run","milestone":"live","route":"/setup/step/public_page","evidence":"public_page","feature":"publicListings","required":false,"depends_on":[],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"legal_identity","group":"grow","milestone":"invoice","route":"/setup/step/legal_identity","evidence":"legal_identity","feature":"invoicing","required":true,"depends_on":[],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"vat","group":"grow","milestone":"invoice","route":"/setup/step/vat","evidence":"vat","feature":"vatManagement","required":true,"depends_on":["legal_identity"],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"numbering","group":"grow","milestone":"invoice","route":"/setup/step/numbering","evidence":"numbering","feature":"numberSequences","required":true,"depends_on":["legal_identity"],"actor":"owner","estimate_minutes":3,"secret":false},{"id":"documents","group":"grow","milestone":"invoice","route":"/setup/step/documents","evidence":"documents","feature":"invoicePdfTemplate","required":false,"depends_on":["legal_identity"],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"einvoicing","group":"grow","milestone":"invoice","route":"/setup/step/einvoicing","evidence":"einvoicing","feature":"einvoiceCustomerDelivery","required":true,"depends_on":["legal_identity","numbering"],"actor":"owner","estimate_minutes":15,"secret":true},{"id":"accounting","group":"grow","milestone":"invoice","route":"/setup/step/accounting","evidence":"accounting","feature":"accountingBook","required":true,"depends_on":["vat"],"actor":"owner","estimate_minutes":10,"secret":false},{"id":"reminders","group":"grow","milestone":"invoice","route":"/setup/step/reminders","evidence":"reminders","feature":"dunning","required":false,"depends_on":[],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"first_booking","group":"launch","milestone":"live","route":"/reserve","evidence":"first_booking","feature":"placeBooking","required":true,"depends_on":["places","member_rights"],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"recovery","group":"launch","milestone":"live","route":"/workspace-settings","evidence":"recovery","feature":null,"required":false,"depends_on":[],"actor":"owner","estimate_minutes":2,"secret":false},{"id":"assistant","group":"launch","milestone":"live","route":"/settings/assistant-setup","evidence":"assistant","feature":"mcpAccess","required":false,"depends_on":[],"actor":"operator","estimate_minutes":5,"secret":false}]$json$::jsonb;
$fn$;
revoke execute on function public.setup_step_catalogue() from public, anon;
grant execute on function public.setup_step_catalogue() to authenticated;

create or replace function public.setup_level_catalogue()
returns jsonb language sql immutable set search_path = public as $fn$
  select $json${"processes":[{"process":"bookings","levels":[{"level":"none","features":[],"needs":[]},{"level":"simple","features":["seriesBooking","bookForOthers","spaceQrCodes","workingHours","planObjectDelete","bookingPolicies","seatDayTimeline","bookingGate","singleRoomLevelNames","calendarFileExport","placeFeedback","planDecor","placeBooking"],"needs":[]},{"level":"resources","features":["adminSeatBlocking","levelBooking","adminLevelAssign","planMemberPhotos","multiSite","publicHolidays","holidayImport","guestParticipation","meetingRooms","parking","externalRooms"],"needs":[]},{"level":"measured","features":["kioskMode","nfcBadges","autoCheckInOut","nfcSeatTags","qrBadges","kioskMemberPhotos","badgeSignIn","capacityKpi","kioskEnrolment"],"needs":[]}]},{"process":"community","levels":[{"level":"basic","features":["calendarTab","eventsTab","pushNotifications","membersDirectory","memberNotifications","deletionRequests","roleManagement","notificationGrouping","calendarHub","richMessageRefs","personalInfo","messageGestures","calendarViews","messagesHub","memberPage","messageForwarding","captureProtection","roleAssignment","messageMentions"],"needs":[]},{"level":"organised","features":["whatsappIntegration","coOwner","validationScopes","validationChain","calendarValidations","managedProfiles","managedProfileAccess","memberOrigin","customRoles","customFields"],"needs":[]}]},{"process":"money","levels":[{"level":"none","features":[],"needs":[]},{"level":"statements","features":["moneyTab","services","accessorySupplements","memberReports","dataAccessLog","financeFaces","priceNegotiations"],"needs":[]},{"level":"invoices","features":["invoicing","adminInvoicing","invoicePdfTemplate","invoiceAddressWindow","dunning","paymentReminders","usageRecords","reportDesignExchange","reportLayouts","numberSequences","workspaceStatus","memberPaymentTerms","reportTexts","usageReport","letterStandard","subscriptionInvoices","usageInvoices","invoiceSettlement","invoiceJourney","reportDesigner","invoicingWizard","settlementFold","carnets","guestPasses","reminderEmail","invoiceEmail"],"needs":[]}]},{"process":"payments","levels":[{"level":"off","features":[],"needs":[]},{"level":"online","features":["onlinePayments"],"needs":[{"process":"money","level":"statements"}]}]},{"process":"tax","levels":[{"level":"none","features":[],"needs":[]},{"level":"vat","features":["vatManagement","vatDeclarations","vatGroups","vatRateHistory","vatCounterparty","vatReport","supplyClassification","viesVerification","recapitulativeStatement","inputVat","salesTax"],"needs":[{"process":"money","level":"invoices"}]},{"level":"books","features":["einvoiceCustomerDelivery","accountingBook","accountingPeriods","accountingConnectors","bankImport","mtdSubmission"],"needs":[{"process":"money","level":"invoices"}]}]},{"process":"purchases","levels":[{"level":"none","features":[],"needs":[]},{"level":"expenses","features":["supplyExpenses","expenseRepartitionWizard","scheduledExpenses","expenseRepartition"],"needs":[{"process":"money","level":"invoices"}]},{"level":"full","features":["purchases","premisesLease","assetRegister","purchaseAnalytics","foreignCurrencyPurchases","purchaseOrders"],"needs":[{"process":"money","level":"invoices"}]}]},{"process":"presentation","levels":[{"level":"basic","features":["uniqueMonograms"],"needs":[]},{"level":"branded","features":["workspaceVocabulary","workspaceBranding"],"needs":[]},{"level":"public","features":["publicListings","spaceInquiries"],"needs":[]}]},{"process":"operations","levels":[{"level":"basic","features":["pdfExport","dataExport","documents","formHelpHints","uiAnimations","regionalFormats","memberDataExport","navigationStyle","demoMode","memberAccountMenu","memberGettingStarted","setupGuide","dataReport"],"needs":[]},{"level":"insight","features":["decisionSurface","biReportDesigner","workspaceOverview"],"needs":[]},{"level":"advanced","features":["environmentPairs","deployments","configurationTransfer","instanceWizard","memberEnvironments","workspaceLibrary","configurableSettings"],"needs":[]}]},{"process":"assistant","levels":[{"level":"off","features":[],"needs":[]},{"level":"on","features":["recordingPrivacy","mcpAccess","taskRecorder","webMcp"],"needs":[]}]}],"presets":[{"preset":"essentiel","levels":[{"process":"bookings","level":"simple"},{"process":"community","level":"basic"},{"process":"money","level":"statements"},{"process":"payments","level":"off"},{"process":"tax","level":"none"},{"process":"purchases","level":"none"},{"process":"presentation","level":"basic"},{"process":"operations","level":"basic"},{"process":"assistant","level":"off"}]},{"preset":"standard","levels":[{"process":"bookings","level":"resources"},{"process":"community","level":"organised"},{"process":"money","level":"invoices"},{"process":"payments","level":"off"},{"process":"tax","level":"none"},{"process":"purchases","level":"expenses"},{"process":"presentation","level":"branded"},{"process":"operations","level":"insight"},{"process":"assistant","level":"off"}]},{"preset":"complet","levels":[{"process":"bookings","level":"measured"},{"process":"community","level":"organised"},{"process":"money","level":"invoices"},{"process":"payments","level":"online"},{"process":"tax","level":"books"},{"process":"purchases","level":"full"},{"process":"presentation","level":"public"},{"process":"operations","level":"advanced"},{"process":"assistant","level":"off"}]}]}$json$::jsonb;
$fn$;
revoke execute on function public.setup_level_catalogue() from public, anon, authenticated;

-- ── the owners' event: kiosk_device ─────────────────────────────────────
create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
declare
  v_pattern text;
  v_out text;
begin
  if position(p_old in p_def) > 0 then
    return replace(p_def, p_old, p_new);
  end if;
  v_pattern := regexp_replace(btrim(p_old, E' \t\n'), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
  v_pattern := regexp_replace(v_pattern, '\s+', '\\s*', 'g');
  v_out := regexp_replace(p_def, v_pattern, replace(btrim(p_new, E' \t\n'), '\', '\\'), 'g');
  return case when v_out = p_def then null else v_out end;
end
$f$;

revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $migration$
declare
  v_def text;
  r record;
begin
  -- the new event type: both type checks, as 0722 did
  for r in select * from (values
    ('events','events_type_check','type'),
    ('validation_policies','validation_policies_event_type_check','event_type')
  ) as c(table_name,constraint_name,column_name) loop
    select pg_get_constraintdef(oid) into v_def from pg_constraint
     where conrelid=('public.'||r.table_name)::regclass and conname=r.constraint_name;
    if v_def is null or position('CHECK (' in v_def) <> 1 then
      raise exception 'event type constraint anchor missing: %',r.constraint_name;
    end if;
    if position('kiosk_device' in v_def)=0 then
      execute format('alter table public.%I drop constraint %I',r.table_name,r.constraint_name);
      execute format('alter table public.%I add constraint %I ',r.table_name,r.constraint_name)
        || replace(v_def,'CHECK (',format('CHECK (%I = %L OR ',r.column_name,'kiosk_device'));
    end if;
  end loop;

  -- who reads it: whoever may change the business's settings (the owners)
  select pg_get_functiondef('public.event_type_view_permissions(text)'::regprocedure) into v_def;
  if position('kiosk_device' in v_def) = 0 then
    v_def := pg_temp.anchor_replace(v_def,
      $a$when p_type = 'settlement_review'
      then array['viewFinances']$a$,
      $a$when p_type = 'settlement_review'
      then array['viewFinances']
    when p_type = 'kiosk_device'
      then array['workspaceSettings']$a$);
    if v_def is null then raise exception '0734: event_type_view_permissions anchor missing'; end if;
    execute v_def;
  end if;
end
$migration$;

-- Equality of two sha256 hex digests in a time that does not depend on
-- where they differ.
create or replace function public.same_sha256_hex(p_a text, p_b text)
returns boolean language plpgsql immutable set search_path = '' as $fn$
declare
  a bytea;
  b bytea;
  diff int := 0;
begin
  if p_a !~ '^[0-9a-f]{64}$' or p_b !~ '^[0-9a-f]{64}$' then
    return false;
  end if;
  a := decode(p_a, 'hex');
  b := decode(p_b, 'hex');
  for i in 0 .. 31 loop
    diff := diff | (get_byte(a, i) # get_byte(b, i));
  end loop;
  return diff = 0;
end;
$fn$;
revoke execute on function public.same_sha256_hex(text, text) from public, anon, authenticated;

-- The business of a valid device: enrolled, not revoked, presenting its own
-- credential, of a business with kiosk enrolment on. Anything else is null, through the same steps: the digest
-- is always taken and always compared (with a stand-in for a missing row).
create or replace function public.kiosk_device_business(p_device_id uuid, p_secret text)
returns uuid language plpgsql security definer set search_path = '' as $fn$
declare
  v_presented text := encode(extensions.digest(coalesce(p_secret, ''), 'sha256'), 'hex');
  v_row public.kiosk_devices;
  v_same boolean;
begin
  select * into v_row from public.kiosk_devices
   where id = p_device_id and revoked_at is null;
  v_same := public.same_sha256_hex(v_presented,
    coalesce(v_row.secret_hash, repeat('0', 64)));
  if v_row.id is null or not v_same or coalesce(p_secret, '') = ''
     or not public.feature_effective(v_row.workspace_id, 'kioskEnrolment') then
    return null;
  end if;
  return v_row.workspace_id;
end;
$fn$;
revoke execute on function public.kiosk_device_business(uuid, text) from public, anon, authenticated;

-- Who may enrol, list and revoke: a holder of operateKiosk or an owner, in
-- their own session.
create or replace function public.may_manage_kiosk_devices(p_workspace_id uuid)
returns boolean language sql stable security definer set search_path = '' as $fn$
  select auth.uid() is not null and not public.mcp_is_delegated() and (
    public.has_permission(p_workspace_id, 'operateKiosk')
    or exists (select 1 from public.members m
                where m.workspace_id = p_workspace_id and m.user_id = auth.uid()
                  and m.status = 'active' and (m.is_owner or m.co_owner = 'active')))
$fn$;
revoke execute on function public.may_manage_kiosk_devices(uuid) from public, anon, authenticated;

-- One event per owner: who did what to which device.
create or replace function public.tell_owners_kiosk_device(
  p_workspace_id uuid, p_change text, p_device public.kiosk_devices)
returns void language sql security definer set search_path = '' as $fn$
  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
  select p_workspace_id, 'kiosk_device', 'created',
         (select a.id from public.members a
           where a.workspace_id = p_workspace_id and a.user_id = auth.uid() limit 1),
         m.id,
         jsonb_build_object('change', p_change, 'device_id', p_device.id, 'device_name', p_device.name),
         'applied'
    from public.members m
   where m.workspace_id = p_workspace_id and m.status = 'active'
     and (m.is_owner or m.co_owner = 'active')
$fn$;
revoke execute on function public.tell_owners_kiosk_device(uuid, text, public.kiosk_devices) from public, anon, authenticated;

-- Enrols the calling device. The credential is in this answer and nowhere
-- else, ever.
create or replace function public.enrol_kiosk_device_v1(p_workspace_id uuid, p_name text)
returns jsonb language plpgsql security definer set search_path = '' as $fn$
declare
  v_credential text;
  v_row public.kiosk_devices;
begin
  if not public.may_manage_kiosk_devices(p_workspace_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if not public.feature_effective(p_workspace_id, 'kioskEnrolment') then
    raise exception 'kiosk enrolment is off' using errcode = '42501';
  end if;
  if length(btrim(coalesce(p_name, ''))) not between 1 and 80 then
    raise exception 'a name of 1 to 80 characters is required' using errcode = '22023';
  end if;
  v_credential := encode(extensions.gen_random_bytes(32), 'hex');
  insert into public.kiosk_devices (workspace_id, name, secret_hash, enrolled_by)
  values (p_workspace_id, btrim(p_name),
          encode(extensions.digest(v_credential, 'sha256'), 'hex'),
          (select m.id from public.members m
            where m.workspace_id = p_workspace_id and m.user_id = auth.uid() limit 1))
  returning * into v_row;
  perform public.tell_owners_kiosk_device(p_workspace_id, 'enrolled', v_row);
  return jsonb_build_object('device_id', v_row.id, 'credential', v_credential);
end;
$fn$;
revoke execute on function public.enrol_kiosk_device_v1(uuid, text) from public, anon;
grant execute on function public.enrol_kiosk_device_v1(uuid, text) to authenticated;

-- Revokes a device: it is no kiosk from now on. false when it was revoked
-- already.
create or replace function public.revoke_kiosk_device_v1(p_device_id uuid)
returns boolean language plpgsql security definer set search_path = '' as $fn$
declare
  v_row public.kiosk_devices;
begin
  select * into v_row from public.kiosk_devices where id = p_device_id for update;
  if v_row.id is null or not public.may_manage_kiosk_devices(v_row.workspace_id) then
    raise exception 'unknown device' using errcode = '42501';
  end if;
  if v_row.revoked_at is not null then
    return false;
  end if;
  update public.kiosk_devices
     set revoked_at = now(),
         revoked_by = (select m.id from public.members m
                        where m.workspace_id = v_row.workspace_id and m.user_id = auth.uid() limit 1)
   where id = p_device_id
  returning * into v_row;
  perform public.tell_owners_kiosk_device(v_row.workspace_id, 'revoked', v_row);
  return true;
end;
$fn$;
revoke execute on function public.revoke_kiosk_device_v1(uuid) from public, anon;
grant execute on function public.revoke_kiosk_device_v1(uuid) to authenticated;

-- A business's devices, newest first, without their hash.
create or replace function public.kiosk_devices_v1(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $fn$
begin
  if not public.may_manage_kiosk_devices(p_workspace_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', d.id, 'name', d.name,
             'enrolled_by', public.profile_full_name(p),
             'enrolled_at', d.enrolled_at, 'last_used_at', d.last_used_at,
             'revoked_at', d.revoked_at) order by d.enrolled_at desc, d.id)
      from public.kiosk_devices d
      left join public.members m on m.id = d.enrolled_by
      left join public.profiles p on p.id = m.user_id
     where d.workspace_id = p_workspace_id), '[]'::jsonb);
end;
$fn$;
revoke execute on function public.kiosk_devices_v1(uuid) from public, anon;
grant execute on function public.kiosk_devices_v1(uuid) to authenticated;

-- ── where badge sign-in works ───────────────────────────────────────────
-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('security.badge_signin_where', 'enum', '"enrolled_kiosks"'::jsonb, null, null, '', 'security', array['workspace'], 'workspaceSettings', null, true, '["enrolled_kiosks","any_device"]'::jsonb, 'badge_auth_verify (#3675)', 'Where badge sign-in works: only on the devices the business enrolled as kiosks, or on any device. On an enrolled kiosk the badge step greets the person by name; elsewhere nobody is named before the PIN. A business that already issued badges stays on any device until its owner switches.')
on conflict (key) do nothing;
-- END GENERATED SEED

-- A business that already issued badges keeps today's behaviour until its
-- owner switches.
insert into public.setting_values (scope, workspace_id, key, value, note)
select 'workspace', w.id, 'security.badge_signin_where', '"any_device"'::jsonb,
       'kept as before by migration 0734 (#3675): badges were issued before kiosks could be enrolled'
  from public.workspaces w
 where exists (select 1 from public.member_badges b where b.workspace_id = w.id)
on conflict do nothing;

-- ── where a failed PIN came from ────────────────────────────────────────
-- A failed PIN is counted on the side it came from: with a valid kiosk or
-- without one. Each side counts only its own, so nothing tried off a kiosk
-- locks a badge at its kiosk, and off a kiosk a real and an unknown tag
-- still lock alike. Every earlier row came without a kiosk.
alter table public.badge_auth_attempts
  add column on_kiosk boolean not null default false;

-- Whether the business signs in on its enrolled kiosks only: the setting,
-- in force while kiosk enrolment is on.
create or replace function public.badge_signin_kiosks_only(p_workspace_id uuid)
returns boolean language sql stable security definer set search_path = '' as $fn$
  select p_workspace_id is not null
     and public.feature_effective(p_workspace_id, 'kioskEnrolment')
     and (public.setting_value(p_workspace_id, 'security.badge_signin_where') #>> '{}') is distinct from 'any_device'
$fn$;
revoke execute on function public.badge_signin_kiosks_only(uuid) from public, anon, authenticated;

-- ── the pause ───────────────────────────────────────────────────────────
-- Badge sign-in of a business is paused while as many distinct badges of it
-- as its ceiling failed their PIN within the window: at its kiosks where it
-- signs in on enrolled kiosks only, anywhere otherwise.
create or replace function public.badge_signin_paused(p_workspace_id uuid)
returns boolean language plpgsql stable security definer set search_path = '' as $fn$
declare
  v_window int := (public.setting_value(null, 'security.badge_lockout_minutes') #>> '{}')::int;
  v_limit int := (public.setting_value(p_workspace_id, 'security.badge_workspace_failure_limit') #>> '{}')::int;
  v_kiosks_only boolean := public.badge_signin_kiosks_only(p_workspace_id);
begin
  return p_workspace_id is not null and (
    select count(distinct token_hash) from public.badge_auth_attempts
     where workspace_id = p_workspace_id and not succeeded and step = 'pin'
       and (on_kiosk or not v_kiosks_only)
       and attempted_at > now() - make_interval(mins => v_window)) >= v_limit;
end;
$fn$;
revoke execute on function public.badge_signin_paused(uuid) from public, anon, authenticated;

-- A failed PIN, on the side it came from. The owners are told once per
-- window when their business is paused -- or, off a kiosk, when one of its
-- badges reaches the lock there: the attempt is seen though it does not
-- bite. Restated from 0714 with the side; the one caller is badge_auth_verify.
drop function if exists public.record_badge_auth_failure(text, uuid);
create or replace function public.record_badge_auth_failure(
  p_hash text, p_workspace uuid, p_on_kiosk boolean default false, p_tried_for uuid default null)
returns void language plpgsql security definer set search_path = '' as $fn$
declare
  v_window int := (public.setting_value(null, 'security.badge_lockout_minutes') #>> '{}')::int;
  v_failures int := (public.setting_value(null, 'security.badge_lockout_failures') #>> '{}')::int;
  v_told uuid := coalesce(p_workspace, p_tried_for);
  v_count int;
  v_tell boolean;
begin
  insert into public.badge_auth_attempts (token_hash, succeeded, workspace_id, step, on_kiosk)
  values (p_hash, false, p_workspace, 'pin', coalesce(p_on_kiosk, false));
  if v_told is null then return; end if;
  if p_workspace is not null then
    v_tell := public.badge_signin_paused(p_workspace);
    select count(*) into v_count from public.badge_auth_attempts
     where workspace_id = p_workspace and not succeeded and step = 'pin'
       and attempted_at > now() - make_interval(mins => v_window);
  else
    -- p_tried_for: a badge of that business tried where it is not signed in.
    select count(*) into v_count from public.badge_auth_attempts
     where token_hash = p_hash and not succeeded and step = 'pin' and not on_kiosk
       and attempted_at > now() - make_interval(mins => v_window);
    v_tell := v_count >= v_failures;
  end if;
  if v_tell and not exists (
    select 1 from public.events where workspace_id = v_told
      and type = 'badge_security_alert'
      and created_at > now() - make_interval(mins => v_window)
  ) then
    insert into public.events
      (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
    select v_told, 'badge_security_alert', 'created', m.id, m.id,
      jsonb_build_object('failures', v_count, 'window_minutes', v_window), 'applied'
      from public.members m where m.workspace_id = v_told
        and m.status = 'active' and (m.is_owner or m.co_owner = 'active');
  end if;
end;
$fn$;
revoke execute on function public.record_badge_auth_failure(text, uuid, boolean, uuid) from public, anon, authenticated;

drop function if exists public.badge_auth_verify(text, text, text);
create or replace function public.badge_auth_verify(
  p_uid text, p_pin text default null, p_source text default null,
  p_device_id uuid default null, p_device_secret text default null)
returns jsonb language plpgsql security definer set search_path = '' as $fn$
declare
  v_hash text := public.badge_token_hash(p_uid);
  v_source text := public.badge_source_key(p_source);
  v_badge public.member_badges;
  v_member public.members;
  v_pin_hash text;
  v_pin_matches boolean := false;
  v_enabled boolean := false;
  v_failures int := (public.setting_value(null, 'security.badge_lockout_failures') #>> '{}')::int;
  v_window int := (public.setting_value(null, 'security.badge_lockout_minutes') #>> '{}')::int;
  v_per_tag int;
  v_per_source int;
  v_recent int;
  v_hour int;
  v_day int;
  v_profile public.profiles;
  v_kiosk uuid;
  v_on_kiosk boolean;
  v_name text;
begin
  -- #3675: the device first, through the same steps whether it is one or
  -- not; a revoked, unknown or foreign device is no device.
  v_kiosk := public.kiosk_device_business(p_device_id, p_device_secret);

  -- SCAN: counted per tag and per source; the same answer for every tag,
  -- except on a valid kiosk, which names the person of its own business.
  if p_pin is null then
    v_per_tag := (public.setting_value(null, 'security.badge_identify_per_tag_limit') #>> '{}')::int;
    v_per_source := (public.setting_value(null, 'security.badge_identify_per_source_limit') #>> '{}')::int;
    perform pg_advisory_xact_lock(hashtextextended('badge-identify:' || v_hash, 0));
    if v_source is not null then
      perform pg_advisory_xact_lock(hashtextextended('badge-identify-source:' || v_source, 0));
    end if;
    -- Scans older than the window count for nothing: they go.
    delete from public.badge_auth_attempts
     where step = 'identify' and attempted_at <= now() - make_interval(mins => v_window);
    if v_source is not null and (select count(*) from public.badge_auth_attempts
         where source_hash = v_source and step = 'identify') >= v_per_source then
      -- One place scanning past its ceiling: the business of a known badge
      -- is told once per window.
      select * into v_badge from public.member_badges
       where token_hash = v_hash and revoked_at is null
       order by created_at, id limit 1;
      if v_badge.workspace_id is not null and not exists (
        select 1 from public.events where workspace_id = v_badge.workspace_id
          and type = 'badge_security_alert'
          and created_at > now() - make_interval(mins => v_window)) then
        insert into public.events
          (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
        select v_badge.workspace_id, 'badge_security_alert', 'created', m.id, m.id,
          jsonb_build_object('failures', v_per_source, 'window_minutes', v_window), 'applied'
          from public.members m where m.workspace_id = v_badge.workspace_id
            and m.status = 'active' and (m.is_owner or m.co_owner = 'active');
      end if;
      return jsonb_build_object('ok', false, 'reason', 'locked');
    end if;
    if (select count(*) from public.badge_auth_attempts
         where token_hash = v_hash and step = 'identify') >= v_per_tag then
      return jsonb_build_object('ok', false, 'reason', 'locked');
    end if;
    -- A valid kiosk of a paused business: every tag scanned there waits.
    if v_kiosk is not null and public.badge_signin_paused(v_kiosk) then
      return jsonb_build_object('ok', false, 'reason', 'locked');
    end if;
    insert into public.badge_auth_attempts (token_hash, succeeded, step, source_hash)
    values (v_hash, true, 'identify', v_source);
    if v_kiosk is not null then
      select p.display_name into v_name
        from public.member_badges b
        join public.members m on m.id = b.member_id and m.status = 'active'
        join public.workspaces w on w.id = b.workspace_id
        join public.profiles p on p.id = m.user_id
       where b.token_hash = v_hash and b.revoked_at is null and b.auth_enabled
         and b.workspace_id = v_kiosk
         and public.feature_effective_in(w.feature_flags, 'badgeSignIn')
       order by b.created_at, b.id limit 1;
      if v_name is not null then
        return jsonb_build_object('ok', true, 'display_name', v_name);
      end if;
    end if;
    return jsonb_build_object('ok', true);
  end if;

  select * into v_badge from public.member_badges
   where token_hash = v_hash and revoked_at is null and auth_enabled
   order by created_at, id limit 1;
  v_on_kiosk := v_kiosk is not null and v_kiosk = v_badge.workspace_id;

  -- Every PIN attempt does one bcrypt operation at the stored cost, including
  -- unknown, inactive, disabled, missing-PIN, off-kiosk and locked
  -- credentials. This fixed dummy is not a credential and can never
  -- authorize an account.
  select k.pin_hash into v_pin_hash from public.account_badge_pins k
    join public.members m on m.user_id = k.user_id where m.id = v_badge.member_id;
  v_pin_matches := extensions.crypt(p_pin, coalesce(nullif(v_pin_hash,''),
    '$2a$10$2plMicy7EHI.UoIbbvMoN.1Qo8HHEaVimd3U1x43GzYgUfyETw.H.')) = v_pin_hash;

  -- Serialize the check and the failure record across badges of one workspace.
  -- An unknown tag retains its own lock without charging an unrelated workspace.
  perform pg_advisory_xact_lock(hashtextextended(
    'badge-signin:' || coalesce(v_badge.workspace_id::text, v_hash), 0));
  -- The failures of this side only: with a valid kiosk, or without one.
  select count(*) filter (where attempted_at > now() - make_interval(mins => v_window)),
         count(*) filter (where attempted_at > now() - interval '1 hour'), count(*)
    into v_recent, v_hour, v_day from public.badge_auth_attempts
   where token_hash = v_hash and not succeeded and step = 'pin'
     and on_kiosk = (v_kiosk is not null)
     and attempted_at > now() - interval '24 hours';
  if v_recent >= v_failures or v_hour >= 2*v_failures or v_day >= 3*v_failures then
    return jsonb_build_object('ok',false,'reason','locked');
  end if;
  -- A valid kiosk of a paused business: every tag there waits.
  if v_kiosk is not null and public.badge_signin_paused(v_kiosk) then
    return jsonb_build_object('ok',false,'reason','locked');
  end if;
  -- Off a kiosk of its own business, a tag of a business that signs in on
  -- enrolled kiosks only, or of a paused one, is answered and counted as an
  -- unknown tag on this side: per tag, never against the business, and never
  -- toward the lock at its kiosk. Its owners are told if it is hammered.
  if not v_on_kiosk and v_badge.workspace_id is not null
     and (public.badge_signin_kiosks_only(v_badge.workspace_id)
          or public.badge_signin_paused(v_badge.workspace_id)) then
    perform public.record_badge_auth_failure(v_hash, null, v_kiosk is not null, v_badge.workspace_id);
    return jsonb_build_object('ok',false,'reason','refused');
  end if;

  select * into v_member from public.members
   where id = v_badge.member_id and status = 'active';
  if v_member.id is not null then
    select public.feature_effective_in(w.feature_flags,'badgeSignIn') into v_enabled
      from public.workspaces w where w.id = v_member.workspace_id;
  end if;
  if v_badge.id is null or v_member.id is null or not coalesce(v_enabled,false)
      or length(coalesce(p_uid,'')) < 8 or not coalesce(v_pin_matches,false) then
    perform public.record_badge_auth_failure(v_hash, v_badge.workspace_id, v_kiosk is not null);
    return jsonb_build_object('ok',false,'reason','refused');
  end if;
  insert into public.badge_auth_attempts (token_hash,succeeded,workspace_id,step,on_kiosk)
  values (v_hash,true,v_badge.workspace_id,'pin',v_kiosk is not null);
  -- The right PIN: this badge's scans stop counting.
  delete from public.badge_auth_attempts
   where step = 'identify' and token_hash = v_hash;
  if v_on_kiosk then
    update public.kiosk_devices set last_used_at = now() where id = p_device_id;
  end if;
  select * into v_profile from public.profiles where id = v_member.user_id;
  -- The name is said once the PIN is right.
  return jsonb_build_object('ok',true,'user_id',v_member.user_id,
    'display_name',coalesce(v_profile.display_name,''));
end;
$fn$;
revoke execute on function public.badge_auth_verify(text, text, text, uuid, text) from public, anon, authenticated;
grant execute on function public.badge_auth_verify(text, text, text, uuid, text) to service_role;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(734);
