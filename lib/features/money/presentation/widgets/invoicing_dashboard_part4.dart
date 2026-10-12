// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'invoicing_dashboard.dart';


class _MatchInvoiceDialogState extends State<MatchInvoiceDialog> {
  final _note = TextEditingController();
  String? _paymentId;
  String _overResolution = 'over_credit_note';
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  LedgerEntry? get _payment => widget.payments
      .where((entry) => entry.id == _paymentId)
      .firstOrNull;

  void _submit() {
    final l10n = context.l10n;
    final payment = _payment;
    if (payment == null) return;
    final paid = payment.amountCents;
    final resolution = paid == widget.dueCents
        ? 'exact'
        : paid > widget.dueCents
            ? _overResolution
            : 'under_accepted';
    final noteRequired =
        resolution == 'over_forced' || resolution == 'under_accepted';
    if (noteRequired && _note.text.trim().isEmpty) {
      setState(() =>
          _error = l10n.invoiceMatchNoteRequired);
      return;
    }
    Navigator.of(context).pop<MatchChoice>((
      paymentLedgerId: payment.id,
      resolution: resolution,
      note: _note.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dateFormat = DateFormat.yMMMd(
      Localizations.maybeLocaleOf(context)?.toString(),
    );
    final payment = _payment;
    final paid = payment?.amountCents;
    final over = paid != null && paid > widget.dueCents;
    final under = paid != null && paid < widget.dueCents;
    return AlertDialog(
      title: Text(l10n.invoiceMatchAction),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.invoiceMatchPickPayment,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (widget.payments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  l10n.invoiceMatchNoPayments,
                  key: const ValueKey('invoice-match-no-payments'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else
              RadioGroup<String>(
                key: const ValueKey('invoicing-dashboard-radio-group'),
                groupValue: _paymentId,
                onChanged: (value) => setState(() {
                  _paymentId = value;
                  _error = null;
                }),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final entry in widget.payments)
                      RadioListTile<String>(
                        key: ValueKey('invoice-match-payment-${entry.id}'),
                        value: entry.id,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          '${widget.currency.formatMinor(entry.amountCents)}'
                          ' · ${dateFormat.format(entry.on)}'
                          '${entry.description.isEmpty ? '' : ' · ${entry.description}'}',
                        ),
                      ),
                  ],
                ),
              ),
            if (over) ...[
              const SizedBox(height: 8),
              Text(
                l10n.invoiceMatchOver(widget.currency
                        .formatMinor(paid - widget.dueCents)),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              RadioGroup<String>(
                key: const ValueKey('invoicing-dashboard-invoice-match-credit-note'),
                groupValue: _overResolution,
                onChanged: (v) =>
                    setState(() => _overResolution = v ?? _overResolution),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  RadioListTile<String>(
                    key: const ValueKey('invoice-match-credit-note'),
                    value: 'over_credit_note',
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.invoiceMatchCreditNote),
                  ),
                  RadioListTile<String>(
                    key: const ValueKey('invoice-match-force'),
                    value: 'over_forced',
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.invoiceMatchForce),
                  ),
                ]),
              ),
            ],
            if (under) ...[
              const SizedBox(height: 8),
              Text(
                l10n.invoiceMatchUnder(widget.currency
                        .formatMinor(widget.dueCents - paid)),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('invoice-match-note'),
              controller: _note,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: l10n.invoiceMatchNoteLabel,
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('invoicing-dashboard-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('invoice-match-confirm'),
          onPressed: payment == null ? null : _submit,
          child: Text(l10n.invoiceMatchAction),
        ),
      ],
    );
  }
}
