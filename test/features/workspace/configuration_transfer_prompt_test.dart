// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2331 — somebody who may not change the space's features is told why the
// configuration would not apply, and is never offered a switch they cannot
// flip.
import 'package:deskilo/features/workspace/presentation/widgets/configuration_transfer_prompt.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _open(WidgetTester tester, {required bool may}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => askConfigurationTransfer(context, maySwitchOn: may),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('without the right: no switch, the reason, and a way on', (
    tester,
  ) async {
    await _open(tester, may: false);
    expect(
      find.byKey(const Key('configurationTransferSwitchOn')),
      findsNothing,
    );
    expect(
      find.textContaining('only somebody who may change its configuration'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Configuration in the space file'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('configurationTransferSkip')), findsOneWidget);
  });

  testWidgets('with the right: the switch is offered', (tester) async {
    await _open(tester, may: true);
    expect(
      find.byKey(const Key('configurationTransferSwitchOn')),
      findsOneWidget,
    );
    expect(find.text('Switch it on and apply'), findsOneWidget);
  });
}
