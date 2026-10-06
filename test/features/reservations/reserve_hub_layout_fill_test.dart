// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Invariant: in portrait the plan / day view gets ALL the height the header
// does not use — not half of it. A short header used to leave the lower part
// of the screen blank because header and content shared the free height.
import 'package:deskilo/features/reservations/presentation/widgets/reserve_hub_layout.dart';
import 'package:deskilo/features/reservations/presentation/widgets/reserve_view_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, double headerHeight) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: ReserveHubLayout(
        header: SizedBox(height: headerHeight),
        view: ReserveView.day,
        buildView: (_) => const SizedBox.expand(key: ValueKey('content')),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the content takes everything below a short header', (
    tester,
  ) async {
    await _pump(tester, 200);
    expect(tester.getSize(find.byKey(const ValueKey('content'))).height, 700);
  });

  testWidgets('a tall header scrolls and leaves the content its share', (
    tester,
  ) async {
    await _pump(tester, 2000);
    final content = tester.getSize(find.byKey(const ValueKey('content')));
    expect(content.height, closeTo(900 * 0.45, 1));
    expect(
      tester
          .getSize(find.byKey(const ValueKey('reserve-header-scroll')))
          .height,
      closeTo(900 * 0.55, 1),
    );
  });
}
