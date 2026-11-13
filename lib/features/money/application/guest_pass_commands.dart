// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3308 — what the guest passes screen does: price a pass and sell one;
// #3829 — revoke one.
// The screen calls these; the repository stays behind them.
import '../../../core/ids/request_id.dart';
import '../../../core/trace/trace_logger.dart';
import '../domain/guest_pass.dart';

class GuestPassCommands {
  const GuestPassCommands(this._passes);

  final GuestPassRepository _passes;

  Future<String> saveOffer(
    String workspaceId, {
    String? id,
    required String name,
    required GuestPassUnit unit,
    required int priceCents,
    String? vatRateId,
    bool active = true,
  }) =>
      _passes.saveOffer(
        workspaceId,
        id: id,
        name: name,
        unit: unit,
        priceCents: priceCents,
        vatRateId: vatRateId,
        active: active,
      );

  Future<GuestPassSale> sell(
    String workspaceId, {
    required GuestPassDraft draft,
    required Map<String, Object?> guest,
    required String requestId,
  }) =>
      _passes.sell(workspaceId, draft: draft, guest: guest, requestId: requestId);

  /// #3829 — revokes one pass; how many bookings were cancelled.
  Future<int> revoke(
    String workspaceId, {
    required String passId,
    required String requestId,
  }) =>
      _passes.revoke(workspaceId, passId: passId, requestId: requestId);

  /// #3829 — revokes [passIds] one after another, each with its own request
  /// id: per pass, the bookings it cancelled, or why it was refused (the
  /// others go on).
  Future<List<GuestPassRevokeOutcome>> revokeEach(
    String workspaceId,
    List<String> passIds,
  ) async {
    final out = <GuestPassRevokeOutcome>[];
    for (final id in passIds) {
      try {
        final cancelled = await revoke(workspaceId, passId: id, requestId: newRequestId());
        out.add((passId: id, cancelled: cancelled, error: null));
      } on Object catch (e, st) {
        TraceLogger.instance.warn('money', 'guest pass not revoked', error: e, stackTrace: st);
        out.add((passId: id, cancelled: null, error: e));
      }
    }
    return out;
  }
}

/// #3829 — one pass's revocation: what it cancelled, or why it was refused.
typedef GuestPassRevokeOutcome = ({String passId, int? cancelled, Object? error});
