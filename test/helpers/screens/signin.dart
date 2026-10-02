// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1864 C — the sign-in screen pump, moved out of `test/features/auth/signin_wordmark_test.dart`:
// the accessibility matrix, the locale walk and the other suites that
// reuse it import this helper instead of a whole test file.
import 'package:deskilo/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../mock_providers.dart';

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
