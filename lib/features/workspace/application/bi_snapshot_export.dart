// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Taking the one snapshot an export is made of. The server answers the
// planned figures once, under the reader's current right to export and to
// read each figure; an answer that arrives after the account changed is
// dropped, never shown to the next person. The preview, the PDF and the
// data files are then made from the snapshot alone.
import '../domain/bi_report_snapshot.dart';

class BiSnapshotExport {
  BiSnapshotExport(this._repository, {required this.isCurrent});

  final BiExportRepository _repository;

  /// Whether the account that asked is still the one signed in.
  final bool Function() isCurrent;

  /// The snapshot of [plan] for [format]. Throws [BiExportRefused].
  Future<BiReportSnapshot> take(
    BiSnapshotPlan plan, {
    required BiSnapshotSource source,
    required BiExportFormat format,
  }) async {
    final answer = await _repository.snapshot(
      source.workspaceId,
      requests: plan.requests,
      format: format,
      reportId: source.reportId,
      reportRevision: source.reportRevision,
    );
    if (!isCurrent()) throw const BiExportRefused(BiExportFailure.stale);
    return biReportSnapshotOf(plan, answer, source: source, format: format);
  }
}
