// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1865 — the recorder's contract is finite and sound: every action,
// outcome and payload field is registered once, under a stable dotted
// identifier and a pinned contract version; a payload is a projection
// onto a finite vocabulary at capture time, so a private value has no
// field it could travel in.
import 'package:deskilo/features/task_recorder/domain/action_registry.dart';
import 'package:deskilo/features/task_recorder/domain/safe_payload.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/recording_fixtures.dart';

void main() {
  test('the registry has no structural problem', () {
    expect(recorderRegistry.problems(safeFields.keys.toSet()), isEmpty);
  });

  test('the contract version is pinned; identifiers are append-only', () {
    // Removing or renaming one is a contract change: bump the version,
    // keep the old id readable, regenerate the fixtures.
    expect(actionContractVersion, 1);
    expect(recorderRegistry.actions.map((a) => a.id), containsAll([
      'reservations.open_reserve',
      'reservations.select_date',
      'reservations.select_period',
      'reservations.switch_view',
      'reservations.select_resource',
      'reservations.change_booking_field',
      'reservations.confirm_booking',
      'reservations.cancel_review',
      'reservations.view_details',
      'navigation.back',
    ]));
    expect(recorderRegistry.outcomes.map((o) => o.id), containsAll([
      'booking.confirmed',
      'booking.requested',
      'booking.series_booked',
      'booking.refused',
      'booking.unknown',
    ]));
  });

  test('the problems check catches what it exists for', () {
    const broken = ActionRegistry(
      contractVersion: 1,
      surfaces: [RecorderSurface('a.b')],
      actions: [
        ActionSpec('a.go', surface: 'a.nowhere', kind: ActionKind.submit),
        ActionSpec('a.go', surface: 'a.b', kind: ActionKind.select,
            payloadFields: {'member_name'}, outcomes: {'a.done'}),
        ActionSpec('Bad Id', surface: 'a.b', kind: ActionKind.open),
      ],
      outcomes: [OutcomeSpec('a.never', state: ObservationState.attempted)],
      prerequisites: [],
    );
    final problems = broken.problems(safeFields.keys.toSet()).join('\n');
    expect(problems, contains('duplicate action a.go'));
    expect(problems, contains('unknown surface a.nowhere'));
    expect(problems, contains('a command needs outcomes'));
    expect(problems, contains('unknown payload field member_name'));
    expect(problems, contains('unknown outcome a.done'));
    expect(problems, contains('not dotted snake_case'));
    expect(problems, contains('never an attempt'));
  });

  test('only the recorder controls are recorder controls', () {
    expect(recorderRegistry.isRecorderControl(RecorderActions.recorderControl),
        isTrue);
    expect(recorderRegistry.isRecorderControl(RecorderActions.confirmBooking),
        isFalse);
  });

  group('safe payloads', () {
    test('undeclared keys are dropped, private values become the placeholder',
        () {
      final p = SafePayload.minimize(
          {'for_whom', 'repeat'}, canaryPayload({'repeat': 'once'}));
      expect(p.values, {'for_whom': withheldValue, 'repeat': 'once'});
      final text = p.toJson().toString();
      for (final c in privateCanaries) {
        expect(text.contains(c), isFalse, reason: c);
      }
    });

    test('a non-string value is withheld, never stringified', () {
      final p = SafePayload.minimize({'period'}, {'period': 42});
      expect(p.values, {'period': withheldValue});
    });

    test('every field is a finite category vocabulary', () {
      for (final field in safeFields.values) {
        expect(field.values, isNotEmpty, reason: field.key);
        expect(field.values.contains(withheldValue), isFalse, reason: field.key);
        for (final v in field.values) {
          expect(RegExp(r'^[a-z_]+$').hasMatch(v), isTrue, reason: v);
        }
      }
    });

    test('parse is strict: one stray key or value refuses the whole payload',
        () {
      expect(SafePayload.parse({'period'}, {'period': 'morning'})!.values,
          {'period': 'morning'});
      expect(SafePayload.parse({'period'}, {'period': withheldValue}),
          isNotNull);
      expect(SafePayload.parse({'period'}, {'period': 'at 9 with Zelda'}),
          isNull);
      expect(SafePayload.parse({'period'}, {'note': 'morning'}), isNull);
      expect(SafePayload.parse({'period'}, ['morning']), isNull);
      expect(SafePayload.parse({'period'}, null), SafePayload.empty);
    });
  });
}
