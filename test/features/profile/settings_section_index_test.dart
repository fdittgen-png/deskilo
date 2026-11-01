// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3068 — the section index of Settings marks the section the reader is in
// as the page scrolls, and the pinned bar never covers the content.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/screens/settings_sections.dart' show pumpSettingsAs;

bool _marked(WidgetTester tester, String id) => tester
    .widget<TextButton>(find.byKey(ValueKey('settings-link-$id')))
    .style!
    .backgroundColor !=
    null;

void main() {
  testWidgets('the index follows the scroll and sits above the content',
      (tester) async {
    await pumpSettingsAs(tester,
        isAdmin: false, isOwner: false, size: const Size(800, 500));
    expect(_marked(tester, 'account'), isTrue);
    expect(_marked(tester, 'advanced'), isFalse);

    // The bar is a sibling above the scroll area: nothing scrolls under it.
    final bar = tester.getRect(find.byKey(const ValueKey('settings-link-account')));
    final scroll = tester.getRect(find
        .byKey(const PageStorageKey('settings-personal')));
    expect(bar.bottom, lessThanOrEqualTo(scroll.top));

    await tester.drag(
        find.byKey(const PageStorageKey('settings-personal')),
        const Offset(0, -6000));
    await tester.pumpAndSettle();
    expect(_marked(tester, 'advanced'), isTrue);
    expect(_marked(tester, 'account'), isFalse);
  });
}
