// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Invariant: a device that never chose stores nothing — the default is
// decided by who uses it and on what (#2414) — and a pick, once made, is
// kept.
import 'package:deskilo/core/navigation/navigation_style.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('an unset device reads no choice; a stored choice wins', () async {
    SharedPreferences.setMockInitialValues({});
    const store = PrefsNavigationStyleStore();
    expect(await store.read(), isNull);
    await store.write('classic');
    expect(await store.read(), 'classic');
    await store.write(null);
    expect(
      await store.read(),
      isNull,
      reason: 'clearing returns to the default',
    );
  });
}
