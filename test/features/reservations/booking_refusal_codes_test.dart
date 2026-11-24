// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3810 (part of #3657), #4156 -- a booking refusal is read by its code
// (0739), never by its sentence: every DKK code has its own words in the five
// languages, a value the server names in DETAIL reaches them, and a reworded
// server message changes nothing. The server's answer becomes ONE pure value
// at the data boundary (`ReservationRefusal.fromServer`), and no shape of
// DETAIL, however malformed, turns a refusal into a second failure.
import 'package:deskilo/core/codes/dk_code.dart';
import 'package:deskilo/core/codes/pg_code.dart';
import 'package:deskilo/features/reservations/domain/reservation_refusal.dart';
import 'package:deskilo/features/reservations/presentation/booking_error_text.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The codes 0739 issues (DKK14 and DKK24 are not issued).
final _codes = [
  for (var i = 1; i <= 36; i++)
    if (i != 14 && i != 24) 'DKK${i.toString().padLeft(2, '0')}',
];

const _languages = ['en', 'fr', 'de', 'es', 'it'];

/// The words of a server answer: what the data boundary and the presentation
/// do together.
String? _words(
  AppLocalizations l10n,
  String? code,
  Object? details, {
  String? message,
  int? stepMinutes,
}) {
  // The sentinel is the fallback: it comes back for a refusal with no words.
  const none = '\u0000';
  final text = bookingErrorText(
    l10n,
    ReservationRefused(
      ReservationRefusal.fromServer(
        code: code,
        message: message,
        details: details,
      ),
    ),
    none,
    stepMinutes: stepMinutes,
  );
  return text == none ? null : text;
}

/// The refusal the data boundary raises for a server answer.
ReservationRefused _refused(String message, {String? code, Object? details}) =>
    ReservationRefused(
      ReservationRefusal.fromServer(
        code: code,
        message: message,
        details: details,
      ),
    );

