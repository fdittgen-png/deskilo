// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1915 (0327) — a rights request as the server records it: when it was
// received, by when the space answers (one calendar month, or the
// extended date with its reason), and what happened, store by store.
// And, before erasing, what goes and what stays.
import '../../../core/data/system_columns.dart';

/// The kinds of request the server accepts.
const rightsRequestKinds = [
  'access',
  'portability',
  'rectification',
  'restriction',
  'objection',
  'erasure',
];

DateTime? _date(Object? raw) {
  if (raw is! String) return null;
  final d = DateTime.parse(raw);
  return DateTime(d.year, d.month, d.day);
}

class RightsRequest implements SystemStamped {
  const RightsRequest({
    this.system = SystemColumns.none,
    required this.id,
    required this.kind,
    required this.status,
    required this.receivedAt,
    required this.dueOn,
    this.details = '',
    this.extendedDueOn,
    this.extensionReason,
    this.refusalReason,
    this.outcome = const {},
  });

  factory RightsRequest.fromJson(Map<String, dynamic> json) => RightsRequest(
    system: SystemColumns.fromRow(json),
    id: json['id'] as String,
    kind: json['kind'] as String,
    status: json['status'] as String? ?? 'received',
    receivedAt: DateTime.parse(json['received_at'] as String).toLocal(),
    dueOn: _date(json['due_on'])!,
    details: json['details'] as String? ?? '',
    extendedDueOn: _date(json['extended_due_on']),
    extensionReason: json['extension_reason'] as String?,
    refusalReason: json['refusal_reason'] as String?,
    outcome: json['outcome'] is Map
        ? Map<String, dynamic>.from(json['outcome'] as Map)
        : const {},
  );

  /// #992 — the server's stamp on this row.
  @override
  final SystemColumns system;

  final String id;
  final String kind;

  /// `received`, `extended`, `completed` or `refused`.
  final String status;
  final DateTime receivedAt;
  final DateTime dueOn;
  final String details;
  final DateTime? extendedDueOn;
  final String? extensionReason;
  final String? refusalReason;

  /// removed / corrected / restricted / retained / pending_external /
  /// failed → the stores, as the controller recorded them.
  final Map<String, dynamic> outcome;

  /// The date the answer is due now: the extended one when extended.
  DateTime get answerBy => extendedDueOn ?? dueOn;
}

/// One store in an erasure preview.
class ErasureStore {
  const ErasureStore({
    required this.store,
    this.count,
    this.basis,
    this.period,
    this.note,
  });

  factory ErasureStore.fromJson(Map<String, dynamic> json) => ErasureStore(
    store: json['store'] as String? ?? '',
    count: (json['count'] as num?)?.toInt(),
    basis: json['basis'] as String?,
    period: json['period'] as String?,
    note: json['note'] as String?,
  );

  final String store;
  final int? count;
  final String? basis;
  final String? period;
  final String? note;
}

/// `preview_my_erasure`: what erasing would remove, restrict, keep (with
/// basis and period) and what lies outside this installation.
class ErasurePreview {
  const ErasurePreview({
    this.removed = const [],
    this.restricted = const [],
    this.retained = const [],
    this.pendingExternal = const [],
  });

  factory ErasurePreview.fromJson(Map<String, dynamic> json) {
    List<ErasureStore> list(String key) => [
      for (final e in (json[key] as List? ?? const []))
        ErasureStore.fromJson(Map<String, dynamic>.from(e as Map)),
    ];
    return ErasurePreview(
      removed: list('removed'),
      restricted: list('restricted'),
      retained: list('retained'),
      pendingExternal: list('pending_external'),
    );
  }

  final List<ErasureStore> removed;
  final List<ErasureStore> restricted;
  final List<ErasureStore> retained;
  final List<ErasureStore> pendingExternal;
}
