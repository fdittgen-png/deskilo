// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4446 -- a list that grows with the business is read to its end. The server stops an answer at its own row cap
// (1000 by default) without saying so; a house with 1200 members or a member with 1200 ledger lines used to see the
// first 1000 as if they were all. Over a mock that serves pages the way PostgREST does, the members of a workspace
// and the ledger of a member come back whole, in order, none twice; a configuration list is paged too, and refused
// past the configuration cap.
import 'dart:convert';

import 'package:deskilo/core/data/paged_fetch.dart';
import 'package:deskilo/features/money/data/supabase_member_account_queries.dart';
import 'package:deskilo/features/workspace/data/supabase_workspace_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The server's own cap: never more rows in one answer than this, whatever was asked.
const _serverCap = 1000;

/// A client whose table [table] holds [total] rows made by [row]; every page asked is answered as PostgREST would,
/// at most [_serverCap] rows, and the requests are kept in [asked].
SupabaseClient _paged(
  String table,
  int total,
  Map<String, Object?> Function(int i) row,
  List<Uri> asked,
) => SupabaseClient(
  'http://localhost',
  'anon',
  httpClient: MockClient((request) async {
    asked.add(request.url);
    expect(request.url.path, '/rest/v1/$table');
    final offset = int.parse(request.url.queryParameters['offset'] ?? '0');
    final limit =
        int.tryParse(request.url.queryParameters['limit'] ?? '') ?? _serverCap;
    final n = (total - offset).clamp(
      0,
      limit < _serverCap ? limit : _serverCap,
    );
    return http.Response(
      jsonEncode([for (var i = offset; i < offset + n; i++) row(i)]),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }),
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

String _id(int i) => '00000000-0000-4000-8000-${i.toString().padLeft(12, '0')}';

void main() {
  test('the members of a workspace past the server\'s cap are all read, in order, none twice', () async {
    final asked = <Uri>[];
    final client = _paged(
      'members',
      1200,
      (i) => {
        'id': _id(i),
        'workspace_id': 'ws-1',
        'user_id': 'user-$i',
        'is_admin': false,
        'is_owner': false,
        'status': 'active',
      },
      asked,
    );
    final members = await SupabaseWorkspaceRepository(client)
        .fetchMembers('ws-1');
    expect(members, hasLength(1200));
    expect(
      {for (final m in members) m.id},
      hasLength(1200),
      reason: 'no member twice',
    );
    expect(members.last.id, _id(1199));
    expect(
      asked.length,
      greaterThan(2),
      reason: 'read page by page, to an empty page',
    );
    expect(
      asked.first.queryParameters['order'],
      contains('id'),
      reason: 'a unique key last: no row repeats or is skipped between pages',
    );
  });

  test('the ledger of a member past the server\'s cap is all read, in order, none twice', () async {
    final asked = <Uri>[];
    final client = _paged(
      'ledger_entries',
      1200,
      (i) => {
        'id': _id(i),
        'member_id': 'member-1',
        'kind': 'charge',
        'category': 'subscription',
        'amount_cents': 100,
        'description': 'line $i',
        'period': '2026-11',
        'created_at': '2026-11-01T00:00:00Z',
      },
      asked,
    );
    final ledger = await SupabaseMemberAccountQueries(client)
        .fetchLedger('member-1');
    expect(ledger, hasLength(1200));
    expect(
      {for (final e in ledger) e.id},
      hasLength(1200),
      reason: 'no line twice',
    );
    expect(
      asked.length,
      greaterThan(2),
      reason: 'read page by page, to an empty page',
    );
    expect(asked.first.queryParameters['order'], contains('id'));
  });

  // A configuration list is paged the same way and refused past the configuration cap, never shown cut short.
  test('a configuration list past the server\'s cap is read whole', () async {
    final asked = <Uri>[];
    final client = _paged(
      'sites',
      1200,
      (i) => {'id': _id(i), 'workspace_id': 'ws-1', 'name': 'Site $i'},
      asked,
    );
    final sites = await SupabaseWorkspaceRepository(client).fetchSites('ws-1');
    expect(sites, hasLength(1200));
    expect(
      asked.first.queryParameters['order']!.split(',').last,
      startsWith('id.'),
      reason: 'a unique key last',
    );
  });

  test('a configuration list longer than the configuration cap is refused, naming its table', () async {
    final client = _paged(
      'sites',
      kConfigurationListCap + 1,
      (i) => {'id': _id(i), 'workspace_id': 'ws-1', 'name': 'Site $i'},
      [],
    );
    await expectLater(
      SupabaseWorkspaceRepository(client).fetchSites('ws-1'),
      throwsA(
        isA<ExportTooLargeException>().having((e) => e.table, 'table', 'sites'),
      ),
    );
  });
}
