// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/billing_rules.dart';
import '../../domain/invoice.dart';
import '../../../../core/i18n/money_format.dart';
import '../../providers/money_providers.dart';
import '../invoice_status.dart';
import '../period_label.dart';

/// #804 — regroup several of ONE member's open invoices into a single
/// document they pay.
///
/// A member on the split billing cycle can be holding a subscription
/// invoice, an end-of-month invoice and last month's leftover at the same
/// time: three demands for one relationship. Regrouping produces one, and
/// the three stop being chased separately.
///
/// One member at a time, deliberately: a demand that mixes two people's
/// invoices is owed by nobody, and the server refuses it anyway.
Future<void> showSettlementSheet(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _SettlementSheet(),
  );
}

class _SettlementSheet extends ConsumerStatefulWidget {
  const _SettlementSheet();

  @override
  ConsumerState<_SettlementSheet> createState() => _SettlementSheetState();
}

class _SettlementSheetState extends ConsumerState<_SettlementSheet> {
  String? _memberId;
  final _picked = <String>{};
  bool _busy = false;

  /// Invoices that can still be regrouped: issued, not void, not already
  /// settled, and with no payment to orphan. The server checks each of
  /// these again — this decides what is worth OFFERING.
  List<Invoice> _candidates(String memberId) => [
        for (final entry in ref.watch(invoicingOverviewProvider).value?.open ??
            const <OpenInvoiceEntry>[])
          if (entry.invoice.memberId == memberId &&
              !entry.invoice.isVoided &&
              entry.invoice.settledByInvoiceId == null &&
              entry.invoice.kind != InvoiceKind.settlement &&
              entry.pendingMatch == null)
            entry.invoice,
      ];

  Future<void> _settle(List<Invoice> chosen) async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    final memberId = _memberId;
    if (workspace == null || memberId == null || chosen.length < 2) return;
    final currency = moneyFormat(chosen.first.currency);
    final total = chosen.fold<int>(0, (sum, i) => sum + i.totalCents);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n?.settlementAction ?? 'Regroup into one invoice'),
        content: Text(
          l10n?.settlementConfirm(
                chosen.length,
                currency.formatMinor(total),
              ) ??
              'Regroup ${chosen.length} invoices into one of '
                  '${currency.formatMinor(total)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n?.commonCancel ?? 'Cancel'),
          ),
          FilledButton(
            key: const ValueKey('settlement-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n?.commonSave ?? 'Save'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    String number;
    try {
      final id = await ref.read(moneyRepositoryProvider).settleInvoices(
            workspaceId: workspace.id,
            memberId: memberId,
            invoiceIds: chosen.map((i) => i.id).toList(),
          );
      number = id;
    } catch (e, st) {
      TraceLogger.instance
          .error('money', 'settle invoices failed', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnack.error(
        context,
        l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
      );
      return;
    }
    ref
      ..invalidate(invoicingOverviewProvider)
      ..invalidate(invoicesProvider);
    if (!mounted) return;
    Navigator.of(context).pop();
    AppSnack.info(
      context,
      l10n?.settlementDone(number) ?? 'Regrouped into $number.',
      replace: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final names = ref.watch(memberNamesProvider).value ?? const {};
    final open = ref.watch(invoicingOverviewProvider).value?.open ??
        const <OpenInvoiceEntry>[];
    // Only members with at least TWO regroupable invoices: offering a
    // member with one is offering an action that cannot be taken.
    final counts = <String, int>{};
    for (final entry in open) {
      if (!entry.invoice.isVoided &&
          entry.invoice.settledByInvoiceId == null &&
          entry.invoice.kind != InvoiceKind.settlement &&
          entry.pendingMatch == null) {
        counts.update(entry.invoice.memberId, (n) => n + 1,
            ifAbsent: () => 1);
      }
    }
    final eligible = [
      for (final e in counts.entries)
        if (e.value >= 2) e.key,
    ];
    final memberId = _memberId;
    final candidates = memberId == null ? const <Invoice>[] : _candidates(memberId);
    final chosen = [
      for (final invoice in candidates)
        if (_picked.contains(invoice.id)) invoice,
    ];
    final currency =
        moneyFormat(candidates.isEmpty ? 'EUR' : candidates.first.currency);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n?.settlementAction ?? 'Regroup into one invoice',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            if (eligible.isEmpty)
              Text(
                l10n?.settlementNeedsTwo ??
                    'Pick at least two open invoices of the same member.',
                style: theme.textTheme.bodySmall,
              )
            else ...[
              DropdownButtonFormField<String>(
                key: const ValueKey('settlement-member'),
                initialValue: memberId,
                decoration: InputDecoration(
                  labelText: l10n?.invoiceMemberLabel ?? 'Member',
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final id in eligible)
                    DropdownMenuItem(
                      value: id,
                      child: Text(names[id] ?? id),
                    ),
                ],
                onChanged: (v) => setState(() {
                  _memberId = v;
                  _picked.clear();
                }),
              ),
              const SizedBox(height: AppSpacing.sm),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final invoice in candidates)
                      CheckboxListTile(
                        key: ValueKey('settlement-pick-${invoice.id}'),
                        dense: true,
                        value: _picked.contains(invoice.id),
                        title: Text(invoice.number),
                        subtitle: Text([
                          invoicePeriodLabel(context, invoice),
                          invoiceKindLabel(l10n, invoice.kind),
                        ].join(' · ')),
                        secondary:
                            Text(currency.formatMinor(invoice.totalCents)),
                        onChanged: (on) => setState(() {
                          if (on == true) {
                            _picked.add(invoice.id);
                          } else {
                            _picked.remove(invoice.id);
                          }
                        }),
                      ),
                  ],
                ),
              ),
              const Divider(),
              Row(children: [
                Expanded(
                  child: Text(
                    l10n?.invoiceBalance ?? 'Balance due',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  currency.formatMinor(
                    chosen.fold<int>(0, (sum, i) => sum + i.totalCents),
                  ),
                  key: const ValueKey('settlement-total'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ]),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      _busy ? null : () => Navigator.of(context).pop(),
                  child: Text(l10n?.commonCancel ?? 'Cancel'),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  key: const ValueKey('settlement-submit'),
                  // Two is the minimum that makes the word "regroup" mean
                  // anything; the server enforces it as well.
                  onPressed: _busy || chosen.length < 2
                      ? null
                      : () => _settle(chosen),
                  child: Text(l10n?.settlementAction ?? 'Regroup'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
