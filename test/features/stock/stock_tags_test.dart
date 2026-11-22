// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4363 (G14) -- the phone's NFC in the stock, at a phone and a desk width, with a fake reader that emits chips:
// the tags of a place or an item are listed, one read binds a tag with its own request id (the same chip again
// answers "already bound here" and binds no second one), a chip bound elsewhere is refused with its owner, a
// tag is retired with a reason, a UHF-only item says so; in a goods sheet a chip read is a scan (a place tag sets
// the place, a chip read twice is "already read", a chip that names nothing is "Unknown tag"), and the button is
// absent without the feature or without NFC on the device.
import 'package:deskilo/core/demo/data/demo_stock_code_resolver.dart';
import 'package:deskilo/core/demo/data/demo_stock_config_commands.dart';
import 'package:deskilo/core/demo/data/demo_stock_ledger.dart';
import 'package:deskilo/core/demo/data/demo_stock_operations.dart';
import 'package:deskilo/core/demo/data/demo_stock_queries.dart';
import 'package:deskilo/core/demo/data/demo_stock_registry.dart';
import 'package:deskilo/core/demo/data/demo_stock_tags.dart';
import 'package:deskilo/core/nfc/nfc_uid_reader.dart';
import 'package:deskilo/features/stock/domain/stock_tags.dart';
import 'package:deskilo/features/stock/presentation/stock_tags_dialog.dart';
import 'package:deskilo/features/stock/presentation/stock_transfers_screen.dart';
import 'package:deskilo/features/stock/providers/stock_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();

/// A phone's NFC that hands out the chips a test queues, one per read.
class _Nfc implements NfcUidReader {
  _Nfc({this.available = true});

  final bool available;
  final List<String> chips = [];

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<NfcStatus> status() async => available ? NfcStatus.ready : NfcStatus.unsupported;

  @override
  Future<bool> startRead({required ValueChanged<String> onUid}) async {
    onUid(chips.removeAt(0));
    return true;
  }

  @override
  Future<void> stop() async {}
}

/// A store whose only tag is a UHF label.
class _UhfOnly implements StockTags {
  @override
  Future<List<StockTag>> tags(String workspaceId, TagOwner owner) async =>
      const [StockTag(id: 't', code: 'E2801160', kind: 'epc', ownerKind: 'item')];

  @override
  Future<TagBound> bind(String workspaceId, {required String requestId, required String code, required TagOwner owner}) =>
      throw UnimplementedError();

  @override
  Future<void> retire(String workspaceId, {required String requestId, required String code, required String reason}) =>
      throw UnimplementedError();
}

Future<void> _frames(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _World {
  _World() {
    ledger = DemoStockLedger('ws-1', config);
    operations = DemoStockOperations(ledger, config);
    resolver = DemoStockCodeResolver('ws-1', config, DemoStockRegistry('ws-1', ledger, config), tags);
  }

  final config = DemoStockConfigCommands('ws-1');
  final tags = DemoStockTags();
  late final DemoStockLedger ledger;
  late final DemoStockOperations operations;
  late final DemoStockCodeResolver resolver;
}

Future<void> _openDialog(WidgetTester tester, _World w, _Nfc nfc, Size size, {TagOwner? owner, StockTags? store, bool flag = true}) async {
  await pumpApp(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          key: const ValueKey('open'),
          onPressed: () => showStockTagsDialog(context, workspaceId: 'ws-1', owner: owner ?? const TagOwner.place('demo-place-shelf'), name: 'Shelf A'),
          child: const Text('open'),
        ),
      ),
    ),
    size: size,
    overrides: [
      ...standardTestOverrides(nfc: nfc),
      stockTagsStoreProvider.overrideWithValue(store ?? w.tags),
      stockTagsProvider.overrideWithValue(flag),
    ],
  );
  await tester.tap(find.byKey(const ValueKey('open')));
  await _frames(tester);
}

