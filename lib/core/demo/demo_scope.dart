// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo/core/backend/connected_installation_providers.dart';
import 'package:deskilo/core/backend/operation_context.dart';
import 'package:deskilo/core/demo/data/account_activity_repository.dart';
import 'package:deskilo/core/demo/data/book_profile_repository.dart';
import 'package:deskilo/core/demo/data/company_lookup_repository.dart';
import 'package:deskilo/core/demo/data/connected_installations.dart';
import 'package:deskilo/core/demo/data/me_repository.dart';
import 'package:deskilo/core/demo/data/messenger_repository.dart';
import 'package:deskilo/core/demo/data/offline_identity_connector.dart';
import 'package:deskilo/core/demo/data/public_directory_repository.dart';
import 'package:deskilo/core/demo/data/sales_tax_repository.dart';
import 'package:deskilo/core/demo/data/settings_repository.dart';
import 'package:deskilo/core/demo/data/tax_reference_repository.dart';
import 'package:deskilo/core/demo/data/vies_repository.dart';
//
// #1373 — what makes a `ProviderScope` the Demo environment.
//
// ADR 0028: Demo is the repository seam, with no backend behind it. This
// is that seam as a list — every provider that would otherwise resolve
// to a Supabase-backed implementation, overridden with the in-memory one
// the fixture seeded.
//
// The guarantee is structural, not a promise: inside a scope built from
// these overrides there is no Supabase client to reach, so an invitation,
// a payment, an e-invoice or a push cannot leave. There is no `if (demo)`
// branch to forget, because there is no code path at all.
//
// Everything a member could change in Demo lives in the fixture, so
// leaving the scope disposes it and a reset is a new fixture rather than
// a cleanup of the old one (#1375).
//
// #1564 finished the list. "The repositories" was not the whole of what
// a Demo scope has to own: the per-device preferences, the backend
// endpoint, the schema probe and the push pair are none of them
// repositories, and every one of them resolved to its real
// implementation inside the scope. A separate root container replaces
// providers, not SharedPreferences and not `Supabase.instance`, so the
// only thing that made them isolated was that nobody had noticed.
import 'package:deskilo/core/demo/data/workspace_application_repository.dart';
import 'package:deskilo/core/demo/demo_finances.dart';
import 'package:deskilo/core/instance/settings_bundle_asset.dart';
import 'package:deskilo/core/session/session_source.dart';
import 'package:deskilo/features/directory/providers/directory_providers.dart';
import 'package:deskilo/features/directory/providers/messenger_providers.dart';
import 'package:deskilo/features/directory/providers/saved_places_providers.dart';
import 'package:deskilo/features/me/providers/me_providers.dart';
import 'package:deskilo/features/money/providers/account_activity_providers.dart';
import 'package:deskilo/features/money/providers/asset_providers.dart';
import 'package:deskilo/features/money/providers/asset_valuation_providers.dart';
import 'package:deskilo/features/money/providers/book_period_providers.dart';
import 'package:deskilo/features/money/providers/book_profile_providers.dart';
import 'package:deskilo/features/money/providers/company_lookup_providers.dart';
import 'package:deskilo/features/money/providers/einvoice_inbox_providers.dart';
import 'package:deskilo/features/money/providers/premises_lease_providers.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
import 'package:deskilo/features/money/providers/room_rental_providers.dart';
import 'package:deskilo/features/money/providers/sales_tax_providers.dart';
import 'package:deskilo/features/money/providers/supplier_providers.dart';
import 'package:deskilo/features/money/providers/tax_reference_providers.dart';
import 'package:deskilo/features/money/providers/usage_read_providers.dart';
import 'package:deskilo/features/money/providers/vies_providers.dart';
import 'package:deskilo/features/visits/providers/visits_providers.dart';
import 'package:deskilo/features/workspace/providers/settings_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_application_providers.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../../app/realtime_invalidations.dart';
import '../../app/shell/shell_bar_visibility.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/auth/providers/oauth_consent_providers.dart';
import '../../features/mcp/providers/assistant_setup_providers.dart';
import '../../features/mcp/providers/mcp_providers.dart';
import '../../features/plan/providers/default_level_controller.dart';
import '../../features/profile/providers/personal_preferences_providers.dart';
import '../../features/profile/providers/profile_providers.dart';
import '../../features/reservations/domain/booking_intent.dart';
import '../../features/reservations/providers/default_period_controller.dart';
import '../../features/reservations/providers/place_feedback_providers.dart';
import '../../features/reservations/providers/reservation_providers.dart';
import '../../features/workspace/application/creation_intent.dart';
import '../../features/workspace/application/template_compare.dart';
import '../../features/workspace/domain/cost_allocation_rules.dart';
import '../../features/workspace/domain/kpi_overview.dart';
import '../../features/workspace/domain/kpi_purchases.dart';
import '../../features/workspace/domain/sample_data.dart';
import '../../features/workspace/providers/bi_providers.dart';
import '../../features/workspace/providers/cost_allocation_providers.dart';
import '../../features/workspace/providers/deployment_providers.dart';
import '../../features/workspace/providers/instance_providers.dart';
import '../../features/workspace/providers/kpi_providers.dart';
import '../../features/workspace/providers/local_setup_providers.dart';
import '../../features/workspace/providers/overview_kpi_providers.dart';
import '../../features/workspace/providers/sample_data_providers.dart';
import '../../features/workspace/providers/template_search_providers.dart';
import '../../features/workspace/providers/workspace_files_providers.dart';
import '../../features/workspace/providers/workspace_import_providers.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import '../backend/backend_settings.dart';
import '../backend/schema_version.dart';
import '../badge/app_badge.dart';
import '../cache/cache_store.dart';
import '../files/file_saver.dart';
import '../links/link_launcher.dart';
import '../locale/locale_controller.dart';
import '../navigation/event_sources.dart';
import '../navigation/navigation_style.dart';
import '../notifications/notification_providers.dart';
import '../push/push_opt_out.dart';
import '../push/push_providers.dart';
import '../realtime/realtime_providers.dart';
import '../scan/front_camera.dart';
import '../share/file_sharer.dart';
import '../share/text_sharer.dart';
import '../storage/active_workspace_store.dart';
import '../storage/booking_intent_store.dart';
import '../storage/entry_intent_store.dart';
import '../storage/help_hint_store.dart';
import '../storage/note_seen_store.dart';
import '../storage/notification_filter_store.dart';
import '../storage/space_prefs_store.dart';
import '../theme/theme_controller.dart';
import '../time/clock.dart';
import '../webmcp/webmcp_device_switch.dart';
import 'data/action_confirmation_repository.dart';
import 'data/demo_setup_repository.dart';
import 'data/identity_binding_repository.dart';
import 'data/instance_repository.dart';
import 'data/kpi_repositories.dart';
import 'data/mcp_admin_repository.dart';
import 'data/mcp_connection_repository.dart';
import 'data/mcp_onboarding_repository.dart';
import 'data/oauth_consent_repository.dart';
import 'data/personal_preferences_repository.dart';
import 'data/place_feedback_repository.dart';
import 'data/premises_lease_repository.dart';
import 'data/template_search_repository.dart';
import 'data/usage_preparation.dart';
import 'data/workbook_origin_repository.dart';
import 'data/workspace_asset_repository.dart';
import 'demo_fixture.dart';
import 'demo_space_routing.dart';
import 'seed/demo_asset_seed.dart';
import 'seed/demo_book_period_seed.dart';
import 'seed/demo_lease_seed.dart';
import 'seed/demo_purchase_seed.dart';
import 'seed/demo_reachable_seed.dart';
import 'seed/demo_room_seed.dart';
import 'seed/demo_second_space_seed.dart';
import 'seed/demo_setup_seed.dart';
import 'seed/demo_valuation_seed.dart';

