// SPDX-License-Identifier: 0BSD
//
// #1205 — the logo and the name, as one lockup.
//
// The boot splash shows the app's face and used to hand over to a
// sign-in screen that dropped it, so the brand vanished at exactly the
// moment somebody is deciding whether they opened the right app.
import 'package:deskilo/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

Finder get _logo => find.byKey(const ValueKey('signin-logo'));
Finder get _title => find.text('DesKilo');

Future<void> pumpSignIn(
  WidgetTester tester, {
  Size size = const Size(400, 800),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(auth: FakeAuthRepository()),
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: const DeskiloApp(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the mark sits to the LEFT of the name, on one line',
      (tester) async {
    await pumpSignIn(tester);
    expect(_logo, findsOneWidget);
    expect(_title, findsOneWidget);

    final mark = tester.getRect(_logo);
    final word = tester.getRect(_title);
    expect(mark.right, lessThanOrEqualTo(word.left),
        reason: 'left of the title, not above it and not over it');
    expect(mark.center.dy, closeTo(word.center.dy, 4),
        reason: 'one lockup — the two share a centre line');
  });

  testWidgets('it says nothing a screen reader has not already heard',
      (tester) async {
    await pumpSignIn(tester);
    final image = tester.widget<Image>(_logo);
    expect(image.excludeFromSemantics, isTrue,
        reason: 'the word beside it IS the name; announcing the mark too '
            'reads "DesKilo" twice');
  });

  // Found while pinning the lockup, and older than it: at a large text
  // scale the "or continue with" rule ran 54 pixels off the right of a
  // 400 dp phone, because a Row's fixed child answers "too wide" by
  // overflowing. Nothing on the screen said so — the stripes only show
  // in a debug build.
  testWidgets('a narrow phone at double text size overflows nothing',
      (tester) async {
    await pumpSignIn(tester, size: const Size(400, 900), textScale: 2);
    expect(tester.takeException(), isNull);
    expect(_title, findsOneWidget);
    final mark = tester.getRect(_logo);
    expect(mark.width, greaterThan(40),
        reason: 'the mark scales WITH the text rather than shrinking '
            'beside it');
  });
}
