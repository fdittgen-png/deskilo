// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3913 — the book profiles through the server's answer: a profile whose
// authority or basis this version cannot read is left out of the list and
// counted, never read as another; a save the server took is saved even when
// its answer cannot be read back — the profile as sent, and the list read
// again counts the unreadable one.
import 'dart:convert';

import 'package:deskilo/core/data/unreadable_rows.dart';
import 'package:deskilo/features/money/application/save_book_profile.dart';
import 'package:deskilo/features/money/data/supabase_book_profile_repository.dart';
import 'package:deskilo/features/money/domain/book_chart.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, Object?> _row(String id, {String authority = 'external_book'}) => {
  'id': id,
  'workspace_id': 'ws-1',
  'issuer_site_id': 'site-1',
  'authority_mode': authority,
  'external_system': 'DATEV',
  'functional_currency': 'EUR',
  'fiscal_year_start_month': 1,
  'fiscal_year_start_day': 1,
  'accounting_basis': 'accrual',
  'effective_from': '2026-01-01',
  'revision': 2,
};

SupabaseClient _server(Map<String, Object?> answers) => SupabaseClient(
  'https://books.example',
  'sb_publishable_test',
  httpClient: MockClient((r) async {
    final name = r.url.pathSegments.last;
    final answer = answers[name];
    if (answer == null) {
      return http.Response('{"message":"not here"}', 404, request: r);
    }
    return http.Response(
      jsonEncode(answer),
      200,
      headers: {'content-type': 'application/json'},
      request: r,
    );
  }),
);

void main() {
  setUp(UnreadableRows.instance.clear);

  test(
    'the list keeps the profile it reads and counts the one it cannot',
    () async {
      final repository = SupabaseBookProfileRepository(
        _server({
          'book_profiles': [_row('bp-1'), _row('bp-2', authority: 'ledger')],
        }),
      );
      final profiles = await repository.fetchBookProfiles('ws-1');
      expect([for (final p in profiles) p.id], ['bp-1']);
      expect(UnreadableRows.instance.count(booksProfilesArea('ws-1')), 1);
    },
  );

  test('a save the server took is saved even when its answer names an '
      'authority this version cannot read', () async {
    final repository = SupabaseBookProfileRepository(
      _server({'save_book_profile': _row('bp-1', authority: 'ledger')}),
    );
    final draft = BookProfile.fromJson(_row('bp-1'))!;
    final saved = await repository.saveBookProfile(draft);
    expect(saved, same(draft), reason: 'the profile as sent');
    // The save command reports it saved, never stale or failed.
    expect(await BookProfiles(repository).save(draft), BookSaveOutcome.saved);
  });
}
