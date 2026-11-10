// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3545 step A -- the screenshot sheet. Run with
//   ME_SHEET=1 flutter test test/ux/me_sheet_test.dart
// It renders every screen of test/ux/me_screens.dart in every state at 390 px,
// light and dark, with Roboto loaded (the font the app bundles) into
// build/me_sheet/<screen>--<state>--<theme>.png and prints the folder. The
// sheet is attached to a PR (before/after), never committed as a golden. Without
// ME_SHEET the test does nothing, so the suite stays fast.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:deskilo/core/time/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/me/me_app.dart';
import 'me_screens.dart';

Future<void> _loadRoboto() async {
  final loader = FontLoader('Roboto')
    ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
  await loader.load();
}

void main() {
  final enabled = Platform.environment['ME_SHEET'] == '1';
  testWidgets('render the Me screens to build/me_sheet', (tester) async {
    await _loadRoboto();
    final out = Directory('build/me_sheet')..createSync(recursive: true);
    final boundary = GlobalKey();
    for (final screen in meScreens) {
      for (final state in screen.states.entries) {
        for (final dark in [false, true]) {
          tester.platformDispatcher.platformBrightnessTestValue =
              dark ? Brightness.dark : Brightness.light;
          final scenario = state.value();
          final router = await pumpMeApp(
            tester,
            workspace: scenario.workspace,
            accountActivity: scenario.documents,
            size: const Size(390, 844),
            clock: FixedClock(meGuardNow),
            extraOverrides: scenario.overrides,
          );
          await goTo(tester, router, screen.route);
          final target = tester.firstRenderObject<RenderRepaintBoundary>(
            find.byType(RepaintBoundary).first,
          );
          final image = await tester.runAsync(target.toImage);
          final bytes = await tester.runAsync(
            () => image!.toByteData(format: ui.ImageByteFormat.png),
          );
          final name =
              '${screen.id}--${state.key.replaceAll(' ', '-')}--${dark ? 'dark' : 'light'}.png';
          File('${out.path}/$name').writeAsBytesSync(bytes!.buffer.asUint8List());
        }
      }
    }
    tester.platformDispatcher.clearAllTestValues();
    debugPrint('me sheet: ${out.path}');
    expect(boundary, isNotNull);
  }, skip: !enabled);
}
