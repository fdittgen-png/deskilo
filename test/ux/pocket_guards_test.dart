// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3620 (desk P0) -- the pocket posture is guarded. The reserve hub (plan,
// day, week), the booking sheet, the calendar, a reservation's own sheet and
// its deep link, and the kiosk with its sheet and receipt each pass the
// experience guards (test/ux/experience_guards.dart): no overflow, one filled
// button at phone width, every control 48 dp and named. Phones are walked at
// 320 and 390 px, text 1.0 and 1.3, light and dark; the kiosk tablet at
// 1280 x 800 (landscape) and 800 x 1280 (portrait). Desk work cannot degrade
// them without one of these going red. My reservations is the `data
// reservations` row of the Me guards (test/ux/me_screens.dart).
//
// [_known] is the named list of what is still wrong: case -> the rules it
// breaks. A case that stops breaking one fails until the entry is removed, so
// the list only falls.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_providers.dart' show kTestNow;
import '../helpers/reserve_view.dart';
import '../helpers/screens/calendar_hub.dart' as calendar;
import '../helpers/screens/kiosk_screen.dart' as kiosk;
import '../helpers/screens/reserve_hub.dart' as reserve;
import 'experience_guards.dart';

/// The two phones the pocket guards walk, as real windows.
const List<Size> _phones = [Size(320, 640), Size(390, 844)];

/// The wall tablet, landscape and portrait.
const List<Size> _tablets = [Size(1280, 800), Size(800, 1280)];

/// What is still wrong: case -> rules. Only falls (#3620).
const Map<String, Set<String>> _known = {
  // A seat drawn on the plan is 59 x 39 dp at 320 px: the canvas scales the
  // floor to the window, and a seat is a few cells of it. The seat list
  // (the view switch beside it) is the touch-sized way to the same seat.
  'reserve · plan': {'target under 48 dp'},
  'reserve · first-run card': {'target under 48 dp'},
  // The week grid at 320 px draws each day 18 dp wide: its day headers are
  // 38 x 34 and its slot cells are 18 x 29 and carry no name.
  'reserve · week': {'target under 48 dp', 'unnamed control'},
};

/// Opens one surface at [size] with the platform set to the cell's text
/// scale and theme; the test then reads the guards off the tree.
typedef _Open = Future<void> Function(WidgetTester tester, Size size);

void _setPlatform(
  WidgetTester tester, {
  required bool dark,
  required double scale,
}) {
  tester.platformDispatcher.platformBrightnessTestValue = dark
      ? Brightness.dark
      : Brightness.light;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  tester.platformDispatcher.localesTestValue = const [Locale('en')];
  tester.platformDispatcher.localeTestValue = const Locale('en');
  addTearDown(tester.platformDispatcher.clearAllTestValues);
}

/// The rules the surface on screen breaks at [size], for a thumb: the desk
/// guards' reading of overflow, cut information, 48 dp and names (a control
/// a list has scrolled half out of view is measured where it is whole),
/// and at phone width no second filled button.
Set<String> _problems(WidgetTester tester, Size size, List<String> details) {
  for (final n in tappableRects(tester)) {
    if (!n.named) details.add('unnamed ${n.rect}');
  }
  return {
    ...deskGuardProblems(
      tester,
      kind: PageKind.task,
      size: size,
      policy: TargetPolicy.touch,
      details: details,
    ),
    if (size.width < 600 && visibleFilledButtons() > 1)
      'more than one filled button',
  };
}

void _guard(String id, List<Size> sizes, _Open open) {
  testWidgets(id, (tester) async {
    await loadSheetFonts(always: true);
    final semantics = tester.ensureSemantics();
    final found = <String, Set<String>>{};
    final details = <String>[];
    for (final dark in [false, true]) {
      for (final scale in guardScales) {
        for (final size in sizes) {
          _setPlatform(tester, dark: dark, scale: scale);
          // A fresh app per cell: no router, sheet or scroll carried over.
          await tester.pumpWidget(const SizedBox());
          await open(tester, size);
          final tag =
              '${size.width.toInt()}x${size.height.toInt()}, '
              '×$scale, ${dark ? 'dark' : 'light'}';
          final cell = <String>[];
          for (final p in _problems(tester, size, cell)) {
            found.putIfAbsent(p, () => {}).add(tag);
          }
          details.addAll([for (final d in cell) '$tag $d']);
          if (scale == 1.0) {
            await writeSheet(
              tester,
              sheet: 'pocket',
              name:
                  '${id.replaceAll(RegExp(r'[ /:]+'), '-')}--'
                  '${size.width.toInt()}--${dark ? 'dark' : 'light'}',
            );
          }
        }
      }
    }
    semantics.dispose();
    expect(
      {for (final e in found.entries) e.key},
      _known[id] ?? <String>{},
      reason: '$id breaks: ${found.keys} by ${details.take(12).join('\n  ')}',
    );
  });
}

