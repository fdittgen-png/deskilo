// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4373 (CS11) -- the till selling offline. When a call to the server gets no answer, the till goes on selling for cash from the
// prices it held, records each sale on the device with a number of its own, and looks for its connection again; when it is back the
// sales are sent in order and the answer is shown. Only cash, only in a till session opened before, only the prices the device
// holds: a line it has no price for is not sold. A sale made offline never goes through the online command, and an online sale
// whose answer was lost is never turned into an offline one (it is confirmed, as before).
//
// The controller serves one till session through [TillOfflineHost]: it reads what the till shows, shows what it changes, runs its
// acts in the session's order, and asks it to price the basket again once the connection is back.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/trace/refusal_text.dart' show serverAnswered;
import '../../../core/trace/trace_logger.dart';
import '../domain/counter_till.dart';
import '../domain/till_offline.dart';
import '../domain/till_offline_queue.dart';
import 'till_offline_mode.dart';
import 'till_state.dart';

/// What the offline selling needs of the till session it serves.
abstract interface class TillOfflineHost {
  TillState get current;
  void show(TillState next);

  /// Runs [work] after the acts before it, as every act of the session does.
  Future<void> serial(Future<void> Function() work);

  /// Prices the basket on the screen again, online.
  Future<void> priceAgain();
  TillPort get port;
  String get workspaceId;
  Duration get callTimeout;
}

class TillOfflineController {
  TillOfflineController(this._host);

  final TillOfflineHost _host;

  /// What the till shows of selling offline.
  final ValueNotifier<TillOfflineStatus> status = ValueNotifier(const TillOfflineStatus());
  TillOfflineKit? _kit;
  String? _sessionId;
  Timer? _timer;
  bool _disposed = false;

  void _put(TillOfflineStatus next) {
    if (!_disposed) status.value = next;
  }

  /// The till is left for good: nothing looks for the connection any more.
  void dispose() {
    _disposed = true;
    _stopReconnect();
    status.dispose();
  }

  /// The next customer: the sale just recorded is no longer shown.
  void clearSale() => _put(status.value.copyWith(sale: () => null));

  /// Gives the session what it needs to sell offline in [sessionId], the open session of the till being used; null turns it off.
  void configure(TillOfflineKit? kit, {String? sessionId}) {
    _kit = kit;
    _sessionId = sessionId;
    if (kit == null) _stopReconnect();
  }

  /// Keeps the prices the device falls back on: the ones the till's keys carry, read while the connection is there.
  Future<void> cachePrices(List<TillKey> keys) async {
    final kit = _kit;
    if (kit == null || status.value.active) return;
    try {
      await kit.queue.cachePrices([
        for (final k in keys)
          if (k.grossMinor != null) OfflinePrice(itemId: k.id, name: k.name, unit: k.unit, grossMinor: k.grossMinor!),
      ]);
      _put(status.value.copyWith(waiting: kit.queue.pendingCount, unreadable: false));
      // sales that waited since the app was last closed offline are sent now, if the connection is there
      if (kit.queue.hasPending) unawaited(reconnect(force: true));
    } on OfflineStoreUnreadable catch (e, st) {
      TraceLogger.instance.warn('money', 'the offline state of the device cannot be read', error: e, stackTrace: st);
      _put(status.value.copyWith(unreadable: true));
    }
  }

  /// An error that is no answer at all (a timeout, a lost connection): the only kind the till answers by selling offline.
  bool connectionLost(Object e) => _kit != null && _sessionId != null && !status.value.unreadable && !serverAnswered(e);

  Future<bool> enter() async {
    final kit = _kit!;
    try {
      await kit.queue.goOffline(sessionId: _sessionId!, now: kit.now());
    } on OfflineStoreUnreadable catch (e, st) {
      TraceLogger.instance.warn('money', 'the offline state of the device cannot be read', error: e, stackTrace: st);
      _put(status.value.copyWith(unreadable: true));
      return false;
    }
    _put(status.value.copyWith(active: true, waiting: kit.queue.pendingCount));
    _startReconnect();
    return true;
  }

  /// Totals the basket from the prices the device holds; no tax is split (the server does that when it receives the sale).
  void priceLocally(List<TillLine> lines) {
    final kit = _kit!;
    final priced = kit.queue.price([for (final l in lines) OfflineBasketLine(itemId: l.itemId, quantity: l.quantity)]);
    if (priced == null) {
      _host.show(_host.current.copyWith(draft: () => null, problem: () => const TillOfflineNoPrice()));
      return;
    }
    final gross = priced.fold<int>(0, (a, l) => a + l.amountMinor);
    final draft = TillDraft(
      receiptId: 'offline',
      revision: 0,
      totals: TillTotals(netMinor: gross, taxMinor: 0, grossMinor: gross, currency: kit.currency),
      lines: [for (final l in priced) TillPricedLine(label: l.name, grossMinor: l.amountMinor, quantity: l.quantity)],
      issueReceipt: 'supported',
    );
    _host.show(_host.current.copyWith(draft: () => draft, problem: () => null));
  }

