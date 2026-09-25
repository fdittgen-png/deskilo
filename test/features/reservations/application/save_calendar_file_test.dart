// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1643 — the decisions behind "Save calendar file", without a widget:
// whose booking may be exported, what the file says when it is read
// NOW, and whether the preview is still true at the moment of saving.
import 'dart:convert';
import 'dart:typed_data';

import 'package:deskilo/core/demo/data/reservation_repository.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/reservations/application/save_calendar_file.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 5, 13, 10);

Reservation _mine({
  String id = 'res-1',
  String memberId = 'member-1',
  ReservationStatus status = ReservationStatus.reserved,
}) =>
    Reservation(
      id: id,
      workspaceId: 'ws-1',
      seatId: 'seat-4',
      memberId: memberId,
      startsAt: WorkspaceTime.at(2026, 6, 2, 9),
      endsAt: WorkspaceTime.at(2026, 6, 2, 13),
      status: status,
    );

/// A writer that records what it was handed and answers [handle].
class _Writer {
  _Writer({this.handle = '/downloads/x'});

  String? handle;
  final calls = <({Uint8List bytes, String fileName})>[];

  Future<String?> call({
    required Uint8List bytes,
    required String fileName,
  }) async {
    calls.add((bytes: bytes, fileName: fileName));
    return handle;
  }
}

CalendarFiles _files(
  FakeReservationRepository repo,
  _Writer writer, {
  String installation = 'example.test',
  String workspaceName = 'Test Space',
}) =>
    CalendarFiles(
      reservations: repo,
      clock: FixedClock(_now),
      installation: installation,
      targetNames: () async => const {'seat-4': 'A1'},
      workspaceName: () async => workspaceName,
      write: writer.call,
    );

