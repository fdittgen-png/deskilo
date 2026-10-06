// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1865 — the shared task-recording fixtures and private-data canaries.
//
// Every consumer of the recording schema (#1866 Word, #1867 guided
// tasks, #1872 packages, #1876 storyboard) tests against
// THESE recordings, never a copy: the JSON files beside this one are
// produced by driving the real RecorderController through the booking
// journeys below, and recording_fixtures_test.dart fails when the
// controller and the files disagree.
//
// The canaries are synthetic. Each is fed into the recorder at the
// capture boundary — in declared payload fields, in undeclared ones, as
// targets, as titles — and every later stage (store bytes, recovery,
// export, logs, package, document, video, support bundle) asserts that
// none of them came out the other side.
import 'dart:io';

import 'package:deskilo/features/task_recorder/application/recorder_controller.dart';
import 'package:deskilo/features/task_recorder/data/recorder_store.dart';
import 'package:deskilo/features/task_recorder/domain/action_registry.dart';
import 'package:deskilo/features/task_recorder/domain/recording_sink.dart';
import 'package:deskilo/features/task_recorder/domain/safe_payload.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording.dart';

/// Synthetic private values. None of them may ever leave the capture
/// boundary.
const kCanaryPassword = 'CANARY-password-7f3a91';
const kCanaryOtp = 'CANARY-otp-482913';
const kCanaryBadgeCode = 'CANARY-badge-04A1B2C3D4';
const kCanaryMemberName = 'CANARY-Member-Zelda-Quixote';
const kCanaryEmail = 'canary.zelda@canary-mail.invalid';
const kCanaryMessage = 'CANARY-message-body-secret-plans';
const kCanaryIban = 'FR76CANARY0000000000000000';
const kCanaryReservationId = 'c4a2f9e0-cana-4ary-9999-000000000001';
const kCanaryWorkspaceId = 'c4a2f9e0-cana-4ary-9999-000000000002';
const kCanaryUserId = 'c4a2f9e0-cana-4ary-9999-000000000003';
const kCanaryToken = 'eyJhbGciOiJDQU5BUlkifQ.canary.token';
const kCanaryUrl = 'https://canary.invalid/r?token=CANARY-query';

const List<String> privateCanaries = [
  kCanaryPassword,
  kCanaryOtp,
  kCanaryBadgeCode,
  kCanaryMemberName,
  kCanaryEmail,
  kCanaryMessage,
  kCanaryIban,
  kCanaryReservationId,
  kCanaryWorkspaceId,
  kCanaryUserId,
  kCanaryToken,
  kCanaryUrl,
];

/// Fragments that must not appear either: a canary split or lower-cased
/// by some transformation is still a leak.
const List<String> canaryFragments = ['canary', 'CANARY', 'Zelda'];

/// A raw payload as a careless call site might pass it: the right keys
/// with private values, and private keys nobody declared.
Map<String, Object?> canaryPayload([Map<String, Object?> legit = const {}]) => {
      for (final c in privateCanaries) 'x_$c': c,
      'member_name': kCanaryMemberName,
      'reservation_id': kCanaryReservationId,
      'workspace_id': kCanaryWorkspaceId,
      'password': kCanaryPassword,
      'note': kCanaryMessage,
      // Every declared field, with a private value in it.
      for (final key in safeFields.keys) key: kCanaryMemberName,
      ...legit,
    };

/// The scope the canary journeys are recorded in.
final RecorderScope canaryScope = RecorderScope.of(
  backendUrl: kCanaryUrl,
  userId: kCanaryUserId,
  workspaceId: kCanaryWorkspaceId,
);

final String canaryNamespace = RecorderScope.accountNamespace(
    backendUrl: kCanaryUrl, userId: kCanaryUserId);

/// A clock the journeys advance by hand: 400 ms per step.
class StepClock {
  int ms = 0;
  int call() => ms;
  void tick([int by = 400]) => ms += by;
}

