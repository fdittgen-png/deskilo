// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4373 (CS11) -- what the till keeps on the device while it is offline: the prices it held when it went offline, the device
// sequence number of each session, and the cash sales not yet sent. It totals a basket from those prices only, refuses what the
// server would refuse anyway (a line with no price, a quantity that is not one, cash short of the total), and sends the sales in
// order under the request id each was made with, so a retry never counts one twice. The sales are wiped from the device once the
// server has answered all of them; the device's own name stays (no card data is ever held here).
//
// Three things the device never does: it never numbers a sale with a number another device of the session may hold (the sequence is
// per device, and the device names itself in every sale), it never drops sales of one session because the till moved to another
// (each session keeps its own sales and numbers until the server has answered them), and it never writes over a store it could not
// read (the sales in it would be lost): it refuses to go on until someone decides.
import 'dart:convert';

import '../../../core/trace/trace_logger.dart';
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

/// The offline state on the device could not be read (a version this app does not know, or text that is not ours). Nothing is
/// written over it: the sales it may hold are not lost. [TillOfflineQueue.discardUnreadable] drops it, on someone's decision.
class OfflineStoreUnreadable implements Exception {
  const OfflineStoreUnreadable();
}

/// One line the till asks to ring up offline: an item and its exact quantity text.
class OfflineBasketLine {
  const OfflineBasketLine({required this.itemId, required this.quantity});

  final String itemId;
  final String quantity;
}

/// The sales and numbers of one till session on this device.
class _Lane {
  _Lane(this.sessionId);

  final String sessionId;
  int nextSeq = 1;
  DateTime? since;
  final List<OfflineSale> pending = [];
}

class TillOfflineQueue {
  TillOfflineQueue({required this.store, required this.newRequestId});

  static const int _version = 2;
  static const int _batch = 200;

  final OfflineStore store;

  /// A new random id as text (a request id, and the device's own name).
  final String Function() newRequestId;

  String? _deviceId;
  String? _current;
  final Map<String, _Lane> _lanes = {};
  final Map<String, OfflinePrice> _prices = {};
  bool _loaded = false;

  /// The till session being sold in, or null.
  String? get sessionId => _current;

  /// The name of this device, the same for as long as the store holds it; null before the first load.
  String? get deviceId => _deviceId;
  DateTime? get offlineSince => _lane?.since;

  /// The sales of the current session waiting to be sent.
  List<OfflineSale> get pending => List.unmodifiable(_lane?.pending ?? const <OfflineSale>[]);

  /// Whether any session of this device has sales waiting.
  bool get hasPending => _lanes.values.any((l) => l.pending.isNotEmpty);

  /// How many sales wait to be sent, in every session of the device.
  int get pendingCount => _lanes.values.fold(0, (a, l) => a + l.pending.length);
  Map<String, OfflinePrice> get prices => Map.unmodifiable(_prices);

  /// What the sales waiting add up to: the cash that is in the drawer and not yet on the server (every session of the device).
  int get pendingKeptMinor => _lanes.values.fold(0, (a, l) => a + l.pending.fold(0, (b, s) => b + s.totalMinor));

  _Lane? get _lane => _current == null ? null : _lanes[_current];

  Future<void> load() async {
    if (_loaded) return;
    final raw = await store.read();
    if (raw != null) {
      try {
        _read(jsonDecode(raw));
      } on Object {
        // not ours, or not a version we know: whatever it holds stays where it is
        _lanes.clear();
        _prices.clear();
        _current = null;
        throw const OfflineStoreUnreadable();
      }
    }
    _deviceId ??= newRequestId();
    _loaded = true;
    for (final lane in _lanes.values) {
      // sales made before devices named themselves are this device's now: one name for every number of a session
      for (var i = 0; i < lane.pending.length; i++) {
        if (lane.pending[i].deviceId == null) lane.pending[i] = lane.pending[i].madeBy(_deviceId!);
      }
    }
  }

  void _read(Object? j) {
    if (j is! Map) throw const FormatException('offline state');
    final version = j['v'];
    if (version != 1 && version != _version) throw const FormatException('offline state version');
    for (final p in (j['prices'] as List? ?? const [])) {
      final price = OfflinePrice.fromJson(p);
      _prices[price.itemId] = price;
    }
    if (version == 1) {
      // one session, as the first release kept it
      final id = j['session_id'] as String?;
      if (id != null) _readLane(id, j);
      _current = id;
      return;
    }
    _deviceId = j['device_id'] as String?;
    for (final l in (j['lanes'] as List? ?? const [])) {
      _readLane((l as Map)['session_id']! as String, l);
    }
    _current = j['current'] as String?;
  }

  void _readLane(String id, Map<dynamic, dynamic> j) {
    final lane = _Lane(id)
      ..nextSeq = (j['next_seq'] as num?)?.toInt() ?? 1
      ..since = j['offline_since'] == null ? null : DateTime.parse(j['offline_since'] as String).toUtc();
    for (final s in (j['sales'] as List? ?? const [])) {
      lane.pending.add(OfflineSale.fromJson(s));
    }
    _lanes[id] = lane;
  }

