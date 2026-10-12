// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/share/file_sharer.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/app_sheet.dart';
import '../../../core/ui/app_snack.dart';
import '../domain/invoice_report.dart';
import 'invoice_actions.dart';
import 'invoice_documents.dart';
import 'widgets/report_preview.dart';

/// #514 — EVERY report exit offers the same triad: see it on screen
/// BEFORE committing to a PDF, save it locally, or hand it to any app
/// (WhatsApp, mail, …). One sheet, one contract — a new report only has
/// to say how it renders and how its PDF builds, and it inherits the
/// three actions.
Future<void> runReportActions(
  BuildContext context,
  WidgetRef ref, {
  required String keyPrefix,
  required Future<({Uint8List bytes, String fileName})> Function() buildPdf,

  /// The report-engine render for the quick view; omit for legacy
  /// (non-engine) PDFs — the sheet then offers save and share only.
  InvoiceReport? Function()? render,
  String logMessage = 'report pdf failed',
}) async {
  final l10n = context.l10n;
  final choice = await showAppSheet<String>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (render != null)
            ListTile(
              key: ValueKey('$keyPrefix-quick'),
              leading: const Icon(Icons.bolt_outlined),
              title: Text(l10n.reportQuickView),
              onTap: () => Navigator.of(sheetContext).pop('quick'),
            ),
          ListTile(
            key: ValueKey('$keyPrefix-download'),
            leading: const Icon(Icons.download_outlined),
            title: Text(l10n.invoiceTemplateDownload),
            onTap: () => Navigator.of(sheetContext).pop('download'),
          ),
          ListTile(
            key: ValueKey('$keyPrefix-share'),
            leading: const Icon(Icons.share_outlined),
            title: Text(l10n.invoiceTemplateShare),
            onTap: () => Navigator.of(sheetContext).pop('share'),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  if (choice == 'quick') {
    final report = render!();
    if (report == null) {
      AppSnack.error(
        context,
        l10n.workspaceGenericError,
      );
      return;
    }
    final images = await resolveReportImages(ref, report);
    if (!context.mounted) return;
    await showReportQuickPreview(context,
        report: report, simulated: false, images: images);
    return;
  }
  await runGuarded(
    context,
    domain: 'money',
    message: logMessage,
    errorText: l10n.workspaceGenericError,
    action: () async {
      final pdf = await buildPdf();
      if (!context.mounted) return;
      if (choice == 'download') {
        await savePdfToDownloads(context, ref,
            bytes: pdf.bytes, fileName: pdf.fileName);
      } else {
        await ref.read(fileSharerProvider)(
          bytes: pdf.bytes,
          fileName: pdf.fileName,
          mimeType: 'application/pdf',
        );
      }
    },
  );
}
