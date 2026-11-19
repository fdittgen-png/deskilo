// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo/features/directory/presentation/discovery_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Finds a comparison card or list control even when it is lazily built.
/// Used for content checks, not for tests of retained scroll position.
Future<void> revealDirectoryItem(WidgetTester tester, Finder target) async {
  final body = find.byType(DiscoveryListView);
  final list = find.descendant(of: body, matching: find.byType(ListView));
  tester.widget<ListView>(list).controller!.jumpTo(0);
  await tester.pump();
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find
        .descendant(of: body, matching: find.byType(Scrollable))
        .first,
  );
  await tester.pump();
}
