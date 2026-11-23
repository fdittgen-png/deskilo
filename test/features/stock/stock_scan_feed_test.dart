// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4360 (G11) -- the scans of one sheet keep what each carried: a lot and an expiry from a GS1 label belong to THAT
// scan. A scan that could not be resolved leaves nothing behind, so a plain scan of the same code afterwards gets no
// lot; two labelled scans of one code queued together each keep their own; a repeat scan of a labelled unit gives an
// expiry to a line that had none.
import 'dart:async';

import 'package:deskilo/features/stock/domain/stock_code_resolver.dart';
import 'package:deskilo/features/stock/domain/stock_scan_session.dart';
import 'package:deskilo/features/stock/presentation/stock_scan_feed.dart';
import 'package:flutter_test/flutter_test.dart';

const _milk = ScannedItem(id: 'item-milk', name: 'Oat milk', unit: 'l');

/// Answers the milk for every code, except while [failNext] is set: then the call throws once.
class _Resolver implements StockCodeResolver {
  bool failNext = false;
  Completer<void>? gate;

  @override
  Future<StockCodeResolution> resolve(String workspaceId, String code) async {
    if (gate != null) await gate!.future;
    if (failNext) {
      failNext = false;
      throw StateError('no connection');
    }
    return StockCodeResolution(kind: ScannedKind.item, code: code, item: _milk);
  }
}

StockScanFeed _feed(_Resolver resolver, StockScanSession session) =>
    StockScanFeed(resolver: resolver, workspaceId: 'ws-1', session: session, onResult: (_) {});

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('a scan that could not be resolved leaves its lot behind no more: the next plain scan gets none', () async {
    final resolver = _Resolver()..failNext = true;
    final session = StockScanSession();
    final feed = _feed(resolver, session)..scan('4006381333931', gs1: (lot: 'LOT-OLD', expiresOn: '2026-05-31'));
    await _settle();
    expect(feed.problem, isNotNull, reason: 'the failed resolution is said');
    expect(session.lines, isEmpty);
    feed.scan('4006381333931');
    await _settle();
    expect(session.lines, hasLength(1));
    expect(session.lines.single.lotCode, isNull, reason: 'the lot of the failed scan is not inherited');
    expect(session.lines.single.expiresOn, isNull);
  });

  test('two labelled scans of one code, queued together, each keep their own lot and expiry', () async {
    final resolver = _Resolver()..gate = Completer<void>();
    final session = StockScanSession();
    _feed(resolver, session)
      ..scan('4006381333931', gs1: (lot: 'A', expiresOn: '2026-05-31'))
      ..scan('4006381333931', gs1: (lot: 'B', expiresOn: '2026-06-30'));
    resolver.gate!.complete();
    await _settle();
    await _settle();
    expect({for (final l in session.lines) l.lotCode: l.expiresOn}, {'A': '2026-05-31', 'B': '2026-06-30'});
  });

  test('a repeat scan of a labelled unit gives an expiry to a line that had none', () async {
    final resolver = _Resolver();
    final session = StockScanSession();
    final feed = _feed(resolver, session)..scan('4006381333931');
    await _settle();
    expect(session.lines.single.expiresOn, isNull);
    feed.scan('4006381333931', gs1: (lot: null, expiresOn: '2026-12-31'));
    await _settle();
    expect(session.lines, hasLength(1), reason: 'the same line');
    expect(session.lines.single.expiresOn, '2026-12-31');
    expect(session.lines.single.scans, 2);
  });
}
