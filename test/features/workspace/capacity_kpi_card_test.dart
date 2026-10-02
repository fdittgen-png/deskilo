// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1918 C — the seat-utilisation tile on the Availability screen: the
// value with its numerator and denominator, the explanation on demand,
// undefined shown as undefined, a refusal and a failure each said as
// such, and a month change asking the server for that month.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:deskilo/features/workspace/providers/kpi_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

class _FakeKpis implements KpiRepository {
  _FakeKpis(this.answer);

  /// What the next call returns, or throws.
  FutureOr<SeatCapacityKpi> Function() answer;
  final calls = <({DateTime from, DateTime to})>[];

  @override
  Future<SeatCapacityKpi> seatCapacity(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
    String? levelId,
  }) async {
    calls.add((from: from, to: to));
    return answer();
  }
}

SeatCapacityKpi _kpi({double offered = 76, double reserved = 10}) =>
    seatCapacityFromJson({
      'from': '2026-10-01T00:00:00Z',
      'to': '2026-11-01T00:00:00Z',
      'seats': 10,
      'physical_seat_hours': 80,
      'offered_seat_hours': offered,
      'reserved_seat_hours': reserved,
      'reserved_outside_offered_seat_hours': 1,
      'quality': offered == 0 ? ['not_applicable'] : <String>[],
      'reasons': const <String>[],
      'computed_at': '2026-10-01T10:00:00Z',
    });

Future<FakeWorkspaceRepository> _open(
  WidgetTester tester,
  _FakeKpis kpis, {
  bool on = true,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 3200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final workspace = FakeWorkspaceRepository.withWorkspace(
    featureFlags: {'capacityKpi': on},
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(workspace: workspace),
        kpiRepositoryProvider.overrideWithValue(kpis),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  final context = tester.element(find.byType(Scaffold).first);
  unawaited(GoRouter.of(context).push('/availability'));
  await tester.pumpAndSettle();
  final card = find.byKey(const ValueKey('capacity-kpi-card'));
  if (card.evaluate().isNotEmpty) {
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
  }
  return workspace;
}

const _value = ValueKey('capacity-kpi-value');

void main() {
  testWidgets('off: no tile and no request', (tester) async {
    final kpis = _FakeKpis(_kpi);
    await _open(tester, kpis, on: false);
    expect(find.byKey(const ValueKey('capacity-kpi-card')), findsNothing);
    expect(kpis.calls, isEmpty);
  });

  testWidgets('the value, its counts and the explanation on demand; reading '
      'writes nothing', (tester) async {
    final kpis = _FakeKpis(_kpi);
    final workspace = await _open(tester, kpis);
    expect(tester.widget<Text>(find.byKey(_value)).data, '13.2%');
    expect(find.text('10.0 of 76.0 seat-hours reserved'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('capacity-kpi-explain')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Physical capacity: 80.0'), findsOneWidget);
    expect(find.textContaining('not in the ratio'), findsOneWidget);
    expect(workspace.flagWrites, isEmpty);
  });

  testWidgets('a month change asks for that month, local midnight to local '
      'midnight', (tester) async {
    final kpis = _FakeKpis(_kpi);
    await _open(tester, kpis);
    final first = kpis.calls.single;
    await tester.tap(find.byKey(const ValueKey('capacity-kpi-previous')));
    await tester.pumpAndSettle();
    final previous = kpis.calls.last;
    expect(previous.to, first.from);
    expect(previous.from.day, 1);
  });

  testWidgets('nothing offered reads as undefined, never 0 %', (tester) async {
    await _open(tester, _FakeKpis(() => _kpi(offered: 0, reserved: 0)));
    expect(tester.widget<Text>(find.byKey(_value)).data, '—');
    expect(find.textContaining('no utilisation to show'), findsOneWidget);
  });

  testWidgets('a refusal says so; a failure offers a retry', (tester) async {
    final kpis = _FakeKpis(() => throw const KpiForbidden());
    await _open(tester, kpis);
    expect(
      find.byKey(const ValueKey('capacity-kpi-forbidden')),
      findsOneWidget,
    );
    expect(find.byKey(_value), findsNothing);

    kpis.answer = () => throw StateError('offline');
    await tester.tap(find.byKey(const ValueKey('capacity-kpi-next')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('capacity-kpi-unavailable')),
      findsOneWidget,
    );
    kpis.answer = _kpi;
    await tester.tap(find.byKey(const ValueKey('capacity-kpi-retry')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(_value)).data, '13.2%');
  });
}
