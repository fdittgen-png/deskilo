-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0246 (#1289) — a workspace's own colours.
--
-- `workspaces.branding` carries what a template may bring and an owner
-- may change afterwards: a brand seed colour the app derives its light,
-- dark and warm themes from, an office fill palette, and the key of a
-- curated seat palette. Never an emblem (the file lives in storage and
-- follows the copy jobs, a later slice), never the status or environment
-- colours (a fire-exit sign is not a branding opportunity — #1289).
--
--   * `branding_clean(map, strict)` is the one validator: the three keys,
--     `#RRGGBB` colours, one to eight office fills, a curated seat key.
--     Strict (the setter) refuses anything else; lenient (an import)
--     drops it. The contrast rule — a seed must keep every pair the app
--     reads at WCAG AA — is the client's `auditThemeContrast`, run at the
--     moment the colour is chosen; the database keeps the shape honest.
--   * `set_workspace_branding(workspace, delta)` merges keyed: a key set
--     to json null is removed, the others replaced, the rest untouched —
--     the #963 idiom, so two owners cannot revert each other.
--   * the `branding` entity (group `appearance`, `keyed_update`) travels
--     with a template and a deployment; `imported_branding` cleans what
--     arrives and, in merge mode, keeps what the target already chose.
--   * `feature_registry()` gains `workspaceBranding` (platform, off).
--
-- The flag ritual on the client is the same commit (#1289).

alter table public.workspaces
  add column if not exists branding jsonb not null default '{}'::jsonb;

comment on column public.workspaces.branding is
  'A workspace''s colours: seed_color #RRGGBB, office_palette [#RRGGBB…], seat_palette key. #1289';

create or replace function public.branding_clean(p_incoming jsonb, p_strict boolean default true)
returns jsonb
language plpgsql immutable set search_path = public as $fn$
declare
  v_out jsonb := '{}'::jsonb;
  v_key text;
  v_seed text;
  v_palette jsonb;
  v_seat text;
begin
  if p_incoming is null or jsonb_typeof(p_incoming) <> 'object' then
    if p_strict then raise exception 'branding is an object'; end if;
    return v_out;
  end if;
  for v_key in select jsonb_object_keys(p_incoming) loop
    if v_key not in ('seed_color', 'office_palette', 'seat_palette') then
      if p_strict then raise exception 'unknown branding key %', v_key; end if;
    end if;
  end loop;
  if jsonb_typeof(p_incoming->'seed_color') = 'string' then
    v_seed := p_incoming->>'seed_color';
    if v_seed !~ '^#[0-9A-Fa-f]{6}$' then
      if p_strict then raise exception 'seed_color must be #RRGGBB, not %', v_seed; end if;
    else
      v_out := v_out || jsonb_build_object('seed_color', upper(v_seed));
    end if;
  elsif p_incoming ? 'seed_color' and jsonb_typeof(p_incoming->'seed_color') <> 'null' and p_strict then
    raise exception 'seed_color must be #RRGGBB';
  end if;
  v_palette := p_incoming->'office_palette';
  if jsonb_typeof(v_palette) = 'array' then
    if jsonb_array_length(v_palette) between 1 and 8
       and not exists (select 1 from jsonb_array_elements(v_palette) c
                        where jsonb_typeof(c) <> 'string' or (c #>> '{}') !~ '^#[0-9A-Fa-f]{6}$') then
      v_out := v_out || jsonb_build_object('office_palette',
        (select jsonb_agg(upper(c #>> '{}')) from jsonb_array_elements(v_palette) c));
    elsif p_strict then
      raise exception 'office_palette is one to eight #RRGGBB colours';
    end if;
  elsif p_incoming ? 'office_palette' and jsonb_typeof(v_palette) <> 'null' and p_strict then
    raise exception 'office_palette is one to eight #RRGGBB colours';
  end if;
  if jsonb_typeof(p_incoming->'seat_palette') = 'string' then
    v_seat := p_incoming->>'seat_palette';
    if v_seat not in ('default') then
      if p_strict then raise exception 'seat_palette % is not a curated set', v_seat; end if;
    else
      v_out := v_out || jsonb_build_object('seat_palette', v_seat);
    end if;
  elsif p_incoming ? 'seat_palette' and jsonb_typeof(p_incoming->'seat_palette') <> 'null' and p_strict then
    raise exception 'seat_palette is a curated set''s key';
  end if;
  return v_out;
end $fn$;

revoke execute on function public.branding_clean(jsonb, boolean) from public, anon;
grant  execute on function public.branding_clean(jsonb, boolean) to authenticated;

-- The keyed write: json null removes a key, a value replaces it, the
-- rest of the map survives. Returns the map as stored.
create or replace function public.set_workspace_branding(p_workspace_id uuid, p_branding jsonb)
returns jsonb
language plpgsql security definer set search_path = public as $fn$
declare
  v_clean jsonb;
  v_removed text[];
  v_out jsonb;
begin
  if auth.uid() is null
     or not public.has_permission(p_workspace_id, 'workspaceSettings') then
    raise exception 'only workspace settings managers may change the colours';
  end if;
  v_clean := public.branding_clean(p_branding, true);
  select coalesce(array_agg(k), '{}'::text[]) into v_removed
    from jsonb_object_keys(p_branding) k
   where jsonb_typeof(p_branding->k) = 'null';
  update public.workspaces
     set branding = (coalesce(branding, '{}'::jsonb) - v_removed) || v_clean
   where id = p_workspace_id
  returning branding into v_out;
  if v_out is null then raise exception 'unknown workspace'; end if;
  return v_out;
end $fn$;

revoke execute on function public.set_workspace_branding(uuid, jsonb) from public, anon;
grant  execute on function public.set_workspace_branding(uuid, jsonb) to authenticated;

-- What an import or a template brings: cleaned leniently; merge keeps the
-- target's own choices for keys the source does not carry.
create or replace function public.imported_branding(p_current jsonb, p_incoming jsonb, p_mode text)
returns jsonb
language sql stable set search_path = public as $fn$
  select case when p_mode = 'merge'
              then coalesce(p_current, '{}'::jsonb) || public.branding_clean(p_incoming, false)
              else public.branding_clean(p_incoming, false) end;
$fn$;

revoke execute on function public.imported_branding(jsonb, jsonb, text) from public, anon;

-- ── the flag: workspaceBranding, platform, off ────────────────────────
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
    "calendarHub": {"parent": null, "default": true, "core": true},
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
    "workspaceBranding": {"parent": null, "default": false, "core": false}
  }'::jsonb
$registry$;

revoke execute on function public.feature_registry() from public, anon;
grant execute on function public.feature_registry() to authenticated;

-- ── the entity, and the paths that carry a workspace key ──────────────
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
  v_patched text;
  v_missing text[] := '{}';
begin
  v_def := pg_get_functiondef('public.deployable_entities()'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    $a$    jsonb_build_object('key', 'features'$a$,
    $a$    jsonb_build_object('key', 'branding', 'kind', 'configuration', 'requires', '[]'::jsonb,
      'merge_policy', 'keyed_update', 'group', 'appearance',
      'workspace_keys', '["branding"]'::jsonb, 'tables', '[]'::jsonb),
    jsonb_build_object('key', 'features'$a$);
  if v_patched is null then v_missing := v_missing || 'entities'::text; else execute v_patched; end if;

  v_def := pg_get_functiondef('public.export_workspace_configuration(uuid)'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    $a$'lexicon', coalesce(w.lexicon, '{}'::jsonb)),$a$,
    $a$'lexicon', coalesce(w.lexicon, '{}'::jsonb),
      'branding', coalesce(w.branding, '{}'::jsonb)),$a$);
  if v_patched is null then v_missing := v_missing || 'export'::text; else execute v_patched; end if;

  v_def := pg_get_functiondef('public.import_workspace_configuration(uuid, jsonb, text)'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    $a$lexicon = case when v_ws ? 'lexicon' then public.imported_lexicon(w.lexicon, v_ws->'lexicon', p_mode) else w.lexicon end$a$,
    $a$lexicon = case when v_ws ? 'lexicon' then public.imported_lexicon(w.lexicon, v_ws->'lexicon', p_mode) else w.lexicon end,
    branding = case when v_ws ? 'branding' then public.imported_branding(w.branding, v_ws->'branding', p_mode) else w.branding end$a$);
  if v_patched is null then v_missing := v_missing || 'import'::text; else execute v_patched; end if;

  v_def := pg_get_functiondef('public.configuration_change_set(uuid, jsonb, text[], text)'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    $a$if v_k = 'lexicon' then
        v_after := public.imported_lexicon(v_dst->'workspace'->'lexicon', v_after, p_mode);
      end if;$a$,
    $a$if v_k = 'lexicon' then
        v_after := public.imported_lexicon(v_dst->'workspace'->'lexicon', v_after, p_mode);
      end if;
      if v_k = 'branding' then
        v_after := public.imported_branding(v_dst->'workspace'->'branding', v_after, p_mode);
      end if;$a$);
  if v_patched is null then v_missing := v_missing || 'change set'::text; else execute v_patched; end if;

  v_def := pg_get_functiondef('public.template_publication_rules()'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    $a$'lexicon', jsonb_build_object('allowed', true),$a$,
    $a$'lexicon', jsonb_build_object('allowed', true),
    'branding', jsonb_build_object('allowed', true,
      'reason', 'colours only; an emblem never leaves its workspace (#1289)'),$a$);
  if v_patched is null then v_missing := v_missing || 'publication'::text; else execute v_patched; end if;

  if cardinality(v_missing) > 0 then
    raise exception '0246: anchors did not match: %', array_to_string(v_missing, ', ');
  end if;

  if not exists (select 1 from jsonb_array_elements(public.deployable_entities()) e
                  where e->>'key' = 'branding'
                    and e->>'merge_policy' = 'keyed_update'
                    and e->>'group' = 'appearance') then
    raise exception '0246: the branding entity did not register';
  end if;
  if not (public.template_publication_rules() ? 'branding') then
    raise exception '0246: the publication rules do not name branding';
  end if;
end
$migration$;

-- ── the association builtin names the new flag explicitly ──────────
-- (`template_contract_test`: a builtin's feature_flags name every feature;
-- supabase/templates/association_fr.json was regenerated by
-- `dart run tool/build_builtin_templates.dart` and this is that file.)
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
      "carnets": false,
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
      "workspaceBranding": false,
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

select public.set_deskilo_schema_version(246);
