// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2380 — the person's decision on one movement: which invoice money in
// settles (the suggestions first, with why; then every other open invoice
// in its currency) and how a difference resolves; whether a movement that
// resembles another statement's is a duplicate; which payment reported as
// made a movement out reconciles.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/form_kit.dart';
import '../../domain/bank/bank_match.dart';
import '../../domain/bank/bank_records.dart';
import '../bank_labels.dart';

/// The invoice chosen for a movement, how an overpayment resolves, and
/// the note a difference needs.
typedef BankMatchChoice = ({
  OpenInvoice invoice,
  String overResolution,
  String note,
});

@visibleForTesting
class BankMatchDialog extends StatefulWidget {
  const BankMatchDialog({
    required this.line,
    required this.suggestions,
    required this.others,
    super.key,
  });

  final StoredBankLine line;
  final List<BankMatchSuggestion> suggestions;

  /// The other open invoices in the movement's currency.
  final List<OpenInvoice> others;

  @override
  State<BankMatchDialog> createState() => _BankMatchDialogState();
}

class _BankMatchDialogState extends State<BankMatchDialog> {
  final _note = TextEditingController();
  late String? _invoiceId = widget.suggestions.firstOrNull?.invoice.id;
  String _over = 'over_credit_note';
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  OpenInvoice? get _invoice {
    for (final i in [
      for (final s in widget.suggestions) s.invoice,
      ...widget.others,
    ]) {
      if (i.id == _invoiceId) return i;
    }
    return null;
  }

  void _submit() {
    final invoice = _invoice;
    if (invoice == null) return;
    final paid = widget.line.amountCents;
    final needsNote =
        paid < invoice.dueCents ||
        (paid > invoice.dueCents && _over == 'over_forced');
    if (needsNote && _note.text.trim().isEmpty) {
      setState(() => _error = context.l10n.invoiceMatchNoteRequired);
      return;
    }
    Navigator.of(context).pop<BankMatchChoice>((
      invoice: invoice,
      overResolution: _over,
      note: _note.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final money = moneyFormat(widget.line.currency);
    final invoice = _invoice;
    final paid = widget.line.amountCents;
    Widget option(OpenInvoice i, String? why) => RadioListTile<String>(
      key: ValueKey('bank-match-invoice-${i.id}'),
      value: i.id,
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text('${i.number} · ${money.formatMinor(i.dueCents)}'),
      subtitle: Text(why == null ? i.memberName : '${i.memberName} · $why'),
    );
    return AlertDialog(
      title: Text(l10n.bankMatchTitle(money.formatMinor(paid))),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.bankMatchPick, style: Theme.of(context).textTheme.bodySmall),
            if (widget.suggestions.isEmpty && widget.others.isEmpty)
              Text(l10n.bankMatchNoInvoice, key: const ValueKey('bank-match-none'))
            else
              RadioGroup<String>(
                key: const ValueKey('bank-match-invoice-group'),
                groupValue: _invoiceId,
                onChanged: (v) => setState(() {
                  _invoiceId = v;
                  _error = null;
                }),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final s in widget.suggestions)
                      option(s.invoice, bankMatchBasisLabel(l10n, s.basis)),
                    for (final i in widget.others) option(i, null),
                  ],
                ),
              ),
            if (invoice != null && paid > invoice.dueCents) ...[
              const FormGap.small(),
              Text(l10n.invoiceMatchOver(money.formatMinor(paid - invoice.dueCents))),
              RadioGroup<String>(
                key: const ValueKey('bank-match-over-group'),
                groupValue: _over,
                onChanged: (v) => setState(() => _over = v ?? _over),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<String>(
                      key: const ValueKey('bank-match-credit-note'),
                      value: 'over_credit_note',
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.invoiceMatchCreditNote),
                    ),
                    RadioListTile<String>(
                      key: const ValueKey('bank-match-force'),
                      value: 'over_forced',
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.invoiceMatchForce),
                    ),
                  ],
                ),
              ),
            ],
            if (invoice != null && paid < invoice.dueCents) ...[
              const FormGap.small(),
              Text(l10n.invoiceMatchUnder(money.formatMinor(invoice.dueCents - paid))),
            ],
            const FormGap.small(),
            AppTextField(
              key: const ValueKey('bank-match-note'),
              controller: _note,
              label: l10n.invoiceMatchNoteLabel,
              error: _error,
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('bank-match-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('bank-match-confirm'),
          onPressed: invoice == null ? null : _submit,
          child: Text(l10n.bankMatchConfirm),
        ),
      ],
    );
  }
}

/// Whether a movement that resembles another statement's is a duplicate
/// (true), a second genuine movement (false), or undecided (null).
Future<bool?> showBankReviewDialog(BuildContext context) => showDialog<bool>(
  context: context,
  builder: (context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.bankReviewTitle),
      content: Text(l10n.bankReviewBody),
      actions: [
        TextButton(
          key: const ValueKey('bank-review-duplicate'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.bankReviewDuplicate),
        ),
        FilledButton(
          key: const ValueKey('bank-review-keep'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.bankReviewKeep),
        ),
      ],
    );
  },
);

/// The reported payment a movement out reconciles; null when none is
/// chosen.
Future<String?> showBankOutDialog(BuildContext context, StoredBankLine line) =>
    showDialog<String>(
      context: context,
      builder: (_) => _BankOutDialog(line: line),
    );

class _BankOutDialog extends StatefulWidget {
  const _BankOutDialog({required this.line});

  final StoredBankLine line;

  @override
  State<_BankOutDialog> createState() => _BankOutDialogState();
}

class _BankOutDialogState extends State<_BankOutDialog> {
  late String? _id = widget.line.outgoingCandidates.length == 1
      ? widget.line.outgoingCandidates.single.id
      : null;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final money = moneyFormat(widget.line.currency);
    final day = DateFormat.yMMMd(Localizations.localeOf(context).toString());
    final candidates = widget.line.outgoingCandidates;
    return AlertDialog(
      title: Text(l10n.bankOutTitle),
      content: SingleChildScrollView(
        child: candidates.isEmpty
            ? Text(l10n.bankOutNone, key: const ValueKey('bank-out-none'))
            : RadioGroup<String>(
                key: const ValueKey('bank-out-group'),
                groupValue: _id,
                onChanged: (v) => setState(() => _id = v),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final c in candidates)
                      RadioListTile<String>(
                        key: ValueKey('bank-out-${c.id}'),
                        value: c.id,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${c.payee} · ${money.formatMinor(c.amountCents)}'),
                        subtitle: Text(
                          c.reference.isEmpty
                              ? day.format(c.paidOn)
                              : '${day.format(c.paidOn)} · ${c.reference}',
                        ),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('bank-out-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('bank-out-confirm'),
          onPressed: _id == null ? null : () => Navigator.of(context).pop(_id),
          child: Text(l10n.bankMatchConfirm),
        ),
      ],
    );
  }
}
