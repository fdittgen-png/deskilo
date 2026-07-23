// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:async';

import 'app/app.dart';
import 'app/app_initializer.dart';
import 'core/files/file_saver.dart';
import 'core/notifications/local_notification_service.dart';
import 'core/notifications/notification_providers.dart';
import 'core/notifications/notification_service.dart';
import 'core/trace/trace_hooks.dart';
import 'core/trace/trace_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Always-on error trace (#144): file-backed logger plus global hooks for
  // framework and platform errors. Installed first so even boot failures
  // below land in the trace.
  final trace = TraceLogger.instance = createAppTraceLogger();
  installGlobalTraceHooks(trace);

  // Defensive boot (#86): nothing that runs before the first frame is
  // allowed to kill the app. A failed Supabase init degrades to the auth
  // screen with error snackbars; failed notification init degrades to a
  // no-op service. Both failures are logged with their stack traces.
  try {
    await initializeApp();
  } catch (e, st) {
    debugPrint('Supabase initialization failed: $e\n$st');
    trace.error('boot', 'Supabase initialization failed',
        error: e, stackTrace: st);
  }

  // One-time repair (Downloads pass): exports saved by older builds sit
  // in the hidden app dir — move them into the visible Downloads. Fire
  // and forget; failures land in the trace, never block boot.
  unawaited(migrateLegacyExports().then((moved) {
    if (moved > 0) trace.warn('files', 'migrated $moved legacy exports');
  }).catchError((Object e, StackTrace st) {
    trace.error('files', 'legacy export migration failed',
        error: e, stackTrace: st);
  }));

  NotificationService notifications = const NoopNotificationService();
  try {
    notifications = await LocalNotificationService.initialize();
  } catch (e, st) {
    debugPrint('Notification initialization failed: $e\n$st');
    trace.error('boot', 'Notification initialization failed',
        error: e, stackTrace: st);
  }

  runApp(
    ProviderScope(
      overrides: [
        notificationServiceProvider.overrideWithValue(notifications),
      ],
      child: const DeskiloApp(),
    ),
  );
}