  /// Takes [givenMinor] in cash for the basket and records the sale on the device, under the next number of its session.
  Future<void> payLocally(int givenMinor) async {
    final kit = _kit!;
    final draft = _host.current.draft;
    if (draft == null || _host.current.sold != null) return;
    if (givenMinor < draft.totals.grossMinor) {
      _host.show(_host.current.copyWith(problem: () => const TillCashShort()));
      return;
    }
    try {
      final sale = await kit.queue.record(
        basket: [for (final l in _host.current.lines) OfflineBasketLine(itemId: l.itemId, quantity: l.quantity)],
        cashGivenMinor: givenMinor,
        now: kit.now(),
      );
      _put(status.value.copyWith(sale: () => sale, waiting: kit.queue.pendingCount));
      _host.show(
        _host.current.copyWith(
          sold: () => TillSold(receiptId: 'offline-${sale.seq}', number: '', totals: draft.totals),
          change: () => sale.changeMinor,
          problem: () => null,
        ),
      );
    } on OfflineRecordRefused catch (e, st) {
      TraceLogger.instance.warn('money', 'an offline sale was refused by the device', error: e, stackTrace: st);
      _host.show(_host.current.copyWith(problem: () => e));
    } on OfflineStoreUnreadable catch (e, st) {
      TraceLogger.instance.warn('money', 'the offline state of the device cannot be read', error: e, stackTrace: st);
      _put(status.value.copyWith(unreadable: true));
    }
  }

  void _startReconnect() {
    final kit = _kit;
    if (kit == null || _timer != null) return;
    _timer = Timer.periodic(kit.reconnectEvery, (_) => unawaited(reconnect()));
  }

  void _stopReconnect() {
    _timer?.cancel();
    _timer = null;
  }

  /// Looks for the connection; [force] sends what waits even when the till is not offline now. When it is there, sends what waited, in order, and shows what the server answered. A send the server
  /// refuses as a whole (a closed session) keeps its sales on the device for a manager and says so; the till is online again.
  Future<void> reconnect({bool force = false}) => _host.serial(() async {
    final kit = _kit;
    if (kit == null || (!status.value.active && !force) || status.value.syncing) return;
    _put(status.value.copyWith(syncing: true));
    try {
      await _host.port.readiness(_host.workspaceId).timeout(_host.callTimeout);
    } on Object catch (e, st) {
      // still no answer: the till stays offline and looks again
      TraceLogger.instance.warn('money', 'the till is still offline', error: e, stackTrace: st);
      _put(status.value.copyWith(syncing: false));
      return;
    }
    OfflineSyncAnswer? answer;
    Object? failure;
    try {
      answer = await kit.queue.sync(kit.port, workspaceId: _host.workspaceId, minorDigits: kit.minorDigits).timeout(_host.callTimeout * 4);
    } on Object catch (e, st) {
      TraceLogger.instance.warn('money', 'the offline sales could not be sent', error: e, stackTrace: st);
      if (!serverAnswered(e)) {
        _put(status.value.copyWith(syncing: false, waiting: kit.queue.pendingCount));
        return;
      }
      failure = e;
    }
    await kit.queue.backOnline();
    _stopReconnect();
    final kept = kit.queue.pendingCount;
    final report = OfflineReport(accepted: answer?.acceptedCount ?? 0, refused: answer?.refused ?? const [], gaps: answer?.gaps ?? const [], failure: failure, kept: kept);
    _put(
      TillOfflineStatus(waiting: kept, sale: status.value.sale, report: report.accepted == 0 && report.clean ? null : report, unreadable: status.value.unreadable),
    );
    if (_host.current.lines.isNotEmpty && _host.current.sold == null) await _host.priceAgain();
  });

  /// The result of the last send has been read.
  void dismissReport() => _put(status.value.copyWith(report: () => null));

  /// The offline state on the device could not be read and someone decided to drop it: the till starts its offline state again.
  Future<void> discardStore() async {
    final kit = _kit;
    if (kit == null) return;
    await kit.queue.discardUnreadable();
    _put(status.value.copyWith(unreadable: false, waiting: 0));
  }
}
