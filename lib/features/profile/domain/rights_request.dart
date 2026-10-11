// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1915 (0327) — a rights request as the server records it: when it was
// received, by when the space answers (one calendar month, or the
// extended date with its reason), and what happened, store by store.
// And, before erasing, what goes and what stays.
import '../../../core/data/json_reader.dart';
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

/// The calendar day of a `date` column, as a local midnight.
DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

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

  /// #2387 — read through [JsonReader]: a missing or mistyped column
  /// names [context] (the RPC), the key and the expected type.
  factory RightsRequest.fromJson(
    Map<String, dynamic> json, {
    String context = 'rights_request',
  }) {
    final r = JsonReader(json, context: context);
    final extended = r.dateTimeOrNull('extended_due_on');
    return RightsRequest(
      system: SystemColumns.fromRow(json),
      id: r.string('id'),
      kind: r.string('kind'),
      status: r.stringOr('status', 'received'),
      receivedAt: r.dateTime('received_at').toLocal(),
      dueOn: _day(r.dateTime('due_on')),
      details: r.stringOr('details'),
      extendedDueOn: extended == null ? null : _day(extended),
      extensionReason: r.stringOrNull('extension_reason'),
      refusalReason: r.stringOrNull('refusal_reason'),
      outcome: r.objectOrEmpty('outcome'),
    );
  }

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

  factory ErasureStore._read(JsonReader r) => ErasureStore(
    store: r.stringOr('store'),
    count: r.intOrNull('count'),
    basis: r.stringOrNull('basis'),
    period: r.stringOrNull('period'),
    note: r.stringOrNull('note'),
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

  factory ErasurePreview.fromJson(
    Map<String, dynamic> json, {
    String context = 'preview_my_erasure',
  }) {
    final r = JsonReader(json, context: context);
    return ErasurePreview(
      removed: r.objects('removed', ErasureStore._read),
      restricted: r.objects('restricted', ErasureStore._read),
      retained: r.objects('retained', ErasureStore._read),
      pendingExternal: r.objects('pending_external', ErasureStore._read),
    );
  }

  final List<ErasureStore> removed;
  final List<ErasureStore> restricted;
  final List<ErasureStore> retained;
  final List<ErasureStore> pendingExternal;
}
