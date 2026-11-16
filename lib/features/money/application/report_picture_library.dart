// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3984 — the report-picture library's writes: a picture is brought to print
// size before it is stored, and the pictures already stored over the weight
// are found from the storage listing and replaced one by one. A picture is
// replaced only after its new version is written (an upsert under the same
// name), so a failed write leaves the stored picture as it was.
import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/images/report_picture_bytes.dart';
import '../../../core/images/report_picture_sizes.dart';
import '../domain/report_template_repository.dart';
import '../providers/money_queries_providers.dart';

part 'report_picture_library.g.dart';

class ReportPictureLibrary {
  const ReportPictureLibrary(this._library);

  final ReportTemplateRepository _library;

  /// Stores [bytes] under [name] at print size. Throws
  /// [ReportPictureException] for bytes that are no picture, and whatever the
  /// repository throws.
  Future<void> add(
    String workspaceId, {
    required String name,
    required Uint8List bytes,
  }) async {
    final picture = await reportPictureForPrint(bytes);
    await _library.uploadReportImage(
      workspaceId,
      name: name,
      bytes: picture.bytes,
      contentType: picture.contentType,
    );
  }

  /// The stored pictures over the weight, by name, from the listing's sizes
  /// (nothing is downloaded).
  Future<List<String>> overWeight(String workspaceId) async {
    final weights = await _library.reportImageWeights(workspaceId);
    return [
      for (final e in weights.entries)
        if (e.value > reportPictureMaxBytes) e.key,
    ]..sort();
  }

  /// Brings each of [names] to print size, one by one, and returns those
  /// that could not be: a picture is replaced only once its new version is
  /// written, and one whose new version would not be lighter is left alone.
  /// [onReplaced] is told of each one replaced.
  Future<List<String>> bringToPrint(
    String workspaceId,
    List<String> names, {
    required void Function(String name) onReplaced,
  }) async {
    final failed = <String>[];
    for (final name in names) {
      try {
        final stored = await _library.fetchReportImage(workspaceId, name);
        if (stored == null) {
          failed.add(name);
          continue;
        }
        final made = await reportPictureForPrint(stored);
        if (made.bytes.lengthInBytes >= stored.lengthInBytes) {
          failed.add(name);
          continue;
        }
        await _library.uploadReportImage(
          workspaceId,
          name: name,
          bytes: made.bytes,
          contentType: made.contentType,
        );
        onReplaced(name);
      } on Object {
        // trace-exempt: a picture that cannot be replaced is named to the
        // person and stays as it was stored.
        failed.add(name);
      }
    }
    return failed;
  }
}

/// The picture library's writes.
@riverpod
ReportPictureLibrary reportPictureLibrary(Ref ref) =>
    ReportPictureLibrary(ref.watch(reportTemplateRepositoryProvider));
