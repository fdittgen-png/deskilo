// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4431 (G17) -- the expiry report as the stock reads it: every lot on hand (and every piece of an item tracked piece by piece)
// that is expired before a reference date or expires from it, one row each, sorted by date then place. The server answers a
// page at a time (`stock_expiry_report_v1`); the report keeps reading until it is complete or a bound is reached, and says so
// when it stopped at the bound.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

/// What the report lists.
enum ExpiryScope {
  expired,
  expiring,
  both;

  /// The word the server takes.
  String get wire => name;
}

/// The question of the report: the reference date (null: today on the business's calendar), what to list, how far ahead
/// (null: the business's setting), and optionally one place and one item group (with its sub-groups).
class ExpiryQuery {
  const ExpiryQuery({this.on, this.scope = ExpiryScope.both, this.horizonDays, this.locationId, this.groupId});

  final DateTime? on;
  final ExpiryScope scope;
  final int? horizonDays;
  final String? locationId;
  final String? groupId;

  @override
  bool operator ==(Object other) =>
      other is ExpiryQuery &&
      other.on == on &&
      other.scope == scope &&
      other.horizonDays == horizonDays &&
      other.locationId == locationId &&
      other.groupId == groupId;

  @override
  int get hashCode => Object.hash(on, scope, horizonDays, locationId, groupId);
}

/// One lot (or piece) on hand with its date.
class ExpiryRow {
  const ExpiryRow({
    required this.itemId,
    required this.itemName,
    required this.lotCode,
    required this.expiresOn,
    required this.days,
    required this.quantity,
    required this.unit,
    required this.locationCode,
    required this.locationName,
    this.variantLabel = '',
    this.pieceId,
    this.tag = '',
  });

  final String itemId;
  final String itemName;
  final String variantLabel;
  final String lotCode;
  final DateTime expiresOn;

  /// From the reference date to [expiresOn]: below zero, past.
  final int days;
  final ExactQuantity quantity;
  final String unit;
  final String locationCode;
  final String locationName;

  /// The piece this row is, for an item tracked piece by piece; null for a lot.
  final String? pieceId;

  /// The piece's tag, when it has one.
  final String tag;

  bool get isPiece => pieceId != null;

  factory ExpiryRow.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'stock_expiry_report.rows');
    return ExpiryRow(
      itemId: r.string('item_id'),
      itemName: r.stringOr('item_name'),
      variantLabel: r.stringOr('variant_label'),
      lotCode: r.stringOr('lot_code'),
      expiresOn: DateTime.parse(r.string('expires_on')),
      days: r.integer('days'),
      quantity: ExactQuantity.parse(r.string('quantity')),
      unit: r.stringOr('unit'),
      locationCode: r.stringOr('location_code'),
      locationName: r.stringOr('location_name'),
      pieceId: r.stringOrNull('piece_id'),
      tag: r.stringOr('tag'),
    );
  }
}

/// The answer: the rows, the reference date they were read for, and whether the bound cut the list.
class ExpiryReport {
  const ExpiryReport({required this.rows, this.asOf, this.cut = false});

  final List<ExpiryRow> rows;

  /// The reference date the server read for (today on the business's calendar when none was asked); null when the
  /// feature is off for the business and the answer is empty.
  final DateTime? asOf;
  final bool cut;
}

abstract interface class StockExpiry {
  /// The report of [query] for [workspaceId], at most [maxRows] rows (a list that goes beyond is cut and says so).
  Future<ExpiryReport> report(String workspaceId, ExpiryQuery query, {int maxRows = 2000});
}
