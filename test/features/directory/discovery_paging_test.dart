// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Discovery pages source by source (#2555 C2, DISC-03).
//
// Invariant: each source installation advances through its own pages
// only; "Show more" asks that one source for its next page; a page that
// fails keeps every card the source already showed, leaves the source at
// the same page and offers a retry that asks for exactly that page; no
// card is skipped or shown twice; the directory's own list of sources
// pages the same way, and new sources join without resetting the ones
// already listed. The loaded count and the directories answering are the
// ones on screen.
import 'package:deskilo/core/demo/data/public_directory_repository.dart';
import 'package:deskilo/features/directory/domain/discovery_paging.dart';
import 'package:deskilo/features/directory/domain/public_workspace.dart';
import 'package:deskilo/features/directory/presentation/directory_screen.dart';
import 'package:deskilo/features/directory/providers/directory_providers.dart';
import 'package:deskilo/features/directory/providers/discovery_listing_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _a = 'https://a.example';
const _b = 'https://b.example';

PublicWorkspace _card(String source, String id) =>
    PublicWorkspace(id, source, 'sb_publishable_test', {'name': 'Place $id'});

Key _row(String source, String id) => ValueKey('directory-row-$source/$id');

/// A directory whose list of sources has two pages: [_a] then [_b]. The
/// second page fails while [failSecond] is set.
class _PagedSources extends FakeDirectoryRepository {
  bool failSecond = true;
  final sourceReads = <int>[];

  @override
  Future<DirectorySourcesPage> sources({int page = 0}) async {
    sourceReads.add(page);
    if (page == 0) {
      return const DirectorySourcesPage([
        DirectorySource(_a, 'sb_publishable_test'),
      ], more: true);
    }
    if (failSecond) throw StateError('directory unavailable');
    return const DirectorySourcesPage([
      DirectorySource(_a, 'sb_publishable_test'),
      DirectorySource(_b, 'sb_publishable_test'),
    ], more: false);
  }
}

