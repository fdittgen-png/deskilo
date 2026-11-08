// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2494 — the PDF side of the invoice actions: save, download, share, quick
// view and the regrouped-annex question they share. Split out of
// invoice_actions.dart (was invoice_actions_part1); same functions, same
// behaviour.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/files/file_delivery.dart';
import '../../../core/files/file_delivery_notice.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/share/file_sharer.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/app_snack.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/invoice.dart';
import '../domain/invoice_pdf_template.dart';
import '../domain/invoice_report.dart';
import '../domain/report_data.dart';
import 'invoice_actions.dart' show requireWorkspaceTaxReference, workspaceTaxReference;
import 'invoice_documents.dart';
import 'report_defaults.dart';
import 'report_layout_actions.dart';
import 'report_strings_l10n.dart';
import 'widgets/report_preview.dart';

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


/// Delivers [bytes] as [fileName] the way this platform can be truthful
/// about — Downloads, the browser's download, an iPhone's Export… choice —
/// and tells the person what actually happened: the shared "download,
/// don't just share" path of every money document (#474). A browser
/// request offers "Download again", the user gesture a blocked hand-over
/// needs. Answers whether the file was handed out ([fileHandedOut]).
Future<bool> savePdfToDownloads(
  BuildContext context,
  WidgetRef ref, {
  required Uint8List bytes,
  required String fileName,
}) async {
  final delivery =
      await deliverFile(context, ref, bytes: bytes, fileName: fileName);
  if (!context.mounted) return fileHandedOut(delivery);
  announceFileDelivery(
    context,
    delivery,
    retry: () => unawaited(
      savePdfToDownloads(context, ref, bytes: bytes, fileName: fileName),
    ),
  );
  return fileHandedOut(delivery);
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
    InvoicePdfFileOptions(reference: requireWorkspaceTaxReference(ref),
      // #920 — through layoutImage, so the shipped layouts' `logo`
      // resolves to whatever the owner actually called theirs.
      reportImage: (String name) => layoutImage(ref, name),
      memberTerms: memberTermsFor(ref, invoice.memberId),
        dueAt: invoiceDueAt(ref, invoice),
        copy: rendersCopy(ref),
        settledIn: settledStampOf(context, ref, invoice),
        annexInvoices: annexes,
        template: invoicePdfTemplateFor(ref),
        workspace: ref.read(currentWorkspaceProvider).value));
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
  final l10n = context.l10n;
  final reference = workspaceTaxReference(ref);
  if (reference == null) {
    AppSnack.error(context, l10n.workspaceTaxContextNotReady);
    return;
  }
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
      reference: reference,
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
          reference: reference,
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
    InvoicePdfFileOptions(reference: requireWorkspaceTaxReference(ref),
      // #920 — through layoutImage, so the shipped layouts' `logo`
      // resolves to whatever the owner actually called theirs.
      reportImage: (String name) => layoutImage(ref, name),
      memberTerms: memberTermsFor(ref, invoice.memberId),
        dueAt: invoiceDueAt(ref, invoice),
        copy: rendersCopy(ref),
        settledIn: settledStampOf(context, ref, invoice),
        annexInvoices: annexes,
        template: invoicePdfTemplateFor(ref),
        workspace: ref.read(currentWorkspaceProvider).value));
      await ref.read(fileSharerProvider)(
        bytes: Uint8List.fromList(pdf.bytes),
        fileName: pdf.fileName,
        mimeType: 'application/pdf',
      );
    },
  );
}
