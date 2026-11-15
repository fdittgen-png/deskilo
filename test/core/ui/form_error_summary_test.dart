// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3286 — a form with problems says how many, takes the focus to the first
// field with one (and again on request), keeps each sentence under its own
// field.
import 'package:deskilo/core/ui/form_error_summary.dart';
import 'package:deskilo/core/ui/form_kit.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _open(WidgetTester tester, FieldErrors Function() validate) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showAppFormSheet(
              context,
              AppFormSheet(
                title: 'New thing',
                submitLabel: 'Save',
                submitKey: const ValueKey('save'),
                onSubmit: () async => null,
                validate: validate,
                builder: (context, refresh) => [
                  AppTextField(
                    key: const ValueKey('name'),
                    controller: TextEditingController(),
                    label: 'Name',
                    fieldKey: 'name',
                  ),
                  AppTextField(
                    key: const ValueKey('city'),
                    controller: TextEditingController(),
                    label: 'City',
                    fieldKey: 'city',
                  ),
                ],
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

bool _hasFocus(WidgetTester tester, String key) => tester
    .widget<TextField>(
      find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(TextField),
      ),
    )
    .focusNode!
    .hasFocus;

void main() {
  testWidgets('two problems: the summary counts them, the focus lands on the '
      'first field and the summary action brings it back', (tester) async {
    await _open(
      tester,
      () => {'name': 'Enter a name', 'city': 'Enter a city'},
    );
    expect(find.byKey(const ValueKey('form-error-summary-go')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('save')));
    await tester.pumpAndSettle();
    expect(find.text('2 fields need your attention'), findsOneWidget);
    expect(find.text('Enter a name'), findsOneWidget);
    expect(find.text('Enter a city'), findsOneWidget);
    expect(_hasFocus(tester, 'name'), isTrue, reason: 'first problem focused');

    // The person moves on; the summary action returns to the first problem.
    await tester.tap(find.byKey(const ValueKey('city')));
    await tester.pumpAndSettle();
    expect(_hasFocus(tester, 'city'), isTrue);
    await tester.tap(find.byKey(const ValueKey('form-error-summary-go')));
    await tester.pumpAndSettle();
    expect(_hasFocus(tester, 'name'), isTrue);

    // Editing a field clears its own problem and the count follows.
    await tester.enterText(find.byKey(const ValueKey('name')), 'Ada');
    await tester.pumpAndSettle();
    expect(find.text('1 field needs your attention'), findsOneWidget);
  });

  testWidgets('#4065 — named problems: one link per field, no "go to the '
      'first", each link calls its own way there', (tester) async {
    final went = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: FormErrorSummary(
            count: 2,
            onGoToFirst: () => went.add('first'),
            problems: [
              (key: const ValueKey('p-a'), label: 'Total', onGo: () => went.add('a')),
              (key: const ValueKey('p-b'), label: 'Due date', onGo: () => went.add('b')),
            ],
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('form-error-summary-go')), findsNothing);
    expect(find.text('Total'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('p-b')));
    await tester.tap(find.byKey(const ValueKey('p-a')));
    expect(went, ['b', 'a']);
  });
}
