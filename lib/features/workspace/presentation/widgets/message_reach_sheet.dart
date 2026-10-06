// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../directory/providers/message_marks_providers.dart';

/// Who a message of mine reached in a group (0383): the people whose last
/// read is at or after it, with when, and those it has not reached yet.
Future<void> showMessageReachSheet(
  BuildContext context,
  WidgetRef ref, {
  required String messageId,
  required Map<String, String> names,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReachSheet(messageId: messageId, names: names),
    );

class _ReachSheet extends ConsumerWidget {
  const _ReachSheet({required this.messageId, required this.names});
  final String messageId;
  final Map<String, String> names;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final format = ref.watch(appFormatProvider);
    final reach = ref.watch(messageReachProvider(messageId));
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
                    key: ValueKey('reach-read-${p.memberId}'),
                    dense: true,
                    leading: const Icon(Icons.done_all, size: 18),
                    title: Text(names[p.memberId] ?? ''),
                    trailing: Text(format.dateTime(p.readAt)),
                  ),
                const SizedBox(height: AppSpacing.sm),
                Text(l10n?.messageNotReadYet ?? 'Not read yet',
                    style: theme.textTheme.labelLarge),
                if (r.pending.isEmpty) const Text('—'),
                for (final id in r.pending)
                  ListTile(
                    key: ValueKey('reach-pending-$id'),
                    dense: true,
                    leading: const Icon(Icons.done, size: 18),
                    title: Text(names[id] ?? ''),
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
