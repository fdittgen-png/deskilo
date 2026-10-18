// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/premises_lease.dart';
import '../../providers/premises_lease_providers.dart';
import 'lease_commitments_sheet.dart';
import 'premises_lease_dialogs.dart';
import 'premises_lease_notice_dialog.dart';
import 'premises_lease_settlement_dialog.dart';
import 'premises_lease_term_dialogs.dart';

/// Opens the premises lease of [workspaceId]. The caller decides when to offer
/// it; the server decides who reads and who writes.
Future<void> showPremisesLeaseSheet(
  BuildContext context,
  String workspaceId, {
  required String currencyCode,
  required bool canManage,
  bool canMatch = false,
}) => showAppSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => PremisesLeaseView(
    workspaceId: workspaceId,
    currencyCode: currencyCode,
    canManage: canManage,
    canMatch: canMatch,
  ),
);

String _leaseStatusLabel(AppLocalizations l10n, LeaseStatus status) =>
    switch (status) {
      LeaseStatus.draft => l10n.leaseStatusDraft,
      LeaseStatus.active => l10n.leaseStatusActive,
      LeaseStatus.noticeGiven => l10n.leaseStatusNotice,
      LeaseStatus.ended => l10n.leaseStatusEnded,
    };

/// The leases, each with its terms and their history, and the doors to add a
/// lease, a term and notice for who may.
@visibleForTesting
class PremisesLeaseView extends ConsumerWidget {
  const PremisesLeaseView({
    required this.workspaceId,
    required this.currencyCode,
    required this.canManage,
    this.canMatch = false,
    super.key,
  });

  final String workspaceId;
  final String currencyCode;
  final bool canManage;

