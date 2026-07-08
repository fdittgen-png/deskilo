// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/app_initializer.dart';
import 'core/notifications/local_notification_service.dart';
import 'core/notifications/notification_providers.dart';
import 'core/notifications/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Defensive boot (#86): nothing that runs before the first frame is
  // allowed to kill the app. A failed Supabase init degrades to the auth
  // screen with error snackbars; failed notification init degrades to a
  // no-op service. Both failures are logged with their stack traces.
  try {
    await initializeApp();
  } catch (e, st) {
    debugPrint('Supabase initialization failed: $e\n$st');
  }

  NotificationService notifications = const NoopNotificationService();
  try {
    notifications = await LocalNotificationService.initialize();
  } catch (e, st) {
    debugPrint('Notification initialization failed: $e\n$st');
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
