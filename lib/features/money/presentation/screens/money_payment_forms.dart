// SPDX-License-Identifier: AGPL-3.0-or-later




import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter/material.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/bill_sections.dart';
import '../../domain/package.dart';
import '../../domain/payment_method.dart';
import '../../domain/price_negotiation.dart';
import '../../providers/money_providers.dart';
import '../payment_method_labels.dart';

/// What the record-payment sheet edits (#154, 0070): the amount, the note,
/// how the money moved, WHEN it moved (defaults to today) and WHICH month
/// it settles (defaults to the running one). The sheet closes with `true`
/// and the caller reads the draft — the draft outlives the sheet.
class MoneyPaymentDraft {
  MoneyPaymentDraft(this.today)
      : paidOn = DateTime(today.year, today.month, today.day),
        period = currentPeriod(today);

  final DateTime today;
  final TextEditingController amount = TextEditingController();
  final TextEditingController note = TextEditingController();

  /// null = not specified (kept valid so old habits keep working).
  PaymentMethod? method;
  DateTime paidOn;
  String period;

  /// A month back is history (settling arrears); a month forward is a
  /// prepayment. Further forward is a typo, not an intent.
  DateTime get periodCeiling => DateTime(today.year, today.month + 1);

  DateTime get periodMonth => monthOfPeriod(period);

  static DateTime monthOfPeriod(String p) => DateTime(
        int.parse(p.split('-')[0]),
        int.parse(p.split('-')[1]),
      );

  /// Moves the settled month by [delta], never past [periodCeiling].
  void shiftPeriod(int delta) {
    final next = DateTime(periodMonth.year, periodMonth.month + delta);
    if (next.isAfter(periodCeiling)) return;
    period = yearMonth(next.year, next.month);
  }
}

/// The record-payment sheet's content; its choices survive rebuilds in
/// [draft].
class RecordPaymentSheet extends StatefulWidget {
  const RecordPaymentSheet({
    super.key,
    required this.draft,
    required this.currency,
  });

  final MoneyPaymentDraft draft;
  final MoneyFormat currency;

  @override
  State<RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends State<RecordPaymentSheet> {
  MoneyPaymentDraft get _draft => widget.draft;
  late DateRead _paidOn = (date: _draft.paidOn, problem: null);
  bool _invalid = false;

  /// Submits only an amount above zero of the sheet's currency on a date
  /// the field could read; otherwise each field says what is wrong.
  void _submit() {
    final amount = appFormatOf(context)
        .readAmount(
          _draft.amount.text,
          currency: widget.currency.code,
          allowNegative: false,
        )
        .minor;
    if (amount == null || amount <= 0 || _paidOn.date == null) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SheetShell(
      title: l10n.moneyRecordPayment,
      children: [
        const SizedBox(height: 12),
        AppAmountField(
          key: const ValueKey('payment-amount'),
          controller: _draft.amount,
          label: l10n.moneyAmountLabel,
          currency: widget.currency.code,
          allowNegative: false,
          showProblem: _invalid,
          autofocus: true,
        ),
        const SizedBox(height: 12),
        _methodChips(l10n),
        const SizedBox(height: 4),
        _dateTile(context, l10n),
        _periodTile(context, l10n),
        const SizedBox(height: 4),
        TextField(
          controller: _draft.note,
          decoration: InputDecoration(
            labelText: l10n.moneyNoteLabel,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const ValueKey('money-submit-payment'),
          onPressed: _submit,
          child: Text(
            l10n.moneySubmitPayment,
          ),
        ),
      ],
    );
  }

  /// #154 — payment method chips (spec §7: amount + date + method + note).
  /// Tapping the selected chip deselects it.
  Widget _methodChips(AppLocalizations l10n) => Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          // displayOrder, not values: the enum is append-only (#192 added
          // methods after `other`), but the catch-all chip must stay last.
          for (final candidate in PaymentMethod.displayOrder)
            ChoiceChip(
              key: ValueKey('money-choice-chip-${candidate.name}'),
              label: Text(paymentMethodLabel(l10n, candidate)),
              selected: _draft.method == candidate,
              onSelected: (selected) => setState(
                () => _draft.method = selected ? candidate : null,
              ),
            ),
        ],
      );

  /// WHEN the money moved.
  Widget _dateTile(BuildContext context, AppLocalizations l10n) {
    final today = _draft.today;
    return AppDateField(
      key: const ValueKey('payment-date-tile'),
      label: l10n.moneyPaymentDateLabel,
      value: _paidOn.date,
      first: DateTime(today.year - 2),
      last: DateTime(today.year, today.month, today.day),
      pickerHelpText: l10n.moneyPaymentDateLabel,
      isRequired: true,
      showProblem: _invalid,
      onChanged: (read) => setState(() {
        _paidOn = read;
        if (read.date case final date?) _draft.paidOn = date;
      }),
    );
  }

  /// WHICH month it settles — the bill and the invoice this credit lands on.
  Widget _periodTile(BuildContext context, AppLocalizations l10n) {
    final today = _draft.today;
    return ListTile(
      key: const ValueKey('payment-period-tile'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.calendar_month_outlined),
      title: Text(l10n.moneyPaymentPeriodLabel),
      subtitle: Text(
        appFormatOf(context).dates(DateShape.monthYear).format(_draft.periodMonth),
        key: const ValueKey('payment-period-label'),
      ),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          tooltip: MaterialLocalizations.of(context).previousMonthTooltip,
          key: const ValueKey('payment-period-prev'),
          icon: const Icon(Icons.chevron_left),
          onPressed: () => setState(() => _draft.shiftPeriod(-1)),
        ),
        IconButton(
          tooltip: MaterialLocalizations.of(context).nextMonthTooltip,
          key: const ValueKey('payment-period-next'),
          icon: const Icon(Icons.chevron_right),
          onPressed:
              _draft.periodMonth.isAfter(DateTime(today.year, today.month))
                  ? null
                  : () => setState(() => _draft.shiftPeriod(1)),
        ),
      ]),
    );
  }
}

/// The extra-quota request sheet (0031): how many half-days, for [period].
class QuotaRequestSheet extends StatelessWidget {
  const QuotaRequestSheet({
    super.key,
    required this.count,
    required this.period,
  });

  final TextEditingController count;
  final String period;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SheetShell(
      title: l10n.quotaRequestTitle,
      children: [
        const SizedBox(height: 8),
        Text(
          l10n.quotaRequestExplainer(period),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('quota-request-count'),
          controller: count,
          decoration: InputDecoration(
            labelText: l10n.quotaRequestCountLabel,
          ),
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const ValueKey('money-submit-payment-2'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            l10n.moneySubmitPayment,
          ),
        ),
      ],
    );
  }
}

/// The package picker (0042): one card per owner-defined package, priced at
/// my negotiated [deal] when I have one (#744).
class BuyPackageSheet extends StatelessWidget {
  const BuyPackageSheet({
    super.key,
    required this.packages,
    required this.currency,
    required this.deal,
  });

  final List<Package> packages;
  final MoneyFormat currency;
  final NegotiationDeal? deal;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SheetShell(
      title: l10n.buyPackageTitle,
      children: [
        const SizedBox(height: 8),
        for (final package in packages)
          Card(
            child: ListTile(
              key: ValueKey('money-buy-package-days-${package.id}'),
              title: Text(package.name),
              subtitle: Text(
                l10n.buyPackageDays(package.days),
              ),
              trailing: Text(currency.formatMinor(
                  deal?.itemPrice('packages', package.id) ??
                      package.priceCents)),
              onTap: () => Navigator.of(context).pop(package),
            ),
          ),
      ],
    );
  }
}
