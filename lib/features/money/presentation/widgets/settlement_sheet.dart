// SPDX-License-Identifier: 0BSD
//
// #804/#831 — regroup a member's open invoices into ONE settlement
// document. #872 — runs as an assistant: choose, then a summary, then
// Finish — the same shape as the month-close wizard.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/billing_rules.dart';
import '../../domain/invoice.dart';
import '../../providers/money_providers.dart';
import '../invoice_status.dart';
import '../period_label.dart';
import 'wizard_scaffold.dart';

/// Opens the settlement assistant (kept under its historical name).
Future<void> showSettlementSheet(BuildContext context, WidgetRef ref) =>
    Navigator.of(context).push<void>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const _SettlementWizard(),
    ));

class _SettlementWizard extends ConsumerStatefulWidget {
  const _SettlementWizard();

  @override
  ConsumerState<_SettlementWizard> createState() => _SettlementWizardState();
}

class _SettlementWizardState extends ConsumerState<_SettlementWizard> {
  String? _memberId;
  final _picked = <String>{};
  int _index = 0;
  bool _busy = false;

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
    setState(() => _busy = true);
    String number;
    try {
      final id = await ref.read(moneyRepositoryProvider).settleInvoices(
            workspaceId: workspace.id,
            memberId: memberId,
            invoiceIds: chosen.map((i) => i.id).toList(),
          );
      final fresh =
          await ref.read(moneyRepositoryProvider).fetchInvoices(workspace.id);
      number = fresh.where((i) => i.id == id).firstOrNull?.number ?? id;
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
    final candidates =
        memberId == null ? const <Invoice>[] : _candidates(memberId);
    final chosen = [
      for (final invoice in candidates)
        if (_picked.contains(invoice.id)) invoice,
    ];
    final currency =
        moneyFormat(candidates.isEmpty ? 'EUR' : candidates.first.currency);
    final total = chosen.fold<int>(0, (sum, i) => sum + i.totalCents);
    final steps = <WizardStepSpec>[
      (name: 'pick', label: l10n?.settlementStepPick ?? 'Choose invoices'),
      (name: 'summary', label: l10n?.wizardStepSummary ?? 'Summary'),
    ];
    final body = _index == 0
        ? ListView(children: [
            const SizedBox(height: AppSpacing.sm),
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
                    DropdownMenuItem(value: id, child: Text(names[id] ?? id)),
                ],
                onChanged: (v) => setState(() {
                  _memberId = v;
                  _picked.clear();
                }),
              ),
              const SizedBox(height: AppSpacing.sm),
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
                  secondary: Text(currency.formatMinor(invoice.totalCents)),
                  onChanged: (on) => setState(() {
                    if (on == true) {
                      _picked.add(invoice.id);
                    } else {
                      _picked.remove(invoice.id);
                    }
                  }),
                ),
              const Divider(),
              _totalRow(l10n, theme, currency.formatMinor(total)),
            ],
          ])
        : ListView(children: [
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n?.settlementSummaryHint ??
                  'These invoices are folded into one settlement document; '
                      'each stays readable behind it.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final invoice in chosen)
              ListTile(
                dense: true,
                title: Text(invoice.number),
                subtitle: Text(invoicePeriodLabel(context, invoice)),
                trailing: Text(currency.formatMinor(invoice.totalCents)),
              ),
            const Divider(),
            _totalRow(l10n, theme, currency.formatMinor(total)),
          ]);
    return WizardScaffold(
      title: l10n?.settlementAction ?? 'Regroup into one invoice',
      steps: steps,
      index: _index,
      body: body,
      onStepTap: (i) => setState(() => _index = i.clamp(0, chosen.length >= 2 ? 1 : 0)),
      onBack: () => setState(() => _index = 0),
      onNext: () => setState(() => _index = 1),
      nextEnabled: chosen.length >= 2,
      onFinish: () => _settle(chosen),
      finishKey: const ValueKey('settlement-submit'),
      finishLabel: l10n?.settlementAction ?? 'Regroup',
      finishEnabled: !_busy && chosen.length >= 2,
    );
  }

  Widget _totalRow(AppLocalizations? l10n, ThemeData theme, String total) =>
      Row(children: [
        Expanded(
          child: Text(
            l10n?.invoiceBalance ?? 'Balance due',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Text(total,
            key: const ValueKey('settlement-total'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ]);
}
