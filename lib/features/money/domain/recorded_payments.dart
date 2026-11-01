// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2578 — the payments behind the collected figure
// (`workspace_recorded_payments_v1`, 0643): one row per payment a match
// consumed, in the window on the workspace clock, newest match first, one
// bounded page at a time. The same rows `finance.collected` sums.
import '../../../core/data/json_reader.dart';
import '../../../core/time/date_text.dart';

/// One payment a match consumed.
class RecordedPayment {
  const RecordedPayment({
    required this.id,
    required this.matchedAt,
    required this.amountMinor,
    required this.currency,
    required this.invoiceId,
    this.paidOn,
    this.invoiceNumber,
    this.payerName,
    this.resolution,
    this.label,
  });

  /// The match payment's id (the cursor's tie-break).
  final String id;

  /// When the match consumed the payment: the figure's date basis.
  final DateTime matchedAt;

  /// The day the payment was recorded as made, when the ledger names one.
  final DateTime? paidOn;

  /// Exact minor units, sent as a decimal string (the column is an int,
  /// so every value fits).
  final int amountMinor;
  final String currency;
  final String invoiceId;
  final String? invoiceNumber;

  /// The payer as the invoice names them.
  final String? payerName;

  /// How the match settled the invoice (exact, under_accepted, …).
  final String? resolution;

  /// The payment's own description as it was recorded.
  final String? label;

  factory RecordedPayment.fromJson(JsonReader r) {
    final paidOn = r.stringOrNull('paid_on');
    return RecordedPayment(
      id: r.string('id'),
      matchedAt: r.dateTime('matched_at'),
      paidOn: paidOn == null ? null : DateTime.tryParse(paidOn),
      amountMinor: _minor(r, 'amount_minor'),
      currency: r.string('currency'),
      invoiceId: r.string('invoice_id'),
      invoiceNumber: r.stringOrNull('invoice_number'),
      payerName: r.stringOrNull('payer_name'),
      resolution: r.stringOrNull('resolution'),
      label: r.stringOrNull('label'),
    );
  }
}

/// A non-negative amount in minor units, as the decimal string the server
/// sends; anything else is a shape error, never a zero.
int _minor(JsonReader r, String key) {
  final text = r.string(key);
  final value = RegExp(r'^[0-9]{1,15}$').hasMatch(text)
      ? int.parse(text)
      : null;
  return value ??
      (throw JsonShapeException(r.context, key, 'decimal String', text));
}

/// Where the next page starts: the last row's keys, as the server sent them.
class RecordedPaymentsCursor {
  const RecordedPaymentsCursor({required this.matchedAt, required this.id});

  /// The server's own text of the instant, sent back unchanged so no
  /// precision is lost between pages.
  final String matchedAt;
  final String id;

  Map<String, Object?> toJson() => {'matched_at': matchedAt, 'id': id};

  static RecordedPaymentsCursor? fromJson(JsonReader? r) => r == null
      ? null
      : RecordedPaymentsCursor(
          matchedAt: r.string('matched_at'),
          id: r.string('id'),
        );
}

/// One page of the read.
class RecordedPaymentsPage {
  const RecordedPaymentsPage({
    required this.items,
    required this.pageSize,
    this.timezone,
    this.nextCursor,
  });

  final List<RecordedPayment> items;

  /// The page size the server applied (the registry's, or fewer).
  final int pageSize;

  /// The workspace clock the window was read on.
  final String? timezone;

  /// Null on the last page.
  final RecordedPaymentsCursor? nextCursor;

  bool get hasMore => nextCursor != null;

  factory RecordedPaymentsPage.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'workspace_recorded_payments_v1');
    return RecordedPaymentsPage(
      items: r.objects('items', RecordedPayment.fromJson),
      pageSize: r.integer('page_size'),
      timezone: r.stringOrNull('timezone'),
      nextCursor: RecordedPaymentsCursor.fromJson(
        r.objectOrNull('next_cursor'),
      ),
    );
  }
}

/// The reader may not see the space's payments (42501).
class RecordedPaymentsForbidden implements Exception {
  const RecordedPaymentsForbidden();
}

/// Money is switched off in the space (55000).
class RecordedPaymentsSwitchedOff implements Exception {
  const RecordedPaymentsSwitchedOff();
}

abstract interface class RecordedPaymentsRepository {
  /// One page of the payments matched between [from] and [to], both local
  /// days of the workspace clock and both included. [after] continues a
  /// read; [limit] asks for fewer rows than the workspace's page size.
  Future<RecordedPaymentsPage> page(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
    RecordedPaymentsCursor? after,
    int? limit,
  });
}

/// The RPC's parameters for one page: the days as ISO dates.
Map<String, Object?> recordedPaymentsParams(
  String workspaceId, {
  required DateTime from,
  required DateTime to,
  RecordedPaymentsCursor? after,
  int? limit,
}) => {
  'p_workspace_id': workspaceId,
  'p_from': isoDay(from),
  'p_to': isoDay(to),
  'p_after': after?.toJson(),
  'p_limit': limit,
};
