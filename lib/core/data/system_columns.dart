// SPDX-License-Identifier: 0BSD
import 'package:flutter/foundation.dart';

/// #992 — the six system columns every table carries, as ONE value.
///
/// The server owns them (migrations 0183/0184): a trigger stamps the
/// creation and the modification, derives the workspace and the site
/// from the row's own keys, and ignores whatever a client sends. The app
/// therefore only READS them — through this value object, never as loose
/// map keys — and never writes them: `test/lint/system_columns_test.dart`
/// refuses a payload that names one of the six.
///
/// Patterns: **Value Object** (immutable, equal by value), **Null Object**
/// ([none] for a row the server never stamped — fakes, fixtures, rows
/// older than the columns), **Factory** ([fromRow], tolerant: a missing
/// or malformed column degrades to [none], never to a crash on read), and
/// an **Observer** hook ([onBreach]) the app wires to its trace so a row
/// that breaks the invariants is reported, not trusted.
@immutable
class SystemColumns {
  const SystemColumns({
    this.createdAt,
    this.modifiedAt,
    this.companyId = '',
    this.siteId = '',
    this.createdByUser = '',
    this.modifiedByUser = '',
  });

  /// A row the server never stamped.
  static const none = SystemColumns();

  /// The column names, spelled the schema's way. The only place they are
  /// written down on the client.
  static const keys = [
    'created_datetime',
    'modified_datetime',
    'company_id',
    'site_id',
    'created_by_user',
    'modified_by_user',
  ];

  /// Where a read finds the invariants broken. Wired once, at start-up,
  /// to the trace; null keeps reads silent (tests).
  static void Function(String detail)? onBreach;

  /// Reads the six out of a table row. Never throws: an entity is not
  /// unreadable because its stamp is.
  factory SystemColumns.fromRow(Map<dynamic, dynamic> row) {
    DateTime? at(String key) {
      final value = row[key];
      return value is String ? DateTime.tryParse(value)?.toUtc() : null;
    }

    String id(String key) {
      final value = row[key];
      return value is String ? value : '';
    }

    final columns = SystemColumns(
      createdAt: at('created_datetime'),
      modifiedAt: at('modified_datetime'),
      companyId: id('company_id'),
      siteId: id('site_id'),
      createdByUser: id('created_by_user'),
      modifiedByUser: id('modified_by_user'),
    );
    if (!columns.isConsistent) {
      final workspace = row['workspace_id'];
      onBreach?.call(
        'system columns inconsistent: modified ${columns.modifiedAt} before '
        'created ${columns.createdAt} on row ${row['id']} of $workspace',
      );
    }
    return columns;
  }

  /// When the row was created (UTC); null for [none].
  final DateTime? createdAt;

  /// When the row was last written (UTC); null for [none].
  final DateTime? modifiedAt;

  /// The workspace the row belongs to ('' when the table has none, e.g.
  /// profiles).
  final String companyId;

  /// The site the row stands at ('' when none).
  final String siteId;

  /// Who created the row ('' for the system or [none]).
  final String createdByUser;

  /// Who last wrote the row ('' for the system or [none]).
  final String modifiedByUser;

  /// Whether the server stamped this row at all.
  bool get isStamped => createdAt != null;

  /// The invariant the server guarantees: never modified before created.
  bool get isConsistent =>
      createdAt == null ||
      modifiedAt == null ||
      !modifiedAt!.isBefore(createdAt!);

  /// Whether the row belongs to [workspaceId] — true for an unstamped row,
  /// which says nothing either way.
  bool belongsTo(String workspaceId) =>
      companyId.isEmpty || companyId == workspaceId;

  /// Removes the six from an outgoing payload. The server ignores them
  /// anyway; this keeps the client honest at the seam.
  static Map<String, dynamic> strip(Map<String, dynamic> payload) => {
        for (final entry in payload.entries)
          if (!keys.contains(entry.key)) entry.key: entry.value,
      };

  @override
  bool operator ==(Object other) =>
      other is SystemColumns &&
      other.createdAt == createdAt &&
      other.modifiedAt == modifiedAt &&
      other.companyId == companyId &&
      other.siteId == siteId &&
      other.createdByUser == createdByUser &&
      other.modifiedByUser == modifiedByUser;

  @override
  int get hashCode => Object.hash(
      createdAt, modifiedAt, companyId, siteId, createdByUser, modifiedByUser);

  @override
  String toString() => 'SystemColumns(created $createdAt by $createdByUser, '
      'modified $modifiedAt by $modifiedByUser, company $companyId, '
      'site $siteId)';
}

/// Every entity mapped from a table row exposes its stamp — the one
/// interface the lint checks a row mapper against.
abstract interface class SystemStamped {
  SystemColumns get system;
}
