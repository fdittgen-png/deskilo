// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2601 — pumpApp passes through exactly what a test asks for: a custom
// provider, a non-English locale, a large text scale, a router and a view
// size all reach the screen, and nothing leaks into the next test.
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/pump_app.dart';

final _sentinel = Provider<String>((ref) => 'real');

class _Probe extends ConsumerWidget {
  const _Probe();
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    children: [
      Text(ref.watch(_sentinel), key: const ValueKey('sentinel')),
      Text(
        AppLocalizations.of(context)!.commonCancel,
        key: const ValueKey('cancel'),
      ),
      Text(
        '${MediaQuery.textScalerOf(context).scale(10)}',
        key: const ValueKey('scale'),
      ),
    ],
  );
}

String _text(WidgetTester t, String key) =>
    t.widget<Text>(find.byKey(ValueKey(key))).data!;

void main() {
  testWidgets('a custom provider, a locale and a text scale arrive unchanged', (
    t,
  ) async {
    await pumpApp(
      t,
      const _Probe(),
      overrides: [_sentinel.overrideWithValue('custom')],
      locale: const Locale('fr'),
      textScale: 2,
    );
    expect(_text(t, 'sentinel'), 'custom');
    expect(_text(t, 'cancel'), 'Annuler');
    expect(_text(t, 'scale'), '20.0');
  });

  testWidgets('without overrides the real provider answers, in English', (
    t,
  ) async {
    await pumpApp(t, const _Probe());
    expect(_text(t, 'sentinel'), 'real');
    expect(_text(t, 'cancel'), 'Cancel');
    expect(_text(t, 'scale'), '10.0');
  });

  testWidgets('a router is pumped, and home is refused beside it', (t) async {
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const _Probe())],
    );
    addTearDown(router.dispose);
    await pumpApp(t, null, router: router, locale: const Locale('de'));
    expect(_text(t, 'cancel'), 'Abbrechen');
    expect(
      () => pumpApp(t, const _Probe(), router: router),
      throwsA(isA<AssertionError>()),
    );
  });

  testWidgets('the view size and pixel ratio are restored by pumpApp\'s own '
      'cleanup, in this case alone', (t) async {
    final defaultSize = t.view.physicalSize;
    final defaultRatio = t.view.devicePixelRatio;
    // Registered BEFORE pumpApp, so it runs AFTER the helper's own teardown
    // callbacks (they run in reverse order): it observes what they left.
    addTearDown(() {
      expect(t.view.physicalSize, defaultSize, reason: 'the size was not reset');
      expect(
        t.view.devicePixelRatio,
        defaultRatio,
        reason: 'the pixel ratio was not reset',
      );
    });
    await pumpApp(t, const _Probe(), size: const Size(360, 640), pixelRatio: 2);
    expect(t.view.physicalSize, const Size(720, 1280));
    expect(t.view.devicePixelRatio, 2);
    expect(const Size(720, 1280), isNot(defaultSize));
    expect(defaultRatio, isNot(2));
  });
}
