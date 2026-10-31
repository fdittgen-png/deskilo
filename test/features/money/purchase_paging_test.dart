// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3070 — the purchase list is read to its end whatever the server's row cap:
// a supplier's printed cost is a sum, and a short list understates it.
import 'dart:convert';

import 'package:deskilo/features/money/data/supabase_purchase_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'every purchase arrives when the server caps below the page size',
    () async {
      final all = [
        for (var i = 0; i < 7; i++)
          {
            'id': 'p$i',
            'kind': 'bill',
            'state': 'approved',
            'category': '',
            'original_reference': 'r$i',
            'currency': 'EUR',
            'received_on': '2026-03-0${i + 1}',
            'legacy_qualification': 'none',
            'supplier_id': 's1',
            'purchase_lines': [
              {'gross_cents': 100},
            ],
          },
      ];
      const serverCap =
          3; // below the helper's page size: short pages all through
      var requests = 0;
      final client = SupabaseClient(
        'http://localhost:54321',
        'anon',
        httpClient: MockClient((request) async {
          requests++;
          final offset = int.parse(
            request.url.queryParameters['offset'] ?? '0',
          );
          final limit = int.parse(
            request.url.queryParameters['limit'] ?? '1000',
          );
          final page = all
              .skip(offset)
              .take(limit < serverCap ? limit : serverCap)
              .toList();
          return http.Response(
            jsonEncode(page),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(client.dispose);

      final purchases = await SupabasePurchaseRepository(client)
          .fetchPurchases('ws');

      expect(purchases.map((p) => p.id), [for (final r in all) r['id']]);
      expect(purchases.every((p) => p.supplierId == 's1'), isTrue);
      expect(
        requests,
        greaterThan(3),
        reason: 'the read went on to an empty page',
      );
    },
  );
}
