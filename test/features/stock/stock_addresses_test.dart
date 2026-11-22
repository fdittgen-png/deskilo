// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4293 -- a place is read by its ADDRESS wherever it appears (the stock, a move's places, a transfer),
// written with the business's own separator, and the labels of the places are printed: a PDF that
// says each address and is handed to the file saver. Phone and desk widths, on the Demo's one ledger.
import 'dart:typed_data';

import 'package:deskilo/core/demo/data/demo_stock_config_commands.dart';
import 'package:deskilo/core/demo/data/demo_stock_ledger.dart';
import 'package:deskilo/core/demo/data/demo_stock_queries.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/features/stock/domain/place_labels_pdf.dart';
import 'package:deskilo/features/stock/presentation/stock_places_screen.dart';
import 'package:deskilo/features/stock/presentation/stock_screen.dart';
import 'package:deskilo/features/stock/providers/stock_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../helpers/mock_providers.dart';
import '../../helpers/pdf_geometry.dart';
import '../../helpers/pump_app.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _open(
  WidgetTester tester,
  Widget screen,
  Size size, {
  String? separator,
  TypedFileSaver? saver,
}) async {
  final config = DemoStockConfigCommands('ws-1');
  final ledger = DemoStockLedger('ws-1', config);
  await pumpApp(
    tester,
    screen,
    size: size,
    overrides: [
      ...standardTestOverrides(),
      stockQueriesProvider.overrideWithValue(DemoStockQueries(ledger)),
      stockConfigCommandsProvider.overrideWithValue(config),
      myPermissionsProvider.overrideWithValue({WorkspacePermission.viewStock, WorkspacePermission.manageStock}),
      if (separator != null) stockAddressSeparatorProvider.overrideWithValue(separator),
      if (saver != null) typedFileSaverProvider.overrideWithValue(saver),
      if (saver != null) fileDeliveryModeProvider.overrideWithValue(FileDeliveryMode.direct),
    ],
  );
  await _settle(tester);
}

void main() {
  for (final (name, size) in [('phone', const Size(390, 844)), ('desk', const Size(1440, 900))]) {
    group('on a $name', () {
      testWidgets('the stock names a place by its address, not by the bare code of its last level', (tester) async {
        await _open(tester, const StockScreen(), size);
        expect(find.textContaining('MAIN-SHELF-A'), findsWidgets, reason: 'the mugs on the shelf: the shelf under the main store');
        expect(find.textContaining(RegExp(r'^SHELF-A')), findsNothing, reason: 'never the bare code of the last level');
      });

      testWidgets('the address is written with the business\'s separator', (tester) async {
        await _open(tester, const StockScreen(), size, separator: '.');
        expect(find.textContaining('MAIN.SHELF-A'), findsWidgets);
        expect(find.textContaining('MAIN-SHELF-A'), findsNothing);
      });

      testWidgets('Print labels hands a PDF of the places to the file saver', (tester) async {
        final saved = <({Uint8List bytes, String fileName})>[];
        await _open(
          tester,
          const StockPlacesScreen(),
          size,
          saver: ({required bytes, required fileName}) async {
            saved.add((bytes: bytes, fileName: fileName));
            return SavedFile('/tmp/$fileName');
          },
        );
        await tester.tap(find.byKey(const ValueKey('stock-places-print')));
        await _settle(tester);
        expect(saved, hasLength(1));
        expect(String.fromCharCodes(saved.single.bytes.take(4)), '%PDF');
        expect(saved.single.fileName, 'deskilo-place-labels.pdf');
      });
    });
  }

  group('the label sheet', () {
    Future<Uint8List> build(List<PlaceLabel> labels) async => buildPlaceLabelsPdf(
      labels: labels,
      baseFont: pw.Font.helvetica(),
      boldFont: pw.Font.helveticaBold(),
    );

    test('is a PDF with ink on one page for one label, and more pages for many', () async {
      final one = await build(const [PlaceLabel(address: 'MAG1-SALES-A03-B02-S4', barcode: 'MAG1-SALES-A03-B02-S4', name: 'Eye level')]);
      expect(String.fromCharCodes(one.take(4)), '%PDF');
      expect(textPositions(one), isNotEmpty, reason: 'the label has ink: the address, the name and the barcode');
      expect(textPositions(one).every((ink) => ink.page == 1), isTrue, reason: 'one label is one page');
      final many = await build([
        for (var i = 0; i < 30; i++) PlaceLabel(address: 'MAIN-S$i', barcode: 'MAIN-S$i'),
      ]);
      expect(many.length, greaterThan(one.length), reason: 'thirty labels need more than one page');
    });
  });
}
