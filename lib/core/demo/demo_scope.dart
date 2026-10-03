// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo/core/demo/data/book_profile_repository.dart';
import 'package:deskilo/features/money/providers/book_profile_providers.dart';
import 'package:deskilo/core/demo/data/public_directory_repository.dart';
import 'package:deskilo/core/demo/data/me_repository.dart';
import 'package:deskilo/features/me/providers/me_providers.dart';
import 'package:deskilo/core/demo/data/messenger_repository.dart';
import 'package:deskilo/features/directory/providers/messenger_providers.dart';
import 'package:deskilo/core/demo/data/connected_installations.dart';
import 'package:deskilo/core/backend/connected_installation_providers.dart';
import 'package:deskilo/core/demo/data/offline_identity_connector.dart';
import 'package:deskilo/features/directory/providers/directory_providers.dart';
import 'package:deskilo/core/demo/data/account_activity_repository.dart';
import 'package:deskilo/features/money/providers/account_activity_providers.dart';
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
import 'package:deskilo/features/workspace/providers/workspace_application_providers.dart';
import '../../features/workspace/application/creation_intent.dart';
import '../../features/workspace/providers/local_setup_providers.dart';
import '../../features/workspace/providers/template_search_providers.dart';
import 'data/identity_binding_repository.dart';
import 'data/oauth_consent_repository.dart';
import 'data/workbook_origin_repository.dart';
import 'data/personal_preferences_repository.dart';
import '../../features/profile/providers/personal_preferences_providers.dart';
import '../../features/workspace/application/template_compare.dart';
import '../../features/auth/providers/oauth_consent_providers.dart';
import 'data/action_confirmation_repository.dart';
import 'data/local_setup_repository.dart';
import 'data/template_search_repository.dart';
import 'data/instance_repository.dart';
import 'data/mcp_admin_repository.dart';
import 'data/mcp_connection_repository.dart';
import '../../features/mcp/providers/mcp_providers.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../../features/auth/providers/auth_providers.dart';
import '../../features/events/providers/event_providers.dart';
import '../../features/money/providers/credit_providers.dart';
import '../../features/money/providers/money_providers.dart';
import '../../features/plan/providers/accessory_providers.dart';
import '../../features/plan/providers/floor_plan_providers.dart';
import '../../features/profile/providers/profile_providers.dart';
import '../../features/reservations/providers/reservation_providers.dart';
import '../../features/calendar/providers/calendar_providers.dart';
import '../../features/workspace/providers/deployment_providers.dart';
import '../../features/workspace/providers/workspace_files_providers.dart';
import '../../features/workspace/providers/workspace_fields_providers.dart';
import '../../features/workspace/providers/workspace_import_providers.dart';
import '../../features/workspace/providers/workspace_roles_providers.dart';
import '../../features/workspace/providers/instance_providers.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import '../../app/shell/shell_bar_visibility.dart';
import '../../features/plan/providers/default_level_controller.dart';
import '../../features/reservations/providers/default_period_controller.dart';
import '../backend/backend_settings.dart';
import '../backend/schema_version.dart';
import '../badge/app_badge.dart';
import '../cache/cache_store.dart';
import '../files/file_saver.dart';
import '../locale/locale_controller.dart';
import '../navigation/navigation_style.dart';
import '../notifications/notification_providers.dart';
import '../push/push_providers.dart';
import '../realtime/realtime_providers.dart';
import '../scan/front_camera.dart';
import '../storage/active_workspace_store.dart';
import '../storage/help_hint_store.dart';
import '../storage/note_seen_store.dart';
import '../storage/entry_intent_store.dart';
import '../storage/booking_intent_store.dart';
import '../storage/notification_filter_store.dart';
import '../../features/reservations/domain/booking_intent.dart';
import '../links/link_launcher.dart';
import '../share/file_sharer.dart';
import '../share/text_sharer.dart';
import '../theme/theme_controller.dart';
import '../time/clock.dart';
import '../../features/workspace/domain/kpi_contract.dart';
import '../../features/workspace/providers/kpi_providers.dart';
import '../../features/workspace/domain/bi_saved_view.dart';
import '../../features/workspace/providers/bi_providers.dart';
import 'demo_fixture.dart';
import '../push/push_opt_out.dart';

