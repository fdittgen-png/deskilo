// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1847 — the PUBLIC discovery interface through the real Supabase client
// over a recorded HTTP transport: every request is anonymous (the
// publishable key, never a session bearer) and stays on its own origin,
// the columns, order and page are the generated contract's, a card this
// version cannot interpret is refused and its source named, and a private
// field that leaks into an answer never reaches the app. Detail reads the
// card again, live, and answers null once it is withdrawn.
//
// #2555 — sources and cards are read separately: one source's page is
// asked of that source alone, a full page says it may have more, and a
// failed page throws instead of answering an empty one.
import 'dart:convert';

import 'package:deskilo/core/public_network/public_network_operations.dart';
import 'package:deskilo/features/directory/data/supabase_public_discovery_repository.dart';
import 'package:deskilo/features/directory/domain/discovery_paging.dart';
import 'package:deskilo/features/directory/domain/public_workspace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const home = 'https://home.example';
const homeKey = 'sb_publishable_home_test_key';
const remote = 'https://remote.example';
const remoteKey = 'sb_publishable_remote_test_key';

Map<String, Object?> card(
  String id,
  String name, {
  Map<String, Object?> doc = const {},
}) => {
  'workspace_id': id,
  'name': name,
  'updated_at': '2026-10-01T09:30:00+00:00',
  'document': {'name': name, 'host_type': 'company', ...doc},
};

const idA = '00000000-0000-4000-8000-0000000018a1';
const idB = '00000000-0000-4000-8000-0000000018b1';
const idC = '00000000-0000-4000-8000-0000000018c1';
const homeSource = DirectorySource(home, homeKey);
const remoteSource = DirectorySource(remote, remoteKey);

