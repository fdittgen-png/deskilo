// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'invoice_actions.dart';


/// #504 — asks the validators to CANCEL the outstanding remainder of a
/// partially paid invoice. Explains that this is a request, takes an
/// optional reason, files the pending 'invoice_writeoff' event.
Future<void> requestInvoiceWriteoffDialog(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice,
) async {
  final l10n = context.l10n;
  final reasonController = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.invoiceWriteoffButton),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.invoiceWriteoffExplain,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey('invoice-writeoff-reason'),
            controller: reasonController,
            maxLength: 300,
            maxLines: 2,
            decoration: InputDecoration(
              labelText:
                  l10n.reservationDeleteReasonLabel,
              counterText: '',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('invoice-actions-cancel-2'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('invoice-writeoff-submit'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.reservationDeleteSubmit),
        ),
      ],
    ),
  );
  final reason = reasonController.text;
  if (confirmed != true || !context.mounted) return;
  if (!await runGuarded(
    context,
    domain: 'money',
    message: 'invoice writeoff request failed',
    errorText:
        l10n.workspaceGenericError,
    action: () => ref
        .read(eventRepositoryProvider)
        .requestInvoiceWriteoff(invoice.id, reason: reason),
  )) {
    return;
  }
  ref.invalidate(eventsProvider);
  invalidateBookingData(ref);
  if (!context.mounted) return;
  AppSnack.success(
    context,
    l10n.invoiceWriteoffRequested,
  );
}

/// SENDS the invoice: builds the document in the syntax the channel
/// wants (#2358 — XML for a network, Factur-X for a person) and posts it
/// to the workspace's platform through the edge function, which holds the
/// credential and records the attempt (0073). The document that leaves is
/// built by the same builder as the download — no second truth.
Future<void> sendEInvoice(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice, {
  required InvoiceParty seller,
  required InvoiceParty buyer,
  required String iban,
  required String workspaceId,
  String environment = 'prod',
  String destination = 'government',
  String provider = 'generic',
}) async {
  final l10n = context.l10n;
  EInvoiceSubmission? result;
  final format = eInvoiceFormatFor(
    provider: provider,
    destination: destination,
    buyerEndpointScheme: buyer.endpointScheme,
  );
  if (!await runGuarded(
    context,
    domain: 'money',
    message: 'e-invoice submission failed',
    errorText:
        l10n.workspaceGenericError,
    action: () async {
      final ({List<int> bytes, String fileName}) file;
      if (format == EInvoiceFormat.facturX) {
        file = await buildFacturXFile(
          context,
          ref,
          invoice,
          seller: seller,
          buyer: buyer,
          iban: iban,
        );
      } else {
        // #2358 — the network's own syntax, from the inputs the
        // download uses.
        final words = reportStringsOf(l10n);
        final association = ref.read(sellerIsAssociationProvider);
        final xml = buildChannelEInvoiceXml(format, EInvoiceInput(
          invoice: invoice, seller: seller, buyer: buyer, iban: iban,
          lineText: (line) => invoiceLineText(words, line,
              association: association, period: invoice.period),
          dueDate: invoiceDueAt(ref, invoice),
          paymentTerms: invoice.legalClauses?.clauses.paymentTerms ??
              memberTermsFor(ref, invoice.memberId)?.paymentTerms ??
              '',
        ));
        file = (
          bytes: utf8.encode(xml),
          fileName: '${safeFileSlug('${format.name} ${invoice.number}')}.xml',
        );
      }
      if (file.fileName.isEmpty) return;
      result = await ref
          .read(moneyRepositoryProvider)
          .sendEInvoice(
            workspaceId: workspaceId,
            invoiceId: invoice.id,
            fileName: file.fileName,
            mimeType: format.mimeType,
            bytes: file.bytes,
            environment: environment,
            destination: destination,
            format: format.name,
            receiverScheme: buyer.endpointScheme,
            receiverId: buyer.endpointId,
          );
    },
  )) {
    return;
  }
  ref.invalidate(invoiceTransmissionsProvider);
  if (!context.mounted) return;
  final submission = result;
  if (submission == null) return;
  if (submission.accepted) {
    AppSnack.success(
      context,
      environment != 'prod'
          ? (l10n.invoiceSendAcceptedTest(environment.toUpperCase()))
          : destination == 'customer'
          ? (l10n.invoiceSendCustomerAccepted)
          : (l10n.invoiceSendAccepted),
    );
    return;
  }
  // The platform's own words beat a generic failure: they are what the
  // owner has to act on.
  AppSnack.error(
    context,
    submission.detail.isEmpty
        ? (l10n.invoiceSendRejected)
        : '${l10n.invoiceSendRejected} '
              '${submission.detail}',
  );
}

/// Saves [bytes] to Downloads and reports where they landed.
/// Saves [bytes] into the device Downloads and reports the path — the
/// shared "download, don't just share" path (#474).
Future<void> savePdfToDownloads(
  BuildContext context,
  WidgetRef ref, {
  required Uint8List bytes,
  required String fileName,
}) async {
  final l10n = context.l10n;
  final path = await ref.read(fileSaverProvider)(
    bytes: bytes,
    fileName: fileName,
  );
  if (!context.mounted) return;
  if (path == null) {
    AppSnack.error(context, l10n.commonSaveFailed);
  } else {
    AppSnack.success(context, l10n.commonSavedTo(path));
  }
}

