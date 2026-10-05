// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/report_block_widgets.dart';
import 'invoice_documents.dart';
import '../../workspace/providers/workspace_providers.dart';

/// #671 — the cover page for a batch print, rendered from the report
/// editor's bands for [docId] through the same pipeline every other
/// document uses.
///
/// The shared workspace library supplies images to every cover band.
/// A workspace switch or closed dialog cancels the pending cover.
Future<({
  List<pw.Widget> header,
  List<pw.Widget> continuation,
  List<pw.Widget> body,
  List<pw.Widget> footer,
})?> batchCover(
  BuildContext context,
  WidgetRef ref, {
  required String docId,
  required Map<String, Object?> data,
}) async {
  final workspaceId = ref.read(currentWorkspaceProvider).value?.id;
  await warmLetterDocProviders(ref, docId);
  if (!context.mounted || ref.read(currentWorkspaceProvider).value?.id != workspaceId) return null;
  final report = renderLetterDoc(context, ref, docId: docId, data: data);
  final images = await resolveReportImages(ref, report);
  if (!context.mounted || ref.read(currentWorkspaceProvider).value?.id != workspaceId) return null;
  return (
    continuation: reportBlockWidgets(report.continuation, images: images),
    header: reportBlockWidgets(report.header, images: images),
    body: reportBlockWidgets(report.body, images: images),
    footer: reportBlockWidgets(report.footer, images: images),
  );
}
