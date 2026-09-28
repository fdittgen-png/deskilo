// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1801 — the MCP answer envelope, read the way the contract defines it:
// schema version 1, a known status, and pending never mistaken for done.
// Anything else is refused rather than guessed at.
import 'mcp_operations.dart';

class McpEnvelopeView {
  const McpEnvelopeView._({
    required this.status,
    required this.operation,
    required this.requestId,
    this.eventId,
    this.data = const {},
    this.errorCode,
  });

  final String status;
  final String operation;
  final String requestId;
  final String? eventId;
  final Map<String, Object?> data;
  final String? errorCode;

  /// The effect happened.
  bool get completed => status == 'completed';

  /// Recorded, but the people the workspace named still have to decide:
  /// NOT an effect.
  bool get pendingValidation => status == 'pending_validation';

  /// Waiting for the person to confirm in the Deskilo app.
  bool get needsConfirmation => status == 'requires_confirmation';

  /// Parses [json]; throws [FormatException] for an unknown schema
  /// version, an unknown status or a missing required field.
  static McpEnvelopeView parse(Map<String, Object?> json) {
    if (json['schema_version'] != 1) {
      throw FormatException(
        'unsupported MCP envelope version ${json['schema_version']}',
      );
    }
    final status = json['status'];
    if (status is! String || !mcpStatuses.contains(status)) {
      throw FormatException('unknown MCP status $status');
    }
    final operation = json['operation'];
    final requestId = json['request_id'];
    if (operation is! String || requestId is! String) {
      throw const FormatException(
        'an MCP envelope names its operation and request',
      );
    }
    final error = json['error'];
    return McpEnvelopeView._(
      status: status,
      operation: operation,
      requestId: requestId,
      eventId: json['event_id'] as String?,
      data: json['data'] is Map
          ? Map<String, Object?>.from(json['data'] as Map)
          : const {},
      errorCode: error is Map ? error['code'] as String? : null,
    );
  }
}
