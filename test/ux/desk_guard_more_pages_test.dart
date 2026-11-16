// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4077 -- the desk walk (test/ux/desk_walk_kit.dart) on the routes the first
// list left out (deskWalkMorePages of test/ux/walked_routes.dart): the owner
// at the four desk sizes, a member and an administrator at 1440 and 390. No
// sheet is written; the pictures are those of desk_guard_pages_test.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'desk_walk_kit.dart';
import 'experience_guards.dart';
import 'walked_routes.dart';

void main() {
  setUpAll(() => loadSheetFonts(always: true));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  runDeskWalk(deskWalkMorePages, pictures: false);
}