  Future<void> _save() => store.write(jsonEncode({
    'v': _version,
    'device_id': _deviceId,
    'current': _current,
    'prices': [for (final p in _prices.values) p.toJson()],
    'lanes': [
      for (final l in _lanes.values)
        {
          'session_id': l.sessionId,
          'next_seq': l.nextSeq,
          'offline_since': l.since?.toUtc().toIso8601String(),
          'sales': [for (final s in l.pending) s.toJson()],
        },
    ],
  }));

  /// Drops what the device holds when it could not be read: the one way past [OfflineStoreUnreadable], taken on someone's decision.
  Future<void> discardUnreadable() async {
    await store.wipe();
    _lanes.clear();
    _prices.clear();
    _current = null;
    _loaded = false;
  }

  /// The till is online: the prices it will fall back on are the ones it just read.
  Future<void> cachePrices(Iterable<OfflinePrice> prices) async {
    await load();
    _prices
      ..clear()
      ..addEntries([for (final p in prices) MapEntry(p.itemId, p)]);
    await _save();
  }

  /// The till lost its connection in [sessionId] at [now]. Sales already waiting keep their numbers, in that session and in any
  /// other the device holds; a session the device has not sold in starts at 1.
  Future<void> goOffline({required String sessionId, required DateTime now}) async {
    await load();
    _lanes.putIfAbsent(sessionId, () => _Lane(sessionId)).since ??= now.toUtc();
    _current = sessionId;
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
    final lane = _lane;
    if (lane == null || basket.isEmpty) throw const OfflineRecordRefused(OfflineRefusal.empty);
    for (final b in basket) {
      if (!_prices.containsKey(b.itemId)) throw const OfflineRecordRefused(OfflineRefusal.noPrice);
      if (tillQuantityOf(b.quantity) == null) throw const OfflineRecordRefused(OfflineRefusal.badQuantity);
    }
    final lines = price(basket)!;
    final total = lines.fold<int>(0, (a, l) => a + l.amountMinor);
    if (cashGivenMinor < total) throw const OfflineRecordRefused(OfflineRefusal.cashShort);
    final sale = OfflineSale(
      seq: lane.nextSeq,
      requestId: newRequestId(),
      occurredAt: now.toUtc(),
      lines: lines,
      cashGivenMinor: cashGivenMinor,
      changeMinor: cashGivenMinor - total,
      deviceId: _deviceId,
    );
    lane.nextSeq++;
    lane.pending.add(sale);
    await _save();
    return sale;
  }

  /// The connection is back and nothing waits in a session: its offline period is over.
  Future<void> backOnline() async {
    await load();
    for (final lane in _lanes.values) {
      if (lane.pending.isEmpty) lane.since = null;
    }
    await _save();
  }

  /// Sends what waits, session by session and in order, [_batch] at a time. A connection that fails throws and leaves what was not
  /// answered where it was (the same request ids go again); once the server has answered a sale, accepted or refused, it leaves the
  /// device. A session the server refuses as a whole (it was closed) keeps its sales and does not hold the others back; its error is
  /// thrown when every session has been tried. Returns the answers, or null when there was nothing to send.
  Future<OfflineSyncAnswer?> sync(TillOfflinePort port, {required String workspaceId, required int minorDigits}) async {
    await load();
    final results = <OfflineSaleResult>[];
    final gaps = <int>{};
    var sent = false;
    Object? failure;
    StackTrace? failureTrace;
    try {
      for (final lane in _lanes.values.where((l) => l.pending.isNotEmpty && l.since != null).toList()) {
        sent = true;
        try {
          await _syncLane(lane, port, workspaceId, minorDigits, results, gaps);
        } on Object catch (e, st) {
          TraceLogger.instance.warn('money', 'the offline sales of a session could not be sent', error: e, stackTrace: st);
          failure ??= e;
          failureTrace ??= st;
        }
      }
    } finally {
      // what the server answered has left the device even when a later batch failed; the rest goes again under its request ids
      for (final lane in _lanes.values) {
        if (lane.pending.isEmpty) lane.since = null;
      }
      await _save();
    }
    if (failure != null) Error.throwWithStackTrace(failure, failureTrace!);
    return sent ? OfflineSyncAnswer(results: results, gaps: gaps.toList()..sort()) : null;
  }

  Future<void> _syncLane(_Lane lane, TillOfflinePort port, String workspaceId, int minorDigits, List<OfflineSaleResult> results, Set<int> gaps) async {
    while (lane.pending.isNotEmpty) {
      final batch = lane.pending.take(_batch).toList();
      final answer = await port.sync(workspaceId, sessionId: lane.sessionId, offlineSince: lane.since!, sales: batch, minorDigits: minorDigits);
      final answered = {for (final r in answer.results) r.requestId};
      if (answered.isEmpty) break;
      lane.pending.removeWhere((s) => answered.contains(s.requestId));
      results.addAll(answer.results);
      gaps
        ..clear()
        ..addAll(answer.gaps);
    }
  }
}
