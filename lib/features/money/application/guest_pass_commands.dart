// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3308 — what the guest passes screen does: price a pass and sell one.
// The screen calls these; the repository stays behind them.
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
    required Map<String, dynamic> guest,
    required String requestId,
  }) =>
      _passes.sell(workspaceId, draft: draft, guest: guest, requestId: requestId);
}
