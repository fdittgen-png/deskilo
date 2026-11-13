// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3650 — a typed number, its validated international form, and the links
// built from that form only. National input is read for an explicit
// country, never guessed; a number typed with + or 00 is read on its own
// and never reinterpreted; Italy's significant zero survives; an extension
// is kept apart and refused by the messages that cannot carry it; the
// legacy "+0612345678" (a French national number stored with a + in front)
// is not a destination.
import 'package:deskilo/core/phone/phone_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('national input → E.164 → link', () {
    const table = [
      ('FR', '06 12 34 56 78', '+33612345678'),
      ('DE', '030 1234567', '+49301234567'),
      ('CH', '044 668 18 00', '+41446681800'),
      ('IT', '02 1234 5678', '+390212345678'),
      ('ES', '612 34 56 78', '+34612345678'),
      ('GB', '07400 123456', '+447400123456'),
      ('US', '(201) 555-0123', '+12015550123'),
    ];
    for (final (country, typed, e164) in table) {
      test('$country: "$typed" is $e164', () {
        final entry = parsePhone(typed, country: country);
        expect(entry.e164, e164);
        expect(entry.typed, typed, reason: 'what was typed is kept as typed');
        expect(entry.country, country);
        expect(
          whatsappLink(entry),
          Uri.https('wa.me', '/${e164.substring(1)}'),
        );
        expect(smsLink(entry), Uri(scheme: 'sms', path: e164));
      });
    }
  });

  test('Italy keeps its significant zero', () {
    expect(parsePhone('02 1234 5678', country: 'IT').e164, startsWith('+3902'));
  });

  test(
    'an international number is read on its own and never reinterpreted',
    () {
      for (final country in [null, 'FR', 'US']) {
        expect(
          parsePhone('+49 30 1234567', country: country).e164,
          '+49301234567',
        );
        expect(
          parsePhone('0049 30 1234567', country: country).e164,
          '+49301234567',
        );
      }
    },
  );

  group('refusals: no validated form, no link', () {
    test('a national number with no country', () {
      final e = parsePhone('06 12 34 56 78');
      expect(e.problem, PhoneProblem.noCountry);
      expect(whatsappLink(e), isNull);
      expect(smsLink(e), isNull);
    });
    test('letters', () {
      expect(
        parsePhone('call me', country: 'FR').problem,
        PhoneProblem.notANumber,
      );
    });
    test('digits that cannot be a number of that country', () {
      expect(
        parsePhone('12', country: 'FR').problem,
        PhoneProblem.notValidForCountry,
      );
      expect(
        parsePhone('+33 1 23', country: 'FR').problem,
        PhoneProblem.notValidForCountry,
      );
    });
    test('the legacy "+0612345678" is not a destination', () {
      final e = parsePhone('+0612345678', country: 'FR');
      expect(e.isValidated, isFalse);
      expect(whatsappLink(e), isNull);
      expect(e.typed, '+0612345678', reason: 'kept, to be corrected');
    });
  });

  test('an extension is kept apart; a message cannot carry it', () {
    final e = parsePhone('01 23 45 67 89 poste 12', country: 'FR');
    expect(e.e164, '+33123456789');
    expect(e.extension, '12');
    expect(whatsappLink(e), isNull);
    expect(smsLink(e), isNull);
  });

  test(
    'written in its international spelling; an unvalidated one as typed',
    () {
      expect(
        phoneDisplay(parsePhone('06 12 34 56 78', country: 'FR')),
        '+33 6 12 34 56 78',
      );
      expect(
        phoneDisplay(parsePhone('01 23 45 67 89 x 12', country: 'FR')),
        '+33 1 23 45 67 89 ext. 12',
      );
      expect(
        phoneDisplay(parsePhone('+0612345678', country: 'FR')),
        '+0612345678',
      );
    },
  );

  test('a message to a contact picked in the app needs no number', () {
    expect(whatsappShare('hi'), Uri.https('wa.me', '/', {'text': 'hi'}));
    expect(smsShare('hi').scheme, 'sms');
  });

  test('the calling code of a country', () {
    expect(callingCodeOf('FR'), '33');
    expect(callingCodeOf('ch'), '41');
    expect(callingCodeOf('ZZ'), '');
  });
}
