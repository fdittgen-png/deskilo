// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2578 — the payments behind the collected figure
// (workspace_recorded_payments_v1, 0643): the decoder, the RPC call the
// repository makes, the typed refusals, and the demo read's paging.
import 'dart:convert';

import 'package:deskilo/core/data/json_reader.dart';
import 'package:deskilo/core/demo/data/finance_kpi_repository.dart';
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/core/demo/data/workspace_repository.dart';
import 'package:deskilo/features/money/data/supabase_recorded_payments_repository.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/recorded_payments.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, Object?> _row(String id, String at, {Object? amount = '1500'}) => {
  'id': id,
  'matched_at': at,
  'paid_on': '2025-05-02',
  'amount_minor': amount,
  'currency': 'EUR',
  'invoice_id': 'inv-1',
  'invoice_number': 'F-1',
  'payer_name': 'Payer One',
  'resolution': 'exact',
  'label': 'bank transfer',
};

/// A host that answers the RPC with [answer] (or [status]) and records
/// every request.
class _Host {
  _Host(this.answer, {this.status = 200});
  final Object? answer;
  final int status;
  final requests = <({String path, Object? body})>[];

  late final SupabaseClient client = SupabaseClient(
    'https://host.example.test',
    'sb_publishable_test',
    httpClient: MockClient((r) async {
      requests.add((
        path: r.url.path,
        body: r.body.isEmpty ? null : jsonDecode(r.body),
      ));
      return http.Response(
        jsonEncode(answer),
        status,
        headers: {'content-type': 'application/json'},
        request: r,
      );
    }),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
}

void main() {
  group('the decoder', () {
    test('reads a page: rows, the applied size, the clock and the cursor', () {
      final page = RecordedPaymentsPage.fromJson({
        'from': '2025-05-01',
        'to': '2025-05-31',
        'timezone': 'Europe/Paris',
        'page_size': 2,
        'items': [
          _row('p-2', '2025-05-20T08:00:00.123456+00:00'),
          _row('p-1', '2025-05-10T12:00:00+00:00', amount: '2147483647'),
        ],
        'next_cursor': {'matched_at': '2025-05-10T12:00:00+00:00', 'id': 'p-1'},
      });

      expect(page.items.map((p) => p.id), ['p-2', 'p-1']);
      expect(page.pageSize, 2);
      expect(page.timezone, 'Europe/Paris');
      expect(page.hasMore, isTrue);
      expect(page.nextCursor!.toJson(), {
        'matched_at': '2025-05-10T12:00:00+00:00',
        'id': 'p-1',
      }, reason: 'the cursor goes back exactly as the server sent it');
      final first = page.items.first;
      expect(first.matchedAt, DateTime.utc(2025, 5, 20, 8, 0, 0, 123, 456));
      expect(first.paidOn, DateTime(2025, 5, 2));
      expect(first.amountMinor, 1500);
      expect(first.currency, 'EUR');
      expect(first.invoiceId, 'inv-1');
      expect(first.invoiceNumber, 'F-1');
      expect(first.payerName, 'Payer One');
      expect(first.resolution, 'exact');
      expect(first.label, 'bank transfer');
      expect(
        page.items.last.amountMinor,
        2147483647,
        reason: 'the largest amount the column holds, exactly',
      );
    });

    test('the last page has no cursor; an amount that is not a decimal '
        'string is a shape error, never a zero', () {
      final page = RecordedPaymentsPage.fromJson({
        'page_size': 50,
        'items': [_row('p-1', '2025-05-10T12:00:00+00:00')],
        'next_cursor': null,
      });
      expect(page.hasMore, isFalse);
      for (final bad in ['-5', '1.5', '', 1500]) {
        expect(
          () => RecordedPaymentsPage.fromJson({
            'page_size': 50,
            'items': [_row('p-1', '2025-05-10T12:00:00+00:00', amount: bad)],
          }),
          throwsA(isA<JsonShapeException>()),
          reason: '$bad',
        );
      }
    });

    test('a row without its keys is a shape error naming the RPC', () {
      expect(
        () => RecordedPaymentsPage.fromJson({
          'page_size': 50,
          'items': [
            {'matched_at': '2025-05-10T12:00:00+00:00'},
          ],
        }),
        throwsA(
          isA<JsonShapeException>().having(
            (e) => e.context,
            'context',
            'workspace_recorded_payments_v1',
          ),
        ),
      );
      expect(
        () => RecordedPaymentsPage.fromJson('nope'),
        throwsA(isA<JsonShapeException>()),
      );
    });
  });

  group('the repository', () {
    test(
      'calls the RPC with the days as ISO dates, the cursor and the limit',
      () async {
        final host = _Host({
          'page_size': 10,
          'items': <Object?>[],
          'next_cursor': null,
        });
        final page = await SupabaseRecordedPaymentsRepository(host.client).page(
          'ws-1',
          from: DateTime(2025, 5),
          to: DateTime(2025, 5, 31),
          after: const RecordedPaymentsCursor(
            matchedAt: '2025-05-10T12:00:00+00:00',
            id: 'p-1',
          ),
          limit: 10,
        );

        expect(page.items, isEmpty);
        expect(
          host.requests.single.path,
          '/rest/v1/rpc/workspace_recorded_payments_v1',
        );
        expect(host.requests.single.body, {
          'p_workspace_id': 'ws-1',
          'p_from': '2025-05-01',
          'p_to': '2025-05-31',
          'p_after': {'matched_at': '2025-05-10T12:00:00+00:00', 'id': 'p-1'},
          'p_limit': 10,
        });
      },
    );

    test('the first page sends no cursor and no limit', () {
      expect(
        recordedPaymentsParams(
          'ws-1',
          from: DateTime(2025, 6),
          to: DateTime(2025, 6, 30),
        ),
        {
          'p_workspace_id': 'ws-1',
          'p_from': '2025-06-01',
          'p_to': '2025-06-30',
          'p_after': null,
          'p_limit': null,
        },
      );
    });

    test('a refusal is typed: 42501 forbidden, 55000 switched off', () async {
      for (final (code, matcher) in [
        ('42501', isA<RecordedPaymentsForbidden>()),
        ('55000', isA<RecordedPaymentsSwitchedOff>()),
      ]) {
        final host = _Host({'code': code, 'message': 'refused'}, status: 403);
        await expectLater(
          SupabaseRecordedPaymentsRepository(host.client)
              .page('ws-1', from: DateTime(2025, 5), to: DateTime(2025, 5, 31)),
          throwsA(matcher),
        );
      }
      final other = _Host({
        'code': '22023',
        'message': 'bad window',
      }, status: 400);
      await expectLater(
        SupabaseRecordedPaymentsRepository(other.client)
            .page('ws-1', from: DateTime(2025, 5, 31), to: DateTime(2025, 5)),
        throwsA(
          isA<PostgrestException>().having((e) => e.code, 'code', '22023'),
        ),
      );
    });
  });

  group('the demo read', () {
    test('lists the matches that consumed a payment in the window, newest '
        'first, every row once across pages', () async {
      final money = FakeMoneyRepository();
      final workspaces = FakeWorkspaceRepository.withWorkspace();
      final ws = workspaces.workspaces.first.id;
      money.invoices.add(
        Invoice(
          id: 'inv-1',
          workspaceId: ws,
          memberId: 'm-1',
          number: 'F-1',
          issuedAt: DateTime.utc(2025, 5),
          period: '2025-05',
          title: 'May',
          lines: const [],
          totalCents: 10000,
          currency: 'EUR',
          memberName: 'Payer One',
          memberAddress: '',
          workspaceName: 'Test Space',
          workspaceAddress: '',
          issuerName: 'M',
          signature: 's',
        ),
      );
      for (final (i, day) in [(1, 3), (2, 10), (3, 20)]) {
        money.invoiceMatchesStore['m$i'] = InvoiceMatch(
          invoiceId: 'inv-1',
          paidCents: i * 100,
          resolution: 'exact',
          paymentLedgerId: 'pay-$i',
          matchedAt: DateTime.utc(2025, 5, day, 10),
        );
      }
      // A match that consumed no payment holds no row.
      money.invoiceMatchesStore['m4'] = InvoiceMatch(
        invoiceId: 'inv-1',
        paidCents: 999,
        resolution: 'exact',
        matchedAt: DateTime.utc(2025, 5, 15, 10),
      );
      final repo = DemoRecordedPaymentsRepository(
        money: money,
        workspaces: workspaces,
      );

      final seen = <String>[];
      RecordedPaymentsCursor? after;
      var pages = 0;
      do {
        final page = await repo.page(
          ws,
          from: DateTime(2025, 5),
          to: DateTime(2025, 5, 31),
          after: after,
          limit: 2,
        );
        seen.addAll(page.items.map((p) => p.id));
        after = page.nextCursor;
        pages++;
      } while (after != null && pages < 5);

      expect(seen, ['pay-3', 'pay-2', 'pay-1']);
      expect(pages, 2);
      final june = await repo.page(
        ws,
        from: DateTime(2025, 6),
        to: DateTime(2025, 6, 30),
      );
      expect(june.items, isEmpty);
    });
  });
}