/// The main space's purchase side, seeded once for the session: its
/// providers and the setup guide's evidence read the same repositories.
typedef _MainBooks = ({
  DemoPurchasing purchasing,
  FakeBookProfileRepository books,
  FakePremisesLeaseRepository lease,
  FakeWorkspaceAssetRepository assets,
});

_MainBooks _seedMainBooks(DemoFixture fixture) {
  final purchasing = seedDemoPurchasing(fixture.seededAt, money: fixture.money);
  return (
    purchasing: purchasing,
    // #1869 in memory; #2365 posts the demo money and its supplier bills.
    books: FakeBookProfileRepository(
      money: fixture.money,
      purchases: purchasing.purchases,
    )..profiles.add(demoBookProfile(fixture.seededAt)),
    // #2569 — the lease the demo space holds as tenant.
    lease: seedDemoLease(fixture.seededAt),
    // #2576 — the equipment the demo space bought.
    assets: seedDemoAssets(fixture.seededAt),
  );
}

/// The setup guide over each space's own fixture: Pézenas holds what
/// every step names, Leipzig what a space a few weeks old holds.
DemoSetupRepository _setupGuide(DemoFixture fixture, _MainBooks main) {
  final second = fixture.secondSpace;
  return DemoSetupRepository(
    rows: fixture.workspaces,
    spaces: {
      'ws-1': DemoSetupSources(
        space: fixture.workspaces,
        plan: fixture.floorPlan,
        reservations: fixture.reservations,
        money: fixture.money,
        events: fixture.events,
        books: DemoSetupBooks(
          suppliers: main.purchasing.suppliers,
          leases: main.lease,
          assets: main.assets,
          books: main.books,
          directory: fixture.directory,
        ),
        decided: demoMainSpaceDecidedEvidence,
      ),
      demoSecondSpaceId: DemoSetupSources(
        space: second.workspaces,
        plan: second.floorPlan,
        reservations: second.reservations,
        money: second.money,
        events: second.events,
      ),
    },
    acknowledged: {'ws-1': demoMainSpaceMarkedDone},
  );
}

