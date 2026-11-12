// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The form kit's date and amount fields: a picked date goes through the same
// reader as a typed one and lands in the field as text; what the field
// understood is said under it; a refusal appears once the person leaves the
// field, in words; the amount field names the record's currency, aligns its
// figures and never deletes a character it was given.
import 'package:deskilo/core/ui/form_kit.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(List<Widget> children) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Column(children: children)),
);

void main() {
  group('AppDateField', () {
    testWidgets('a typed date is read back under the field', (tester) async {
      DateRead? last;
      await tester.pumpWidget(
        _host([
          AppDateField(
            key: const ValueKey('d'),
            label: 'Day',
            value: null,
            locale: 'de_DE',
            onChanged: (r) => last = r,
          ),
        ]),
      );
      await tester.enterText(find.byKey(const ValueKey('d')), '01022030');
      await tester.pump();
      expect(last, (date: DateTime(2030, 2), problem: null));
      expect(find.textContaining('2030'), findsWidgets);
      expect(find.textContaining('Read as'), findsOneWidget);
    });

    testWidgets('a refused date is said once the field is left', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host([
          AppDateField(
            key: const ValueKey('d'),
            label: 'Day',
            value: null,
            locale: 'en_GB',
            onChanged: (_) {},
          ),
          const TextField(key: ValueKey('next')),
        ]),
      );
      await tester.enterText(find.byKey(const ValueKey('d')), '31/02/2030');
      await tester.pump();
      expect(
        find.text('This date does not exist.'),
        findsNothing,
        reason: 'not while the person is still typing',
      );
      await tester.tap(find.byKey(const ValueKey('next')));
      await tester.pump();
      expect(find.text('This date does not exist.'), findsOneWidget);
    });

    testWidgets('a picked date is written as text and read like a typed one', (
      tester,
    ) async {
      DateRead? last;
      await tester.pumpWidget(
        _host([
          AppDateField(
            key: const ValueKey('d'),
            label: 'Day',
            value: DateTime(2030, 2),
            first: DateTime(2030),
            last: DateTime(2030, 12, 31),
            locale: 'en_US',
            onChanged: (r) => last = r,
          ),
        ]),
      );
      expect(find.text('2/1/2030'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('d-pick')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('15'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('2/15/2030'), findsOneWidget);
      expect(last, (date: DateTime(2030, 2, 15), problem: null));
    });
  });

  group('AppAmountField', () {
    testWidgets('names its currency, aligns its figures and keeps what was '
        'typed', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host([
          AppAmountField(
            key: const ValueKey('a'),
            controller: controller,
            label: 'Amount',
            currency: 'JPY',
            allowNegative: false,
            locale: 'en_US',
          ),
          const TextField(key: ValueKey('next')),
        ]),
      );
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const ValueKey('a')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.textAlign, TextAlign.end);
      expect(
        field.style!.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      expect(field.decoration!.suffixText, 'JPY');

      await tester.enterText(find.byKey(const ValueKey('a')), '1.5');
      await tester.tap(find.byKey(const ValueKey('next')));
      await tester.pump();
      expect(find.text('JPY has no decimals.'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('a')), '12e3');
      await tester.pump();
      expect(controller.text, '12e3', reason: 'an exponent is never deleted');
      await tester.enterText(find.byKey(const ValueKey('a')), '−5');
      await tester.pump();
      expect(controller.text, '-5', reason: 'a minus sign is tidied, kept');
    });
  });
}
