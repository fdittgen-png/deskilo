// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4362 (G13) -- the Demo's RFID tags as a person reads them: a gift basket tracked piece by piece lists its five pieces,
// each with its tag; a crate of apples carries one tag for the crate, not for its fruit; two places are tagged; and the
// tag mode of each item is its own value, shown with where it comes from.
import 'package:deskilo/core/codes/dk_code.dart';
import 'package:deskilo/core/demo/data/demo_item_groups.dart';
import 'package:deskilo/core/demo/data/demo_stock_config_commands.dart';
import 'package:deskilo/core/demo/data/demo_stock_tags.dart';
import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:deskilo/features/stock/domain/stock_tags.dart';
import 'package:deskilo/features/stock/presentation/stock_tags_dialog.dart';
import 'package:deskilo/features/stock/providers/stock_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();

Future<void> _frames(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _open(WidgetTester tester, TagOwner owner, String name, Size size) async {
  await pumpApp(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          key: const ValueKey('open'),
          onPressed: () => showStockTagsDialog(context, workspaceId: 'ws-1', owner: owner, name: name),
          child: const Text('open'),
        ),
      ),
    ),
    size: size,
    overrides: [...standardTestOverrides(), stockTagsStoreProvider.overrideWithValue(DemoStockTags())],
  );
  await tester.tap(find.byKey(const ValueKey('open')));
  await _frames(tester);
}

void main() {
  for (final (name, size) in [('a phone', const Size(390, 844)), ('a desk', const Size(1440, 900))]) {
    group('on $name', () {
      testWidgets('a gift basket tracked piece by piece lists its five pieces, each with its tag', (tester) async {
        await _open(tester, const TagOwner.item('demo-item-basket'), 'Gift basket', size);
        expect(find.text(_en.stockTagsPieces(5)), findsOneWidget);
        for (var i = 1; i <= 5; i++) {
          expect(find.text(_en.stockTagPiece('$i')), findsOneWidget);
        }
        expect(find.byKey(const ValueKey('stock-piece-E2801160600002054AF3E001')), findsOneWidget);
      });

      testWidgets('a crate of apples carries one tag for the crate, and no piece is listed', (tester) async {
        await _open(tester, const TagOwner.item('demo-item-apples'), 'Apples, crate', size);
        expect(find.byKey(const ValueKey('stock-tag-E2801160600002054AF3D001')), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-tags-pieces')), findsNothing);
      });

      testWidgets('two places are tagged', (tester) async {
        final tags = DemoStockTags();
        expect((await tags.tags('ws-1', const TagOwner.place('demo-place-shelf'))).single.ownerKind, 'place');
        expect((await tags.tags('ws-1', const TagOwner.place('demo-place-back'))).single.ownerKind, 'place');
        await _open(tester, const TagOwner.place('demo-place-back'), 'Back room', size);
        expect(find.byKey(const ValueKey('stock-tag-A1B2C3D5')), findsOneWidget);
      });
    });
  }

  test('the Demo items carry their tag mode as their own value: pieces for the basket, batches for the crate', () async {
    final config = DemoStockConfigCommands('ws-1');
    final groups = DemoItemGroups('ws-1', config, () => DateTime(2026, 11, 22));
    final basket = (await groups.effective('ws-1', 'demo-item-basket')).params['tag_mode']!;
    final apples = (await groups.effective('ws-1', 'demo-item-apples')).params['tag_mode']!;
    expect((basket.value, basket.own), ('per_unit', true));
    expect((apples.value, apples.own), ('per_batch', true));
  });

  group('the Demo binds as the server does', () {
    DemoStockTags tags(Map<String, String> modes) => DemoStockTags(tagModeOf: (item) async => modes[item]);

    test('only an item tagged per batch binds a tag; per piece and none are refused in the server\'s words', () async {
      final t = tags({'demo-item-apples': 'per_batch', 'demo-item-basket': 'per_unit', 'demo-item-milk': 'none'});
      await t.bind('ws-1', requestId: 'r1', code: '04AA11BB22', owner: const TagOwner.item('demo-item-apples'));
      await expectLater(
        t.bind('ws-1', requestId: 'r2', code: '04AA11BB23', owner: const TagOwner.item('demo-item-basket')),
        throwsA(isA<StockConfigRefused>().having((e) => e.reason, 'reason', 'tag_per_unit_item')),
      );
      await expectLater(
        t.bind('ws-1', requestId: 'r3', code: '04AA11BB24', owner: const TagOwner.item('demo-item-milk')),
        throwsA(isA<StockConfigRefused>().having((e) => e.reason, 'reason', 'tag_mode_none')),
      );
    });

    test('a place binds whatever any item\'s mode is', () async {
      await tags({}).bind('ws-1', requestId: 'r1', code: '04AA11BB25', owner: const TagOwner.place('demo-place-main'));
    });

    test('the tag of a piece, read in its own item\'s dialog, is bound elsewhere, not "already here"', () async {
      await expectLater(
        DemoStockTags().bind('ws-1', requestId: 'r1', code: 'E2801160600002054AF3E001', owner: const TagOwner.item('demo-item-basket')),
        throwsA(isA<StockTagRefused>().having((e) => e.code, 'code', DkCode.dkg22)),
      );
    });

    test('a piece that is still in stock keeps its tag: retiring it is refused', () async {
      await expectLater(
        DemoStockTags().retire('ws-1', requestId: 'r1', code: 'E2801160600002054AF3E001', reason: 'lost'),
        throwsA(isA<StockTagRefused>().having((e) => e.code, 'code', DkCode.dkg24)),
      );
    });
  });
}
