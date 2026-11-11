// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3680 — several reads answer together: a figure is shown only when each
// read holds a value; a running read stands in as progress, a failed one as
// the failure with Try again, never as an empty list.
import 'package:deskilo/core/ui/async_read_body.dart';
import 'package:deskilo/core/ui/loading_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const one = AsyncData<List<int>>([1]);
  const empty = AsyncData<List<int>>([]);
  const running = AsyncLoading<List<int>>();
  final failed = AsyncError<List<int>>(StateError('down'), StackTrace.empty);

  test('every read with a value is answered, an empty list included', () {
    expect(ReadsAnswer.of([one, empty]).answered, isTrue);
    expect(ReadsAnswer.of([one, empty]).standIn(onRetry: () {}), isNull);
  });

  test('a running read stands in as progress', () {
    final a = ReadsAnswer.of([one, running]);
    expect(a.answered, isFalse);
    expect(a.waiting, isTrue);
    expect(a.standIn(onRetry: () {}), isA<LoadingView>());
  });

  test('a failed read stands in as the failure, before any running one', () {
    final a = ReadsAnswer.of([running, failed, one]);
    expect(a.failure, isA<StateError>());
    expect(a.standIn(onRetry: () {}), isA<ReadFailureBanner>());
  });

  test('a refresh that failed keeps the value it had: still answered', () {
    final refreshed = failed.copyWithPrevious(one);
    expect(refreshed.hasError, isTrue);
    expect(ReadsAnswer.of([refreshed]).answered, isTrue);
  });
}
