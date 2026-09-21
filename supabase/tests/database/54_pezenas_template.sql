-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #1599 — the Pézenas variant, rehearsed on a synthetic workspace.
--
-- `coworking_appli_MB.PDF` is a field report, not a wish list: every
-- value below is either something it asked for in so many words or
-- something this variant inherited, and
-- `supabase/templates/variants/pezenas_coworking.md` says which. This
-- file is the half of that review that executes — the payload applied
-- to a workspace, and then the report's own numbers read back out of
-- it.
--
-- The variant is OWNER-PRIVATE and no migration inserts it: #1600
-- publishes it against a real workspace. So the template row is created
-- here, from the same JSON `supabase/templates/variants/pezenas_coworking.json`
-- carries, and `pezenas_template_test` holds the two equal.
--
-- Three things this file is careful about:
--
--   * BOTH percentages, all fifteen months. The association's report
--     prints one column; the doubling is an assertion about the app and
--     is written out month by month rather than sampled.
--   * The November correction. Both November rows of the report read
--     «40 journées». They are granted as 40 HALF-days, and the case
--     that says so names 80 as the number that must not appear.
--   * The floor plan is two named levels and NOTHING else. The PDF's
--     crops show one table and two places; that is not an inventory,
--     so none is invented. The tables below are fixtures, named
--     `REHEARSAL 1599 …` so that nobody mistakes them for Pézenas.
begin;
select plan(19);

create or replace function pg_temp.groups() returns text[] language sql as $$
  select array_agg(distinct e->>'group')
    from jsonb_array_elements(public.deployable_entities()) e;
$$;

create or replace function pg_temp.ws() returns uuid language sql as $$
  select current_setting('deskilo.pez.ws')::uuid;
$$;

create or replace function pg_temp.tpl() returns uuid language sql as $$
  select current_setting('deskilo.pez.tpl')::uuid;
$$;

create or replace function pg_temp.member(p_who text) returns uuid language sql as $$
  select current_setting('deskilo.pez.m_' || p_who)::uuid;
$$;

-- Half-days included in p_period for p_who, as the statement says.
create or replace function pg_temp.included(p_who text, p_period text)
returns int language sql as $$
  select ((public.member_statement(pg_temp.member(p_who), p_period))
            ->>'included_half_days')::int;
$$;

-- The fifteen months of the report, in order, for one subscription.
create or replace function pg_temp.fifteen(p_who text)
returns int[] language sql as $$
  select array_agg(pg_temp.included(p_who, to_char(m, 'YYYY-MM')) order by m)
    from generate_series(date '2026-10-01', date '2027-12-01', interval '1 month') m;
$$;

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_owner uuid := '00000000-0000-4000-8000-0000000000b1';
  u_full  uuid := '00000000-0000-4000-8000-0000000000b2';
  ws uuid; tpl uuid; m_half uuid; m_full uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u_owner,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','pez-owner@deskilo.test','',now(),now(),now()),
         (u_full ,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','pez-full@deskilo.test','',now(),now(),now());

  -- Deliberately `en`, so that the template's own default_locale has to
  -- arrive rather than already being there.
  insert into public.workspaces (name, country_code, currency_code, timezone,
                                 created_by, default_locale)
  values ('REHEARSAL 1599 Pézenas', 'FR', 'EUR', 'Europe/Paris', u_owner, 'en')
  returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, subscription_pct)
  values (ws, u_owner, true, true, 50) returning id into m_half;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, subscription_pct)
  values (ws, u_full, false, false, 100) returning id into m_full;

  -- A closure the workspace decided for itself, on a Saturday so that it
  -- changes no monthly number: it exists to be still there afterwards.
  insert into public.closure_days (workspace_id, day, reason)
  values (ws, date '2026-10-31', 'REHEARSAL 1599 pont');

  insert into public.workspace_templates
    (key, name, description, sort_order, visibility, owner_workspace_id,
     schema_version, template_version, tags, entities, configuration, floor_plan)
  values ('pezenas_coworking', 'Coworking Pézenas', 'rehearsal', 1,
          'private', ws, 1, 1, array['association','coworking','france','pezenas'],
          array['identity','tariffs','credit_products','floor_plan','booking_rules',
                'closure_days','lexicon','workspace_roles','features'],
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
      "legend_profile": "simple",
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
    "lexicon": {
      "fr": {
        "spaceKindSeat": "Place",
        "spaceKindLevel": "Étage",
        "shellReserveButton": "Réservations",
        "legendFree": "Place libre",
        "legendReserved": "Place réservée",
        "legendMine": "Ma place",
        "legendUnavailable": "Place non disponible"
      }
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
      "memberAccountMenu": true,
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
      "publicHolidays": true,
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
    "years": 2,
    "country": "FR"
  }
}$cfg$::jsonb,
          $tpl$[
  {
    "name": "Étage 1",
    "sort_order": 0,
    "bookable_as_whole": false,
    "price_cents": 0,
    "background_path": "",
    "site": null,
    "images": [],
    "offices": []
  },
  {
    "name": "Étage 2",
    "sort_order": 1,
    "bookable_as_whole": false,
    "price_cents": 0,
    "background_path": "",
    "site": null,
    "images": [],
    "offices": []
  }
]$tpl$::jsonb)
  returning id into tpl;

  perform set_config('deskilo.pez.ws', ws::text, false);
  perform set_config('deskilo.pez.tpl', tpl::text, false);
  perform set_config('deskilo.pez.m_half', m_half::text, false);
  perform set_config('deskilo.pez.m_full', m_full::text, false);
  perform set_config('request.jwt.claims',
    json_build_object('sub', u_owner::text, 'role', 'authenticated')::text, false);
