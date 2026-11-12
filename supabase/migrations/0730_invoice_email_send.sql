-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (the builtin template's row and the setup catalogues are restated; one
--  table and five functions are new; save_business_mail_sender_v1 is
--  restated whole; no workspace's stored flags move)
--
-- #3673 (invoices by e-mail, second of two files) -- an issued invoice
-- leaves by e-mail from the business's own sender (0724), behind the
-- feature `invoiceEmail` (0729). This file carries, in order:
--
--  1. the builtin template, which writes every flag explicitly
--     (supabase/templates/association_fr.json: invoiceEmail false), and the
--     setup step and level catalogues (dart run tool/build_setup_steps.dart);
--  2. the business's sender, which may be set when purchase orders,
--     reminders by e-mail OR invoices by e-mail are on;
--  3. the fence of an invoice e-mail (below).

-- ── 1. the builtin template and the setup catalogues ──
-- ── the builtin template carries `invoiceEmail` ──
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

-- The setup steps and levels name invoiceEmail (dart run tool/build_setup_steps.dart).
create or replace function public.setup_step_catalogue()
returns jsonb language sql immutable set search_path = public as $fn$
  select $json$[{"id":"basics","group":"open","milestone":"bookable","route":"/setup/step/basics","evidence":"basics","feature":null,"required":true,"depends_on":[],"actor":"owner","estimate_minutes":3,"secret":false},{"id":"hours","group":"open","milestone":"bookable","route":"/setup/step/hours","evidence":"hours","feature":null,"required":true,"depends_on":["basics"],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"places","group":"open","milestone":"bookable","route":"/setup/step/places","evidence":"places","feature":"placeBooking","required":true,"depends_on":["basics"],"actor":"owner","estimate_minutes":10,"secret":false},{"id":"member_rights","group":"open","milestone":"bookable","route":"/setup/step/member_rights","evidence":"member_rights","feature":null,"required":true,"depends_on":[],"actor":"owner","estimate_minutes":1,"secret":false},{"id":"invite","group":"open","milestone":"bookable","route":"/setup/step/invite","evidence":"invite","feature":null,"required":false,"depends_on":["member_rights"],"actor":"owner","estimate_minutes":3,"secret":false},{"id":"pricing","group":"run","milestone":"money","route":"/setup/step/pricing","evidence":"pricing","feature":"moneyTab","required":true,"depends_on":[],"actor":"owner","estimate_minutes":10,"secret":false},{"id":"services","group":"run","milestone":"money","route":"/setup/step/services","evidence":"services","feature":"services","required":false,"depends_on":[],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"payment_methods","group":"run","milestone":"money","route":"/setup/step/payment_methods","evidence":"payment_methods","feature":"moneyTab","required":true,"depends_on":["pricing"],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"online_payments","group":"run","milestone":"money","route":"/setup/step/online_payments","evidence":"online_payments","feature":"onlinePayments","required":true,"depends_on":["payment_methods"],"actor":"operator","estimate_minutes":5,"secret":true},{"id":"approvals","group":"run","milestone":"money","route":"/setup/step/approvals","evidence":"approvals","feature":null,"required":true,"depends_on":["invite"],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"new_members","group":"run","milestone":"live","route":"/setup/step/new_members","evidence":"manual","feature":null,"required":false,"depends_on":[],"actor":"owner","estimate_minutes":3,"secret":false},{"id":"notifications","group":"run","milestone":"live","route":"/setup/step/notifications","evidence":"manual","feature":null,"required":false,"depends_on":[],"actor":"owner","estimate_minutes":3,"secret":false},{"id":"limits","group":"run","milestone":"live","route":"/setup/step/limits","evidence":"manual","feature":"bookingPolicies","required":false,"depends_on":[],"actor":"owner","estimate_minutes":3,"secret":false},{"id":"kiosk","group":"run","milestone":"live","route":"/setup/step/kiosk","evidence":"kiosk","feature":"kioskMode","required":false,"depends_on":[],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"purchases","group":"run","milestone":"money","route":"/setup/step/purchases","evidence":"purchases","feature":"purchases","required":false,"depends_on":[],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"lease","group":"run","milestone":"money","route":"/setup/step/lease","evidence":"lease","feature":"premisesLease","required":false,"depends_on":[],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"assets","group":"run","milestone":"money","route":"/setup/step/assets","evidence":"assets","feature":"assetRegister","required":false,"depends_on":[],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"look","group":"run","milestone":"live","route":"/setup/step/look","evidence":"look","feature":"workspaceBranding","required":false,"depends_on":[],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"public_page","group":"run","milestone":"live","route":"/setup/step/public_page","evidence":"public_page","feature":"publicListings","required":false,"depends_on":[],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"legal_identity","group":"grow","milestone":"invoice","route":"/setup/step/legal_identity","evidence":"legal_identity","feature":"invoicing","required":true,"depends_on":[],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"vat","group":"grow","milestone":"invoice","route":"/setup/step/vat","evidence":"vat","feature":"vatManagement","required":true,"depends_on":["legal_identity"],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"numbering","group":"grow","milestone":"invoice","route":"/setup/step/numbering","evidence":"numbering","feature":"numberSequences","required":true,"depends_on":["legal_identity"],"actor":"owner","estimate_minutes":3,"secret":false},{"id":"documents","group":"grow","milestone":"invoice","route":"/setup/step/documents","evidence":"documents","feature":"invoicePdfTemplate","required":false,"depends_on":["legal_identity"],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"einvoicing","group":"grow","milestone":"invoice","route":"/setup/step/einvoicing","evidence":"einvoicing","feature":"einvoiceCustomerDelivery","required":true,"depends_on":["legal_identity","numbering"],"actor":"owner","estimate_minutes":15,"secret":true},{"id":"accounting","group":"grow","milestone":"invoice","route":"/setup/step/accounting","evidence":"accounting","feature":"accountingBook","required":true,"depends_on":["vat"],"actor":"owner","estimate_minutes":10,"secret":false},{"id":"reminders","group":"grow","milestone":"invoice","route":"/setup/step/reminders","evidence":"reminders","feature":"dunning","required":false,"depends_on":[],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"first_booking","group":"launch","milestone":"live","route":"/reserve","evidence":"first_booking","feature":"placeBooking","required":true,"depends_on":["places","member_rights"],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"recovery","group":"launch","milestone":"live","route":"/workspace-settings","evidence":"recovery","feature":null,"required":false,"depends_on":[],"actor":"owner","estimate_minutes":2,"secret":false},{"id":"assistant","group":"launch","milestone":"live","route":"/settings/assistant-setup","evidence":"assistant","feature":"mcpAccess","required":false,"depends_on":[],"actor":"operator","estimate_minutes":5,"secret":false}]$json$::jsonb;
$fn$;
revoke execute on function public.setup_step_catalogue() from public, anon;
grant execute on function public.setup_step_catalogue() to authenticated;

create or replace function public.setup_level_catalogue()
returns jsonb language sql immutable set search_path = public as $fn$
  select $json${"processes":[{"process":"bookings","levels":[{"level":"none","features":[],"needs":[]},{"level":"simple","features":["seriesBooking","bookForOthers","spaceQrCodes","workingHours","planObjectDelete","bookingPolicies","seatDayTimeline","bookingGate","singleRoomLevelNames","calendarFileExport","placeFeedback","planDecor","placeBooking"],"needs":[]},{"level":"resources","features":["adminSeatBlocking","levelBooking","adminLevelAssign","planMemberPhotos","multiSite","publicHolidays","holidayImport","guestParticipation","meetingRooms","parking","externalRooms"],"needs":[]},{"level":"measured","features":["kioskMode","nfcBadges","autoCheckInOut","nfcSeatTags","qrBadges","kioskMemberPhotos","badgeSignIn","capacityKpi"],"needs":[]}]},{"process":"community","levels":[{"level":"basic","features":["calendarTab","eventsTab","pushNotifications","membersDirectory","memberNotifications","deletionRequests","roleManagement","notificationGrouping","calendarHub","richMessageRefs","personalInfo","messageGestures","calendarViews","messagesHub","memberPage","messageForwarding","captureProtection","roleAssignment","messageMentions"],"needs":[]},{"level":"organised","features":["whatsappIntegration","coOwner","validationScopes","validationChain","calendarValidations","managedProfiles","managedProfileAccess","memberOrigin","customRoles","customFields"],"needs":[]}]},{"process":"money","levels":[{"level":"none","features":[],"needs":[]},{"level":"statements","features":["moneyTab","services","accessorySupplements","memberReports","dataAccessLog","financeFaces","priceNegotiations"],"needs":[]},{"level":"invoices","features":["invoicing","adminInvoicing","invoicePdfTemplate","invoiceAddressWindow","dunning","paymentReminders","usageRecords","reportDesignExchange","reportLayouts","numberSequences","workspaceStatus","memberPaymentTerms","reportTexts","usageReport","letterStandard","subscriptionInvoices","usageInvoices","invoiceSettlement","invoiceJourney","reportDesigner","invoicingWizard","settlementFold","carnets","guestPasses","reminderEmail","invoiceEmail"],"needs":[]}]},{"process":"payments","levels":[{"level":"off","features":[],"needs":[]},{"level":"online","features":["onlinePayments"],"needs":[{"process":"money","level":"statements"}]}]},{"process":"tax","levels":[{"level":"none","features":[],"needs":[]},{"level":"vat","features":["vatManagement","vatDeclarations","vatGroups","vatRateHistory","vatCounterparty","vatReport","supplyClassification","viesVerification","recapitulativeStatement","inputVat","salesTax"],"needs":[{"process":"money","level":"invoices"}]},{"level":"books","features":["einvoiceCustomerDelivery","accountingBook","accountingPeriods","accountingConnectors","bankImport","mtdSubmission"],"needs":[{"process":"money","level":"invoices"}]}]},{"process":"purchases","levels":[{"level":"none","features":[],"needs":[]},{"level":"expenses","features":["supplyExpenses","expenseRepartitionWizard","scheduledExpenses","expenseRepartition"],"needs":[{"process":"money","level":"invoices"}]},{"level":"full","features":["purchases","premisesLease","assetRegister","purchaseAnalytics","foreignCurrencyPurchases","purchaseOrders"],"needs":[{"process":"money","level":"invoices"}]}]},{"process":"presentation","levels":[{"level":"basic","features":["uniqueMonograms"],"needs":[]},{"level":"branded","features":["workspaceVocabulary","workspaceBranding"],"needs":[]},{"level":"public","features":["publicListings","spaceInquiries"],"needs":[]}]},{"process":"operations","levels":[{"level":"basic","features":["pdfExport","dataExport","documents","formHelpHints","uiAnimations","regionalFormats","memberDataExport","navigationStyle","demoMode","memberAccountMenu","memberGettingStarted","setupGuide","dataReport"],"needs":[]},{"level":"insight","features":["decisionSurface","biReportDesigner","workspaceOverview"],"needs":[]},{"level":"advanced","features":["environmentPairs","deployments","configurationTransfer","instanceWizard","memberEnvironments","workspaceLibrary","configurableSettings"],"needs":[]}]},{"process":"assistant","levels":[{"level":"off","features":[],"needs":[]},{"level":"on","features":["recordingPrivacy","mcpAccess","taskRecorder","webMcp"],"needs":[]}]}],"presets":[{"preset":"essentiel","levels":[{"process":"bookings","level":"simple"},{"process":"community","level":"basic"},{"process":"money","level":"statements"},{"process":"payments","level":"off"},{"process":"tax","level":"none"},{"process":"purchases","level":"none"},{"process":"presentation","level":"basic"},{"process":"operations","level":"basic"},{"process":"assistant","level":"off"}]},{"preset":"standard","levels":[{"process":"bookings","level":"resources"},{"process":"community","level":"organised"},{"process":"money","level":"invoices"},{"process":"payments","level":"off"},{"process":"tax","level":"none"},{"process":"purchases","level":"expenses"},{"process":"presentation","level":"branded"},{"process":"operations","level":"insight"},{"process":"assistant","level":"off"}]},{"preset":"complet","levels":[{"process":"bookings","level":"measured"},{"process":"community","level":"organised"},{"process":"money","level":"invoices"},{"process":"payments","level":"online"},{"process":"tax","level":"books"},{"process":"purchases","level":"full"},{"process":"presentation","level":"public"},{"process":"operations","level":"advanced"},{"process":"assistant","level":"off"}]}]}$json$::jsonb;
$fn$;
revoke execute on function public.setup_level_catalogue() from public, anon, authenticated;

-- ── 2. the business's sender may be set for invoices by e-mail too ──
-- Restated whole from 0724; the one change is the third flag admitted.
-- Callers: the app's sender settings (SupabasePurchaseOrderRepository's
-- save), save_purchase_order_mail_settings_v1 (0724, a delegate) and
-- pgTAP 393.
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
          or public.feature_effective(p_workspace_id, 'reminderEmail')
          or public.feature_effective(p_workspace_id, 'invoiceEmail')) then
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

