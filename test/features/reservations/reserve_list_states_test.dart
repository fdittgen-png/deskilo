// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3061 — the Reserve list view's floor plan: loading is the skeleton, not an
// empty plan; a failed or refused read is a failure with Try again (the same
// read, once more), never "no seats"; a refresh keeps the list on screen.
import 'dart:async';
import 'dart:io';

import 'package:deskilo/core/demo/data/floor_plan_repository.dart';
import 'package:deskilo/features/plan/domain/floor_plan.dart';
import 'package:deskilo/features/plan/providers/floor_plan_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../helpers/screens/reserve_hub.dart' show pumpHub;

final _en = AppLocalizationsEn();

/// A plan store whose reads the test holds, fails and counts.
class _Plans extends FakeFloorPlanRepository {
  int reads = 0;
  Completer<void>? hold;
  Object? failure;

  @override
  Future<FloorPlan> fetchPlan(String levelId) async {
    reads++;
    await hold?.future;
    if (failure case final error?) throw error;
    return super.fetchPlan(levelId);
  }
}

const _list = ValueKey('reserve-list-view');
const _skeleton = ValueKey('reserve-plan-skeleton');
const _banner = ValueKey('reserve-plan-unavailable');
const _refreshing = ValueKey('read-refreshing');

Future<void> _toList(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.view_list_outlined));
  await tester.pump(const Duration(milliseconds: 400));
}

/// The test app's container keeps Riverpod's default retry (the real app's
/// is `readRetry`): a failed read settles into its error after ~40 s of it.
Future<void> _retriesRunOut(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 60));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('loading is the skeleton, then the list', (tester) async {
    final plans = _Plans()..hold = Completer<void>();
    await pumpHub(tester, floorPlans: plans);
    await _toList(tester);
    expect(find.byKey(_skeleton), findsOneWidget);
    expect(find.byKey(_list), findsNothing);
    expect(find.text(_en.planNoSeats), findsNothing);

    plans.hold!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(_list), findsOneWidget);
    expect(find.byKey(_skeleton), findsNothing);
  });

  testWidgets('a refused read is access, never "no seats"; Try again reads '
      'the same plan once more', (tester) async {
    final plans = _Plans()
      ..failure = const PostgrestException(message: 'rls', code: '42501');
    await pumpHub(tester, floorPlans: plans);
    await _toList(tester);
    await _retriesRunOut(tester);
    expect(find.byKey(_banner), findsOneWidget);
    expect(find.text(_en.readStateDenied), findsOneWidget);
    expect(find.text(_en.planNoSeats), findsNothing);
    expect(find.textContaining('rls'), findsNothing);

    final before = plans.reads;
    plans.failure = null;
    await tester.tap(find.descendant(of: find.byKey(_banner), matching: find.text(_en.commonRetry)));
    await tester.pumpAndSettle();
    expect(plans.reads, before + 1);
    expect(find.byKey(_list), findsOneWidget);
    expect(find.byKey(_banner), findsNothing);
  });

  testWidgets('a connectivity failure says so', (tester) async {
    final plans = _Plans()..failure = const SocketException('offline');
    await pumpHub(tester, floorPlans: plans);
    await _toList(tester);
    await _retriesRunOut(tester);
    expect(find.text(_en.readStateOffline), findsOneWidget);
    expect(find.text(_en.planNoSeats), findsNothing);
  });

  testWidgets('a refresh keeps the list with a thin progress line; a failed '
      'refresh keeps it under the failure', (tester) async {
    final plans = _Plans();
    await pumpHub(tester, floorPlans: plans);
    await _toList(tester);
    expect(find.byKey(_list), findsOneWidget);

    plans.hold = Completer<void>();
    final container = ProviderScope.containerOf(tester.element(find.byKey(_list)));
    container.invalidate(floorPlanProvider(plans.levels.first.id));
    await tester.pump();
    expect(find.byKey(_list), findsOneWidget, reason: 'content stays');
    expect(find.byKey(_refreshing), findsOneWidget);
    expect(find.byKey(_skeleton), findsNothing);

    plans.failure = const PostgrestException(message: 'gone', code: '42501');
    plans.hold!.complete();
    await _retriesRunOut(tester);
    expect(find.byKey(_list), findsOneWidget);
    expect(find.byKey(_banner), findsOneWidget);
    expect(find.text(_en.readStateDenied), findsOneWidget);
  });
}
