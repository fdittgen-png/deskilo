// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #864 — carrying one report design out of the app and back in.
//
// Out is a file that explains itself (see report_design_file.dart), so
// whoever or whatever edits it has the field meanings, the markup and
// the placeholder list in front of them. In is a refusal with a reason
// whenever the file is not the design of the report being imported into
// — never a half-applied layout.
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/files/file_picker.dart';
import '../../../core/files/file_saver.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/app_snack.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/invoice_pdf_template.dart';
import '../domain/report_design_file.dart';
import '../domain/report_kind.dart';

/// Writes [bands] out as the design of [kind]. Returns the saved path,
/// or null when the save failed or was cancelled.
Future<String?> exportReportDesign(
  BuildContext context,
  WidgetRef ref, {
  required ReportKind kind,
  required String language,
  required String workspaceName,
  required ReportBands bands,
  required DateTime exportedAt,
}) async {
  final l10n = context.l10n;
  final content = buildReportDesignFile(
    kind: kind,
    language: language,
    workspaceName: workspaceName,
    bands: bands,
    exportedAt: exportedAt,
  );
  final fileName = reportDesignFileName(
    kindId: kind.id,
    language: language,
    workspaceName: workspaceName,
  );
  final path = await ref.read(fileSaverProvider)(
    bytes: utf8.encode(content),
    fileName: fileName,
  );
  if (!context.mounted) return path;
  if (path == null) {
    AppSnack.error(context, l10n.commonSaveFailed);
  } else {
    AppSnack.success(
        context, l10n.commonSavedTo(path));
  }
  return path;
}

/// Asks for a design file and returns its bands, or null when the pick
/// was cancelled or the file was refused (the reason is shown).
Future<ReportBands?> importReportDesign(
  BuildContext context,
  WidgetRef ref, {
  required ReportKind kind,
  required int reminderLevels,
}) async {
  final l10n = context.l10n;
  final file = await ref.read(filePickerProvider)(XTypeGroup(
    label: l10n.reportDesignFileTypeLabel,
    extensions: const ['json'],
    mimeTypes: const ['application/json'],
  ));
  if (file == null) return null; // cancelled
  // Explicit UTF-8: XFile.readAsString is not UTF-8-safe for data-backed
  // files, the same reason the workspace XML import decodes by hand.
  final content = utf8.decode(await file.readAsBytes());
  if (!context.mounted) return null;
  try {
    final design = parseReportDesignFile(
      content,
      expectedKind: kind,
      reminderLevels: reminderLevels,
    );
    return design.bands;
  } on ReportDesignException catch (e, st) {
    TraceLogger.instance.error(
        'money', 'report design import rejected: ${e.detail}',
        error: e, stackTrace: st);
    if (!context.mounted) return null;
    AppSnack.error(context, reportDesignErrorText(l10n, e.error));
    return null;
  }
}

/// One sentence per refusal, because "invalid file" tells the holder of
/// the file nothing about what to change.
String reportDesignErrorText(
        AppLocalizations l10n, ReportDesignError error) =>
    switch (error) {
      ReportDesignError.malformed =>
        l10n.reportDesignErrorMalformed,
      ReportDesignError.notADesignFile =>
        l10n.reportDesignErrorNotADesign,
      ReportDesignError.unsupportedVersion =>
        l10n.reportDesignErrorVersion,
      ReportDesignError.unknownKind =>
        l10n.reportDesignErrorUnknownKind,
      ReportDesignError.wrongKind =>
        l10n.reportDesignErrorWrongKind,
      ReportDesignError.invalidDesign =>
        l10n.reportDesignErrorInvalidDesign,
    };

/// The pair of actions, so the designer carries three lines rather than
/// twenty. Rendered only when the workspace has the feature — the caller
/// decides that, because it is the caller that watches the flags.
class ReportDesignExchangeButtons extends StatelessWidget {
  const ReportDesignExchangeButtons({
    super.key,
    required this.onExport,
    required this.onImport,
  });

  /// Null disables the button, which is how the designer says "busy".
  final VoidCallback? onExport;
  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      children: [
        TextButton.icon(
          key: const ValueKey('report-design-export'),
          icon: const Icon(Icons.file_upload_outlined),
          label: Text(l10n.reportDesignExport),
          onPressed: onExport,
        ),
        TextButton.icon(
          key: const ValueKey('report-design-import'),
          icon: const Icon(Icons.file_download_outlined),
          label: Text(l10n.reportDesignImport),
          onPressed: onImport,
        ),
      ],
    );
  }
}
