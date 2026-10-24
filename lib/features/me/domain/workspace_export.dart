// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2557 C3 — my own records in ONE workspace, as `export_my_data` answers
// them on that workspace's host: my membership, reservations, ledger,
// invoices and the rest the subject-access export carries. Never the
// personal home's part (conversations, privacy): that is exported there.
//
// Each workspace is its own source: it is asked on its own verified host,
// and it succeeds, is refused or does not answer on its own. The file is
// the host's answer itself, unchanged; an answer that does not say when it
// was made, or carries no member, is refused as malformed and offers no
// file.
import 'dart:convert';
import 'dart:typed_data';

import '../../../core/files/file_names.dart';

/// One workspace whose own-data export the person may ask for: the
/// installation that hosts it, its local id there, and its name where the
/// person may read it.
final class WorkspaceExportSource {
  const WorkspaceExportSource({
    required this.installationId,
    required this.workspaceId,
    this.hostedHere = false,
    this.label,
  });

  final String installationId;
  final String workspaceId;

  /// The workspace lives on the installation the personal home is.
  final bool hostedHere;

  /// The workspace's name, null when the person may not read it.
  final String? label;

  @override
  bool operator ==(Object other) =>
      other is WorkspaceExportSource &&
      other.installationId == installationId &&
      other.workspaceId == workspaceId &&
      other.hostedHere == hostedHere &&
      other.label == label;

  @override
  int get hashCode =>
      Object.hash(installationId, workspaceId, hostedHere, label);
}

/// Why a workspace gave no export.
enum WorkspaceExportFailure {
  /// The workspace's host is not connected here, or is not who it claims.
  hostUnavailable,

  /// The workspace has the data export switched off.
  disabled,

  /// The host refused: the person is not a member there (any more).
  forbidden,

  /// The answer is not an own-data export this app can read.
  malformed,

  /// The host did not answer.
  failed;

  /// Whether asking again can change the answer.
  bool get retryable => this == hostUnavailable || this == failed;
}

/// The workspace's host answered, and the answer is not an export.
final class WorkspaceExportRefused implements Exception {
  const WorkspaceExportRefused(this.failure, {this.detail});

  final WorkspaceExportFailure failure;
  final String? detail;

  @override
  String toString() => 'WorkspaceExportRefused(${failure.name}: $detail)';
}

/// One workspace's export of my own records, as its host answered it.
final class WorkspaceExport {
  WorkspaceExport._(this.source, this.document, this.exportedAt);

  final WorkspaceExportSource source;

  /// The whole answer, as it came: the file's content.
  final Map<String, Object?> document;

  /// When the host produced it, by its own clock.
  final DateTime exportedAt;

  /// Decodes [raw] for [source]; no time or no member is malformed.
  static WorkspaceExport decode(WorkspaceExportSource source, Object? raw) {
    WorkspaceExportRefused malformed(String detail) => WorkspaceExportRefused(
      WorkspaceExportFailure.malformed,
      detail: detail,
    );
    if (raw is! Map) throw malformed('not an object');
    final document = Map<String, Object?>.from(raw);
    final at = document['exported_at'];
    final exportedAt = at is String ? DateTime.tryParse(at) : null;
    if (exportedAt == null) throw malformed('exported_at $at');
    if (document['member'] is! Map) throw malformed('member');
    return WorkspaceExport._(source, Map.unmodifiable(document), exportedAt);
  }

  /// How many records the list [section] holds; 0 when absent.
  int count(String section) {
    final value = document[section];
    return value is List ? value.length : 0;
  }

  /// The file: the answer as indented JSON, UTF-8.
  Uint8List bytes() => Uint8List.fromList(
    utf8.encode(const JsonEncoder.withIndent('  ').convert(document)),
  );

  /// The file's name: the workspace (by name, else by id) and the export's
  /// own day, so two workspaces' files never take each other's place.
  String get fileName {
    final label = source.label;
    final which = safeFileSlug(
      label == null || label.trim().isEmpty ? source.workspaceId : label,
    );
    final day = exportedAt.toIso8601String().substring(0, 10);
    return 'deskilo-my-data-$which-$day.json';
  }
}

/// Reads one workspace's own-data export on that workspace's host.
abstract interface class WorkspaceExportRepository {
  /// The export of [source]; [WorkspaceExportRefused] when the host says no.
  Future<WorkspaceExport> export(WorkspaceExportSource source);
}
