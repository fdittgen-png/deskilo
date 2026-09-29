// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/messenger.dart';
import '../../providers/messenger_providers.dart';
import 'context_thread_screen.dart';

/// #1824 — the way into the space's Inquiries view, in the space's own
/// inbox. Shown to its hosts (owners and admins) while the workspace has
/// `spaceInquiries` on; the server answers only its real host roster.
class SpaceInquiriesEntry extends ConsumerWidget {
  const SpaceInquiriesEntry({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.spaceInquiries);
    final me = ref.watch(myMemberProvider).value;
    final workspace = ref.watch(currentWorkspaceProvider).value;
    if (!on ||
        workspace == null ||
        !(me?.isOwner == true || me?.isAdmin == true)) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    return TextButton.icon(
      key: const ValueKey('space-inquiries-entry'),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SpaceInquiriesScreen(
            workspaceId: workspace.id,
            workspaceName: workspace.name,
          ),
        ),
      ),
      icon: const Icon(Icons.support_agent_outlined),
      label: Text(l10n?.messengerInquiriesTitle ?? 'Inquiries'),
    );
  }
}

/// The inquiries outside people wrote to this space, newest first.
class SpaceInquiriesScreen extends ConsumerWidget {
  const SpaceInquiriesScreen({
    super.key,
    required this.workspaceId,
    required this.workspaceName,
  });

  final String workspaceId;
  final String workspaceName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final format = ref.watch(appFormatProvider);
    final provider = workspaceInquiriesProvider(workspaceId);
    final inquiries = ref.watch(provider);
    return Scaffold(
      key: const ValueKey('space-inquiries'),
      appBar: AppBar(title: Text(l10n?.messengerInquiriesTitle ?? 'Inquiries')),
      body: switch (inquiries) {
        AsyncData(value: final list) when list.isEmpty => Center(
          child: Padding(
            padding: AppSpacing.lgAll,
            child: Text(
              l10n?.messengerInquiriesEmpty ?? 'No inquiries yet.',
              key: const ValueKey('space-inquiries-empty'),
            ),
          ),
        ),
        AsyncData(value: final list) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(provider),
          child: ListView(
            children: [
              for (final inquiry in list)
                ListTile(
                  key: ValueKey('space-inquiry-${inquiry.id}'),
                  leading: const Icon(Icons.support_agent_outlined),
                  title: Text(
                    l10n?.messengerInquiryFrom(inquiry.requesterName) ??
                        'From ${inquiry.requesterName}',
                  ),
                  subtitle: Text(
                    inquiry.lastBody,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        format.date(inquiry.lastAt),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      if (inquiry.unread > 0)
                        Badge.count(count: inquiry.unread),
                    ],
                  ),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ContextThreadScreen(
                          kind: MessageContextKind.inquiryIn,
                          contextId: inquiry.id,
                          title: inquiry.requesterName,
                          subtitle:
                              l10n?.messengerContextInquiryIn(workspaceName) ??
                              'Inquiry to $workspaceName',
                        ),
                      ),
                    );
                    ref.invalidate(provider);
                  },
                ),
            ],
          ),
        ),
        AsyncError() => Center(
          child: TextButton(
            key: const ValueKey('space-inquiries-retry'),
            onPressed: () => ref.invalidate(provider),
            child: Text(l10n?.commonRetry ?? 'Try again'),
          ),
        ),
        _ => const LoadingView(),
      },
    );
  }
}
