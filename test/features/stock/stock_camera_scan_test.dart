// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4360 (G11) -- the camera as a scanner in the move sheet, at a phone and a desk width, with a fake reader that
// emits codes: the camera button is there with scanning on; a decoded EAN fills the sheet through the same path a
// typed scan takes; the same label seen again is one read; a GTIN with a wrong check digit is resolved as typed and said to be a misread only when nothing is found; a
// GS1 string is resolved by its GTIN; a camera that cannot start says so. And the QR-only scanners still ask for QR.
import 'package:deskilo/core/demo/data/demo_stock_code_resolver.dart';
import 'package:deskilo/core/demo/data/demo_stock_config_commands.dart';
import 'package:deskilo/core/demo/data/demo_stock_ledger.dart';
import 'package:deskilo/core/demo/data/demo_stock_operations.dart';
import 'package:deskilo/core/demo/data/demo_stock_queries.dart';
import 'package:deskilo/core/demo/data/demo_stock_registry.dart';
import 'package:deskilo/core/scan/goods_code_formats.dart';
import 'package:deskilo/core/scan/goods_scan_widget.dart';
import 'package:deskilo/core/scan/qr_scan_widget.dart';
import 'package:deskilo/features/stock/presentation/stock_transfers_screen.dart';
import 'package:deskilo/features/stock/providers/stock_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart' show Format, ReaderWidget;

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();

/// What the fake camera hands to the app: the callbacks it was built with.
class _Camera {
  ValueChanged<String>? onCode;
  ValueChanged<Object>? onError;
  bool failToStart = false;

  GoodsScanWidgetBuilder get builder => ({required onCode, required front, onError}) {
    this.onCode = onCode;
    this.onError = onError;
    if (failToStart) WidgetsBinding.instance.addPostFrameCallback((_) => onError?.call(Exception('permission denied')));
    return const SizedBox(key: ValueKey('fake-camera'));
  };
}

Future<void> _frames(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<(_Camera, DemoStockLedger)> _open(WidgetTester tester, Size size, {bool failToStart = false}) async {
  final config = DemoStockConfigCommands('ws-1');
  final ledger = DemoStockLedger('ws-1', config);
  final camera = _Camera()..failToStart = failToStart;
  await pumpApp(
    tester,
    const StockTransfersScreen(),
    size: size,
    overrides: [
      ...standardTestOverrides(),
      stockQueriesProvider.overrideWithValue(DemoStockQueries(ledger)),
      stockConfigCommandsProvider.overrideWithValue(config),
      stockOperationsProvider.overrideWithValue(DemoStockOperations(ledger)),
      stockCodeResolverProvider.overrideWithValue(DemoStockCodeResolver('ws-1', config, DemoStockRegistry('ws-1', ledger, config))),
      stockScanningProvider.overrideWithValue(true),
      goodsScanWidgetBuilderProvider.overrideWithValue(camera.builder),
      myPermissionsProvider.overrideWithValue({WorkspacePermission.viewStock, WorkspacePermission.manageStock}),
      enabledFeaturesSyncProvider.overrideWithValue({WorkspaceFeature.stockManagement}),
    ],
  );
  await _frames(tester);
  await tester.tap(find.byKey(const ValueKey('stock-move-open')));
  await _frames(tester);
  await tester.tap(find.byKey(const ValueKey('stock-scan-camera')));
  await _frames(tester);
  return (camera, ledger);
}

String? _shown(WidgetTester tester, String key) => tester.widget<DropdownButtonFormField<String?>>(find.byKey(ValueKey(key))).initialValue;

void main() {
  for (final (name, size) in [('phone', const Size(390, 844)), ('desk', const Size(1440, 900))]) {
    group('on a $name', () {
      testWidgets('a decoded EAN fills the sheet through the typed path, and the same label again is one read', (tester) async {
        final (camera, _) = await _open(tester, size);
        expect(find.byKey(const ValueKey('stock-camera-dialog')), findsOneWidget);
        camera.onCode!('4006381333931');
        await _frames(tester);
        expect(find.text(_en.stockCameraCount(1)), findsOneWidget);
        expect(tester.widget<Text>(find.byKey(const ValueKey('stock-camera-last'))).data, _en.stockScanLast('Mugs', '1', 'piece'));
        camera.onCode!('4006381333931');
        await _frames(tester);
        expect(find.text(_en.stockCameraCount(1)), findsOneWidget, reason: 'the same label in the next frame is not a second read');
        await tester.tap(find.byKey(const ValueKey('stock-camera-close')));
        await _frames(tester);
        expect(_shown(tester, 'stock-move-item'), 'demo-item-mugs');
      });

      testWidgets('a GTIN with a wrong check digit is resolved as typed and, finding nothing, said to be a misread', (tester) async {
        final (camera, _) = await _open(tester, size);
        camera.onCode!('4006381333930');
        await _frames(tester);
        expect(find.byKey(const ValueKey('stock-camera-misread')), findsOneWidget);
        expect(find.text(_en.stockCameraMisread), findsOneWidget);
        expect(find.text(_en.stockCameraCount(1)), findsOneWidget, reason: 'it was sent to the resolver, which knew nothing of it');
        expect(find.byKey(const ValueKey('stock-camera-last')), findsNothing);
      });

      testWidgets('a GS1 string is resolved by its GTIN', (tester) async {
        final (camera, _) = await _open(tester, size);
        camera.onCode!('01040063813339311725123110LOT42');
        await _frames(tester);
        expect(tester.widget<Text>(find.byKey(const ValueKey('stock-camera-last'))).data, _en.stockScanLast('Mugs', '1', 'piece'));
      });

      testWidgets('a camera that cannot start says so, with what to do', (tester) async {
        await _open(tester, size, failToStart: true);
        await _frames(tester);
        expect(find.byKey(const ValueKey('goods-scan-denied')), findsOneWidget);
        expect(find.text(_en.stockCameraDenied), findsOneWidget);
      });
    });
  }

  test('the goods reader asks for product and place codes; the QR scanners still ask for QR alone', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final goods = container.read(goodsScanWidgetBuilderProvider)(onCode: (_) {}, front: false);
    final qr = container.read(qrScanWidgetBuilderProvider)(onCode: (_) {});
    expect((goods as ReaderWidget).codeFormat, goodsCodeFormats);
    for (final f in [Format.ean13, Format.ean8, Format.upca, Format.upce, Format.code128, Format.dataMatrix, Format.qrCode]) {
      expect(goodsCodeFormats & f, f);
    }
    expect((qr as ReaderWidget).codeFormat, Format.qrCode, reason: 'check-in, invitations and badges are unchanged');
  });
}
