// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Ambiguous missing originals are distinguished from permission and server failures.
import 'package:deskilo/features/money/data/supabase_bank_statement_repository.dart';
import 'package:deskilo/features/money/domain/bank/bank_records.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  SupabaseBankStatementRepository repository(
    int status,
  ) => SupabaseBankStatementRepository(
    SupabaseClient(
      'http://localhost',
      'anon',
      httpClient: MockClient(
        (request) async => http.Response(
          '{"statusCode":"$status","error":"not_found","message":"unavailable"}',
          status,
          headers: {'content-type': 'application/json'},
        ),
      ),
    ),
  );
  test('ambiguous 404 is reported without claiming source absence', () async {
    await expectLater(
      repository(404).fetchOriginal('workspace', 'digest'),
      throwsA(isA<BankOriginalUnavailable>()),
    );
  });
  test('permission and server failures remain failures', () async {
    for (final code in [403, 500]) {
      await expectLater(
        repository(code).fetchOriginal('workspace', 'digest'),
        throwsA(isA<StorageException>()),
      );
    }
  });
}
