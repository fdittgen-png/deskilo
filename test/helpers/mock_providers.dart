// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:ui' show Locale;
import 'package:deskilo/core/locale/device_locale.dart';
import 'package:deskilo/features/workspace/domain/workspace_export_bundle.dart';
import 'package:deskilo/features/workspace/providers/workspace_files_providers.dart';
import 'package:deskilo/core/backend/schema_version.dart';
import 'package:deskilo/core/instance/schema_compatibility.dart';
import 'package:deskilo/app/shell/shell_bar_visibility.dart';
import 'package:deskilo/features/workspace/domain/deployment.dart';
import 'package:deskilo/features/workspace/providers/deployment_providers.dart';
import 'fake_deployment_repository.dart';
import 'package:deskilo/core/demo/data/auth_repository.dart';
import 'package:deskilo/core/demo/data/workspace_repository.dart';
export 'package:deskilo/core/demo/data/auth_repository.dart';
import 'package:deskilo/core/demo/data/stores.dart';
export 'package:deskilo/core/demo/data/stores.dart';
export 'package:deskilo/core/demo/data/workspace_repository.dart';
import 'package:deskilo/core/navigation/navigation_style.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show ValueChanged;
import 'package:flutter/widgets.dart' show Widget, ColoredBox, Color, Center, Text;

import 'package:deskilo/core/i18n/app_format.dart';
import 'package:deskilo/core/i18n/format_prefs.dart';
import 'package:deskilo/core/i18n/format_controller.dart';
import 'package:deskilo/features/auth/domain/auth_repository.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/badge/app_badge.dart';
import 'package:deskilo/core/realtime/realtime_providers.dart';
import 'package:deskilo/core/realtime/realtime_sync.dart';
import 'package:deskilo/core/cache/cache_store.dart';
import 'package:deskilo/core/nfc/nfc_uid_reader.dart';
import 'package:deskilo/features/workspace/domain/workspace_repository.dart';
import 'package:deskilo/core/notifications/notification_providers.dart';
import 'package:deskilo/core/notifications/notification_service.dart';
import 'package:deskilo/core/scan/front_camera.dart';
import 'package:deskilo/core/share/file_sharer.dart';
import 'package:deskilo/core/scan/qr_scan_widget.dart';
import 'package:deskilo/core/storage/active_workspace_store.dart';
import 'package:deskilo/core/storage/help_hint_store.dart';
import 'package:deskilo/core/storage/note_seen_store.dart';
import 'package:deskilo/core/storage/notification_filter_store.dart';
import 'package:deskilo/core/time/clock.dart';

import 'fake_realtime_sync.dart';
import 'test_clock.dart';
export 'test_clock.dart' show kTestNow, kTestPeriod;
import 'package:deskilo/features/calendar/domain/calendar_repository.dart';
import 'package:deskilo/features/calendar/providers/calendar_providers.dart';
import 'package:deskilo/features/events/domain/event_repository.dart';
import 'package:deskilo/features/events/providers/event_providers.dart';
import 'package:deskilo/features/money/domain/money_repository.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/plan/domain/accessory_repository.dart';
import 'package:deskilo/features/plan/domain/floor_plan_repository.dart';
import 'package:deskilo/features/plan/providers/accessory_providers.dart';
import 'package:deskilo/features/plan/providers/default_level_controller.dart';
import 'package:deskilo/features/reservations/providers/default_period_controller.dart';
import 'package:deskilo/features/plan/providers/floor_plan_providers.dart';
import 'package:deskilo/features/profile/domain/profile_repository.dart';
import 'package:deskilo/features/profile/providers/profile_providers.dart';
import 'package:deskilo/features/reservations/domain/reservation_repository.dart';
import 'package:deskilo/features/reservations/providers/reservation_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/core/demo/data/workspace_fields_repository.dart';
import 'package:deskilo/core/demo/data/workspace_roles_repository.dart';
import 'package:deskilo/features/workspace/domain/workspace_fields_repository.dart';
import 'package:deskilo/features/workspace/domain/workspace_roles_repository.dart';
import 'package:deskilo/features/workspace/providers/workspace_fields_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_roles_providers.dart';
import 'package:flutter_riverpod/misc.dart';

import 'fake_accessory_repository.dart';
import 'fake_calendar_repository.dart';
import 'fake_event_repository.dart';
import 'fake_floor_plan_repository.dart';
import 'fake_money_repository.dart';
import 'fake_notification_service.dart';
import 'fake_profile_repository.dart';
import 'fake_reservation_repository.dart';
import 'in_memory_default_level_store.dart';
import 'fake_pref_stores.dart';
import 'package:deskilo/features/money/domain/credit_product.dart';
import 'package:deskilo/features/money/providers/credit_providers.dart';
import 'fake_credit_repository.dart';



/// Baseline overrides for widget tests: a signed-in user who is the owner
/// of one workspace. Always start from these and add feature-specific
/// overrides on top.
/// In-memory [DevModeStore] — the settings toggle without the platform
/// channel. Default OFF, like a fresh install; tests exercising

