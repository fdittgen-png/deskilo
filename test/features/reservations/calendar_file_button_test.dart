// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1643 — "Save calendar file" on my own booking: the preview says what
// the file says, the save hands exactly those bytes to the local seam,
// cancel writes nothing, a refused save keeps the dialog for a retry, a
// booking that moved in between is shown again before anything is
// written — and the button is absent when the feature is off or the
// booking is somebody else's.
import 'dart:convert';
import 'dart:typed_data';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/presentation/widgets/reservation_detail_sheet.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_accessory_repository.dart';
import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/fake_reservation_repository.dart';
import '../../helpers/in_memory_default_level_store.dart';
import '../../helpers/mock_providers.dart';
import '../calendar/reservation_detail_sheet_test.dart' show reservationAt;

/// The captured local save.
class Saves {
  String? handle = '/downloads/deskilo.ics';
  final calls = <({Uint8List bytes, String fileName})>[];

  Future<String?> call({
    required Uint8List bytes,
    required String fileName,
  }) async {
    calls.add((bytes: bytes, fileName: fileName));
    return handle;
  }
}

Future<FakeReservationRepository> pump(
  WidgetTester tester, {
  required List<Reservation> seed,
  required Saves saves,
  bool featureOn = true,
}) async {
  final reservations = FakeReservationRepository()..reservations.addAll(seed);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          workspace: FakeWorkspaceRepository.withWorkspace(
            featureFlags: {
              'calendarHub': false,
              if (!featureOn) 'calendarFileExport': false,
            },
          ),
          floorPlan: FakeFloorPlanRepository()..seedSmallPlan(),
          reservations: reservations,
          accessories: FakeAccessoryRepository(),
          defaultLevel: InMemoryDefaultLevelStore(),
        ),
        fileSaverProvider.overrideWithValue(saves.call),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Calendar'));
  await tester.pumpAndSettle();
  return reservations;
}

/// Today 23:00 on the seeded seat, so the sheet opens on a booking that
/// is mine and still ahead — `flutter test` runs the device clock in
/// UTC-7, so an afternoon slot on the Berlin workspace clock is already
/// past by `kTestNow` and the sheet would show the request path instead.
Reservation todayAt23() {
  final now = kTestNow;
  return reservationAt(
    WorkspaceTime.at(now.year, now.month, now.day, 23),
    seatId: 'seat-4',
  );
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.textContaining('23:00'));
  await tester.pumpAndSettle();
}

final _button = find.byKey(const ValueKey('reservation-calendar-file'));
final _preview = find.byKey(const ValueKey('calendar-file-preview'));
final _save = find.byKey(const ValueKey('calendar-file-save'));
final _cancel = find.byKey(const ValueKey('calendar-file-cancel'));

