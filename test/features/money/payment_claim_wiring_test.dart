// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3556 (1b) — the claim's wiring through the real Supabase classes, with a
// fake transport: what the payment function and the database answer is
// read as the app's own words — a claim refused by its code, an unknown
// claim code as a refusal of its own, the function's word that it takes a
// claim, and how many invoices it says the payment names.
import 'dart:convert';

import 'package:deskilo/core/codes/dk_code.dart';
import 'package:deskilo/core/codes/pg_code.dart';
import 'package:deskilo/features/money/data/supabase_member_account_commands.dart';
import 'package:deskilo/features/money/data/supabase_payment_gateway_repository.dart';
import 'package:deskilo/features/money/domain/payment_claims.dart';
import 'package:deskilo/features/money/domain/payment_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A client whose every request is answered [status] with [body].
SupabaseClient _answering(int status, Object body, {List<String>? seen}) =>
    SupabaseClient(
      'http://localhost:54321',
      'anon-key',
      httpClient: MockClient((request) async {
        seen?.add(request.url.path);
        return http.Response(
          jsonEncode(body),
          status,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );

const _claim = InvoiceClaim(
  period: '2026-10',
  amountCents: 12000,
  invoiceIds: ['i-1', 'i-2'],
);

Future<Object?> _caught(Future<Object?> Function() call) async {
  try {
    await call();
    return null;
  } on Object catch (e) {
    return e;
  }
}

void main() {
  group('the payment function', () {
    test(
      'a claim it answers refused (409 claim_refused) is that refusal',
      () async {
        final repo = SupabasePaymentGatewayRepository(
          _answering(409, {'error': 'claim_refused', 'code': DkCode.dkc06}),
        );
        final error = await _caught(
          () => repo.createClaimOrder(
            provider: PaymentProvider.stripe,
            workspaceId: 'ws',
            memberId: 'm',
            currencyCode: 'EUR',
            claim: _claim,
            requestId: 'r',
          ),
        );
        expect(error, isA<ClaimRefused>());
        expect((error! as ClaimRefused).reason, ClaimRefusal.alreadyInPayment);
      },
    );

    test(
      'an unknown claim code is a refusal of its own, not a failure',
      () async {
        final repo = SupabasePaymentGatewayRepository(
          _answering(409, {'error': 'claim_refused', 'code': 'DKC99'}),
        );
        final error = await _caught(
          () => repo.createClaimOrder(
            provider: PaymentProvider.stripe,
            workspaceId: 'ws',
            memberId: 'm',
            currencyCode: 'EUR',
            claim: _claim,
          ),
        );
        expect((error! as ClaimRefused).reason, ClaimRefusal.other);
      },
    );

    test('it says whether it takes a claim; an older one does not', () async {
      final current = await SupabasePaymentGatewayRepository(
        _answering(200, {
          'providers': ['stripe'],
          'missing': <String, Object?>{},
          'claims': true,
        }),
      ).fetchPaymentConfig('ws');
      final older = await SupabasePaymentGatewayRepository(
        _answering(200, {
          'providers': ['stripe'],
          'missing': <String, Object?>{},
        }),
      ).fetchPaymentConfig('ws');
      expect((current.claims, older.claims), (true, false));
    });

    test('an order answers how many invoices it names', () async {
      final order =
          await SupabasePaymentGatewayRepository(
            _answering(200, {
              'status': 'created',
              'provider': 'stripe',
              'order_id': 'cs_1',
              'approve_url': 'https://pay.example/cs_1',
              'claimed': 2,
            }),
          ).createClaimOrder(
            provider: PaymentProvider.stripe,
            workspaceId: 'ws',
            memberId: 'm',
            currencyCode: 'EUR',
            claim: _claim,
          );
      expect(order.claimed, 2);
    });
  });

  group('the database', () {
    test(
      'a declaration whose claim it refuses (DKC07) is that refusal',
      () async {
        final commands = SupabaseMemberAccountCommands(
          _answering(400, {
            'code': DkCode.dkc07,
            'message': 'a payment of these invoices is what they still owe',
            'details': null,
            'hint': null,
          }),
        );
        final error = await _caught(
          () => commands.declareInvoicesPaid(
            workspaceId: 'ws',
            memberId: 'm',
            claim: _claim,
          ),
        );
        expect((error! as ClaimRefused).reason, ClaimRefusal.amount);
      },
    );

    test('a declaration the business already decided cannot be taken back '
        '(DKC13), asked by its event', () async {
      final seen = <String>[];
      final commands = SupabaseMemberAccountCommands(
        _answering(400, {
          'code': DkCode.dkc13,
          'message': 'this declaration was already decided',
          'details': null,
          'hint': null,
        }, seen: seen),
      );
      final error = await _caught(
        () => commands.withdrawPaymentDeclaration(
          workspaceId: 'ws',
          eventId: 'e-1',
        ),
      );
      expect((error! as ClaimRefused).reason, ClaimRefusal.decided);
      expect(seen.single, endsWith('/rpc/withdraw_payment_declaration'));
    });

    test('another database error stays what it is', () async {
      final commands = SupabaseMemberAccountCommands(
        _answering(400, {
          'code': PgCode.raiseException,
          'message': 'something else',
          'details': null,
          'hint': null,
        }),
      );
      final error = await _caught(
        () => commands.withdrawPaymentClaim(workspaceId: 'ws', paymentId: 'p'),
      );
      expect(error, isA<PostgrestException>());
    });
  });

  group('a declaration is one request (#4321)', () {
    /// A client whose answers come from [answers] in order: a status, or
    /// null for an answer lost on the way back. The request ids it saw
    /// are collected in [ids].
    SupabaseClient scripted(List<int?> answers, List<String> ids) {
      var n = 0;
      return SupabaseClient(
        'http://localhost:54321',
        'anon-key',
        httpClient: MockClient((request) async {
          ids.add(
            (jsonDecode(request.body) as Map<String, Object?>)['p_request_id']!
                as String,
          );
          final status = answers[n++];
          if (status == null) throw http.ClientException('connection lost');
          return http.Response(
            jsonEncode(
              status == 200
                  ? 'event-1'
                  : {'code': DkCode.dkc06, 'message': 'held', 'details': '', 'hint': ''},
            ),
            status,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
    }

    Future<Object?> declare(SupabaseMemberAccountCommands c) => _caught(
      () => c.declareInvoicesPaid(workspaceId: 'w', memberId: 'm', claim: _claim),
    );

    test('a lost answer is sent again under the same id', () async {
      final ids = <String>[];
      final commands = SupabaseMemberAccountCommands(scripted([null, 200], ids));
      expect(await declare(commands), isA<http.ClientException>());
      expect(await declare(commands), isNull);
      expect(ids, hasLength(2));
      expect(ids[1], ids[0]);
    });

    test('an answered declaration is forgotten: the next is a new payment', () async {
      final ids = <String>[];
      final commands = SupabaseMemberAccountCommands(scripted([200, 200], ids));
      await declare(commands);
      await declare(commands);
      expect(ids[1], isNot(ids[0]));
    });

    test('a refusal is forgotten too, and stays its own refusal', () async {
      final ids = <String>[];
      final commands = SupabaseMemberAccountCommands(scripted([409, 200], ids));
      expect(await declare(commands), isA<ClaimRefused>());
      await declare(commands);
      expect(ids[1], isNot(ids[0]));
    });

    test('the payment of another content has its own id', () async {
      final ids = <String>[];
      final commands = SupabaseMemberAccountCommands(scripted([null, null], ids));
      await _caught(
        () => commands.recordPayment(
          workspaceId: 'w', memberId: 'm', amountCents: 100,
        ),
      );
      await _caught(
        () => commands.recordPayment(
          workspaceId: 'w', memberId: 'm', amountCents: 200,
        ),
      );
      expect(ids[1], isNot(ids[0]));
    });
  });
}
