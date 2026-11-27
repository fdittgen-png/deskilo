// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4492 -- the place a till sells from. The invariant: a till is saved whole, with the place it sells from, and what
// its sheet could not read or does not show is saved as it was read. Proven: the answer of the server is read with the
// business's selling place; the Demo's port keeps the server's rules (a place it does not offer is refused and changes
// nothing; a place the till already has is kept); the sheet gives a till its place, a rename keeps the place and the
// site, a place the list no longer offers is shown and kept, the places that could not be read are said with a way to
// ask again and never become "no place", and where the business keeps no goods the sheet shows no place; the lot choice
// names the till of the sale.
import 'dart:async';

import 'package:deskilo/core/demo/data/demo_till.dart';
import 'package:deskilo/core/demo/data/demo_till_drawer.dart';
import 'package:deskilo/features/money/domain/counter_till.dart';
import 'package:deskilo/features/money/domain/till_drawer.dart';
import 'package:deskilo/features/money/presentation/till_drawer/till_drawer_screen.dart';
import 'package:deskilo/features/money/presentation/till_lot_choice.dart';
import 'package:deskilo/features/money/presentation/till_session.dart';
import 'package:deskilo/features/money/providers/till_drawer_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();

const _settings = DrawerSettings(blindCount: true, byDenomination: false, reasons: ['change', 'expense', 'other'], paidOutLimitMinor: 0);
const _front = DrawerTill(id: 'till-front', name: 'Front', active: true, siteId: 'site-1', sellingPlaceId: 'demo-place-shelf');

/// The Demo's drawer whose places cannot be read the first [failures] times.
class _FlakyPlaces extends DemoTillDrawer {
  _FlakyPlaces({required this.failures, super.tills});

  int failures;

  @override
  Future<TillSellingPlaces> sellingPlaces(String workspaceId) async {
    if (failures > 0) {
      failures--;
      throw StateError('the places were not read');
    }
    return super.sellingPlaces(workspaceId);
  }
}

/// A lots port that keeps the till it was asked for.
class _AskedLots implements TillLotsPort {
  final List<String?> tills = [];

  @override
  Future<List<TillLot>> lots(String workspaceId, String itemId, {String? tillId}) async {
    tills.add(tillId);
    return const [];
  }
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.tap(find.byKey(ValueKey(key)));
  await _settle(tester);
}

Future<void> _open(WidgetTester tester, DemoTillDrawer drawer, {bool offered = true}) async {
  await pumpApp(
    tester,
    const TillDrawerScreen(workspaceId: 'ws-1', currency: 'EUR', canManage: true),
    size: const Size(390, 844),
    overrides: [
      tillDrawerPortProvider.overrideWithValue(drawer),
      drawerSettingsProvider.overrideWith((ref) => _settings),
      tillSellingPlaceOfferedProvider.overrideWithValue(offered),
    ],
  );
  await _settle(tester);
}

Future<DrawerTill> _till(DemoTillDrawer drawer, String id) async => (await drawer.tills('ws-1')).firstWhere((t) => t.id == id);

