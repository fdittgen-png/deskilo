// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4367 -- the cash drawer's commands: each is one call to the server and what it makes stale. A screen reads the drawer, a sheet
// asks for a command; the sheet never resolves a repository or an invalidation itself, so the operation is the same wherever it is
// asked from (a test replaces the port, nothing else).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/cash_reason.dart';
import '../domain/till_drawer.dart';
import '../providers/till_drawer_providers.dart';

class TillDrawerCommands {
  TillDrawerCommands(this._ref, {required this.workspaceId});

  final Ref _ref;
  final String workspaceId;

  TillDrawerPort get _port => _ref.read(tillDrawerPortProvider);

  /// A new till (null [tillId]) or the edit of one.
  Future<DrawerTill> saveTill({required String requestId, String? tillId, required String name, String? siteId, required bool active}) async {
    final till = await _port.saveTill(workspaceId, requestId: requestId, tillId: tillId, name: name, siteId: siteId, active: active);
    _ref.invalidate(tillDrawerProvider(workspaceId));
    return till;
  }

  /// #4511 -- the notes and coins a till's drawer carries; empty is every current one of the currency.
  Future<List<int>?> setTillDenominations({required String tillId, required List<int> values}) async {
    final picked = await _port.setTillDenominations(workspaceId, tillId: tillId, values: values);
    _ref.invalidate(tillDrawerProvider(workspaceId));
    return picked;
  }

  /// #4514 -- a new reason of the business's own (null [code]) or the edit of one.
  Future<CashReason> saveCashReason({String? code, required String name, required Set<CashReasonProcess> processes, bool? archived}) async {
    final saved = await _port.saveCashReason(workspaceId, code: code, name: name, processes: processes, archived: archived);
    _ref.invalidate(cashReasonsProvider(workspaceId));
    return saved;
  }

  Future<DrawerOpened> openSession({required String requestId, required String tillId, required int floatMinor, Denominations? denominations}) async {
    final opened = await _port.openSession(workspaceId, requestId: requestId, tillId: tillId, floatMinor: floatMinor, denominations: denominations);
    _ref.invalidate(tillDrawerProvider(workspaceId));
    return opened;
  }

  Future<DrawerEntryMade> cashEntry({required String requestId, required String sessionId, required DrawerEntry entry}) async {
    final made = await _port.cashEntry(workspaceId, requestId: requestId, sessionId: sessionId, entry: entry);
    _ref
      ..invalidate(drawerExpectedProvider)
      ..invalidate(tillDrawerProvider(workspaceId));
    return made;
  }

  Future<DrawerClosed> closeSession({required String requestId, required String sessionId, required DrawerCount count}) async {
    final closed = await _port.closeSession(workspaceId, requestId: requestId, sessionId: sessionId, count: count);
    _ref
      ..invalidate(drawerExpectedProvider)
      ..invalidate(tillDrawerProvider(workspaceId));
    return closed;
  }
}

/// The drawer's commands for one business.
final tillDrawerCommandsProvider = Provider.family<TillDrawerCommands, String>((ref, workspaceId) => TillDrawerCommands(ref, workspaceId: workspaceId));
