// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1869 — a book profile belongs to one issuer, never to a name or a
// locale: two issuers sharing a workspace and a name keep two books, one
// issuer keeps one whatever its sites; the fiscal year may span two
// calendar years; and the profile in force on a day is the latest one
// effective by then. Expectations are written out by hand.
import 'package:deskilo/features/money/domain/book_profile.dart';
import 'package:flutter_test/flutter_test.dart';

BookProfile profile({
  String id = 'p1',
  String issuer = 'site-fr',
  BookAuthority authority = BookAuthority.localBook,
  String external = '',
  String currency = 'EUR',
  int month = 1,
  int day = 1,
  AccountingBasis basis = AccountingBasis.accrual,
  DateTime? from,
}) => BookProfile(
  id: id,
  workspaceId: 'ws',
  issuerSiteId: issuer,
  authority: authority,
  externalSystem: external,
  functionalCurrency: currency,
  fiscalYearStartMonth: month,
  fiscalYearStartDay: day,
  basis: basis,
  effectiveFrom: from ?? DateTime.utc(2026, 1, 1),
  revision: 1,
);

void main() {
  group('validation', () {
    test('a sound profile has no problem', () {
      expect(validateBookProfile(profile()), isEmpty);
    });

    test('an external book names the system that stays authoritative', () {
      expect(
        validateBookProfile(profile(authority: BookAuthority.externalBook)),
        [BookProfileProblem.externalSystemMissing],
      );
      expect(
        validateBookProfile(
          profile(authority: BookAuthority.externalBook, external: 'DATEV'),
        ),
        isEmpty,
      );
    });

    test('the currency has a reviewed exponent', () {
      expect(validateBookProfile(profile(currency: 'XYZ')), [
        BookProfileProblem.unsupportedCurrency,
      ]);
    });

    test('a fiscal year starts on a day every year has', () {
      expect(validateBookProfile(profile(month: 2, day: 29)), [
        BookProfileProblem.invalidFiscalStart,
      ]);
      expect(validateBookProfile(profile(month: 4, day: 31)), [
        BookProfileProblem.invalidFiscalStart,
      ]);
      expect(validateBookProfile(profile(month: 13)), [
        BookProfileProblem.invalidFiscalStart,
      ]);
      expect(validateBookProfile(profile(month: 2, day: 28)), isEmpty);
    });
  });

  group('fiscal year', () {
    test('a calendar fiscal year', () {
      final y = fiscalYearOf(profile(), DateTime(2026, 9, 30));
      expect((y.start, y.end), (DateTime(2026, 1, 1), DateTime(2026, 12, 31)));
      expect(y.label, '2026');
    });

    test('a year from 1 July spans two calendar years', () {
      final p = profile(month: 7, day: 1);
      final before = fiscalYearOf(p, DateTime(2026, 6, 30));
      final after = fiscalYearOf(p, DateTime(2026, 7, 1));
      expect(
        (before.start, before.end),
        (DateTime(2025, 7, 1), DateTime(2026, 6, 30)),
      );
      expect(
        (after.start, after.end),
        (DateTime(2026, 7, 1), DateTime(2027, 6, 30)),
      );
      expect(after.label, '2026/27');
    });

    test('the day is a calendar date: 23:30 on 30 June is still June', () {
      final p = profile(month: 7, day: 1);
      expect(
        fiscalYearOf(p, DateTime(2026, 6, 30, 23, 30)).start,
        DateTime(2025, 7, 1),
      );
    });

    test('a year ending in a leap February keeps the 29th', () {
      final y = fiscalYearOf(profile(month: 3, day: 1), DateTime(2027, 6, 1));
      expect(y.end, DateTime(2028, 2, 29));
    });
  });

  group('which profile is in force', () {
    final versions = [
      profile(id: 'a', issuer: 'site-fr', from: DateTime.utc(2025, 1, 1)),
      profile(
        id: 'b',
        issuer: 'site-fr',
        authority: BookAuthority.externalBook,
        external: 'Pennylane',
        from: DateTime.utc(2026, 7, 1),
      ),
      profile(
        id: 'c',
        issuer: 'site-ch',
        currency: 'CHF',
        from: DateTime.utc(2025, 1, 1),
      ),
    ];

    test('the latest version effective by the day, for that issuer only', () {
      expect(profileOn(versions, 'site-fr', DateTime(2026, 6, 30))?.id, 'a');
      expect(profileOn(versions, 'site-fr', DateTime(2026, 7, 1))?.id, 'b');
      expect(profileOn(versions, 'site-ch', DateTime(2026, 7, 1))?.id, 'c');
    });

    test('before any version, and for an unknown issuer, there is none', () {
      expect(profileOn(versions, 'site-fr', DateTime(2024, 12, 31)), isNull);
      expect(profileOn(versions, 'site-de', DateTime(2026, 1, 1)), isNull);
    });
  });

  test('the wire form round-trips and keeps unknown modes out', () {
    final p = profile(
      authority: BookAuthority.externalBook,
      external: 'DATEV',
      month: 7,
      basis: AccountingBasis.cash,
    );
    expect(BookProfile.fromJson(p.toJson()).toJson(), p.toJson());
    expect(p.toJson()['authority_mode'], 'external_book');
    expect(p.toJson()['effective_from'], '2026-01-01');
    expect(
      () => BookProfile.fromJson({...p.toJson(), 'authority_mode': 'ledger'}),
      throwsFormatException,
    );
  });
}
