// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/ids/request_id.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/lease_commitment.dart';
import '../../providers/premises_lease_providers.dart';
import 'lease_match_dialog.dart';

/// The rent a lease expects month by month, and the bills that replaced it.
Future<void> showLeaseCommitmentsSheet(
  BuildContext context,
  String workspaceId,
  String leaseId, {
  required String currencyCode,
  required bool canMatch,
}) => showAppSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => LeaseCommitmentsView(
    workspaceId: workspaceId,
    leaseId: leaseId,
    currencyCode: currencyCode,
    canMatch: canMatch,
  ),
);

String _stateLabel(AppLocalizations l10n, CommitmentState s) => switch (s) {
  CommitmentState.expected => l10n.leaseCommitmentExpected,
  CommitmentState.partial => l10n.leaseCommitmentPartial,
  CommitmentState.matched => l10n.leaseCommitmentMatched,
};

@visibleForTesting
class LeaseCommitmentsView extends ConsumerWidget {
  const LeaseCommitmentsView({
    required this.workspaceId,
    required this.leaseId,
    required this.currencyCode,
    required this.canMatch,
    super.key,
  });

  final String workspaceId;
  final String leaseId;
  final String currencyCode;
  final bool canMatch;

  ({String workspaceId, String leaseId}) get _key =>
      (workspaceId: workspaceId, leaseId: leaseId);

  Future<void> _match(
    BuildContext context,
    WidgetRef ref,
    CommitmentOccurrence occurrence,
  ) async {
    final saved = await showLeaseMatchDialog(
      context,
      workspaceId,
      occurrence,
      currencyCode,
    );
    if (saved != true) return;
    ref.invalidate(leaseCommitmentsProvider(_key));
    if (context.mounted) AppSnack.success(context, context.l10n.leaseMatchDone);
  }

  Future<void> _reverse(
    BuildContext context,
    WidgetRef ref,
    CommitmentMatch match,
  ) async {
    final reason = await _askReason(context);
    if (reason == null || reason.trim().isEmpty || !context.mounted) return;
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'commitment reversal failed',
      errorText: context.l10n.leaseMatchRefused,
      action: () async {
        await ref
            .read(commitmentCommandProvider)
            .reverse(
              workspaceId,
              matchId: match.id,
              reason: reason,
              requestId: newRequestId(),
            );
      },
    );
    ref.invalidate(leaseCommitmentsProvider(_key));
    if (ok && context.mounted) {
      AppSnack.success(context, context.l10n.leaseMatchReversed);
    }
  }

  Future<String?> _askReason(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(dialog.l10n.leaseMatchReverseTitle),
        content: AppTextField(
          key: const ValueKey('match-reverse-reason'),
          controller: controller,
          label: dialog.l10n.leaseMatchReverseReason,
          maxLength: 300,
        ),
        actions: [
          TextButton(
            key: const ValueKey('match-reverse-cancel'),
            onPressed: () => Navigator.of(dialog).pop(),
            child: Text(MaterialLocalizations.of(dialog).cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('match-reverse-confirm'),
            onPressed: () => Navigator.of(dialog).pop(controller.text),
            child: Text(dialog.l10n.leaseMatchReverseAction),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final money = moneyFormat(currencyCode);
    final page = ref.watch(leaseCommitmentsProvider(_key));
    return SheetShell(
      title: l10n.leaseCommitments,
      children: [
        Text(
          l10n.leaseCommitmentsIntro,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        page.when(
          loading: () => const LoadingView(),
          error: (_, _) => Text(l10n.leaseCommitmentsLoadFailed),
          data: (p) => p.occurrences.isEmpty
              ? Text(
                  l10n.leaseCommitmentsEmpty,
                  key: const ValueKey('commitments-empty'),
                )
              : Column(
                  children: [
                    for (final o in p.occurrences)
                      _OccurrenceCard(
                        occurrence: o,
                        money: money,
                        canMatch: canMatch,
                        onMatch: () => _match(context, ref, o),
                        onReverse: (m) => _reverse(context, ref, m),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _OccurrenceCard extends StatelessWidget {
  const _OccurrenceCard({
    required this.occurrence,
    required this.money,
    required this.canMatch,
    required this.onMatch,
    required this.onReverse,
  });

  final CommitmentOccurrence occurrence;
  final MoneyFormat money;
  final bool canMatch;
  final VoidCallback onMatch;
  final ValueChanged<CommitmentMatch> onReverse;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final o = occurrence;
    return Card(
      key: ValueKey('commitment-${o.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${MaterialLocalizations.of(context).formatMediumDate(o.dueOn)} · '
              '${_stateLabel(l10n, o.state)}',
              key: ValueKey('commitment-state-${o.id}'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              l10n.leaseCommitmentLine(
                money.formatMinor(o.expectedCents),
                money.formatMinor(o.matchedCents),
              ),
            ),
            for (final m in o.matches)
              _MatchTile(
                match: m,
                money: money,
                canReverse: canMatch && !m.reversed,
                onReverse: () => onReverse(m),
              ),
            if (canMatch && o.remainingCents > 0)
              TextButton(
                key: ValueKey('commitment-match-add-${o.id}'),
                onPressed: onMatch,
                child: Text(l10n.leaseMatchAction),
              ),
          ],
        ),
      ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  const _MatchTile({
    required this.match,
    required this.money,
    required this.canReverse,
    required this.onReverse,
  });

  final CommitmentMatch match;
  final MoneyFormat money;
  final bool canReverse;
  final VoidCallback onReverse;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final m = match;
    return ListTile(
      key: ValueKey('commitment-match-${m.id}'),
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(
        l10n.leaseMatchLineText(m.reference, money.formatMinor(m.allocatedCents)),
      ),
      subtitle: m.reversed
          ? Text(l10n.leaseMatchWasReversed)
          : m.lineUnallocatedCents > 0
          ? Text(l10n.leaseMatchVariance(money.formatMinor(m.lineUnallocatedCents)))
          : null,
      trailing: canReverse
          ? TextButton(
              key: ValueKey('commitment-reverse-${m.id}'),
              onPressed: onReverse,
              child: Text(l10n.leaseMatchReverse),
            )
          : null,
    );
  }
}
