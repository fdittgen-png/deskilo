// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2555 -- discovery reads its public sources through the personal home the
// installation declares, never through a guessed host.
//
// Invariants:
// - DISC-SPLIT (client side): a personal home P with no workspace of its own
//   lists W-A and W-B; both are found from P through the production
//   wiring, every public read carries only the publishable key of the
//   origin it goes to, and selecting a workspace on W-B afterwards neither
//   re-reads the sources nor changes the listing or the directory home.
// - A workspace host that names no personal home is refused with the typed
//   PersonalHomeUnavailable: no source list is asked of any server.
// - Recovery: the screen names the refusal, and its Retry reads the
//   declaration again, so a corrected one lists the places; a transient
//   failure of the declaration read is not kept either.
import 'dart:convert';

import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/context_client_providers.dart';
import 'package:deskilo/core/backend/personal_home.dart';
import 'package:deskilo/core/backend/personal_home_providers.dart';
import 'package:deskilo/core/demo/data/public_directory_repository.dart';
import 'package:deskilo/features/directory/domain/discovery_paging.dart';
import 'package:deskilo/features/directory/domain/public_workspace.dart';
import 'package:deskilo/features/directory/presentation/directory_screen.dart';
import 'package:deskilo/features/directory/providers/directory_providers.dart';
import 'package:deskilo/features/directory/providers/discovery_listing_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _p = BackendEndpoint('https://p.example', 'sb_publishable_p_key_0001');
const _wa = BackendEndpoint('https://wa.example', 'sb_publishable_wa_key_001');
const _wb = BackendEndpoint('https://wb.example', 'sb_publishable_wb_key_001');

/// Every installation of the split, behind one recorded transport.
class _Network {
  _Network(this.declaration);

  /// What P's `installation_identity` answers; null fails the read.
  Map<String, Object?>? declaration;
  final seen = <http.BaseRequest>[];

  Map<String, Object?> _card(String id, String name) => {
    'workspace_id': id,
    'name': name,
    'updated_at': '2026-10-01T09:30:00+00:00',
    'document': {'name': name, 'host_type': 'company'},
  };

  http.Client transport() => MockClient((request) async {
    seen.add(request);
    final origin = request.url.origin;
    final path = request.url.path;
    Object? body;
    if (path.endsWith('/installation_identity') && origin == _p.url) {
      final row = declaration;
      if (row == null) return http.Response('unavailable', 503);
      body = row;
    } else if (path.endsWith('/public_directory_sources') && origin == _p.url) {
      body = [
        {'origin': _wa.url, 'publishable_key': _wa.key},
        {'origin': _wb.url, 'publishable_key': _wb.key},
      ];
    } else if (path.endsWith('/public_workspace_cards')) {
      body = switch (origin) {
        'https://wa.example' => [
          _card('00000000-0000-4000-8000-00000000a001', 'Atelier A'),
        ],
        'https://wb.example' => [
          _card('00000000-0000-4000-8000-00000000b001', 'Bureau B'),
        ],
        // P is a personal home: it publishes no workspace.
        _ => <Object>[],
      };
    } else {
      return http.Response('not found', 404);
    }
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  });

  List<String> reads(String suffix) => [
    for (final r in seen)
      if (r.url.path.endsWith(suffix)) r.url.origin,
  ];
}

const _personalHome = {
  'roles': ['personal_home'],
  'personal_home_kind': 'self',
};

