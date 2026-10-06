// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Invariant: a value enters a recording only through the typed channel —
// bounded, typed, and NEVER a secret, a payment identifier or personal
// contact data: such a field is recorded as redacted, with only the length
// of what was typed. The validator refuses anything the recorder would not
// have kept.
import 'package:deskilo/features/task_recorder/domain/step_values.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('what a field becomes', () {
    test('plain text is kept, a number as a number', () {
      expect(valueOfField('Team lunch'), TextValue('Team lunch'));
      expect(valueOfField('12,5', numeric: true), const NumberValue(12.5));
      expect(valueOfField('abc', numeric: true), TextValue('abc'));
    });

    test(
      'a field that hides what is typed is redacted, with its length only',
      () {
        expect(valueOfField('hunter2', obscure: true), const RedactedValue(7));
      },
    );

    test('secrets, payment, tax and personal contact fields are redacted by '
        'their hint, key or label', () {
      for (final probe in [
        (hint: 'password', key: null, label: null),
        (hint: 'newPassword', key: null, label: null),
        (hint: 'oneTimeCode', key: null, label: null),
        (hint: 'email', key: null, label: null),
        (hint: 'telephoneNumber', key: null, label: null),
        (hint: 'creditCardNumber', key: null, label: null),
        (hint: 'streetAddressLine1', key: null, label: null),
        (hint: 'givenName', key: null, label: null),
        (hint: '', key: 'login-iban-field', label: null),
        (hint: '', key: null, label: 'E-Mail-Adresse'),
        (hint: '', key: null, label: 'Mot de passe'),
        (hint: '', key: null, label: 'API key'),
        (hint: '', key: 'vat-number', label: 'VAT number'),
      ]) {
        final v = valueOfField(
          'secret value',
          hints: probe.hint.isEmpty ? const [] : [probe.hint],
          key: probe.key,
          label: probe.label,
        );
        expect(v, isA<RedactedValue>(), reason: '$probe');
        expect((v as RedactedValue).length, 12);
      }
    });

    test('ordinary fields are not caught by the filter', () {
      for (final label in [
        'Title',
        'Notes',
        'Quantity',
        'Desk name',
        'Reason',
      ]) {
        expect(
          valueOfField('x', label: label),
          isA<TextValue>(),
          reason: label,
        );
      }
    });

    test('text is cut at the bound and loses control characters', () {
      final long = 'a' * 500;
      expect(
        (valueOfField(long) as TextValue).text.length,
        StepValues.maxLength,
      );
      expect((valueOfField('a\u0000b\u0007c') as TextValue).text, 'abc');
    });
  });

  group('the validator', () {
    test('round-trips every kind of value, keys sorted', () {
      final values = StepValues.of({
        'title': TextValue('Board'),
        'qty': const NumberValue(3),
        'checked': const FlagValue(true),
        'pwd': const RedactedValue(9),
      });
      final json = values.toJson();
      expect(json.keys.toList(), ['checked', 'pwd', 'qty', 'title']);
      expect(StepValues.parse(json), values);
    });

    test('refuses what the recorder would not keep', () {
      expect(StepValues.parse({'Bad Key': 'x'}), isNull);
      expect(
        StepValues.parse({
          'a': ['list'],
        }),
        isNull,
      );
      expect(
        StepValues.parse({
          'a': {'nested': 1},
        }),
        isNull,
      );
      expect(
        StepValues.parse({
          'a': {'redacted': true},
        }),
        isNull,
      );
      expect(StepValues.parse({'a': 'x' * 241}), isNull);
      expect(StepValues.parse({'a': 'bell\u0007'}), isNull);
      expect(StepValues.parse(<String, Object>{}), isNull);
      expect(
        StepValues.parse({for (var i = 0; i < 17; i++) 'k$i': 'v'}),
        isNull,
      );
      expect(StepValues.parse('not a map'), isNull);
    });

    test('absence is the empty value set', () {
      expect(StepValues.parse(null), StepValues.none);
      expect(StepValues.none.isEmpty, isTrue);
    });

    test('a badly named entry is dropped when building, never recorded', () {
      expect(StepValues.of({'Bad Key': TextValue('x')}).isEmpty, isTrue);
    });
  });
}
