// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4373 (CS11) -- what the till keeps on the device while it is offline: the prices it held when it went offline, the device
// sequence number of the session, and the cash sales not yet sent. It totals a basket from those prices only, refuses what the
// server would refuse anyway (a line with no price, a quantity that is not one, cash short of the total), and sends the sales in
// order under the request id each was made with, so a retry never counts one twice. The sales are wiped from the device once the
// server has answered all of them; the sequence number stays for the session (no card data is ever held here).
import 'dart:convert';

import 'till_offline.dart';
import 'till_quantity.dart';

/// Where the device keeps the offline state: the app's encrypted store; a test keeps it in memory.
abstract interface class OfflineStore {
  Future<String?> read();
  Future<void> write(String json);
  Future<void> wipe();
}

/// The sale could not be recorded: [refusal] says why (a typed basket is never lost: it stays in the till).
class OfflineRecordRefused implements Exception {
  const OfflineRecordRefused(this.refusal);

  final OfflineRefusal refusal;
}

/// One line the till asks to ring up offline: an item and its exact quantity text.
class OfflineBasketLine {
  const OfflineBasketLine({required this.itemId, required this.quantity});

  final String itemId;
  final String quantity;
}

class TillOfflineQueue {
  TillOfflineQueue({required OfflineStore store, required String Function() newRequestId}) : _store = store, _newRequestId = newRequestId;

  static const int _version = 1;
  static const int _batch = 200;

  final OfflineStore _store;
  final String Function() _newRequestId;

  String? _sessionId;
  DateTime? _offlineSince;
  int _nextSeq = 1;
  final Map<String, OfflinePrice> _prices = {};
  final List<OfflineSale> _pending = [];
  bool _loaded = false;

  String? get sessionId => _sessionId;
  DateTime? get offlineSince => _offlineSince;
  List<OfflineSale> get pending => List.unmodifiable(_pending);
  bool get hasPending => _pending.isNotEmpty;
  Map<String, OfflinePrice> get prices => Map.unmodifiable(_prices);

  /// What the sales waiting add up to: the cash that is in the drawer and not yet on the server.
  int get pendingKeptMinor => _pending.fold(0, (a, s) => a + s.totalMinor);

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final raw = await _store.read();
    if (raw == null) return;
    final j = jsonDecode(raw);
    if (j is! Map || j['v'] != _version) return;
    _sessionId = j['session_id'] as String?;
    _offlineSince = j['offline_since'] == null ? null : DateTime.parse(j['offline_since'] as String).toUtc();
    _nextSeq = (j['next_seq'] as num?)?.toInt() ?? 1;
    for (final p in (j['prices'] as List? ?? const [])) {
      final price = OfflinePrice.fromJson(p);
      _prices[price.itemId] = price;
    }
    for (final s in (j['sales'] as List? ?? const [])) {
      _pending.add(OfflineSale.fromJson(s));
    }
  }

  Future<void> _save() => _store.write(jsonEncode({
    'v': _version,
    'session_id': _sessionId,
    'offline_since': _offlineSince?.toUtc().toIso8601String(),
    'next_seq': _nextSeq,
    'prices': [for (final p in _prices.values) p.toJson()],
    'sales': [for (final s in _pending) s.toJson()],
  }));

  /// The till is online: the prices it will fall back on are the ones it just read.
  Future<void> cachePrices(Iterable<OfflinePrice> prices) async {
    await load();
    _prices
      ..clear()
      ..addEntries([for (final p in prices) MapEntry(p.itemId, p)]);
    await _save();
  }

  /// The till lost its connection in [sessionId] at [now]. Sales already waiting keep their numbers; a new session starts at 1.
  Future<void> goOffline({required String sessionId, required DateTime now}) async {
    await load();
    if (_sessionId != sessionId) {
      _pending.clear();
      _nextSeq = 1;
      _sessionId = sessionId;
    }
    _offlineSince ??= now.toUtc();
    await _save();
  }

  /// Totals [basket] on the cached prices, or null when a line has no price or no valid quantity.
  List<OfflineLine>? price(List<OfflineBasketLine> basket) {
    if (basket.isEmpty) return null;
    final lines = <OfflineLine>[];
    for (final b in basket) {
      final price = _prices[b.itemId];
      if (price == null || tillLineAmount(price.grossMinor, b.quantity) == null) return null;
      lines.add(OfflineLine(itemId: b.itemId, name: price.name, quantity: b.quantity, unitMinor: price.grossMinor));
    }
    return lines;
  }

  /// Records a cash sale of [basket] with [cashGivenMinor] handed over. Throws [OfflineRecordRefused] and records nothing when it
  /// cannot be made.
  Future<OfflineSale> record({required List<OfflineBasketLine> basket, required int cashGivenMinor, required DateTime now}) async {
    await load();
    if (_sessionId == null) throw const OfflineRecordRefused(OfflineRefusal.empty);
    if (basket.isEmpty) throw const OfflineRecordRefused(OfflineRefusal.empty);
    for (final b in basket) {
      if (!_prices.containsKey(b.itemId)) throw const OfflineRecordRefused(OfflineRefusal.noPrice);
      if (tillQuantityOf(b.quantity) == null) throw const OfflineRecordRefused(OfflineRefusal.badQuantity);
    }
    final lines = price(basket)!;
    final total = lines.fold<int>(0, (a, l) => a + l.amountMinor);
    if (cashGivenMinor < total) throw const OfflineRecordRefused(OfflineRefusal.cashShort);
    final sale = OfflineSale(
      seq: _nextSeq,
      requestId: _newRequestId(),
      occurredAt: now.toUtc(),
      lines: lines,
      cashGivenMinor: cashGivenMinor,
      changeMinor: cashGivenMinor - total,
    );
    _nextSeq++;
    _pending.add(sale);
    await _save();
    return sale;
  }

  /// The connection is back and nothing waits: the offline period is over.
  Future<void> backOnline() async {
    await load();
    if (_pending.isEmpty) _offlineSince = null;
    await _save();
  }

  /// Sends what waits, in order, [_batch] at a time. A connection that fails throws and leaves what was not answered where it
  /// was (the same request ids go again); once the server has answered a sale, accepted or refused, it leaves the device.
  /// Returns the answers, or null when there was nothing to send.
  Future<OfflineSyncAnswer?> sync(TillOfflinePort port, {required String workspaceId, required int minorDigits}) async {
    await load();
    final session = _sessionId;
    final since = _offlineSince;
    if (session == null || since == null || _pending.isEmpty) return null;
    final results = <OfflineSaleResult>[];
    var gaps = const <int>[];
    try {
      while (_pending.isNotEmpty) {
        final batch = _pending.take(_batch).toList();
        final answer = await port.sync(workspaceId, sessionId: session, offlineSince: since, sales: batch, minorDigits: minorDigits);
        final answered = {for (final r in answer.results) r.requestId};
        if (answered.isEmpty) break;
        _pending.removeWhere((s) => answered.contains(s.requestId));
        results.addAll(answer.results);
        gaps = answer.gaps;
      }
    } finally {
      // what the server answered has left the device even when a later batch failed; the rest goes again under its request ids
      if (_pending.isEmpty) _offlineSince = null;
      await _save();
    }
    return OfflineSyncAnswer(results: results, gaps: gaps);
  }
}
