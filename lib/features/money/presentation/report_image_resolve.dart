// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2586 — the report images a rendered report names, resolved to bytes.
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/trace/trace_logger.dart';
import '../domain/invoice_report.dart';
import '../domain/report_image_failure.dart';
import '../providers/money_providers.dart';

/// Resolves every `![name]` a rendered report references to bytes
/// (#488). An optional image that is truly absent (null) is skipped: the
/// document renders without it.
///
/// #2586 — a read that was DENIED, unavailable or returned invalid bytes
/// is not an absent image. With [strict] (a final export) the first such
/// failure is rethrown as a [ReportImageFailure] naming the image, so the
/// export fails visibly instead of announcing a complete document; without
/// it (a preview) the image is left out and the failure traced.
Future<Map<String, Uint8List>> resolveReportImages(
  WidgetRef ref,
  InvoiceReport? report, {
  bool strict = false,
}) async {
  if (report == null) return const {};
  final images = <String, Uint8List>{};
  ReportImageFailure? failure;
  for (final name in reportImageRefs(report)) {
    try {
      final bytes = await ref.read(reportImageBytesProvider(name).future);
      if (bytes != null) images[name] = bytes;
    } on Object catch (e, st) {
      TraceLogger.instance.warn(
        'money',
        'report image fetch failed',
        error: e,
        stackTrace: st,
      );
      failure ??= e is ReportImageFailure
          ? e
          : ReportImageFailure(ReportImageFailureKind.unavailable, name, e);
    }
  }
  if (strict && failure != null) throw failure;
  return images;
}
