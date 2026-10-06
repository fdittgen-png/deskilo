// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/member_note_refs.dart';
import '../../providers/message_marks_providers.dart';

/// My bookmarked messages, across every conversation (0382).
class StarredMessagesScreen extends ConsumerWidget {
  const StarredMessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final starred = ref.watch(starredMessagesProvider);
    final format = ref.watch(appFormatProvider);
    return Scaffold(
      key: const ValueKey('starred-messages'),
      appBar: AppBar(title: Text(l10n?.messengerStarred ?? 'Starred')),
      body: switch (starred) {
        AsyncData(value: final rows) when rows.isEmpty => EmptyState(
            key: const ValueKey('starred-empty'),
            icon: Icons.star_outline,
            title: l10n?.messengerNoStarred ?? 'No starred message yet.',
          ),
        AsyncData(value: final rows) => Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: AppSpacing.mdAll,
                children: [
                  for (final m in rows)
                    Card(
                      key: ValueKey('starred-${m.messageId}'),
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        leading: const Icon(Icons.star, size: 20),
                        title: Text(
                          notePreview(m.body, max: 200),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text([
                          if (m.authorName.isNotEmpty) m.authorName,
                          if (m.contextLabel.isNotEmpty) m.contextLabel,
                          format.dateTime(m.sentAt),
                        ].join(' · ')),
                      ),
                    ),
                ],
              ),
            ),
          ),
        AsyncError() => Center(
            child: TextButton(
              key: const ValueKey('starred-retry'),
              onPressed: () => ref.invalidate(starredMessagesProvider),
              child: Text(l10n?.commonRetry ?? 'Try again'),
            ),
          ),
        _ => const LoadingView(),
      },
    );
  }
}
