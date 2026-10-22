// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2578 — a drill-through carries the period of the figure it came from.
import 'package:deskilo/features/money/domain/workspace_status.dart';
import 'package:deskilo/features/money/presentation/screens/workspace_status_screen.dart';
import 'package:deskilo/features/workspace/domain/bi_modules.dart';
import 'package:deskilo/features/workspace/domain/bi_query.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

const _finance = BiDrill(
  route: '/money/status',
  permission: WorkspacePermission.viewFinances,
  carriesPeriod: true,
);

void main() {
  group('BiDrill.target', () {
    test('a month opens that month', () {
      expect(
        _finance.target(const BiPeriod(BiGrain.month, 2026, 3)),
        '/money/status?from=2026-03&to=2026-03',
      );
    });

    test('a quarter opens its three months, across no year', () {
      expect(
        _finance.target(const BiPeriod(BiGrain.quarter, 2026, 4)),
        '/money/status?from=2026-10&to=2026-12',
      );
    });

    test('a year opens January to December', () {
      expect(
        _finance.target(const BiPeriod(BiGrain.year, 2025, 1)),
        '/money/status?from=2025-01&to=2025-12',
      );
    });

    test('a drill that does not carry a period stays the bare route', () {
      const plain = BiDrill(
        route: '/availability',
        permission: WorkspacePermission.workspaceSettings,
      );
      expect(
        plain.target(const BiPeriod(BiGrain.month, 2026, 3)),
        '/availability',
      );
    });

    test('the finance modules and the capacity figure carry a period', () {
      final carrying = {
        for (final m in biModules)
          if (m.drill?.carriesPeriod ?? false) m.id,
      };
      expect(carrying, {
        'finance.invoiced',
        'finance.collected',
        'capacity.seat_utilisation',
      });
    });
  });

  group('the money report opened from a figure', () {
    Future<void> pump(WidgetTester tester, {String? from, String? to}) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: standardTestOverrides(
            money: FakeMoneyRepository()
              ..status = const WorkspaceStatus(
                from: '2026-07',
                to: '2026-09',
                currency: 'EUR',
                          ),
            workspace: FakeWorkspaceRepository.withWorkspace(),
          ),
          child: MaterialApp(
            home: WorkspaceStatusScreen(from: from, to: to),
          ),
        ),
      );
      await tester.pump();
    }

    String? chosen(WidgetTester tester, String key) => tester
        .widget<DropdownButtonFormField<String>>(find.byKey(ValueKey(key)))
        .initialValue;

    testWidgets('the months of the figure are the months shown', (
      tester,
    ) async {
      await pump(tester, from: '2026-01', to: '2026-03');
      expect(chosen(tester, 'status-from'), '2026-01');
      expect(chosen(tester, 'status-to'), '2026-03');
    });

    testWidgets('a reversed pair is put in order', (tester) async {
      await pump(tester, from: '2026-03', to: '2026-01');
      expect(chosen(tester, 'status-from'), '2026-01');
      expect(chosen(tester, 'status-to'), '2026-03');
    });

    testWidgets('a month the screen does not offer falls back to its default', (
      tester,
    ) async {
      await pump(tester, from: '1999-01', to: 'junk');
      expect(chosen(tester, 'status-from'), isNot('1999-01'));
      expect(chosen(tester, 'status-to'), isNot('junk'));
    });
  });
}