void main() {
  group('one source listing', () {
    const source = DirectorySource(_a, 'k');
    test('a failed page keeps the pages before it and is the page asked '
        'again', () {
      final first = const SourceListing(
        source,
      ).loaded(SourceCardsPage([_card(_a, '1'), _card(_a, '2')], more: true));
      final failed = first.loading().failed();
      expect(failed.cards.map((c) => c.id), ['1', '2']);
      expect(failed.pages, 1, reason: 'the failed page is asked again');
      expect(failed.canAdvance, isTrue);
      final retried = failed.loading().loaded(
        SourceCardsPage([_card(_a, '2'), _card(_a, '3')], more: false),
      );
      expect(retried.cards.map((c) => c.id), [
        '1',
        '2',
        '3',
      ], reason: 'a card already held is not repeated');
      expect(retried.pages, 2);
      expect(retried.canAdvance, isFalse, reason: 'a short page is the last');
    });

    test('one source changing leaves every other as it is; new sources '
        'join after the listed ones', () {
      var results = const DiscoveryResults().withSources(
        const DirectorySourcesPage([
          DirectorySource(_a, 'k'),
          DirectorySource(_b, 'k'),
        ], more: true),
      );
      results = results.updating(
        _a,
        (s) => s.loaded(SourceCardsPage([_card(_a, '1')], more: true)),
      );
      results = results.updating(_b, (s) => s.failed());
      expect(results.of(_a)!.pages, 1);
      expect(results.unavailable, [_b]);
      final grown = results.withSources(
        const DirectorySourcesPage([
          DirectorySource(_a, 'k'),
          DirectorySource('https://c.example', 'k'),
        ], more: false),
      );
      expect(grown.sources.map((s) => s.origin), [_a, _b, 'https://c.example']);
      expect(
        grown.of(_a)!.cards.single.id,
        '1',
        reason: 'a source already listed keeps its pages',
      );
      expect(grown.of(_b)!.status, SourceStatus.failed);
      expect(grown.answered, 1);
    });
  });

  testWidgets(
    'Show more advances one source; a failed page keeps what was shown and '
    'its retry asks for that same page',
    (tester) async {
      final directory = FakeDirectoryRepository()
        ..pageSize = 2
        ..cards.addAll([
          for (var i = 0; i < 5; i++) _card(_a, 'a$i'),
          for (var i = 0; i < 3; i++) _card(_b, 'b$i'),
        ])
        ..failPages.add('$_b#1');
      await pumpApp(
        tester,
        const DirectoryScreen(),
        size: const Size(800, 2400),
        overrides: standardTestOverrides(
          auth: FakeAuthRepository.signedIn(),
          directory: directory,
        ),
      );
      await tester.pumpAndSettle();
      expect(directory.reads, ['$_a#0', '$_b#0']);
      expect(find.byKey(_row(_a, 'a2')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('directory-source-more-$_a')));
      await tester.pumpAndSettle();
      expect(find.byKey(_row(_a, 'a2')), findsOneWidget);
      expect(directory.reads.last, '$_a#1');

      await tester.tap(find.byKey(const ValueKey('directory-source-more-$_b')));
      await tester.pumpAndSettle();
      expect(directory.reads.last, '$_b#1');
      expect(
        find.byKey(_row(_b, 'b0')),
        findsOneWidget,
        reason: 'a failed page keeps the pages already shown',
      );
      expect(find.byKey(_row(_b, 'b1')), findsOneWidget);
      expect(
        find.text(
          'b.example did not answer. The places already shown '
          'stay.',
        ),
        findsOneWidget,
      );

      // The other source carries on while this one is failed.
      await tester.tap(find.byKey(const ValueKey('directory-source-more-$_a')));
      await tester.pumpAndSettle();
      expect(directory.reads.last, '$_a#2');
      expect(
        find.byKey(const ValueKey('directory-source-more-$_a')),
        findsNothing,
        reason: 'a short page is the last',
      );

      directory.failPages.clear();
      await tester.tap(
        find.byKey(const ValueKey('directory-source-retry-$_b')),
      );
      await tester.pumpAndSettle();
      expect(directory.reads, [
        '$_a#0',
        '$_b#0',
        '$_a#1',
        '$_b#1',
        '$_a#2',
        '$_b#1',
      ], reason: 'the retry asks for the page that failed, nothing skipped');
      for (final id in ['a0', 'a1', 'a2', 'a3', 'a4']) {
        expect(find.byKey(_row(_a, id)), findsOneWidget, reason: id);
      }
      for (final id in ['b0', 'b1', 'b2']) {
        expect(find.byKey(_row(_b, id)), findsOneWidget, reason: id);
      }
      expect(
        find.text(
          'Places loaded: 8 · shown: 8 · directories answering: 2 of 2',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a source whose first page fails is named with a retry; the '
      'others show, and the count says who answered', (tester) async {
    final directory = FakeDirectoryRepository()
      ..cards.addAll([_card(_a, 'a0'), _card(_b, 'b0')])
      ..failPages.add('$_b#0');
    await pumpApp(
      tester,
      const DirectoryScreen(),
      overrides: standardTestOverrides(
        auth: FakeAuthRepository.signedIn(),
        directory: directory,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(_row(_a, 'a0')), findsOneWidget);
    expect(find.byKey(_row(_b, 'b0')), findsNothing);
    expect(
      find.text('Places loaded: 1 · shown: 1 · directories answering: 1 of 2'),
      findsOneWidget,
    );
    directory.failPages.clear();
    await tester.tap(find.byKey(const ValueKey('directory-source-retry-$_b')));
    await tester.pumpAndSettle();
    expect(find.byKey(_row(_b, 'b0')), findsOneWidget);
    expect(directory.reads, ['$_a#0', '$_b#0', '$_b#0']);
  });

  test('more directories append new sources and keep the listed ones; a '
      'failed source page is retried without losing them', () async {
    final directory = _PagedSources()
      ..pageSize = 1
      ..cards.addAll([_card(_a, 'a0'), _card(_a, 'a1'), _card(_b, 'b0')]);
    final container = ProviderContainer(
      overrides: [
        publicDiscoveryRepositoryProvider.overrideWithValue(directory),
      ],
    );
    addTearDown(container.dispose);
    final listing = discoveryListingProvider('');
    final keepAlive = container.listen(listing, (_, _) {});
    addTearDown(keepAlive.close);
    await container.read(listing.future);
    await container.read(listing.notifier).more(_a);
    expect(container.read(listing).value!.of(_a)!.pages, 2);

    await container.read(listing.notifier).moreSources();
    var results = container.read(listing).value!;
    expect(results.sourcesFailed, isTrue);
    expect(results.of(_a)!.cards.map((c) => c.id), ['a0', 'a1']);
    expect(results.canAddSources, isTrue);

    directory.failSecond = false;
    await container.read(listing.notifier).moreSources();
    results = container.read(listing).value!;
    expect(directory.sourceReads, [0, 1, 1]);
    expect(results.sources.map((s) => s.origin), [_a, _b]);
    expect(results.of(_a)!.pages, 2, reason: 'listed sources keep their pages');
    expect(results.of(_b)!.cards.single.id, 'b0');
    expect(results.moreSources, isFalse);
    expect(directory.reads, [
      '$_a#0',
      '$_a#1',
      '$_b#0',
    ], reason: 'a source already listed is not read again');
  });
}
