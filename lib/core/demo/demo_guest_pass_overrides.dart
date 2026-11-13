// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3308 — each Demo space sells its own guest passes: Pézenas a day pass
// (its network page says so), London day passes and a drop-in hour, New
// York by the hour (the owner's choice for the city). Leipzig carries a
// new space's defaults, so the passes are off there and it lists none.
import 'package:flutter_riverpod/misc.dart' show Override;

import '../../features/money/domain/guest_pass.dart';
import '../../features/money/providers/guest_pass_providers.dart';
import '../../features/workspace/domain/workspace_permission.dart';
import 'data/guest_pass_repository.dart';
import 'demo_fixture.dart';
import 'demo_space_pick.dart';

const _pezenasPasses = [
  GuestPassOffer(id: 'demo-pass-pezenas-day', name: 'Pass journée', unit: GuestPassUnit.day, priceCents: 1800),
];
const _londonPasses = [
  GuestPassOffer(id: 'demo-pass-london-day', name: 'Day pass', unit: GuestPassUnit.day, priceCents: 2500),
  GuestPassOffer(id: 'demo-pass-london-hour', name: 'Drop-in hour', unit: GuestPassUnit.hour, priceCents: 600),
];
const _newYorkPasses = [
  GuestPassOffer(id: 'demo-pass-ny-hour', name: 'Hourly pass', unit: GuestPassUnit.hour, priceCents: 900),
];

/// The persona's rights where the pass is sold, read when it is sold.
class _Rights {
  Set<WorkspacePermission> Function() held = () => const {};
  bool has(WorkspacePermission p) => held().contains(p);
}

/// One space's guest passes, kept on its stores for the session (#3846: a
/// switch of persona reaches the same sales), and the rights they are sold
/// under, set by whoever reads them.
class DemoGuestPasses {
  DemoGuestPasses._(this.repository, this._rights);

  final FakeGuestPassRepository repository;
  final _Rights _rights;

  /// The rights the persona holds, read when a pass is sold or priced.
  void heldBy(Set<WorkspacePermission> Function() rights) {
    _rights.held = rights;
  }
}

/// The passes the space [key] offers.
List<GuestPassOffer> _offers(DemoSpaceKey key) => switch (key) {
  DemoSpaceKey.home => _pezenasPasses,
  DemoSpaceKey.london => _londonPasses,
  DemoSpaceKey.newYork => _newYorkPasses,
  // Leipzig, the trade cities (#3832) and the twin sell none yet.
  DemoSpaceKey.leipzig ||
  DemoSpaceKey.zurich ||
  DemoSpaceKey.milan ||
  DemoSpaceKey.twin => const [],
};

/// The guest passes of the space [key] over the space's own parts.
DemoGuestPasses demoGuestPasses(DemoFixture fixture, DemoSpaceKey key) {
  final rights = _Rights();
  final parts = fixture.space(key);
  return DemoGuestPasses._(
    FakeGuestPassRepository(
      workspaceId: key.id,
      currency: key.currency,
      reservations: parts.reservations,
      workspaces: parts.workspaces,
      money: parts.money,
      now: () => fixture.seededAt,
      maySell: () => rights.has(WorkspacePermission.issueInvoices),
      mayPrice: () => rights.has(WorkspacePermission.manageServices),
      floorPlanSeats: () => parts.floorPlan.seats,
      offers: _offers(key),
    ),
    rights,
  );
}

List<Override> demoGuestPassOverrides(DemoFixture fixture) => [
  guestPassRepositoryProvider.overrideWith((ref) {
    final passes = fixture.stores.at(demoOpenSpace(ref)).guestPasses
      ..heldBy(() => ref.read(myPermissionsProvider).toSet());
    return passes.repository;
  }),
];
