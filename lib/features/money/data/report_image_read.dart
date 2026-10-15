// SPDX-License-Identifier: AGPL-3.0-or-later

/// #2586 — one library image read, classified.
///
/// The old read caught every `StorageException` and returned null, so a
/// denied read, an expired session or a 500 rendered like a deleted
/// optional image and a complete-looking document. Here:
/// - null only for the Storage API's own not-found answer (status 404 /
///   error `not_found`; a private object the caller may not see answers the
///   same, so absence never leaks existence);
/// - 401/403 -> [ReportImageFailureKind.forbidden];
/// - any other storage status, a transport failure or a timeout ->
///   [ReportImageFailureKind.unavailable] (transport failures retried by
///   the existing bounded policy first; only this read is retried);
/// - bytes that are not a jpeg/png/webp/gif -> [ReportImageFailureKind.invalid].
library;

import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' show StorageException;

import '../../../core/data/retry.dart';
import '../domain/report_image_failure.dart';

/// Reads image [name] through [download].
Future<Uint8List?> readReportImage(
  String name,
  Future<Uint8List> Function() download, {
  List<Duration> delays = kRetryDelays,
}) async {
  final Uint8List bytes;
  try {
    bytes = await retryTransient('report image', download, delays: delays);
  } on StorageException catch (e, st) {
    final status = int.tryParse(e.statusCode ?? '');
    if (status == 404 || e.error == 'not_found') return null;
    throw ReportImageFailure(
      status == 401 || status == 403
          ? ReportImageFailureKind.forbidden
          : ReportImageFailureKind.unavailable,
      name,
      e,
      st,
    );
  } on Object catch (e, st) {
    throw ReportImageFailure(ReportImageFailureKind.unavailable, name, e, st);
  }
  if (!_looksLikeImage(bytes)) {
    throw ReportImageFailure(ReportImageFailureKind.invalid, name);
  }
  return bytes;
}

bool _looksLikeImage(Uint8List b) {
  bool at(int i, List<int> sig) {
    if (b.length < i + sig.length) return false;
    for (var k = 0; k < sig.length; k++) {
      if (b[i + k] != sig[k]) return false;
    }
    return true;
  }

  return at(0, const [0x89, 0x50, 0x4E, 0x47]) || // png
      at(0, const [0xFF, 0xD8, 0xFF]) || // jpeg
      at(0, const [0x47, 0x49, 0x46, 0x38]) || // gif
      (at(0, const [0x52, 0x49, 0x46, 0x46]) &&
          at(8, const [0x57, 0x45, 0x42, 0x50])); // webp
}
