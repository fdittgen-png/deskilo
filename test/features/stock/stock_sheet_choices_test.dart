// SPDX-License-Identifier: AGPL-3.0-or-later
//
// What a stock sheet chooses from is read in one place: the items and the
// places are asked together (neither waits for the other), the first read
// that failed is the failure as it was raised, and a sheet opens only with
// both. A failed read says so and opens nothing; a sheet that changed
// something has the page's reads asked again, and one that did not leaves
// them alone.
import 'dart:async';

import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:deskilo/features/stock/domain/stock_page.dart';
import 'package:deskilo/features/stock/presentation/stock_sheet_opener.dart';
import 'package:deskilo/features/stock/providers/stock_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();

/// The two reads behind the choices, answered when the test says so.
class _Reads {
  final items = Completer<List<StockItem>>();
  final places = Completer<List<StockPlaceConfig>>();
  int itemsAsked = 0;
  int placesAsked = 0;

  List<Override> get overrides => [
    stockItemsProvider.overrideWith((ref, _) {
      itemsAsked++;
      return items.future;
    }),
    stockPlaceConfigsProvider.overrideWith((ref, _) {
      placesAsked++;
      return places.future;
    }),
  ];
}

void main() {
  test('the items and the places are asked together, and the choices carry both with the separator', () async {
    final reads = _Reads();
    final container = ProviderContainer.test(overrides: reads.overrides);
    final sub = container.listen(stockSheetChoicesProvider('ws-1'), (_, _) {});
    final answer = container.read(stockSheetChoicesProvider('ws-1').future);
    await Future<void>.delayed(Duration.zero);
    expect(
      (reads.itemsAsked, reads.placesAsked),
      (1, 1),
      reason: 'neither read waits for the other',
    );
    reads.places.complete(const []);
    reads.items.complete(const []);
    final choices = await answer;
    expect(choices.items, isEmpty);
    expect(choices.places, isEmpty);
    expect(choices.separator, isNotEmpty);
    sub.close();
  });

  test(
    'a read that failed is the failure as it was raised, not a wrapper',
    () async {
      final reads = _Reads();
      final container = ProviderContainer.test(overrides: reads.overrides);
      final sub = container.listen(
        stockSheetChoicesProvider('ws-1'),
        (_, _) {},
      );
      final answer = container.read(stockSheetChoicesProvider('ws-1').future);
      reads.items.complete(const []);
      reads.places.completeError(StateError('offline'));
      await expectLater(answer, throwsA(isA<StateError>()));
      sub.close();
    },
  );

  group('StockSheetOpener', () {
    Future<(WidgetRef, BuildContext)> pump(
      WidgetTester tester,
      _Reads reads,
    ) async {
      late WidgetRef ref;
      late BuildContext context;
      await pumpApp(
        tester,
        Scaffold(
          body: Consumer(
            builder: (c, r, _) {
              ref = r;
              context = c;
              return const SizedBox();
            },
          ),
        ),
        overrides: reads.overrides,
      );
      return (ref, context);
    }

    testWidgets('a failed read says so and opens nothing', (tester) async {
      final reads = _Reads();
      final (ref, context) = await pump(tester, reads);
      var opened = 0;
      final asked = StockSheetOpener(ref).open(
        context,
        'ws-1',
        what: 'test',
        sheet: (_) async {
          opened++;
          return true;
        },
      );
      reads.places.complete(const []);
      reads.items.completeError(StateError('offline'));
      await asked;
      await tester.pumpAndSettle();
      expect(opened, 0);
      expect(find.text(_en.stockReadFailed), findsOneWidget);
    });

    testWidgets(
      'a sheet that changed something has the reads asked again; one that did not, not',
      (tester) async {
        final reads = _Reads();
        reads.items.complete(const []);
        reads.places.complete(const []);
        final (ref, context) = await pump(tester, reads);
        ref.listenManual(stockItemsProvider('ws-1'), (_, _) {});
        await tester.pump();
        final asked = reads.itemsAsked;

        await StockSheetOpener(ref).open(
          context,
          'ws-1',
          what: 'test',
          sheet: (_) async => false,
          reads: [stockItemsProvider('ws-1')],
        );
        await tester.pump();
        expect(
          reads.itemsAsked,
          asked,
          reason: 'nothing changed, nothing is read again',
        );

        StockSheetChoices? given;
        await StockSheetOpener(ref).open(
          context,
          'ws-1',
          what: 'test',
          sheet: (c) async {
            given = c;
            return true;
          },
          reads: [stockItemsProvider('ws-1')],
        );
        await tester.pump();
        expect(given, isNotNull, reason: 'the sheet opens with the choices');
        expect(
          reads.itemsAsked,
          asked + 1,
          reason: 'what the sheet changed is read again',
        );
        expect(find.text(_en.stockReadFailed), findsNothing);
      },
    );
  });
}
