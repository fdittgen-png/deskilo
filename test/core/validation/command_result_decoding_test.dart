// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2585 — a command answer is decoded by its discriminator: pending needs an
// event id, applied needs the promised result id, and a missing id never
// becomes ''.
import 'package:deskilo/core/data/json_reader.dart';
import 'package:deskilo/core/validation/pending_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final shape = throwsA(isA<JsonShapeException>());

  group('applyOrPending (a command that promises an id)', () {
    test('applied with a valid id returns it', () {
      expect(applyOrPending({'pending': false, 'invoice_id': 'inv-1'}), 'inv-1');
      expect(
        applyOrPending({'pending': false, 'x': 'abc'}, idKey: 'x'),
        'abc',
      );
    });

    test('pending with an event id stays pending, not a failure', () {
      expect(
        () => applyOrPending({'pending': true, 'event_id': 'ev-9'}),
        throwsA(isA<PendingValidationException>()
            .having((e) => e.eventId, 'eventId', 'ev-9')),
      );
    });

    test('applied without, with an empty or with a wrong-type id refuses', () {
      expect(() => applyOrPending({'pending': false}), shape);
      expect(() => applyOrPending({'pending': false, 'invoice_id': ''}), shape);
      expect(() => applyOrPending({'pending': false, 'invoice_id': 7}), shape);
      expect(() => applyOrPending({'pending': false, 'invoice_id': null}), shape);
    });

    test('pending without, with an empty or with a wrong-type event id refuses',
        () {
      expect(() => applyOrPending({'pending': true}), shape);
      expect(() => applyOrPending({'pending': true, 'event_id': ''}), shape);
      expect(() => applyOrPending({'pending': true, 'event_id': 3}), shape);
    });

    test('an unknown discriminator or a non-object is a protocol failure', () {
      expect(() => applyOrPending({'invoice_id': 'inv-1'}), shape);
      expect(() => applyOrPending({'pending': 'false', 'invoice_id': 'a'}), shape);
      expect(() => applyOrPending({'pending': null, 'invoice_id': 'a'}), shape);
      expect(() => applyOrPending(null), shape);
      expect(() => applyOrPending('ok'), shape);
      expect(() => applyOrPending(<Object?>[]), shape);
    });
  });

  group('applyOrPendingVoid (a documented void success)', () {
    test('applied {pending: false} succeeds with no id', () {
      expect(() => applyOrPendingVoid({'pending': false}), returnsNormally);
    });

    test('pending needs its event id', () {
      expect(
        () => applyOrPendingVoid({'pending': true, 'event_id': 'ev-2'}),
        throwsA(isA<PendingValidationException>()),
      );
      expect(() => applyOrPendingVoid({'pending': true}), shape);
      expect(() => applyOrPendingVoid({'pending': true, 'event_id': ''}), shape);
    });

    test('an empty or unknown answer is not a success', () {
      expect(() => applyOrPendingVoid(<String, Object?>{}), shape);
      expect(() => applyOrPendingVoid(null), shape);
      expect(() => applyOrPendingVoid({'pending': 1}), shape);
    });
  });
}