/// The overrides that turn a scope into the Demo environment.
///
/// [fixture] is the session's data; a new one is a new session.
List<Override> demoOverrides(DemoFixture fixture) {
  // #1847 — the one in-memory directory behind its three interfaces.
  final directory = FakeDirectoryRepository();
  return [
      // The clock first: everything the fixture seeded is relative to it,
      // so a demo opened next year still shows a booking for today.
      clockProvider.overrideWithValue(FixedClock(fixture.seededAt)),

      // The repositories. Each of these would otherwise be constructed
      // from `Supabase.instance.client`; inside this scope none of them
      // is, which is what makes an external effect impossible rather
      // than refused.
      authRepositoryProvider.overrideWithValue(fixture.auth),
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
        FakeMcpConnectionRepository(installationId: kDemoInstallationId),
      ),
      // #1626/#1627 — no policy to save and no queue to review; and no
      // second factor, since Demo has no Auth server to verify one.
      mcpAdminRepositoryProvider.overrideWithValue(FakeMcpAdminRepository()),
      // #1829 — Demo names no instance owner: the visitor is not an account.
      instanceRepositoryProvider.overrideWithValue(FakeInstanceRepository()),
      // #1625 — Demo's one fictional installation: nothing is verified
      // against a server, and every client borrows the fakes above.
      activeMcpTargetProvider.overrideWith(
        (ref) => fixedMcpTarget(ref, kDemoInstallationId),
      ),
      // #1656 — Demo lacks nothing locally.
      localSetupRepositoryProvider.overrideWithValue(FakeLocalSetupRepository()),
      // #1659 — Demo searches only its own fixture templates.
      templateSearchRepositoryProvider
          .overrideWithValue(FakeTemplateSearchRepository(source: () => fixture.workspaces.templates)),
      secondFactorRepositoryProvider
          .overrideWithValue(FakeSecondFactorRepository()),
      workspaceRepositoryProvider.overrideWithValue(fixture.workspaces),
      floorPlanRepositoryProvider.overrideWithValue(fixture.floorPlan),
      reservationRepositoryProvider.overrideWithValue(fixture.reservations),
      eventRepositoryProvider.overrideWithValue(fixture.events),
      calendarRepositoryProvider.overrideWithValue(fixture.calendar),
      moneyRepositoryProvider.overrideWithValue(fixture.money),
      // #1869 — book profiles in memory.
      bookProfileRepositoryProvider.overrideWithValue(FakeBookProfileRepository()),
      creditRepositoryProvider.overrideWithValue(fixture.credits),
      accessoryRepositoryProvider.overrideWithValue(fixture.accessories),
      profileRepositoryProvider.overrideWithValue(fixture.profiles),
      connectedInstallationsProvider.overrideWith((ref)=>FakeConnectedInstallations()),
      connectedSourcesProvider.overrideWith((ref) async=>[]),
      // #1834 — Demo never opens another server's sign-in.
      identityConnectorProvider.overrideWithValue(const OfflineIdentityConnector()),
      // #1847 — public discovery, publication management and participant
      // requests: three interfaces, one in-memory directory.
      publicDiscoveryRepositoryProvider.overrideWith((ref)=>directory),
      publicationRepositoryProvider.overrideWith((ref)=>directory),
      directoryParticipantRepositoryProvider.overrideWith((ref)=>directory),
      meRepositoryProvider.overrideWith((ref) => FakeMeRepository()), // #1823
      accountContactRepositoryProvider.overrideWith((ref,source)=>FakeAccountContactRepository()),
      // #1824 — the messenger of every server, one in-memory one each.
      messengerRepositoryProvider.overrideWith((ref, source) => FakeMessengerRepository()),
      accountActivityRepositoryProvider.overrideWithValue(FakeAccountActivityRepository()),
      workspaceApplicationRepositoryProvider.overrideWithValue(FakeWorkspaceApplicationRepository()),
      personalPreferencesRepositoryProvider.overrideWithValue(FakePersonalPreferencesRepository()),
      deploymentRepositoryProvider.overrideWithValue(fixture.deployments),
      workspaceFilesRepositoryProvider.overrideWithValue(fixture.files),
      workspaceImportRepositoryProvider.overrideWithValue(fixture.imports),
      workspaceFieldsRepositoryProvider.overrideWithValue(fixture.fields),
      workspaceRolesRepositoryProvider.overrideWithValue(fixture.roles),
      // #1918 — no server to compute capacity on: the tile says so.
      kpiRepositoryProvider.overrideWithValue(const UnavailableKpiRepository()),
      // #1923 C — saved views live in memory for the demonstration.
      biViewRepositoryProvider.overrideWithValue(InMemoryBiViewRepository()),
      // #1924 — no server to sum invoices on: the cards say so.
      financeKpiRepositoryProvider.overrideWithValue(
        const UnavailableFinanceKpiRepository(),
      ),

      // #1377 — the ways an effect could leave the app, each pointed at
      // something inert. A payment, an invitation, an e-invoice and a
      // webhook all travel through a repository above; what is left is
      // the app's own outward edges, and Demo holds none of them.
      realtimeSyncProvider.overrideWithValue(fixture.realtime),
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
const kDemoInstallationId = '00000000-0000-4000-8000-00000000de30';

/// The providers a Demo scope must override, by name.
///
/// The list exists so a NEW repository cannot quietly stay live in Demo:
/// `demo_scope_test` compares it against what [demoOverrides] actually
/// overrides, and against the repository providers the app declares.
const Set<String> demoOverriddenProviders = {
  'bookProfileRepositoryProvider', // #1869
  'clockProvider',
  'authRepositoryProvider',
  'identityBindingRepositoryProvider',
  'oauthConsentRepositoryProvider',
  'workbookOriginRepositoryProvider',
  'actionConfirmationRepositoryProvider',
  'mcpConnectionRepositoryProvider',
  'mcpAdminRepositoryProvider',
  'instanceRepositoryProvider',
  'activeMcpTargetProvider',
  'localSetupRepositoryProvider',
  'templateSearchRepositoryProvider',
  'secondFactorRepositoryProvider',
  'workspaceRepositoryProvider',
  'floorPlanRepositoryProvider',
  'reservationRepositoryProvider',
  'eventRepositoryProvider',
  'calendarRepositoryProvider',
  'moneyRepositoryProvider',
  'creditRepositoryProvider',
  'accessoryRepositoryProvider',
  'profileRepositoryProvider',
  'personalPreferencesRepositoryProvider',
  'workspaceApplicationRepositoryProvider',
  'accountActivityRepositoryProvider',
  'connectedInstallationsProvider', 'connectedSourcesProvider',
  'identityConnectorProvider', // #1834
  'publicDiscoveryRepositoryProvider', 'publicationRepositoryProvider',
  'directoryParticipantRepositoryProvider', 'accountContactRepositoryProvider',
  'meRepositoryProvider', // #1823
  'messengerRepositoryProvider',
  'deploymentRepositoryProvider',
  'workspaceFilesRepositoryProvider',
  'workspaceImportRepositoryProvider',
  'workspaceFieldsRepositoryProvider',
  'workspaceRolesRepositoryProvider',
  'kpiRepositoryProvider',
  'biViewRepositoryProvider', // #1923 C
  'financeKpiRepositoryProvider', // #1924
  'realtimeSyncProvider',
  'notificationServiceProvider',
  'appBadgeProvider',
  'fileSaverProvider',
  'typedFileSaverProvider',
  'fileSharerProvider',
  'textSharerProvider',
  'linkLauncherProvider',
  // #1564 — the backend services that are not repositories, and every
  // per-device preference.
  'pushConnectorProvider',
  'pushEndpointRepositoryProvider',
  'schemaVersionSourceProvider',
  'localeStoreProvider',
  'themeStoreProvider',
  'navigationStyleStoreProvider',
  'shellBarHiddenStoreProvider',
  'shellSwipeCoachStoreProvider',
  'pushOptOutStoreProvider',
  'frontCameraStoreProvider',
  'activeWorkspaceStoreProvider',
  'defaultWorkspaceStoreProvider',
  'defaultLevelStoreProvider',
  'defaultPeriodStoreProvider',
  'entryIntentStoreProvider',
  'creationDraftStoreProvider',
  'bookingIntentStoreProvider',
  'notificationFilterStoreProvider',
  'helpHintStoreProvider',
  'noteSeenStoreProvider',
  'backendSettingsStoreProvider',
  'cacheStoreProvider',
};

/// The app's outward edges: the providers through which something could
/// leave the device or the backend. Demo overrides every one of them,
/// and `demo_scope_test` fails when the app grows another.
const Set<String> outwardEdgeProviders = {
  'realtimeSyncProvider',
  'notificationServiceProvider',
  'appBadgeProvider',
  'fileSaverProvider',
  'typedFileSaverProvider',
  'fileSharerProvider',
  'textSharerProvider',
  'linkLauncherProvider',
  'pushConnectorProvider',
  'pushEndpointRepositoryProvider',
  // #1564 — a schema probe is a request that leaves the device too.
  'schemaVersionSourceProvider',
};