void main() {
  late List<http.BaseRequest> seen;
  late Map<String, List<Map<String, Object?>>> cardsByOrigin;
  late List<Map<String, Object?>> sources;
  late Set<String> failing;

  http.Client transport() => MockClient((request) async {
    seen.add(request);
    final path = request.url.path;
    final origin = request.url.origin;
    if (failing.contains(origin)) {
      return http.Response('unavailable', 503, request: request);
    }
    Object body;
    if (path.endsWith('/public_directory_sources')) {
      body = sources;
    } else if (path.endsWith('/public_workspace_cards')) {
      final id = request.url.queryParameters['workspace_id'];
      body = [
        for (final c in cardsByOrigin[origin] ?? const <Map<String, Object?>>[])
          if (id == null || id == 'eq.${c['workspace_id']}') c,
      ];
    } else {
      return http.Response('not found', 404, request: request);
    }
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  });

  SupabasePublicDiscoveryRepository repository() =>
      SupabasePublicDiscoveryRepository(
        origin: home,
        publishableKey: homeKey,
        transport: transport,
      );

  setUp(() {
    seen = [];
    failing = {};
    sources = [
      {'origin': remote, 'publishable_key': remoteKey},
    ];
    cardsByOrigin = {
      home: [card(idA, 'Atelier')],
      remote: [card(idB, 'Bureau')],
    };
  });

  test('the first page of sources leads with the directory itself; cards '
      'are read anonymously, one source at a time, with the contract\'s '
      'columns, order and page', () async {
    final first = await repository().sources();
    expect(first.sources, [homeSource, remoteSource]);
    expect(first.more, isFalse);
    final page = await repository().workspaces(remoteSource, 'Bu', page: 1);
    expect(page.cards.map((w) => '${w.source}/${w.name}'), ['$remote/Bureau']);
    expect(page.more, isFalse, reason: 'a short page is the last one');
    expect(page.incompatible, isFalse);
    const search = PublicNetworkOperations.directoryWorkspacesSearch;
    final reads = seen
        .where((r) => r.url.path.endsWith('/public_workspace_cards'))
        .toList();
    expect(reads.map((r) => r.url.origin), [remote],
        reason: 'a source page is asked of that source alone');
    for (final r in reads) {
      expect(r.url.queryParameters['select'], search.selectClause);
      expect(
        r.url.queryParameters['order'],
        'name.asc.nullslast,workspace_id.asc.nullslast',
      );
      expect(r.url.queryParameters['search_text'], 'ilike.%Bu%');
      expect(r.url.queryParameters['offset'], '25');
      expect(r.url.queryParameters['limit'], '25');
    }
    for (final r in seen) {
      final key = r.url.origin == home ? homeKey : remoteKey;
      expect(r.headers['apikey'], key, reason: '${r.url}');
      final bearer = r.headers['Authorization'] ?? r.headers['authorization'];
      expect(
        bearer == null || bearer == 'Bearer $key',
        isTrue,
        reason: 'a public request carries no session: $bearer',
      );
    }
  });

  test('a full page may have more; a later source page names only the '
      'directory\'s rows', () async {
    const size = 25;
    cardsByOrigin[remote] = [
      for (var i = 0; i < size; i++)
        card('00000000-0000-4000-8000-0000000019${i.toString().padLeft(2, '0')}',
            'Bureau $i'),
    ];
    expect((await repository().workspaces(remoteSource, '')).more, isTrue);
    sources = [
      for (var i = 0; i < PublicNetworkOperations.directorySourcesList.pageSize!; i++)
        {'origin': 'https://s$i.example', 'publishable_key': 'sb_publishable_s$i'},
    ];
    final first = await repository().sources();
    expect(first.more, isTrue);
    final second = await repository().sources(page: 1);
    expect(second.sources.map((s) => s.origin), isNot(contains(home)),
        reason: 'the directory itself leads the first page only');
    final sourceReads = seen
        .where((r) => r.url.path.endsWith('/public_directory_sources'))
        .map((r) => r.url.queryParameters['offset'])
        .toList();
    expect(sourceReads, ['0', '20']);
  });

  test('a source that does not answer throws; it never reads as empty',
      () async {
    failing = {remote};
    await expectLater(
      repository().workspaces(remoteSource, ''),
      throwsA(anything),
    );
    expect((await repository().workspaces(homeSource, '')).cards, hasLength(1));
  });

  test('a blank query sends no filter; % and _ are escaped', () async {
    await repository().workspaces(homeSource, '  ');
    expect(
      seen
          .where((r) => r.url.path.endsWith('/public_workspace_cards'))
          .every((r) => !r.url.queryParameters.containsKey('search_text')),
      isTrue,
    );
    seen.clear();
    await repository().workspaces(homeSource, '50%_off');
    expect(
      seen
          .firstWhere((r) => r.url.path.endsWith('/public_workspace_cards'))
          .url
          .queryParameters['search_text'],
      r'ilike.%50\%\_off%',
    );
  });

  test('a card with an unknown required term is refused and its source named; '
      'the source\'s other cards still show', () async {
    cardsByOrigin[remote] = [
      card(
        idB,
        'Bureau',
        doc: {
          'price_terms': {'amount_minor': 1500},
          'must_understand': ['price_terms'],
        },
      ),
      card(idC, 'Cabane'),
    ];
    final page = await repository().workspaces(remoteSource, '');
    expect(page.cards.map((w) => w.name), ['Cabane']);
    expect(page.incompatible, isTrue);
  });

  test('private canaries in an answer never reach the app', () async {
    cardsByOrigin[home] = [
      {
        ...card(
          idA,
          'Atelier',
          doc: {'invite_code': 'CANARY-INVITE', 'internal_note': 'CANARY'},
        ),
        'company_id': 'CANARY-COMPANY',
      },
    ];
    final page = await repository().workspaces(homeSource, '');
    final atelier = page.cards.firstWhere((w) => w.name == 'Atelier');
    expect('${atelier.document}', isNot(contains('CANARY')));
  });

  test('an invalid registered source is unavailable, not contacted', () async {
    sources = [
      {'origin': 'https://bad.example', 'publishable_key': 'service_role_key'},
    ];
    final page = await repository().sources();
    expect(page.refused, ['https://bad.example']);
    expect(page.sources, [homeSource]);
    expect(seen.any((r) => r.url.origin == 'https://bad.example'), isFalse);
  });

  test('detail reads the card again on its own origin, and answers null once '
      'it is withdrawn', () async {
    final listed =
        (await repository().workspaces(remoteSource, '')).cards.single;
    seen.clear();
    final again = await repository().detail(listed);
    expect(again?.name, 'Bureau');
    final read = seen.single;
    expect(read.url.origin, remote);
    expect(read.url.queryParameters['workspace_id'], 'eq.$idB');
    expect(
      read.url.queryParameters['select'],
      PublicNetworkOperations.directoryWorkspacesDetail.selectClause,
    );
    expect(read.headers['apikey'], remoteKey);

    cardsByOrigin[remote] = [];
    expect(await repository().detail(listed), isNull);
  });

  test('detail of a preview card (no source) asks nobody', () async {
    const preview = PublicWorkspace(idA, '', '', {'name': 'Mine'});
    expect(await repository().detail(preview), same(preview));
    expect(seen, isEmpty);
  });
}