/// A controller over [store] with a deterministic clock and ids.
RecorderController fixtureController(RecordingSink store, StepClock clock,
        {RecordingLimits limits = const RecordingLimits()}) =>
    RecorderController(
      sink: store,
      platform: RecordingPlatform.android,
      clock: clock.call,
      limits: limits,
      newId: () => '0123456789abcdef0123456789abcdef',
    );

/// The four booking journeys of #1865's acceptance.
enum BookingJourney {
  /// Plan, confirmed and checked in, then the details, then back.
  planConfirmed('booking_plan_confirmed'),

  /// List, refused by the server (a conflict).
  listRefused('booking_list_refused'),

  /// The review sheet opened and cancelled; nothing was booked.
  cancelledReview('booking_cancelled_review'),

  /// Confirmed, and the answer never came: outcome unknown.
  unknownOutcome('booking_unknown_outcome');

  const BookingJourney(this.file);
  final String file;
}

/// Drives [c] through [journey] with canaries at every boundary.
Future<TaskRecording> recordJourney(
    RecorderController c, StepClock clock, BookingJourney journey) async {
  final started = await c.start(
    scope: canaryScope,
    title: 'Book a desk',
    prerequisites: const [
      Prerequisite('signed_in'),
      Prerequisite('starts_on', value: RecorderSurfaces.reserve),
    ],
  );
  if (!started) throw StateError('fixture recording did not start');
  final list = journey == BookingJourney.listRefused;
  void step(String action,
      {String? target, Map<String, Object?> legit = const {}}) {
    clock.tick();
    c.record(action, target: target, payload: canaryPayload(legit));
  }

  step(RecorderActions.openReserve);
  step(RecorderActions.selectDate, legit: {'date_relation': 'tomorrow'});
  step(RecorderActions.selectPeriod, legit: {'period': 'morning'});
  if (list) step(RecorderActions.switchView, legit: {'view_mode': 'list'});
  step(RecorderActions.selectResource,
      legit: {'view_mode': list ? 'list' : 'plan', 'resource_kind': 'desk'});
  step(RecorderActions.changeBookingField, target: 'check_in');
  step(RecorderActions.changeBookingField, target: 'check_in'); // coalesces
  if (journey == BookingJourney.cancelledReview) {
    step(RecorderActions.cancelReview);
    clock.tick();
    c.annotate('I only wanted to look.');
  } else {
    clock.tick();
    final token = c.attempt(RecorderActions.confirmBooking,
        payload: canaryPayload(
            {'for_whom': 'self', 'repeat': 'once', 'check_in': 'yes'}));
    clock.tick(900);
    switch (journey) {
      case BookingJourney.planConfirmed:
        c.outcome(token, RecorderOutcomes.bookingConfirmed,
            payload: canaryPayload({'check_in': 'yes'}));
        step(RecorderActions.viewDetails);
        step(RecorderActions.back);
      case BookingJourney.listRefused:
        c.outcome(token, RecorderOutcomes.bookingRefused,
            payload: canaryPayload({'refusal': 'conflict'}));
      case BookingJourney.unknownOutcome:
        c.outcome(token, RecorderOutcomes.bookingUnknown,
            payload: canaryPayload());
      case BookingJourney.cancelledReview:
        break;
    }
  }
  clock.tick();
  return (await c.stop())!;
}

/// Records [journey] into a fresh in-memory store.
Future<({TaskRecording recording, MemoryRecorderLogBackend backend})>
    recordFixture(BookingJourney journey) async {
  final backend = MemoryRecorderLogBackend();
  final store = RecorderStore(backend: backend, namespace: canaryNamespace);
  final clock = StepClock();
  final c = fixtureController(store, clock);
  final recording = await recordJourney(c, clock, journey);
  await c.dispose();
  return (recording: recording, backend: backend);
}

/// The directory the JSON fixtures live in.
final Directory fixturesDir =
    Directory('test/features/task_recorder/fixtures');

/// One committed JSON fixture's text.
String fixtureText(String name) =>
    File('${fixturesDir.path}/$name.json').readAsStringSync();