-- ── 3. the fence of an invoice e-mail ──
--
--  * `begin_invoice_email_v1`, with the CALLER's token: a native session of
--    someone who issues invoices -- checked first, before a replay answers
--    anything -- then the `invoiceEmail` feature, an invoice of the space
--    that is not voided, the sender configured, and the contact e-mail of
--    the customer's profile. The same attempt id replays the attempt and
--    says whether it may still be sent: by the call that opened it, or by a
--    replay younger than the bound after which a person decides it.
--  * Once: an invoice has at most one FIRST e-mail that may have left
--    (pending, unconfirmed, accepted, delivered) -- a unique index. "Send
--    again" is its own kind ('resend'), offered once the first was
--    accepted or delivered; each is its own attempt with its own row. No
--    attempt opens while any attempt of that invoice has no outcome.
--  * `finish_invoice_email` (service role) records the provider's answer
--    and nothing else: no event and no push -- the customer was told of the
--    invoice when it was issued (#3672). The rows are the evidence.
--  * `invoice_email_state_v1` is what the invoice page shows: whether the
--    customer can be e-mailed (or why not) and the attempts, newest first.
--
-- The server writes no words: the app sends the invoice, its subject and
-- its text in the customer's document language, which the attempt records.

create table public.invoice_email_sends (
  id uuid primary key,
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  invoice_id uuid not null references public.invoices(id) on delete cascade,
  kind text not null check (kind in ('first', 'resend')),
  state text not null default 'pending'
    check (state in ('pending', 'accepted', 'refused', 'unconfirmed', 'delivered', 'not_delivered')),
  recipient text not null check (char_length(recipient) <= 254),
  language text not null check (language in ('en', 'fr', 'de', 'es', 'it')),
  provider_id text not null default '' check (char_length(provider_id) <= 200),
  reason text not null default '' check (char_length(reason) <= 300),
  actor_member_id uuid not null,
  finished_at timestamptz,
  resolved_by_member_id uuid,
  foreign key (workspace_id, actor_member_id) references public.members (workspace_id, id)
);
select public.ensure_system_columns('invoice_email_sends');

comment on table public.invoice_email_sends is
  '#3673 -- the e-mail sends of issued invoices: one row per attempt (first or sent again), its recipient, language, provider answer and who decided an unconfirmed one.';

-- Once: one first e-mail per invoice that may have left.
create unique index invoice_email_sends_first_once
  on public.invoice_email_sends (invoice_id)
  where kind = 'first' and state in ('pending', 'unconfirmed', 'accepted', 'delivered');
create index invoice_email_sends_invoice on public.invoice_email_sends (invoice_id);

alter table public.invoice_email_sends enable row level security;
revoke all on public.invoice_email_sends from public, anon, authenticated;
grant select on public.invoice_email_sends to authenticated;
create policy invoice_email_sends_select on public.invoice_email_sends for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['issueInvoices'])));
create policy mcp_delegated_deny on public.invoice_email_sends as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

