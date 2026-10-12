// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1619 — a high-impact action an assistant asked for, waiting for its
// human in the Deskilo app. The id in a link is not an authorisation: the
// server answers only the bound human, only from a native session.
import '../../../core/data/json_reader.dart';
import 'mcp_context.dart';

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
    this.scope,
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

  /// #1625 — the installation and account it was read from; the answer
  /// goes back there, whatever the app shows by then.
  final McpInstanceRef? scope;

  ActionConfirmation withScope(McpInstanceRef scope) => ActionConfirmation(
    id: id,
    status: status,
    operation: operation,
    workspaceName: workspaceName,
    clientName: clientName,
    arguments: arguments,
    target: target,
    expiresAt: expiresAt,
    scope: scope,
  );

  factory ActionConfirmation.fromJson(String id, Object? json) {
    if (json is! Map) {
      return ActionConfirmation(id: id, status: ConfirmationStatus.unavailable);
    }
    // Fail-closed (#2387): a malformed field reads as absent.
    final r = JsonReader.of(json, context: 'action_confirmation');
    final preview = r.objectOrAbsent('preview');
    return ActionConfirmation(
      id: id,
      status: ConfirmationStatus.fromWire(r.json['status']),
      operation: r.textOrAbsent('operation') ?? '',
      workspaceName: r.textOrAbsent('workspace_name') ?? '',
      clientName: r.textOrAbsent('client_name') ?? '',
      arguments: preview.objectOrAbsent('arguments').json,
      target: preview.objectOrAbsent('target').json,
      expiresAt:
          DateTime.tryParse(r.textOrAbsent('expires_at') ?? '')?.toUtc(),
    );
  }
}

abstract interface class ActionConfirmationRepository {
  Future<ActionConfirmation> get(String id);

  /// Confirms ([accept]) or declines; answers the resulting status.
  Future<ConfirmationStatus> respond(String id, {required bool accept});
}
