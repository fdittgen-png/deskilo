// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4416 — the error reporter, composed where the session, the settings and the
// installation's client meet. It runs only while somebody is signed in, never
// in the Demo, and only while the Privacy switch is on (on by default); it is
// rebuilt when any of those changes, so switching off stops it at once.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_info.dart';
import '../core/backend/context_client_providers.dart';
import '../core/data/supabase_trace_report_sink.dart';
import '../core/demo/demo_entry.dart';
import '../core/instance/schema_compatibility.dart';
import '../core/settings/active_settings.dart';
import '../core/settings/setting_defaults.g.dart';
import '../core/time/clock.dart';
import '../core/trace/trace_logger.dart';
import '../core/trace/trace_report.dart';
import '../core/trace/trace_report_device.dart';
import '../core/trace/trace_reporter.dart';
import '../features/auth/providers/auth_providers.dart';

/// Where reports go: the installation the person is signed in to.
@visibleForTesting
final traceReportSinkProvider = Provider<TraceReportSink>(
  (ref) => SupabaseTraceReportSink(ref.watch(personalClientProvider)),
);

/// Watched by the composition root; builds to nothing while reports are off.
final traceReportingProvider = Provider<void>((ref) {
  final signedIn = ref.watch(authStateProvider).value != null;
  final demo = ref.watch(demoEntryProvider);
  // Until the switch is read nothing is sent: off is the safe side of unknown.
  final on = ref.watch(traceReportsSwitchProvider).value ?? false;
  if (!signedIn || demo || !on) return;
  final settings = ref.watch(platformSettingsProvider).value;
  int setting(String key, int registryDefault) =>
      settings != null && settings.definitions.containsKey(key)
      ? settings.read<int>(key)
      : registryDefault;
  final store = ref.read(traceReportDeviceStoreProvider);
  final trace = ref.read(traceLoggerProvider);
  final clock = ref.read(clockProvider);
  final reporter = TraceReporter(
    entries: trace.added,
    report: (entry) async => traceReportOf(
      entry,
      deviceId: await store.deviceId(),
      appVersion: await ref.read(appVersionProvider.future),
      schemaVersion: requiredSchemaVersion,
      platform: kIsWeb ? 'web' : defaultTargetPlatform.name,
      maxBytes: setting(
        'trace.report_max_bytes',
        SettingDefaults.traceReportMaxBytes,
      ),
    ),
    // Read when a report goes, never before: no client is made for nothing.
    sink: _LazySink(() => ref.read(traceReportSinkProvider)),
    perHour: () =>
        setting('trace.reports_per_hour', SettingDefaults.traceReportsPerHour),
    now: clock.now,
    warn: (message, [error, stack]) =>
        trace.warn(traceReportArea, message, error: error, stackTrace: stack),
  );
  ref.onDispose(reporter.dispose);
});

class _LazySink implements TraceReportSink {
  const _LazySink(this._sink);

  final TraceReportSink Function() _sink;

  @override
  Future<TraceReportAnswer> submit(TraceReport report) =>
      _sink().submit(report);
}
