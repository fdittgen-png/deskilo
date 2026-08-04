// SPDX-License-Identifier: 0BSD
import 'dart:convert' show utf8;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;

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
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/e_invoice_routing.dart';
import '../domain/invoice.dart';
import '../domain/invoice_pdf.dart';
import '../domain/einvoice_gateway.dart';
import '../domain/invoice_cii.dart';
import '../domain/invoice_ubl.dart';
import '../domain/fec.dart';
import '../domain/saf_t.dart';
import '../domain/invoice_ubl_check.dart';
import '../domain/ledger_entry.dart';
import '../domain/invoice_pdf_template.dart';
import '../providers/money_providers.dart';
import 'e_invoice_identity.dart';
import 'widgets/einvoice_environment_picker.dart';
import 'invoice_line_text.dart';
import 'period_label.dart';
import 'widgets/accounting_export_sheet.dart';
import 'widgets/e_invoice_sheet.dart';
import 'widgets/invoice_detail_sheet.dart';
import 'widgets/invoice_form_sheet.dart';
import 'widgets/invoicing_dashboard.dart';
import '../../../core/time/clock.dart';

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
InvoicePdfTemplate invoicePdfTemplateFor(WidgetRef ref) =>
    ref
            .read(enabledFeaturesSyncProvider)
            .contains(WorkspaceFeature.invoicePdfTemplate)
        ? ref.read(invoicePdfTemplateProvider).value ??
            InvoicePdfTemplate.empty
        : InvoicePdfTemplate.empty;

Future<({List<int> bytes, String fileName})> buildInvoicePdfFile(
  BuildContext context,
  Invoice invoice, {
  bool proforma = false,
  bool copy = false,
  String facturXml = '',
  Uint8List? colorProfile,
  InvoicePdfTemplate template = InvoicePdfTemplate.empty,
}) async {
  final l10n = AppLocalizations.of(context);
  final currency = NumberFormat.simpleCurrency(name: invoice.currency);
  final dateFormat = DateFormat.yMMMd(
    Localizations.maybeLocaleOf(context)?.toString(),
  );
  final dateLabel = dateFormat.format(invoice.issuedAt);
  final periodLabel = invoicePeriodLabel(context, invoice);
  final voidedAt = invoice.voidedAt;
  final voidedLabel = voidedAt == null
      ? ''
      : '${l10n?.invoicePdfVoided ?? 'ERRONEOUS — voided on'} '
          '${dateFormat.format(voidedAt)}';
  Future<pw.Font> font(String asset) async =>
      pw.Font.ttf(await rootBundle.load(asset));
  // #454: placeholder resolution happens here, where every value is at
  // hand — the renderer receives finished text.
  final placeholderValues = <String, String>{
    'workspace': invoice.workspaceName,
    'member': invoice.memberName,
    'number': invoice.number,
    'period': periodLabel,
    'issued': dateLabel,
    'total': currency.format(invoice.totalCents / 100),
  };
  final bytes = await buildInvoicePdf(
    invoice: invoice,
    lineText: (line) => invoiceLineText(l10n, line),
    activityText: (entry) => annexEntryText(l10n, entry),
    strings: InvoicePdfStrings(
      invoiceTitle: l10n?.invoicePdfTitle ?? 'Invoice',
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
    ),
    money: (cents) => currency.format(cents / 100),
    dateLabel: dateLabel,
    // The stored title is the raw period ('2026-07'); the document reads
    // the month like a human would.
    periodLabel: periodLabel,
    proforma: proforma,
    copy: copy,
    facturXml: facturXml,
    colorProfile: colorProfile,
    introText: InvoicePdfTemplate.apply(template.intro, placeholderValues),
    footerText:
        InvoicePdfTemplate.apply(template.footer, placeholderValues),
    baseFont: await font('assets/fonts/Roboto-Regular.ttf'),
    boldFont: await font('assets/fonts/Roboto-Bold.ttf'),
  );
  // A proforma is named after what it covers — it has no number to be
  // filed under, and must never sit in a folder looking like the invoice.
  final stem = proforma
      ? safeFileSlug('${l10n?.invoicePdfProforma ?? 'proforma'} '
          '${invoice.number.isEmpty ? '${invoice.memberName} $periodLabel' : invoice.number}')
      : safeFileSlug(invoice.number);
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
  final l10n = AppLocalizations.of(context);
  final xml = buildInvoiceCii(
    invoice: invoice,
    seller: seller,
    buyer: buyer,
    iban: iban,
    lineText: (line) => invoiceLineText(l10n, line),
  );
  // PDF/A-3 cannot exist without an embedded output intent.
  final icc = await rootBundle.load('assets/pdf/sRGB2014.icc');
  if (!context.mounted) {
    return (bytes: const <int>[], fileName: '');
  }
  final pdf = await buildInvoicePdfFile(
    context,
    invoice,
    copy: _rendersCopy(ref),
    facturXml: xml,
    colorProfile: icc.buffer.asUint8List(),
    template: invoicePdfTemplateFor(ref),
  );
  return (
    bytes: pdf.bytes,
    fileName: '${safeFileSlug('facturx ${invoice.number}')}.pdf',
  );
}