/// The purchase side -- suppliers, received supplier invoices, bills and
/// receipts -- seeded for the session's day.
List<Override> _purchasingOverrides(DemoFixture fixture, _MainBooks main) {
  final purchasing = main.purchasing;
  return [
    eInvoiceInboxRepositoryProvider.overrideWithValue(purchasing.inbox),
    supplierRepositoryProvider.overrideWithValue(purchasing.suppliers),
    // #2863 — the registry a supplier is looked up in answers from fixtures.
    companyLookupRepositoryProvider.overrideWithValue(FakeCompanyLookupRepository()),
    purchaseRepositoryProvider.overrideWithValue(purchasing.purchases),
    bookProfileRepositoryProvider.overrideWithValue(main.books),
    premisesLeaseRepositoryProvider.overrideWithValue(main.lease),
    workspaceAssetRepositoryProvider.overrideWithValue(main.assets),
    // #2365 — last year's books, closed and exported.
    bookPeriodRepositoryProvider.overrideWithValue(
      seedDemoBookPeriods(fixture.seededAt),
    ),
    // #2568 — the rooms the demo space rents.
    roomRentalRepositoryProvider.overrideWithValue(
      seedDemoRooms(fixture.seededAt),
    ),
    // #2576 — the accountant's valuations of the demo space's equipment.
    assetValuationRepositoryProvider.overrideWithValue(
      seedDemoValuations(fixture.seededAt),
    ),
    leaseCommitmentRepositoryProvider.overrideWithValue(
      seedDemoCommitments(fixture.seededAt),
    ),
    // #2582 — the purchase figures over these documents.
    purchaseKpiRepositoryProvider.overrideWithValue(
      DemoPurchaseKpiRepository(
        purchases: purchasing.purchases,
        now: fixture.seededAt,
      ),
    ),
  ];
}

/// What only a server can answer: Demo offers nothing in its place.
List<Override> _serverOnlyOverrides() => [
  // #2582 — the purchase figures are _purchasingOverrides'; the cost
  // figures need the server's ledger of every source.
  costKpiRepositoryProvider.overrideWithValue(
    const UnavailableCostKpiRepository(),
  ),
  costAllocationRepositoryProvider.overrideWithValue(
    const UnavailableCostAllocationRepository(),
  ),
  // #2583 — the overview's own figures need the server.
  overviewKpiRepositoryProvider.overrideWithValue(
    const UnavailableOverviewKpiRepository(),
  ),
  // #2872 — sample data is made by a server in a test space; Demo is its
  // own sample, so the card offers nothing here.
  sampleDataRepositoryProvider.overrideWithValue(
    const UnavailableSampleDataRepository(),
  ),
];

