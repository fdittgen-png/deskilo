// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4037 — the money page's content can always be reached at the narrowest
// phone and the largest text. At 320 dp with text at 200 % the Invoices
// button is tapped for real (a hit test that misses fails the test), and with
// the bar swiped away — where the body runs behind the Reserve button — the
// face's scrolling ends above it: the bottom inset is part of the padding.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_bar_visibility.dart';
import 'package:deskilo/app/shell/shell_bottom_bar.dart' show ShellBarMetrics;
import 'package:deskilo/features/money/domain/money_face.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/screens/invoices.dart';
import '../../helpers/screens/money_faces.dart';

const _phone = Size(320, 800);

void main() {
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

  testWidgets('at 320 dp and twice the text the Invoices button is tapped',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    // pumpInvoices scrolls the button into view and taps it: a tap that
    // misses throws here.
    await pumpInvoices(tester, size: _phone);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with the bar swiped away the face ends above the Reserve '
      'button, at twice the text too', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpFaces(tester, size: _phone);
    await face(tester, MoneyFace.invoices);
    // Swipe the bar away: the body now runs behind the Reserve button.
    await ProviderScope.containerOf(tester.element(find.byType(DeskiloApp)))
        .read(shellBarHiddenProvider.notifier)
        .set(hidden: true);
    await tester.pumpAndSettle();
    final list = tester.widget<ListView>(
      find.byKey(const ValueKey('money-face-body-invoices')),
    );
    expect(
      (list.padding! as EdgeInsets).bottom,
      greaterThanOrEqualTo(ShellBarMetrics.hiddenHeight),
      reason: 'the content runs behind the floating Reserve button: its '
          'scroll must end above it',
    );
  });
}