/// ACCOUNTING EXPORT (0074): one SAF-T file for a period — the OECD's own
/// XML for handing accounting data to an accountant. Saved to Downloads,
/// because that is where a file destined for someone else's software goes.
Future<void> exportAccountingFile(
  BuildContext context,
  WidgetRef ref,
  List<Invoice> invoices, {
  required String label,
}) async {
  final l10n = AppLocalizations.of(context);
  final workspace = ref.read(currentWorkspaceProvider).value;
  if (workspace == null) return;
  if (invoices.isEmpty) {
    AppSnack.info(
      context,
      l10n?.invoiceAccountingExportEmpty ??
          'Nothing to export for this period.',
    );
    return;
  }
  final matches = ref.read(invoiceMatchesProvider).value ?? const {};
  final company = sellerOf(invoices.last, workspace);
  // Two standards, and which one is wanted depends on who asks: an
  // accountant's software reads SAF-T, a French audit demands the FEC.
  final format = await showAccountingExportSheet(
    context,
    offerFec: workspace.countryCode.toUpperCase() == 'FR',
  );
  if (format == null || !context.mounted) return;

  if (format == AccountingExportFormat.fec) {
    // The file NAME is the SIREN — without it the export cannot even be
    // called what the arrêté requires.
    if (company.legalId.replaceAll(RegExp('[^0-9]'), '').isEmpty) {
      AppSnack.error(
        context,
        l10n?.fecMissingSiren ??
            'The FEC is named after your registration number — fill it in '
                'under Legal identity first.',
      );
      return;
    }
    // The owner's own VAT account (0072) if they set one — the dialog is
    // where it can still be corrected.
    final accounts = await showFecAccountsDialog(
      context,
      initial: workspace.vatAccount.isEmpty
          ? const FecAccounts()
          : FecAccounts(vat: workspace.vatAccount),
    );
    if (accounts == null || !context.mounted) return;
    await runGuarded(
      context,
      domain: 'money',
      message: 'FEC export failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
        final fec = buildFecFile(
          invoices: invoices,
          matches: matches,
          company: company,
          accounts: accounts,
          lineText: (line) => invoiceLineText(l10n, line),
          customersLabel: l10n?.fecAccountCustomers ?? 'Clients',
          revenueLabel: l10n?.fecAccountRevenue ?? 'Ventes',
          bankLabel: l10n?.fecAccountBank ?? 'Banque',
          vatLabel: l10n?.fecAccountVat ?? 'TVA collectée',
        );
        // The fiscal year closes on 31 December of the latest invoiced
        // year — the only close date the app can know.
        final year = invoices
            .map((invoice) => invoice.issuedAt.year)
            .reduce((a, b) => a > b ? a : b);
        final bytes = Uint8List.fromList(utf8.encode(fec));
        if (!context.mounted) return;
        await _save(
          context,
          ref,
          bytes: bytes,
          fileName: fecFileName(company.legalId, DateTime(year, 12, 31)),
        );
      },
    );
    return;
  }

  await runGuarded(
    context,
    domain: 'money',
    message: 'accounting export failed',
    errorText: l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () async {
      final xml = buildSafTFile(
        invoices: invoices,
        matches: matches,
        company: company,
        currency: workspace.currencyCode,
        softwareVersion: safTSoftwareVersion,
        createdAt: ref.read(clockProvider).now(),
        lineText: (line) => invoiceLineText(l10n, line),
        fallbackDescription: l10n?.invoicesTitle ?? 'Invoice',
      );
      final bytes = Uint8List.fromList(utf8.encode(xml));
      if (!context.mounted) return;
      await _save(
        context,
        ref,
        bytes: bytes,
        fileName: '${safeFileSlug('saf-t ${workspace.name} $label')}.xml',
      );
    },
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
}) async {
  final l10n = AppLocalizations.of(context);
  EInvoiceSubmission? result;
  if (!await runGuarded(
    context,
    domain: 'money',
    message: 'e-invoice submission failed',
    errorText: l10n?.workspaceGenericError ??
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
      result = await ref.read(moneyRepositoryProvider).sendEInvoice(
            workspaceId: workspaceId,
            invoiceId: invoice.id,
            fileName: file.fileName,
            mimeType: 'application/pdf',
            bytes: file.bytes,
            environment: environment,
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
      environment == 'prod'
          ? (l10n?.invoiceSendAccepted ?? 'Sent — the platform accepted it.')
          : (l10n?.invoiceSendAcceptedTest(environment.toUpperCase()) ??
              'Test send accepted (${environment.toUpperCase()}).'),
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

/// Renders the month as a PROFORMA and hands it to the share sheet — the
/// quote an issuer sends before invoicing, and the payment request they
/// can re-send afterwards. Nothing is issued, nothing is booked.
Future<void> shareProforma(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice,
) async {
  final l10n = AppLocalizations.of(context);
  if (!invoice.lines.any((line) => line.amountCents > 0)) {
    AppSnack.info(
      context,
      l10n?.invoiceProformaNothing ??
          'Nothing tracked for this month — no proforma to send.',
    );
    return;
  }
  if (!await runGuarded(
    context,
    domain: 'money',
    message: 'proforma share failed',
    errorText: l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () async {
      final pdf = await buildInvoicePdfFile(context, invoice,
          proforma: true, template: invoicePdfTemplateFor(ref));
      await ref.read(fileSharerProvider)(
        bytes: Uint8List.fromList(pdf.bytes),
        fileName: pdf.fileName,
        mimeType: 'application/pdf',
      );
    },
  )) {
    return;
  }
  if (!context.mounted) return;
  AppSnack.success(
    context,
    l10n?.invoiceProformaShared ?? 'Proforma shared.',
  );
}

/// Builds the proforma of a month that has NOT been invoiced yet: the
/// server's own derivation (the same RPC the issue sheet previews) dressed
/// in the live workspace and member identity. Returns null when the month
/// tracked nothing.
Future<Invoice?> proformaForMonth(
  WidgetRef ref, {
  required String memberId,
  required String period,
}) async {
  final workspace = ref.read(currentWorkspaceProvider).value;
  if (workspace == null) return null;
  final preview = await ref.read(moneyRepositoryProvider).previewInvoice(
        workspaceId: workspace.id,
        memberId: memberId,
        period: period,
      );
  if (preview.lines.isEmpty) return null;
  final names = await ref.read(memberNamesProvider.future);
  final members = await ref.read(workspaceMembersProvider.future);
  final userId = members
      .where((m) => m.id == memberId)
      .map((m) => m.userId)
      .firstOrNull;
  final profiles = await ref.read(memberProfilesProvider.future);
  return Invoice(
    // No id and no number: nothing was issued.
    id: '',
    workspaceId: workspace.id,
    memberId: memberId,
    number: '',
    issuedAt: ref.read(clockProvider).now(),
    period: period,
    title: period,
    lines: preview.lines,
    totalCents: preview.totalCents,
    currency: workspace.currencyCode,
    memberName: names[memberId] ?? '',
    memberAddress: userId == null ? '' : profiles[userId]?.address ?? '',
    workspaceName: workspace.name,
    workspaceAddress: workspace.address,
    issuerName: '',
    signature: '',
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
Future<void> _save(
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
  await runGuarded(
    context,
    domain: 'money',
    message: 'invoice download failed',
    errorText: l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () async {
      final pdf = await buildInvoicePdfFile(
        context,
        invoice,
        copy: _rendersCopy(ref),
        template: invoicePdfTemplateFor(ref),
      );
      if (!context.mounted) return;
      await _save(
        context,
        ref,
        bytes: Uint8List.fromList(pdf.bytes),
        fileName: pdf.fileName,
      );
    },
  );
}

Future<void> shareInvoicePdf(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice,
) async {
  final l10n = AppLocalizations.of(context);
  await runGuarded(
    context,
    domain: 'money',
    message: 'invoice share failed',
    errorText: l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () async {
      final pdf = await buildInvoicePdfFile(
        context,
        invoice,
        copy: _rendersCopy(ref),
        template: invoicePdfTemplateFor(ref),
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
    errorText: l10n?.workspaceGenericError ??
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
Future<void> remindInvoice(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice,
) async {
  final l10n = AppLocalizations.of(context);
  final currency = NumberFormat.simpleCurrency(name: invoice.currency);
  final message = l10n?.invoiceReminderMessage(
        invoice.number,
        currency.format(invoice.totalCents / 100),
      ) ??
      'Friendly reminder: invoice ${invoice.number} — balance due '
          '${currency.format(invoice.totalCents / 100)}.';
  if (!await runGuarded(
    context,
    domain: 'money',
    message: 'invoice reminder failed',
    errorText: l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () async {
      // PDF first — it captures its context-derived values before any
      // await (use_build_context_synchronously).
      final pdf = await buildInvoicePdfFile(context, invoice,
          template: invoicePdfTemplateFor(ref));
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
  );
  // The same judgement against the LIVE identity: if that one passes, the
  // owner is not missing anything — the document is simply older than the
  // identity, and only a replacement can carry the new one.
  final identityFixedSince = invoice.sellerParty != null &&
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
    TraceLogger.instance.warn('money', 'e-invoice gateway probe failed',
        error: e, stackTrace: st);
    gateway = EInvoiceGatewayConfig.notConfigured;
  }
  if (!context.mounted) return;
  final export = await showEInvoiceSheet(
    context,
    route: route,
    readiness: readiness,
    canFixIdentity: me?.actsAsOwner ?? false,
    identityFixedSince: identityFixedSince,
    // Only an issuer sends, and only when a platform is configured.
    canSend: gateway.configured &&
        (me?.actsAsOwner == true || me?.canAdminister == true),
  );
  if (export == null || !context.mounted) return;
  if (export == EInvoiceExport.fixIdentity) {
    context.push('/legal-identity');
    return;
  }
  final l10nForFile = AppLocalizations.of(context);
  if (export == EInvoiceExport.send) {
    // Dev mode + a configured test platform → choose the target (#393);
    // anyone else goes straight to production, no extra tap.
    final environment =
        await pickEInvoiceEnvironment(context, ref, gateway: gateway);
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
    );
    return;
  }
  if (export == EInvoiceExport.facturXDownload ||
      export == EInvoiceExport.facturXShare) {
    await runGuarded(
      context,
      domain: 'money',
      message: 'factur-x export failed',
      errorText: l10nForFile?.workspaceGenericError ??
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
        await _save(context, ref, bytes: bytes, fileName: file.fileName);
      },
    );
    return;
  }
  final l10n = AppLocalizations.of(context);
  await runGuarded(
    context,
    domain: 'money',
    message: 'e-invoice export failed',
    errorText: l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () async {
      final xml = buildInvoiceUbl(
        invoice: invoice,
        seller: seller,
        buyer: buyer,
        iban: workspaceIban(workspace),
        lineText: (line) => invoiceLineText(l10n, line),
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
      await _save(context, ref, bytes: bytes, fileName: fileName);
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
  final currency = NumberFormat.simpleCurrency(name: invoice.currency);
  // 0068 — the candidates: the member's registered payments (incl. settled
  // online payments) not yet consumed by another match.
  final repo = ref.read(moneyRepositoryProvider);
  final ledger = await repo.fetchLedger(invoice.memberId);
  final matches = ref.read(invoiceMatchesProvider).value ?? const {};
  final consumed = {
    for (final match in matches.values) ?match.paymentLedgerId,
  };
  final payments = [
    for (final entry in ledger)
      if (entry.kind == LedgerKind.credit &&
          entry.category == LedgerCategory.payment &&
          !consumed.contains(entry.id))
        entry,
    // Newest PAYMENT first — by the day the money moved (0070), not by
    // the day it happened to be typed in.
  ]..sort((a, b) => b.on.compareTo(a.on));
  if (!context.mounted) return;
  final choice = await showDialog<MatchChoice>(
    context: context,
    builder: (context) => MatchInvoiceDialog(
      dueCents: invoice.totalCents,
      currency: currency,
      payments: payments,
    ),
  );
  if (choice == null || !context.mounted) return;
  if (!await runGuarded(
    context,
    domain: 'money',
    message: 'invoice match failed',
    errorText: l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () => ref.read(moneyRepositoryProvider).matchInvoice(
          invoiceId: invoice.id,
          paymentLedgerId: choice.paymentLedgerId,
          resolution: choice.resolution,
          note: choice.note,
        ),
  )) {
    return;
  }
  ref.invalidate(invoiceMatchesProvider);
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
  NumberFormat currency,
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
              currency.format(total / 100),
            ) ??
            'Issue ${entries.length} invoices for '
                '${monthLabel(context, period)}, '
                '${currency.format(total / 100)} in total? An issued '
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
      await ref.read(moneyRepositoryProvider).createInvoice(
            workspaceId: workspace.id,
            memberId: entry.memberId,
            period: period,
          );
      issued++;
    } catch (e, st) {
      TraceLogger.instance.error('money', 'invoice sweep entry failed',
          error: e, stackTrace: st);
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
}) =>
    switch (action) {
      InvoiceAction.downloadPdf => downloadInvoicePdf(context, ref, invoice),
      InvoiceAction.sharePdf => shareInvoicePdf(context, ref, invoice),
      InvoiceAction.eInvoice =>
        exportEInvoice(context, ref, invoice, countryCode: countryCode),
      InvoiceAction.remind => remindInvoice(context, ref, invoice),
      InvoiceAction.markPaid => matchInvoiceToPayment(context, ref, invoice),
      InvoiceAction.markErroneous =>
        voidInvoiceWithConfirm(context, ref, invoice),
      InvoiceAction.replace =>
        showInvoiceIssueSheet(context, ref, replaces: invoice),
    };
