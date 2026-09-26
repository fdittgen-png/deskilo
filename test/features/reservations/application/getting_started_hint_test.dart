// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1654 — the Get started card's choice, as a table: one row per fact
// state the hub can be in, one expected action and reason per row, for
// an ordinary member, an owner and a pending membership.
//
// The invariant: the choice never claims what the facts do not know. A
// loading membership suggests nothing; an offline plan is not an empty
// plan; an allowance the policy has not answered is not zero; a booking
// counts only when the hub loaded it. And the choice never writes — it
// is a function, so this file needs no widget tree, no store and no
// repository.
import 'package:deskilo/features/reservations/application/getting_started_hint.dart';
import 'package:flutter_test/flutter_test.dart';

const _member = Fact.ready(MembershipStanding.member);
const _owner = Fact.ready(MembershipStanding.owner);
const _admin = Fact.ready(MembershipStanding.administrator);
const _pending = Fact.ready(MembershipStanding.pending);
const _inactive = Fact.ready(MembershipStanding.inactive);

const _open = Fact.ready(true);
const _closed = Fact.ready(false);
const _spaces = Fact.ready(4);
const _noSpaces = Fact.ready(0);
const _none = Fact<BookingEvidence?>.ready(null);
const _booked = Fact<BookingEvidence?>.ready(
  BookingEvidence(id: 'res-9', state: 'reserved'),
);

GettingStartedFacts _facts({
  Fact<MembershipStanding> membership = _member,
  Fact<bool> dayOpen = _open,
  Fact<int> spaces = _spaces,
  Fact<int> allowance = const Fact.ready(2),
  Fact<BookingEvidence?> booking = _none,
}) => GettingStartedFacts(
  membership: membership,
  workspaceName: 'Coworkonti',
  dayOpen: dayOpen,
  bookableSpaces: spaces,
  allowance: allowance,
  ownBooking: booking,
);

typedef Row = (
  String name,
  GettingStartedFacts facts,
  GettingStartedReason? reason,
  GettingStartedAction? action,
);

/// A row that expects a hint (with or without an action).
Row hint(
  String name,
  GettingStartedFacts facts,
  GettingStartedReason reason,
  GettingStartedAction? action,
) => (name, facts, reason, action);

/// A row that expects no hint at all.
Row nothing(String name, GettingStartedFacts facts) =>
    (name, facts, null, null);

