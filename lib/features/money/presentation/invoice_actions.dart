// SPDX-License-Identifier: 0BSD
import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:typed_data';
import '../../../core/i18n/money_format.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/files/file_names.dart';
import '../../../core/files/file_saver.dart';
import '../../../core/share/file_sharer.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/app_snack.dart';
import '../../../l10n/app_localizations.dart';
import '../../events/providers/event_providers.dart';
import '../../members/providers/directory_providers.dart';
import '../../reservations/providers/reservation_providers.dart';
import '../domain/payment_terms.dart';
import '../../workspace/domain/workspace.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/invoice_legal.dart';
import '../domain/e_invoice_routing.dart';
import '../domain/invoice.dart';
import '../domain/invoice_pdf.dart';
import '../domain/einvoice_gateway.dart';
import '../domain/invoice_cii.dart';
import '../domain/invoice_ubl.dart';
import '../domain/invoice_ubl_check.dart';
import '../domain/ledger_entry.dart';
import '../domain/address_window.dart';
import '../domain/invoice_pdf_template.dart';
import '../domain/dunning.dart';
import '../domain/invoice_report.dart';
import 'report_layout_actions.dart';
import 'report_layout_defaults.dart';
import '../providers/money_providers.dart';
import 'invoice_status.dart';
import 'report_defaults.dart';
import 'widgets/report_preview.dart';
import 'e_invoice_identity.dart';
import 'widgets/einvoice_environment_picker.dart';
import '../domain/invoice_line_text.dart';
import '../domain/report_data.dart';
import '../domain/report_data_letters.dart';
import 'report_facts_of.dart';
import 'report_strings_l10n.dart';
import 'period_label.dart';
import 'widgets/e_invoice_sheet.dart';
import 'widgets/invoice_detail_sheet.dart';
import 'widgets/invoice_form_sheet.dart';
import 'widgets/invoicing_dashboard.dart';
import '../../plan/providers/accessory_providers.dart';
import '../../plan/providers/floor_plan_providers.dart';
import '../../workspace/domain/member.dart';
import '../../../core/locale/report_language.dart';
import '../../../core/theme/app_spacing.dart';

/// Everything an issued invoice can be PUT THROUGH, extracted out of the
/// screen (0069): the archive rows, the open cards and the detail sheet all
/// drive the same code, so an action cannot behave differently depending on
/// where it was tapped.

/// Renders the signed PDF. Every context-derived value is captured BEFORE
/// the first await (use_build_context_synchronously).
/// The active workspace's PDF template (#454) — empty when the
/// invoicePdfTemplate feature is off, so switching the flag off takes
/// the text off every future render without touching the template. A
/// SYNC read: the invoices hub watches the provider, so it is warm
/// before any render action can be tapped.
/// Resolves every `![name]` a rendered report references to bytes
/// (#488) — misses are skipped; the document renders without them.
Future<Map<String, Uint8List>> resolveReportImages(
  WidgetRef ref,
  InvoiceReport? report,
) async {
  if (report == null) return const {};
  final images = <String, Uint8List>{};
  for (final name in reportImageRefs(report)) {
    try {
      final bytes = await ref.read(reportImageBytesProvider(name).future);
      if (bytes != null) images[name] = bytes;
    } catch (e, st) {
      TraceLogger.instance.warn(
        'money',
        'report image fetch failed',
        error: e,
        stackTrace: st,
      );
    }
  }
  return images;
}

InvoicePdfTemplate invoicePdfTemplateFor(WidgetRef ref) =>
    ref
        .read(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.invoicePdfTemplate)
    ? ref.read(invoicePdfTemplateProvider).value ?? InvoicePdfTemplate.empty
    : InvoicePdfTemplate.empty;

/// #910 — the day the invoice falls due: the issue date plus the delay
/// the workspace's reminder rules define, which is the same delay the
/// journey counts down (`invoice_journey.dart`). One source, so the
/// document and the app can never state two different deadlines.
DateTime invoiceDueAt(WidgetRef ref, Invoice invoice) => invoice.issuedAt.add(
      Duration(
        days: (ref.read(dunningRulesProvider).value ?? DunningRules.defaults)
            .firstAfterDays,
      ),
    );

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

