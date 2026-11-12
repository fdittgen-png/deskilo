// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3810 (part of #3657) -- a booking refusal is read by its code (0739),
// never by its sentence: every DKK code has its own words in the five
// languages, a value the server names in DETAIL reaches them, and a reworded
// server message changes nothing.
import 'package:deskilo/features/reservations/domain/booking_error_text.dart';
import 'package:deskilo/features/reservations/domain/booking_refusal_codes.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

/// The codes 0739 issues (DKK14 and DKK24 are not issued).
final _codes = [
  for (var i = 1; i <= 36; i++)
    if (i != 14 && i != 24) 'DKK${i.toString().padLeft(2, '0')}',
];

const _languages = ['en', 'fr', 'de', 'es', 'it'];

void main() {
  test('every code has its own words in the five languages', () {
    for (final language in _languages) {
      final l10n = lookupAppLocalizations(Locale(language));
      final texts = <String, String>{};
      for (final code in _codes) {
        final text = bookingCodeText(l10n, code, null);
        expect(text, isNotNull, reason: '$language $code');
        expect(text, isNotEmpty, reason: '$language $code');
        texts[code] = text!;
      }
      // Codes that share a meaning share their words; no other two do.
      expect(
        texts.values.toSet().length,
        greaterThanOrEqualTo(30),
        reason: language,
      );
    }
  });

  test('a value the server names reaches the words', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(
      bookingCodeText(en, 'DKK08', '{"days" : 45}'),
      en.bookingHorizonError(45),
    );
    expect(
      bookingCodeText(en, 'DKK09', '{"minutes" : 30}'),
      en.bookingTooShortError(30),
    );
    expect(
      bookingCodeText(en, 'DKK06', '{"minutes" : 20}'),
      en.planSlotError(20),
    );
    expect(
      bookingCodeText(en, 'DKK34', '{"days" : 120}'),
      en.bookingSeriesTooLong(120),
    );
    // No DETAIL, or one that is not JSON: the screen's own grid, else 15.
    expect(
      bookingCodeText(en, 'DKK06', null, stepMinutes: 30),
      en.planSlotError(30),
    );
    expect(bookingCodeText(en, 'DKK06', 'not json'), en.planSlotError(15));
  });

  test('the code decides, whatever the sentence says', () {
    final fr = lookupAppLocalizations(const Locale('fr'));
    const reworded = PostgrestException(
      message: 'a sentence nobody pinned',
      code: 'DKK29',
    );
    expect(bookingErrorText(fr, reworded, 'fallback'), fr.bookingNotYours);
  });

  test('a code that is not a booking refusal is not read as one', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(bookingCodeText(en, 'DKB01', null), isNull);
    expect(bookingCodeText(en, null, null), isNull);
    expect(
      bookingErrorText(
        en,
        const PostgrestException(message: 'boom', code: 'XX000'),
        'fb',
      ),
      'fb',
    );
  });
}