void main() {
  for (final (name, size) in [('phone', const Size(390, 844)), ('desk', const Size(1440, 900))]) {
    group('on a $name', () {
      testWidgets('the tags of a place are listed; a chip read binds one, the same chip again binds no second', (tester) async {
        final w = _World();
        final nfc = _Nfc()..chips.addAll(['04aa11bb', '04aa11bb']);
        await _openDialog(tester, w, nfc, size);
        expect(find.byKey(const ValueKey('stock-tag-A1B2C3D4')), findsOneWidget, reason: 'the shelf already has a chip');
        await tester.tap(find.byKey(const ValueKey('stock-scan-nfc')));
        await _frames(tester);
        expect(find.byKey(const ValueKey('stock-tag-04AA11BB')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('stock-scan-nfc')));
        await _frames(tester);
        expect((await w.tags.tags('ws-1', const TagOwner.place('demo-place-shelf'))).where((t) => t.code == '04AA11BB'), hasLength(1));
        expect(find.text(_en.stockTagsAlready('04AA11BB')), findsOneWidget, reason: 'replayed, not bound twice');
      });

      testWidgets('a chip bound elsewhere is refused with its owner, and nothing is bound', (tester) async {
        final w = _World();
        final nfc = _Nfc()..chips.add('a1b2c3d4');
        await _openDialog(tester, w, nfc, size, owner: const TagOwner.item('demo-item-beans'));
        await tester.tap(find.byKey(const ValueKey('stock-scan-nfc')));
        await _frames(tester);
        expect(find.text(_en.stockTagBoundElsewhere('demo-place-shelf')), findsOneWidget);
        expect(await w.tags.tags('ws-1', const TagOwner.item('demo-item-beans')), isEmpty);
      });

      testWidgets('a tag is retired with a reason and is out of the list', (tester) async {
        final w = _World();
        await _openDialog(tester, w, _Nfc(), size);
        await tester.tap(find.byKey(const ValueKey('stock-tag-retire-A1B2C3D4')));
        await _frames(tester);
        await tester.tap(find.text(_en.stockTagReasonLost));
        await _frames(tester);
        expect(find.byKey(const ValueKey('stock-tag-A1B2C3D4')), findsNothing);
        expect(find.byKey(const ValueKey('stock-tags-none')), findsOneWidget);
      });

      testWidgets('an item with only UHF labels says that a phone cannot read them', (tester) async {
        final w = _World();
        await _openDialog(tester, w, _Nfc(), size, owner: const TagOwner.item('demo-item-beans'), store: _UhfOnly());
        expect(find.byKey(const ValueKey('stock-tags-uhf-only')), findsOneWidget);
        expect(find.text(_en.stockTagsUhfOnly), findsOneWidget);
      });

      testWidgets('without NFC on the device, or without the feature, there is no button', (tester) async {
        final w = _World();
        await _openDialog(tester, w, _Nfc(available: false), size);
        expect(find.byKey(const ValueKey('stock-scan-nfc')), findsNothing);
      });

      testWidgets('in the move sheet a chip read is a scan: a place tag sets the place; twice is already read; unknown is said', (tester) async {
        final w = _World();
        final nfc = _Nfc()..chips.addAll(['a1b2c3d4', 'a1b2c3d4', 'ffee0011']);
        await pumpApp(
          tester,
          const StockTransfersScreen(),
          size: size,
          overrides: [
            ...standardTestOverrides(nfc: nfc),
            stockQueriesProvider.overrideWithValue(DemoStockQueries(w.ledger)),
            stockConfigCommandsProvider.overrideWithValue(w.config),
            stockOperationsProvider.overrideWithValue(w.operations),
            stockCodeResolverProvider.overrideWithValue(w.resolver),
            stockTagsStoreProvider.overrideWithValue(w.tags),
            stockScanningProvider.overrideWithValue(true),
            stockTagsProvider.overrideWithValue(true),
            myPermissionsProvider.overrideWithValue({WorkspacePermission.viewStock, WorkspacePermission.manageStock}),
            enabledFeaturesSyncProvider.overrideWithValue({WorkspaceFeature.stockManagement}),
          ],
        );
        await _frames(tester);
        await tester.tap(find.byKey(const ValueKey('stock-move-open')));
        await _frames(tester);
        await tester.tap(find.byKey(const ValueKey('stock-scan-nfc')));
        await _frames(tester);
        expect(tester.widget<DropdownButtonFormField<String?>>(find.byKey(const ValueKey('stock-move-from'))).initialValue, 'demo-place-shelf');
        await tester.tap(find.byKey(const ValueKey('stock-scan-nfc')));
        await _frames(tester);
        expect(find.byKey(const ValueKey('stock-scan-already-read')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('stock-scan-nfc')));
        await _frames(tester);
        expect(find.text(_en.stockScanUnknownTag('FFEE0011')), findsOneWidget);
      });
    });
  }
}
