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

  group('the SQL twin (migration 0158)', () {
    final sql =
        File('supabase/migrations/0158_client_name_company.sql').readAsStringSync();

    test('profile_full_name falls back to the company, as Dart does', () {
      expect(sql, contains('create or replace function public.profile_full_name'));
      expect(sql, contains("btrim(coalesce(p.company, ''))"));
    });

    test('profile_postal_block drops the company when no person is named '
        '— the same condition PersonalInfo.postalBlock applies', () {
      expect(
        sql,
        contains("case when btrim(coalesce(p.first_name, '')) <> ''"),
      );
      expect(sql, contains("or btrim(coalesce(p.last_name, '')) <> ''"));
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
      const both = PersonalInfo(
        firstName: 'Guilhem',
        lastName: 'martin',
        company: 'SASU KaloA',
        street: '209 rue Jean Bart',
        postalCode: '31670',
        city: 'Labège',
        countryCode: 'FR',
      );
      expect(both.fullName, 'Guilhem MARTIN');
      expect(both.postalBlock(workspaceCountry: 'FR'),
          'SASU KaloA\n209 rue Jean Bart\n31670 LABÈGE');
    });
  });
}
