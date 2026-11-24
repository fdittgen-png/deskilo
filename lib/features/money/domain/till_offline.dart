// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4373 (CS11) -- the till that keeps selling for cash when its connection is lost. A sale made offline is totalled on the device
// from the prices it held when it went offline, recorded with a device sequence number (gapless per till session) and sent in order
// when the connection returns; the server (`counter_offline_sync_v1`, contract section 7) checks every rule again. Nothing here
// takes anything but cash, claims a fiscal signature, or prices a line the device has no price for. Amounts are MINOR units.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show JsonReader;
import 'package:meta/meta.dart' show visibleForTesting;

import 'till_quantity.dart';

/// The price an item had when the till went offline: gross, minor units of one unit.
class OfflinePrice {
  const OfflinePrice({required this.itemId, required this.name, required this.unit, required this.grossMinor});

  final String itemId;
  final String name;
  final String unit;
  final int grossMinor;

  Map<String, Object?> toJson() => {'item_id': itemId, 'name': name, 'unit': unit, 'gross_minor': grossMinor};

  factory OfflinePrice.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'offline.price');
    return OfflinePrice(itemId: r.string('item_id'), name: r.stringOr('name'), unit: r.stringOr('unit'), grossMinor: r.integer('gross_minor'));
  }
}

/// A line of an offline sale: the item, its exact quantity and the unit price it was sold at.
class OfflineLine {
  const OfflineLine({required this.itemId, required this.name, required this.quantity, required this.unitMinor});

  final String itemId;
  final String name;
  final String quantity;
  final int unitMinor;

  /// The line's amount, half up once: null only for a quantity that is not one (never a line the till made).
  int get amountMinor => tillLineAmount(unitMinor, quantity) ?? 0;

  Map<String, Object?> toJson() => {'item_id': itemId, 'name': name, 'quantity': quantity, 'unit_minor': unitMinor};

  factory OfflineLine.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'offline.line');
    return OfflineLine(itemId: r.string('item_id'), name: r.stringOr('name'), quantity: r.string('quantity'), unitMinor: r.integer('unit_minor'));
  }
}

/// How often an offline till looks for its connection again: a technical interval, nothing a business sets.
const Duration kOfflineReconnectEvery = Duration(seconds: 20);

/// The reasons the device refuses to record a sale itself.
enum OfflineRefusal { noPrice, badQuantity, empty, cashShort }

/// A sale made offline, as the device keeps it until the server has answered.
class OfflineSale {
  const OfflineSale({
    required this.seq,
    required this.requestId,
    required this.occurredAt,
    required this.lines,
    required this.cashGivenMinor,
    required this.changeMinor,
    this.deviceId,
  });

  /// The device that made the sale, named once per device: the sequence number is unique per (session, device), so two devices of
  /// one session both number from 1. Null for a sale made before devices named themselves (the server reads the one legacy device).
  final String? deviceId;

  /// The device sequence number: 1, 2, 3 … within one till session, never reused, never skipped.
  final int seq;
  final String requestId;

  /// The device clock when the sale was made (UTC); the server records it and never uses it as the receipt's issue time.
  final DateTime occurredAt;
  final List<OfflineLine> lines;
  final int cashGivenMinor;
  final int changeMinor;

  int get totalMinor => lines.fold(0, (a, l) => a + l.amountMinor);

  /// The same sale, made by [id].
  OfflineSale madeBy(String id) => OfflineSale(
    seq: seq,
    requestId: requestId,
    occurredAt: occurredAt,
    lines: lines,
    cashGivenMinor: cashGivenMinor,
    changeMinor: changeMinor,
    deviceId: id,
  );

  /// The sale as `counter_offline_sync_v1` takes it: the unit price is in major units read on the gross basis.
  Map<String, Object?> toSyncJson({required int minorDigits}) => {
    'seq': seq,
    'request_id': requestId,
    'occurred_at': occurredAt.toUtc().toIso8601String(),
    'cash_given_minor': cashGivenMinor,
    'change_minor': changeMinor,
    if (deviceId != null) 'device_id': deviceId,
    'body': {
      'lines': [
        for (final l in lines) {'item_id': l.itemId, 'quantity': l.quantity, 'unit_price': majorText(l.unitMinor, minorDigits)},
      ],
    },
  };

  Map<String, Object?> toJson() => {
    'seq': seq,
    'request_id': requestId,
    'occurred_at': occurredAt.toUtc().toIso8601String(),
    'lines': [for (final l in lines) l.toJson()],
    'cash_given_minor': cashGivenMinor,
    'change_minor': changeMinor,
    if (deviceId != null) 'device_id': deviceId,
  };