List<Override> standardTestOverrides({
  // #1150 — most fixtures were written against workspace wall time (the
  // app's default); a few against the device's. Each test says which.
  TimeZoneMode timeZoneMode = TimeZoneMode.workspace,
  // A test of the format CONTROLLER itself needs the real provider, not
  // a pinned value.
  bool pinFormats = true,
  Clock? clock,
  bool devMode = false,
  BackendSettingsStore? backendSettings,
  AuthRepository? auth,
  WorkspaceRepository? workspace,
  FloorPlanRepository? floorPlan,
  AccessoryRepository? accessories,
  ReservationRepository? reservations,
  EventRepository? events,
  CalendarRepository? calendar,
  MoneyRepository? money,
  CreditRepository? credits,
  NotificationService? notifications,
  ActiveWorkspaceStore? activeWorkspace,
  FakeQrScanner? qrScan,
  DefaultWorkspaceStore? defaultWorkspace,
  DefaultLevelStore? defaultLevel,
  DefaultPeriodStore? defaultPeriod,
  ProfileRepository? profile,
  NfcUidReader? nfc,
  FrontCameraStore? frontCamera,
  FileSharer? fileSharer,
  RealtimeSync? realtime,
  FakeAppBadge? badge,
  NoteSeenStore? noteSeen,
  NotificationFilterStore? notificationFilters,
  HelpHintStore? helpHints,
  ShellFlagStore? shellBarHidden,
  ShellFlagStore? shellSwipeCoach,
  NavigationStyleStore? navigationStyle,
  DeploymentRepository? deployment,
  SchemaVersionSource? schemaVersion,
  WorkspaceFilesRepository? workspaceFiles,
  WorkspaceFieldsRepository? fields,
  WorkspaceRolesRepository? roles,
  Locale? deviceLocale,
}) {
  return [
    // #1150 — a 24-hour clock for every test: `ClockPref.auto` renders
    // "8:00 AM" under en_US, which is right for that member and wrong for
    // a fixture that pins "08:00". The app honours the preference; the
    // tests pin one.
    if (pinFormats)
      appFormatProvider.overrideWithValue(
        AppFormat(locale: 'en_US', currencyCode: 'EUR', clock: ClockPref.h24, timeZoneMode: timeZoneMode),
      ),
    // #1303 — a fixed device locale: onboarding seeds its country from it,
    // and a test must not depend on the machine running it.
    deviceLocaleProvider.overrideWithValue(deviceLocale ?? const Locale('de', 'DE')),
    // #1310 — the workspace's stored files, in memory.
    workspaceFilesRepositoryProvider
        .overrideWithValue(workspaceFiles ?? FakeWorkspaceFiles()),
    // #1288 — the workspace's own questions, in memory.
    workspaceFieldsRepositoryProvider
        .overrideWithValue(fields ?? FakeWorkspaceFields()),
    // #1528 — the roles a workspace defined itself, in memory.
    workspaceRolesRepositoryProvider
        .overrideWithValue(roles ?? FakeWorkspaceRoles()),
    // #1312 — the server answers with exactly this app's schema, so no
    // test is sent to the update screen unless it says otherwise.
    schemaVersionSourceProvider.overrideWithValue(
        schemaVersion ?? const FixedSchemaVersionSource(requiredSchemaVersion)),
    // #969/#970 — the per-device preferences, in memory by default.
    navigationStyleStoreProvider.overrideWithValue(
        navigationStyle ?? InMemoryNavigationStyleStore()),
    // No-op realtime by default: the real impl touches Supabase.instance,
    // which does not exist under flutter_test (#413).
    realtimeSyncProvider.overrideWithValue(realtime ?? FakeRealtimeSync()),
    appBadgeProvider.overrideWithValue(badge ?? FakeAppBadge()),
    // The clock is defaulted here rather than per-test so a screen that
    // starts reading it does not quietly re-arm the time bomb.
    clockProvider.overrideWithValue(clock ?? FixedClock(kTestNow)),

    authRepositoryProvider
        .overrideWithValue(auth ?? FakeAuthRepository.signedIn()),
    workspaceRepositoryProvider.overrideWithValue(() {
      final repo = workspace ?? FakeWorkspaceRepository.withWorkspace();
      if (devMode && repo is FakeWorkspaceRepository) repo.applyDevMode(true);
      return repo;
    }()),
    floorPlanRepositoryProvider
        .overrideWithValue(floorPlan ?? FakeFloorPlanRepository()),
    // #988 — the deployment engine, in memory.
    deploymentRepositoryProvider
        .overrideWithValue(deployment ?? FakeDeploymentRepository()),
    accessoryRepositoryProvider
        .overrideWithValue(accessories ?? FakeAccessoryRepository()),
    reservationRepositoryProvider
        .overrideWithValue(reservations ?? FakeReservationRepository()),
    eventRepositoryProvider
        .overrideWithValue(events ?? FakeEventRepository()),
    calendarRepositoryProvider
        .overrideWithValue(calendar ?? FakeCalendarRepository()),
    moneyRepositoryProvider
        .overrideWithValue(money ?? FakeMoneyRepository()),
    creditRepositoryProvider
        .overrideWithValue(credits ?? FakeCreditRepository()),
    notificationServiceProvider
        .overrideWithValue(notifications ?? FakeNotificationService()),
    activeWorkspaceStoreProvider
        .overrideWithValue(activeWorkspace ?? InMemoryActiveWorkspaceStore()),
    // Camera scanner seam (K3): widget tests can't run a camera — the
    // fake renders a placeholder and lets tests emit codes on demand.
    qrScanWidgetBuilderProvider
        .overrideWithValue((qrScan ?? FakeQrScanner()).build),
    defaultWorkspaceStoreProvider
        .overrideWithValue(defaultWorkspace ?? InMemoryDefaultWorkspaceStore()),
    defaultLevelStoreProvider
        .overrideWithValue(defaultLevel ?? InMemoryDefaultLevelStore()),
    // #586: the default booking period persists on-device.
    defaultPeriodStoreProvider
        .overrideWithValue(defaultPeriod ?? InMemoryDefaultPeriodStore()),
    // #464: an in-memory read state — the prefs impl would need a
    // SharedPreferences mock in every widget test.
    noteSeenStoreProvider
        .overrideWithValue(noteSeen ?? InMemoryNoteSeenStore()),
    // #581: the bell filter persists on-device — in-memory for tests.
    notificationFilterStoreProvider.overrideWithValue(
        notificationFilters ?? InMemoryNotificationFilterStore()),
    // #606: dismissed help hints persist on-device — in-memory for tests.
    helpHintStoreProvider
        .overrideWithValue(helpHints ?? InMemoryHelpHintStore()),
    // #1173: the swipe-away shell flags persist on-device. The coach
    // mark defaults to SEEN so its pill never floats over a test that
    // is about something else — the tests that are about it pass their
    // own store.
    shellBarHiddenStoreProvider
        .overrideWithValue(shellBarHidden ?? InMemoryShellFlagStore()),
    shellSwipeCoachStoreProvider
        .overrideWithValue(shellSwipeCoach ?? InMemoryShellFlagStore(true)),
    profileRepositoryProvider
        .overrideWithValue(profile ?? FakeProfileRepository()),
    nfcUidReaderProvider.overrideWithValue(nfc ?? FakeNfcUidReader()),
    frontCameraStoreProvider
        .overrideWithValue(frontCamera ?? InMemoryFrontCameraStore()),
    // #780 — which Supabase instance the device talks to: in-memory in
    // tests, so no SharedPreferences channel and no real endpoint.
    backendSettingsStoreProvider
        .overrideWithValue(backendSettings ?? InMemoryBackendSettingsStore()),
    // File cache would touch path_provider channels in tests — and boot
    // eviction runs on every app pump.
    cacheStoreProvider.overrideWithValue(InMemoryCacheStore()),
    // Share seam (0060): the real one opens a system share sheet.
    fileSharerProvider.overrideWithValue(
      fileSharer ??
          ({required bytes, required fileName, required mimeType, text}) async =>
              FileShareOutcome.sent,
    ),
  ];
}