create or replace function public.invoice_email_send_json(p_send uuid)
returns jsonb language sql stable security definer set search_path = public as $fn$
  select jsonb_build_object('id', s.id, 'invoice_id', s.invoice_id, 'kind', s.kind,
    'state', s.state, 'recipient', s.recipient, 'language', s.language,
    'provider_id', s.provider_id, 'reason', s.reason,
    'created_at', s.created_datetime, 'finished_at', s.finished_at)
    from public.invoice_email_sends s where s.id = p_send;
$fn$;
revoke execute on function public.invoice_email_send_json(uuid) from public, anon, authenticated;

-- The invoice page's read: reachable or why not, and every attempt.
create or replace function public.invoice_email_state_v1(p_workspace_id uuid, p_invoice_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_invoice public.invoices;
  v_recipient text;
  v_on boolean;
  v_sender boolean;
begin
  if auth.uid() is null or public.mcp_is_delegated()
     or not public.has_permission(p_workspace_id, 'issueInvoices') then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select * into v_invoice from public.invoices
   where id = p_invoice_id and workspace_id = p_workspace_id;
  if v_invoice.id is null then raise exception 'unknown invoice' using errcode = '22023'; end if;
  v_on := public.feature_effective(p_workspace_id, 'invoiceEmail');
  v_sender := exists (select 1 from public.purchase_order_mail_settings m
                       where m.workspace_id = p_workspace_id and m.has_api_key);
  v_recipient := public.invoice_customer_email(p_invoice_id);
  return jsonb_build_object(
    'available', v_on and v_sender and v_recipient is not null and v_invoice.voided_at is null,
    'recipient', coalesce(v_recipient, ''),
    'reason', case
      when not v_on then 'feature_off'
      when v_invoice.voided_at is not null then 'voided'
      when v_recipient is null then 'no_address'
      when not v_sender then 'sender_not_configured'
      else '' end,
    'sends', coalesce((select jsonb_agg(public.invoice_email_send_json(s.id)
                                        order by s.created_datetime desc, s.id)
                         from public.invoice_email_sends s
                        where s.invoice_id = p_invoice_id), '[]'::jsonb));
end;
$fn$;
revoke execute on function public.invoice_email_state_v1(uuid, uuid) from public, anon;
grant execute on function public.invoice_email_state_v1(uuid, uuid) to authenticated;

create or replace function public.begin_invoice_email_v1(
  p_workspace_id uuid, p_invoice_id uuid, p_kind text, p_language text, p_attempt_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_actor public.members;
  v_invoice public.invoices;
  v_send public.invoice_email_sends;
  v_recipient text;
  -- A technical bound, not a business value: far beyond any live attempt;
  -- resolve_invoice_email_v1 decides by hand after the same bound.
  c_stuck constant interval := interval '10 minutes';
begin
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  begin
    v_actor := public.issuing_member(p_workspace_id);
  exception when others then
    raise exception 'not allowed' using errcode = '42501';
  end;
  if p_attempt_id is null then raise exception 'an attempt id is required' using errcode = '22023'; end if;
  select * into v_send from public.invoice_email_sends where id = p_attempt_id;
  if v_send.id is not null then
    if v_send.workspace_id <> p_workspace_id or v_send.invoice_id <> p_invoice_id then
      raise exception 'this attempt id was already used for another invoice' using errcode = '22023';
    end if;
    return public.invoice_email_send_json(v_send.id) || jsonb_build_object(
      'opened', false,
      'sendable', v_send.state = 'pending' and v_send.created_datetime >= now() - c_stuck);
  end if;
  if not public.feature_effective(p_workspace_id, 'invoiceEmail') then
    raise exception 'invoices by e-mail are off in this space' using errcode = '42501';
  end if;
  if coalesce(p_kind, '') not in ('first', 'resend') then
    raise exception 'unknown kind of send' using errcode = '22023';
  end if;
  if coalesce(p_language, '') not in ('en', 'fr', 'de', 'es', 'it') then
    raise exception 'the invoice names no language' using errcode = '22023';
  end if;
  select * into v_invoice from public.invoices
   where id = p_invoice_id and workspace_id = p_workspace_id for update;
  if v_invoice.id is null then raise exception 'unknown invoice' using errcode = '22023'; end if;
  if v_invoice.voided_at is not null then
    raise exception 'a voided invoice is not e-mailed' using errcode = '22023';
  end if;
  v_recipient := public.invoice_customer_email(p_invoice_id);
  if v_recipient is null then
    raise exception 'the customer has no e-mail address on file' using errcode = '22023';
  end if;
  if not exists (select 1 from public.purchase_order_mail_settings m
                  where m.workspace_id = p_workspace_id and m.has_api_key) then
    raise exception 'this business has not configured how it sends e-mail' using errcode = '22023';
  end if;
  if exists (select 1 from public.invoice_email_sends s
              where s.invoice_id = p_invoice_id and s.state in ('pending', 'unconfirmed')) then
    raise exception 'an earlier e-mail of this invoice has no confirmed outcome: check before sending again'
      using errcode = '55000';
  end if;
  if p_kind = 'first' and exists (select 1 from public.invoice_email_sends s
              where s.invoice_id = p_invoice_id and s.kind = 'first'
                and s.state in ('accepted', 'delivered')) then
    raise exception 'this invoice was already e-mailed: send it again deliberately' using errcode = '55000';
  end if;
  if p_kind = 'resend' and not exists (select 1 from public.invoice_email_sends s
              where s.invoice_id = p_invoice_id and s.kind = 'first'
                and s.state in ('accepted', 'delivered')) then
    raise exception 'this invoice was not e-mailed yet' using errcode = '22023';
  end if;
  insert into public.invoice_email_sends
    (id, workspace_id, invoice_id, kind, recipient, language, actor_member_id)
  values (p_attempt_id, p_workspace_id, p_invoice_id, p_kind, v_recipient, p_language, v_actor.id)
  returning * into v_send;
  return public.invoice_email_send_json(v_send.id)
    || jsonb_build_object('opened', true, 'sendable', true);
end;
$fn$;
revoke execute on function public.begin_invoice_email_v1(uuid, uuid, text, text, uuid) from public, anon;
grant execute on function public.begin_invoice_email_v1(uuid, uuid, text, text, uuid) to authenticated;

-- The provider's answer, recorded by the send function (service role).
create or replace function public.finish_invoice_email(
  p_attempt_id uuid, p_outcome text, p_provider_id text, p_reason text
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_send public.invoice_email_sends;
begin
  if p_outcome not in ('accepted', 'refused', 'unconfirmed') then
    raise exception 'unknown outcome %', p_outcome using errcode = '22023';
  end if;
  select * into v_send from public.invoice_email_sends where id = p_attempt_id for update;
  if v_send.id is null then raise exception 'unknown send attempt' using errcode = '22023'; end if;
  -- An outcome is recorded once; a repeat of the same answer is a replay.
  if v_send.state <> 'pending' then
    if v_send.state = p_outcome then return public.invoice_email_send_json(v_send.id); end if;
    raise exception 'this attempt already has its outcome' using errcode = '55000';
  end if;
  update public.invoice_email_sends
     set state = p_outcome, provider_id = left(coalesce(p_provider_id, ''), 200),
         reason = left(coalesce(p_reason, ''), 300), finished_at = now()
   where id = v_send.id;
  return public.invoice_email_send_json(v_send.id);
end;
$fn$;
revoke execute on function public.finish_invoice_email(uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.finish_invoice_email(uuid, text, text, text) to service_role;

-- A person decides an e-mail nobody could confirm.
create or replace function public.resolve_invoice_email_v1(
  p_workspace_id uuid, p_attempt_id uuid, p_delivered boolean
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  -- A technical bound, not a business value: far beyond any live attempt.
  c_stuck constant interval := interval '10 minutes';
  v_actor public.members;
  v_send public.invoice_email_sends;
begin
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  begin
    v_actor := public.issuing_member(p_workspace_id);
  exception when others then
    raise exception 'not allowed' using errcode = '42501';
  end;
  select * into v_send from public.invoice_email_sends
   where id = p_attempt_id and workspace_id = p_workspace_id for update;
  if v_send.id is null then raise exception 'unknown send attempt' using errcode = '22023'; end if;
  if not (v_send.state = 'unconfirmed'
          or (v_send.state = 'pending' and v_send.created_datetime < now() - c_stuck)) then
    raise exception 'only an unconfirmed e-mail is decided by hand' using errcode = '22023';
  end if;
  update public.invoice_email_sends
     set state = case when p_delivered then 'delivered' else 'not_delivered' end,
         resolved_by_member_id = v_actor.id,
         finished_at = coalesce(finished_at, now())
   where id = v_send.id;
  return public.invoice_email_send_json(v_send.id);
end;
$fn$;
revoke execute on function public.resolve_invoice_email_v1(uuid, uuid, boolean) from public, anon;
grant execute on function public.resolve_invoice_email_v1(uuid, uuid, boolean) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(730);
