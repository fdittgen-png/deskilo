// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4167 (A) -- Me › My businesses: what each business of the person's is still
// owed, per business and per currency side by side. Currencies are never added,
// and what the business owes its customers back (a refund due) is a line of its
// own, never netted. A business that could not be read says so; it is never a
// zero. The business's own screens decide who may act: this face only reads.
import 'package:flutter/material.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/view_toggle.dart';
import '../../domain/business_payables.dart';
import '../../domain/business_receivables.dart';
import 'business_detail_sheet.dart';

/// #4167 — the two faces of Me › Finances.
enum FinancesFace { personal, businesses }

/// The switch between Personal and My businesses.
class FinancesFaceSwitch extends StatelessWidget {
  const FinancesFaceSwitch({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final FinancesFace selected;
  final ValueChanged<FinancesFace> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: ViewToggle<FinancesFace>(
        key: const ValueKey('finances-face'),
        selected: selected,
        onChanged: onChanged,
        options: [
          ViewToggleOption(
            value: FinancesFace.personal,
            icon: Icons.person_outline,
            label: l10n.myBusinessesFacePersonal,
          ),
          ViewToggleOption(
            value: FinancesFace.businesses,
            icon: Icons.storefront_outlined,
            label: l10n.myBusinessesFaceBusinesses,
          ),
        ],
      ),
    );
  }
}

class MyBusinessesFace extends StatelessWidget {
  const MyBusinessesFace({
    super.key,
    required this.sources,
    this.payables = const [],
    required this.onRetry,
    required this.onOpen,
    required this.onDetail,
  });

  /// The businesses to show: those that answered or could not be read.
  final List<BusinessReceivablesSource> sources;

  /// What each business has to pay, by workspace: the same businesses read the
  /// other way. Empty while it is being read.
  final List<BusinessPayables> payables;

  final VoidCallback onRetry;

  /// Opens the invoices of the business [workspaceId], in that business.
  final ValueChanged<String> onOpen;

  /// Opens the rows behind a figure.
  final ValueChanged<BusinessDetail> onDetail;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      key: const ValueKey('my-businesses-face'),
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(l10n.myBusinessesIntro, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.md),
        for (final source in sources)
          switch (source) {
            BusinessReceivablesAnswered() => _Business(
              source: source,
              payables: payables
                  .where((p) => p.target.financeKey == source.target.financeKey)
                  .firstOrNull,
              onOpen: () => onOpen(source.workspaceId),
              onDetail: onDetail,
            ),
            BusinessReceivablesUnavailable() => _Unavailable(
              source: source,
              onRetry: onRetry,
            ),
            // The person may not read this business's money: it is not one of
            // the businesses shown here, and no figure stands in for it.
            BusinessReceivablesRefused() => const SizedBox.shrink(),
          },
      ],
    );
  }
}

class _Business extends StatelessWidget {
  const _Business({
    required this.source,
    required this.payables,
    required this.onOpen,
    required this.onDetail,
  });

  final BusinessReceivablesAnswered source;
  final BusinessPayables? payables;
  final ValueChanged<BusinessDetail> onDetail;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rows = source.summary.rows;
    return Card(
      key: ValueKey('my-business-${source.workspaceId}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(source.name, style: Theme.of(context).textTheme.sectionTitle),
            const SizedBox(height: AppSpacing.sm),
            if (rows.isEmpty) Text(l10n.myBusinessNothingOwed),
            for (final row in rows)
              _Currency(
                row: row,
                onState: (state) => onDetail(
                  ReceivablesDetail(source.target, source.name, row.currency, state),
                ),
              ),
            if (payables != null)
              _Payables(
                payables: payables!,
                onKind: (currency, kind) => onDetail(
                  PayablesDetail(source.target, source.name, currency, kind),
                ),
              ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                key: ValueKey('my-business-open-${source.workspaceId}'),
                onPressed: onOpen,
                child: Text(l10n.myBusinessOpen),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the business has to pay: suppliers and the members it owes an expense
/// back, apart; held is shown as part of what remains. A direction that was
/// refused or could not be read says so; it is never a zero.
class _Payables extends StatelessWidget {
  const _Payables({required this.payables, required this.onKind});

  final BusinessPayables payables;
  final void Function(String currency, String? kind) onKind;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final key = payables.target.workspaceId;
    final notes = <Widget>[
      if (payables.suppliers is! PayablesAnswered || payables.members is! PayablesAnswered)
        Text(
          key: ValueKey('my-business-payables-note-$key'),
          payables.suppliers is PayablesUnavailable || payables.members is PayablesUnavailable
              ? l10n.myBusinessPayablesUnavailable
              : l10n.myBusinessPayablesRefused,
        ),
    ];
    final currencies = payables.currencies;
    if (currencies.isEmpty && notes.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (currencies.isNotEmpty)
            Text(l10n.cashHubToPay, style: Theme.of(context).textTheme.labelLarge),
          for (final c in currencies)
            _PayablesCurrency(currency: c, onKind: (kind) => onKind(c.currency, kind)),
          ...notes,
        ],
      ),
    );
  }
}

class _PayablesCurrency extends StatelessWidget {
  const _PayablesCurrency({required this.currency, required this.onKind});