end
$seed$;

select pg_temp.seed();
select public.apply_workspace_template(pg_temp.ws(), pg_temp.tpl(), pg_temp.groups());

-- ── what the report asked for, in so many words ──────────────────────

select is(
  (select format('%s %s-%s-%s %s %s',
                 booking_rules->>'granularity',
                 booking_rules->>'work_start_minutes',
                 booking_rules->>'half_boundary_minutes',
                 booking_rules->>'work_end_minutes',
                 booking_rules->>'legend_profile',
                 default_locale)
     from public.workspaces where id = pg_temp.ws()),
  'half_day 420-780-1140 simple fr',
  'the two periods of PDF p.1 — 07:00–13:00 and 13:00–19:00 — the simple '
  'legend of p.3 and French: four demands and one default_locale, none of '
  'which an import may quietly drop');

select is(
  (select format('%s %s %s', subscription_levels->>'enabled_presets',
                 subscription_levels->>'extra_levels',
                 subscription_levels->>'allow_custom')
     from public.workspaces where id = pg_temp.ws()),
  '[50, 100] [] false',
  'two subscription levels are offered and no third can be invented');

select is(
  array[((public.member_statement(pg_temp.member('half'),'2026-10'))->>'fee_cents')::int,
        ((public.member_statement(pg_temp.member('full'),'2026-10'))->>'fee_cents')::int],
  array[5000, 10000],
  'and they are charged 50 € and 100 € — the fee bands of p.1');

select is(
  (select string_agg(format('%s %s %s %s', c.name, c.half_days, c.price_cents,
                            coalesce(c.validity_months::text, 'never')),
                     ' / ' order by c.sort_order)
     from public.credit_products c where c.workspace_id = pg_temp.ws()),
  'Carnet 10 demi-journées 10 5000 never / Carnet 20 demi-journées 20 8000 never',
  'the two carnets arrive at the prices the report prints, and neither '
  'expires: the PDF names no expiry, so none is invented');

select is(
  (select lexicon->'fr' from public.workspaces where id = pg_temp.ws()),
  '{"legendFree":"Place libre","legendMine":"Ma place","legendReserved":"Place réservée",'
  '"legendUnavailable":"Place non disponible","shellReserveButton":"Réservations",'
  '"spaceKindLevel":"Étage","spaceKindSeat":"Place"}'::jsonb,
  'every word pp.2–4 show, and exactly those: a place is a «Place», a '
  'level an «Étage», the destination «Réservations», and the four legend '
  'entries the simple profile draws');

