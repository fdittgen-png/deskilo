// SPDX-License-Identifier: 0BSD
//
// Boot splash (field request): from the very first frame the user sees
// the brand splash, the data warm-up runs behind it, and the finished
// screen fades in — never the form assembling itself.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_floor_plan_repository.dart';
import '../helpers/mock_providers.dart';

void main() {
  testWidgets(
      'the splash covers the first frames; once the warm-up resolves the '
      'shell fades in and the splash is gone', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(
          floorPlan: FakeFloorPlanRepository()..seedSmallPlan(),
        ),
        child: const DeskiloApp(),
      ),
    );
    // First frame: splash only — no shell underneath being "built".
    // (With the in-memory fakes the warm-up resolves within a frame or
    // two, so assert on the very first one.)
    expect(find.byKey(const ValueKey('boot-splash')), findsOneWidget);
    expect(find.byType(ShellBottomBar), findsNothing);

    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('boot-splash')), findsNothing);
    expect(find.byType(ShellBottomBar), findsOneWidget);
  });
}
