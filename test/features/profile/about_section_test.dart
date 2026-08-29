// SPDX-License-Identifier: 0BSD
//
// The About section (#560, the Sparkilo idiom): who builds the app,
// under which licence, where to report — and how to support the
// project. Every tile opens its external link through the launcher
// seam; the facts (author, handles, repo) are consts, not l10n keys.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/links/link_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

void main() {
  testWidgets(
      'the About section names the author, licence and privacy policy, '
      'and the support tiles open PayPal/Revolut through the launcher',
      (tester) async {
    // #719 added the Privacy & data tile; 2700 no longer reached Revolut.
    tester.view.physicalSize = const Size(800, 2900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final launched = <Uri>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...standardTestOverrides(),
          linkLauncherProvider.overrideWithValue((uri) async {
            launched.add(uri);
            return true;
          }),
        ],
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('about-version')), findsOneWidget);
    expect(find.text('Florian DITTGEN'), findsOneWidget);
    expect(find.text('fdittgen@gmail.com'), findsOneWidget);
    expect(find.byKey(const ValueKey('about-privacy')), findsOneWidget);
    expect(find.byKey(const ValueKey('about-issues')), findsOneWidget);
    expect(find.text('Support this project'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('about-paypal')));
    await tester.tap(find.byKey(const ValueKey('about-revolut')));
    await tester.tap(find.byKey(const ValueKey('about-source')));
    await tester.pump();

    expect(
      launched.map((u) => u.toString()),
      containsAll([
        'https://paypal.me/FlorianDITTGEN',
        'https://revolut.me/floriamcep',
        'https://github.com/fdittgen-png/deskilo',
      ]),
    );
  });
}
