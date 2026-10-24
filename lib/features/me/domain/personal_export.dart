// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2557 C2 — the personal part of my data, as `export_my_personal_data_v1()`
// (0566) answers it on my personal home with no workspace: my account, my
// preferences, my conversations and the workspaces I name by reference.
// Never a workspace's records: each workspace exports its own on its host.
//
// The decoding is strict about what it claims: the answer must say it is a
// personal export of a version this app knows, or it is refused as
// malformed and nothing is offered as a file. The file is the answer
// itself, unchanged, so what the person keeps is what the home said.
import 'dart:convert';
import 'dart:typed_data';

/// Why the personal home gave no export.
enum PersonalExportFailure {
  /// The home does not have the reader (an older installation).
  unsupported,

  /// The session may not read it (not signed in, or not a native session).
  forbidden,

  /// The answer is not a personal export this app can read.
  malformed,
}

/// The personal home answered, and the answer is not an export.
final class PersonalExportRefused implements Exception {
  const PersonalExportRefused(this.failure, {this.detail});

  final PersonalExportFailure failure;
  final String? detail;

  @override
  String toString() => 'PersonalExportRefused(${failure.name}: $detail)';
}

/// The wire format and version this app reads.
const String personalExportFormat = 'deskilo.personal-export';
const int personalExportVersion = 1;

/// One personal export, as the home answered it.
final class PersonalExport {
  PersonalExport._(this.document, this.exportedAt);

  /// The whole answer, as it came: the file's content.
  final Map<String, Object?> document;

  /// When the home produced it, by its own clock.
  final DateTime exportedAt;

  /// Decodes [raw]; a wrong format, version or time is [PersonalExportRefused].
  static PersonalExport decode(Object? raw) {
    PersonalExportRefused malformed(String detail) =>
        PersonalExportRefused(PersonalExportFailure.malformed, detail: detail);
    if (raw is! Map) throw malformed('not an object');
    final document = Map<String, Object?>.from(raw);
    if (document['format'] != personalExportFormat) {
      throw malformed('format ${document['format']}');
    }
    if (document['version'] != personalExportVersion) {
      throw malformed('version ${document['version']}');
    }
    final at = document['exported_at'];
    final exportedAt = at is String ? DateTime.tryParse(at) : null;
    if (exportedAt == null) throw malformed('exported_at $at');
    return PersonalExport._(Map.unmodifiable(document), exportedAt);
  }

  /// How many records the list [section] holds; 0 when it is absent or
  /// not a list (a section the home does not hold is not an error).
  int count(String section) {
    final value = document[section];
    return value is List ? value.length : 0;
  }

  int get conversations => count('account_conversations');
  int get messages =>
      count('account_messages') + count('account_group_messages');
  int get workspaces => count('workspace_refs');

  /// The file: the answer as indented JSON, UTF-8.
  Uint8List bytes() => Uint8List.fromList(
    utf8.encode(const JsonEncoder.withIndent('  ').convert(document)),
  );

  /// The file's name, dated by the export's own day.
  String get fileName =>
      'deskilo-personal-data-${exportedAt.toIso8601String().substring(0, 10)}.json';
}
