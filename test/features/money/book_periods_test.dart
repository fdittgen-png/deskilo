// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2365 -- closing a period of the books: what the commands refuse before
// sending, the rules the demo twin keeps in step with the server (pgTAP 234),
// and the sheet from the list to the dialogs. A reopening states why; an
// owner-only door is not offered to anyone else.
import 'package:deskilo/core/demo/data/book_period_repository.dart';
import 'package:deskilo/core/demo/seed/demo_book_period_seed.dart';
import 'package:deskilo/features/money/application/book_period_commands.dart';
import 'package:deskilo/features/money/domain/book_period.dart';
import 'package:deskilo/features/money/presentation/widgets/book_periods_sheet.dart';
import 'package:deskilo/features/money/providers/book_period_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget body, List<Override> overrides) => ProviderScope(
  key: UniqueKey(),
  overrides: overrides,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: body)),
  ),
);

final _today = DateTime(2026, 10, 18);

void main() {
  test('nothing is sent for a backwards period, a period that has not ended, or a reopening without a reason', () async {
    final repo = FakeBookPeriodRepository(today: _today);
    final commands = BookPeriodCommands(repo);
    expect(await commands.close('ws', DateTime(2025, 12, 31), DateTime(2025), _today), isNull);
    expect(await commands.close('ws', DateTime(2026), DateTime(2026, 12, 31), _today), isNull);
    expect((await repo.fetch('ws')).periods, isEmpty);
    final closed = (await commands.close('ws', DateTime(2025), DateTime(2025, 12, 31), _today))!;
    expect(closed.closed, isTrue);
    expect(await commands.reopen('ws', closed, '  '), isNull);
    expect((await repo.fetch('ws')).periods.single.closed, isTrue);
    final reopened = (await commands.reopen('ws', closed, 'The accountant found an error'))!;
    expect(reopened.closed, isFalse);
    expect(reopened.reopenReason, 'The accountant found an error');
  });

  test('a closed day is found, a reopened period holds nothing, an overlap is refused', () async {
    final repo = seedDemoBookPeriods(_today);
    final overview = await repo.fetch('ws');
    expect(overview.closedOn(DateTime(2025, 6, 15)), isNotNull);
    expect(overview.closedOn(DateTime(2026, 1, 10)), isNull);
    await expectLater(
      repo.close('ws', DateTime(2025, 6), DateTime(2025, 6, 30)),
      throwsStateError,
    );
    final p = overview.periods.single;
    await repo.reopen('ws', p.id, 'again');
    expect((await repo.fetch('ws')).closedOn(DateTime(2025, 6, 15)), isNull);
  });

  test('an export of a closed year is logged as of a closed period with its digest; one reaching the open year is not', () async {
    final repo = seedDemoBookPeriods(_today);
    final commands = BookPeriodCommands(repo);
    await commands.logExport('ws', formatId: 'fec', year: 2025, content: 'a\nb\n', documents: 1);
    await commands.logExport('ws', formatId: 'fec', year: 2026, content: 'a\nb\n', documents: 1);
    final exports = (await repo.fetch('ws')).exports;
    expect(exports.map((e) => e.closedPeriod), [false, true, true]);
    expect(exports.first.sha256, exports[1].sha256, reason: 'the same bytes, the same digest');
    expect(exports.first.sha256, hasLength(64));
    expect(exports.first.rowCount, 2);
    expect(exports.first.byteCount, 4);
  });

  test('a failed log never fails the export', () async {
    final commands = BookPeriodCommands(_Broken());
    await commands.logExport('ws', formatId: 'fec', year: 2025, content: 'x', documents: 1);
  });

  testWidgets('the sheet lists the closed year and its export; only an owner is offered the doors', (tester) async {
    final repo = seedDemoBookPeriods(_today);
    Future<void> open({required bool owner}) async {
      await tester.pumpWidget(_app(
        BookPeriodsView(workspaceId: 'ws', isOwner: owner),
        [bookPeriodRepositoryProvider.overrideWithValue(repo)],
      ));
      await tester.pumpAndSettle();
    }

    await open(owner: false);
    expect(find.byKey(const ValueKey('book-period-demo-period-last-year')), findsOneWidget);
    expect(find.byKey(const ValueKey('book-export-demo-export-last-year')), findsOneWidget);
    expect(find.textContaining('FEC'), findsOneWidget);
    expect(find.byKey(const ValueKey('book-period-close')), findsNothing);
    expect(find.byKey(const ValueKey('book-period-reopen-demo-period-last-year')), findsNothing);

    await open(owner: true);
    expect(find.byKey(const ValueKey('book-period-close')), findsOneWidget);
    expect(find.byKey(const ValueKey('book-period-reopen-demo-period-last-year')), findsOneWidget);
  });

  testWidgets('reopening: no reason sends nothing, a reason reopens', (tester) async {
    final repo = seedDemoBookPeriods(_today);
    await tester.pumpWidget(_app(
      const BookPeriodsView(workspaceId: 'ws', isOwner: true),
      [bookPeriodRepositoryProvider.overrideWithValue(repo)],
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('book-period-reopen-demo-period-last-year')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('book-period-reopen-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('book-period-reopen-invalid')), findsOneWidget);
    expect(repo.periods.single.closed, isTrue);

    await tester.enterText(find.byKey(const ValueKey('book-period-reason')), 'Error found');
    await tester.tap(find.byKey(const ValueKey('book-period-reopen-save')));
    await tester.pumpAndSettle();
    expect(repo.periods.single.closed, isFalse);
    expect(repo.periods.single.reopenReason, 'Error found');
  });

  testWidgets('closing: no days sends nothing', (tester) async {
    final repo = seedDemoBookPeriods(_today);
    await tester.pumpWidget(_app(
      const BookPeriodsView(workspaceId: 'ws', isOwner: true),
      [bookPeriodRepositoryProvider.overrideWithValue(repo)],
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('book-period-close')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('book-period-close-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('book-period-invalid')), findsOneWidget);
    expect(repo.periods, hasLength(1));
  });
}

class _Broken extends FakeBookPeriodRepository {
  _Broken() : super(today: DateTime(2026, 10, 18));

  @override
  Future<void> recordExport(String workspaceId, BookExportRecord record) async =>
      throw Exception('offline');
}
