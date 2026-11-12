// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3610 — one search at a time: an older answer never replaces a newer
// one, an answer for another account, server or workspace is dropped, and a
// source that fails or never answers gives nothing.
import 'dart:async';

import 'package:deskilo/features/search/application/search_run.dart';
import 'package:deskilo/features/search/domain/search_result.dart';
import 'package:flutter_test/flutter_test.dart';

const SearchScope _a = (account: 'u1', server: 'https://s', workspace: 'A');
const SearchScope _b = (account: 'u1', server: 'https://s', workspace: 'B');

SearchResult _r(String id) => SearchResult(
  id: id,
  kind: SearchKind.record,
  source: 'test',
  title: id,
  where: 'test',
);

/// A source whose answers the test releases by hand.
class _Held implements SearchSource {
  final Map<String, Completer<List<SearchResult>>> asked = {};

  @override
  String get id => 'test';

  @override
  Future<List<SearchResult>> search(String query) =>
      (asked[query] = Completer()).future;
}

class _Fails implements SearchSource {
  @override
  String get id => 'fails';

  @override
  Future<List<SearchResult>> search(String query) =>
      Future.error(StateError('down'));
}

class _Many implements SearchSource {
  @override
  String get id => 'many';

  @override
  Future<List<SearchResult>> search(String query) async => [
    for (var i = 0; i < 20; i++) _r('m$i'),
  ];
}

void main() {
  test('a slow "Al" never replaces the newer "Alice"', () async {
    final run = SearchRun();
    final held = _Held();
    const SearchScope scope = _a;
    final al = run.run(_a, 'Al', [held], currentScope: () => scope);
    final alice = run.run(_a, 'Alice', [held], currentScope: () => scope);
    held.asked['Alice']!.complete([_r('alice')]);
    expect((await alice)!.single.id, 'alice');
    held.asked['Al']!.complete([_r('al'), _r('alice')]);
    expect(await al, isNull);
  });

  test(
    'an A answer arriving after the switch to B is dropped; B\'s stays',
    () async {
      final run = SearchRun();
      final held = _Held();
      SearchScope? scope = _a;
      final fromA = run.run(_a, 'inv', [held], currentScope: () => scope);
      final heldA = held.asked['inv']!;
      // The person switches to B; the window discards what was in flight.
      scope = _b;
      run.discard();
      final fromB = run.run(_b, 'inv', [held], currentScope: () => scope);
      held.asked['inv']!.complete([_r('b-invoice')]);
      expect((await fromB)!.single.id, 'b-invoice');
      heldA.complete([_r('a-invoice')]);
      expect(await fromA, isNull);
    },
  );

  test('a sign-out while a search runs drops its answer', () async {
    final run = SearchRun();
    final held = _Held();
    SearchScope? scope = _a;
    final found = run.run(_a, 'x', [held], currentScope: () => scope);
    scope = null;
    held.asked['x']!.complete([_r('x')]);
    expect(await found, isNull);
  });

  test('a failing source gives nothing, a slow one is cut, a long one is '
      'bounded', () async {
    final run = SearchRun(
      perSource: 3,
      timeout: const Duration(milliseconds: 10),
    );
    final found = await run.run(_a, 'q', [
      _Fails(),
      _Held(),
      _Many(),
    ], currentScope: () => _a);
    expect(found!.map((r) => r.id), ['m0', 'm1', 'm2']);
  });

  test('every word of the query is found, whatever the case', () {
    expect(searchMatches('inv 2026', ['INV-2026-0001', 'Acme']), isTrue);
    expect(searchMatches('acme inv', ['INV-2026-0001', 'Acme']), isTrue);
    expect(searchMatches('zeta', ['INV-2026-0001', 'Acme']), isFalse);
    expect(searchMatches('  ', ['anything']), isFalse);
  });
}
