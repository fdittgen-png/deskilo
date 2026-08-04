// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'notification_service.dart';

part 'notification_providers.g.dart';

/// Overridden in main() with the initialized [LocalNotificationService]
/// and in tests with a fake — there is no safe synchronous default.
@Riverpod(keepAlive: true)
NotificationService notificationService(Ref ref) =>
    throw UnimplementedError('override notificationServiceProvider');

/// System-level notification permission truth (#436): false = Android
/// suppresses every notification of this app; Settings names the fix.
@Riverpod(keepAlive: true)
Future<bool?> systemNotificationsEnabled(Ref ref) =>
    ref.watch(notificationServiceProvider).notificationsEnabled();
