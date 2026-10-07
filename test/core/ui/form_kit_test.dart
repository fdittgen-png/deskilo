// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Invariant: the form kit keeps its promises — controllers are created on
// demand and disposed once; a field shows its error under itself; a form
// sheet stays open with the reason when the submit is refused, cannot be
// submitted twice while saving, closes with true on success, and disposes
// what it was given when it goes away.
import 'dart:async';

import 'package:deskilo/core/ui/form_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<bool?> _openSheet(
  WidgetTester tester,
  Future<String?> Function() onSubmit, {
  VoidCallback? onDispose,
}) async {
  bool? result;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await showAppFormSheet(
                context,
                AppFormSheet(
                  title: 'New thing',
                  submitLabel: 'Save',
                  submitKey: const ValueKey('save'),
                  onSubmit: onSubmit,
                  onDispose: onDispose,
                  builder: (context, refresh) => [
                    AppTextField(
                      controller: TextEditingController(),
                      label: 'Name',
                    ),
                  ],
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  test('controllers are made on demand, trimmed, and disposed once', () {
    final fields = FormControllers({'name': '  Ana  '});
    expect(fields.text('name'), 'Ana');
    fields['city'].text = 'Lyon';
    expect(fields.values, {'name': 'Ana', 'city': 'Lyon'});
    fields.dispose();
    fields.dispose(); // a second call is harmless
  });

  testWidgets('a field shows its error under itself', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppTextField(
            controller: TextEditingController(),
            label: 'E-mail',
            error: 'Enter an e-mail address.',
            autofillHints: const [AutofillHints.email],
          ),
        ),
      ),
    );
    expect(find.text('Enter an e-mail address.'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.autofillHints, [AutofillHints.email]);
  });

  testWidgets('a refused submit keeps the sheet open with the reason', (
    tester,
  ) async {
    var answer = 'Name the thing.';
    await _openSheet(tester, () async => answer.isEmpty ? null : answer);
    await tester.tap(find.byKey(const ValueKey('save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('form-sheet-error')), findsOneWidget);
    expect(find.text('Name the thing.'), findsOneWidget);
    expect(find.text('New thing'), findsOneWidget, reason: 'still open');

    answer = '';
    await tester.tap(find.byKey(const ValueKey('save')));
    await tester.pumpAndSettle();
    expect(find.text('New thing'), findsNothing, reason: 'closed on success');
  });

  testWidgets('saving cannot be pressed twice, and the sheet disposes what '
      'it was given', (tester) async {
    final gate = Completer<String?>();
    var calls = 0;
    var disposed = 0;
    await _openSheet(tester, () {
      calls++;
      return gate.future;
    }, onDispose: () => disposed++);
    await tester.tap(find.byKey(const ValueKey('save')));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byKey(const ValueKey('save'))).onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('save')), warnIfMissed: false);
    await tester.pump();
    expect(calls, 1);
    gate.complete(null);
    await tester.pumpAndSettle();
    expect(disposed, 1);
  });
}