void main() {
  test('the server\'s answers are read: a till with its place, the places a till may be given', () {
    final till = DrawerTill.fromJson({'id': 't', 'name': 'Front', 'active': true, 'site_id': null, 'selling_place_id': 'p-1'});
    expect([till.sellingPlaceId, till.siteId], ['p-1', null]);
    expect(DrawerTill.fromJson({'id': 't', 'name': 'Kiosk', 'active': true}).sellingPlaceId, isNull, reason: 'no place of its own');
    expect(DrawerTill.saved({'till_id': 't', 'name': 'Front', 'active': true, 'selling_place_id': 'p-1'}).sellingPlaceId, 'p-1');
    final places = TillSellingPlaces.fromJson({
      'default_code': 'MAIN',
      'default_place_id': 'p-0',
      'places': [
        {'id': 'p-0', 'code': 'MAIN', 'name': '', 'path': ['MAIN']},
        {'id': 'p-1', 'code': 'SHELF-A', 'name': 'Shelf A', 'path': ['MAIN', 'FLOOR', 'SHELF-A']},
      ],
    });
    expect(places.defaultCode, 'MAIN');
    expect([for (final p in places.places) p.label], ['MAIN', 'MAIN / FLOOR / SHELF-A · Shelf A']);
  });

  group('the Demo keeps the server\'s rules', () {
    test('a till is saved with its place, and without one it sells from the business\'s', () async {
      final drawer = DemoTillDrawer();
      await drawer.saveTill('ws-1', requestId: 'r1', till: const DrawerTillEdit(tillId: 'demo-till-front', name: 'Front counter', active: true, sellingPlaceId: 'demo-place-sales'));
      expect((await _till(drawer, 'demo-till-front')).sellingPlaceId, 'demo-place-sales');
      await drawer.saveTill('ws-1', requestId: 'r2', till: const DrawerTillEdit(tillId: 'demo-till-front', name: 'Front counter', active: true));
      expect((await _till(drawer, 'demo-till-front')).sellingPlaceId, isNull);
    });

    test('a place the business does not sell from is refused and the till stays as it was', () async {
      final drawer = DemoTillDrawer(tills: [_front]);
      await expectLater(
        drawer.saveTill('ws-1', requestId: 'r1', till: const DrawerTillEdit(tillId: 'till-front', name: 'Front', active: true, sellingPlaceId: 'no-such-place')),
        throwsA(isA<PostgrestException>().having((e) => '${e.details}', 'reason', contains('selling_place_unknown'))),
      );
      expect((await _till(drawer, 'till-front')).sellingPlaceId, 'demo-place-shelf');
      // recovery: the same till saved with a place that is offered
      await drawer.saveTill('ws-1', requestId: 'r2', till: const DrawerTillEdit(tillId: 'till-front', name: 'Front', active: true, sellingPlaceId: 'demo-place-main'));
      expect((await _till(drawer, 'till-front')).sellingPlaceId, 'demo-place-main');
    });

    test('the place a till already has is kept although the list no longer offers it', () async {
      const gone = DrawerTill(id: 'till-old', name: 'Old', active: true, sellingPlaceId: 'place-gone');
      final drawer = DemoTillDrawer(tills: [gone]);
      await drawer.saveTill('ws-1', requestId: 'r1', till: const DrawerTillEdit(tillId: 'till-old', name: 'Old till', active: true, sellingPlaceId: 'place-gone'));
      final saved = await _till(drawer, 'till-old');
      expect([saved.name, saved.sellingPlaceId], ['Old till', 'place-gone']);
    });
  });

  testWidgets('a till is given the place it sells from', (tester) async {
    final drawer = DemoTillDrawer();
    await _open(tester, drawer);
    await _tap(tester, 'drawer-edit-demo-till-front');
    expect(find.text(_en.tillDrawerSellingPlaceBusiness('MAIN')), findsWidgets, reason: 'a till that names no place sells from the business\'s');
    expect(find.text(_en.tillDrawerSellingPlaceNote), findsOneWidget);
    await _tap(tester, 'drawer-till-selling-place');
    await tester.tap(find.text('MAIN / SALES · Sales floor').last);
    await _settle(tester);
    await _tap(tester, 'drawer-till-save');
    expect((await _till(drawer, 'demo-till-front')).sellingPlaceId, 'demo-place-sales');
  });

  testWidgets('a rename keeps the place and the site of the till', (tester) async {
    final drawer = DemoTillDrawer(tills: [_front]);
    await _open(tester, drawer);
    await _tap(tester, 'drawer-edit-till-front');
    await tester.enterText(find.byKey(const ValueKey('drawer-till-name')), 'Front counter');
    await tester.pump();
    await _tap(tester, 'drawer-till-save');
    final saved = await _till(drawer, 'till-front');
    expect([saved.name, saved.sellingPlaceId, saved.siteId], ['Front counter', 'demo-place-shelf', 'site-1']);
  });

  testWidgets('a place the list no longer offers is shown as the till has it and saved as it was read', (tester) async {
    const gone = DrawerTill(id: 'till-old', name: 'Old', active: true, sellingPlaceId: 'place-gone');
    final drawer = DemoTillDrawer(tills: [gone]);
    await _open(tester, drawer);
    await _tap(tester, 'drawer-edit-till-old');
    expect(find.text(_en.tillDrawerSellingPlaceStored), findsWidgets);
    await tester.enterText(find.byKey(const ValueKey('drawer-till-name')), 'Old till');
    await tester.pump();
    await _tap(tester, 'drawer-till-save');
    final saved = await _till(drawer, 'till-old');
    expect([saved.name, saved.sellingPlaceId], ['Old till', 'place-gone']);
  });

  testWidgets('places that could not be read are said, never taken for "no place", and are asked again', (tester) async {
    final drawer = _FlakyPlaces(failures: 1, tills: [_front]);
    await _open(tester, drawer);
    await _tap(tester, 'drawer-edit-till-front');
    expect(find.byKey(const ValueKey('drawer-till-places-retry')), findsOneWidget);
    expect(find.byKey(const ValueKey('drawer-till-selling-place')), findsNothing);
    // asked again, the places are read and the till's own is the one shown
    await _tap(tester, 'drawer-till-places-retry');
    expect(find.byKey(const ValueKey('drawer-till-selling-place')), findsOneWidget);
    expect(find.text('MAIN / SHELF-A · Shelf A'), findsWidgets);
  });

  testWidgets('saved while its places could not be read, the till keeps the place it has', (tester) async {
    final drawer = _FlakyPlaces(failures: 5, tills: [_front]);
    await _open(tester, drawer);
    await _tap(tester, 'drawer-edit-till-front');
    await tester.enterText(find.byKey(const ValueKey('drawer-till-name')), 'Front desk');
    await tester.pump();
    await _tap(tester, 'drawer-till-save');
    final saved = await _till(drawer, 'till-front');
    expect([saved.name, saved.sellingPlaceId], ['Front desk', 'demo-place-shelf']);
  });

  testWidgets('where the business keeps no goods the sheet shows no place and a save keeps the one the till has', (tester) async {
    final drawer = DemoTillDrawer(tills: [_front]);
    await _open(tester, drawer, offered: false);
    await _tap(tester, 'drawer-edit-till-front');
    expect(find.byKey(const ValueKey('drawer-till-selling-place')), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('drawer-till-name')), 'Front desk');
    await tester.pump();
    await _tap(tester, 'drawer-till-save');
    expect((await _till(drawer, 'till-front')).sellingPlaceId, 'demo-place-shelf');
  });

  testWidgets('the lot choice asks for the lots of the till the sale is made at', (tester) async {
    final asked = _AskedLots();
    final session = TillSession(port: DemoTill(country: 'FR', currency: 'EUR', vatPercent: 20), workspaceId: 'ws-1');
    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            key: const ValueKey('choose'),
            onPressed: () => unawaited(chooseTillLot(context, asked, session, 0)),
            child: const Text('choose'),
          ),
        ),
      ),
      overrides: standardTestOverrides(),
    );
    unawaited(session.add(itemId: 'demo-item-milk', name: 'Oat milk', unit: 'l'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    session.tillId = 'till-front';
    await tester.tap(find.byKey(const ValueKey('choose')));
    await _settle(tester);
    expect(asked.tills, ['till-front']);
  });
}
