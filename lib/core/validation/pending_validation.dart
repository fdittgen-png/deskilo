// SPDX-License-Identifier: 0BSD

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

/// Reads a request function's answer: the id it applied with, or throws
/// [PendingValidationException] when the policy held it.
String applyOrPending(Map<dynamic, dynamic> answer, {String idKey = 'invoice_id'}) {
  if (answer['pending'] == true) {
    throw PendingValidationException('${answer['event_id'] ?? ''}');
  }
  return '${answer[idKey] ?? ''}';
}
