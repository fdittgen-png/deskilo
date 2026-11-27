// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4466, #4454 -- the Demo business's till boards, in memory for the session: the ideaspark board at the front counter,
// paired, as its QR code reads (the board the firmware's host test pins). A code made in the Demo is given and
// withdrawn like the server's; no board presents it, so it connects nothing.
import 'package:meta/meta.dart' show visibleForTesting;

import '../../devices/device_board.dart';
import '../../devices/device_code.dart';

/// The QR code the Demo's till board shows (the tests scan it).
@visibleForTesting
const demoTillBoardQr =
    'deskilo-device:v1?id=11111111-1111-4111-8111-111111111111&board=ideaspark_st7789_v1&fw=1.0.3&fp=AB12-CD34'
    '&h=ab12cd3400000000000000000000000000000000000000000000000000000000';

class DemoTillBoards implements TillBoardPort {
  DemoTillBoards({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final _boards = <TillBoard>[];
  final _codes = <String, DateTime>{};
  var _next = 0;

  /// The front counter's board, paired.
  void seed() {
    final scanned = readDeviceCode(demoTillBoardQr);
    if (scanned is! DeviceCodeOk) return;
    _boards.add(TillBoard(
      id: 'demo-board-front',
      tillId: 'demo-till-front',
      tillName: 'Front counter',
      deviceId: scanned.code.id!,
      profile: scanned.code.profile,
      fingerprint: scanned.code.fingerprint!,
      firmware: scanned.code.firmware ?? '',
      status: TillBoardStatus.paired,
    ));
  }

  @override
  Future<List<TillBoard>> boards(String workspaceId) async => List.unmodifiable(_boards.reversed);

  @override
  Future<TillBoardCode> code(String workspaceId, String tillId, DeviceCode scanned) async {
    if (!scanned.connectable) throw const TillBoardRefused(TillBoardRefusal.proof);
    final id = 'demo-code-${_next++}';
    final expires = _now().add(const Duration(minutes: 5));
    _codes[id] = expires;
    const alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
    final digits = [for (var i = 0; i < 12; i++) alphabet[(id.hashCode >> (i % 6) * 5 ^ i * 7) & 31]].join();
    return TillBoardCode(
      id: id,
      code: '${digits.substring(0, 4)}-${digits.substring(4, 8)}-${digits.substring(8)}',
      expiresAt: expires,
    );
  }

  @override
  Future<bool> cancelCode(String codeId) async {
    final expires = _codes.remove(codeId);
    return expires != null && expires.isAfter(_now());
  }

  @override
  Future<void> approve(String boardId, String fingerprint) async {
    final i = _boards.indexWhere((b) => b.id == boardId);
    if (i < 0 || _boards[i].status != TillBoardStatus.pendingApproval) throw const TillBoardRefused(TillBoardRefusal.used);
    final b = _boards[i];
    if (fingerprint.trim().toUpperCase() != b.fingerprint) throw const TillBoardRefused(TillBoardRefusal.proof);
    _boards[i] = TillBoard(
      id: b.id,
      tillId: b.tillId,
      tillName: b.tillName,
      deviceId: b.deviceId,
      profile: b.profile,
      fingerprint: b.fingerprint,
      firmware: b.firmware,
      status: TillBoardStatus.paired,
    );
  }

  @override
  Future<bool> revoke(String boardId) async {
    final before = _boards.length;
    _boards.removeWhere((b) => b.id == boardId);
    return _boards.length < before;
  }
}
