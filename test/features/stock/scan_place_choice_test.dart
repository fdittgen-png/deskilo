// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4495 -- a scanned code that two places carry (Site A / Shop and Site B / Shop are both SHOP) is not taken for the first of them: the answer
// lists the places, a sheet's scan asks which, and the place the person says is the place scanned. The Demo answers as the server does.
import 'package:deskilo/core/demo/data/demo_stock_code_resolver.dart';
import 'package:deskilo/core/demo/data/demo_stock_config_commands.dart';
import 'package:deskilo/core/demo/data/demo_stock_ledger.dart';
import 'package:deskilo/core/demo/data/demo_stock_registry.dart';
import 'package:deskilo/features/stock/domain/stock_code_resolver.dart';
import 'package:deskilo/features/stock/domain/stock_scan_session.dart';
import 'package:deskilo/features/stock/presentation/stock_scan_feed.dart';
import 'package:flutter_test/flutter_test.dart';

const _answer = {
  'kind': 'place',
  'matched_by': 'place_code',
  'code': 'SHOP',
  'places': [
    {'id': 'p-a', 'code': 'SHOP', 'name': 'Shop', 'kind': 'zone', 'path': 'SITE-A › SHOP'},
    {'id': 'p-b', 'code': 'SHOP', 'name': 'Shop', 'kind': 'zone', 'path': 'SITE-B › SHOP'},
  ],
};

class _Resolver implements StockCodeResolver {
  @override
  Future<StockCodeResolution> resolve(String workspaceId, String code) async => StockCodeResolution.fromJson(_answer);
}

void main() {
  test('the answer lists the places with their paths and names none of them', () {
    final r = StockCodeResolution.fromJson(_answer);
    expect(r.place, isNull);
    expect(r.asksWhichPlace, isTrue);
    expect(r.placeChoices.map((p) => p.path), ['SITE-A › SHOP', 'SITE-B › SHOP']);
  });

  test('a code one place carries is a place, not a question', () {
    final r = StockCodeResolution.fromJson({
      'kind': 'place',
      'code': 'BACK',
      'place': {'id': 'p-c', 'code': 'BACK', 'name': 'Back room', 'kind': 'zone'},
    });
    expect((r.asksWhichPlace, r.place?.id), (false, 'p-c'));
  });

  test('the session asks which place and sets none; saying which sets that one as the current place', () async {
    final session = StockScanSession();
    final results = <ScanResult>[];
    final feed = StockScanFeed(resolver: _Resolver(), workspaceId: 'ws', session: session, onResult: results.add)..scan('SHOP');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(results.single.outcome, ScanOutcome.askPlace);
    expect(results.single.choices, hasLength(2));
    expect(session.current, isNull, reason: 'nothing is chosen for the person');

    feed.choosePlace(results.single.choices.last);
    expect(results.last.outcome, ScanOutcome.place);
    expect(session.current?.id, 'p-b');
    feed.dispose();
  });

  test('the Demo answers a code its two BACK places carry with both, and a code one carries with that one', () async {
    final config = DemoStockConfigCommands('ws-1');
    final resolver = DemoStockCodeResolver('ws-1', config, DemoStockRegistry('ws-1', DemoStockLedger('ws-1', config), config));
    final back = await resolver.resolve('ws-1', 'BACK');
    expect(back.asksWhichPlace, isTrue);
    expect(back.placeChoices.map((p) => p.path), containsAll(['MAIN › BACK', 'DEPOT › BACK']));
    final main = await resolver.resolve('ws-1', 'MAIN');
    expect((main.asksWhichPlace, main.place?.code), (false, 'MAIN'));
  });
}
