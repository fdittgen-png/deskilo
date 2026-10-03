// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1865 — the booking adapter, the edited copy and the route treatment
// say only categories: whom a booking is for becomes "self" or "another
// member", a refusal its category, a day its relation to today; an
// edited copy keeps provenance and dependency validity; a protected
// screen leaves a marker and an uninstrumented one a visible manual step.
import 'dart:async';
import 'dart:io';

import 'package:deskilo/features/reservations/application/book_seat.dart';
import 'package:deskilo/features/reservations/domain/reservation_repository.dart';
import 'package:deskilo/features/task_recorder/application/booking_observation.dart';
import 'package:deskilo/features/task_recorder/domain/action_registry.dart';
import 'package:deskilo/features/task_recorder/domain/recording_edit.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording_codec.dart';
import 'package:deskilo/features/task_recorder/presentation/route_classification.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/recording_fixtures.dart';

void main() {
  group('booking adapter', () {
    test('the attempt says what was asked, as categories', () {
      expect(
          bookingAttemptPayload(forSomeoneElse: true, series: false, checkIn: true),
          {'for_whom': 'other_member', 'repeat': 'once', 'check_in': 'yes'});
    });

    test('each command outcome maps to its registered outcome', () {
      final at = DateTime.utc(2026, 10, 5, 9);
      expect(
          bookingOutcomeObservation(Booked(
                  reservationId: kCanaryReservationId,
                  start: at,
                  end: at,
                  checkedIn: false))
              .outcome,
          RecorderOutcomes.bookingConfirmed);
      final requested = bookingOutcomeObservation(const SentForConfirmation(
          reservationId: kCanaryReservationId, subjectMemberId: kCanaryUserId));
      expect(requested.outcome, RecorderOutcomes.bookingRequested);
      expect(requested.payload, isEmpty);
      final partly = bookingOutcomeObservation(SeriesBooked(SeriesResult(
          seriesId: kCanaryReservationId, booked: [at], skipped: [at])));
      expect(partly.payload, {'series_result': 'partially_booked'});
      for (final o in [requested, partly]) {
        expect(o.payload.toString(), isNot(contains('CANARY')));
      }
    });

    test('a lost connection or a timeout is unknown; anything else refused',
        () {
      expect(bookingErrorObservation(const SocketException('Failed host lookup'))
          .outcome, RecorderOutcomes.bookingUnknown);
      expect(bookingErrorObservation(TimeoutException('slow')).outcome,
          RecorderOutcomes.bookingUnknown);
      final refused =
          bookingErrorObservation(StateError('overlap with $kCanaryMemberName'));
      expect(refused.outcome, RecorderOutcomes.bookingRefused);
      expect(refused.payload, {'refusal': 'conflict'});
      expect(refusalCategory(StateError('outside the opening hours')), 'closed');
      expect(refusalCategory(StateError('quota exceeded')), 'quota');
      expect(refusalCategory(StateError('42501')), 'permission');
      expect(refusalCategory(StateError('something odd')), 'other');
    });

    test('a day is told by its relation to today, never by its date', () {
      final monday = DateTime(2026, 10, 5);
      expect(dateRelation(monday, monday), 'today');
      expect(dateRelation(DateTime(2026, 10, 6), monday), 'tomorrow');
      expect(dateRelation(DateTime(2026, 10, 9), monday), 'later_this_week');
      expect(dateRelation(DateTime(2026, 10, 12), monday), 'later');
      expect(dateRelation(DateTime(2026, 10, 4), monday), 'past');
      expect(periodOf(startHour: 8, length: const Duration(hours: 4)), 'morning');
      expect(periodOf(startHour: 13, length: const Duration(hours: 4)),
          'afternoon');
      expect(periodOf(startHour: 8, length: const Duration(hours: 10)),
          'full_day');
    });
  });

  group('edited copy', () {
    late TaskRecording source;
    setUp(() async {
      source = (await recordFixture(BookingJourney.planConfirmed)).recording;
    });

    int seqOf(String id) =>
        source.steps.firstWhere((s) => s.action == id || s.outcome == id).seq;

    test('leaving out an attempt leaves out its outcome; provenance kept', () {
      final attempt = seqOf(RecorderActions.confirmBooking);
      final edited = editedCopy(source, {attempt});
      expect(edited.kind, RecordingKind.edited);
      expect(edited.sourceDigest, recordingDigest(source));
      expect(edited.steps.length, source.steps.length - 2);
      expect(edited.steps.map((s) => s.seq),
          [for (var i = 1; i <= edited.steps.length; i++) i]);
      expect(edited.steps.last.sourceSeq, source.steps.last.seq);
      expect(edited.completeness, source.completeness);
      final decoded = decodeRecordingText(encodeRecordingText(edited));
      expect(decoded.accepted, isTrue, reason: '${decoded.issues}');
    });

    test('leaving out only the outcome keeps an honest unanswered attempt',
        () {
      final edited =
          editedCopy(source, {seqOf(RecorderOutcomes.bookingConfirmed)});
      expect(edited.unansweredAttempts, hasLength(1));
      expect(decodeRecordingText(encodeRecordingText(edited)).accepted, isTrue);
    });

    test('nothing left out is the source itself', () {
      expect(identical(editedCopy(source, const {}), source), isTrue);
    });

    test('an edited copy never claims completeness the source lacked',
        () async {
      final partial = TaskRecording(
        actionContractVersion: 1,
        platform: RecordingPlatform.web,
        segments: source.segments,
        steps: source.steps.take(6).toList(), // the attempt, unanswered
        endReason: RecordingEndReason.stopped,
      );
      expect(partial.completeness, Completeness.partial);
      final edited = editedCopy(partial, {1});
      expect(edited.completeness, Completeness.partial);
    });
  });

  group('route treatment', () {
    test('instrumented, protected and unrecorded routes', () {
      expect(treatRoute('/reserve'), isA<Instrumented>());
      expect(treatRoute('/res/abc'), isA<Instrumented>());
      expect(treatRoute(taskRecorderRoute), isA<RecorderScreen>());
      expect((treatRoute('/auth') as Protected).category,
          ProtectedSurface.authentication);
      expect((treatRoute('/conversation/42') as Protected).category,
          ProtectedSurface.messenger);
      expect((treatRoute('/payment-methods') as Protected).category,
          ProtectedSurface.payment);
      expect((treatRoute('/settings/assistants') as Protected).category,
          ProtectedSurface.provider);
      expect((treatRoute('/installation/assistants') as Protected).category,
          ProtectedSurface.operator);
      expect((treatRoute('/settings/personal-info') as Protected).category,
          ProtectedSurface.identity);
      // #2142 — a member's page is the generic layer's: keys and the
      // app's own words only, never what the page shows.
      expect(treatRoute('/member/7'), isA<Unrecorded>());
      expect(treatRoute('/task-recorder'), isA<RecorderScreen>());
      expect(treatRoute('/settings'), isA<Unrecorded>());
      expect(treatRoute('/calendar'), isA<Unrecorded>());
      expect(treatRoute('/messagesX'), isA<Unrecorded>(),
          reason: 'a prefix is a path segment, not a string prefix');
    });
  });
}
