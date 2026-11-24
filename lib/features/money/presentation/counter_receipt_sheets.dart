// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4185 (CS2) -- the acts on a counter receipt, each its own form: a correction (a new receipt that credits the sale),
// money given back against a correction, goods taken back into stock against a correction, and the terminal's answer to
// a card authorization that was left open. Each sends under one request id per content, so a retry after a lost answer
// is answered by the act already made and never makes a second one; every bound the form checks is checked again by
// the server.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/i18n/format_controller.dart';
import '../../../core/ids/request_id.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/form_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/counter_book.dart';
import '../domain/till_quantity.dart';
import 'till_text.dart';

/// One request id per content of a form: the same content again (a retry) goes under the same id.
class _RequestIds {
  final Map<String, String> _ids = {};

  String of(String content) => _ids[content] ??= newRequestId();
}

/// Runs [act]; null when it went through, the refusal in words otherwise.
Future<String?> _run(AppLocalizations l10n, String what, Future<void> Function() act) async {
  try {
    await act();
    return null;
  } on Object catch (e, st) {
    TraceLogger.instance.error('money', 'counter $what refused', error: e, stackTrace: st);
    return tillProblemText(l10n, e);
  }
}

final _quantityChars = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];

String? _quantityError(AppLocalizations l10n, String typed, String left) => switch (counterQuantityCheck(typed, left)) {
  CounterQuantityCheck.invalid => l10n.counterSaleQuantityInvalid,
  CounterQuantityCheck.beyond => l10n.counterSaleAtMost(left),
  _ => null,
};

/// The lines of a correction or a return as typed: the ones with a quantity, each exact.
List<CounterBookQuantity> _typed(FormControllers fields, Iterable<CounterBookLine> lines) => [
  for (final l in lines)
    if (fields[l.id].text.trim().isNotEmpty) CounterBookQuantity(lineId: l.id, quantity: tillQuantityOf(fields[l.id].text) ?? fields[l.id].text.trim()),
];

/// A correction of [sale]: per line, the quantity to credit (never above what is left of it), and the reason. Answers
/// the number of the correction issued, or null when the sheet was closed.
Future<String?> showCounterCorrectSheet(
  BuildContext context, {
  required CounterBook book,
  required CounterBookReceipt sale,
  required Future<String> Function(String requestId, List<CounterBookQuantity> lines, String reason) correct,
}) async {
  final l10n = context.l10n;
  final open = [for (final l in sale.lines) if (counterQuantityUnits(book.leftOf(l)) > 0) l];
  final fields = FormControllers({for (final l in open) l.id: '', 'reason': ''});
  final ids = _RequestIds();
  String? number;
  final done = await showAppFormSheet(
    context,
    AppFormSheet(
      title: l10n.counterSaleCorrectTitle(sale.number),
      submitLabel: l10n.counterSaleCorrectSubmit,
      submitKey: const ValueKey('counter-correct-submit'),
      onDispose: fields.dispose,
      validate: () => {
        for (final l in open)
          l.id: ?_quantityError(l10n, fields[l.id].text, book.leftOf(l)),
      },
      onSubmit: () async {
        final lines = _typed(fields, open);
        if (lines.isEmpty) return l10n.counterSaleCorrectNothing;
        final reason = fields['reason'].text.trim();
        final content = '${[for (final l in lines) '${l.lineId}:${l.quantity}'].join(',')}|$reason';
        return _run(l10n, 'correction', () async => number = await correct(ids.of(content), lines, reason));
      },
      builder: (context, refresh) => [
        Text(l10n.counterSaleCorrectHint),
        const FormGap(),
        for (final l in open) ...[
          AppTextField(
            key: ValueKey('counter-correct-qty-${l.id}'),
            controller: fields[l.id],
            fieldKey: l.id,
            label: l10n.counterSaleCorrectLineLabel(l.label, '${book.leftOf(l)} ${l.unit}'.trim()),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: _quantityChars,
          ),
          const FormGap(),
        ],
        AppTextField(key: const ValueKey('counter-correct-reason'), controller: fields['reason'], label: l10n.counterSaleCorrectReason, maxLength: counterReasonMaxLength),
      ],
    ),
  );
  return done ? number : null;
}