final rows = <Row>[
  // ordinary member
  hint(
    'member, open day, spaces: choose a time',
    _facts(),
    GettingStartedReason.readyToBook,
    GettingStartedAction.chooseTime,
  ),
  hint(
    'member, closed day: choose another day',
    _facts(dayOpen: _closed),
    GettingStartedReason.closedToday,
    GettingStartedAction.chooseTime,
  ),
  hint(
    'member, empty plan: membership, never "create seats"',
    _facts(spaces: _noSpaces),
    GettingStartedReason.noSpaces,
    GettingStartedAction.viewMembership,
  ),
  hint(
    'member, plan loading: nothing yet',
    _facts(spaces: const Fact.loading()),
    GettingStartedReason.loading,
    null,
  ),
  hint(
    'member, day loading: nothing yet',
    _facts(dayOpen: const Fact.loading()),
    GettingStartedReason.loading,
    null,
  ),
  hint(
    'member, plan refreshing: the last answer decides',
    _facts(spaces: const Fact.refreshing(3)),
    GettingStartedReason.readyToBook,
    GettingStartedAction.chooseTime,
  ),
  hint(
    'member, plan stale: the last answer decides, provisionally',
    _facts(spaces: const Fact.stale(3)),
    GettingStartedReason.readyToBook,
    GettingStartedAction.chooseTime,
  ),
  hint(
    'member, plan offline: not an empty plan — the help',
    _facts(spaces: const Fact.offline()),
    GettingStartedReason.availabilityUnknown,
    GettingStartedAction.openHelp,
  ),
  hint(
    'member, plan refused: not an empty plan — the help',
    _facts(spaces: const Fact.refused()),
    GettingStartedReason.availabilityUnknown,
    GettingStartedAction.openHelp,
  ),
  hint(
    'member, day offline: neither open nor closed — the help',
    _facts(dayOpen: const Fact.offline()),
    GettingStartedReason.availabilityUnknown,
    GettingStartedAction.openHelp,
  ),
  hint(
    'member, a booking of mine loaded: success, read the membership',
    _facts(booking: _booked),
    GettingStartedReason.booked,
    GettingStartedAction.viewMembership,
  ),
  hint(
    'member, booking loaded on a closed day: still success',
    _facts(booking: _booked, dayOpen: _closed),
    GettingStartedReason.booked,
    GettingStartedAction.viewMembership,
  ),
  hint(
    'member, own bookings still loading: not a success, plan decides',
    _facts(booking: const Fact.loading()),
    GettingStartedReason.readyToBook,
    GettingStartedAction.chooseTime,
  ),
  hint(
    'member, own bookings offline: not a success, plan decides',
    _facts(booking: const Fact.offline()),
    GettingStartedReason.readyToBook,
    GettingStartedAction.chooseTime,
  ),
  // membership states
  hint(
    'membership loading: nothing yet',
    _facts(membership: const Fact.loading()),
    GettingStartedReason.loading,
    null,
  ),
  hint(
    'membership refreshing: the known standing decides',
    _facts(membership: const Fact.refreshing(MembershipStanding.member)),
    GettingStartedReason.readyToBook,
    GettingStartedAction.chooseTime,
  ),
  hint(
    'membership offline: the help, and no booking claim',
    _facts(membership: const Fact.offline()),
    GettingStartedReason.membershipUnknown,
    GettingStartedAction.openHelp,
  ),
  hint(
    'membership refused: the help, and no booking claim',
    _facts(membership: const Fact.refused()),
    GettingStartedReason.membershipUnknown,
    GettingStartedAction.openHelp,
  ),
  hint(
    'pending admission: no action — the waiting room is the surface',
    _facts(membership: _pending),
    GettingStartedReason.pendingAdmission,
    null,
  ),
  hint(
    'pending with a plan loaded: still no booking data exposed',
    _facts(membership: _pending, booking: _booked),
    GettingStartedReason.pendingAdmission,
    null,
  ),
  nothing('inactive membership: nothing', _facts(membership: _inactive)),
  // owner and administrator: the normal permitted task, no invented list
  hint(
    'owner, open day, spaces: the same task a member gets',
    _facts(membership: _owner),
    GettingStartedReason.readyToBook,
    GettingStartedAction.chooseTime,
  ),
  hint(
    'owner, empty plan: membership, not "draw the plan"',
    _facts(membership: _owner, spaces: _noSpaces),
    GettingStartedReason.noSpaces,
    GettingStartedAction.viewMembership,
  ),
  hint(
    'administrator, closed day: choose another day',
    _facts(membership: _admin, dayOpen: _closed),
    GettingStartedReason.closedToday,
    GettingStartedAction.chooseTime,
  ),
];

