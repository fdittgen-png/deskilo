// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2575 -- a series preview names the dates that would fail before anything
// books: the demo preview writes nothing, and the dialog lets the person
// book the others or nothing.
import 'package:deskilo/core/demo/data/reservation_repository.dart';
import 'package:deskilo/core/demo/data/series_previewer.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/domain/reservation_repository.dart';
import 'package:deskilo/features/reservations/domain/series_preview.dart';
import 'package:deskilo/features/reservations/presentation/widgets/series_preview_dialog.dart';
import 'package:deskilo/features/reservations/providers/reservation_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

final _monday = DateTime(2027, 1, 4, 8);

SeriesAsk _ask() => SeriesAsk(
  workspaceId: 'ws-1',
  seatId: 'seat-1',
  firstStart: _monday,
  firstEnd: _monday.add(const Duration(hours: 4)),
  pattern: SeriesPattern.daily,
  until: _monday.add(const Duration(days: 2)),
);

class _Previewer implements SeriesPreviewer {
  _Previewer(this.booked, this.skipped);
  final int booked;
  final List<DateTime> skipped;

  @override
  Future<SeriesResult> preview(SeriesAsk ask) async => SeriesResult(
    seriesId: '',
    booked: [for (var i = 0; i < booked; i++) _monday],
    skipped: skipped,
  );
}

Future<bool?> _ask0(WidgetTester tester, SeriesPreviewer previewer) async {
  bool? answer;
  await pumpApp(
    tester,
    Consumer(
      builder: (context, ref, _) => TextButton(
        onPressed: () async => answer = await confirmSeriesPreview(
          context,
          () => ref.read(seriesPreviewerProvider),
          _ask(),
        ),
        child: const Text('go'),
      ),
    ),
    overrides: [seriesPreviewerProvider.overrideWithValue(previewer)],
  );
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
  return answer;
}

void main() {
  test('the demo preview names a taken date and writes nothing', () async {
    final repo = FakeReservationRepository()
      ..reservations.add(
        Reservation(
          id: 'taken',
          workspaceId: 'ws-1',
          seatId: 'seat-1',
          memberId: 'member-2',
          startsAt: _monday.add(const Duration(days: 1)),
          endsAt: _monday.add(const Duration(days: 1, hours: 4)),
          status: ReservationStatus.reserved,
        ),
      );
    final preview = await FakeSeriesPreviewer(repo).preview(_ask());
    expect(preview.booked, hasLength(2));
    expect(preview.skipped, [_monday.add(const Duration(days: 1))]);
    expect(repo.reservations.map((r) => r.id), ['taken']);
  });

  testWidgets('every date books: no question is asked', (tester) async {
    expect(await _ask0(tester, _Previewer(3, const [])), isTrue);
    expect(find.byKey(const ValueKey('series-preview-dialog')), findsNothing);
  });

  testWidgets('a failing date is named; cancel books nothing', (tester) async {
    final answer = _ask0(
      tester,
      _Previewer(2, [_monday.add(const Duration(days: 1))]),
    );
    await answer;
    expect(find.byKey(const ValueKey('series-preview-dialog')), findsOneWidget);
    expect(find.text('Tue, Jan 5'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('series-preview-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('series-preview-dialog')), findsNothing);
  });

  testWidgets('the person may book the others', (tester) async {
    bool? answer;
    await pumpApp(
      tester,
      Consumer(
        builder: (context, ref, _) => TextButton(
          onPressed: () async => answer = await confirmSeriesPreview(
            context,
            () => ref.read(seriesPreviewerProvider),
            _ask(),
          ),
          child: const Text('go'),
        ),
      ),
      overrides: [
        seriesPreviewerProvider.overrideWithValue(
          _Previewer(2, [_monday.add(const Duration(days: 1))]),
        ),
      ],
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('series-preview-book-others')));
    await tester.pumpAndSettle();
    expect(answer, isTrue);
  });

  testWidgets('nothing would book: only cancel is offered', (tester) async {
    await _ask0(tester, _Previewer(0, [_monday]));
    expect(
      find.byKey(const ValueKey('series-preview-book-others')),
      findsNothing,
    );
    expect(find.text('None of these dates can be booked.'), findsOneWidget);
  });
}