  final PayablesCurrency currency;
  final ValueChanged<String?> onKind;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final money = personalFormatOf(context).moneyNamed(currency.currency);
    final code = currency.currency;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      key: ValueKey('my-business-payables-$code'),
      children: [
        Row(
          children: [
            Expanded(child: Text(code, style: Theme.of(context).textTheme.bodySmall)),
            Text(
              money.formatMinor(currency.totalCents),
              key: ValueKey('my-business-payable-$code'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        if (currency.supplierCents != 0)
          _Line(l10n.myBusinessSuppliers, money.formatMinor(currency.supplierCents), valueKey: 'my-business-payable-suppliers-$code', onTap: () => onKind('supplier')),
        if (currency.memberCents != 0)
          _Line(l10n.myBusinessMemberExpenses, money.formatMinor(currency.memberCents), valueKey: 'my-business-payable-members-$code', onTap: () => onKind('member')),
        if (currency.heldCents != 0)
          _Line(l10n.myBusinessHeld, money.formatMinor(currency.heldCents),
              valueKey: 'my-business-payable-held-$code'),
      ],
    );
  }
}

class _Currency extends StatelessWidget {
  const _Currency({required this.row, required this.onState});

  final BusinessReceivablesRow row;
  final ValueChanged<ReceivableState?> onState;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final money = personalFormatOf(context).moneyNamed(row.currency);
    String amount(int cents) => money.formatMinor(cents);
    final lines = <(String, int, String, ReceivableState)>[
      (l10n.myBusinessToCollect, row.toCollectCents, 'to-collect', ReceivableState.toCollect),
      (l10n.myBusinessDeclared, row.declaredCents, 'declared', ReceivableState.declared),
      (l10n.myBusinessReceived, row.receivedUnmatchedCents, 'received', ReceivableState.receivedUnmatched),
      (l10n.myBusinessAwaiting, row.awaitingCents, 'awaiting', ReceivableState.awaiting),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      key: ValueKey('my-business-currency-${row.currency}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${row.currency} · ${l10n.invoicingInvoiceCount(row.invoices)}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              Text(
                amount(row.receivableCents),
                key: ValueKey('my-business-owed-${row.currency}'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          Text(l10n.myBusinessStillOwed, style: Theme.of(context).textTheme.bodySmall),
          for (final (label, cents, key, state) in lines)
            if (cents != 0)
              _Line(label, amount(cents), valueKey: 'my-business-$key-${row.currency}',
                  onTap: () => onState(state)),
          if (row.refundDueCents != 0)
            _Line(
              l10n.myBusinessRefunds,
              amount(row.refundDueCents), valueKey: 'my-business-refund-${row.currency}',
              onTap: () => onState(ReceivableState.refundDue),
            ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {required this.valueKey, this.onTap});

  final String label;
  final String value;
  final String valueKey;

  /// Opens the rows behind this figure.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: ValueKey('$valueKey-rows'),
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, key: ValueKey(valueKey)),
        ],
      ),
    ),
  );
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.source, required this.onRetry});

  final BusinessReceivablesUnavailable source;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      key: ValueKey('my-business-unavailable-${source.workspaceId}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(source.name, style: Theme.of(context).textTheme.sectionTitle),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.myBusinessUnavailable),
            TextButton(
              key: ValueKey('my-business-retry-${source.workspaceId}'),
              onPressed: onRetry,
              child: Text(l10n.myBusinessRetry),
            ),
          ],
        ),
      ),
    );
  }
}
