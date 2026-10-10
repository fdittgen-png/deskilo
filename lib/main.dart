// SPDX-License-Identifier: AGPL-3.0-or-later
import 'core/data/system_columns.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:async';

import 'app/app.dart';
import 'app/app_initializer.dart';
import 'app/bootstrap.dart';
import 'app/server_choice_app.dart';
import 'features/workspace/providers/workspace_providers.dart';
import 'core/files/file_saver.dart';
import 'core/notifications/deferred_notification_service.dart';
import 'core/notifications/local_notification_service.dart';
import 'core/notifications/notification_providers.dart';
import 'core/trace/trace_hooks.dart';
import 'core/trace/trace_provider_observer.dart';
import 'core/trace/trace_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Always-on error trace (#144): file-backed logger plus global hooks for
  // framework and platform errors. Installed first so even boot failures
  // below land in the trace.
  final trace = TraceLogger.instance = createAppTraceLogger();
  installGlobalTraceHooks(trace);
  // #992 — a row whose system columns break the server's invariants is
  // reported to the trace, never trusted silently.
  SystemColumns.onBreach = (detail) => trace.warn('data', detail);

  // #2343 — a build without a default server (F-Droid) asks which server
  // to use before anything is contacted. The choice is stored, and the
  // essential start-up below runs on it: no restart.
  if (await needsServerChoice().catchError((Object e, StackTrace st) {
    trace.error('boot', 'stored server unreadable', error: e, stackTrace: st);
    return false;
  })) {
    final chosen = Completer<void>();
    runApp(ProviderScope(
      overrides: [
        enabledFeaturesSyncProvider
            .overrideWithValue(ServerChoiceApp.features),
      ],
      child: ServerChoiceApp(onChosen: chosen.complete),
    ));
    await chosen.future;
  }

  // Defensive boot (#86, #2015): the essential start-up runs ONCE, with a
  // deadline. A failure or a hang shows a truthful recovery screen instead
  // of an app whose providers would touch an uninitialised Supabase client;
  // a late success hands over to the real app. Failures land in the trace.
  final boot = EssentialBoot(initializeApp().catchError((Object e, StackTrace st) {
    debugPrint('Supabase initialization failed: $e\n$st');
    trace.error('boot', 'Supabase initialization failed',
        error: e, stackTrace: st);
    throw e;
  }));
  // One-time repair (Downloads pass): exports saved by older builds sit
  // in the hidden app dir — move them into the visible Downloads. Fire
  // and forget; failures land in the trace, never block boot.
  unawaited(migrateLegacyExports().then((moved) {
    if (moved > 0) trace.warn('files', 'migrated $moved legacy exports');
  }).catchError((Object e, StackTrace st) {
    trace.error('files', 'legacy export migration failed',
        error: e, stackTrace: st);
  }));

  // #2015 — local notifications never hold the first frame: the app gets
  // the deferred service now, the platform one attaches when it is ready
  // (#86: a failed init leaves the honest no-op behaviour).
  final notifications = DeferredNotificationService();
  // #614: the web has no local-notification scheduling (zonedSchedule
  // and the pending mirror both throw) — the no-op behaviour IS the web
  // implementation, said once instead of erroring on every sweep.
  if (kIsWeb) {
    trace.log(TraceLevel.info, 'notifications',
        'web build — local notifications disabled');
  } else {
    unawaited(LocalNotificationService.initialize().then(
      notifications.attach,
      onError: (Object e, StackTrace st) {
        debugPrint('Notification initialization failed: $e\n$st');
        trace.error('boot', 'Notification initialization failed',
            error: e, stackTrace: st);
      },
    ));
  }
  void startApp() => runApp(
    ProviderScope(
      // #742 — every provider failure lands in the trace.
      observers: const [TraceProviderObserver()],
      overrides: [
        notificationServiceProvider.overrideWithValue(notifications),
      ],
      child: const DeskiloRoot(),
    ),
  );
  final state = await boot.settle(Future<void>.delayed(kEssentialBootDeadline));
  if (state == BootState.ready) return startApp();
  trace.warn('boot', 'essential start-up ${state.name}: recovery screen shown');
  var started = false;
  // A ProviderScope of its own (riverpod_lint): the recovery screen reads
  // no provider, and the real app gets its full scope in startApp().
  runApp(ProviderScope(
    child: BootRecoveryApp(
      boot: boot,
      onReady: () {
        if (started) return;
        started = true;
        trace.log(TraceLevel.info, 'boot', 'essential start-up completed late');
        startApp();
      },
    ),
  ));
}
