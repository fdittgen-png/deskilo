// SPDX-License-Identifier: 0BSD
//
// #886 — the two renderings every document prints, pinned equal to
// their SQL twins.
//
// The invoice FREEZES what `profile_full_name` and `profile_postal_block`
// return at issue time (migration 0152); the designer preview and the
// window-envelope mirror show what the Dart functions return. If the two
// ever differ, a member sees one address on screen and posts another.
// The expected strings below are the SQL functions' actual output for
// the same input, captured by the 0152 harness on 2026-09-05.
import 'package:deskilo/features/profile/domain/personal_info.dart';
import 'package:flutter_test/flutter_test.dart';

const _kaloa = PersonalInfo(
  firstName: ' Guilhem ',
  lastName: 'martin',
  company: 'SASU KaloA',
  street: '209 rue Jean Bart, Immeuble AGORA 1B',
  postalCode: '31670',
  city: 'Labège',
  countryCode: 'FR',
);

void main() {
  group('full name', () {
    test(
      '"Prénom NOM": family name in capitals, trimmed — as SQL renders it',
      () {
        expect(_kaloa.fullName, 'Guilhem MARTIN');
      },
    );

    test('either half alone; nothing when both are blank', () {
      expect(const PersonalInfo(firstName: 'Anne').fullName, 'Anne');
      expect(const PersonalInfo(lastName: 'Dupont').fullName, 'DUPONT');
      expect(PersonalInfo.empty.fullName, '');
    });

    test('#910 — a client with no personal name IS its company', () {
      const company = PersonalInfo(company: 'SASU KaloA');
      expect(company.fullName, 'SASU KaloA');
      expect(company.personName, '', reason: 'nobody is named');
    });

    test('#910 — a person named alongside a company keeps the name', () {
      expect(_kaloa.fullName, 'Guilhem MARTIN');
      expect(_kaloa.personName, 'Guilhem MARTIN');
    });
  });

  group('the company and the block (#910)', () {
    const company = PersonalInfo(
      company: 'SASU KaloA',
      street: '209 rue Jean Bart, Immeuble AGORA 1B',
      postalCode: '31670',
      city: 'Labège',
      countryCode: 'FR',
    );

    test('promoted to the name line, it leaves the block — an address '
        'that repeats its own addressee is not an address', () {
      expect(
        company.postalBlock(workspaceCountry: 'FR'),
        '209 rue Jean Bart, Immeuble AGORA 1B\n31670 LABÈGE',
      );
    });

    test('but it stays in the block when a PERSON is named above it', () {
      expect(
        _kaloa.postalBlock(workspaceCountry: 'FR'),
        startsWith('SASU KaloA\n'),
      );
    });

    test('nameAbove decides it, so a caller printing a frozen name says '
        'which one', () {
      // An older document names the person and freezes the company
      // beside it: the block must still carry the company.
      expect(
        company.postalBlock(
          workspaceCountry: 'FR',
          nameAbove: 'Guilhem MARTIN',
        ),
        startsWith('SASU KaloA\n'),
      );
    });

    test('the country still closes the block when abroad', () {
      expect(company.postalBlock(workspaceCountry: 'DE'), endsWith('\nFR'));
    });
  });

  group('postal block', () {
    test(
      'company · street · POSTAL CITY, locality in capitals (NF Z 10-011)',
      () {
        expect(
          _kaloa.postalBlock(workspaceCountry: 'FR'),
          'SASU KaloA\n209 rue Jean Bart, Immeuble AGORA 1B\n31670 LABÈGE',
        );
      },
    );

    test('the country code closes the block only when abroad', () {
      expect(
        _kaloa.postalBlock(workspaceCountry: 'DE'),
        endsWith('\n31670 LABÈGE\nFR'),
      );
      expect(
        _kaloa.postalBlock(workspaceCountry: 'fr'),
        isNot(endsWith('FR')),
        reason: 'case must not make a French address look foreign',
      );
      expect(
        _kaloa.postalBlock(),
        isNot(endsWith('FR')),
        reason: 'an unknown workspace country cannot call anything abroad',
      );
    });

    test('empty elements leave no blank lines; the name is never inside', () {
      const noCompany = PersonalInfo(street: '4 rue Silène', city: 'Pézenas');
      expect(noCompany.postalBlock(), '4 rue Silène\nPÉZENAS');
      expect(const PersonalInfo(city: 'Pézenas').postalBlock(), 'PÉZENAS');
      expect(
        const PersonalInfo(firstName: 'X', lastName: 'Y').postalBlock(),
        '',
      );
    });
  });

  group('the value', () {
    test('isEmpty and isPostalComplete', () {
      expect(PersonalInfo.empty.isEmpty, isTrue);
      expect(_kaloa.isEmpty, isFalse);
      expect(_kaloa.isPostalComplete, isTrue);
      expect(
        const PersonalInfo(firstName: 'A', lastName: 'B').isPostalComplete,
        isFalse,
        reason: 'a name without a place cannot be posted',
      );
    });

    test('normalized trims and upper-cases the country — what is stored', () {
      final n = const PersonalInfo(
        firstName: ' a ',
        countryCode: 'fr',
        email: ' x@y.z ',
      ).normalized();
      expect((n.firstName, n.countryCode, n.email), ('a', 'FR', 'x@y.z'));
    });

    test('round-trips through the wire keys shared with profiles and '
        'managed members', () {
      final back = PersonalInfo.fromDb(_kaloa.toDb());
      expect(back, _kaloa);
      expect(
        _kaloa.toDb().keys,
        containsAll([
          'first_name',
          'last_name',
          'company',
          'street',
          'postal_code',
          'city',
          'country_code',
          'phone',
          'email',
          'vat_id',
          'legal_id',
        ]),
      );
    });
  });
}
