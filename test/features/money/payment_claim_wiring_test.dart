// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3556 (1b) — the claim's wiring through the real Supabase classes, with a
// fake transport: what the payment function and the database answer is
// read as the app's own words — a claim refused by its code, an unknown
// claim code as a refusal of its own, the function's word that it takes a
// claim, and how many invoices it says the payment names.
import 'dart:convert';

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
          _answering(409, {'error': 'claim_refused', 'code': 'DKC06'}),
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
            'code': 'DKC07',
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

    test('another database error stays what it is', () async {
      final commands = SupabaseMemberAccountCommands(
        _answering(400, {
          'code': 'P0001',
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
}
