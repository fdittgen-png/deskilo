// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Invariant: the hamburger menu is what a device gets until its person picks
// the classic bar — and the pick, once made, is kept.
import 'package:deskilo/core/navigation/navigation_style.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('an unset device reads the menu; a stored choice wins', () async {
    SharedPreferences.setMockInitialValues({});
    const store = PrefsNavigationStyleStore();
    expect(await store.read(), 'menu');
    await store.write('classic');
    expect(await store.read(), 'classic');
    await store.write(null);
    expect(
      await store.read(),
      'menu',
      reason: 'clearing returns to the default',
    );
  });
}