  /// Whether the signed-in person may link supplier bills (managePurchases).
  final bool canMatch;

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    Future<bool?> Function() dialog,
  ) async {
    final saved = await dialog();
    if (saved != true) return;
    ref.invalidate(premisesLeasesProvider(workspaceId));
    if (context.mounted) AppSnack.success(context, context.l10n.leaseSaved);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final leases = ref.watch(premisesLeasesProvider(workspaceId));
    return SheetShell(
      title: l10n.leaseTitle,
      children: [
        Text(l10n.leaseIntro, style: Theme.of(context).textTheme.bodySmall),
        if (canManage)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const ValueKey('lease-add'),
              onPressed: () => _open(
                context,
                ref,
                () => showLeaseDialog(context, workspaceId),
              ),
              icon: const Icon(Icons.add),
              label: Text(l10n.leaseAdd),
            ),
          ),
        leases.when(
          loading: () => const LoadingView(),
          error: (_, _) => Text(l10n.leaseLoadFailed),
          data: (rows) => rows.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Text(
                    l10n.leaseEmpty,
                    key: const ValueKey('lease-empty'),
                  ),
                )
              : Column(
                  children: [
                    for (final lease in rows)
                      _LeaseCard(
                        lease: lease,
                        currencyCode: currencyCode,
                        onCommitments: () => showLeaseCommitmentsSheet(
                          context,
                          workspaceId,
                          lease.id,
                          currencyCode: currencyCode,
                          canMatch: canMatch,
                        ),
                        onTerm: !canManage || lease.terminated
                            ? null
                            : () => _open(
                                context,
                                ref,
                                () => showLeaseTermDialog(
                                  context,
                                  workspaceId,
                                  lease,
                                ),
                              ),
                        onNotice:
                            !canManage || lease.status != LeaseStatus.active
                            ? null
                            : () => _open(
                                context,
                                ref,
                                () => showLeaseNoticeDialog(
                                  context,
                                  workspaceId,
                                  lease,
                                ),
                              ),
                        onSettle:
                            !canManage ||
                                lease.status == LeaseStatus.draft ||
                                !lease.terms.any(
                                  (t) =>
                                      t.kind ==
                                      LeaseTermKind.serviceChargeAdvance,
                                )
                            ? null
                            : () => _open(
                                context,
                                ref,
                                () => showLeaseSettlementDialog(
                                  context,
                                  workspaceId,
                                  lease,
                                ),
                              ),
                        onEdit: !canManage || lease.terminated
                            ? null
                            : () => _open(
                                context,
                                ref,
                                () => showLeaseDialog(
                                  context,
                                  workspaceId,
                                  lease: lease,
                                ),
                              ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _LeaseCard extends StatelessWidget {
  const _LeaseCard({
    required this.lease,
    required this.currencyCode,
    required this.onTerm,
    required this.onNotice,
    required this.onSettle,
    required this.onEdit,
    required this.onCommitments,
  });

  final PremisesLease lease;
  final String currencyCode;
  final VoidCallback? onTerm;
  final VoidCallback? onNotice;
  final VoidCallback? onSettle;
  final VoidCallback? onEdit;
  final VoidCallback onCommitments;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    final money = moneyFormat(currencyCode);
    String day(DateTime d) => material.formatMediumDate(d);
    return Card(
      key: ValueKey('lease-${lease.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lease.premises,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '${l10n.leaseLessor(lease.supplierName)} · '
              '${_leaseStatusLabel(l10n, lease.status)}',
              key: ValueKey('lease-status-${lease.id}'),
            ),
            Text(l10n.leaseStarted(day(lease.startsOn))),
            if (lease.fixedUntil != null)
              Text(l10n.leaseFixedUntil(day(lease.fixedUntil!))),
            if (lease.noticeDeadline != null && !lease.terminated)
              Text(
                l10n.leaseNoticeDeadline(day(lease.noticeDeadline!)),
                key: ValueKey('lease-deadline-${lease.id}'),
              ),
            if (lease.depositCents > 0)
              Text(l10n.leaseDeposit(money.formatMinor(lease.depositCents))),
            if (lease.indexationNote.isNotEmpty) Text(lease.indexationNote),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.leaseTermsHeading,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            for (final t in lease.terms)
              ListTile(
                key: ValueKey('lease-term-${t.id}'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  t.effectiveTo == null
                      ? l10n.leaseTermLine(
                          t.kind == LeaseTermKind.other
                              ? t.label
                              : leaseTermKindLabel(l10n, t.kind),
                          money.formatMinor(t.amountCents),
                          day(t.effectiveFrom),
                        )
                      : l10n.leaseTermLineClosed(
                          t.kind == LeaseTermKind.other
                              ? t.label
                              : leaseTermKindLabel(l10n, t.kind),
                          money.formatMinor(t.amountCents),
                          day(t.effectiveFrom),
                          day(t.effectiveTo!),
                        ),
                ),
              ),
            _SettlementLines(lease: lease, money: money),
            if (lease.terminated) ...[
              Text(
                l10n.leaseEndsOn(
                  day(lease.effectiveEnd!),
                  lease.terminationReason,
                ),
                key: ValueKey('lease-end-${lease.id}'),
              ),
              if (lease.depositDueBackCents > 0)
                Text(
                  l10n.leaseDepositBack(
                    money.formatMinor(lease.depositDueBackCents),
                  ),
                  key: ValueKey('lease-deposit-back-${lease.id}'),
                ),
              if (lease.occurrencesAfterEnd > 0)
                Text(l10n.leaseOccurrencesAfter(lease.occurrencesAfterEnd)),
            ],
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                TextButton(
                  key: ValueKey('lease-commitments-${lease.id}'),
                  onPressed: onCommitments,
                  child: Text(l10n.leaseCommitments),
                ),
                if (onEdit != null)
                  TextButton(
                    key: ValueKey('lease-edit-${lease.id}'),
                    onPressed: onEdit,
                    child: Text(l10n.leaseEdit),
                  ),
                if (onTerm != null)
                  TextButton(
                    key: ValueKey('lease-term-add-${lease.id}'),
                    onPressed: onTerm,
                    child: Text(l10n.leaseAddTerm),
                  ),
                if (onSettle != null)
                  TextButton(
                    key: ValueKey('lease-settle-${lease.id}'),
                    onPressed: onSettle,
                    child: Text(l10n.leaseSettle),
                  ),
                if (onNotice != null)
                  TextButton(
                    key: ValueKey('lease-notice-${lease.id}'),
                    onPressed: onNotice,
                    child: Text(l10n.leaseGiveNotice),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The settlements of the service charges: what was billed against the
/// advances, and what is owed or credited.
class _SettlementLines extends StatelessWidget {
  const _SettlementLines({required this.lease, required this.money});

  final PremisesLease lease;
  final MoneyFormat money;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    String day(DateTime d) => material.formatMediumDate(d);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in lease.settlements)
          Text(
            key: ValueKey('lease-settlement-${s.id}'),
            s.creditCents > 0
                ? l10n.leaseSettlementCredit(
                    day(s.periodStart),
                    day(s.periodEnd),
                    money.formatMinor(s.creditCents),
                  )
                : l10n.leaseSettlementOwed(
                    day(s.periodStart),
                    day(s.periodEnd),
                    money.formatMinor(s.owedCents),
                    day(s.dueOn),
                  ),
          ),
      ],
    );
  }
}
