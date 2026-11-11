// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3679 -- the kit's action button is busy while its action runs.
import 'dart:async';

import 'package:deskilo/core/ui/kit/kit_action_button.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  const key = ValueKey('go');

  testWidgets('a second tap while the first runs does nothing', (t) async {
    final gate = Completer<void>();
    var calls = 0;
    await t.pumpWidget(_host(KitActionButton(
      key: key,
      label: 'Issue',
      onPressed: () {
        calls++;
        return gate.future;
      },
    )));
    await t.tap(find.byKey(key));
    await t.pump();
    await t.tap(find.byKey(key), warnIfMissed: false);
    await t.pump();
    expect(calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    gate.complete();
    await t.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('enabled again after success and after an error', (t) async {
    var calls = 0;
    var fail = false;
    await t.pumpWidget(_host(KitActionButton(
      key: key,
      label: 'Issue',
      onPressed: () async {
        calls++;
        if (fail) throw StateError('refused');
      },
    )));
    await t.tap(find.byKey(key));
    await t.pump();
    expect(calls, 1);
    fail = true;
    await runZonedGuarded(() async {
      await t.tap(find.byKey(key));
      await t.pump();
    }, (_, _) {});
    expect(calls, 2);
    await t.pump();
    final button = t.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull, reason: 'the error released it');
  });

  testWidgets('the busy state is announced and a screen can add its own',
      (t) async {
    final handle = t.ensureSemantics();
    final gate = Completer<void>();
    await t.pumpWidget(_host(KitActionButton(
      key: key,
      label: 'Issue',
      onPressed: () => gate.future,
    )));
    await t.tap(find.byKey(key));
    await t.pump();
    expect(find.bySemanticsLabel(RegExp('Working')), findsWidgets,
        reason: 'announced while it runs');
    gate.complete();
    await t.pump();
    handle.dispose();

    await t.pumpWidget(_host(KitActionButton(
      key: key,
      label: 'Issue',
      busy: true,
      onPressed: () async {},
    )));
    expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
  });

  testWidgets('a null action is a disabled button', (t) async {
    await t.pumpWidget(_host(const KitActionButton(
      key: key,
      label: 'Issue',
      onPressed: null,
      tonal: true,
    )));
    expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
  });
}