/// The hub on a member's usual day: the first-run card put away.
Future<void> _hub(
  WidgetTester t,
  Size s, {
  List<Reservation> seed = const [],
}) async {
  await reserve.pumpHub(t, size: s, seed: seed);
  final dismiss = find.byKey(const ValueKey('getting-started-dismiss'));
  if (dismiss.evaluate().isEmpty) return;
  // The same call the button makes, without scrolling the header with it.
  t.widget<TextButton>(dismiss).onPressed!();
  await t.pumpAndSettle();
}

/// One own, upcoming booking of member-1 on the seeded seat, today.
final _mine = reserve.reservationOn(
  DateTime(kTestNow.year, kTestNow.month, kTestNow.day),
  id: 'res-1',
);

void main() {
  setUpAll(() {
    WorkspaceTime.install('Europe/Berlin');
    kiosk.kioskClock = FixedClock(
      WorkspaceTime.at(kTestNow.year, kTestNow.month, kTestNow.day, 10),
    );
  });
  tearDownAll(WorkspaceTime.reset);

  // The reserve hub: the plan, the day, the week.
  _guard('reserve · plan', _phones, (t, s) async {
    await _hub(t, s, seed: [_mine]);
  });
  // The first run: the card that names the next step stays on the page.
  _guard('reserve · first-run card', _phones, (t, s) async {
    await reserve.pumpHub(t, size: s);
  });
  _guard('reserve · day', _phones, (t, s) async {
    await _hub(t, s, seed: [_mine]);
    await pickReserveView(t, 'day');
    await t.pumpAndSettle();
  });
  _guard('reserve · week', _phones, (t, s) async {
    await _hub(t, s, seed: [_mine]);
    await pickReserveView(t, 'week');
    await t.pumpAndSettle();
  });

  // The sheets a seat opens: a free seat books, an own booking offers its
  // check-in and cancel.
  _guard('reserve · booking sheet', _phones, (t, s) async {
    await _hub(t, s);
    await t.tapAt(reserve.seatCenter(t));
    await t.pumpAndSettle();
  });
  _guard('reserve · own booking sheet', _phones, (t, s) async {
    await _hub(t, s, seed: [_mine]);
    await t.tapAt(reserve.seatCenter(t));
    await t.pumpAndSettle();
  });

  _guard('calendar', _phones, (t, s) async {
    await calendar.pumpHub(t, size: s);
  });

  // The deep link a notification opens.
  _guard('/res/:id', _phones, (t, s) async {
    await _hub(t, s, seed: [_mine]);
    ProviderScope.containerOf(t.element(find.byType(DeskiloApp)))
        .read(routerProvider)
        .go('/res/res-1');
    await t.pumpAndSettle();
  });

  // The kiosk: the gate, the plan, the one sheet, the receipt.
  _guard('kiosk · gate', _tablets, (t, s) async {
    await kiosk.pumpKiosk(t, size: s, startKiosk: false);
  });
  _guard('kiosk · plan', _tablets, (t, s) async {
    await kiosk.pumpKiosk(t, size: s);
  });
  _guard('kiosk · sheet', _tablets, (t, s) async {
    await kiosk.pumpKiosk(t, size: s);
    await t.tapAt(kiosk.seatCenter(t));
    await t.pumpAndSettle();
    // The sheet is the surface under guard: it must be on screen.
    expect(find.byKey(const ValueKey('kiosk-badge-field')), findsOneWidget);
  });
  _guard('kiosk · receipt', _tablets, (t, s) async {
    await kiosk.pumpKiosk(t, size: s);
    await t.tapAt(kiosk.seatCenter(t));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('kiosk-check-in')));
    await t.pumpAndSettle();
    await t.enterText(
      find.byKey(const ValueKey('kiosk-badge-field')),
      'badge-token-1',
    );
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('kiosk-success-card')), findsOneWidget);
  });
}