select is(
  (select format('%s %s %s %s %s %s %s %s',
                 feature_flags->>'carnets', feature_flags->>'workspaceVocabulary',
                 feature_flags->>'customRoles', feature_flags->>'publicHolidays',
                 feature_flags->>'memberAccountMenu', feature_flags->>'eventsTab',
                 feature_flags->>'membersDirectory', feature_flags->>'memberPage')
     from public.workspaces where id = pg_temp.ws()),
  'true true true true true false false false',
  'the navigation of p.4: one combined calendar destination, no events '
  'tab and no directory for ordinary members, the member account menu '
  '(#1598) kept — and the four features without which the carnets, the '
  'words, the bureau and the holidays would be carried but invisible');

-- ── the floor plan: two names, and no inventory ──────────────────────

select is(
  (select string_agg(l.name, ' | ' order by l.sort_order)
     from public.levels l where l.workspace_id = pg_temp.ws()),
  'Étage 1 | Étage 2',
  'the two levels p.2 names');

select is(
  (select format('%s %s %s',
                 (select count(*) from public.offices where workspace_id = pg_temp.ws()),
                 (select count(*) from public.desks where workspace_id = pg_temp.ws()),
                 (select count(*) from public.seats where workspace_id = pg_temp.ws()))),
  '0 0 0',
  'and NOTHING else. The PDF''s crops show one table and places 21 and '
  '22; that establishes no capacity, so the variant carries no room, no '
  'table and no place. The generic eight-seat example would have been a '
  'plausible lie about a space nobody has measured');

-- ── the fifteen months, at both percentages ──────────────────────────

select is(
  pg_temp.fifteen('half'),
  array[22,20,22,20,20,22,22,19,22,21,22,22,21,20,23],
  'a 50 % member is included for exactly the half-days the report prints, '
  'month by month: ceil(open days × 2 × 50 / 100) with the mainland '
  'French holidays, May 2027 down to 19 for its four');

select is(
  pg_temp.fifteen('full'),
  array[44,40,44,40,40,44,44,38,44,42,44,44,42,40,46],
  'and a 100 % member their doubles — all fifteen, not a sample: the '
  'existing fixture proved 50 % and four months of 100 %');

select is(
  array[pg_temp.included('full','2026-11'), pg_temp.included('full','2027-11')],
  array[40, 40],
  'BOTH November rows of the report literally read «40 journées». They '
  'are granted as 40 DEMI-journées. 80 is the number this case exists to '
  'refuse, and the correction is written down in the review rather than '
  'made silently');

-- ── whole tables on Étage 2 ──────────────────────────────────────────
--
-- The fixture the PDF could not supply. Named so that no reader takes
-- it for the real layout: one table on each level, one place on the
-- Étage 2 one.

create or replace function pg_temp.fixture_plan() returns void language plpgsql as $fix$
declare o1 uuid; o2 uuid; d1 uuid; d2 uuid;
begin
  insert into public.offices (workspace_id, level_id, name, color, bookable_as_whole, x, y, w, h)
  select pg_temp.ws(), l.id, 'REHEARSAL 1599 salle ' || l.name, 0, false, 0, 0, 40, 24
    from public.levels l where l.workspace_id = pg_temp.ws() and l.name = 'Étage 1'
  returning id into o1;
  insert into public.offices (workspace_id, level_id, name, color, bookable_as_whole, x, y, w, h)
  select pg_temp.ws(), l.id, 'REHEARSAL 1599 salle ' || l.name, 0, false, 0, 0, 40, 24
    from public.levels l where l.workspace_id = pg_temp.ws() and l.name = 'Étage 2'
  returning id into o2;
  -- Étage 1 keeps whole-table booking; Étage 2 is the one p.3 refuses.
  insert into public.desks (workspace_id, office_id, name, x, y, w, h, bookable_as_whole)
  values (pg_temp.ws(), o1, 'REHEARSAL 1599 Table A', 2, 2, 14, 8, true) returning id into d1;
  insert into public.desks (workspace_id, office_id, name, x, y, w, h, bookable_as_whole)
  values (pg_temp.ws(), o2, 'REHEARSAL 1599 Table 1', 2, 2, 14, 8, false) returning id into d2;
  insert into public.seats (workspace_id, desk_id, name, x, y, orientation, chair)
  values (pg_temp.ws(), d2, 'REHEARSAL 1599 Place 21', 4, 4, 'n', 'standard');
  perform set_config('deskilo.pez.d1', d1::text, false);
  perform set_config('deskilo.pez.d2', d2::text, false);
