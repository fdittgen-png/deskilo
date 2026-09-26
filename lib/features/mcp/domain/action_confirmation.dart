// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1619 — a high-impact action an assistant asked for, waiting for its
// human in the Deskilo app. The id in a link is not an authorisation: the
// server answers only the bound human, only from a native session.

enum ConfirmationStatus {
  pending,
  acknowledged,
  consumed,
  declined,
  expired,
  revoked,
  targetChanged,
  notFound,

  /// The server could not be asked, or answered something unreadable.
  unavailable;

  static ConfirmationStatus fromWire(Object? raw) => switch (raw) {
    'pending' => pending,
    'acknowledged' => acknowledged,
    'consumed' => consumed,
    'declined' => declined,
    'expired' => expired,
    'revoked' => revoked,
    'target_changed' => targetChanged,
    'not_found' => notFound,
    _ => unavailable,
  };

  /// Only a pending confirmation can be answered.
  bool get answerable => this == pending;
}

class ActionConfirmation {
  const ActionConfirmation({
    required this.id,
    required this.status,
    this.operation = '',
    this.workspaceName = '',
    this.clientName = '',
    this.arguments = const {},
    this.target = const {},
    this.expiresAt,
  });

  final String id;
  final ConfirmationStatus status;

  /// The contract operation id (`request_refund`, …).
  final String operation;
  final String workspaceName;

  /// The assistant that asked.
  final String clientName;
  final Map<String, Object?> arguments;

  /// What the action is about, as the server read it: an invoice (number,
  /// total, currency, period), a member (name, status, share) or an event.
  final Map<String, Object?> target;
  final DateTime? expiresAt;

  factory ActionConfirmation.fromJson(String id, Object? json) {
    if (json is! Map) {
      return ActionConfirmation(id: id, status: ConfirmationStatus.unavailable);
    }
    final status = ConfirmationStatus.fromWire(json['status']);
    final preview = json['preview'] is Map
        ? json['preview'] as Map
        : const <Object?, Object?>{};
    Map<String, Object?> map(Object? v) =>
        v is Map ? {for (final e in v.entries) '${e.key}': e.value} : const {};
    return ActionConfirmation(
      id: id,
      status: status,
      operation: '${json['operation'] ?? ''}',
      workspaceName: '${json['workspace_name'] ?? ''}',
      clientName: '${json['client_name'] ?? ''}',
      arguments: map(preview['arguments']),
      target: map(preview['target']),
      expiresAt: DateTime.tryParse('${json['expires_at']}')?.toUtc(),
    );
  }
}

abstract interface class ActionConfirmationRepository {
  Future<ActionConfirmation> get(String id);

  /// Confirms ([accept]) or declines; answers the resulting status.
  Future<ConfirmationStatus> respond(String id, {required bool accept});
}
