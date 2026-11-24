// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4447 -- a list arrives in the order its screen means. postgrest sorts descending unless told otherwise, so
// the sites and the stock places came Z to A (and the site ranked first came last). The order sent is read off
// the request: the default site first, then by rank and name ascending, the id last; the places by code
// ascending.
import 'dart:convert';

import 'package:deskilo/features/stock/data/supabase_stock_config_commands.dart';
import 'package:deskilo/features/workspace/data/supabase_workspace_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A client that answers every read with an empty list and keeps the order each table was asked in.
SupabaseClient _client(Map<String, String> orders) => SupabaseClient(
  'http://localhost',
  'anon',
  httpClient: MockClient((request) async {
    orders[request.url.pathSegments.last] ??=
        request.url.queryParameters['order'] ?? '';
    return http.Response(
      jsonEncode(const <Object?>[]),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }),
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

void main() {
  test('the sites are asked default first, then by rank and name ascending, the id last', () async {
    final orders = <String, String>{};
    await SupabaseWorkspaceRepository(_client(orders)).fetchSites('ws-1');
    expect(
      orders['sites'],
      'is_default.desc.nullslast,sort_order.asc.nullslast,name.asc.nullslast,id.asc.nullslast',
    );
  });

  test('the stock places are asked by code ascending, the id last', () async {
    final orders = <String, String>{};
    await SupabaseStockConfigCommands(_client(orders)).places('ws-1');
    expect(orders['stock_locations'], startsWith('code.asc'));
    expect(orders['stock_locations'], endsWith('id.asc.nullslast'));
  });
}
