// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4318 — the number of public services the public page carries has one
// source: the server's public_page_service_limit(). The app's mirror
// (publicPageServiceLimit) is pinned to the latest definition, and no public
// projection carries the services under a written-out limit.

import 'package:deskilo/features/money/domain/public_page.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

void main() {
  final migrations = sqlFiles('supabase/migrations')
    ..sort((a, b) => a.path.compareTo(b.path));

  test('the app mirrors the server function', () {
    final definition = RegExp(
      r'function public\.public_page_service_limit\(\)[^$]*\$\$\s*select\s+(\d+)\s*\$\$',
    );
    int? latest;
    for (final f in migrations) {
      for (final m in definition.allMatches(f.readAsStringSync())) {
        latest = int.parse(m.group(1)!);
      }
    }
    expect(latest, isNotNull, reason: 'public_page_service_limit() is defined');
    expect(publicPageServiceLimit, latest);
  });

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
