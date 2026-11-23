// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4426 -- the business's day as the app wires it for the money screens: the business's own calendar when it is known, the
// UTC date (never the device's) while it is not, and the new business's day after a workspace switch.
import 'package:deskilo/app/business_day_wiring.dart';
import 'package:deskilo/core/backend/operation_context.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/core/time/work_hours.dart';
import 'package:deskilo/core/time/workspace_calendar.dart';
import 'package:deskilo/features/money/providers/business_day_provider.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The only thing the wiring reads of a context is its calendar.
class _Context implements WorkspaceContext {
  _Context(String timezone)
    : calendar = WorkspaceCalendar(timezone: timezone, openWeekdays: const [1, 2, 3, 4, 5], workHours: WorkHours.defaults, closures: const []);

  @override
  final WorkspaceCalendar calendar;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Workspace _row(String timezone) => Workspace(id: 'w-1', name: 'W', countryCode: 'FR', currencyCode: 'EUR', timezone: timezone, inviteCode: 'x');

void main() {
  // 23:30 UTC on the 22nd: the 23rd in Auckland, the 22nd in Los Angeles and in UTC.
  final now = DateTime.utc(2026, 11, 22, 23, 30);
  WorkspaceContext? current;

  /// The zone of the workspace row, while the captured context is not ready.
  Workspace? row;

  Future<ProviderContainer> make() async {
    final container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(FixedClock(now)),
        readyWorkspaceContextProvider.overrideWith((ref) => current),
        currentWorkspaceProvider.overrideWith((ref) async => row),
        businessDayFromApp,
      ],
    );
    addTearDown(container.dispose);
    await container.read(currentWorkspaceProvider.future);
    return container;
  }

  setUp(() {
    current = null;
    row = null;
  });

  test('a known calendar gives the business\'s own day', () async {
    current = _Context('Pacific/Auckland');
    expect((await make()).read(businessDayProvider), DateTime(2026, 11, 23));
  });

  test('while no zone is known the UTC date stands in, never the device\'s', () async {
    expect((await make()).read(businessDayProvider), DateTime(2026, 11, 22));
  });

  test('before the context is ready the zone of the workspace row gives the business\'s day', () async {
    row = _row('Pacific/Auckland');
    expect((await make()).read(businessDayProvider), DateTime(2026, 11, 23));
  });

  test('after a workspace switch the day is the new business\'s', () async {
    current = _Context('Pacific/Auckland');
    final container = await make();
    expect(container.read(businessDayProvider), DateTime(2026, 11, 23));
    current = _Context('America/Los_Angeles');
    container.invalidate(readyWorkspaceContextProvider);
    expect(container.read(businessDayProvider), DateTime(2026, 11, 22));
    current = null;
    container.invalidate(readyWorkspaceContextProvider);
    expect(container.read(businessDayProvider), DateTime(2026, 11, 22));
  });
}
