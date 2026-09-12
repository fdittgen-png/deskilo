// SPDX-License-Identifier: 0BSD
import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:typed_data';
import '../../../core/i18n/money_format.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/files/file_names.dart';
import '../../../core/files/file_saver.dart';
import '../../../core/share/file_sharer.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/app_snack.dart';
import '../../../l10n/app_localizations.dart';
import '../../events/providers/event_providers.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/e_invoice_routing.dart';
import '../domain/invoice.dart';
import '../domain/einvoice_gateway.dart';
import '../domain/invoice_ubl.dart';
import '../domain/invoice_ubl_check.dart';
import '../domain/ledger_entry.dart';
import '../domain/invoice_pdf_template.dart';
import '../domain/dunning.dart';
import '../domain/invoice_report.dart';
import 'report_layout_actions.dart';
import '../providers/money_providers.dart';
import 'report_defaults.dart';
import 'widgets/report_preview.dart';
import 'e_invoice_identity.dart';
import 'widgets/einvoice_environment_picker.dart';
import '../domain/invoice_line_text.dart';
import '../domain/report_data.dart';
import 'invoice_documents.dart';
import 'report_strings_l10n.dart';
import 'period_label.dart';
import 'widgets/e_invoice_sheet.dart';
import 'widgets/invoice_detail_sheet.dart';
import 'widgets/invoice_form_sheet.dart';
import 'widgets/invoicing_dashboard.dart';
import '../../../core/theme/app_spacing.dart';

/// Everything an issued invoice can be PUT THROUGH, extracted out of the
/// screen (0069): the archive rows, the open cards and the detail sheet all
/// drive the same code, so an action cannot behave differently depending on
/// where it was tapped.

/// #508 — records the REFUND the workspace paid on a NEGATIVE invoice
/// (a credit note / avoir): books the payout charge and closes the
/// document — through the invoice_payment validation policy when one
/// is configured.
Future<void> settleCreditInvoiceDialog(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice,
) async {
  final l10n = AppLocalizations.of(context);
  final currency = moneyFormat(invoice.currency);
  final noteController = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n?.invoiceRefundButton ?? 'Record the refund'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.invoiceRefundExplain(
                  currency.formatMinor(-invoice.totalCents),
                ) ??
                'This credit note means the WORKSPACE owes the member '
                    '${currency.formatMinor(-invoice.totalCents)}. '
                    'Record that the refund was paid out — the amount is '
                    'booked against the member\'s balance and the '
                    'document closes as Refunded.',
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey('invoice-refund-note'),
            controller: noteController,
            maxLength: 300,
            maxLines: 2,
            decoration: InputDecoration(
              labelText:
                  l10n?.reservationDeleteReasonLabel ?? 'Reason (optional)',
              counterText: '',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
        FilledButton(
          key: const ValueKey('invoice-refund-submit'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n?.invoiceRefundButton ?? 'Record the refund'),
        ),
      ],
    ),
  );
  final note = noteController.text;
  if (confirmed != true || !context.mounted) return;
  if (!await runGuarded(
    context,
    domain: 'money',
    message: 'credit note refund failed',
    errorText:
        l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () => ref
        .read(moneyRepositoryProvider)
        .settleCreditInvoice(invoice.id, note: note),
  )) {
    return;
  }
  ref.invalidate(invoiceMatchesProvider);
  ref.invalidate(myAccountProvider);
  ref.invalidate(invoicesProvider);
  invalidateBookingData(ref);
  if (!context.mounted) return;
  AppSnack.success(context, l10n?.invoiceRefunded ?? 'Refund recorded.');
}

