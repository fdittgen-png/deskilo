// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — my spaces on the other servers this account is linked to, in
// the same list, the server named only as a quiet subtitle.
//
// Reading them uses each server's own linked session. #2562 -- OPENING one
// uses it too: the member's workspaces there are read through that
// installation's pinned client, then the selection names the workspace and
// its source, so the space runs on its own installation and the root
// client is never its fallback. A refusal says why, keeps the person where
// they are and changes nothing.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/space_entry.dart';
import '../../../core/backend/connection_outcome.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/app_sheet.dart';
import '../../../core/ui/inline_banner.dart';
import '../../directory/presentation/connection_outcome_text.dart';
import '../../workspace/providers/connected_space_providers.dart';
import '../domain/my_spaces.dart';
import '../providers/me_providers.dart';
import 'me_workspace_row.dart';

class LinkedSpacesSection extends ConsumerWidget {
  const LinkedSpacesSection({super.key});

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    LinkedServerSpaces server,
    LinkedSpace space,
  ) async {
    final l10n = context.l10n;
    final go = await showAppSheet<bool>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: AppSpacing.gutterAll,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                space.name,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.meLinkedOpenBody(server.host),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                key: const ValueKey('linked-space-open'),
                icon: const Icon(Icons.swap_horiz),
                label: Text(
                  l10n.meLinkedOpen(server.host),
                ),
                onPressed: () => Navigator.of(sheetContext).pop(true),
              ),
            ],
          ),
        ),
      ),
    );
    if (go != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final entered = await ref
          .read(connectedSpaceEntryProvider.notifier)
          .enter(server.source, space.id);
      // Null: a newer entry superseded this one; it selects, this does not.
      if (entered == null || !context.mounted) return;
      await enterSpace(context, ref, entered, connected: true);
    } on ConnectionFailure catch (failure, st) {
      TraceLogger.instance.warn('me', 'linked space not opened',
          error: failure, stackTrace: st);
      messenger.showSnackBar(
        SnackBar(content: Text(connectionFailureText(l10n, failure))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final servers = ref.watch(linkedServerSpacesProvider).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final server in servers) ...[
          if (server.unavailable)
            InlineBanner(
              key: ValueKey('linked-unavailable-${server.host}'),
              icon: Icons.cloud_off_outlined,
              severity: InlineBannerSeverity.info,
              text:
                  l10n.meLinkedUnavailable(server.host),
              actionLabel: l10n.commonRetry,
              onAction: () => ref.invalidate(linkedServerSpacesProvider),
            ),
          for (final group in _groups(server.spaces))
            MeWorkspaceRow(
              environmentHint: group.any((s) => s.environment == 'dev')
                  ? l10n.uxTestSpaceHint : null,
              avatar: const CircleAvatar(child: Icon(Icons.dns_outlined)),
              name: group.first.name,
              detail: group.any((s) => s.standing == MySpaceStanding.pending)
                  ? (l10n.meLinkedPendingOn(server.host))
                  : server.host,
              actions: [
                for (final space in group)
                  Tooltip(
                    message: space.standing == MySpaceStanding.pending
                        ? (l10n.meLinkedPendingOn(server.host))
                        : space.name,
                    child: Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: OutlinedButton(
                        key: ValueKey('linked-space-${server.host}-${space.id}'),
                        onPressed: () => _open(context, ref, server, space),
                        child: Text(space.environment.isEmpty
                            ? (l10n.meSpaceOpen)
                            : space.environment == 'prod'
                            ? l10n.uxOpenWorkspace
                            : l10n.uxTestSpace),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ],
    );
  }
}

List<List<LinkedSpace>> _groups(List<LinkedSpace> spaces) {
  final groups = <String, List<LinkedSpace>>{};
  for (final space in spaces) {
    final key = space.pairId.isEmpty
        ? 'space:${space.id}'
        : 'pair:${space.pairId}';
    groups.putIfAbsent(key, () => []).add(space);
  }
  return [
    for (final group in groups.values)
      group..sort((a, b) => b.environment.compareTo(a.environment)),
  ];
}
