// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/context_l10n.dart';
import '../notifications/notification_providers.dart';
import 'push_connector.dart';
import 'push_providers.dart';
import 'push_service.dart';

/// Push pipeline status line for Settings (#424/#428): FCM registered,
/// or not-configured with the owner-facing fix — the field had ZERO
/// registered endpoints and no way to see why.
class PushStatusTile extends ConsumerWidget {
  const PushStatusTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // #436: the system-level truth outranks everything — when Android
    // suppresses this app's notifications, say so and name the fix
    // (this is what made the icon badge look 'broken' in the field).
    final systemEnabled = ref.watch(systemNotificationsEnabledProvider).value;
    if (systemEnabled == false) {
      return ListTile(
        leading: const Icon(Icons.notifications_off_outlined),
        title: Text(l10n.notificationsSystemOff),
        subtitle: Text(l10n.notificationsSystemOffHint),
        trailing: const _AllowButton(),
      );
    }
    final service = ref.watch(pushBootstrapProvider).value;
    if (service == null) return const SizedBox.shrink();
    return ValueListenableBuilder<PushStatus>(
      valueListenable: service.status,
      builder: (context, status, _) => switch (status) {
        PushStatus.registered => ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: Text(l10n.pushStatusRegistered),
          ),
        // #2559 C2 — never asked, or denied: the deliberate action.
        PushStatus.permissionNeeded => ListTile(
            leading: const Icon(Icons.notifications_off_outlined),
            title: Text(l10n.pushStatusPermissionNeeded),
            subtitle: Text(l10n.pushStatusPermissionNeededHint),
            trailing: const _AllowButton(),
          ),
        // #716 — an F-Droid build has NO transport to configure; telling
        // its owner to finish the Firebase setup would send them on an
        // errand that cannot succeed.
        PushStatus.notConfigured when !kPushTransportAvailable => ListTile(
            leading: const Icon(Icons.notifications_off_outlined),
            title: Text(l10n.pushStatusNoTransport),
            subtitle: Text(l10n.pushStatusNoTransportHint),
          ),
        PushStatus.notConfigured => ListTile(
            leading: const Icon(Icons.notifications_off_outlined),
            title: Text(l10n.pushStatusNotConfigured),
            subtitle: Text(l10n.pushStatusNotConfiguredHint),
          ),
      },
    );
  }
}

/// #2559 C2 — the person deliberately asks for notifications: the system
/// prompt appears now (never at start), and an allowed device registers
/// for push. A denial changes nothing else; the action can be repeated.
Future<void> allowNotifications(WidgetRef ref) async {
  final service = await ref.read(pushBootstrapProvider.future);
  if (service != null) {
    await service.allow();
  } else {
    await ref.read(notificationServiceProvider).requestPermission();
  }
  ref.invalidate(systemNotificationsEnabledProvider);
}

class _AllowButton extends ConsumerWidget {
  const _AllowButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) => TextButton(
        key: const ValueKey('push-allow'),
        onPressed: () => allowNotifications(ref),
        child: Text(context.l10n.pushAllowAction),
      );
}
