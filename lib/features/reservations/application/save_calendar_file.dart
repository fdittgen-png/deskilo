// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1643 — the command behind "Save calendar file".
//
// A class behind a provider rather than a free function (#1449): the
// free form leaves every caller resolving the repository to hand it
// over, so the widget stays counted by the layering ratchet and the
// extraction is only half made. `CalendarFiles` resolves everything
// itself; the button only says which reservation the member is looking
// at.
//
// ## What is decided here
//
//   - whether this member may export this booking: it must exist and be
//     THEIRS. A foreign booking, a booking the repository no longer
//     answers for (revoked membership, wrong workspace) and one that
//     never existed are all refused the same way, so a refusal does not
//     say which.
//   - what the file says: the snapshot, built from the reservation the
//     repository returns NOW — never from the row the sheet was opened
//     with, which may be minutes old.
//   - whether the preview is still true at save time: the booking is
//     read again and compared with the previewed snapshot; a retime or
//     a cancellation in between hands back a FRESH preview to look at
//     instead of a stale file.
//
// ## What is deliberately not here
//
// No BuildContext, no l10n, no snack bar: outcomes are values and the
// button renders them. No write to the booking, the events or the
// ledger: exporting is a read. And no catch — a repository failure is
// the caller's to report, through the guard every button uses.
import 'dart:convert';
import 'dart:typed_data';

import '../../../core/time/clock.dart';
import '../domain/reservation.dart';
import '../domain/reservation_calendar_file.dart';
import '../domain/reservation_repository.dart';

/// The local save seam as the command sees it — structurally the
/// `FileSaver` of `core/files`, restated here so the application layer
/// does not import a file that imports Flutter.
typedef CalendarFileWriter = Future<String?> Function({
  required Uint8List bytes,
  required String fileName,
});

/// A file ready to be saved: the fields the member is shown, and the
/// bytes that will leave the device — the same thing, twice.
final class CalendarFilePreview {
  const CalendarFilePreview({
    required this.reservationId,
    required this.snapshot,
    required this.fileName,
    required this.text,
  });

  final String reservationId;
  final CalendarSnapshot snapshot;
  final String fileName;

  /// The file's text; its UTF-8 encoding is what gets written.
  final String text;

  Uint8List get bytes => Uint8List.fromList(utf8.encode(text));
}

/// Why a preview was not produced.
enum CalendarFileRefusal {
  /// Not found, not the member's, or not answered by the repository —
  /// deliberately one word for all three.
  notYours,
}

/// What asking for a preview did.
sealed class CalendarFileOutcome {
  const CalendarFileOutcome();
}

final class CalendarFileReady extends CalendarFileOutcome {
  const CalendarFileReady(this.preview);

  final CalendarFilePreview preview;
}

final class CalendarFileRefused extends CalendarFileOutcome {
  const CalendarFileRefused(this.reason);

  final CalendarFileRefusal reason;
}

/// What saving did.
sealed class CalendarSaveOutcome {
  const CalendarSaveOutcome();
}

/// The bytes are in the member's storage; [handle] names where.
final class CalendarFileSaved extends CalendarSaveOutcome {
  const CalendarFileSaved(this.handle);

  final String handle;
}

/// The booking changed since the preview. [fresh] is what it says now —
/// the member looks again and decides again; nothing was written.
final class CalendarFileStale extends CalendarSaveOutcome {
  const CalendarFileStale(this.fresh);

  final CalendarFilePreview fresh;
}

/// The booking is no longer the member's to export. Nothing was written.
final class CalendarSaveRefused extends CalendarSaveOutcome {
  const CalendarSaveRefused(this.reason);

  final CalendarFileRefusal reason;
}

/// The platform did not save the file — the seam answered null.
final class CalendarSaveFailed extends CalendarSaveOutcome {
  const CalendarSaveFailed();
}

/// Builds and saves one owned reservation's calendar file.
class CalendarFiles {
  CalendarFiles({
    required this._reservations,
    required this._clock,
    required this._installation,
    required this._targetNames,
    required this._workspaceName,
    required this._write,
  });

  final ReservationRepository _reservations;
  final Clock _clock;
  final String _installation;
  final Future<Map<String, String>> Function() _targetNames;
  final Future<String> Function() _workspaceName;
  final CalendarFileWriter _write;

  /// The preview for [reservationId], as the repository reports it now,
  /// or a refusal when it is not [memberId]'s to export.
  Future<CalendarFileOutcome> prepare({
    required String reservationId,
    required String memberId,
  }) async {
    final reservation = await _reservations.fetchById(reservationId);
    if (reservation == null || reservation.memberId != memberId) {
      return const CalendarFileRefused(CalendarFileRefusal.notYours);
    }
    return CalendarFileReady(await _previewOf(reservation));
  }

  /// Writes [preview] — unless the booking no longer matches it.
  ///
  /// The re-read is the point: between the preview and the tap the
  /// booking may have been retimed on another device or cancelled by
  /// an administrator, and the file the member confirmed would then
  /// describe a booking that no longer exists in that shape.
  Future<CalendarSaveOutcome> save(
    CalendarFilePreview preview, {
    required String memberId,
  }) async {
    final reservation = await _reservations.fetchById(preview.reservationId);
    if (reservation == null || reservation.memberId != memberId) {
      return const CalendarSaveRefused(CalendarFileRefusal.notYours);
    }
    final fresh = await _previewOf(reservation);
    if (!fresh.snapshot.sameBookingAs(preview.snapshot)) {
      return CalendarFileStale(fresh);
    }
    final handle = await _write(bytes: preview.bytes, fileName: preview.fileName);
    if (handle == null) return const CalendarSaveFailed();
    return CalendarFileSaved(handle);
  }

  Future<CalendarFilePreview> _previewOf(Reservation reservation) async {
    final names = await _targetNames();
    final snapshot = calendarSnapshotOf(
      reservation,
      installation: _installation,
      spaceName: reservation.spaceNameFrom(names),
      workspaceName: await _workspaceName(),
      now: _clock.now(),
    );
    return CalendarFilePreview(
      reservationId: reservation.id,
      snapshot: snapshot,
      fileName: calendarFileNameFor(snapshot),
      text: serializeCalendarFile(snapshot),
    );
  }
}

/// `deskilo-20260329-1a2b3c4d.ics`: the start date and the first eight
/// hex digits of the UID. Nothing in the name says whose booking it is
/// or where it was booked — the name travels further than the file.
String calendarFileNameFor(CalendarSnapshot snapshot) {
  final date = formatCalendarInstant(snapshot.startUtc).substring(0, 8);
  final tag = snapshot.uid.substring(0, 8);
  return 'deskilo-$date-$tag.ics';
}