void main() {
  group('the table', () {
    for (final (name, facts, reason, action) in rows) {
      test(name, () {
        final got = chooseGettingStartedHint(facts, dismissed: false);
        if (reason == null) {
          expect(got, isNull);
          return;
        }
        expect(got, isNotNull, reason: 'expected $reason, got nothing');
        expect(got!.reason, reason);
        expect(got.action, action);
        expect(got.showsCard, action != null);
      });
    }
  });

  group('what the hint may quote', () {
    test('a known allowance is quoted', () {
      final got = chooseGettingStartedHint(_facts(), dismissed: false)!;
      expect(got.allowance, 2);
      expect(got.standing, MembershipStanding.member);
    });

    for (final (name, fact) in <(String, Fact<int>)>[
      ('loading', const Fact.loading()),
      ('offline', const Fact.offline()),
      ('refused', const Fact.refused()),
    ]) {
      test('an allowance that is $name is not zero and not completed', () {
        final got = chooseGettingStartedHint(
          _facts(allowance: fact),
          dismissed: false,
        )!;
        expect(got.allowance, isNull);
        expect(got.reason, isNot(GettingStartedReason.booked));
        expect(got.action, GettingStartedAction.chooseTime);
      });
    }

    test('a loaded booking is quoted by its real id and state', () {
      final got = chooseGettingStartedHint(
        _facts(booking: _booked),
        dismissed: false,
      )!;
      expect(got.booking?.id, 'res-9');
      expect(got.booking?.state, 'reserved');
    });

    test('no booking is quoted when none was loaded', () {
      expect(
        chooseGettingStartedHint(_facts(), dismissed: false)!.booking,
        isNull,
      );
    });
  });

  group('dismissal', () {
    test('a dismissed card returns nothing, whatever the facts', () {
      for (final (_, facts, _, _) in rows) {
        expect(chooseGettingStartedHint(facts, dismissed: true), isNull);
      }
    });
  });

  group('the owner seam (#1636)', () {
    const own = GettingStartedHint(
      reason: GettingStartedReason.readyToBook,
      action: GettingStartedAction.openHelp,
      standing: MembershipStanding.owner,
    );

    test('is consulted for an owner and an administrator', () {
      for (final standing in [_owner, _admin]) {
        var asked = 0;
        final got = chooseGettingStartedHint(
          _facts(membership: standing),
          dismissed: false,
          ownerGuidance: (facts) {
            asked++;
            return own;
          },
        );
        expect(asked, 1);
        expect(got, same(own));
      }
    });

    test('is never consulted for a member or a pending person', () {
      for (final standing in [_member, _pending]) {
        chooseGettingStartedHint(
          _facts(membership: standing),
          dismissed: false,
          ownerGuidance: (facts) => fail('asked for $standing'),
        );
      }
    });

    test('is never consulted while the membership is unknown', () {
      for (final standing in <Fact<MembershipStanding>>[
        const Fact.loading(),
        const Fact.offline(),
        const Fact.refused(),
      ]) {
        chooseGettingStartedHint(
          _facts(membership: standing),
          dismissed: false,
          ownerGuidance: (facts) => fail('asked for $standing'),
        );
      }
    });

    test('answering null falls through to the normal permitted task', () {
      final got = chooseGettingStartedHint(
        _facts(membership: _owner, spaces: _noSpaces),
        dismissed: false,
        ownerGuidance: (facts) => null,
      )!;
      expect(got.reason, GettingStartedReason.noSpaces);
      expect(got.action, GettingStartedAction.viewMembership);
    });

    test('the default is exactly that: nothing invented', () {
      expect(noOwnerReadinessGuidance(_facts(membership: _owner)), isNull);
    });
  });

  group('the seen key', () {
    test('names installation, account, workspace and version', () {
      expect(
        gettingStartedSeenKey(
          installation: 'a.supabase.co',
          accountId: 'u1',
          workspaceId: 'w1',
        ),
        'getting-started:v1:a.supabase.co:u1:w1',
      );
    });

    test('the same workspace id on another installation is another key', () {
      final a = gettingStartedSeenKey(
        installation: 'a.example',
        accountId: 'u1',
        workspaceId: 'w1',
      );
      final b = gettingStartedSeenKey(
        installation: 'b.example',
        accountId: 'u1',
        workspaceId: 'w1',
      );
      expect(a, isNot(b));
    });

    test('another account on the same phone is another key', () {
      final a = gettingStartedSeenKey(
        installation: 'a.example',
        accountId: 'u1',
        workspaceId: 'w1',
      );
      final b = gettingStartedSeenKey(
        installation: 'a.example',
        accountId: 'u2',
        workspaceId: 'w1',
      );
      expect(a, isNot(b));
    });

    test('a newer guidance version is another key; the app version is not '
        'part of it', () {
      final v1 = gettingStartedSeenKey(
        installation: 'a',
        accountId: 'u',
        workspaceId: 'w',
        version: 1,
      );
      final v2 = gettingStartedSeenKey(
        installation: 'a',
        accountId: 'u',
        workspaceId: 'w',
        version: 2,
      );
      expect(v1, isNot(v2));
      expect(kGettingStartedGuidanceVersion, 1);
    });

    test('an unknown scope has no key', () {
      expect(
        gettingStartedSeenKey(
          installation: '',
          accountId: 'u',
          workspaceId: 'w',
        ),
        isNull,
      );
      expect(
        gettingStartedSeenKey(
          installation: 'a',
          accountId: '',
          workspaceId: 'w',
        ),
        isNull,
      );
      expect(
        gettingStartedSeenKey(
          installation: 'a',
          accountId: 'u',
          workspaceId: '',
        ),
        isNull,
      );
    });
  });

  test('Fact.known is true only for an answered fact', () {
    expect(const Fact.ready(1).known, isTrue);
    expect(const Fact.refreshing(1).known, isTrue);
    expect(const Fact.stale(1).known, isTrue);
    expect(const Fact<int>.loading().known, isFalse);
    expect(const Fact<int>.offline().known, isFalse);
    expect(const Fact<int>.refused().known, isFalse);
  });
}
