// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3726 (K1) — an installation may accept only newer apps. Below its floor
// the app shows one screen with the way to update and the way out (the
// Server screen, signing out); at or above it, or with no floor, nothing
// changes; a floor that could not be read never blocks. A verdict once
// read is kept while the installation cannot be asked, and a newer answer
// replaces it.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/schema_gate.dart';
import 'package:deskilo/core/backend/app_floor.dart';
import 'package:deskilo/core/instance/app_compatibility.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_providers.dart';

/// A source whose answers a test changes between reads.
class _SwitchingSource implements AppFloorSource {
  int? floor;
  bool unavailable = false;
  int reads = 0;
  @override
  Future<int?> read() async {
    reads++;
    if (unavailable) throw const AppFloorUnavailable('offline in the test');
    return floor;
  }
}

Future<void> _boot(WidgetTester tester, AppFloorSource source,
    {Size size = const Size(390, 844), bool signedIn = true}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        appFloor: source,
        auth: signedIn ? null : FakeAuthRepository(),
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
}

const _update = ValueKey('app-update');

void main() {
  group('judgeAppFloor', () {
    test('no floor accepts every app', () {
      expect(judgeAppFloor(null), AppFloorVerdict.accepted);
    });
    test('at or above the floor is accepted, below is not', () {
      expect(judgeAppFloor(3, app: 3), AppFloorVerdict.accepted);
      expect(judgeAppFloor(3, app: 4), AppFloorVerdict.accepted);
      expect(judgeAppFloor(3, app: 2), AppFloorVerdict.below);
    });
  });

  group('appFloorGateRedirect', () {
    test('below sends an ordinary route to the update screen', () {
      expect(appFloorGateRedirect(AppFloorVerdict.below, '/reserve'),
          kAppUpdateRoute);
    });
    test('below leaves the way out open', () {
      for (final open in ['/server', '/server/new-instance', '/help',
          '/privacy', '/demo', kAppUpdateRoute]) {
        expect(appFloorGateRedirect(AppFloorVerdict.below, open), isNull,
            reason: open);
      }
    });
    test('accepted and unknown gate nothing, and leave the update screen', () {
      for (final v in [null, AppFloorVerdict.accepted, AppFloorVerdict.unknown]) {
        expect(appFloorGateRedirect(v, '/reserve'), isNull);
        expect(appFloorGateRedirect(v, kAppUpdateRoute), '/reserve');
      }
    });
  });

  group('appFloorProvider', () {
    test('a failed refresh keeps a known refusal; a newer answer replaces it',
        () async {
      final source = _SwitchingSource()..floor = appCompatibilityNumber + 1;
      final c = ProviderContainer(
          overrides: [appFloorSourceProvider.overrideWithValue(source)]);
      addTearDown(c.dispose);
      expect(await c.read(appFloorProvider.future), AppFloorVerdict.below);

      source.unavailable = true;
      c.invalidate(appFloorProvider);
      expect(await c.read(appFloorProvider.future), AppFloorVerdict.below,
          reason: 'silence does not reopen an installation known to refuse');

      source
        ..unavailable = false
        ..floor = null;
      c.invalidate(appFloorProvider);
      expect(await c.read(appFloorProvider.future), AppFloorVerdict.accepted,
          reason: 'a lowered floor, read successfully, unblocks');
    });

    test('a floor never read is unknown, and unknown never blocks', () async {
      final c = ProviderContainer(overrides: [
        appFloorSourceProvider.overrideWithValue(
            const FixedAppFloorSource(null, unavailable: true)),
      ]);
      addTearDown(c.dispose);
      expect(await c.read(appFloorProvider.future), AppFloorVerdict.unknown);
      expect(appFloorGateRedirect(AppFloorVerdict.unknown, '/reserve'), isNull);
    });
  });

  for (final size in const [Size(390, 844), Size(1440, 900)]) {
    final w = size.width.toInt();
    testWidgets('at $w: below the floor shows the update screen with its way out',
        (tester) async {
      await _boot(tester, const FixedAppFloorSource(appCompatibilityNumber + 1),
          size: size);
      expect(find.byKey(_update), findsOneWidget);
      expect(find.text('This app needs an update'), findsOneWidget);
      expect(find.byKey(const ValueKey('app-update-how')), findsOneWidget);
      expect(find.byKey(const ValueKey('app-update-server')), findsOneWidget);
      expect(find.byKey(const ValueKey('app-update-sign-out')), findsOneWidget);
      for (final key in ['app-update-retry', 'app-update-server',
          'app-update-sign-out']) {
        final s = tester.getSize(find.byKey(ValueKey(key)));
        expect(s.height, greaterThanOrEqualTo(48), reason: key);
      }
    });
  }

  testWidgets('signed out below the floor: the screen, without a sign-out',
      (tester) async {
    await _boot(tester, const FixedAppFloorSource(appCompatibilityNumber + 1),
        signedIn: false);
    expect(find.byKey(_update), findsOneWidget);
    expect(find.byKey(const ValueKey('app-update-sign-out')), findsNothing);
  });

  testWidgets('no floor, at the floor, or an unreadable floor: no screen',
      (tester) async {
    for (final source in const [
      FixedAppFloorSource(null),
      FixedAppFloorSource(appCompatibilityNumber),
      FixedAppFloorSource(null, unavailable: true),
    ]) {
      await _boot(tester, source);
      expect(find.byKey(_update), findsNothing);
    }
  });
}