end
$fix$;

create or replace function pg_temp.book(p_desk text, p_day date, p_seat boolean default false)
returns text language sql as $$
  select format($q$ select public.create_reservation(%L, %s, null,
      (date %L + time '07:00') at time zone 'Europe/Paris',
      (date %L + time '13:00') at time zone 'Europe/Paris', false, null, %s) $q$,
    pg_temp.ws(),
    case when p_seat then quote_literal((select s.id from public.seats s
                                          where s.workspace_id = pg_temp.ws() limit 1)) || '::uuid'
         else 'null' end,
    p_day, p_day,
    case when p_seat then 'null'
         else quote_literal(current_setting('deskilo.pez.' || p_desk)) || '::uuid' end);
$$;

select pg_temp.fixture_plan();

select throws_ok(
  pg_temp.book('d2', date '2026-10-05'),
  'level booking is not enabled',
  'AS APPLIED, no whole space of any kind can be booked: `levelBooking` '
  'is the inherited core default and is off, so p.3''s demand is already '
  'met for every table in the space. That is not a proof that the demand '
  'landed — it is the reason the next two cases exist');

select lives_ok(
  pg_temp.book('d2', date '2026-10-06', true),
  'and an individual place on that very table still books: what p.3 '
  'refuses is the table, never the place on it');

-- The fixture deviation, and the only one: whole-space booking switched
-- on by hand, so that the desk flag is the thing being read rather than
-- a feature gate in front of it.
update public.workspaces
   set feature_flags = feature_flags || '{"levelBooking": true}'::jsonb
 where id = pg_temp.ws();

select throws_ok(
  pg_temp.book('d2', date '2026-10-07'),
  'desk not bookable as a whole',
  'with whole-space booking ON, the Étage 2 table is refused for the '
  'DESK''s own reason. A level flag would have answered «level not '
  'bookable as a whole» — a different guard, which is why p.3''s wording '
  'needs the per-table flag and not a switch on the étage');

select lives_ok(
  pg_temp.book('d1', date '2026-10-08'),
  'and the Étage 1 table is accepted: the report restricts one level, so '
  'the other keeps what it had');

-- ── applying twice, and what never travels ───────────────────────────

select public.apply_workspace_template(pg_temp.ws(), pg_temp.tpl(), pg_temp.groups());

select is(
  (select format('%s %s %s %s',
                 (select count(*) from public.fee_bands where workspace_id = pg_temp.ws()),
                 (select count(*) from public.credit_products where workspace_id = pg_temp.ws()),
                 (select count(*) from public.workspace_roles where workspace_id = pg_temp.ws()),
                 (select count(*) from public.levels where workspace_id = pg_temp.ws()))),
  '2 2 3 2',
  'a second apply merges: still two bands, two carnets, three roles and '
  'two levels — nothing sold twice and nothing deleted');

select is(
  (select format('%s %s %s',
                 (select count(*) from public.closure_days
                   where workspace_id = pg_temp.ws() and reason = 'REHEARSAL 1599 pont'),
                 (select count(*) from public.desks where workspace_id = pg_temp.ws()),
                 (select w.name from public.workspaces w where w.id = pg_temp.ws()))),
  '1 2 REHEARSAL 1599 Pézenas',
  'and what the workspace had of its own survives it: its Saturday '
  'closure, the fixture tables, its own name');

select is(
  (select format('%s %s',
                 (select count(*) from public.workspace_role_members rm
                    join public.workspace_roles x on x.id = rm.role_id
                   where x.workspace_id = pg_temp.ws()),
                 (select count(*) from public.member_credits
                   where workspace_id = pg_temp.ws()))),
  '0 0',
  'definitions travel and holdings do not: the bureau is defined and '
  'nobody holds it, and no carnet arrives already bought');

select is(
  (select string_agg(x.key, ',' order by x.sort_order)
     from public.workspace_roles x where x.workspace_id = pg_temp.ws()),
  'tresorier,secretaire,referent_salle',
  'the three roles inherited from the generic association template — '
  'inherited, not asked for: the report names no officer, and the '
  'review says so');

select * from finish();
rollback;
