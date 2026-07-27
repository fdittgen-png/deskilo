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
import '../../workspace/providers/workspace_providers.dart';
import '../domain/e_invoice_routing.dart';
import '../domain/invoice.dart';
import '../domain/invoice_pdf.dart';
import '../domain/invoice_ubl.dart';
import '../domain/invoice_ubl_check.dart';
import '../domain/ledger_entry.dart';
import '../providers/money_providers.dart';
import 'e_invoice_identity.dart';
import 'invoice_line_text.dart';
import 'period_label.dart';
import 'widgets/e_invoice_sheet.dart';
import 'widgets/invoice_detail_sheet.dart';
import 'widgets/invoice_form_sheet.dart';
import 'widgets/invoicing_dashboard.dart';

/// Everything an issued invoice can be PUT THROUGH, extracted out of the
/// screen (0069): the archive rows, the open cards and the detail sheet all
/// drive the same code, so an action cannot behave differently depending on
/// where it was tapped.

/// Renders the signed PDF. Every context-derived value is captured BEFORE
/// the first await (use_build_context_synchronously).
Future<({List<int> bytes, String fileName})> buildInvoicePdfFile(
  BuildContext context,
  Invoice invoice, {
  bool proforma = false,
  bool copy = false,
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
      final pdf = await buildInvoicePdfFile(context, invoice, proforma: true);
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
    issuedAt: DateTime.now(),
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
      final pdf = await buildInvoicePdfFile(context, invoice);
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
  final me = ref.read(myMemberProvider).value;
  final export = await showEInvoiceSheet(
    context,
    route: route,
    readiness: readiness,
    canFixIdentity: me?.actsAsOwner ?? false,
  );
  if (export == null || !context.mounted) return;
  if (export == EInvoiceExport.fixIdentity) {
    context.push('/legal-identity');
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