/// The l10n bundle of a target DOCUMENT language (#496) — what a
/// letter renders with when its reader's language differs from the UI.
AppLocalizations l10nForLanguage(String language) =>
    lookupAppLocalizations(Locale(language));

/// Resolves a document's language for a reader (#496): member's
/// preferred → workspace language → country language; throws
/// [AmbiguousReportLanguage] for a multi-language country with nothing
/// configured.
String resolveMemberReportLanguage(WidgetRef ref, {String memberLocale = ''}) {
  final workspace = ref.read(currentWorkspaceProvider).value;
  return resolveReportLanguage(
    memberLocale: memberLocale,
    workspaceLocale: workspace?.defaultLocale ?? '',
    countryCode: workspace?.countryCode ?? '',
  );
}

/// Warms every provider the #494 letter-document builders read, so the
/// SYNC data builders see loaded values (the invoice-hub warming idiom).
Future<void> warmLetterDocProviders(WidgetRef ref, String docId) async {
  Future<void> quiet(Future<void> Function() load) async {
    try {
      await load();
    } catch (e, st) {
      TraceLogger.instance.warn(
        'money',
        'letter-doc provider warm failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  await quiet(() => ref.read(invoicePdfTemplateProvider.future));
  if (docId == 'agreement') {
    await quiet(() => ref.read(feeBandsProvider.future));
    await quiet(() => ref.read(servicesProvider.future));
    await quiet(() => ref.read(packagesProvider.future));
    await quiet(() => ref.read(accessoriesProvider().future));
    await quiet(() async {
      final levels = await ref.read(levelsProvider.future);
      for (final level in levels) {
        await ref.read(floorPlanProvider(level.id).future);
      }
    });
  } else if (docId == 'payments') {
    await quiet(() => ref.read(myLedgerProvider.future));
    await quiet(() => ref.read(eventsProvider.future));
  } else if (docId == 'workspace') {
    await quiet(() => ref.read(workspaceMembersProvider.future));
    await quiet(() => ref.read(feeBandsProvider.future));
    await quiet(() => ref.read(servicesProvider.future));
    await quiet(() => ref.read(openWeekdaysProvider.future));
    await quiet(() async {
      final levels = await ref.read(levelsProvider.future);
      for (final level in levels) {
        await ref.read(floorPlanProvider(level.id).future);
      }
    });
  }
  await quiet(() => ref.read(memberNamesProvider.future));
}

/// Renders letter document [docId] through the workspace's template
/// bands (or the shipped default — a broken template never blocks, the
/// #470 contract).
InvoiceReport renderLetterDoc(
  BuildContext context,
  WidgetRef ref, {
  required String docId,
  required Map<String, Object?> data,
  // #496 — the TARGET language; '' renders in the UI language.
  String language = '',
}) {
  final l10n = language.isEmpty
      ? AppLocalizations.of(context)
      : l10nForLanguage(language);
  final template = invoicePdfTemplateFor(ref).forLocale(language);
  final bands = template.docBands(docId) ?? defaultBandsForDoc(docId, l10n);
  // #880 — the owner's texts ride beside the data for every document.
  final texted = withOwnerTexts(data, template.texts);
  return renderReportBands(bands: bands, data: texted) ??
      renderReportBands(bands: defaultBandsForDoc(docId, l10n), data: texted)!;
}

/// #917 — the word every document of a DEVELOPMENT workspace carries,
/// '' from a real one. One source, so an invoice, a statement, a VAT
/// report and a reminder all say it the same way.
String developmentMark(BuildContext context, WidgetRef ref) =>
    (ref.read(currentWorkspaceProvider).value?.isDevelopment ?? false)
        ? (AppLocalizations.of(context)?.developmentWatermark ?? 'DEVELOPMENT')
        : '';

/// The PDF of a rendered letter document (#494).
///
/// #875 — with [layoutXml] and [data] the positioned engine renders the
/// letter and [report] is only the fallback for a layout that fails.
Future<({Uint8List bytes, String fileName})> letterDocPdf(
  BuildContext context,
  WidgetRef ref, {
  required InvoiceReport report,
  required String title,
  String? layoutXml,
  Map<String, Object?> data = const {},
}) async {
  final l10n = AppLocalizations.of(context);
  // #917 — read before the first await: the context must not be used
  // across an async gap, and the answer cannot change mid-render.
  final mark = developmentMark(context, ref);
  Future<pw.Font> font(String asset) async =>
      pw.Font.ttf(await rootBundle.load(asset));
  if (layoutXml != null) {
    final bytes = await tryLayoutPdf(
      layoutXml: layoutXml,
      data: data,
      what: title,
      documentTitle: title,
      pageLabel: l10n?.invoicePdfPage ?? 'Page',
      font: font,
      image: (name) => layoutImage(ref, name),
      // #917 — a report from a rehearsal space says so, like its
      // invoices do.
      watermark: mark,
    );
    if (bytes != null) {
      return (bytes: bytes, fileName: '${safeFileSlug(title)}.pdf');
    }
  }
  final images = await resolveReportImages(ref, report);
  final bytes = await buildBandedLetterPdf(
    report: report,
    reportImages: images,
    pageLabel: l10n?.invoicePdfPage ?? 'Page',
    documentTitle: title,
    baseFont: await font('assets/fonts/Roboto-Regular.ttf'),
    boldFont: await font('assets/fonts/Roboto-Bold.ttf'),
    watermark: mark,
  );
  return (
    bytes: Uint8List.fromList(bytes),
    fileName: '${safeFileSlug(title)}.pdf',
  );
}

Future<({List<int> bytes, String fileName})> buildInvoicePdfFile(
  BuildContext context,
  Invoice invoice, {
  bool proforma = false,
  bool copy = false,
  String facturXml = '',
  Uint8List? colorProfile,
  InvoicePdfTemplate template = InvoicePdfTemplate.empty,
  Workspace? workspace,
  // #488 — resolves ![name] references; null renders without images.
  Future<Uint8List?> Function(String name)? reportImage,
  // #831 — the stamp of a regrouped source ('' otherwise); the callers
  // with a ref build it with [settledStampOf].
  String settledIn = '',

  /// #837 — the invoices this one regrouped, appended after its own
  /// pages as documentation. The caller resolves them, because only it
  /// holds the archive; each is stamped with this document's number.
  List<Invoice> annexInvoices = const [],
  // #881 — the member's own conditions; callers holding a ref pass
  // memberTermsFor(ref, invoice.memberId).
  PaymentTerms? memberTerms,
  // #910 — the settlement date the document must state; callers
  // holding a ref pass invoiceDueAt(ref, invoice).
  DateTime? dueAt,
}) async {
  final l10n = AppLocalizations.of(context);
  final currency = moneyFormat(invoice.currency);
  final dateFormat = DateFormat.yMMMd(
    Localizations.maybeLocaleOf(context)?.toString(),
  );
  final dateLabel = dateFormat.format(invoice.issuedAt);
  final periodLabel = invoicePeriodLabel(context, invoice);
  // #837 — every appended invoice keeps its OWN issue date and period;
  // only the stamp is about where it went.
  final annexes = [
    for (final source in annexInvoices)
      (
        invoice: source,
        dateLabel: dateFormat.format(source.issuedAt),
        periodLabel: invoicePeriodLabel(context, source),
        watermark:
            l10n?.invoicePdfSettledIn(invoice.number) ??
            'Regrouped in ${invoice.number}',
      ),
  ];
  final voidedAt = invoice.voidedAt;
  final voidedLabel = voidedAt == null
      ? ''
      : '${l10n?.invoicePdfVoided ?? 'ERRONEOUS — voided on'} '
            '${dateFormat.format(voidedAt)}';
  Future<pw.Font> font(String asset) async =>
      pw.Font.ttf(await rootBundle.load(asset));
  final reportData = invoiceReportData(
    reportStringsFor(context),
    invoice,
    memberTerms: memberTerms,
    proforma: proforma,
    copy: copy,
    workspace: workspace,
    dueAt: dueAt,
  );
  // #476: a proforma renders its OWN bands when the owner set them —
  // else the invoice's, as it always did.
  final bands = proforma
      ? (template.proformaBands ?? template.invoiceBands)
      : template.invoiceBands;
  final features = effectiveFeatures(
    resolveEnabledFeatures(workspace?.featureFlags ?? const {}),
  );
  final strings = InvoicePdfStrings(
    // #508 — a NEGATIVE document is titled as the credit note it is.
    invoiceTitle: invoice.totalCents < 0
        ? (l10n?.invoicePdfCreditNote ?? 'Credit note')
        : (l10n?.invoicePdfTitle ?? 'Invoice'),
    issuedOn: l10n?.invoicePdfIssuedOn ?? 'Issued on',
    issuedBy: l10n?.invoicePdfIssuedBy ?? 'Issued by',
    billedTo: l10n?.invoicePdfBilledTo ?? 'Billed to',
    total: l10n?.invoiceBalance ?? 'Balance due',
    signature: l10n?.invoicePdfSignature ?? 'Digital signature (SHA-256)',
    voided: voidedLabel,
    // The archive row's own word for it — one term, everywhere.
    voidedWatermark: l10n?.invoiceVoidedChip ?? 'Erroneous',
    proforma: l10n?.invoicePdfProforma ?? 'Proforma',
    copy: l10n?.invoicePdfCopy ?? 'Copy',
    // #831 — a regrouped source says where it went.
    settledIn: settledIn,
    // #917 — a document printed by a development workspace says so
    // across the page, above every other stamp it could carry.
    development: workspace?.isDevelopment ?? false
        ? (l10n?.developmentWatermark ?? 'DEVELOPMENT')
        : '',
    replaces: l10n?.invoicePdfReplaces ?? 'Replaces',
    description: l10n?.invoicePdfDescription ?? 'Description',
    charges: l10n?.invoicePdfCharges ?? 'Charges',
    payments: l10n?.invoicePdfPayments ?? 'Payments',
    net: l10n?.vatPdfNet ?? 'Net',
    vat: l10n?.vatPdfVat ?? 'VAT',
    annex: l10n?.invoicePdfAnnex ?? 'Annex — details',
    attendance: l10n?.invoicePdfAttendance ?? 'Check-ins',
    activity: l10n?.invoicePdfActivity ?? 'Bookings & payments',
    reserved: l10n?.invoicePdfReserved ?? 'reserved',
    page: l10n?.invoicePdfPage ?? 'Page',
  );
  // A proforma is named after what it covers — it has no number to be
  // filed under, and must never sit in a folder looking like the invoice.
  final stem = proforma
      ? safeFileSlug(
          '${l10n?.invoicePdfProforma ?? 'proforma'} '
          '${invoice.number.isEmpty ? '${invoice.clientName} $periodLabel' : invoice.number}',
        )
      : safeFileSlug(invoice.number);
  // #875 — a positioned layout, when this document has one, IS the
  // document: it states its own geometry and the bands never run. A
  // proforma without a layout of its own borrows the invoice's, as it
  // borrows its bands. Annexes stay banded — they are documentation
  // appended behind, and the layout engine renders one document.
  // #874 — a kind without a design renders the letter standard's
  // default layout when that flag is on.
  final letterStandard = features.contains(WorkspaceFeature.letterStandard);
  final layoutXml =
      features.contains(WorkspaceFeature.reportLayouts) && annexInvoices.isEmpty
      ? (proforma
            ? (template.layoutFor('proforma') ??
                  resolveLayoutXmlFor(
                    template: template,
                    kindId: 'invoice',
                    letterStandard: letterStandard,
                    l10n: AppLocalizations.of(context),
                  ))
            : resolveLayoutXmlFor(
                template: template,
                kindId: 'invoice',
                letterStandard: letterStandard,
                l10n: AppLocalizations.of(context),
              ))
      : null;
  if (layoutXml != null) {
    final bytes = await tryLayoutPdf(
      layoutXml: layoutXml,
      data: withOwnerTexts(reportData, template.texts),
      what: invoice.number.isEmpty ? stem : invoice.number,
      documentTitle: '${strings.invoiceTitle} ${invoice.number}',
      pageLabel: strings.page,
      font: font,
      image: reportImage,
      watermark: invoiceWatermark(
        strings,
        proforma: proforma,
        voided: invoice.isVoided,
        copy: copy,
      ),
      signatureLabel: strings.signature,
      signature: proforma ? '' : invoice.signature,
    );
    if (bytes != null) return (bytes: bytes, fileName: '$stem.pdf');
  }
  final report = renderReportBands(bands: bands, data: withOwnerTexts(reportData, template.texts));
  final reportImages = <String, Uint8List>{};
  if (report != null && reportImage != null) {
    for (final name in reportImageRefs(report)) {
      final imageBytes = await reportImage(name);
      if (imageBytes != null) reportImages[name] = imageBytes;
    }
  }
  // #869 — the envelope window: the template's explicit choice wins,
  // otherwise the seller's country decides the side. Off entirely when
  // the workspace has not enabled the feature.
  final addressWindow = features.contains(WorkspaceFeature.invoiceAddressWindow)
      ? (template.addressWindow ??
            addressWindowForCountry(workspace?.countryCode ?? ''))
      : AddressWindow.off;
  final association = InvoiceLegal.fromJson(
    workspace?.invoiceLegal ?? const {},
  ).isAssociation;
  final words = reportStringsOf(l10n);
  final bytes = await buildInvoicePdf(
    addressWindow: addressWindow,
    invoice: invoice,
    reportImages: reportImages,
    lineText: (line) => invoiceLineText(words, line,
        association: association, period: invoice.period),
    activityText: (entry) => annexEntryText(words, entry),
    strings: strings,
    money: (cents) => currency.formatMinor(cents),
    dateLabel: dateLabel,
    // The stored title is the raw period ('2026-07'); the document reads
    // the month like a human would.
    periodLabel: periodLabel,
    annexes: annexes,
    proforma: proforma,
    copy: copy,
    facturXml: facturXml,
    colorProfile: colorProfile,
    report: report,
    baseFont: await font('assets/fonts/Roboto-Regular.ttf'),
    boldFont: await font('assets/fonts/Roboto-Bold.ttf'),
  );
  return (bytes: bytes, fileName: '$stem.pdf');
}

/// FACTUR-X: one PDF that carries the EN 16931 invoice inside it (as CII,
/// the syntax the format mandates). A human opens it and sees the invoice;
/// a platform opens it and finds `factur-x.xml`. This is what French and
/// German small businesses actually hand to their platform.
Future<({List<int> bytes, String fileName})> buildFacturXFile(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice, {
  required InvoiceParty seller,
  required InvoiceParty buyer,
  required String iban,
}) async {
  final association = ref.read(sellerIsAssociationProvider);
  final words = reportStringsOf(AppLocalizations.of(context));
  final xml = buildInvoiceCii(
    invoice: invoice,
    seller: seller,
    buyer: buyer,
    iban: iban,
    lineText: (line) => invoiceLineText(words, line,
        association: association, period: invoice.period),
    // #941 — the same due date and terms the PDF prints.
    dueDate: invoiceDueAt(ref, invoice),
    paymentTerms: memberTermsFor(ref, invoice.memberId)?.paymentTerms ?? '',
  );
  // PDF/A-3 cannot exist without an embedded output intent.
  final icc = await rootBundle.load('assets/pdf/sRGB2014.icc');
  if (!context.mounted) {
    return (bytes: const <int>[], fileName: '');
  }
  final pdf = await buildInvoicePdfFile(
    context,
    invoice,
    memberTerms: memberTermsFor(ref, invoice.memberId),
    dueAt: invoiceDueAt(ref, invoice),
    copy: _rendersCopy(ref),
    settledIn: settledStampOf(context, ref, invoice),
    facturXml: xml,
    colorProfile: icc.buffer.asUint8List(),
    template: invoicePdfTemplateFor(ref),
    workspace: ref.read(currentWorkspaceProvider).value,
    // #920 — through layoutImage, so the shipped layouts' `logo`
    // resolves to whatever the owner actually called theirs.
    reportImage: (name) => layoutImage(ref, name),
  );
  return (
    bytes: pdf.bytes,
    fileName: '${safeFileSlug('facturx ${invoice.number}')}.pdf',
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

/// Whether THIS viewer renders a copy: only an issuer (owner, or an admin
/// with the delegation) holds the original. A member downloading their own
/// invoice gets a document stamped as the duplicate it is.
bool _rendersCopy(WidgetRef ref) {
  final me = ref.read(myMemberProvider).value;
  if (me == null) return true;
  return !(me.actsAsOwner || me.canAdminister);
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
        copy: _rendersCopy(ref),
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
      copy: _rendersCopy(ref),
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
          copy: _rendersCopy(ref),
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
        copy: _rendersCopy(ref),
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

/// Records a payment reminder (0066) and hands the invoice PDF to the share
/// sheet with a localized reminder message — mail, WhatsApp, whatever the
/// device offers.
/// Renders the reminder LETTER for [invoice] at [level] (#472): the
/// owner's band set for that level, else the shipped localized default.
/// A broken custom band set falls back to the default — a reminder must
/// never fail on a template.
Future<({List<int> bytes, String fileName, String title})> buildReminderPdfFile(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice, {
  required int level,
  ReportBands? draftBands,
}) async {
  // #496 — the reminder letter prints in the MEMBER's language (their
  // preference → workspace language → country language).
  var language = '';
  try {
    final members =
        ref.read(workspaceMembersProvider).value ?? const <Member>[];
    final userId = members
        .where((m) => m.id == invoice.memberId)
        .firstOrNull
        ?.userId;
    final profile = userId == null
        ? null
        : ref.read(memberProfilesProvider).value?[userId];
    language = resolveMemberReportLanguage(
      ref,
      memberLocale: profile?.preferredLocale ?? '',
    );
  } on AmbiguousReportLanguage {
    language = '';
  }
  final l10n = language.isEmpty
      ? AppLocalizations.of(context)
      : l10nForLanguage(language);
  final title = level <= 1
      ? (l10n?.reminderPdfTitleFriendly ?? 'Payment reminder')
      : '${l10n?.reminderPdfTitleFirm ?? 'Reminder'} $level';
  final data = reminderReportData(
    reportStringsFor(context,
        l10n: l10n, localeName: language.isEmpty ? null : language),
    reminderFactsOf(ref, invoice),
    invoice,
    level: level,
  );
  final template = invoicePdfTemplateFor(ref).forLocale(language);
  final bands = draftBands ?? template.reminderBands(level);
  final fallback = defaultReminderBands(level, l10n);
  final texted = withOwnerTexts(data, template.texts);
  final report =
      (bands == null ? null : renderReportBands(bands: bands, data: texted)) ??
      renderReportBands(bands: fallback, data: texted)!;
  final pageLabel = l10n?.invoicePdfPage ?? 'Page';
  final mark = developmentMark(context, ref);
  Future<pw.Font> font(String asset) async =>
      pw.Font.ttf(await rootBundle.load(asset));
  final bytes = await buildBandedLetterPdf(
    report: report,
    reportImages: await resolveReportImages(ref, report),
    pageLabel: pageLabel,
    documentTitle: '$title ${invoice.number}',
    baseFont: await font('assets/fonts/Roboto-Regular.ttf'),
    boldFont: await font('assets/fonts/Roboto-Bold.ttf'),
    watermark: mark,
  );
  return (
    bytes: bytes,
    fileName: '${safeFileSlug('$title ${invoice.number}')}.pdf',
    title: title,
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

/// #831 — the watermark of a regrouped source: "Regrouped in INV-…", or
/// '' for every other document.
String settledStampOf(BuildContext context, WidgetRef ref, Invoice invoice) {
  if (!invoice.isFolded) return '';
  final l10n = AppLocalizations.of(context);
  final number = settledByNumberOf(
    invoice,
    ref.read(invoicesProvider).value ?? const [],
  );
  return l10n?.invoicePdfSettledIn(number) ?? 'Regrouped in $number';
}

/// #837 — the invoices [invoice] regrouped, resolved from the archive in
/// the order its own snapshot lists them. Empty when it regroups
/// nothing, or when the archive has not loaded them.
List<Invoice> regroupedSourcesOf(WidgetRef ref, Invoice invoice) {
  if (invoice.settles.isEmpty) return const [];
  final all = ref.read(invoicesProvider).value ?? const <Invoice>[];
  return [
    for (final source in invoice.settles)
      ...all.where((i) => i.id == source.invoiceId),
  ];
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

/// #881 — the member's own payment conditions, from the members list
/// already loaded; null when they inherit the workspace's.
PaymentTerms? memberTermsFor(WidgetRef ref, String memberId) => ref
    .read(workspaceMembersProvider)
    .value
    ?.where((m) => m.id == memberId)
    .firstOrNull
    ?.paymentTerms;

