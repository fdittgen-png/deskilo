// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4454 -- a till board of the business, as the server keeps it (till_terminals_v1, migration 0984): which till it
// serves, which board it is, and whether it waits for the owner's approval or is paired. The code that connects a
// board, given once. The port the Devices page reads and acts through.
import 'package:meta/meta.dart' show immutable;

import '../failure/app_failure.dart' show TypedRefusal;
import 'device_code.dart';

enum TillBoardStatus {
  pendingApproval('pending_approval'),
  paired('paired');

  const TillBoardStatus(this.wire);
  final String wire;

  static TillBoardStatus? of(String? wire) => values.where((s) => s.wire == wire).firstOrNull;
}

@immutable
class TillBoard {
  const TillBoard({
    required this.id,
    required this.tillId,
    required this.tillName,
    required this.deviceId,
    required this.profile,
    required this.fingerprint,
    required this.firmware,
    required this.status,
  });

  final String id;
  final String tillId;
  final String tillName;
  final String deviceId;

  /// Null for a profile this app does not know (a newer board): shown by its id only.
  final BoardProfile? profile;
  final String fingerprint;
  final String firmware;
  final TillBoardStatus status;

  /// The first eight characters of the board's id, as its code and its screen show them.
  String get shortId => deviceId.substring(0, 8).toUpperCase();
}

/// The code the owner gives a board: valid until [expiresAt], once.
@immutable
class TillBoardCode {
  const TillBoardCode({required this.id, required this.code, required this.expiresAt});

  final String id;
  final String code;
  final DateTime expiresAt;
}

/// Why the server refused a board command, in the contract's words.
enum TillBoardRefusal { notAllowed, scope, proof, used }

class TillBoardRefused implements TypedRefusal {
  const TillBoardRefused(this.reason);
  final TillBoardRefusal reason;

  @override
  String toString() => 'TillBoardRefused($reason)';
}

abstract interface class TillBoardPort {
  /// The boards waiting or paired, newest first.
  Future<List<TillBoard>> boards(String workspaceId);

  /// A code for the board [scanned] names (its id and its secret's hash, read from its QR code), for [tillId].
  Future<TillBoardCode> code(String workspaceId, String tillId, DeviceCode scanned);

  /// Withdraws a code not yet used; false when it was used or had expired.
  Future<bool> cancelCode(String codeId);

  /// Approves a waiting board when [fingerprint] is the one it shows.
  Future<void> approve(String boardId, String fingerprint);

  /// Revokes a board; false when it was revoked already.
  Future<bool> revoke(String boardId);
}