/// Money given back against [correction]: an amount (never above what it still credits), in cash or another way.
Future<bool> showCounterRefundSheet(
  BuildContext context, {
  required CounterBookReceipt correction,
  required Future<void> Function(String requestId, CounterRefundPart part) refund,
  String? tillId,
}) {
  final l10n = context.l10n;
  final format = appFormatOf(context);
  final money = format.moneyIn(correction.currency);
  final left = correction.refundLeftMinor;
  final fields = FormControllers({'amount': ''});
  final ids = _RequestIds();
  var kind = 'cash';
  return showAppFormSheet(
    context,
    AppFormSheet(
      title: l10n.counterSaleRefundTitle(correction.number),
      submitLabel: l10n.counterSaleRefundSubmit,
      submitKey: const ValueKey('counter-refund-submit'),
      onDispose: fields.dispose,
      validate: () => switch (counterRefundCheck(format.parseMinor(fields['amount'].text), left)) {
        CounterRefundCheck.invalid => {'amount': l10n.counterSaleRefundInvalid},
        CounterRefundCheck.beyond => {'amount': l10n.counterSaleAtMost(money.formatMinor(left))},
        CounterRefundCheck.ok => const {},
      },
      onSubmit: () {
        final part = CounterRefundPart(kind: kind, amountMinor: format.parseMinor(fields['amount'].text)!, tillId: kind == 'cash' ? tillId : null);
        return _run(l10n, 'refund', () => refund(ids.of('${part.kind}:${part.amountMinor}'), part));
      },
      builder: (context, refresh) => [
        Text(l10n.counterSaleRefunded(money.formatMinor(correction.refundedMinor), money.formatMinor(correction.totalMinor))),
        const FormGap(),
        SegmentedButton<String>(
          key: const ValueKey('counter-refund-kind'),
          segments: [
            ButtonSegment(value: 'cash', label: Text(l10n.counterSaleTenderCash)),
            ButtonSegment(value: 'other', label: Text(l10n.counterSaleTenderOther)),
          ],
          selected: {kind},
          onSelectionChanged: (s) {
            kind = s.first;
            refresh();
          },
        ),
        const FormGap(),
        AppTextField(
          key: const ValueKey('counter-refund-amount'),
          controller: fields['amount'],
          fieldKey: 'amount',
          label: l10n.counterSaleRefundAmount(money.formatMinor(left)),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
      ],
    ),
  );
}

/// Goods of [correction] taken back into stock: per goods line, the quantity (never above what it still credits).
Future<bool> showCounterReturnSheet(
  BuildContext context, {
  required CounterBookReceipt correction,
  required Future<void> Function(String requestId, List<CounterBookQuantity> lines) takeBack,
}) {
  final l10n = context.l10n;
  final open = [for (final l in correction.lines) if (l.goods && counterQuantityUnits(correction.returnLeft(l)) > 0) l];
  final fields = FormControllers({for (final l in open) l.id: ''});
  final ids = _RequestIds();
  return showAppFormSheet(
    context,
    AppFormSheet(
      title: l10n.counterSaleReturnTitle(correction.number),
      submitLabel: l10n.counterSaleReturnSubmit,
      submitKey: const ValueKey('counter-return-submit'),
      onDispose: fields.dispose,
      validate: () => {
        for (final l in open)
          l.id: ?_quantityError(l10n, fields[l.id].text, correction.returnLeft(l)),
      },
      onSubmit: () {
        final lines = _typed(fields, open);
        if (lines.isEmpty) return Future.value(l10n.counterSaleCorrectNothing);
        return _run(l10n, 'return', () => takeBack(ids.of([for (final l in lines) '${l.lineId}:${l.quantity}'].join(',')), lines));
      },
      builder: (context, refresh) => [
        for (final l in open) ...[
          AppTextField(
            key: ValueKey('counter-return-qty-${l.id}'),
            controller: fields[l.id],
            fieldKey: l.id,
            label: l10n.counterSaleReturnLineLabel(l.label, '${correction.returnLeft(l)} ${l.unit}'.trim()),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: _quantityChars,
          ),
          const FormGap(),
        ],
      ],
    ),
  );
}

/// The terminal's answer to [tender], read from its journal by the tender's reference: accepted or declined, and,
/// while no answer was recorded at all, none. The reference the terminal printed is kept beside it.
Future<bool> showCounterTenderAnswerSheet(
  BuildContext context, {
  required CounterBookTender tender,
  required String currency,
  required Future<void> Function(String requestId, String outcome, String providerRef) resolve,
}) {
  final l10n = context.l10n;
  final money = appFormatOf(context).moneyIn(currency);
  final fields = FormControllers({'ref': ''});
  final ids = _RequestIds();
  var outcome = 'accepted';
  return showAppFormSheet(
    context,
    AppFormSheet(
      title: l10n.counterSaleRecordAnswer,
      submitLabel: l10n.counterSaleRecordAnswer,
      submitKey: const ValueKey('counter-answer-submit'),
      onDispose: fields.dispose,
      onSubmit: () {
        final ref = fields['ref'].text.trim();
        return _run(l10n, 'tender answer', () => resolve(ids.of('$outcome|$ref'), outcome, ref));
      },
      builder: (context, refresh) => [
        Text(l10n.counterSaleCardAskedTitle(money.formatMinor(tender.amountMinor))),
        Text(l10n.counterSaleReference(tender.providerKey)),
        const FormGap(),
        SegmentedButton<String>(
          key: const ValueKey('counter-answer-outcome'),
          segments: [
            ButtonSegment(value: 'accepted', label: Text(l10n.counterSaleCardAccepted)),
            ButtonSegment(value: 'refused', label: Text(l10n.counterSaleCardRefused)),
            if (tender.state == 'requested') ButtonSegment(value: 'unknown', label: Text(l10n.counterSaleCardNoAnswer)),
          ],
          selected: {outcome},
          onSelectionChanged: (s) {
            outcome = s.first;
            refresh();
          },
        ),
        const FormGap(),
        AppTextField(
          key: const ValueKey('counter-answer-ref'),
          controller: fields['ref'],
          label: l10n.counterSaleAnswerRefLabel,
          helper: l10n.counterSaleAnswerRefHint,
          maxLength: counterReasonMaxLength,
        ),
      ],
    ),
  );
}