  factory OfflineSale.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'offline.sale');
    return OfflineSale(
      seq: r.integer('seq'),
      requestId: r.string('request_id'),
      occurredAt: DateTime.parse(r.string('occurred_at')).toUtc(),
      lines: [for (final l in r.listOrAbsent('lines')) OfflineLine.fromJson(l)],
      cashGivenMinor: r.integer('cash_given_minor'),
      changeMinor: r.integer('change_minor'),
      deviceId: r.stringOrNull('device_id'),
    );
  }
}

/// [minor] as the decimal text of major units with exactly [digits] decimals (`120` with 2 is `1.20`).
@visibleForTesting
String majorText(int minor, int digits) {
  if (digits <= 0) return '$minor';
  final sign = minor < 0 ? '-' : '';
  final s = minor.abs().toString().padLeft(digits + 1, '0');
  return '$sign${s.substring(0, s.length - digits)}.${s.substring(s.length - digits)}';
}

/// What the server answered for one sale of a sync.
class OfflineSaleResult {
  const OfflineSaleResult({required this.seq, required this.requestId, required this.accepted, required this.reason, required this.number, required this.replayed});

  final int seq;
  final String requestId;
  final bool accepted;

  /// `session`, `before_session`, `too_long`, `too_many`, `clock`, `price`, `item`, `cash`, `refused:<code>`; empty when accepted.
  final String reason;
  final String number;
  final bool replayed;

  factory OfflineSaleResult.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'offline.result');
    return OfflineSaleResult(
      seq: r.integer('seq'),
      requestId: r.string('request_id'),
      accepted: r.string('state') == 'accepted',
      reason: r.stringOr('reason'),
      number: r.stringOr('number'),
      replayed: r.boolOr('replayed', fallback: false),
    );
  }
}

/// The answer of one sync: every sale's result and the sequence numbers the server finds missing.
class OfflineSyncAnswer {
  const OfflineSyncAnswer({required this.results, required this.gaps});

  final List<OfflineSaleResult> results;
  final List<int> gaps;

  int get acceptedCount => results.where((x) => x.accepted).length;
  List<OfflineSaleResult> get refused => [for (final x in results) if (!x.accepted) x];

  factory OfflineSyncAnswer.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'offline.sync');
    return OfflineSyncAnswer(
      results: [for (final x in r.listOrAbsent('results')) OfflineSaleResult.fromJson(x)],
      gaps: [for (final g in r.listOrAbsent('gaps')) _gapNumber(g)],
    );
  }
}

/// A sale of the owner's list, as the server holds it.
class OfflineSaleRow {
  const OfflineSaleRow({required this.seq, required this.accepted, required this.reason, required this.number, required this.totalMinor, required this.cashGivenMinor, required this.changeMinor, required this.occurredAt});

  final int seq;
  final bool accepted;
  final String reason;
  final String number;
  final int? totalMinor;
  final int cashGivenMinor;
  final int changeMinor;
  final DateTime occurredAt;

  /// Cash of a refused sale: it is in the drawer, so it is in the count.
  int get keptMinor => cashGivenMinor - changeMinor;

  factory OfflineSaleRow.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'offline.row');
    return OfflineSaleRow(
      seq: r.integer('seq'),
      accepted: r.string('state') == 'accepted',
      reason: r.stringOr('reason'),
      number: r.stringOr('number'),
      totalMinor: r.intOrNull('total_minor'),
      cashGivenMinor: r.integer('cash_given_minor'),
      changeMinor: r.integer('change_minor'),
      occurredAt: DateTime.parse(r.string('occurred_at')).toUtc(),
    );
  }
}

/// The sales of one till session as the server received them, and its gaps (`counter_offline_list_v1`).
class OfflineList {
  const OfflineList({required this.sales, required this.gaps});

  final List<OfflineSaleRow> sales;
  final List<int> gaps;

  List<OfflineSaleRow> get refused => [for (final s in sales) if (!s.accepted) s];

  factory OfflineList.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'offline.list');
    return OfflineList(
      sales: [for (final s in r.listOrAbsent('sales')) OfflineSaleRow.fromJson(s)],
      gaps: [for (final g in r.listOrAbsent('gaps')) _gapNumber(g)],
    );
  }
}

/// A missing sequence number as the server lists it: a number, or `{device_id, seq}` once sales name their device.
int _gapNumber(Object? gap) => gap is num ? gap.toInt() : JsonReader.of(gap, context: 'offline.gap').integer('seq');

/// The server side of the offline sales.
abstract interface class TillOfflinePort {
  Future<OfflineSyncAnswer> sync(String workspaceId, {required String sessionId, required DateTime offlineSince, required List<OfflineSale> sales, required int minorDigits});

  Future<OfflineList> list(String workspaceId, {required String sessionId});
}
