// SPDX-License-Identifier: AGPL-3.0-or-later

import '../data/json_reader.dart';

/// #982 — a request that a validation policy holds: the act did not
/// happen yet, a pending event carries it, and whoever the policy names
/// decides. Thrown by the repositories whose server function answered
/// `{pending: true}`; `runGuarded` turns it into one calm notice.
class PendingValidationException implements Exception {
  const PendingValidationException(this.eventId);

  final String eventId;

  @override
  String toString() => 'PendingValidationException($eventId)';
}

/// Reads a request function's answer that promises a result id: the id it
/// applied with, or throws [PendingValidationException] when the policy held
/// it.
///
/// #2585 — strict: the answer must be an object whose `pending` is a bool;
/// a held answer must carry a non-empty `event_id` and an applied one a
/// non-empty [idKey]. Anything else is a [JsonShapeException]: a missing id
/// never becomes `''`, and a decoding error says nothing about whether the
/// server committed, so callers must not resend the command on it.
String applyOrPending(Object? answer, {String idKey = 'invoice_id'}) {
  final reader = _outcome(answer);
  final id = reader.string(idKey);
  if (id.isEmpty) {
    throw JsonShapeException(reader.context, idKey, 'non-empty String', 'empty String');
  }
  return id;
}

/// Like [applyOrPending] for the commands whose applied answer promises no id
/// (`{pending: false}`): returns normally when applied, throws
/// [PendingValidationException] when held.
void applyOrPendingVoid(Object? answer) {
  _outcome(answer);
}

/// The reader of an applied answer; throws for a held one.
JsonReader _outcome(Object? answer) {
  final reader = JsonReader.of(answer, context: 'request_*');
  final pending = reader.raw('pending');
  if (pending is! bool) {
    throw JsonShapeException(
      reader.context,
      'pending',
      'bool',
      pending == null ? 'null' : pending.runtimeType.toString(),
    );
  }
  if (pending) {
    final eventId = reader.string('event_id');
    if (eventId.isEmpty) {
      throw JsonShapeException(reader.context, 'event_id', 'non-empty String', 'empty String');
    }
    throw PendingValidationException(eventId);
  }
  return reader;
}
