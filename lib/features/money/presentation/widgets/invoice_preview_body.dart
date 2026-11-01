// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/invoice.dart';
import '../../domain/invoice_line_text.dart';
import '../../domain/vat_rate.dart';
import '../report_strings_l10n.dart';

/// The derived positions of the issue form -- read-only by design (0062).
/// A preview that could not be read ([failed]) is unavailable: it is neither
/// an empty month nor a total.
class InvoicePreviewBody extends StatelessWidget {
  const InvoicePreviewBody({
    super.key,
    required this.memberPicked,
    required this.loading,
    required this.failed,
    required this.preview,
    required this.l10n,
    required this.currency,
    required this.association,
    required this.period,
  });

  final bool memberPicked;
  final bool loading;
  final bool failed;
  final ({List<InvoiceLine> lines, int totalCents})? preview;
  final AppLocalizations l10n;
  final MoneyFormat currency;
  final bool association;
  final String period;

  @override
  Widget build(BuildContext context) {
    final preview = this.preview;
    if (!memberPicked) {
      return _Note(l10n.invoicePickMember, 'invoice-pick-member', small: true);
    }
    if (failed && !loading) {
      return _Note(
        l10n.invoicePreviewUnavailable,
        'invoice-preview-unavailable',
      );
    }
    if (loading || preview == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: LoadingView(),
      );
    }
    if (preview.lines.isEmpty) {
      return _Note(l10n.invoiceNothingToInvoice, 'invoice-preview-empty');
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, line) in preview.lines.indexed) _lineRow(i, line),
        const Divider(),
        ..._vatRows(context, preview.lines),
        _totalRow(context, preview.totalCents),
      ],
    );
  }

  Widget _lineRow(int index, InvoiceLine line) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      key: ValueKey('invoice-preview-line-$index'),
      children: [
        Expanded(
          child: Text(
            invoiceLineText(
              reportStringsOf(l10n),
              line,
              association: association,
              period: period,
            ),
          ),
        ),
        Text(currency.formatMinor(line.amountCents)),
      ],
    ),
  );

  // The VAT the document will carry (0072) -- computed here exactly as the
  // server computes it at issue time. Only taxed rates are shown, so the zero
  // category never reaches the screen.
  List<Widget> _vatRows(BuildContext context, List<InvoiceLine> lines) {
    final hint = TextStyle(color: Theme.of(context).hintColor);
    return [
      for (final total in vatTotalsOf([
        for (final line in lines)
          (amountCents: line.amountCents, vatPercent: line.vatPercent),
      ], zeroCategory: 'O'))
        if (total.vatCents > 0)
          Padding(
            key: ValueKey('invoice-preview-vat-${total.percent}'),
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${l10n.vatPdfVat} '
                    '${total.percent == total.percent.roundToDouble() ? total.percent.toStringAsFixed(0) : total.percent} %',
                    style: hint,
                  ),
                ),
                Text(currency.formatMinor(total.vatCents), style: hint),
              ],
            ),
          ),
    ];
  }

  // 0063 -- the invoice nets consumptions against payments: the total IS the
  // balance due (solde).
  Widget _totalRow(BuildContext context, int totalCents) {
    final style = Theme.of(context).textTheme.titleSmall;
    return Row(
      key: const ValueKey('invoice-preview-total'),
      children: [
        Expanded(child: Text(l10n.invoiceBalance, style: style)),
        Text(currency.formatMinor(totalCents), style: style),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text, this.keyName, {this.small = false});

  final String text;
  final String keyName;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        key: ValueKey(keyName),
        textAlign: TextAlign.center,
        style: small ? textTheme.bodySmall : textTheme.bodyMedium,
      ),
    );
  }
}
