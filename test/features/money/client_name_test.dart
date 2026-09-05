// SPDX-License-Identifier: 0BSD
//
// #910 — a client is not always a person.
//
// An admin-managed profile may hold nothing but a COMPANY: the
// invitation only asks for one of first name, last name or company. The
// name renderer looked at the two personal halves only, so a company
// client was named '' — the document addressed nobody, and every
// surface that interpolated the name printed an orphan separator
// ("INV-2026-0055 ·", "Facturé à: , SASU KaloA, …", "waiting for  's
// payment"). The company was frozen beside it the whole time.
import 'dart:io';

import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/profile/domain/personal_info.dart';
import 'package:flutter_test/flutter_test.dart';

Invoice _invoice({
  String memberName = '',
  InvoiceParty? buyer,
}) =>
    Invoice(
      id: 'inv-1',
      workspaceId: 'ws-1',
      memberId: 'member-1',
      number: 'INV-2026-0055',
      issuedAt: DateTime.utc(2026, 9, 5),
      period: '2026-09',
      title: 'INV-2026-0055',
      lines: const [
        InvoiceLine(kind: 'subscription', label: '100', amountCents: 10000),
      ],
      totalCents: 10000,
      currency: 'EUR',
      memberName: memberName,
      memberAddress: 'SASU KaloA\n209 rue Jean Bart\n31670 LABÈGE',
      workspaceName: 'COWORKONTI',
      workspaceAddress: '',
      issuerName: 'Flo2',
      signature: 'sig',
      buyerParty: buyer,
    );

void main() {
  group('who the document is addressed to', () {
    test('the buyer party names it when it has a name', () {
      expect(
        _invoice(
          memberName: 'snapshot',
          buyer: const InvoiceParty(name: 'Guilhem MARTIN'),
        ).clientName,
        'Guilhem MARTIN',
      );
    });

    test('else the frozen snapshot', () {
      expect(_invoice(memberName: 'Guilhem MARTIN').clientName,
          'Guilhem MARTIN');
    });

    test('and when neither names anybody, the frozen COMPANY does — this '
        'is what rescues a document already issued, without rewriting a '
        'single byte of it', () {
      final issued = _invoice(
        buyer: const InvoiceParty(company: 'SASU KaloA'),
      );
      expect(issued.memberName, '', reason: 'the defect, as frozen');
      expect(issued.clientName, 'SASU KaloA');
    });

    test('nothing at all stays empty rather than inventing a client', () {
      expect(_invoice().clientName, '');
      expect(_invoice(buyer: const InvoiceParty()).clientName, '');
    });

    test('whitespace is not a name', () {
      expect(
        _invoice(
          memberName: '   ',
          buyer: const InvoiceParty(name: '  ', company: 'SASU KaloA'),
        ).clientName,
        'SASU KaloA',
      );
    });
  });

  group('the SQL twin (migrations 0158 · 0159)', () {
    final sql =
        File('supabase/migrations/0158_client_name_company.sql').readAsStringSync();
    final sql912 =
        File('supabase/migrations/0159_courtesy_title.sql').readAsStringSync();

    test('#912 — the courtesy word is a code resolved per language, and '
        'the five the app speaks are all there', () {
      expect(sql912, contains('create or replace function public.courtesy_word'));
      for (final word in ['Monsieur', 'Madame', 'Herr', 'Frau', 'Sr.',
        'Sra.', 'Sig.', 'Sig.ra', 'Mr', 'Ms']) {
        expect(sql912, contains("'$word'"), reason: '$word missing');
      }
    });

    test('#912 — profile_full_name puts the company first, and the block '
        'names the person under it', () {
      expect(sql912,
          contains("select coalesce(nullif(btrim(coalesce(p.company, '')), '')"));
      expect(sql912, contains('public.profile_person_name(p)'));
      expect(sql912, contains('public.courtesy_word(p.courtesy, p_lang)'));
    });

    test('#912 — create_invoice freezes the person and the code beside '
        'the company, so another language can still greet them', () {
      expect(sql912, contains("''person'', v_member_person"));
      expect(sql912, contains("''courtesy'', v_member_courtesy"));
      expect(sql912, contains('public.profile_person_name(pr)'));
    });

    test('0158 introduced the company fallback; 0159 keeps it and puts '
        'the company FIRST', () {
      expect(sql, contains('create or replace function public.profile_full_name'));
      expect(sql, contains("btrim(coalesce(p.company, ''))"));
      expect(sql912,
          contains('create or replace function public.profile_full_name'));
    });

    test('the two renderings agree, case by case, with the Dart ones', () {
      // Captured from the live harness on 2026-09-05, before applying.
      const company = PersonalInfo(
        company: 'SASU KaloA',
        street: '209 rue Jean Bart, Immeuble AGORA 1B',
        postalCode: '31670',
        city: 'Labège',
        countryCode: 'FR',
      );
      expect(company.fullName, 'SASU KaloA');
      expect(company.postalBlock(workspaceCountry: 'FR'),
          '209 rue Jean Bart, Immeuble AGORA 1B\n31670 LABÈGE');
      expect(company.postalBlock(workspaceCountry: 'DE'),
          '209 rue Jean Bart, Immeuble AGORA 1B\n31670 LABÈGE\nFR');
      // Captured from the 0159 harness on 2026-09-05: A, B, D and E.
      const both = PersonalInfo(
        firstName: 'Guilhem',
        lastName: 'martin',
        company: 'SASU KaloA',
        street: '209 rue Jean Bart',
        postalCode: '31670',
        city: 'Labège',
        countryCode: 'FR',
      );
      // #912 — the organisation is the addressee; the person is named
      // under it, with the title they chose.
      expect(both.fullName, 'SASU KaloA');
      expect(both.postalBlock(workspaceCountry: 'FR'),
          'Guilhem MARTIN\n209 rue Jean Bart\n31670 LABÈGE');
      expect(
        both
            .copyWith(courtesy: Courtesy.mr)
            .postalBlock(workspaceCountry: 'FR', courtesyWord: 'Monsieur'),
        'Monsieur Guilhem MARTIN\n209 rue Jean Bart\n31670 LABÈGE',
      );
    });
  });
}