/// Fake RFID/NFC reader: [available] toggles the tap path ([deviceStatus]
/// pins a precise state instead); [startFails] simulates a session that
/// will not start; [tap] drives a card presentation without hardware.
class FakeNfcUidReader extends NfcUidReader {
  FakeNfcUidReader({
    this.available = false,
    this.deviceStatus,
    this.startFails = false,
  });

  final bool available;
  final NfcStatus? deviceStatus;
  final bool startFails;
  ValueChanged<String>? _onUid;

  @override
  Future<NfcStatus> status() async =>
      deviceStatus ??
      (available ? NfcStatus.ready : NfcStatus.unsupported);

  @override
  Future<bool> startRead({required ValueChanged<String> onUid}) async {
    if (startFails) return false;
    _onUid = onUid;
    return true;
  }

  @override
  Future<void> stop() async => _onUid = null;

  /// Simulates a physical card tap with UID [uid] (already normalized).
  void tap(String uid) => _onUid?.call(uid);
}


/// Fake camera QR scanner (K3): [build] renders a keyed placeholder and
/// captures the sheet's onCode callback; [emit] simulates a decoded QR.
class FakeQrScanner {
  /// The lens the last build asked for (#773 surface defaults).
  bool? lastFront;

  ValueChanged<String>? _onCode;

  Widget build({required ValueChanged<String> onCode, bool front = true}) {
    lastFront = front;
    _onCode = onCode;
    return const ColoredBox(
      color: Color(0xFF222222),
      child: Center(child: Text('camera')),
    );
  }

  /// Simulates the camera decoding [code].
  void emit(String code) => _onCode?.call(code);
}


/// #1312 — a server whose `deskilo_schema_version()` answers [version];
/// null is a server that predates the marker.
class FixedSchemaVersionSource implements SchemaVersionSource {
  const FixedSchemaVersionSource(this.version, {this.unavailable = false});
  final int? version;
  final bool unavailable;
  @override
  Future<int?> read() async {
    if (unavailable) {
      throw const SchemaVersionUnavailable('offline in the test');
    }
    return version;
  }
}

