// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2557 C3 — My data › Personal information: my own records in each
// workspace my account names, one row per workspace. Each row asks its
// own workspace's host when the person taps Export, and says on its own
// what came of it: the file delivered through the platform's truthful
// delivery, or why nothing was exported, with Try again where asking again
// can help. One workspace that fails never reads as "all exported", and
// the personal part above is not touched.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/files/file_delivery.dart';
import '../../../core/files/file_delivery_notice.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/session/session_source.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/app_localizations.dart';
import '../application/workspace_exports.dart';
import '../domain/workspace_export.dart';
import '../providers/me_providers.dart';

/// The words for a workspace export that did not come.
String _workspaceExportProblem(
  AppLocalizations l10n,
  WorkspaceExportFailure failure,
) => switch (failure) {
  WorkspaceExportFailure.hostUnavailable => l10n.meDataWorkspaceHostUnavailable,
  WorkspaceExportFailure.disabled => l10n.meDataWorkspaceDisabled,
  WorkspaceExportFailure.forbidden => l10n.meDataWorkspaceForbidden,
  WorkspaceExportFailure.malformed => l10n.meDataWorkspaceMalformed,
  WorkspaceExportFailure.failed => l10n.meDataWorkspaceFailed,
};

class WorkspaceExportsCard extends ConsumerWidget {
  const WorkspaceExportsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final answer = ref.watch(myWorkspaceExportSourcesProvider);
    final sources = answer.value;
    final Widget body;
    if (answer.isLoading && !answer.hasValue) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: LinearProgressIndicator(
          key: ValueKey('me-data-workspaces-loading'),
        ),
      );
    } else if (answer.hasError) {
      body = Column(
        key: const ValueKey('me-data-workspaces-failed'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.meDataWorkspacesFailed,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          TextButton(
            key: const ValueKey('me-data-workspaces-retry'),
            onPressed: () => ref.invalidate(personalWorkspaceRefsProvider),
            child: Text(l10n.commonRetry),
          ),
        ],
      );
    } else if (sources == null || sources.isEmpty) {
      body = Text(
        l10n.meDataWorkspacesEmpty,
        key: const ValueKey('me-data-workspaces-empty'),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final source in sources)
            _WorkspaceExportRow(
              key: ValueKey(
                'me-data-workspace-${source.installationId}:${source.workspaceId}',
              ),
              source: source,
            ),
        ],
      );
    }
    return Card(
      key: const ValueKey('me-data-workspaces'),
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Padding(
        padding: AppSpacing.lgAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.meDataWorkspacesTitle,
              style: theme.textTheme.titleMedium?.strong,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.meDataWorkspacesScope,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            body,
          ],
        ),
      ),
    );
  }
}

/// One workspace: its name, Export, and what the last ask came to.
class _WorkspaceExportRow extends ConsumerStatefulWidget {
  const _WorkspaceExportRow({super.key, required this.source});

  final WorkspaceExportSource source;

  @override
  ConsumerState<_WorkspaceExportRow> createState() =>
      _WorkspaceExportRowState();
}

class _WorkspaceExportRowState extends ConsumerState<_WorkspaceExportRow> {
  bool _busy = false;
  WorkspaceExportOutcome? _last;

  String get _id =>
      '${widget.source.installationId}:${widget.source.workspaceId}';

  /// The signed-in account now; none once the row is gone.
  String? _principal() => mounted ? ref.read(sessionStateProvider).value : null;

  Future<void> _export() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _last = null;
    });
    final outcome = await ref
        .read(workspaceExportCommandProvider)
        .run(widget.source, principal: _principal);
    if (!mounted) return;
    setState(() => _last = outcome);
    if (outcome is WorkspaceExportReady) {
      await _deliver(outcome.export);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _deliver(WorkspaceExport export) async {
    final delivery = await deliverFile(
      context,
      ref,
      bytes: export.bytes(),
      fileName: export.fileName,
    );
    if (!mounted) return;
    announceFileDelivery(context, delivery, retry: () => _deliver(export));
  }

  @override
  Widget build(BuildContext context) {
    // Watched, so the command and the account stream live while a row
    // may still be waiting for its host.
    ref
      ..watch(workspaceExportCommandProvider)
      ..watch(sessionStateProvider);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final label = widget.source.label;
    final last = _last;
    final String? problem = switch (last) {
      WorkspaceExportNotDone(:final failure) => _workspaceExportProblem(
        l10n,
        failure,
      ),
      WorkspaceExportSuperseded() => l10n.meDataWorkspaceSuperseded,
      _ => null,
    };
    final retry = last is WorkspaceExportNotDone && last.failure.retryable;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label == null || label.isEmpty
                      ? l10n.meDataWorkspaceUnnamed(
                          widget.source.workspaceId.substring(
                            0,
                            widget.source.workspaceId.length.clamp(0, 8),
                          ),
                        )
                      : label,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              OutlinedButton.icon(
                key: ValueKey('me-data-workspace-export-$_id'),
                onPressed: _busy || retry ? null : _export,
                icon: const Icon(Icons.download_outlined),
                label: Text(l10n.meDataWorkspaceExport),
              ),
            ],
          ),
          if (_busy)
            LinearProgressIndicator(
              key: ValueKey('me-data-workspace-busy-$_id'),
            ),
          if (problem != null)
            Text(
              problem,
              key: ValueKey('me-data-workspace-problem-$_id'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          if (retry)
            TextButton(
              key: ValueKey('me-data-workspace-retry-$_id'),
              onPressed: _busy ? null : _export,
              child: Text(l10n.commonRetry),
            ),
        ],
      ),
    );
  }
}
