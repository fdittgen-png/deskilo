// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2573 — filing a member's receipt of several lines: save the draft, then
// send it to the expense validation, which files ONE expense of the whole
// amount. One filing per form: it remembers what it sent under which
// request ids, so a retry of the same entries replays instead of saving or
// filing twice, and changed entries update the saved draft at its revision.
import 'dart:convert';

import '../../../core/ids/request_id.dart';
import '../domain/purchase.dart';
import 'purchase_commands.dart';

class PurchaseReceiptFiling {
  PurchaseReceiptFiling(this._commands, this.workspaceId);

  final PurchaseCommands _commands;
  final String workspaceId;

  String? _attempted;
  String _saveRequestId = newRequestId();
  String? _savedEntries;
  ({String id, int revision})? _saved;
  String _submitRequestId = newRequestId();

  /// True once the receipt awaits its validation; false, nothing sent, when
  /// the entries cannot be a receipt. A refusal of the server propagates and
  /// keeps what was saved.
  Future<bool> file(PurchaseReceiptDraft entries) async {
    final key = jsonEncode(entries.toPayload());
    if (_saved == null || _savedEntries != key) {
      // Same entries: same id (a lost answer is replayed, not doubled).
      if (_attempted != key) _saveRequestId = newRequestId();
      _attempted = key;
      final previous = _saved;
      final id = await _commands.saveReceipt(
        workspaceId,
        _saveRequestId,
        previous == null
            ? entries
            : entries.savedAs(previous.id, previous.revision),
      );
      if (id == null) return false;
      _saved = (id: id, revision: (previous?.revision ?? 0) + 1);
      _savedEntries = key;
      _submitRequestId = newRequestId();
    }
    final saved = _saved!;
    await _commands.submitReceipt(
      workspaceId,
      saved.id,
      saved.revision,
      _submitRequestId,
    );
    return true;
  }
}
