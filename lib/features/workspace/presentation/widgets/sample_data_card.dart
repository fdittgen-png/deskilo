// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Sample data on the setup guide (ADR 0047 §9): only in a test space and
// only for someone who configures it. With none, the card says what a fill
// creates, that nothing is sent and that it can be cleared; with a batch,
// its counts and the way to clear it. A clear that did not happen says
// "not cleared" and offers to try again — never "done".
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../application/sample_data_commands.dart';
import '../../domain/sample_data.dart';
import '../../domain/workspace.dart';
import '../../domain/workspace_permission.dart';
import '../../providers/sample_data_providers.dart';
import '../../providers/workspace_providers.dart';

/// The card, or nothing where sample data does not belong.
class SampleDataCard extends ConsumerWidget {
  const SampleDataCard({super.key, required this.workspaceId});
  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final configures = ref
        .watch(myPermissionsProvider)
        .contains(WorkspacePermission.manageConfiguration);
    if (workspace == null ||
        workspace.id != workspaceId ||
        !workspace.isDevelopment ||
        !configures) {
      return const SizedBox.shrink();
    }
    return _SampleDataBody(workspaceId: workspaceId);
  }
}

enum _Failure { none, fill, clear }

class _SampleDataBody extends ConsumerStatefulWidget {
  const _SampleDataBody({required this.workspaceId});
  final String workspaceId;

  @override
  ConsumerState<_SampleDataBody> createState() => _SampleDataBodyState();
}

class _SampleDataBodyState extends ConsumerState<_SampleDataBody> {
  bool _busy = false;
  _Failure _failure = _Failure.none;

  Future<void> _fill() async {
    setState(() => _busy = true);
    final ok = await runGuarded(
      context,
      domain: 'workspace',
      message: 'sample data fill failed',
      action: () =>
          ref.read(sampleDataCommandsProvider).fill(widget.workspaceId),
    );
    _settle(ok ? _Failure.none : _Failure.fill);
  }

  Future<void> _clear(SampleDataBatch batch) async {
    setState(() => _busy = true);
    final ok = await runGuarded(
      context,
      domain: 'workspace',
      message: 'sample data clear failed',
      action: () async {
        final cleared = await ref
            .read(sampleDataCommandsProvider)
            .clear(widget.workspaceId, batch);
        if (!cleared) throw StateError('the sample data batch is still open');
      },
    );
    _settle(ok ? _Failure.none : _Failure.clear);
  }

  void _settle(_Failure failure) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failure = failure;
    });
    ref.invalidate(sampleDataStatusProvider(widget.workspaceId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = ref.watch(sampleDataStatusProvider(widget.workspaceId));
    // A server that cannot answer (an older one, or none) offers nothing.
    if (status is AsyncError) return const SizedBox.shrink();
    final body = switch (status) {
      AsyncData(:final value) => _content(context, value),
      _ => const LoadingView(),
    };
    return Card(
      key: const ValueKey('sample-data-card'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.sampleDataTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            body,
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, SampleDataBatch? batch) {
    final l10n = context.l10n;
    final failed = switch (_failure) {
      _Failure.fill when batch == null => InlineBanner(
        key: const ValueKey('sample-data-fill-failed'),
        icon: Icons.error_outline,
        text: l10n.sampleDataFillFailed,
        actionLabel: l10n.commonRetry,
        onAction: _busy ? null : _fill,
      ),
      _Failure.clear when batch != null => InlineBanner(
        key: const ValueKey('sample-data-not-cleared'),
        icon: Icons.error_outline,
        text: l10n.sampleDataNotCleared,
        actionLabel: l10n.commonRetry,
        onAction: _busy ? null : () => _clear(batch),
      ),
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (batch == null) ...[
          Text(l10n.sampleDataExplain),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.tonal(
            key: const ValueKey('sample-data-fill'),
            onPressed: _busy ? null : _fill,
            child: Text(l10n.sampleDataFill),
          ),
        ] else ...[
          Text(
            l10n.sampleDataCounts(
              batch.members,
              batch.bookings,
              batch.payments,
            ),
            key: const ValueKey('sample-data-counts'),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            key: const ValueKey('sample-data-clear'),
            onPressed: _busy ? null : () => _clear(batch),
            child: Text(l10n.sampleDataClear),
          ),
        ],
        if (failed != null) ...[const SizedBox(height: AppSpacing.sm), failed],
      ],
    );
  }
}