/// #504 — asks the validators to CANCEL the outstanding remainder of a
/// partially paid invoice. Explains that this is a request, takes an
/// optional reason, files the pending 'invoice_writeoff' event.
Future<void> requestInvoiceWriteoffDialog(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice,
) async {
  final l10n = AppLocalizations.of(context);
  final reasonController = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n?.invoiceWriteoffButton ?? 'Cancel outstanding amount'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.invoiceWriteoffExplain ??
                'The unpaid remainder of this invoice will be cancelled '
                    'and the invoice archived as partially paid — once '
                    'the validators confirm. Until then it stays open '
                    'and owed.',
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey('invoice-writeoff-reason'),
            controller: reasonController,
            maxLength: 300,
            maxLines: 2,
            decoration: InputDecoration(
              labelText:
                  l10n?.reservationDeleteReasonLabel ?? 'Reason (optional)',
              counterText: '',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
        FilledButton(
          key: const ValueKey('invoice-writeoff-submit'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n?.reservationDeleteSubmit ?? 'Send request'),
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
        l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
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
    l10n?.invoiceWriteoffRequested ??
        'Write-off requested — awaiting validation.',
  );
}

/// SENDS the invoice: builds the Factur-X document and posts it to the
/// workspace's platform through the edge function, which holds the
/// credential and records the attempt (0073). The document that leaves is
/// byte-for-byte the one the download produces — one builder, no second
/// truth.
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
}) async {
  final l10n = AppLocalizations.of(context);
  EInvoiceSubmission? result;
  if (!await runGuarded(
    context,
    domain: 'money',
    message: 'e-invoice submission failed',
    errorText:
        l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () async {
      final file = await buildFacturXFile(
        context,
        ref,
        invoice,
        seller: seller,
        buyer: buyer,
        iban: iban,
      );
      if (file.fileName.isEmpty) return;
      result = await ref
          .read(moneyRepositoryProvider)
          .sendEInvoice(
            workspaceId: workspaceId,
            invoiceId: invoice.id,
            fileName: file.fileName,
            mimeType: 'application/pdf',
            bytes: file.bytes,
            environment: environment,
            destination: destination,
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
          ? (l10n?.invoiceSendAcceptedTest(environment.toUpperCase()) ??
                'Test send accepted (${environment.toUpperCase()}).')
          : destination == 'customer'
          ? (l10n?.invoiceSendCustomerAccepted ??
                "Sent — the customer's service accepted it.")
          : (l10n?.invoiceSendAccepted ?? 'Sent — the platform accepted it.'),
    );
    return;
  }
  // The platform's own words beat a generic failure: they are what the
  // owner has to act on.
  AppSnack.error(
    context,
    submission.detail.isEmpty
        ? (l10n?.invoiceSendRejected ?? 'The platform refused it.')
        : '${l10n?.invoiceSendRejected ?? 'The platform refused it.'} '
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
  final l10n = AppLocalizations.of(context);
  final path = await ref.read(fileSaverProvider)(
    bytes: bytes,
    fileName: fileName,
  );
  if (!context.mounted) return;
  if (path == null) {
    AppSnack.error(context, l10n?.commonSaveFailed ?? 'Could not save.');
  } else {
    AppSnack.success(context, l10n?.commonSavedTo(path) ?? 'Saved to $path');
  }
}

Future<void> downloadInvoicePdf(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice,
) async {
  final l10n = AppLocalizations.of(context);
  final annexes = await askRegroupedAnnexes(context, ref, invoice);
  if (annexes == null || !context.mounted) return;
  await runGuarded(
    context,
    domain: 'money',
    message: 'invoice download failed',
    errorText:
        l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
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
Future<void> quickViewInvoice(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice, {
  bool proforma = false,
}) async {
  final l10n = AppLocalizations.of(context);
  final annexes = await askRegroupedAnnexes(context, ref, invoice);
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
      l10n?.workspaceGenericError ?? 'Something went wrong. Please try again.',
    );
    return;
  }
  // #837 — the regrouped invoices as further sheets, same stamp as the
  // PDF, each below the one before it.
  final stamp =
      l10n?.invoicePdfSettledIn(invoice.number) ??
      'Regrouped in ${invoice.number}';
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
  final l10n = AppLocalizations.of(context);
  final annexes = await askRegroupedAnnexes(context, ref, invoice);
  if (annexes == null || !context.mounted) return;
  await runGuarded(
    context,
    domain: 'money',
    message: 'invoice share failed',
    errorText:
        l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
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
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n?.invoiceVoidAction ?? 'Mark erroneous'),
      content: Text(
        l10n?.invoiceVoidConfirm(invoice.number) ??
            'Mark invoice ${invoice.number} as erroneous? '
                'This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
        FilledButton(
          key: const ValueKey('invoice-void-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n?.invoiceVoidAction ?? 'Mark erroneous'),
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
        l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () => ref.read(moneyRepositoryProvider).voidInvoice(invoice.id),
  )) {
    return;
  }
  ref.invalidate(invoicesProvider);
  if (!context.mounted) return;
  AppSnack.success(
    context,
    l10n?.invoiceVoided ?? 'Invoice marked as erroneous.',
  );
}

Future<void> remindInvoice(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice,
) async {
  final l10n = AppLocalizations.of(context);
  final currency = moneyFormat(invoice.currency);
  final message =
      l10n?.invoiceReminderMessage(
        invoice.number,
        currency.formatMinor(invoice.totalCents),
      ) ??
      'Friendly reminder: invoice ${invoice.number} — balance due '
          '${currency.formatMinor(invoice.totalCents)}.';
  // #472: the level of THIS send — one past what was already sent,
  // capped at the configured maximum (extra sends reuse the last
  // letter).
  final rules = ref.read(dunningRulesProvider).value ?? DunningRules.defaults;
  final sent =
      ref.read(invoiceRemindersProvider).value?[invoice.id]?.count ?? 0;
  final level = (sent + 1).clamp(1, rules.levels);
  if (!await runGuarded(
    context,
    domain: 'money',
    message: 'invoice reminder failed',
    errorText:
        l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () async {
      // PDF first — it captures its context-derived values before any
      // await (use_build_context_synchronously).
      final pdf = await buildReminderPdfFile(
        context,
        ref,
        invoice,
        level: level,
      );
      await ref.read(moneyRepositoryProvider).remindInvoice(invoice.id);
      await ref.read(fileSharerProvider)(
        bytes: Uint8List.fromList(pdf.bytes),
        fileName: pdf.fileName,
        mimeType: 'application/pdf',
        text: message,
      );
    },
  )) {
    return;
  }
  ref.invalidate(invoiceRemindersProvider);
  if (!context.mounted) return;
  AppSnack.success(context, l10n?.invoiceReminded ?? 'Reminder recorded.');
}

/// EN 16931 e-invoice (0066/0069): the sheet first — WHERE the file has to
/// go in this country, and whether it would be ACCEPTED at all — then the
/// UBL 2.1 XML to Downloads or the share sheet.
Future<void> exportEInvoice(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice, {
  required String countryCode,
}) async {
  final association = ref.read(sellerIsAssociationProvider);
  final route = eInvoiceRouteFor(countryCode);
  final workspace = ref.read(currentWorkspaceProvider).value;
  if (route == null || workspace == null) return;
  // The invoice's own snapshot, or the live workspace identity for
  // pre-0069 documents (see sellerOf).
  final seller = sellerOf(invoice, workspace);
  final buyer = buyerOf(invoice, workspace);
  final readiness = checkEInvoiceReadiness(
    invoice: invoice,
    seller: seller,
    buyer: buyer,
    // #922 — the sheet's default leg is the government platform; the
    // public-sector references are asked for there, as a warning.
    destination: 'government',
  );
  // The same judgement against the LIVE identity: if that one passes, the
  // owner is not missing anything — the document is simply older than the
  // identity, and only a replacement can carry the new one.
  final identityFixedSince =
      invoice.sellerParty != null &&
      !readiness.ready &&
      checkEInvoiceReadiness(
        invoice: invoice,
        seller: workspaceParty(workspace),
        buyer: buyer,
      ).ready;
  final me = ref.read(myMemberProvider).value;
  // AWAIT the probe: a cached `.value` is null on the first open, which
  // would hide the Send button exactly when it is most wanted.
  EInvoiceGatewayConfig gateway;
  try {
    gateway = await ref.read(eInvoiceGatewayProvider.future);
  } catch (e, st) {
    TraceLogger.instance.warn(
      'money',
      'e-invoice gateway probe failed',
      error: e,
      stackTrace: st,
    );
    gateway = EInvoiceGatewayConfig.notConfigured;
  }
  if (!context.mounted) return;
  final isIssuer = me?.actsAsOwner == true || me?.canAdminister == true;
  final export = await showEInvoiceSheet(
    context,
    route: route,
    readiness: readiness,
    canFixIdentity: me?.actsAsOwner ?? false,
    identityFixedSince: identityFixedSince,
    // Only an issuer sends, and only when a platform is configured.
    canSend: gateway.configured && isIssuer,
    // The customer leg (#568): its own endpoint, its own flag, the same
    // issuer gate.
    canSendCustomer:
        gateway.customerConfigured &&
        isIssuer &&
        ref
            .read(enabledFeaturesSyncProvider)
            .contains(WorkspaceFeature.einvoiceCustomerDelivery),
  );
  if (export == null || !context.mounted) return;
  if (export == EInvoiceExport.fixIdentity) {
    unawaited(context.push('/legal-identity'));
    return;
  }
  final l10nForFile = AppLocalizations.of(context);
  if (export == EInvoiceExport.send || export == EInvoiceExport.sendCustomer) {
    final toCustomer = export == EInvoiceExport.sendCustomer;
    // Dev mode + a configured test platform → choose the target (#393);
    // anyone else goes straight to production, no extra tap. The picker
    // judges the DESTINATION's environments (#568).
    final envGateway = toCustomer
        ? EInvoiceGatewayConfig(
            configured: true,
            environments:
                gateway.destinations['customer']?.environments ?? const {},
          )
        : gateway;
    final environment = await pickEInvoiceEnvironment(
      context,
      ref,
      gateway: envGateway,
    );
    if (environment == null || !context.mounted) return;
    await sendEInvoice(
      context,
      ref,
      invoice,
      seller: seller,
      buyer: buyer,
      iban: workspaceIban(workspace),
      workspaceId: workspace.id,
      environment: environment,
      destination: toCustomer ? 'customer' : 'government',
    );
    return;
  }
  if (export == EInvoiceExport.facturXDownload ||
      export == EInvoiceExport.facturXShare) {
    await runGuarded(
      context,
      domain: 'money',
      message: 'factur-x export failed',
      errorText:
          l10nForFile?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
        final file = await buildFacturXFile(
          context,
          ref,
          invoice,
          seller: seller,
          buyer: buyer,
          iban: workspaceIban(workspace),
        );
        if (file.fileName.isEmpty) return;
        final bytes = Uint8List.fromList(file.bytes);
        if (export == EInvoiceExport.facturXShare) {
          await ref.read(fileSharerProvider)(
            bytes: bytes,
            fileName: file.fileName,
            mimeType: 'application/pdf',
          );
          return;
        }
        if (!context.mounted) return;
        await savePdfToDownloads(
          context,
          ref,
          bytes: bytes,
          fileName: file.fileName,
        );
      },
    );
    return;
  }
  final l10n = AppLocalizations.of(context);
  final words = reportStringsOf(l10n);
  await runGuarded(
    context,
    domain: 'money',
    message: 'e-invoice export failed',
    errorText:
        l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () async {
      final xml = buildInvoiceUbl(
        invoice: invoice,
        seller: seller,
        buyer: buyer,
        iban: workspaceIban(workspace),
        lineText: (line) => invoiceLineText(words, line,
            association: association, period: invoice.period),
      );
      final bytes = Uint8List.fromList(utf8.encode(xml));
      final fileName = '${safeFileSlug(invoice.number)}.xml';
      if (export == EInvoiceExport.share) {
        await ref.read(fileSharerProvider)(
          bytes: bytes,
          fileName: fileName,
          mimeType: 'application/xml',
        );
        return;
      }
      if (!context.mounted) return;
      await savePdfToDownloads(context, ref, bytes: bytes, fileName: fileName);
    },
  );
}

/// Matches an open invoice to its payment (0067) — the only way an invoice
/// closes and archives. Over/under payments resolve in the dialog; the
/// server re-validates and files the invoice_payment event (pending when a
/// validation rule exists).
Future<void> matchInvoiceToPayment(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice,
) async {
  final l10n = AppLocalizations.of(context);
  final currency = moneyFormat(invoice.currency);
  // 0068 — the candidates: the member's registered payments (incl. settled
  // online payments) not yet consumed by another match.
  final repo = ref.read(moneyRepositoryProvider);
  final ledger = await repo.fetchLedger(invoice.memberId);
  final matches = ref.read(invoiceMatchesProvider).value ?? const {};
  // #506 — the junction knows EVERY consumed payment (an aggregate
  // match only remembers its last one).
  final workspace = ref.read(currentWorkspaceProvider).value;
  final consumed = {
    for (final match in matches.values) ?match.paymentLedgerId,
    if (workspace != null) ...await repo.fetchConsumedPaymentIds(workspace.id),
  };
  // A standing PARTIAL match shifts the target: further payments are
  // measured against what is STILL DUE.
  final existing = matches[invoice.id];
  final dueCents =
      existing != null &&
          !existing.pending &&
          existing.resolution == 'under_accepted' &&
          existing.writeoffAt == null
      ? invoice.totalCents - existing.paidCents
      : invoice.totalCents;
  // #512 — a credit BAKED into an issued invoice (negative line at
  // derivation) was spent there; the server refuses it too.
  final memberInvoices = ref.read(invoicesProvider).value ?? const <Invoice>[];
  bool baked(LedgerEntry entry) => memberInvoices.any(
    (i) =>
        i.memberId == invoice.memberId &&
        !i.isVoided &&
        i.period == entry.period &&
        i.issuedAt.isAfter(entry.createdAt),
  );
  final payments = [
    for (final entry in ledger)
      if (entry.kind == LedgerKind.credit &&
          // #512 — account credits (avoir excess) settle too: the
          // imputation of a credit note on any outstanding invoice.
          (entry.category == LedgerCategory.payment ||
              entry.category == LedgerCategory.adjustment) &&
          !consumed.contains(entry.id) &&
          !baked(entry))
        entry,
    // Newest PAYMENT first — by the day the money moved (0070), not by
    // the day it happened to be typed in.
  ]..sort((a, b) => b.on.compareTo(a.on));
  if (!context.mounted) return;
  final choice = await showDialog<MatchChoice>(
    context: context,
    builder: (context) => MatchInvoiceDialog(
      dueCents: dueCents,
      currency: currency,
      payments: payments,
    ),
  );
  if (choice == null || !context.mounted) return;
  if (!await runGuarded(
    context,
    domain: 'money',
    message: 'invoice match failed',
    errorText:
        l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () => ref
        .read(moneyRepositoryProvider)
        .matchInvoice(
          invoiceId: invoice.id,
          paymentLedgerId: choice.paymentLedgerId,
          resolution: choice.resolution,
          note: choice.note,
        ),
  )) {
    return;
  }
  ref.invalidate(invoiceMatchesProvider);
  ref.invalidate(myAccountProvider);
  ref.invalidate(invoicesProvider);
  invalidateBookingData(ref);
  if (!context.mounted) return;
  AppSnack.success(context, l10n?.invoiceMatched ?? 'Invoice matched.');
}

/// One tap invoices every listed member for [period] — behind a confirm
/// naming what is about to become N immutable documents. Per-member
/// guarded, so one failing statement neither stops the sweep nor hides
/// itself: the snack reports what did NOT go through.
Future<void> issueInvoicesForAll(
  BuildContext context,
  WidgetRef ref,
  List<ToInvoiceEntry> entries,
  String period,
  MoneyFormat currency,
) async {
  final l10n = AppLocalizations.of(context);
  final workspace = ref.read(currentWorkspaceProvider).value;
  if (workspace == null || entries.isEmpty) return;
  final total = entries.fold(0, (sum, e) => sum + e.totalCents);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n?.invoiceIssueAll ?? 'Invoice all'),
      content: Text(
        l10n?.invoiceIssueAllConfirm(
              entries.length,
              monthLabel(context, period),
              currency.formatMinor(total),
            ) ??
            'Issue ${entries.length} invoices for '
                '${monthLabel(context, period)}, '
                '${currency.formatMinor(total)} in total? An issued '
                'invoice can no longer be edited.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
        FilledButton(
          key: const ValueKey('invoice-issue-all-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n?.invoiceIssueAll ?? 'Invoice all'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  var issued = 0;
  for (final entry in entries) {
    try {
      await ref
          .read(moneyRepositoryProvider)
          .createInvoice(
            workspaceId: workspace.id,
            memberId: entry.memberId,
            period: period,
          );
      issued++;
    } catch (e, st) {
      TraceLogger.instance.error(
        'money',
        'invoice sweep entry failed',
        error: e,
        stackTrace: st,
      );
    }
  }
  ref.invalidate(invoicesProvider);
  if (!context.mounted) return;
  final failed = entries.length - issued;
  if (failed > 0) {
    AppSnack.error(
      context,
      l10n?.invoiceIssuedPartial(issued, failed) ??
          '$issued issued, $failed failed.',
    );
    return;
  }
  AppSnack.success(
    context,
    l10n?.invoiceIssuedCount(issued) ?? '$issued invoices issued.',
  );
}

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
    final l10n = AppLocalizations.of(context);
    AppSnack.info(
      context,
      l10n?.settlementDocumentationOnly ??
          'Documentation only — every operation happens on the regrouping invoice.',
      replace: true,
    );
    return Future.value();
  }
  return switch (action) {
    InvoiceAction.quickView => quickViewInvoice(context, ref, invoice),
    InvoiceAction.downloadPdf => downloadInvoicePdf(context, ref, invoice),
    InvoiceAction.sharePdf => shareInvoicePdf(context, ref, invoice),
    InvoiceAction.eInvoice => exportEInvoice(
      context,
      ref,
      invoice,
      countryCode: countryCode,
    ),
    InvoiceAction.remind => remindInvoice(context, ref, invoice),
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
Future<List<Invoice>?> askRegroupedAnnexes(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice,
) async {
  final sources = regroupedSourcesOf(ref, invoice);
  if (sources.isEmpty) return const [];
  final l10n = AppLocalizations.of(context);
  final include = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        l10n?.settlementAnnexTitle ?? 'Attach the regrouped invoices?',
      ),
      content: Text(
        l10n?.settlementAnnexBody(sources.length) ??
            'The ${sources.length} invoices this one replaces can follow it, '
                'each on its own pages and stamped as regrouped.',
      ),
      actions: [
        TextButton(
          key: const ValueKey('invoice-annex-alone'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n?.settlementAnnexAlone ?? 'This invoice only'),
        ),
        FilledButton(
          key: const ValueKey('invoice-annex-with'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n?.settlementAnnexWith ?? 'Attach them'),
        ),
      ],
    ),
  );
  if (include == null) return null;
  return include ? sources : const [];
}

