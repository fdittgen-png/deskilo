// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4492 — the one read answer of a page and of a part of a page: still
// reading is the progress, a read that failed is the failure with Try again
// (in a typed refusal's own words when the page has them), an answer is the
// content — an empty one included — and a refresh that failed keeps the
// content under the failure. A failed read is never drawn as the content of
// an empty answer.
import 'package:deskilo/core/ui/async_read_body.dart';
import 'package:deskilo/core/ui/loading_view.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _en = AppLocalizationsEn();

class _Refused implements Exception {
  const _Refused();
}

Future<void> _pump(WidgetTester tester, Widget body) => tester.pumpWidget(
  MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: body),
  ),
);

Widget _rows(List<String> rows) => rows.isEmpty
    ? const Text('nothing yet', key: ValueKey('empty'))
    : Column(children: [for (final r in rows) Text(r)]);

void main() {
  for (final part in [false, true]) {
    final where = part ? 'a part of a scrolling page' : 'a page';
    Widget answer(
      AsyncValue<List<String>> value, {
      VoidCallback? onRetry,
      String? Function(Object error)? refusal,
      Key? retryKey,
    }) {
      void none() {}
      if (!part) {
        return AsyncReadBody(
          value: value,
          onRetry: onRetry ?? none,
          refusal: refusal,
          retryKey: retryKey,
          isEmpty: (rows) => rows.isEmpty,
          data: _rows,
        );
      }
      // One part among others, in a list that scrolls: no height of its own.
      return ListView(
        children: [
          const Text('above'),
          AsyncReadBody.part(
            value: value,
            onRetry: onRetry ?? none,
            refusal: refusal,
            retryKey: retryKey,
            isEmpty: (rows) => rows.isEmpty,
            data: _rows,
          ),
          const Text('below'),
        ],
      );
    }

    group(where, () {
      testWidgets('still reading is the progress, not an empty answer', (
        tester,
      ) async {
        await _pump(tester, answer(const AsyncLoading()));
        expect(find.byType(LoadingView), findsOneWidget);
        expect(find.byKey(const ValueKey('empty')), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('a read that failed says so and Try again asks again; it '
          'is never the empty answer', (tester) async {
        var retried = 0;
        await _pump(
          tester,
          answer(
            AsyncError(StateError('x'), StackTrace.empty),
            onRetry: () => retried++,
          ),
        );
        expect(find.byKey(const ValueKey('read-failure')), findsOneWidget);
        expect(find.text(_en.readStateFailed), findsOneWidget);
        expect(find.byKey(const ValueKey('empty')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('inline-banner-action')));
        expect(retried, 1);
        expect(tester.takeException(), isNull);
      });

      testWidgets('a typed refusal keeps its own words and the page’s '
          'own retry key; another failure is worded by its kind', (
        tester,
      ) async {
        var retried = 0;
        String? words(Object e) => e is _Refused ? 'Not yours to see.' : null;
        await _pump(
          tester,
          answer(
            const AsyncError(_Refused(), StackTrace.empty),
            onRetry: () => retried++,
            refusal: words,
            retryKey: const ValueKey('own-retry'),
          ),
        );
        expect(find.text('Not yours to see.'), findsOneWidget);
        expect(find.text(_en.readStateFailed), findsNothing);
        await tester.tap(find.byKey(const ValueKey('own-retry')));
        expect(retried, 1);

        await _pump(
          tester,
          answer(
            AsyncError(StateError('x'), StackTrace.empty),
            refusal: words,
            retryKey: const ValueKey('own-retry'),
          ),
        );
        expect(find.text('Not yours to see.'), findsNothing);
        expect(find.text(_en.readStateFailed), findsOneWidget);
      });

      testWidgets('an answer is the content, an empty one included', (
        tester,
      ) async {
        await _pump(tester, answer(const AsyncData(['one', 'two'])));
        expect(find.text('one'), findsOneWidget);
        expect(find.byKey(const ValueKey('read-failure')), findsNothing);
        await _pump(tester, answer(const AsyncData([])));
        expect(find.byKey(const ValueKey('empty')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('a refresh that failed keeps the content under the '
          'failure', (tester) async {
        // A read that answers once and fails when it is asked again: the
        // state then carries the failure and the value it had.
        var fails = false;
        var answer0 = ['one'];
        final rows = FutureProvider<List<String>>((ref) async {
          if (fails) throw StateError('x');
          return answer0;
        });
        await tester.pumpWidget(
          ProviderScope(
            retry: (_, _) => null,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) => answer(
                    ref.watch(rows),
                    onRetry: () => ref.invalidate(rows),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('one'), findsOneWidget);
        fails = true;
        ProviderScope.containerOf(
          tester.element(find.text('one')),
        ).invalidate(rows);
        await tester.pump();
        await tester.pump();
        expect(find.text('one'), findsOneWidget);
        expect(find.byKey(const ValueKey('read-failure')), findsOneWidget);
        // Try again reads again, and the answer replaces the failure.
        fails = false;
        await tester.tap(find.byKey(const ValueKey('inline-banner-action')));
        await tester.pump();
        await tester.pump();
        expect(find.text('one'), findsOneWidget);
        expect(find.byKey(const ValueKey('read-failure')), findsNothing);

        // An empty answer of before is not repeated under a failure: the
        // failure stands alone, and the empty answer returns with a read.
        answer0 = [];
        void readAgain() => ProviderScope.containerOf(
          tester.element(find.byType(Scaffold)),
        ).invalidate(rows);
        readAgain();
        await tester.pump();
        await tester.pump();
        expect(find.byKey(const ValueKey('empty')), findsOneWidget);
        fails = true;
        readAgain();
        await tester.pump();
        await tester.pump();
        expect(find.byKey(const ValueKey('read-failure')), findsOneWidget);
        expect(find.byKey(const ValueKey('empty')), findsNothing);
        fails = false;
        await tester.tap(find.byKey(const ValueKey('inline-banner-action')));
        await tester.pump();
        await tester.pump();
        expect(find.byKey(const ValueKey('empty')), findsOneWidget);
        expect(find.byKey(const ValueKey('read-failure')), findsNothing);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
