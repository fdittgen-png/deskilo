// SPDX-License-Identifier: 0BSD
//
// #928 — three documents that carried no number take one from the
// framework: member numbers, VAT declaration numbers, payment
// references. The Dart side reads them; the SQL twin (0165) draws them.
import 'dart:io';

import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/number_sequence.dart';
import 'package:deskilo/features/money/domain/payment_intent.dart';
import 'package:deskilo/features/money/domain/vat_declaration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/0165_number_sequence_adopters.sql',
  ).readAsStringSync();

  group('per-journal defaults, pinned to number_sequence_defaults', () {
    test('a member number never resets and carries no year', () {
      final m = NumberSequence.defaultsFor('member');
      expect((m.prefix, m.datePart, m.reset), (
        'M-',
        NumberDatePart.none,
        NumberReset.never,
      ));
      expect(sql, contains("when 'member' then 'M-'"));
      expect(sql, contains("case p_journal when 'member' then 'none' else 'year' end"));
      expect(sql, contains("case p_journal when 'member' then 'never' else 'yearly' end"));
    });

    test('the others follow the invoice: year, yearly', () {
      for (final (journal, prefix) in [
        ('invoice', 'INV-'),
        ('credit_note', 'CN-'),
        ('vat_declaration', 'DECL-'),
        ('payment', 'PAY-'),
      ]) {
        final d = NumberSequence.defaultsFor(journal);
        expect((d.prefix, d.datePart, d.reset), (
          prefix,
          NumberDatePart.year,
          NumberReset.yearly,
        ), reason: journal);
        expect(sql, contains("when '$journal' then '$prefix'"));
      }
    });
  });

  group('the readers', () {
    test('the buyer party carries the member number, frozen at issue', () {
      final party = InvoiceParty.fromSnapshot({
        'name': 'SASU KaloA',
        'legal_id': '849 149 108',
        'member_number': 'M-0011',
      });
      expect(party.memberNumber, 'M-0011');
      expect(InvoiceParty.fromSnapshot(const {}).memberNumber, '',
          reason: 'an older invoice simply has none');
    });

    test('a filed declaration has a number; a draft has none', () {
      final row = <String, dynamic>{
        'id': 'd', 'workspace_id': 'w', 'period_start': '2026-01-01',
        'period_end': '2026-03-31', 'status': 'submitted', 'lines': <dynamic>[],
        'total_net_cents': 0, 'total_vat_cents': 0, 'currency': 'EUR',
        'invoice_count': 0, 'created_at': '2026-04-01T00:00:00Z',
        'number': 'DECL-2026-0001',
      };
      expect(VatDeclaration.fromRow(row).number, 'DECL-2026-0001');
      expect(VatDeclaration.fromRow({...row}..remove('number')).number, '');
    });

    test('a payment intent carries the reference the payer saw', () {
      final intent = PaymentIntent.fromRow({
        'id': 'i', 'member_id': 'm', 'provider': 'stripe',
        'order_id': 'cs_123', 'period': '2026-09', 'amount_cents': 1000,
        'status': 'created', 'created_at': '2026-09-06T00:00:00Z',
        'reference': 'PAY-2026-0117',
      });
      expect(intent.reference, 'PAY-2026-0117');
    });
  });

  group('the SQL twin (migration 0165)', () {
    test('every issuer of a membership draws the number; a re-join never '
        'redraws one', () {
      expect("public.next_document_number(ws_id, ''member'')".allMatches(sql).length, 2);
      expect(sql, contains("public.next_document_number(p_workspace_id, ''member'')"));
      expect(sql, contains("where id = v_member_id and member_number = ''''"));
    });

    test('existing members are numbered in join order, then the series '
        'continues from the count', () {
      expect(sql, contains('partition by workspace_id order by joined_at, id'));
      expect(sql, contains("select w.id, 'member', 'M-', 'none', 4, 'never', '',"));
    });

    test('a declaration is numbered when FILED, never as a draft', () {
      expect(sql, contains("number = case when number = '''' then public.next_document_number(workspace_id, ''vat_declaration'') else number end"));
      expect(sql, contains("where d.status = 'submitted'"));
    });

    test('the payment reference is drawn inside the intent insert, by a '
        'function only the service role may call', () {
      expect(sql, contains("v_ref := public.next_document_number(p_workspace_id, 'payment');"));
      expect(sql, contains("'pending:' || v_id::text"));
      expect(sql, contains('revoke execute on function public.open_payment_intent(uuid, uuid, text, text, int, text) from public, anon, authenticated'));
      expect(sql, contains('grant execute on function public.open_payment_intent(uuid, uuid, text, text, int, text) to service_role'));
    });

    test('the invoice freezes the buyer member number beside the legal id', () {
      expect(sql, contains("''member_number'', coalesce(v_subject.member_number, '''')"));
    });
  });
}