Future<void> downloadInvoicePdf(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice,
) async {
  final l10n = context.l10n;
  final annexes = await _askRegroupedAnnexes(context, ref, invoice);
  if (annexes == null || !context.mounted) return;
  await runGuarded(
    context,
    domain: 'money',
    message: 'invoice download failed',
    errorText:
        l10n.workspaceGenericError,
    action: () async {
      final pdf = await buildInvoicePdfFile(
        context,
        invoice,
        memberTerms: memberTermsFor(ref, invoice.memberId),
        dueAt: invoiceDueAt(ref, invoice),
        copy: rendersCopy(ref),
        settledIn: settledStampOf(context, ref, invoice),
        annexInvoices: annexes,
        template: invoicePdfTemplateFor(ref),
        workspace: ref.read(currentWorkspaceProvider).value,
        // #920 — through layoutImage, so the shipped layouts' `logo`
    // resolves to whatever the owner actually called theirs.
    reportImage: (name) => layoutImage(ref, name),
      );
      if (!context.mounted) return;
      await savePdfToDownloads(
        context,
        ref,
        bytes: Uint8List.fromList(pdf.bytes),
        fileName: pdf.fileName,
      );
    },
  );
}

/// #514 — see the rendered invoice ON SCREEN before any PDF exists.
/// Renders through the workspace template; an uncustomized template
/// falls back to the default bands so the quick view always works.
Future<void> _quickViewInvoice(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice, {
  bool proforma = false,
}) async {
  final l10n = context.l10n;
  final annexes = await _askRegroupedAnnexes(context, ref, invoice);
  if (annexes == null || !context.mounted) return;
  final template = invoicePdfTemplateFor(ref);
  final data = withOwnerTexts(
    invoiceReportData(
      reportStringsFor(context),
      invoice,
      memberTerms: memberTermsFor(ref, invoice.memberId),
      proforma: proforma,
      copy: rendersCopy(ref),
      workspace: ref.read(currentWorkspaceProvider).value,
    ),
    template.texts,
  );
  var bands = proforma
      ? (template.proformaBands ?? template.invoiceBands)
      : template.invoiceBands;
  if (!bands.hasBands) bands = defaultBandsForDoc('invoice', l10n);
  final report = renderReportBands(bands: bands, data: data);
  if (report == null) {
    AppSnack.error(
      context,
      l10n.workspaceGenericError,
    );
    return;
  }
  // #837 — the regrouped invoices as further sheets, same stamp as the
  // PDF, each below the one before it.
  final stamp =
      l10n.invoicePdfSettledIn(invoice.number);
  final annexReports = <QuickPreviewAnnex>[];
  for (final source in annexes) {
    final sourceReport = renderReportBands(
      bands: bands,
      data: withOwnerTexts(
        invoiceReportData(
          reportStringsFor(context),
          source,
          memberTerms: memberTermsFor(ref, source.memberId),
          proforma: false,
          copy: rendersCopy(ref),
          workspace: ref.read(currentWorkspaceProvider).value,
        ),
        template.texts,
      ),
    );
    if (sourceReport != null) {
      annexReports.add((report: sourceReport, stamp: stamp));
    }
  }
  final images = await resolveReportImages(ref, report);
  if (!context.mounted) return;
  await showReportQuickPreview(
    context,
    annexes: annexReports,
    report: report,
    simulated: false,
    images: images,
  );
}

Future<void> shareInvoicePdf(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice,
) async {
  final l10n = context.l10n;
  final annexes = await _askRegroupedAnnexes(context, ref, invoice);
  if (annexes == null || !context.mounted) return;
  await runGuarded(
    context,
    domain: 'money',
    message: 'invoice share failed',
    errorText:
        l10n.workspaceGenericError,
    action: () async {
      final pdf = await buildInvoicePdfFile(
        context,
        invoice,
        memberTerms: memberTermsFor(ref, invoice.memberId),
        dueAt: invoiceDueAt(ref, invoice),
        copy: rendersCopy(ref),
        settledIn: settledStampOf(context, ref, invoice),
        annexInvoices: annexes,
        template: invoicePdfTemplateFor(ref),
        workspace: ref.read(currentWorkspaceProvider).value,
        // #920 — through layoutImage, so the shipped layouts' `logo`
    // resolves to whatever the owner actually called theirs.
    reportImage: (name) => layoutImage(ref, name),
      );
      await ref.read(fileSharerProvider)(
        bytes: Uint8List.fromList(pdf.bytes),
        fileName: pdf.fileName,
        mimeType: 'application/pdf',
      );
    },
  );
}

/// Tags [invoice] erroneous (0061) after an explicit confirm — the stamp is
/// one-way, so the dialog says so.
Future<void> voidInvoiceWithConfirm(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice,
) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.invoiceVoidAction),
      content: Text(
        l10n.invoiceVoidConfirm(invoice.number),
      ),
      actions: [
        TextButton(
          key: const ValueKey('invoice-actions-cancel-3'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('invoice-void-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.invoiceVoidAction),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  if (!await runGuarded(
    context,
    domain: 'money',
    message: 'invoice void failed',
    errorText:
        l10n.workspaceGenericError,
    action: () => ref.read(moneyRepositoryProvider).voidInvoice(invoice.id),
  )) {
    return;
  }
  ref.invalidate(invoicesProvider);
  if (!context.mounted) return;
  AppSnack.success(
    context,
    l10n.invoiceVoided,
  );
}
