// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4038 -- a screen opened by its route, never by a word of the language it
// is shown in: the matrix walks the same screen in five languages.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Goes to [path] through the app's router and lets the screen settle.
Future<void> goToRoute(WidgetTester tester, String path) async {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go(path);
  await tester.pumpAndSettle();
}