void main() {
  setUpAll(() => WorkspaceTime.install('Europe/Berlin'));
  tearDownAll(WorkspaceTime.reset);

  test('an owned reservation previews the file the repository holds NOW, '
      'not the row the caller had', () async {
    final repo = FakeReservationRepository()..reservations.add(_mine());
    final files = _files(repo, _Writer());
    final outcome =
        await files.prepare(reservationId: 'res-1', memberId: 'member-1');
    final preview = (outcome as CalendarFileReady).preview;
    expect(preview.reservationId, 'res-1');
    expect(preview.snapshot.summary, 'A1');
    expect(preview.snapshot.location, 'Test Space');
    expect(preview.snapshot.startUtc, DateTime.utc(2026, 6, 2, 7));
    expect(preview.snapshot.endUtc, DateTime.utc(2026, 6, 2, 11));
    expect(preview.fileName, matches(RegExp(r'^deskilo-20260602-[0-9a-f]{8}\.ics$')));
    expect(preview.text, startsWith('BEGIN:VCALENDAR\r\n'));
    expect(utf8.decode(preview.bytes), preview.text);
  });

  test('a foreign member, a missing booking and a booking the repository '
      'no longer answers for are refused with one word', () async {
    final repo = FakeReservationRepository()
      ..reservations.add(_mine(memberId: 'member-9'));
    final files = _files(repo, _Writer());
    expect(
      await files.prepare(reservationId: 'res-1', memberId: 'member-1'),
      isA<CalendarFileRefused>()
          .having((r) => r.reason, 'reason', CalendarFileRefusal.notYours),
    );
    expect(
      await files.prepare(reservationId: 'nope', memberId: 'member-1'),
      isA<CalendarFileRefused>(),
    );
    // Membership revoked between preview and save: the repository stops
    // answering, and the save is refused rather than written.
    repo.reservations.clear();
    repo.reservations.add(_mine());
    final preview = ((await files.prepare(
            reservationId: 'res-1', memberId: 'member-1')) as CalendarFileReady)
        .preview;
    repo.reservations.clear();
    final writer = _Writer();
    final saved =
        await _files(repo, writer).save(preview, memberId: 'member-1');
    expect(saved, isA<CalendarSaveRefused>());
    expect(writer.calls, isEmpty);
  });

  test('a cancelled booking is exported as CANCELLED, never hidden or '
      'passed off as live', () async {
    final repo = FakeReservationRepository()
      ..reservations.add(_mine(status: ReservationStatus.cancelled));
    final outcome = await _files(repo, _Writer())
        .prepare(reservationId: 'res-1', memberId: 'member-1');
    final preview = (outcome as CalendarFileReady).preview;
    expect(preview.text, contains('STATUS:CANCELLED\r\n'));
    expect(preview.text, isNot(contains('CONFIRMED')));
  });

  test('save writes the previewed bytes under the previewed name and '
      'mutates nothing', () async {
    final repo = FakeReservationRepository()..reservations.add(_mine());
    final writer = _Writer(handle: '/downloads/deskilo.ics');
    final files = _files(repo, writer);
    final preview = ((await files.prepare(
            reservationId: 'res-1', memberId: 'member-1')) as CalendarFileReady)
        .preview;
    final before = List.of(repo.reservations);
    final outcome = await files.save(preview, memberId: 'member-1');
    expect(outcome,
        isA<CalendarFileSaved>().having((s) => s.handle, 'handle', '/downloads/deskilo.ics'));
    expect(writer.calls.single.fileName, preview.fileName);
    expect(utf8.decode(writer.calls.single.bytes), preview.text);
    expect(repo.reservations, before, reason: 'an export is a read');
  });

  test('a booking retimed between preview and save is NOT written: the '
      'fresh preview comes back, with the same UID', () async {
    final repo = FakeReservationRepository()..reservations.add(_mine());
    final writer = _Writer();
    final files = _files(repo, writer);
    final preview = ((await files.prepare(
            reservationId: 'res-1', memberId: 'member-1')) as CalendarFileReady)
        .preview;
    repo.reservations[0] = repo.reservations[0].copyWith(
      startsAt: WorkspaceTime.at(2026, 6, 2, 14),
      endsAt: WorkspaceTime.at(2026, 6, 2, 18),
    );
    final outcome = await files.save(preview, memberId: 'member-1');
    final stale = outcome as CalendarFileStale;
    expect(writer.calls, isEmpty);
    expect(stale.fresh.snapshot.startUtc, DateTime.utc(2026, 6, 2, 12));
    expect(stale.fresh.snapshot.uid, preview.snapshot.uid,
        reason: 'a retime keeps the identity of the event');
    expect(stale.fresh.text, isNot(preview.text));
    // Saving the FRESH preview then goes through.
    expect(await files.save(stale.fresh, memberId: 'member-1'),
        isA<CalendarFileSaved>());
    expect(writer.calls.single.fileName, stale.fresh.fileName);
  });

  test('a cancellation between preview and save is stale too', () async {
    final repo = FakeReservationRepository()..reservations.add(_mine());
    final writer = _Writer();
    final files = _files(repo, writer);
    final preview = ((await files.prepare(
            reservationId: 'res-1', memberId: 'member-1')) as CalendarFileReady)
        .preview;
    repo.reservations[0] =
        repo.reservations[0].copyWith(status: ReservationStatus.cancelled);
    final outcome = await files.save(preview, memberId: 'member-1');
    expect(outcome, isA<CalendarFileStale>());
    expect((outcome as CalendarFileStale).fresh.text,
        contains('STATUS:CANCELLED'));
    expect(writer.calls, isEmpty);
  });

  test('a save the platform refuses is reported, not swallowed', () async {
    final repo = FakeReservationRepository()..reservations.add(_mine());
    final writer = _Writer(handle: null);
    final files = _files(repo, writer);
    final preview = ((await files.prepare(
            reservationId: 'res-1', memberId: 'member-1')) as CalendarFileReady)
        .preview;
    expect(await files.save(preview, memberId: 'member-1'),
        isA<CalendarSaveFailed>());
    expect(writer.calls, hasLength(1));
  });

  test('the same reservation id on two installations never collides',
      () async {
    final repo = FakeReservationRepository()..reservations.add(_mine());
    final a = ((await _files(repo, _Writer(), installation: 'a.test')
            .prepare(reservationId: 'res-1', memberId: 'member-1'))
        as CalendarFileReady);
    final b = ((await _files(repo, _Writer(), installation: 'b.test')
            .prepare(reservationId: 'res-1', memberId: 'member-1'))
        as CalendarFileReady);
    expect(a.preview.snapshot.uid, isNot(b.preview.snapshot.uid));
    expect(a.preview.fileName, isNot(b.preview.fileName));
  });

  test('canaries: neither the file, its name nor its bytes carry the '
      'member, the row, the backend or the workspace id', () async {
    final repo = FakeReservationRepository()
      ..reservations.add(_mine(memberId: 'member-private-7d1e'));
    final writer = _Writer();
    final files = _files(repo, writer, installation: 'backend.example.test');
    final preview = ((await files.prepare(
            reservationId: 'res-1', memberId: 'member-private-7d1e'))
        as CalendarFileReady)
        .preview;
    await files.save(preview, memberId: 'member-private-7d1e');
    final everything = '${preview.text}\n${preview.fileName}\n'
        '${utf8.decode(writer.calls.single.bytes)}\n${writer.calls.single.fileName}';
    for (final canary in [
      'member-private-7d1e',
      'res-1',
      'backend.example.test',
      'ws-1',
      'mailto',
      'METHOD',
      'ATTENDEE',
    ]) {
      expect(everything, isNot(contains(canary)), reason: canary);
    }
  });
}
