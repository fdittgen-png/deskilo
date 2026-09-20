// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1305 S3 — offline, the Reserve hub says its availability is saved,
// not live, and when it was saved; the banner leaves when a read succeeds.
import 'package:deskilo/core/cache/stale_reads.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'reserve_hub_test.dart' show pumpHub;

void main() {
  tearDown(StaleReads.instance.reset);

  testWidgets('stale availability is named, retried, and cleared',
      (tester) async {
    await pumpHub(tester);
    expect(find.byKey(const ValueKey('reserve-stale-banner')), findsNothing);

    StaleReads.instance.served('resv:ws-1:2026-09-17', DateTime.utc(2026, 9, 17, 7, 30));
    await tester.pumpAndSettle();
    final banner = find.byKey(const ValueKey('reserve-stale-banner'));
    expect(banner, findsOneWidget);
    expect(find.descendant(of: banner, matching: find.textContaining('Offline')),
        findsOneWidget);

    await tester.tap(find.descendant(of: banner, matching: find.text('Retry')));
    await tester.pumpAndSettle();

    StaleReads.instance.fresh('resv:ws-1:2026-09-18');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reserve-stale-banner')), findsNothing);
  });

  testWidgets('a stale floor plan alone does not claim availability is stale',
      (tester) async {
    await pumpHub(tester);
    StaleReads.instance.served('plan:level-1', DateTime.utc(2026, 9, 17));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reserve-stale-banner')), findsNothing);
  });
}