Future<void> _tapButton(WidgetTester tester) async {
  await tester.ensureVisible(_button);
  await tester.tap(_button);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => WorkspaceTime.install('Europe/Berlin'));
  tearDownAll(WorkspaceTime.reset);

  testWidgets('the preview names the event, the time, the venue, the status '
      'and the file, warns that it is a snapshot, and shows the bytes',
      (tester) async {
    final saves = Saves();
    await pump(tester, seed: [todayAt23()], saves: saves);
    await _openSheet(tester);
    expect(find.text('Save calendar file'), findsOneWidget);
    await _tapButton(tester);

    expect(_preview, findsOneWidget);
    expect(find.textContaining('Event: A1'), findsOneWidget);
    expect(find.textContaining('23:00'), findsWidgets);
    expect(find.textContaining('Location: Test Space'), findsOneWidget);
    expect(find.textContaining('Status: Confirmed'), findsOneWidget);
    expect(find.textContaining(RegExp(r'File: deskilo-20260513-[0-9a-f]{8}\.ics')),
        findsOneWidget);
    expect(find.textContaining('snapshot'), findsOneWidget);
    expect(find.textContaining('cannot be taken back'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('calendar-file-contents')));
    await tester.pumpAndSettle();
    final raw = tester
        .widget<SelectableText>(find.byKey(const ValueKey('calendar-file-text')))
        .data!;
    expect(raw, startsWith('BEGIN:VCALENDAR\r\n'));
    expect(raw, contains('DTSTART:20260513T210000Z\r\n'));
    expect(raw, contains('DTEND:20260513T230000Z\r\n'));
    expect(raw, contains('SUMMARY:A1\r\n'));
    expect(raw, isNot(contains('member-1')));
    expect(saves.calls, isEmpty, reason: 'a preview writes nothing');
  });

  testWidgets('Save hands the previewed bytes to the local seam under the '
      'previewed name, closes, names where it went — and touches no booking',
      (tester) async {
    final saves = Saves();
    final repo = await pump(tester, seed: [todayAt23()], saves: saves);
    final before = List.of(repo.reservations);
    await _openSheet(tester);
    await _tapButton(tester);
    final shownName = tester
        .widgetList<Text>(find.textContaining('File: deskilo-'))
        .first;
    await tester.tap(_save);
    await tester.pumpAndSettle();

    expect(_preview, findsNothing);
    expect(saves.calls, hasLength(1));
    final call = saves.calls.single;
    expect(shownName.textSpan!.toPlainText(), 'File: ${call.fileName}');
    expect(call.fileName, endsWith('.ics'));
    final text = utf8.decode(call.bytes);
    expect(text, startsWith('BEGIN:VCALENDAR\r\nVERSION:2.0\r\n'));
    expect(text, endsWith('END:VEVENT\r\nEND:VCALENDAR\r\n'));
    expect(text, contains('STATUS:CONFIRMED\r\n'));
    expect(text, contains('LOCATION:Test Space\r\n'));
    expect(text, isNot(contains('member-1')));
    expect(text, isNot(contains('res-1')));
    expect(find.textContaining('Saved to /downloads/deskilo.ics'),
        findsOneWidget);
    expect(repo.reservations, before, reason: 'an export is a read');
  });

  testWidgets('Cancel writes nothing', (tester) async {
    final saves = Saves();
    await pump(tester, seed: [todayAt23()], saves: saves);
    await _openSheet(tester);
    await _tapButton(tester);
    await tester.tap(_cancel);
    await tester.pumpAndSettle();
    expect(_preview, findsNothing);
    expect(saves.calls, isEmpty);
  });

  testWidgets('a save the platform refuses keeps the dialog open, says so, '
      'and the next Save is the retry', (tester) async {
    final saves = Saves()..handle = null;
    await pump(tester, seed: [todayAt23()], saves: saves);
    await _openSheet(tester);
    await _tapButton(tester);
    await tester.tap(_save);
    await tester.pumpAndSettle();
    expect(_preview, findsOneWidget, reason: 'the file is still right');
    expect(find.text('Could not save the file.'), findsOneWidget);
    expect(saves.calls, hasLength(1));

    // Let the error snack expire, or the success one queues behind it.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    saves.handle = '/downloads/retry.ics';
    await tester.tap(_save);
    await tester.pumpAndSettle();
    expect(_preview, findsNothing);
    expect(saves.calls, hasLength(2));
    expect(find.textContaining('Saved to /downloads/retry.ics'),
        findsOneWidget);
  });

  testWidgets('a booking retimed after the preview is not written: the '
      'dialog shows the fresh times and says to look again', (tester) async {
    final saves = Saves();
    final repo = await pump(tester, seed: [todayAt23()], saves: saves);
    await _openSheet(tester);
    await _tapButton(tester);
    expect(find.byKey(const ValueKey('calendar-file-stale')), findsNothing);

    // Another device moves the booking while the dialog is open.
    final now = kTestNow;
    repo.reservations[0] = repo.reservations[0].copyWith(
      startsAt: WorkspaceTime.at(now.year, now.month, now.day, 20),
      endsAt: WorkspaceTime.at(now.year, now.month, now.day, 22),
    );
    await tester.tap(_save);
    await tester.pumpAndSettle();

    expect(saves.calls, isEmpty);
    expect(_preview, findsOneWidget);
    expect(find.byKey(const ValueKey('calendar-file-stale')), findsOneWidget);
    expect(find.textContaining('20:00'), findsWidgets);

    // Saving what is now shown goes through, with the fresh instant.
    await tester.tap(_save);
    await tester.pumpAndSettle();
    expect(saves.calls, hasLength(1));
    expect(utf8.decode(saves.calls.single.bytes),
        contains('DTSTART:20260513T180000Z\r\n'));
  });

  testWidgets('feature OFF: the button is absent, and so is any preview',
      (tester) async {
    final saves = Saves();
    await pump(tester, seed: [todayAt23()], saves: saves, featureOn: false);
    await _openSheet(tester);
    expect(find.byKey(const ValueKey('reservation-edit')), findsOneWidget,
        reason: 'the sheet itself is open');
    expect(_button, findsNothing);
    expect(saves.calls, isEmpty);
  });

  testWidgets('somebody else\'s booking has no button', (tester) async {
    // The Calendar tab lists only my own bookings, so the sheet is
    // pumped directly on a foreign one — the same widget, same providers.
    final foreign = todayAt23().copyWith(memberId: 'member-9');
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(
          workspace: FakeWorkspaceRepository.withWorkspace(),
          floorPlan: FakeFloorPlanRepository()..seedSmallPlan(),
          reservations: FakeReservationRepository()..reservations.add(foreign),
          accessories: FakeAccessoryRepository(),
        ),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ReservationDetailSheet(reservation: foreign)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Show on plan'), findsOneWidget,
        reason: 'the sheet itself is open');
    expect(find.byKey(const ValueKey('reservation-edit')), findsNothing,
        reason: 'not mine: no edit either');
    expect(_button, findsNothing);
  });
}