void main() {
  test('every code has its own words in the five languages', () {
    for (final language in _languages) {
      final l10n = lookupAppLocalizations(Locale(language));
      final texts = <String, String>{};
      for (final code in _codes) {
        final text = _words(l10n, code, null);
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

  test('the codes the app reads are the codes 0739 issues, no more', () {
    for (var i = 0; i <= 99; i++) {
      final code = 'DKK${i.toString().padLeft(2, '0')}';
      expect(
        ReservationRefusal.fromServer(code: code).kind ==
            ReservationRefusalKind.coded,
        _codes.contains(code),
        reason: code,
      );
    }
  });

  test('a value the server names reaches the words', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(_words(en, DkCode.dkk08, '{"days" : 45}'), en.bookingHorizonError(45));
    expect(
      _words(en, DkCode.dkk09, '{"minutes" : 30}'),
      en.bookingTooShortError(30),
    );
    expect(_words(en, DkCode.dkk06, '{"minutes" : 20}'), en.planSlotError(20));
    expect(_words(en, DkCode.dkk34, '{"days" : 120}'), en.bookingSeriesTooLong(120));
    // A detail already decoded reads the same.
    expect(_words(en, DkCode.dkk10, {'minutes': 240}), en.bookingTooLongError(240));
    // No DETAIL, or one that is not JSON: the screen's own grid, else 15.
    expect(_words(en, DkCode.dkk06, null, stepMinutes: 30), en.planSlotError(30));
    expect(_words(en, DkCode.dkk06, 'not json'), en.planSlotError(15));
  });

  group('a malformed DETAIL is never a second failure', () {
    final en = lookupAppLocalizations(const Locale('en'));
    // Valid JSON whose number is not a number, and every other shape DETAIL
    // can take: the value is absent, so the existing fallbacks apply.
    const notNumbers = <String, String>{
      'a string': '"30"',
      'a list': '[30]',
      'an object': '{"x": 30}',
      'a boolean': 'true',
      'null': 'null',
      'a negative number': '-30',
      'a number too large to mean a duration': '99999999999',
    };
    notNumbers.forEach((name, json) {
      test('minutes as $name keeps the screen\'s grid', () {
        expect(
          _words(en, DkCode.dkk06, '{"minutes": $json}', stepMinutes: 30),
          en.planSlotError(30),
        );
        expect(
          _words(en, DkCode.dkk09, '{"minutes": $json}'),
          en.bookingTooShortError(0),
        );
      });
      test('days as $name is absent', () {
        expect(
          _words(en, DkCode.dkk08, '{"days": $json}'),
          en.bookingHorizonError(0),
        );
      });
    });

    test('a whole number written as a double keeps its meaning', () {
      expect(_words(en, DkCode.dkk06, '{"minutes": 45.0}'), en.planSlotError(45));
      expect(_words(en, DkCode.dkk06, {'minutes': 45.0}), en.planSlotError(45));
      // ... and a fraction is not a duration.
      expect(
        _words(en, DkCode.dkk06, '{"minutes": 45.5}', stepMinutes: 30),
        en.planSlotError(30),
      );
    });

    test('a detail that is not an object names nothing', () {
      for (final details in <Object?>[
        '[1, 2]',
        '"text"',
        '42',
        'true',
        '',
        '   ',
        '{broken',
        42,
        true,
        ['minutes'],
      ]) {
        expect(
          () => ReservationRefusal.fromServer(code: DkCode.dkk06, details: details),
          returnsNormally,
          reason: '$details',
        );
        expect(
          _words(en, DkCode.dkk06, details, stepMinutes: 30),
          en.planSlotError(30),
          reason: '$details',
        );
      }
    });

    test('a detail map with keys of any type is read', () {
      expect(
        _words(en, DkCode.dkk08, <Object?, Object?>{1: 'x', 'days': 7}),
        en.bookingHorizonError(7),
      );
    });
  });

  test('the code decides, whatever the sentence says', () {
    final fr = lookupAppLocalizations(const Locale('fr'));
    expect(
      bookingErrorText(
        fr,
        _refused('a sentence nobody pinned', code: DkCode.dkk29),
        'fallback',
      ),
      fr.bookingNotYours,
    );
  });

  test('a code that is not a booking refusal is not read as one', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(_words(en, DkCode.dkb01, null), isNull);
    expect(_words(en, null, null), isNull);
    // An unknown code keeps no code and no sentence: nothing of the backend
    // reaches a person, and the screen's own fallback is shown.
    final unknown = ReservationRefusal.fromServer(
      code: 'XX000',
      message: 'relation "reservations" violates constraint xyz',
    );
    expect(unknown.kind, ReservationRefusalKind.unknown);
    expect(unknown.code, isNull);
    expect(bookingErrorText(en, _refused('boom', code: 'XX000'), 'fb'), 'fb');
    // Not a refusal at all: the fallback.
    expect(bookingErrorText(en, StateError('x'), 'fb'), 'fb');
  });

  test('the words a refusal without a code of its own is read by', () {
    final en = lookupAppLocalizations(const Locale('en'));
    String words(String message) =>
        bookingErrorText(en, _refused(message), 'fb');
    expect(
      words('that space is already reserved in that period'),
      en.bookingSpaceChainTaken,
    );
    expect(words('seat already reserved'), en.levelConflict);
    expect(
      words('not allowed to make reservations'),
      en.bookingNotAllowedError,
    );
    expect(words('something else'), 'fb');
    // The kiosk's two.
    expect(
      ReservationRefusal.fromServer(message: 'badge not recognized').kind,
      ReservationRefusalKind.badgeRejected,
    );
    expect(
      ReservationRefusal.fromServer(message: 'reservation not checked in').kind,
      ReservationRefusalKind.notCheckedIn,
    );
  });

  test('another reservation blocks: by its code or its words, never the '
      'member\'s own', () {
    expect(isBlockedByOtherError(_refused('x', code: DkCode.dkk26)), isTrue);
    expect(isBlockedByOtherError(_refused('x', code: PgCode.exclusionViolation)), isTrue);
    expect(isBlockedByOtherError(_refused('seat already reserved')), isTrue);
    expect(
      isBlockedByOtherError(
        _refused('you already have a reservation in that period'),
      ),
      isFalse,
    );
    expect(isBlockedByOtherError(StateError('x')), isFalse);
  });

  test('the typed refusal carries no wording and says what it is', () {
    final refused = _refused('secret backend text', code: DkCode.dkk06);
    expect(refused.toString(), 'ReservationRefused(coded DKK06)');
    expect(refused.toString(), isNot(contains('secret')));
  });
}
