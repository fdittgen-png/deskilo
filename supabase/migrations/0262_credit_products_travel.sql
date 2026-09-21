-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0262 (#1271 T1/T2) — the carnets a space SELLS travel; the carnets a
-- member BOUGHT never do.
--
-- T1. `credit_products` is the catalogue #1279 gave a workspace: a name,
-- a number of half-days, a price, an optional expiry and a VAT rate. It
-- is configuration in exactly the sense `packages` and `services` are —
-- an offer the space makes — and it was the only priced catalogue the
-- configuration transfer did not carry. A template could describe a
-- space that sells prepaid half-days and then arrive with nothing to
-- sell.
--
-- So it becomes an entity on the same terms as the others: kind
-- `master_data`, group `pricing_credits`, `requires` the VAT rates whose
-- labels its rows name, and `keyed_update` by name — which
-- `entity_row_key` already answers, because its default branch IS
-- `p_row->>'name'`. Patching that function to say the same thing twice
-- would move its digest for nothing, so it is deliberately left alone.
--
-- **The definitions only.** `member_credits` (what somebody bought) and
-- `member_credit_uses` (what they spent it on) name a member, and
-- members do not travel — a carnet sold in the development twin means
-- nothing in production, where that person may not exist, and it is a
-- charge on somebody's account besides. Neither table is in the entity,
-- neither is in the export, and a mirror import DEACTIVATES a product
-- the payload does not name rather than deleting it: a deleted product
-- would take the sales that point at it with it.
--
-- T2. The association builtin then carries what it advertises. Its
-- description promised carnets for whoever does not subscribe; the
-- template carried a lexicon while `workspaceVocabulary` was off (the
-- consumer returns no lexicon while off) and three role definitions
-- while `customRoles` was off. The two carnets the association's own
-- report prices — 10 half-days for 50 €, 20 for 80 €, no expiry — now
-- arrive with the template, and the three flags that make the vocabulary,
-- the bureau and the carnets usable are on.
--
-- Nothing is assigned to anybody by any of this: a role that arrives
-- holds nobody (0251), and a carnet that arrives has been sold to
-- nobody.

create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text language plpgsql as $f$
begin
  if position(p_old in p_def) = 0 then return null; end if;
  return replace(p_def, p_old, p_new);
end
$f$;

revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $migration$
declare
  v_def text;
  v_patched text;
  v_missing text[] := '{}';
begin
  v_def := pg_get_functiondef('public.deployable_entities()'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    $a$    jsonb_build_object('key', 'features'$a$,
    $a$    jsonb_build_object('key', 'credit_products', 'kind', 'master_data',
      'requires', '["vat"]'::jsonb, 'merge_policy', 'keyed_update',
      'group', 'pricing_credits', 'workspace_keys', '[]'::jsonb,
      'tables', '["credit_products"]'::jsonb),
    jsonb_build_object('key', 'features'$a$);
  if v_patched is null then v_missing := v_missing || 'entities'::text;
  else execute v_patched; end if;

  v_def := pg_get_functiondef('public.template_publication_rules()'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    $a$    'features', jsonb_build_object('allowed', true)$a$,
    $a$    'credit_products', jsonb_build_object('allowed', true,
      'reason', 'the catalogue only; what a member bought and what they spent stay with that member (#1271)'),
    'features', jsonb_build_object('allowed', true)$a$);
  if v_patched is null then v_missing := v_missing || 'publication'::text;
  else execute v_patched; end if;

  v_def := pg_get_functiondef('public.export_workspace_configuration(uuid)'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    $a$      'workspace_roles', public.workspace_roles_export(p_workspace_id),$a$,
    $a$      'workspace_roles', public.workspace_roles_export(p_workspace_id),
      'credit_products', coalesce((select jsonb_agg(jsonb_build_object(
          'name', c.name, 'half_days', c.half_days, 'price_cents', c.price_cents,
          'validity_months', c.validity_months, 'active', c.active,
          'sort_order', c.sort_order,
          'vat_rate', (select r.label from public.vat_rates r where r.id = c.vat_rate_id))
          order by c.sort_order, c.name)
        from public.credit_products c where c.workspace_id = p_workspace_id), '[]'::jsonb),$a$);
  if v_patched is null then v_missing := v_missing || 'export'::text;
  else execute v_patched; end if;

  v_def := pg_get_functiondef('public.import_workspace_configuration(uuid, jsonb, text)'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    $a$  if v_t ? 'workspace_roles' then$a$,
    $a$  if v_t ? 'credit_products' then
    for v_row in select value from jsonb_array_elements(v_t->'credit_products') loop
      select id into v_id from public.credit_products
       where workspace_id = p_workspace_id and name = v_row->>'name'
       order by created_at limit 1;
      if v_id is null then
        insert into public.credit_products (workspace_id, name, half_days, price_cents,
                                            validity_months, active, sort_order, vat_rate_id)
        values (p_workspace_id, v_row->>'name', (v_row->>'half_days')::int,
                coalesce((v_row->>'price_cents')::int, 0),
                (v_row->>'validity_months')::int,
                coalesce((v_row->>'active')::boolean, true),
                coalesce((v_row->>'sort_order')::int, 0),
                public.vat_rate_id_by_label(p_workspace_id, v_row->>'vat_rate'));
      else
        update public.credit_products set half_days = (v_row->>'half_days')::int,
               price_cents = coalesce((v_row->>'price_cents')::int, 0),
               validity_months = (v_row->>'validity_months')::int,
               active = coalesce((v_row->>'active')::boolean, true),
               sort_order = coalesce((v_row->>'sort_order')::int, 0),
               vat_rate_id = public.vat_rate_id_by_label(p_workspace_id, v_row->>'vat_rate')
         where id = v_id;
      end if;
    end loop;
    -- Deactivate, never delete: a sale points at the product it was.
    update public.credit_products c set active = false
     where p_mode = 'mirror' and c.workspace_id = p_workspace_id
       and not exists (select 1 from jsonb_array_elements(v_t->'credit_products') e
                        where e.value->>'name' = c.name);
  end if;

  if v_t ? 'workspace_roles' then$a$);
  if v_patched is null then v_missing := v_missing || 'import'::text;
  else execute v_patched; end if;

  if cardinality(v_missing) > 0 then
    raise exception '0262: anchors did not match: %', array_to_string(v_missing, ', ');
  end if;
end
$migration$;

-- ── the association builtin carries what it advertises ───────────────
-- (`template_contract_test` requires the migration that inserts a
-- builtin to carry the whole payload, which is why the template is
-- restated rather than the three keys updated in place.
-- `supabase/templates/association_fr.json` was regenerated by
-- `dart run tool/build_builtin_templates.dart` and this is that file.)
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
  $cfg$
{
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
      "adminInvoicing": false,
      "adminLevelAssign": false,
      "adminSeatBlocking": false,
      "autoCheckInOut": false,
      "badgeSignIn": false,
      "bookForOthers": true,
      "bookingGate": true,
      "bookingPolicies": true,
      "calendarHub": true,
      "calendarTab": true,
      "calendarValidations": true,
      "calendarViews": true,
      "carnets": true,
      "coOwner": false,
      "configurationTransfer": false,
      "customFields": false,
      "customRoles": true,
      "dataAccessLog": false,
      "dataExport": true,
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
      "financeFaces": true,
      "formHelpHints": true,
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
      "memberAccountMenu": false,
      "memberDataExport": true,
      "memberEnvironments": false,
      "memberNotifications": true,
      "memberOrigin": false,
      "memberPage": false,
      "memberPaymentTerms": false,
      "memberReports": false,
      "membersDirectory": false,
      "messageGestures": true,
      "messagesHub": true,
      "moneyTab": true,
      "multiSite": false,
      "navigationStyle": true,
      "nfcBadges": false,
      "nfcSeatTags": false,
      "notificationGrouping": false,
      "numberSequences": false,
      "onlinePayments": false,
      "paymentReminders": false,
      "pdfExport": true,
      "personalInfo": true,
      "planMemberPhotos": false,
      "planObjectDelete": true,
      "priceNegotiations": false,
      "publicHolidays": false,
      "pushNotifications": true,
      "qrBadges": false,
      "recordingPrivacy": false,
      "regionalFormats": true,
      "reportDesignExchange": false,
      "reportDesigner": false,
      "reportLayouts": false,
      "reportTexts": false,
      "richMessageRefs": true,
      "roleManagement": true,
      "scheduledExpenses": false,
      "seatDayTimeline": true,
      "seriesBooking": true,
      "services": true,
      "settlementFold": false,
      "singleRoomLevelNames": true,
      "siteDocuments": false,
      "spaceQrCodes": true,
      "subscriptionInvoices": false,
      "supplyExpenses": false,
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
      "whatsappIntegration": false,
      "workingHours": true,
      "workspaceBranding": false,
      "workspaceLibrary": false,
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
  $tpl$
[
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

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(262);