ProviderContainer _container(_Network network) {
  final c = ProviderContainer(
    overrides: [
      personalClientProvider.overrideWithValue(
        SupabaseClient(
          _p.url,
          _p.key,
          httpClient: network.transport(),
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      ),
      publicTransportProvider.overrideWithValue(network.transport),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('DISC-SPLIT: P without workspaces finds W-A and W-B through its own '
      'directory; selecting W-B changes neither the listing nor the '
      'directory home', () async {
    final network = _Network(_personalHome);
    final c = _container(network);
    final listing = discoveryListingProvider('');
    var notified = 0;
    final sub = c.listen(listing, (_, _) => notified++);
    addTearDown(sub.close);
    final results = await c.read(listing.future);

    expect(results.workspaces.map((w) => '${w.source}/${w.name}'), [
      '${_wa.url}/Atelier A',
      '${_wb.url}/Bureau B',
    ], reason: 'both workspace hosts are found from P; P itself has none');
    expect(network.reads('/installation_identity'), [_p.url]);
    expect(network.reads('/public_directory_sources'), [
      _p.url,
    ], reason: 'the source list is asked of the declared home alone');
    for (final r in network.seen.where(
      (r) => !r.url.path.endsWith('/installation_identity'),
    )) {
      final key = {_p.url: _p.key, _wa.url: _wa.key, _wb.url: _wb.key};
      expect(r.headers['apikey'], key[r.url.origin], reason: '${r.url}');
      expect(
        r.headers['Authorization'] ?? r.headers['authorization'],
        'Bearer ${key[r.url.origin]}',
        reason: 'a public read carries only its own publishable key',
      );
    }

    final before = network.seen.length;
    final settled = notified;
    c
        .read(selectedWorkspaceHostProvider.notifier)
        .select('00000000-0000-4000-8000-00000000b001', _wb.url);
    await pumpEventQueue();
    expect(network.seen.length, before, reason: 'nothing is read again');
    expect(notified, settled, reason: 'the listing is not rebuilt');
    expect(c.read(listing).value, same(results));
    expect((await c.read(directoryHomeProvider.future)).url, _p.url);
  });

  test('a workspace host that names no personal home is refused, typed, and '
      'no server is asked for a source list', () async {
    final network = _Network({
      'roles': ['workspace_host'],
      'personal_home_kind': 'unset',
    });
    final c = _container(network);
    final listing = discoveryListingProvider('');
    final sub = c.listen(listing, (_, _) {});
    addTearDown(sub.close);
    await expectLater(
      c.read(listing.future),
      throwsA(
        isA<PersonalHomeUnavailable>().having(
          (e) => e.fault,
          'fault',
          PersonalHomeFault.missing,
        ),
      ),
    );
    expect(network.reads('/public_directory_sources'), isEmpty);
    expect(network.reads('/public_workspace_cards'), isEmpty);

    // Recovery: the operator declares the home; reading it again (what the
    // screen's Retry does) lists the places.
    network.declaration = _personalHome;
    c
      ..invalidate(directoryHomeProvider)
      ..invalidate(listing);
    final results = await c.read(listing.future);
    expect(results.workspaces, hasLength(2));
  });

  test('a failed declaration read is not kept: the retry asks again', () async {
    final network = _Network(null);
    final c = _container(network);
    final listing = discoveryListingProvider('');
    final sub = c.listen(listing, (_, _) {});
    addTearDown(sub.close);
    await expectLater(c.read(listing.future), throwsA(anything));
    final failedReads = network.reads('/installation_identity').length;
    network.declaration = _personalHome;
    c
      ..invalidate(directoryHomeProvider)
      ..invalidate(listing);
    expect((await c.read(listing.future)).workspaces, hasLength(2));
    expect(
      network.reads('/installation_identity'),
      hasLength(failedReads + 1),
      reason: 'the declaration is asked again, once',
    );
  });

  group('the screen', () {
    testWidgets('names the missing personal home, and Retry reads the '
        'declaration again and lists the places', (tester) async {
      final directory = _Refusing()
        ..cards.add(
          const PublicWorkspace('w1', 'https://wa.example', 'k', {
            'name': 'Atelier A',
          }),
        );
      var homeReads = 0;
      await pumpApp(
        tester,
        const DirectoryScreen(),
        overrides: [
          ...standardTestOverrides(
            auth: FakeAuthRepository.signedIn(),
            directory: directory,
          ),
          directoryHomeProvider.overrideWith((ref) async {
            homeReads++;
            return _p;
          }),
        ],
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DirectoryScreen)),
      );
      final home = container.listen(directoryHomeProvider, (_, _) {});
      addTearDown(home.close);
      await tester.pumpAndSettle();
      expect(homeReads, 1);

      expect(
        find.byKey(const ValueKey('directory-home-unavailable')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('directory-portal-directory-unavailable-2')),
        findsNothing,
        reason: 'the typed refusal is not the generic outage',
      );
      expect(
        find.byKey(const ValueKey('directory-row-https://wa.example/w1')),
        findsNothing,
      );

      directory.refuse = false;
      await tester.tap(find.byKey(const ValueKey('directory-home-retry')));
      await tester.pumpAndSettle();
      expect(homeReads, 2, reason: 'the declaration is read again');
      expect(
        find.byKey(const ValueKey('directory-home-unavailable')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('directory-row-https://wa.example/w1')),
        findsOneWidget,
      );
    });

    testWidgets('another failure keeps the generic outage, and its retry '
        'recovers too', (tester) async {
      final directory = _Refusing(error: Exception('offline'))
        ..cards.add(
          const PublicWorkspace('w1', 'https://wa.example', 'k', {
            'name': 'Atelier A',
          }),
        );
      await pumpApp(
        tester,
        const DirectoryScreen(),
        overrides: standardTestOverrides(
          auth: FakeAuthRepository.signedIn(),
          directory: directory,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('directory-home-unavailable')),
        findsNothing,
      );
      directory.refuse = false;
      await tester.tap(
        find.byKey(const ValueKey('directory-portal-directory-unavailable-2')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('directory-row-https://wa.example/w1')),
        findsOneWidget,
      );
    });
  });
}

/// A directory whose source list is refused until [refuse] is cleared.
class _Refusing extends FakeDirectoryRepository {
  _Refusing({
    this.error = const PersonalHomeUnavailable(PersonalHomeFault.missing),
  });
  final Exception error;
  bool refuse = true;

  @override
  Future<DirectorySourcesPage> sources({int page = 0}) async {
    if (refuse) throw error;
    return super.sources(page: page);
  }
}
