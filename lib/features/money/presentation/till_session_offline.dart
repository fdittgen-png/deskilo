// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4373 (CS11) -- the till session selling offline. When a call to the server gets no answer, the till goes on selling for cash from
// the prices it held, records each sale on the device with a number of its own, and looks for its connection again; when it is back
// the sales are sent in order and the answer is shown. Only cash, only in a till session opened before, only the prices the device
// holds: a line it has no price for is not sold. A sale made offline never goes through the online command, and an online sale
// whose answer was lost is never turned into an offline one (it is confirmed, as before).
part of 'till_session.dart';

extension TillSessionOffline on TillSession {
  void _setOffline(TillOfflineStatus next) {
    if (!_disposed) offline.value = next;
  }

  /// Gives the session what it needs to sell offline in [sessionId], the open session of the till being used; null turns it off.
  void configureOffline(TillOfflineKit? kit, {String? sessionId}) {
    offlineKit = kit;
    offlineSessionId = sessionId;
    if (kit == null) _stopReconnect();
  }

  /// Keeps the prices the device falls back on: the ones the till's keys carry, read while the connection is there.
  Future<void> cacheOfflinePrices(List<TillKey> keys) async {
    final kit = offlineKit;
    if (kit == null || offline.value.active) return;
    try {
      await kit.queue.cachePrices([
        for (final k in keys)
          if (k.grossMinor != null) OfflinePrice(itemId: k.id, name: k.name, unit: k.unit, grossMinor: k.grossMinor!),
      ]);
      _setOffline(offline.value.copyWith(waiting: kit.queue.pendingCount, unreadable: false));
    } on OfflineStoreUnreadable {
      _setOffline(offline.value.copyWith(unreadable: true));
    }
  }

  /// An error that is no answer at all (a timeout, a lost connection): the only kind the till answers by selling offline.
  bool _connectionLost(Object e) => offlineKit != null && offlineSessionId != null && !offline.value.unreadable && !serverAnswered(e);

  Future<bool> _enterOffline() async {
    final kit = offlineKit!;
    try {
      await kit.queue.goOffline(sessionId: offlineSessionId!, now: kit.now());
    } on OfflineStoreUnreadable {
      _setOffline(offline.value.copyWith(unreadable: true));
      return false;
    }
    _setOffline(offline.value.copyWith(active: true, waiting: kit.queue.pendingCount));
    _startReconnect();
    return true;
  }

  /// Totals the basket from the prices the device holds; no tax is split (the server does that when it receives the sale).
  void _priceOffline(List<TillLine> lines) {
    final kit = offlineKit!;
    final priced = kit.queue.price([for (final l in lines) OfflineBasketLine(itemId: l.itemId, quantity: l.quantity)]);
    if (priced == null) {
      _set(_now.copyWith(draft: () => null, problem: () => const TillOfflineNoPrice()));
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
    _set(_now.copyWith(draft: () => draft, problem: () => null));
  }

  /// Takes [givenMinor] in cash for the basket and records the sale on the device, under the next number of its session.
  Future<void> _payOffline(int givenMinor) async {
    final kit = offlineKit!;
    final draft = _now.draft;
    if (draft == null || _now.sold != null) return;
    if (givenMinor < draft.totals.grossMinor) {
      _set(_now.copyWith(problem: () => const TillCashShort()));
      return;
    }
    try {
      final sale = await kit.queue.record(
        basket: [for (final l in _now.lines) OfflineBasketLine(itemId: l.itemId, quantity: l.quantity)],
        cashGivenMinor: givenMinor,
        now: kit.now(),
      );
      _setOffline(offline.value.copyWith(sale: () => sale, waiting: kit.queue.pendingCount));
      _set(
        _now.copyWith(
          sold: () => TillSold(receiptId: 'offline-${sale.seq}', number: '', totals: draft.totals),
          change: () => sale.changeMinor,
          problem: () => null,
        ),
      );
    } on OfflineRecordRefused catch (e, st) {
      TraceLogger.instance.warn('money', 'an offline sale was refused by the device', error: e, stackTrace: st);
      _set(_now.copyWith(problem: () => e));
    } on OfflineStoreUnreadable {
      _setOffline(offline.value.copyWith(unreadable: true));
    }
  }

  void _startReconnect() {
    final kit = offlineKit;
    if (kit == null || _reconnectTimer != null) return;
    _reconnectTimer = Timer.periodic(kit.reconnectEvery, (_) => unawaited(reconnect()));
  }

  void _stopReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// Looks for the connection; when it is there, sends what waited, in order, and shows what the server answered. A send the server
  /// refuses as a whole (a closed session) keeps its sales on the device for a manager and says so; the till is online again.
  Future<void> reconnect() => _serial(() async {
    final kit = offlineKit;
    if (kit == null || !offline.value.active || offline.value.syncing) return;
    _setOffline(offline.value.copyWith(syncing: true));
    try {
      await port.readiness(workspaceId).timeout(callTimeout);
    } on Object {
      // still no answer: the till stays offline and looks again
      _setOffline(offline.value.copyWith(syncing: false));
      return;
    }
    OfflineSyncAnswer? answer;
    Object? failure;
    try {
      answer = await kit.queue.sync(kit.port, workspaceId: workspaceId, minorDigits: kit.minorDigits).timeout(callTimeout * 4);
    } on Object catch (e, st) {
      TraceLogger.instance.warn('money', 'the offline sales could not be sent', error: e, stackTrace: st);
      if (!serverAnswered(e)) {
        _setOffline(offline.value.copyWith(syncing: false, waiting: kit.queue.pendingCount));
        return;
      }
      failure = e;
    }
    await kit.queue.backOnline();
    _stopReconnect();
    final kept = kit.queue.pendingCount;
    final report = OfflineReport(accepted: answer?.acceptedCount ?? 0, refused: answer?.refused ?? const [], gaps: answer?.gaps ?? const [], failure: failure, kept: kept);
    _setOffline(
      TillOfflineStatus(waiting: kept, sale: offline.value.sale, report: report.accepted == 0 && report.clean ? null : report, unreadable: offline.value.unreadable),
    );
    if (_now.lines.isNotEmpty && _now.sold == null) await _price(_now.lines);
  });

  /// The result of the last send has been read.
  void dismissOfflineReport() => _setOffline(offline.value.copyWith(report: () => null));

  /// The offline state on the device could not be read and someone decided to drop it: the till starts its offline state again.
  Future<void> discardOfflineStore() async {
    final kit = offlineKit;
    if (kit == null) return;
    await kit.queue.discardUnreadable();
    _setOffline(offline.value.copyWith(unreadable: false, waiting: 0));
  }
}
