// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1619 — a high-impact action an assistant asked for, waiting for its
// human in the Deskilo app. The id in a link is not an authorisation: the
// server answers only the bound human, only from a native session.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
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
    this.askedAt,
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

  /// #3978 — when the assistant asked (the assistants page lists it).
  final DateTime? askedAt;

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
    askedAt: askedAt,
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
      status: ConfirmationStatus.fromWire(r.textOrAbsent('status')),
      operation: r.textOrAbsent('operation') ?? '',
      workspaceName: r.textOrAbsent('workspace_name') ?? '',
      clientName: r.textOrAbsent('client_name') ?? '',
      arguments: preview.objectOrAbsent('arguments').json,
      target: preview.objectOrAbsent('target').json,
      expiresAt:
          DateTime.tryParse(r.textOrAbsent('expires_at') ?? '')?.toUtc(),
      askedAt: DateTime.tryParse(r.textOrAbsent('created_at') ?? '')?.toUtc(),
    );
  }

  /// #3978 — this request with [status], everything else kept.
  ActionConfirmation withStatus(ConfirmationStatus status) =>
      ActionConfirmation(
        id: id,
        status: status,
        operation: operation,
        workspaceName: workspaceName,
        clientName: clientName,
        arguments: arguments,
        target: target,
        expiresAt: expiresAt,
        askedAt: askedAt,
        scope: scope,
      );
}

/// #3978 — how far back the assistants page lists the requests already
/// answered: the last days, enough to find what was just decided on
/// another device, without growing into a history.
const answeredRequestsShown = Duration(days: 7);

/// #3978 — the person's own requests, as the server lists them (newest
/// first). A status this version cannot read reads as unavailable, never
/// as waiting; a row without its id is no request.
List<ActionConfirmation> actionConfirmationsFromJson(Object? json) => [
  if (json is List)
    for (final row in json)
      if (row is Map && row['id'] is String)
        ActionConfirmation.fromJson(row['id']! as String, row),
];

abstract interface class ActionConfirmationRepository {
  Future<ActionConfirmation> get(String id);

  /// #3978 — every request waiting for the person and the ones asked since
  /// [answeredSince], newest first.
  Future<List<ActionConfirmation>> mine({required DateTime answeredSince});

  /// Confirms ([accept]) or declines; answers the resulting status.
  Future<ConfirmationStatus> respond(String id, {required bool accept});
}
