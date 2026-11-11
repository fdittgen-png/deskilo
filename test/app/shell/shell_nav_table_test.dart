// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3551 — the shell as one table from (features, permissions) to the
// destinations in order, the one selected for a location, the landing and the
// centre action. A business with places keeps exactly its branch list; one
// without leads with Overview, Clients, Invoices, Messages, then Calendar.
import 'package:deskilo/app/shell/shell_destinations.dart';
import 'package:deskilo/features/workspace/domain/bi_modules.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:flutter_test/flutter_test.dart';

const _all = {
  WorkspaceFeature.placeBooking,
  WorkspaceFeature.workspaceOverview,
  WorkspaceFeature.calendarTab,
  WorkspaceFeature.membersDirectory,
  WorkspaceFeature.moneyTab,
  WorkspaceFeature.eventsTab,
  WorkspaceFeature.invoicing,
};

const _owner = {
  WorkspacePermission.useMessages,
  WorkspacePermission.viewCalendar,
  WorkspacePermission.viewDirectory,
  WorkspacePermission.viewFinances,
  WorkspacePermission.issueInvoices,
  WorkspacePermission.makeReservations,
};

Set<WorkspaceFeature> _without(WorkspaceFeature f) => {..._all}..remove(f);

List<String> _ids(Set<WorkspaceFeature> f, Set<WorkspacePermission> p) => [
  for (final n in shellNavFor(f, p)) n.id,
];

void main() {
  test('a business with places keeps its branch list exactly', () {
    for (final perms in [
      _owner,
      {WorkspacePermission.useMessages},
      {WorkspacePermission.viewFinances, WorkspacePermission.viewDirectory},
    ]) {
      expect(
        [for (final n in shellNavFor(_all, perms)) n.branch],
        visibleShellBranches(_all, perms),
      );
      expect(shellNavFor(_all, perms).every((n) => n.location == null), isTrue);
    }
  });

  test('without places: Overview, Clients, Invoices, Messages, Calendar', () {
    final noPlaces = _without(WorkspaceFeature.placeBooking);
    expect(_ids(noPlaces, _owner), [
      'overview',
      'directory',
      'money',
      'messages',
      'calendar',
    ]);
    // Each destination appears only with what gives it.
    expect(
      _ids(noPlaces, {WorkspacePermission.useMessages}),
      ['overview', 'messages'],
    );
    expect(
      _ids({...noPlaces}..remove(WorkspaceFeature.workspaceOverview), _owner),
      ['directory', 'money', 'messages', 'calendar'],
    );
  });

  test('the two destinations of branch 0 are selected by their location', () {
    final navs = shellNavFor(_without(WorkspaceFeature.placeBooking), _owner);
    String? selected(int branch, String path) => navs
        .where((n) => n.selectedAt(branch: branch, path: path))
        .map((n) => n.id)
        .firstOrNull;
    expect(selected(ShellBranch.messages, '/workspace-overview'), 'overview');
    expect(selected(ShellBranch.messages, '/messages'), 'messages');
    expect(selected(ShellBranch.money, '/money'), 'money');
    expect(selected(ShellBranch.directory, '/directory'), 'directory');
  });

  test('the landing follows the places, then the overview', () {
    expect(landingRouteFor(_all), '/reserve');
    expect(
      landingRouteFor(_without(WorkspaceFeature.placeBooking)),
      '/workspace-overview',
    );
    expect(
      landingRouteFor(
        _without(WorkspaceFeature.placeBooking)
          ..remove(WorkspaceFeature.workspaceOverview),
      ),
      '/messages',
    );
  });

  test('the centre action: the booking, a new invoice, or none', () {
    expect(shellCenterActionFor(_all, _owner), ShellCenterAction.reserve);
    expect(
      shellCenterActionFor(_all, const {}, membershipKnown: false),
      ShellCenterAction.reserve,
      reason: 'unknown permissions hide nothing',
    );
    expect(shellCenterActionFor(_all, const {}), ShellCenterAction.none);
    final noPlaces = _without(WorkspaceFeature.placeBooking);
    expect(shellCenterActionFor(noPlaces, _owner), ShellCenterAction.newInvoice);
    expect(
      shellCenterActionFor(noPlaces, {WorkspacePermission.viewFinances}),
      ShellCenterAction.none,
      reason: 'a member who may not issue gets no centre action',
    );
    expect(
      shellCenterActionFor({...noPlaces}..remove(WorkspaceFeature.invoicing), _owner),
      ShellCenterAction.none,
    );
  });

  test('without places the capacity indicators are not shown; sales, '
      'purchases, cash and people stay', () {
    Set<String> areas(Map<String, bool> flags) => {
      for (final m in visibleBiModules(
        effectiveFeatures(resolveEnabledFeatures(flags)),
        WorkspacePermission.values.toSet(),
      ))
        m.area.name,
    };
    final everything = {for (final f in WorkspaceFeature.values) f.name: true};
    expect(areas(everything), contains('capacity'));
    final noPlaces = areas({...everything, 'placeBooking': false});
    expect(noPlaces, isNot(contains('capacity')));
    expect(noPlaces, containsAll(areas(everything).difference({'capacity'})));
  });
}