/// The overrides that turn a scope into the Demo environment.
///
/// [fixture] is the session's data; a new one is a new session.
List<Override> demoOverrides(DemoFixture fixture) {
  // #1847 — the one in-memory directory behind its three interfaces.
  final directory = fixture.directory;
  final main = _seedMainBooks(fixture);
  return [
      // The clock first: everything the fixture seeded is relative to it,
      // so a demo opened next year still shows a booking for today.
      clockProvider.overrideWithValue(FixedClock(fixture.seededAt)),

      // The repositories. Each of these would otherwise be constructed
      // from `Supabase.instance.client`; inside this scope none of them
      // is, which is what makes an external effect impossible rather
      // than refused.
      authRepositoryProvider.overrideWithValue(fixture.auth), sessionSourceFromAuth, captureReaderNameFromProfile, enabledFeatureKeysFromWorkspace, ...realtimeWiringFromApp, // #2495
      workbookOriginRepositoryProvider.overrideWithValue(FakeWorkbookOriginRepository()),
      oauthConsentRepositoryProvider.overrideWithValue(FakeOAuthConsentRepository()),
      // #1647 — Demo binds no identity: the visitor is not a Deskilo user.
      identityBindingRepositoryProvider
          .overrideWithValue(FakeIdentityBindingRepository()),
      // #1619 — Demo has no assistant, so nothing to confirm.
      actionConfirmationRepositoryProvider
          .overrideWithValue(FakeActionConfirmationRepository()),
      // #1615 — nor an assistant to connect.
      mcpConnectionRepositoryProvider.overrideWithValue(
        FakeMcpConnectionRepository(installationId: _kDemoInstallationId),
      ),
      // #1626/#1627 — no policy to save, no queue, no second factor (no Auth).
      mcpAdminRepositoryProvider.overrideWithValue(FakeMcpAdminRepository()),
      // #2145 — no client to approve, no endpoint, no notices.
      mcpOnboardingRepositoryProvider
          .overrideWithValue(FakeMcpOnboardingRepository()),
      // #1829 — Demo names no instance owner: the visitor is not an account.
      instanceRepositoryProvider.overrideWithValue(FakeInstanceRepository()),
      // #1625 — Demo's one fictional installation: nothing is verified
      // against a server, and every client borrows the fakes above.
      activeMcpTargetProvider.overrideWith(
        (ref) => fixedMcpTarget(ref, _kDemoInstallationId),
      ),
      // #1656 — Demo lacks nothing locally; #2872 — its setup guide reads
      // each space's own fixture.
      localSetupRepositoryProvider.overrideWithValue(_setupGuide(fixture, main)),
      // #1659 — Demo searches only its own fixture templates.
      templateSearchRepositoryProvider
          .overrideWithValue(FakeTemplateSearchRepository(source: () => fixture.workspaces.templates)),
      secondFactorRepositoryProvider
          .overrideWithValue(FakeSecondFactorRepository()),
      // The list of spaces is the installation's; everything one space
      // holds answers per space (demo_space_routing.dart).
      workspaceListRepositoryProvider.overrideWithValue(fixture.workspaces),
      ...demoSpaceOverrides(fixture),
      placeFeedbackRepositoryProvider.overrideWithValue(FakePlaceFeedbackRepository()),
      usagePreparationProvider.overrideWithValue(const FakeUsagePreparation()), // #2590
      viesRepositoryProvider.overrideWithValue(FakeViesRepository()), // #2354
      salesTaxRepositoryProvider.overrideWithValue(FakeSalesTaxRepository()), // #2362
      ..._purchasingOverrides(fixture, main), // #2358, #2567, #2573
      taxReferenceRepositoryProvider.overrideWithValue(FakeTaxReferenceRepository()), settingsRepositoryProvider.overrideWith((ref) => FakeSettingsRepository.fromLoader(ref.watch(settingsBundleLoaderProvider))), // #2477 #2484 in memory
      profileRepositoryProvider.overrideWithValue(fixture.profiles), memberProfileRepositoryProvider.overrideWithValue(fixture.profiles), // #2564
      connectedInstallationsProvider.overrideWith((ref)=>FakeConnectedInstallations()), connectedSourcesProvider.overrideWith((ref) async=>[]),
      _demoPersonalContext, savedPlacesStoreProvider.overrideWithValue(fixture.prefs.savedPlaces), // #2555 — the persona at the fictional installation; saved pages in the session
      // #1834 — Demo never opens another server's sign-in.
      identityConnectorProvider.overrideWithValue(const OfflineIdentityConnector()),
      // #1847 — public discovery, publication management and participant
      // requests: three interfaces, one in-memory directory.
      publicDiscoveryRepositoryProvider.overrideWith((ref)=>directory),
      publicationRepositoryProvider.overrideWith((ref)=>directory),
      directoryParticipantRepositoryProvider.overrideWith((ref)=>directory),
      meRepositoryProvider.overrideWith((ref) => FakeMeRepository()), linkedMeRepositoryProvider.overrideWith((ref) => FakeLinkedMeRepository()), // #1823
      // #1835 — the visitor's own visits, in memory (#2327: seeded).
      guestParticipationRepositoryProvider
          .overrideWithValue(fixture.guests),
      _demoContacts(fixture), // #2472
      // #1824 — the messenger of every server, one in-memory one each.
      // #2327 — this server's is the fixture's, seeded; any other is empty.
      // #2405 — this server named by its origin is this server too, as
      // `ConnectedInstallations.use` reads it: a listed space's inquiry
      // lands in the fixture's messenger.
      messengerRepositoryProvider.overrideWith((ref, source) =>
          source.isEmpty || source == kDemoServerOrigin
              ? fixture.messenger
              : FakeMessengerRepository()),
      accountActivityRepositoryProvider.overrideWithValue(FakeAccountActivityRepository(derive: () => demoFinanceOverview(fixture))), selectedWorkspaceAccountActivityRepositoryProvider.overrideWithValue(FakeAccountActivityRepository(derive: () => demoFinanceOverview(fixture))), // #2327; no connected host in Demo
      workspaceApplicationRepositoryProvider.overrideWithValue(FakeWorkspaceApplicationRepository()),
      personalPreferencesRepositoryProvider.overrideWithValue(FakePersonalPreferencesRepository()),
      deploymentRepositoryProvider.overrideWithValue(fixture.deployments),
      workspaceFilesRepositoryProvider.overrideWithValue(fixture.files),
      workspaceImportRepositoryProvider.overrideWithValue(fixture.imports),
      // #2573 — the demo files no expense request as a purchase document,
      // and the app's opener reads the server: none here.
      eventSourceOpenersProvider.overrideWithValue(const {}),
      // #1918 — capacity over the demo's own plan and bookings.
      kpiRepositoryProvider.overrideWithValue(
        DemoCapacityKpiRepository(
          plan: fixture.floorPlan,
          reservations: fixture.reservations,
          now: fixture.seededAt,
        ),
      ),
      ..._serverOnlyOverrides(),
      // #1923 C — saved views live in memory for the demonstration.
      biViewRepositoryProvider.overrideWithValue(fixture.biViews),

      // #1377 — the ways an effect could leave the app, each pointed at
      // something inert. A payment, an invitation, an e-invoice and a
      // webhook all travel through a repository above; what is left is
      // the app's own outward edges, and Demo holds none of them.
      ...realtimeSyncOverrides(fixture.realtime),
      notificationServiceProvider.overrideWithValue(fixture.notifications),
      appBadgeProvider.overrideWithValue(fixture.badge),
      fileSaverProvider.overrideWithValue(fixture.outward.saveFile),
      typedFileSaverProvider.overrideWithValue(fixture.outward.saveFileTyped),
      fileSharerProvider.overrideWithValue(fixture.outward.shareFile),
      textSharerProvider.overrideWithValue(fixture.outward.shareText),
      linkLauncherProvider.overrideWithValue(fixture.outward.openLink),

      // #1564 — the two edges that are neither a repository nor the
      // app's own doing, and so stayed live: the push transport and the
      // registry it writes to. The exemption that covered them claimed
      // the bootstrap never runs; `pushBootstrap` gates on
      // `enabledFeatures`, which in Demo is the fixture's, with
      // `pushNotifications` on.
      pushConnectorProvider.overrideWithValue(fixture.outward.push),
      pushEndpointRepositoryProvider
          .overrideWithValue(fixture.outward.pushEndpoints),

      // #1564 — the schema probe the ROUTER watches. Left live, an old
      // configured backend could send an independent demonstration to
      // the server-update screen.
      schemaVersionSourceProvider.overrideWithValue(fixture.outward.schema),

      // #1564 — every per-device preference, owned by the session.
      //
      // A separate root container does not replace SharedPreferences:
      // each of these resolved to its `Prefs…Store` and wrote to the real
      // app's memory. `DefaultWorkspaceId` was the sharpest — it reads
      // "signed in" from the overridden auth repository, asks the fixture
      // for a server default, gets null and writes it through, and a null
      // write is `prefs.remove`. Entering Demo deleted the member's real
      // default profile.
      localeStoreProvider.overrideWithValue(fixture.prefs.locale),
      themeStoreProvider.overrideWithValue(fixture.prefs.theme),
      navigationStyleStoreProvider
          .overrideWithValue(fixture.prefs.navigationStyle),
      shellBarHiddenStoreProvider
          .overrideWithValue(fixture.prefs.shellBarHidden),
      shellSwipeCoachStoreProvider
          .overrideWithValue(fixture.prefs.shellSwipeCoach),
      pushOptOutStoreProvider.overrideWithValue(fixture.prefs.pushOptOut),
      webMcpSwitchStoreProvider.overrideWithValue(fixture.prefs.webMcpSwitch),
      frontCameraStoreProvider.overrideWithValue(fixture.prefs.frontCamera),
      activeWorkspaceStoreProvider
          .overrideWithValue(fixture.prefs.activeWorkspace),
      defaultWorkspaceStoreProvider
          .overrideWithValue(fixture.prefs.defaultWorkspace),
      defaultLevelStoreProvider.overrideWithValue(fixture.prefs.defaultLevel),
      defaultPeriodStoreProvider.overrideWithValue(fixture.prefs.defaultPeriod),
      notificationFilterStoreProvider
          .overrideWithValue(fixture.prefs.notificationFilters),
      helpHintStoreProvider.overrideWithValue(fixture.prefs.helpHints),
      spacePrefsStoreProvider.overrideWithValue(fixture.prefs.spacePrefs),
      noteSeenStoreProvider.overrideWithValue(fixture.prefs.noteSeen),
      backendSettingsStoreProvider.overrideWithValue(fixture.prefs.backend),
      // #1650 — the resumable errand is device state too.
      entryIntentStoreProvider.overrideWithValue(fixture.prefs.entryIntent),
      creationDraftStoreProvider.overrideWithValue(fixture.prefs.creationDraft),
      // #1855 — a visitor's interrupted booking stays inside the
      // demonstration, scoped to its own synthetic account and server.
      bookingIntentStoreProvider.overrideWithValue(fixture.prefs.bookingIntents),
      bookingIntentScopeProvider.overrideWithValue(
        const BookingIntentScope(account: 'demo-visitor', origin: 'demo://'),
      ),
      // The file cache is device state too: the real one writes the
      // demonstration's synthetic rows to the device filesystem.
      cacheStoreProvider.overrideWithValue(fixture.prefs.cache),
    ];
}

/// #1625 — Demo's fictional installation id (never a real server's).
const _kDemoInstallationId = '00000000-0000-4000-8000-00000000de30';

/// #2472 — this server's directory is both spaces' cast, read at each
/// call so a persona switch is followed; any other server's is empty.
Override _demoContacts(DemoFixture fixture) =>
    accountContactRepositoryProvider.overrideWith(
      (ref, source) => FakeAccountContactRepository()
        ..reachableOf = source.isEmpty || source == kDemoServerOrigin
            ? () => demoReachablePeople(fixture.actor.memberId)
            : null,
    );

/// The visitor's personal context: the demonstration's persona at its one
/// fictional installation. The real provider reads the installation row of
/// the device's server, which a demonstration never touches.
final Override _demoPersonalContext = personalContextProvider.overrideWith(
  (ref) async {
    final subject = await ref.watch(sessionStateProvider.future);
    if (subject == null) return null;
    return PersonalContext(
      identity: CanonicalIdentity(
        issuer: '$kDemoServerOrigin/auth/v1',
        subject: subject,
      ),
      homeInstallationId: _kDemoInstallationId,
      personalLocalUserId: subject,
      personalEpoch: 1,
    );
  },
);
