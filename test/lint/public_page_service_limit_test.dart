// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4318 — the number of public services the public page carries has one
// source: the server's public_page_service_limit(). The app's mirror
// (publicPageServiceLimit) is pinned to the latest definition, and no public
// projection carries the services under a written-out limit.

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

void main() {
  final migrations = sqlFiles('supabase/migrations')
    ..sort((a, b) => a.path.compareTo(b.path));

  // The app's mirror is a row of mirrored_bounds_test (#4419).
  test('the public services projection reads the limit from its source', () {
    // The latest migration that touches public_workspace_offer's services
    // must not write the limit out.
    final offer = migrations.lastWhere((f) {
      final t = f.readAsStringSync();
      return t.contains('public_workspace_offer(uuid)') &&
          t.contains('sv.sort_order');
    });
    final text = offer.readAsStringSync();
    expect(text, contains('limit public.public_page_service_limit()'));
  });
}
