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
import '../../../core/ui/server_label.dart';
import '../../directory/presentation/connection_outcome_text.dart';
import '../../workspace/providers/connected_space_providers.dart';
import '../domain/my_spaces.dart';
import '../domain/space_pairs.dart';
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
    final label = serverLabel(l10n, server.source);
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
                l10n.meLinkedOpenBody(label),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                key: const ValueKey('linked-space-open'),
                icon: const Icon(Icons.swap_horiz),
                label: Text(
                  l10n.meLinkedOpen(label),
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
    final servers = ref.watch(linkedServerSpacesProvider).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final server in servers)
          ..._server(context, ref, server),
      ],
    );
  }

  List<Widget> _server(
    BuildContext context,
    WidgetRef ref,
    LinkedServerSpaces server,
  ) {
    final l10n = context.l10n;
    final host = serverHost(server.source);
    final label = serverLabel(l10n, server.source);
    return [
      if (server.unavailable)
        InlineBanner(
          key: ValueKey('linked-unavailable-$host'),
          icon: Icons.cloud_off_outlined,
          severity: InlineBannerSeverity.info,
          text:
              l10n.meLinkedUnavailable(label),
          actionLabel: l10n.commonRetry,
          onAction: () => ref.invalidate(linkedServerSpacesProvider),
        ),
      for (final group in pairSides(server.spaces))
        MeWorkspaceRow(
          environmentHint: group.any((s) => s.env.isDevelopment)
              ? l10n.uxTestSpaceHint : null,
          avatar: const CircleAvatar(child: Icon(Icons.dns_outlined)),
          name: group.first.name,
          detail: group.any((s) => s.standing == MySpaceStanding.pending)
              ? (l10n.meLinkedPendingOn(label))
              : label,
          actions: [
            for (final space in group)
              Tooltip(
                message: space.standing == MySpaceStanding.pending
                    ? (l10n.meLinkedPendingOn(label))
                    : space.name,
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: OutlinedButton(
                    key: ValueKey('linked-space-$host-${space.id}'),
                    onPressed: () => _open(context, ref, server, space),
                    child: Text(space.env.isProduction
                        ? l10n.uxOpenWorkspace
                        : l10n.uxTestSpace),
                  ),
                ),
              ),
          ],
        ),
    ];
  }
}
