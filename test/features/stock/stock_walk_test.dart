// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4401 -- the one stock walk: it reads the first page, then each page from the cursor the last gave; a failed
// page keeps the rows shown and asks the same cursor again; the first page stays readable for what the read says as
// a whole; a reload starts again. On hand, the movements, the registry and the goods of a document all walk this.
import 'package:deskilo/features/stock/application/stock_walk.dart';
import 'package:deskilo/features/stock/domain/stock_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Three pages of two numbers; [failAt] makes the page after that cursor fail once.
class _Pages {
  final asked = <StockCursor?>[];
  int? failAt;

  Future<StockPage<int>> read(StockCursor? after) async {
    asked.add(after);
    final from = (after?['n'] as int?) ?? 0;
    if (failAt == from) {
      failAt = null;
      throw StateError('the page could not be read');
    }
    final rows = [from, from + 1];
    final complete = from + 2 >= 6;
    return StockPage(
      rows: rows,
      complete: complete,
      next: complete ? null : {'n': from + 2},
    );
  }
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late _Pages pages;
  late ProviderContainer container;
  late NotifierProvider<StockWalk<int>, StockWalkState<int>> walk;

  setUp(() {
    pages = _Pages();
    walk = NotifierProvider<StockWalk<int>, StockWalkState<int>>(
      () => StockWalk<int>((ref) => pages.read),
    );
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  test('the first page, then each page from the cursor the last one gave, to the end', () async {
    container.listen(walk, (_, _) {});
    expect(container.read(walk).isFirstLoad, isTrue);
    await _settle();
    expect(container.read(walk).rows, [0, 1]);
    await container.read(walk.notifier).loadMore();
    await container.read(walk.notifier).loadMore();
    final state = container.read(walk);
    expect(state.rows, [0, 1, 2, 3, 4, 5]);
    expect(state.complete, isTrue);
    expect(state.canLoadMore, isFalse);
    expect(pages.asked, [
      null,
      {'n': 2},
      {'n': 4},
    ]);
    expect(state.first?.rows, [0, 1], reason: 'the first page stays readable');
  });

  test(
    'a failed page keeps the rows shown and the same cursor is asked again',
    () async {
      container.listen(walk, (_, _) {});
      await _settle();
      pages.failAt = 2;
      await container.read(walk.notifier).loadMore();
      var state = container.read(walk);
      expect(state.error, isA<StateError>());
      expect(state.rows, [
        0,
        1,
      ], reason: 'a failure is never shown as an empty list');
      expect(state.failedFirst, isFalse);
      await container.read(walk.notifier).loadMore();
      state = container.read(walk);
      expect(state.error, isNull);
      expect(state.rows, [0, 1, 2, 3]);
      expect(pages.asked, [
        null,
        {'n': 2},
        {'n': 2},
      ]);
    },
  );

  test('a reload starts again from the first page', () async {
    container.listen(walk, (_, _) {});
    await _settle();
    await container.read(walk.notifier).loadMore();
    await container.read(walk.notifier).reload();
    expect(container.read(walk).rows, [0, 1]);
    expect(pages.asked.last, isNull);
  });
}
