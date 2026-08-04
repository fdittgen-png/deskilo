// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'push_providers.dart';
import 'push_service.dart';

/// Push pipeline status line for Settings (#424/#428): FCM registered,
/// or not-configured with the owner-facing fix — the field had ZERO
/// registered endpoints and no way to see why.
class PushStatusTile extends ConsumerWidget {
  const PushStatusTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final service = ref.watch(pushBootstrapProvider).value;
    if (service == null) return const SizedBox.shrink();
    return ValueListenableBuilder<PushStatus>(
      valueListenable: service.status,
      builder: (context, status, _) => switch (status) {
        PushStatus.registered => ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: Text(l10n?.pushStatusRegistered ??
                'Push notifications are active'),
          ),
        PushStatus.notConfigured => ListTile(
            leading: const Icon(Icons.notifications_off_outlined),
            title: Text(l10n?.pushStatusNotConfigured ??
                'Push notifications are not set up yet'),
            subtitle: Text(l10n?.pushStatusNotConfiguredHint ??
                'The workspace owner completes the Firebase setup '
                    '(push-setup guide).'),
          ),
      },
    );
  }
}
