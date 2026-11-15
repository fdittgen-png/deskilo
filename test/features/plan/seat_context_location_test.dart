// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4054 — a booking's location line names each level once: the Demo's
// boardroom (a seat named as its room) reads "Boardroom", not "Boardroom ·
// Boardroom table · Boardroom".
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/seed/demo_resource_seed.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the Demo\'s boardroom is named once on its location line', () async {
    final fixture = DemoFixture.build();
    final place = await fixture.floorPlan.fetchSeatContext(
      DemoResources.boardroom,
    );
    final parts = place!.locationLine.split(' · ');
    expect(
      parts.where((p) => p == 'Boardroom'),
      hasLength(1),
      reason: '$parts',
    );
    expect(parts.toSet(), hasLength(parts.length), reason: 'no name twice');
    expect(parts, contains('Boardroom table'));
  });
}
