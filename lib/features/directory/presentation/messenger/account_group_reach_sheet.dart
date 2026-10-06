// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/account_group.dart';
import '../../providers/messenger_providers.dart';

final _groupReachProvider =
    FutureProvider.autoDispose.family<GroupReach, String>((ref, id) =>
        ref.watch(messengerActionsProvider()).groupReach(id));

/// Who a message of mine in a group reached (0384): read, with when, and
/// not yet.
Future<void> showGroupReachSheet(
  BuildContext context,
  WidgetRef ref, {
  required String messageId,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _GroupReach(messageId: messageId),
    );

class _GroupReach extends ConsumerWidget {
  const _GroupReach({required this.messageId});
  final String messageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final format = ref.watch(appFormatProvider);
    final reach = ref.watch(_groupReachProvider(messageId));
    return SafeArea(
      child: Padding(
        padding: AppSpacing.lgAll,
        child: switch (reach) {
          AsyncData(value: final r) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n?.messageInfo ?? 'Message info',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                Text(l10n?.messageReadBy ?? 'Read by',
                    style: theme.textTheme.labelLarge),
                if (r.readers.isEmpty) const Text('—'),
                for (final p in r.readers)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.done_all, size: 18),
                    title: Text(p.name),
                    trailing: Text(format.dateTime(p.readAt)),
                  ),
                const SizedBox(height: AppSpacing.sm),
                Text(l10n?.messageNotReadYet ?? 'Not read yet',
                    style: theme.textTheme.labelLarge),
                if (r.pending.isEmpty) const Text('—'),
                for (final name in r.pending)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.done, size: 18),
                    title: Text(name),
                  ),
              ],
            ),
          AsyncError() => Text(l10n?.portalActionFailed ??
              'Could not save this change. Please try again.'),
          _ => const LoadingView(),
        },
      ),
    );
  }
}
