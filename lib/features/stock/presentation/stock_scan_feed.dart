// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4359 (G10) -- the scans of ONE open goods sheet. Each scan is resolved by the server in one call and then
// applied by the sheet; the scans are served in the order they arrived, one at a time, so two codes typed in a
// burst never overtake each other, and while the sheet's own command is in flight they wait (they are queued in
// the sheet, not sent) and are served when it is done. The sheet's request id is never touched: a scan only fills
// the form, the command it already calls decides.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/trace/guarded.dart';
import '../domain/stock_code_resolver.dart';
import '../domain/stock_scan_session.dart';

/// The resolver of the selected workspace, read when a code is scanned (not when the sheet opens: a sheet opened
/// where no server is reachable still opens).
class LazyStockCodeResolver implements StockCodeResolver {
  const LazyStockCodeResolver(this._read);

  final StockCodeResolver Function() _read;

  @override
  Future<StockCodeResolution> resolve(String workspaceId, String code) => _read().resolve(workspaceId, code);
}

class StockScanFeed extends ChangeNotifier {
  StockScanFeed({
    required this.resolver,
    required this.workspaceId,
    required this.session,
    required this.onResult,
    this.placeAllowed,
    this.itemAllowed,
  });

  final StockCodeResolver resolver;
  final String workspaceId;
  final StockScanSession session;

  /// The sheet applies what the scan did to its own fields.
  final void Function(ScanResult result) onResult;
  final bool Function(ScannedPlace place)? placeAllowed;
  final bool Function(ScannedItem item)? itemAllowed;

  /// What the last scan did, for the bar.
  ScanResult? last;

  /// Set when a code could not be resolved at all (a refusal or no connection): said, never "unknown".
  Object? problem;

  /// The scans in the order they arrived, each with what its GS1 label carried: a record per scan, so a plain
  /// scan of the same code never inherits another scan's lot or expiry.
  final List<({String code, ({String? lot, String? expiresOn})? gs1})> _queue = [];
  bool _paused = false;
  bool _running = false;
  bool _closed = false;

  /// The sheet's command is in flight: scans wait until [resume].
  void pause() => _paused = true;

  void resume() {
    _paused = false;
    unawaited(_drain());
  }

  /// A code was scanned; [gs1] is what a GS1 element string carried besides the GTIN that [code] is.
  void scan(String code, {({String? lot, String? expiresOn})? gs1}) {
    _queue.add((code: code, gs1: gs1));
    unawaited(_drain());
  }

  /// #4495 -- the person said which of the places a scanned code names: applied as the place scanned.
  void choosePlace(ScannedPlace place) {
    final answer = StockCodeResolution(kind: ScannedKind.place, code: place.code, matchedBy: 'place_code', place: place);
    last = session.apply(answer, placeAllowed: placeAllowed, itemAllowed: itemAllowed);
    onResult(last!);
    if (!_closed) notifyListeners();
  }

  final Set<String> _tags = {};

  /// A tag was read by NFC ([uid] as the tag's upper-case hex): the same resolution as a scan, but a tag read a
  /// second time in this sheet is ignored and said so.
  void readTag(String uid) {
    final code = uid.toUpperCase();
    if (!_tags.add(code)) {
      last = ScanResult(ScanOutcome.alreadyRead, code: code, fromTag: true);
      notifyListeners();
      return;
    }
    _queue.add((code: code, gs1: null));
    _fromTag.add(code);
    unawaited(_drain());
  }

  final Set<String> _fromTag = {};

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }

  Future<void> _drain() async {
    if (_running) return;
    _running = true;
    try {
      while (!_paused && !_closed && _queue.isNotEmpty) {
        final scan = _queue.removeAt(0);
        final code = scan.code;
        final fromTag = _fromTag.remove(code);
        final answer = await guardRead<StockCodeResolution?>(
          domain: 'stock',
          message: 'a scanned code could not be resolved',
          read: () => resolver.resolve(workspaceId, code),
          fallback: (e) {
            problem = e;
            return null;
          },
        );
        if (_closed) return;
        if (answer != null) {
          problem = null;
          last = session.apply(answer, placeAllowed: placeAllowed, itemAllowed: itemAllowed, fromTag: fromTag, gs1: scan.gs1);
          onResult(last!);
        }
        if (!_closed) notifyListeners();
      }
    } finally {
      _running = false;
    }
  }
}
