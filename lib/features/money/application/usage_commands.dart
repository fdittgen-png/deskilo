// SPDX-License-Identifier: AGPL-3.0-or-later
import '../domain/usage_record.dart';

/// #2590 — what is sent to record a month's usage. Nothing is sent for a
/// period that is not a month (the server refuses it too).
class UsageCommands {
  const UsageCommands(this._preparation);

  final UsagePreparation _preparation;

  static final _month = RegExp(r'^[0-9]{4}-(0[1-9]|1[0-2])$');

  /// How many records were made, or null when nothing was sent.
  Future<int?> prepare(
    String workspaceId,
    String period,
    String requestId,
  ) async {
    if (!_month.hasMatch(period)) return null;
    return _preparation.prepare(workspaceId, period, requestId);
  }
}
