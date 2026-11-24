// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3556 (1b) — the bar of a selection on My finances: how many invoices,
// what they still owe in the business's one currency (named), then "Pay"
// (filled) and "I have paid" (outlined). It sits at the bottom of My
// finances, above the app's own bar, and wraps rather than hides anything
// on a narrow screen with large text. One line says why an invoice of
// another business or currency cannot join.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../domain/finance_selection.dart';
import '../../domain/payment_claims.dart';
import '../../providers/finance_overview_provider.dart';
import '../../providers/finance_selection_provider.dart';
import '../../providers/invoice_group_providers.dart';
import '../claim_refusal_text.dart';
import '../finance_host_unavailable.dart';
import '../screens/money_online_payment.dart';
import 'finance_selection_confirm.dart';
import 'invoice_group_sheet.dart';

class FinanceSelectionBar extends ConsumerStatefulWidget {
  const FinanceSelectionBar({super.key});

  @override
  ConsumerState<FinanceSelectionBar> createState() => _BarState();
}

class _BarState extends ConsumerState<FinanceSelectionBar> {
  bool _busy = false;

  /// Pays the oldest month of [selection] online, after its confirmation:
  /// one provider checkout per tap; the other months stay selected.
  Future<void> _pay(FinanceSelection selection) async {
    final commands = ref.read(financeSelectionCommandsProvider);
    if (_tooMany(selection)) return;
    final confirmed = await confirmFinanceSelection(
      context,
      selection,
      declare: false,
    );
    if (confirmed != true || !mounted) return;
    final captured = await commands.capture(selection);
    if (captured == null) {
      if (mounted) _unavailable(selection, () => _run(() => _pay(selection)));
      return;
    }
    try {
      if (!mounted) return;
      // #4165 — invoices without a month are one payment, whatever their
      // issue dates; monthly ones are paid a month at a time.
      final first = selection.isStandalone ? null : selection.months.first;
      final paid = first?.invoices ?? selection.invoices;
      final started = await MoneyOnlinePayment(this, ref).pay(
        first?.cents ?? selection.cents, first?.period ?? '',
        invoiceIds: [for (final i in paid) i.id], captured: captured,
        standalone: selection.isStandalone,
      );
      if (started) {
        ref.read(financeSelectionControllerProvider.notifier).remove(paid);
      }
    } finally {
      captured.release();
    }
    // refused, failed or started: the rows are read again either way
    await refreshMyFinances(ref);
  }

  /// A month over the payment function's limit is said before anything is
  /// sent.
  bool _tooMany(FinanceSelection selection) {
    if (selection.isStandalone
        ? selection.count <= maxClaimedInvoices
        : selection.months.every((m) => m.invoices.length <= maxClaimedInvoices)) {
      return false;
    }
    AppSnack.error(
      context,
      context.l10n.financesTooManyInvoices(maxClaimedInvoices),
    );
    return true;
  }

  /// The business of [selection] could not be reached or verified: nothing
  /// was sent, and the person may try again ([retry]).
  void _unavailable(FinanceSelection selection, VoidCallback retry) =>
      showFinanceHostUnavailable(
        context,
        selection.workspaceName ?? '',
        retry: () {
          if (mounted) retry();
        },
      );

  /// Tries a declaration again on what is selected NOW: a month already
  /// recorded has left the selection, so it is never declared twice.
  void _declareAgain() {
    final now = ref.read(financeSelectionProvider);
    if (mounted && !now.isEmpty) unawaited(_run(() => _declare(now)));
  }

  /// A declaration that stopped, said as what it did: the months recorded
  /// before it and the months not, with why; nothing recorded reads as the
  /// refusal or as a business that could not be reached. The host being lost
  /// offers to try again on what is still selected.
  void _declareStopped(
    FinanceSelection selection, {
    required List<String> recorded,
    required ClaimRefusal? refused,
  }) {
    final l10n = context.l10n;
    final business = selection.workspaceName ?? '';
    if (recorded.isEmpty) {
      if (refused != null) {
        AppSnack.error(context, claimRefusalText(l10n, refused));
      } else {
        _unavailable(selection, _declareAgain);
      }
      return;
    }
    String months(List<String> periods) =>
        periods.map((p) => monthLabel(context, p)).join(', ');
    final rest = [
      for (final m in selection.months)
        if (!recorded.contains(m.period)) m.period,
    ];
    AppSnack.error(
      context,
      l10n.financesDeclaredPart(
        months(recorded),
        months(rest),
        refused != null
            ? claimRefusalText(l10n, refused)
            : l10n.financesBusinessUnavailableOpen(business),
      ),
      action: refused != null
          ? null
          : SnackBarAction(
              key: const ValueKey('finance-declare-retry'),
              label: l10n.commonRetry,
              onPressed: _declareAgain,
            ),
    );
  }

