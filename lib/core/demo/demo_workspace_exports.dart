// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2557 C3 — Demo's own-data export of each space, on its one fictional
// installation.
import '../../features/reservations/domain/reservation.dart'
    show reservationStatusToDb;
import 'data/workspace_export_repository.dart';
import 'demo_fixture.dart';
import 'seed/demo_london_seed.dart';
import 'seed/demo_new_york_seed.dart';
import 'seed/demo_second_space_seed.dart';
import 'seed/demo_twin_seed.dart';

/// #2557 C3 — each demo space's own-data export: the persona's membership
/// and own reservations of that space, as `export_my_data` shapes them.
FakeWorkspaceExportRepository demoWorkspaceExports(DemoFixture fixture) =>
    FakeWorkspaceExportRepository(
      document: (source) {
        // Each space exports its own bookings (#3302: the cities and the
        // twin answered with the main space's).
        final space = switch (source.workspaceId) {
          demoSecondSpaceId => fixture.secondSpace.reservations,
          demoLondonSpaceId => fixture.london.reservations,
          demoNewYorkSpaceId => fixture.newYork.reservations,
          demoTwinSpaceId => fixture.twin.reservations,
          _ => fixture.reservations,
        };
        final me = fixture.actor.memberId;
        return {
          'exported_at': fixture.seededAt.toUtc().toIso8601String(),
          'member': {'id': me, 'workspace_id': source.workspaceId},
          'reservations': [
            for (final r in space.reservations)
              if (r.memberId == me)
                {
                  'id': r.id,
                  'starts_at': r.startsAt.toUtc().toIso8601String(),
                  'ends_at': r.endsAt.toUtc().toIso8601String(),
                  'status': reservationStatusToDb(r.status),
                },
          ],
          'ledger': const <Object?>[],
          'invoices': const <Object?>[],
        };
      },
    );
