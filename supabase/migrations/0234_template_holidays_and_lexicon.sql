-- SPDX-License-Identifier: 0BSD
-- risk: transforming
--
-- 0234 (#1282 S3) — a template can bring the country's public holidays and
-- its own words; and the workspace lexicon finally travels.
--
-- ## The lexicon never travelled
--
-- 0223 declared `lexicon` a deployable entity (group `wording`, key
-- `lexicon`), but neither `export_workspace_configuration` nor
-- `import_workspace_configuration` knew the column: a deployment, a
-- template and a configuration file all carried a workspace's own words as
-- nothing. Fixed here, with `imported_lexicon` as the one gate: only
-- allow-listed keys with non-empty text, the same list
-- `set_workspace_lexicon_term` enforces; a mirror replaces the lexicon, a
-- merge adds and updates term by term, locale by locale, never removing a
-- word the workspace chose.
--
-- ## Holidays that move
--
-- Easter Monday, Ascension and Whit Monday move every year, so a template
-- cannot carry closure days as dates. It carries a marker,
-- `configuration.holidays = {"years": 2, "country": "FR"?}`, and
-- `template_snapshot` resolves it for the TARGET workspace through
-- `public_holidays(country, year)` (0218) — for the current year and the
-- next — with the target's own country unless the marker names one.
-- Months the target has already invoiced are skipped, exactly as
-- `generate_closure_days` skips them: a template must never change
-- financial history.
--
-- `template_snapshot` therefore takes the target workspace; its two
-- callers pass it.

-- ── the lexicon gate ───────────────────────────────────────────────────
create or replace function public.imported_lexicon(
  p_current jsonb, p_incoming jsonb, p_mode text)
returns jsonb
language plpgsql
stable
set search_path = public
as $$
declare
  v_clean jsonb := '{}'::jsonb;
  v_locale record;
  v_term record;
  v_terms jsonb;
  v_out jsonb;
begin
  if p_incoming is null or jsonb_typeof(p_incoming) <> 'object' then
    return case when p_mode = 'merge' then coalesce(p_current, '{}'::jsonb) else '{}'::jsonb end;
  end if;
  for v_locale in select key, value from jsonb_each(p_incoming) loop
    if jsonb_typeof(v_locale.value) <> 'object' then continue; end if;
    v_terms := '{}'::jsonb;
    for v_term in select key, value from jsonb_each(v_locale.value) loop
      if jsonb_typeof(v_term.value) = 'string'
         and btrim(v_term.value #>> '{}') <> ''
         and exists (select 1 from public.lexicon_allowed_keys() k where k.key = v_term.key) then
        v_terms := v_terms || jsonb_build_object(v_term.key, v_term.value);
      end if;
    end loop;
    if v_terms <> '{}'::jsonb then
      v_clean := v_clean || jsonb_build_object(v_locale.key, v_terms);
    end if;
  end loop;
  if p_mode <> 'merge' then
    return v_clean;
  end if;
  v_out := coalesce(p_current, '{}'::jsonb);
  for v_locale in select key, value from jsonb_each(v_clean) loop
    v_out := v_out || jsonb_build_object(v_locale.key,
      coalesce(v_out->v_locale.key, '{}'::jsonb) || v_locale.value);
  end loop;
  return v_out;
end;
$$;

revoke execute on function public.imported_lexicon(jsonb, jsonb, text) from public, anon;

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

-- ── the snapshot resolves the holidays marker for its target ───────────
drop function if exists public.template_snapshot(public.workspace_templates);

create or replace function public.template_snapshot(
  p_template public.workspace_templates, p_workspace_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tables jsonb := coalesce(p_template.configuration->'tables', '{}'::jsonb)
                    || jsonb_build_object('floor_plan', public.strip_template_plan(p_template.floor_plan));
  v_marker jsonb := p_template.configuration->'holidays';
  v_country text;
  v_tz text;
  v_years int;
  v_year int;
  v_days jsonb;
begin
  if v_marker is not null and jsonb_typeof(v_marker) = 'object' and p_workspace_id is not null then
    select w.country_code, w.timezone into v_country, v_tz
      from public.workspaces w where w.id = p_workspace_id;
    v_country := coalesce(nullif(v_marker->>'country', ''), v_country);
    v_years := least(greatest(coalesce((v_marker->>'years')::int, 2), 1), 3);
    v_year := extract(year from now() at time zone coalesce(nullif(v_tz, ''), 'UTC'))::int;
    select coalesce(jsonb_agg(jsonb_build_object('day', h.day, 'reason', h.key) order by h.day), '[]'::jsonb)
      into v_days
      from generate_series(v_year, v_year + v_years - 1) y
     cross join lateral public.public_holidays(coalesce(v_country, ''), y) h
     where not exists (select 1 from public.invoices i
                        where i.workspace_id = p_workspace_id
                          and i.period = to_char(h.day, 'YYYY-MM'));
    v_tables := v_tables || jsonb_build_object('closure_days',
      coalesce(v_tables->'closure_days', '[]'::jsonb) || v_days);
  end if;
  return jsonb_build_object(
    'workspace', coalesce(p_template.configuration->'workspace', '{}'::jsonb),
    'tables', v_tables);
end;
$$;

revoke execute on function public.template_snapshot(public.workspace_templates, uuid) from public, anon;

do $migration$
declare
  v_def text;
  v_patched text;
  v_missing text[] := '{}';
begin
  -- export carries the lexicon
  v_def := pg_get_functiondef('public.export_workspace_configuration(uuid)'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    $a$'payment_instructions', coalesce(w.payment_instructions, '{}'::jsonb)),$a$,
    $a$'payment_instructions', coalesce(w.payment_instructions, '{}'::jsonb),
      'lexicon', coalesce(w.lexicon, '{}'::jsonb)),$a$);
  if v_patched is null then v_missing := v_missing || 'export'::text; else execute v_patched; end if;

  -- import writes it through the gate
  v_def := pg_get_functiondef('public.import_workspace_configuration(uuid, jsonb, text)'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    $a$payment_instructions = case when v_ws ? 'payment_instructions' then v_ws->'payment_instructions' else w.payment_instructions end$a$,
    $a$payment_instructions = case when v_ws ? 'payment_instructions' then v_ws->'payment_instructions' else w.payment_instructions end,
    lexicon = case when v_ws ? 'lexicon' then public.imported_lexicon(w.lexicon, v_ws->'lexicon', p_mode) else w.lexicon end$a$);
  if v_patched is null then v_missing := v_missing || 'import'::text; else execute v_patched; end if;

  -- a merged lexicon compares as what the merge will write
  v_def := pg_get_functiondef('public.configuration_change_set(uuid, jsonb, text[], text)'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    $a$if p_mode = 'merge' and v_k = 'feature_flags' then
        v_after := public.imported_feature_flags(v_after);
      end if;$a$,
    $a$if p_mode = 'merge' and v_k = 'feature_flags' then
        v_after := public.imported_feature_flags(v_after);
      end if;
      if v_k = 'lexicon' then
        v_after := public.imported_lexicon(v_dst->'workspace'->'lexicon', v_after, p_mode);
      end if;$a$);
  if v_patched is null then v_missing := v_missing || 'change set'::text; else execute v_patched; end if;

  -- both template callers pass their target
  v_def := pg_get_functiondef('public.preview_workspace_template(uuid, uuid, text[])'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def, 'public.template_snapshot(v_tpl)',
    'public.template_snapshot(v_tpl, p_workspace_id)');
  if v_patched is null then v_missing := v_missing || 'preview'::text; else execute v_patched; end if;

  v_def := pg_get_functiondef('public.apply_workspace_template(uuid, uuid, text[])'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def, 'public.template_snapshot(v_tpl)',
    'public.template_snapshot(v_tpl, p_workspace_id)');
  if v_patched is null then v_missing := v_missing || 'apply'::text; else execute v_patched; end if;

  if cardinality(v_missing) > 0 then
    raise exception '0234: anchors did not match: %', array_to_string(v_missing, ', ');
  end if;
end
$migration$;

-- ── the association builtin brings its holidays and its words ─────────
insert into public.workspace_templates
  (key, name, description, sort_order, visibility, schema_version, template_version,
   tags, entities, configuration, floor_plan)
values (
  'association_fr',
  'Association de coworking (France)',
  'Pour une association de coworking en France : demi-journées de 7 h à 13 h et de 13 h à 19 h du lundi au vendredi, jours fériés de l''année et de la suivante, cotisations à 50 % et 100 %, un calendrier où se prennent les validations, les mots de l''association, et deux étages prêts à réserver.',
  1,
  'builtin',
  1,
  1,
  array['association', 'coworking', 'france'],
  array['identity', 'tariffs', 'floor_plan', 'booking_rules', 'closure_days', 'lexicon', 'features'],
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
      "coOwner": false,
      "configurationTransfer": false,
      "dataAccessLog": false,
      "dataExport": true,
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
      "workspaceLibrary": false,
      "workspaceStatus": false,
      "workspaceVocabulary": false
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
    ]
  },
  "holidays": {
    "years": 2
  }
}$cfg$::jsonb,
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
]$tpl$::jsonb
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

select public.set_deskilo_schema_version(234);