  /// Declares [selection] paid, one declaration per month, after its one
  /// confirmation; a refusal is said in its own words, with the months
  /// recorded before it, and leaves what is still to declare selected.
  Future<void> _declare(FinanceSelection selection) async {
    final l10n = context.l10n;
    final commands = ref.read(financeSelectionCommandsProvider);
    if (_tooMany(selection)) return;
    final confirmed = await confirmFinanceSelection(
      context,
      selection,
      declare: true,
    );
    if (confirmed != true || !mounted) return;
    ClaimRefusal? refused;
    bool? done;
    final recorded = <String>[];
    await runGuarded(
      context,
      domain: 'money',
      message: 'declare selected invoices failed',
      errorText: l10n.financesDeclareFailed,
      action: () async {
        try {
          done = await commands.declare(
                selection,
                onRecorded: (m) {
                  recorded.add(m.period);
                  ref
                      .read(financeSelectionControllerProvider.notifier)
                      .remove(m.invoices);
                },
              );
        } on ClaimRefused catch (r, st) {
          TraceLogger.instance.warn(
            'money',
            'payment claim refused: ${r.reason.code}',
            error: r,
            stackTrace: st,
          );
          refused = r.reason;
        }
      },
    );
    await refreshMyFinances(ref);
    if (!mounted) return;
    if (refused != null || done == false) {
      _declareStopped(selection, recorded: recorded, refused: refused);
    } else if (done == true) {
      AppSnack.success(
        context,
        l10n.financesDeclaredSent(selection.workspaceName ?? ''),
      );
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(financeSelectionProvider);
    if (selection.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final total = personalFormatOf(context)
        .moneyNamed(selection.currency!)
        .formatMinor(selection.cents);
    // #4165 — a selection is of one kind: said once, so a checkbox that
    // will not tick has its reason in view
    final kindNote = selection.isStandalone
        ? l10n.financesSelectionOnlyStandalone
        : l10n.financesSelectionOnlyMonthly;
    return Material(
      key: const ValueKey('finances-selection-bar'),
      elevation: 3,
      color: theme.colorScheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.financesSelectionSummary(selection.count, total),
                      key: const ValueKey('finances-selection-summary'),
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  _More(selection: selection),
                  IconButton(
                    key: const ValueKey('finances-selection-clear'),
                    tooltip: l10n.financesSelectionClear,
                    icon: const Icon(Icons.close),
                    onPressed: () => ref
                        .read(financeSelectionControllerProvider.notifier)
                        .clear(),
                  ),
                ],
              ),
              Text(
                l10n.financesSelectionOneBusiness(
                  selection.workspaceName ?? '',
                ),
                style: theme.textTheme.bodySmall,
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      kindNote,
                      key: const ValueKey('finances-selection-kind'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  if (selection.isStandalone)
                    HelpDot(
                      l10n.standaloneInvoiceMore,
                      anchor: HelpAnchor.moneyStandalonePayment,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  FilledButton(
                    key: const ValueKey('finances-selection-pay'),
                    onPressed: _busy ? null : () => _run(() => _pay(selection)),
                    child: Text(l10n.financesPayAmount(total)),
                  ),
                  OutlinedButton(
                    key: const ValueKey('finances-selection-declare'),
                    onPressed: _busy
                        ? null
                        : () => _run(() => _declare(selection)),
                    child: Text(l10n.financesIHavePaid),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The bar's overflow: the selection filed in one of my groups (#3556 part
/// 2), each invoice by the installation that holds it; one whose
/// installation cannot be told is left out.
class _More extends ConsumerWidget {
  const _More({required this.selection});

  final FinanceSelection selection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final refOf = ref.watch(invoiceRefResolverProvider);
    final items = [
      for (final invoice in selection.invoices)
        if (refOf(invoice) case final r?) (invoice, r),
    ];
    return PopupMenuButton<void>(
      key: const ValueKey('finances-selection-more'),
      tooltip: MaterialLocalizations.of(context).showMenuTooltip,
      itemBuilder: (_) => [
        PopupMenuItem<void>(
          key: const ValueKey('finances-selection-group'),
          enabled: items.isNotEmpty,
          onTap: () => showInvoiceGroupSheetFor(context, items),
          child: Text(context.l10n.financesGroupAdd),
        ),
      ],
    );
  }
}
