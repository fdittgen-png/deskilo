// SPDX-License-Identifier: 0BSD
//
// #925 — one number-sequence framework, per workspace, generated in the
// database. The Dart side is the owner's view of a series; the numbers
// are drawn by `next_document_number` (0164) and nothing here can take
// one. These tests pin the model, the preview that mirrors the server's
// format, and the SQL twin.
import 'dart:io';

import 'package:deskilo/features/money/domain/number_sequence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the model', () {
    test('reads a row and rejects nonsense with the defaults', () {
      final s = NumberSequence.fromDb({
        'journal': 'invoice',
        'prefix': 'INV-',
        'date_part': 'year',
        'digits': 4,
        'reset': 'yearly',
        'next_value': 57,
        'period_key': '2026',
      });
      expect((s.prefix, s.datePart, s.digits, s.reset, s.nextValue), (
        'INV-',
        NumberDatePart.year,
        4,
        NumberReset.yearly,
        57,
      ));
      final odd = NumberSequence.fromDb({
        'journal': 'x',
        'date_part': 'week',
        'digits': 40,
        'reset': 'daily',
      });
      expect((odd.datePart, odd.digits, odd.reset), (
        NumberDatePart.year,
        9,
        NumberReset.yearly,
      ));
    });

    test('the preview mirrors number_sequence_format', () {
      final at = DateTime(2026, 9, 6);
      expect(
        const NumberSequence(journal: 'invoice', prefix: 'INV-').format(57, at),
        'INV-2026-0057',
      );
      expect(
        const NumberSequence(
          journal: 'invoice',
          prefix: 'F-',
          digits: 5,
        ).format(59, at),
        'F-2026-00059',
      );
      expect(
        const NumberSequence(
          journal: 'x',
          datePart: NumberDatePart.yearMonth,
          digits: 3,
        ).format(7, at),
        '2026-09-007',
      );
      expect(
        const NumberSequence(
          journal: 'x',
          datePart: NumberDatePart.none,
          suffix: '/A',
        ).format(12, at),
        '0012/A',
      );
    });

    test('every journal the app knows is listed side by side', () {
      expect(NumberSequence.journals, ['invoice', 'credit_note']);
    });
  });

  group('the SQL twin (migration 0164)', () {
    final sql = File(
      'supabase/migrations/0164_number_sequences.sql',
    ).readAsStringSync();

    test(
      'one narrow row per (workspace, journal), locked FOR UPDATE — '
      'gapless and O(1), not a Postgres sequence',
      () {
        expect(sql, contains('primary key (workspace_id, journal)'));
        expect(sql, contains('for update;'));
        expect(sql, isNot(contains('create sequence')));
        expect(sql, isNot(contains('nextval(')));
      },
    );

    test(
      'gapless is constrained true: no cached blocks, no gapped mode '
      'until a journal asks for one',
      () {
        expect(
          sql,
          contains(
            'gapless      boolean not null default true check (gapless)',
          ),
        );
      },
    );

    test('the period key is resolved on the WORKSPACE clock, not UTC', () {
      expect(sql, contains("at time zone coalesce(w.timezone, 'UTC')"));
      expect(sql, isNot(contains("date_part('year', now())::int")));
    });

    test(
      'drawing a number is not a client call; previewing and configuring are',
      () {
        expect(
          sql,
          contains(
            'revoke execute on function public.next_document_number(uuid, text) '
            'from public, anon, authenticated',
          ),
        );
        expect(
          sql,
          contains(
            'grant execute on function public.preview_document_number(uuid, text) '
            'to authenticated',
          ),
        );
        expect(
          sql,
          contains(
            'grant execute on function public.set_number_sequence(uuid, text, '
            'text, text, text, int, text, bigint) to authenticated',
          ),
        );
      },
    );

    test('the counter is raised, never lowered, and only by the owner', () {
      expect(sql, contains("raise exception 'a sequence never goes backwards"));
      expect(
        sql,
        contains("raise exception 'only owners may configure number sequences'"),
      );
    });

    test(
      'every workspace is seeded to continue unbroken, and both issuers '
      'draw from the framework',
      () {
        expect(
          sql,
          contains("select w.id, 'invoice', 'INV-', 'year', 4, 'yearly',"),
        );
        expect(
          "v_number := public.next_document_number(p_workspace_id, ''invoice'');"
              .allMatches(sql)
              .length,
          2,
        );
        expect(
          sql,
          contains("raise exception '0164: create_invoice numbering anchor missing'"),
        );
        expect(
          sql,
          contains("raise exception '0164: settle_invoices numbering anchor missing'"),
        );
      },
    );
  });
}
