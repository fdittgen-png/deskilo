// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3545 step 0 -- the ONE table of the Me screens the experience guards walk:
// the route, the source files that build its Scaffold, and the states to pump
// (what the person has: a populated Demo, nothing, one source failed). A new
// Me screen is added here in the PR that adds it; `me_scaffold_table_test`
// fails when a Scaffold under lib/features/me/presentation is not listed.
import 'package:deskilo/core/demo/data/account_activity_repository.dart';
import 'package:deskilo/features/me/providers/me_providers.dart';
import 'package:deskilo/features/me/providers/personal_shell_providers.dart';
import 'package:deskilo/features/money/domain/finance_overview.dart';
import 'package:deskilo/features/reservations/domain/my_reservations.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/providers/reservation_providers.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../features/me/me_app.dart';
import '../helpers/mock_providers.dart';
import '../helpers/screens/my_finances_screen.dart' show invoice;

/// What a state pumps: the workspace repository, the account repositories and
/// the extra provider overrides.
class MeScenario {
  const MeScenario({
    required this.workspace,
    required this.overrides,
    this.me,
    this.documents,
    this.messenger,
  });

  final FakeWorkspaceRepository workspace;
  final List<Override> overrides;
  final FakeMeRepository? me;
  final FakeAccountActivityRepository? documents;
  final FakeMessengerRepository? messenger;
}

/// The instant every Me guard and sheet runs at (UTC, so no zone moves it).
final DateTime meGuardNow = DateTime.utc(2026, 5, 13, 10);

/// A state of a screen, by name, and how to set it up.
typedef MeStateBuilder = MeScenario Function();

/// One Me screen: where it lives and what to walk.
class MeScreen {
  const MeScreen({
    required this.id,
    required this.route,
    required this.sources,
    required this.states,
  });

  final String id;
  final String route;

  /// The files under lib/features/me/presentation that build its Scaffold.
  final List<String> sources;
  final Map<String, MeStateBuilder> states;
}

class _Hosts implements MyReservationsRepository {
  _Hosts({this.items = const [], this.failing = false});

  final List<MyReservationItem> items;
  final bool failing;

  @override
  Future<MyReservationsLimits> limits() async => const MyReservationsLimits(
    windowDays: 7,
    maxDays: 60,
    concurrency: 4,
    timeout: Duration(seconds: 12),
  );

  @override
  Future<MyReservationsPage> page(
    MyReservationsSource source,
    MyReservationsQuery query,
  ) async {
    if (failing) throw StateError('host down');
    return MyReservationsPage(
      source: source.installationId,
      items: items,
      next: null,
      hasMore: false,
    );
  }
}

const _host = MyReservationsSource(
  installationId: 'inst-a',
  workspaceIds: ['ws-1'],
  hostedHere: true,
  labels: ['Pézenas'],
);

MyReservationItem _booking() {
  // A fixed instant, not a local one: the same text in every time zone.
  final start = DateTime.utc(2026, 5, 14, 9);
  return MyReservationItem(
    id: 'b1',
    workspaceId: 'ws-1',
    workspaceName: 'Pézenas',
    placeKind: MyReservationPlaceKind.desk,
    placeId: 'desk-1',
    placeLabel: 'Desk 1',
    startsAt: start,
    endsAt: start.add(const Duration(hours: 2)),
    status: ReservationStatus.reserved,
    checkedInAt: null,
    checkedOutAt: null,
  );
}

/// Two businesses, two currencies: the figure the sum guard looks for.
FakeAccountActivityRepository twoCurrencies() => FakeAccountActivityRepository()
  ..financeOverview = FinanceOverview(
    invoices: [
      invoice('eur', ws: 'One', due: DateTime(2999)),
      invoice('chf', ws: 'Two', total: 8000, currency: 'CHF', due: DateTime(2999)),
    ],
  );

/// The amounts of [twoCurrencies] (cents): 100.00 EUR and 80.00 CHF.
const List<int> twoCurrencyCents = [10000, 8000];

List<Override> _shell({_Hosts? hosts}) => [
  personalShellEnabledProvider.overrideWithValue(true),
  myReservationsRepositoryProvider.overrideWithValue(hosts ?? _Hosts()),
  myReservationsSourcesProvider.overrideWith((ref) async => const [_host]),
];

MeScenario _populated() => MeScenario(
  workspace: twoSpaces(),
  overrides: _shell(hosts: _Hosts(items: [_booking()])),
  documents: twoCurrencies(),
);

MeScenario _empty() => MeScenario(
  workspace: FakeWorkspaceRepository(workspaces: []),
  overrides: _shell(),
);

MeScenario _oneSourceFailed() => MeScenario(
  workspace: twoSpaces(),
  overrides: _shell(hosts: _Hosts(failing: true)),
  documents: twoCurrencies(),
);

/// The Spaces page's own source is the references of the account: when they
/// cannot be read it says so beside what it could read (#1650, #3545).
MeScenario _spacesSourceFailed() => MeScenario(
  workspace: twoSpaces(),
  overrides: [
    ..._shell(hosts: _Hosts()),
    personalWorkspaceRefsProvider.overrideWith(
      (ref) async => throw StateError('the account references are unreadable'),
    ),
  ],
  documents: twoCurrencies(),
);

const Map<String, MeStateBuilder> _states = {
  'populated': _populated,
  'empty': _empty,
  'one source failed': _oneSourceFailed,
};

/// The Me screens, one row each.
final List<MeScreen> meScreens = [
  const MeScreen(
    id: 'home',
    route: '/me',
    sources: ['personal_overview.dart', 'me_home_tab.dart'],
    states: _states,
  ),
  const MeScreen(
    id: 'spaces',
    route: '/me/spaces',
    sources: ['personal_spaces_view.dart'],
    states: {
      'populated': _populated,
      'empty': _empty,
      'one source failed': _spacesSourceFailed,
    },
  ),
  const MeScreen(
    id: 'discover',
    route: '/me/discover',
    sources: [],
    states: {'populated': _populated, 'empty': _empty},
  ),
  const MeScreen(
    id: 'messages',
    route: '/me/messages',
    sources: [],
    states: {'populated': _populated, 'empty': _empty},
  ),
  const MeScreen(
    id: 'data',
    route: '/me/data',
    sources: [],
    states: {'populated': _populated, 'empty': _empty},
  ),
  const MeScreen(
    id: 'account',
    route: '/me/account',
    sources: ['me_account_tab.dart'],
    states: {'populated': _populated, 'empty': _empty},
  ),
];

/// The files holding a Scaffold the guards cover without a table row of their
/// own: the shell around every screen and the screen of another person.
const List<String> meShellScaffolds = [
  'me_personal_shell.dart',
  'me_shell.dart',
  'public_person_screen.dart',
];
