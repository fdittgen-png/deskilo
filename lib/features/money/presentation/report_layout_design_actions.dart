// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #875 — export and import of a positioned layout, as user actions.
//
// The XML twin of exportReportDesign/importReportDesign: the same file
// saver and picker, the same snacks, the same error vocabulary
// (ReportDesignError) so the import dialog speaks one language for both
// formats. Kept in its own file so report_design_actions.dart stays
// about the JSON bands and neither outgrows its budget.
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/files/file_drop.dart';
import '../../../core/files/file_picker.dart';
import '../../../core/files/file_saver.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/ui/app_snack.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/report_design_file.dart';
import '../domain/report_kind.dart';
import '../domain/report_layout_file.dart';
import 'report_design_actions.dart' show reportDesignErrorText;

Future<String?> exportReportLayout(
  BuildContext context,
  WidgetRef ref, {
  required ReportKind kind,
  required String language,
  required String workspaceName,
  required String layoutXml,
  required DateTime exportedAt,
  Map<String, String> texts = const {},
}) async {
  final l10n = context.l10n;
  final content = buildReportLayoutFile(
    kind: kind,
    language: language,
    texts: texts,
    workspaceName: workspaceName,
    layoutXml: layoutXml,
    exportedAt: exportedAt,
  );
  final fileName = reportLayoutFileName(
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
    AppSnack.success(context, l10n.commonSavedTo(path));
  }
  return path;
}

/// What a layout file is: the same group for the picker and the drop.
XTypeGroup _reportLayoutTypes(AppLocalizations l10n) => XTypeGroup(
  label: l10n.reportLayoutFileTypeLabel,
  extensions: const ['xml'],
  mimeTypes: const ['application/xml', 'text/xml'],
);

/// #3818 — [child] also takes a layout file dropped onto it, handed to
/// [onFile]: the editor's layout import.
class ReportLayoutDropZone extends StatelessWidget {
  const ReportLayoutDropZone({
    required this.onFile,
    required this.enabled,
    required this.child,
    super.key,
  });

  final Future<void> Function(XFile file) onFile;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) => FileDropZone(
    typeGroup: _reportLayoutTypes(context.l10n),
    onFile: onFile,
    enabled: enabled,
    child: child,
  );
}

/// Picks a layout file and returns its `<report-layout>` XML, or null
/// when cancelled or refused (the refusal is shown, with its reason). A
/// file already in hand ([dropped], #3818) skips the picker.
Future<ReportLayoutFile?> importReportLayout(
  BuildContext context,
  WidgetRef ref, {
  required ReportKind kind,
  required int reminderLevels,
  XFile? dropped,
}) async {
  final l10n = context.l10n;
  final file =
      dropped ?? await ref.read(filePickerProvider)(_reportLayoutTypes(l10n));
  if (file == null) return null; // cancelled
  final content = utf8.decode(await file.readAsBytes());
  try {
    final parsed = parseReportLayoutFile(content,
        expectedKind: kind, reminderLevels: reminderLevels);
    return parsed;
  } on ReportDesignException catch (e, st) {
    // trace-exempt: a refused file is the user's to see, not a fault to
    // trace — the reason is shown in the snack, in their language.
    assert(st.toString().isNotEmpty, 'a caught error has a stack');
    if (context.mounted) {
      AppSnack.error(context, reportDesignErrorText(l10n, e.error));
    }
    return null;
  }
}
