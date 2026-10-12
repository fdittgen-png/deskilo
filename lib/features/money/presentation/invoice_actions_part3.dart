// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'invoice_actions.dart';


/// Runs what the detail sheet decided on, with the SCREEN's context — the
/// sheet is already gone by then.
Future<void> runInvoiceAction(
  BuildContext context,
  WidgetRef ref,
  InvoiceAction action,
  Invoice invoice, {
  required String countryCode,
}) {
  // #831 — a regrouped source is documentation: reading and the
  // stamped PDF stay, every operation happens on the settlement.
  if (invoice.isFolded &&
      action != InvoiceAction.quickView &&
      action != InvoiceAction.downloadPdf &&
      action != InvoiceAction.sharePdf) {
    final l10n = context.l10n;
    AppSnack.info(
      context,
      l10n.settlementDocumentationOnly,
      replace: true,
    );
    return Future.value();
  }
  return switch (action) {
    InvoiceAction.quickView => _quickViewInvoice(context, ref, invoice),
    InvoiceAction.downloadPdf => downloadInvoicePdf(context, ref, invoice),
    InvoiceAction.sharePdf => shareInvoicePdf(context, ref, invoice),
    InvoiceAction.eInvoice => _exportEInvoice(
      context,
      ref,
      invoice,
      countryCode: countryCode,
    ),
    InvoiceAction.remind => remindInvoice(context, ref, invoice),
    InvoiceAction.dunningHold => toggleDunningHold(context, ref, invoice),
    InvoiceAction.markPaid => matchInvoiceToPayment(context, ref, invoice),
    InvoiceAction.markErroneous => voidInvoiceWithConfirm(
      context,
      ref,
      invoice,
    ),
    InvoiceAction.replace => showInvoiceIssueSheet(
      context,
      ref,
      replaces: invoice,
    ),
  };
}

/// #837 — a regrouping invoice goes out either on its own or with the
/// invoices it replaced appended behind it, each stamped with where its
/// balance went. Asked at export time rather than settled once in a
/// setting, because the answer depends on who receives the document: a
/// member wants the detail, an accountant already has the originals.
///
/// Returns the invoices to append, empty for "this one alone", and null
/// when the question was dismissed — nothing should be exported then.
Future<List<Invoice>?> _askRegroupedAnnexes(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice,
) async {
  final sources = regroupedSourcesOf(ref, invoice);
  if (sources.isEmpty) return const [];
  final l10n = context.l10n;
  final include = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        l10n.settlementAnnexTitle,
      ),
      content: Text(
        l10n.settlementAnnexBody(sources.length),
      ),
      actions: [
        TextButton(
          key: const ValueKey('invoice-annex-alone'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.settlementAnnexAlone),
        ),
        FilledButton(
          key: const ValueKey('invoice-annex-with'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.settlementAnnexWith),
        ),
      ],
    ),
  );
  if (include == null) return null;
  return include ? sources : const [];
}
