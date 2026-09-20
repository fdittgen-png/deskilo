// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1582 — the eight-state model on the surfaces that reach it.
//
// Loading · Refreshing · Ready · Empty · Stale · Offline/Unavailable ·
// Error · Success/Changed. Not a tidiness exercise: three defects
// shipped this month were one of these states wearing another's
// clothes — #1561 (every error became `PersonalInfo.empty`, so FAILURE
// was presented as EMPTY and the form saved the blanks over a stored
// identity), #1563 (an UNLOADED value was indistinguishable from a
// CHOSEN one) and #1580 (STALE/unresolved presented as authoritative).
//
// So the three assertions every row is written to make:
//
//   unresolved is distinguishable from empty and from refused;
//   stale is never presented as authoritative;
//   empty is never presented as failure.
//
// Like `test/a11y/matrix.dart`, the model is DECLARED: each surface
// names every state, asserted or with a reason. A state nobody asserts
// is a line you can read rather than a silence.
import 'dart:async';

import 'package:deskilo/core/cache/stale_reads.dart';
import 'package:deskilo/core/demo/data/workspace_repository.dart';
import 'package:deskilo/core/ui/inline_banner.dart';
import 'package:deskilo/core/ui/loading_view.dart';
import 'package:deskilo/features/profile/domain/personal_info.dart';
import 'package:deskilo/features/reservations/presentation/widgets/stale_availability_banner.dart';
import 'package:deskilo/features/workspace/domain/managed_identity_read.dart';
import 'package:deskilo/features/workspace/domain/new_member_defaults.dart';
import 'package:deskilo/features/workspace/domain/overage_policy.dart';
import 'package:deskilo/features/workspace/presentation/widgets/new_member_defaults_tiles.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The eight.
enum SurfaceState {
  loading,
  refreshing,
  ready,
  empty,
  stale,
  unavailable,
  error,
  changed,
}

/// One data-driven surface and what is asserted about it.
class StateRow {
  StateRow(this.surface, {this.states = const {}, this.gaps = const {}})
      : assert(
          SurfaceState.values
              .every((s) => states.contains(s) ^ gaps.containsKey(s)),
          '$surface: every state is asserted or carries a reason',
        );

  final String surface;
  final Set<SurfaceState> states;
  final Map<SurfaceState, String> gaps;
}

/// THE MODEL. Rows may be added; a row may not quietly lose a state.
final List<StateRow> kStateModel = [
  StateRow('New-member defaults (#1563)', states: const {
    SurfaceState.loading,
    SurfaceState.ready,
    SurfaceState.empty,
    SurfaceState.error,
    SurfaceState.changed,
  }, gaps: const {
    SurfaceState.refreshing: 'the section has no refresh of its own; the '
        'retry is a fresh read — #1582 (2026-09-20)',
    SurfaceState.stale: 'billing_rules is not cached, so it is never served '
        'stale — #1582 (2026-09-20)',
    SurfaceState.unavailable: 'the read is not access-gated; a refusal '
        'arrives as an error — #1582 (2026-09-20)',
  }),
  StateRow('Managed identity read (#1561)', states: const {
    SurfaceState.loading,
    SurfaceState.ready,
    SurfaceState.empty,
    SurfaceState.unavailable,
    SurfaceState.error,
  }, gaps: const {
    SurfaceState.refreshing: 'asserted at the screen, not the read — '
        '#1582 (2026-09-20)',
    SurfaceState.stale: 'an identity is never served from the stale tier — '
        '#1582 (2026-09-20)',
    SurfaceState.changed: 'the save path is covered by '
        'test/features/members/managed_profile_test.dart — #1582 (2026-09-20)',
  }),
  StateRow('Availability freshness (#1305 S3)', states: const {
    SurfaceState.ready,
    SurfaceState.stale,
  }, gaps: {
    for (final s in SurfaceState.values)
      if (s != SurfaceState.ready && s != SurfaceState.stale)
        s: 'the banner answers one question — is what you see live — and '
            'nothing else — #1582 (2026-09-20)',
  }),
  // The hole this model is FOR. Nothing is asserted because the
  // behaviour is wrong and known: `bookingGateOf` substitutes
  // `WorkHours.defaults` and an all-week opening for reads in flight, so
  // a window reads bookable on hours the space never chose. Asserting
  // today's behaviour would pin the defect.
  StateRow('Booking window gate', gaps: {
    for (final s in SurfaceState.values)
      s: 'unresolved is presented as open — #1580 (2026-09-20)',
  }),
];

/// States asserted somewhere below. RATCHET: up only.
const _stateFloor = 12;

// ───────────────────────────── helpers ─────────────────────────────

/// The section on its own, in whichever state the arguments describe:
/// no app, no router, and so no delay needed to reach a state.
Future<void> _pumpDefaults(
  WidgetTester tester, {
  required NewMemberDefaults? defaults,
  bool failed = false,
  VoidCallback? onRetry,
  ValueChanged<int>? onChanged,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: NewMemberDefaultsTiles(
          defaults: defaults,
          enabled: true,
          failed: failed,
          onRetry: onRetry,
          onSubscriptionChanged: onChanged ?? (_) {},
          onOveragePolicyChanged: (_) {},
        ),
      ),
    ),
  ));
  // NOT pumpAndSettle: LoadingView fades in and never settles.
  await tester.pump();
}

/// The controls a member only sees once the value has arrived.
final _controls = find.byKey(const ValueKey('new-member-pct-up'));
final _retry = find.byKey(const ValueKey('inline-banner-action'));

/// A workspace repository whose identity read is held open, or fails.
class _Identity extends FakeWorkspaceRepository {
  _Identity() : super.withWorkspace();

  Completer<PersonalInfo> gate = Completer<PersonalInfo>();
  Object? failWith;

  @override
  Future<PersonalInfo> managedIdentityOf(String memberId) {
    if (failWith != null) return Future.error(failWith!);
    return gate.future;
  }
}

/// What the read ANSWERED, whichever of the states that is.
///
/// Two harness facts, both of which turn a real answer into a hang or a
/// `StateError` if they are missed: the provider is auto-disposing, so
/// the read needs a listener held open; and Riverpod 3 RETRIES a
/// provider that ends in error, so a failed read never completes unless
/// the retry is switched off for the container.
Future<ManagedIdentityRead> _read(_Identity repo) {
  final container = ProviderContainer(
    overrides: [workspaceRepositoryProvider.overrideWithValue(repo)],
    retry: (_, _) => null,
  );
  addTearDown(container.dispose);
  final provider = managedIdentityProvider('m-1');
  final sub = container.listen(provider, (_, _) {});
  addTearDown(sub.close);
  return container.read(provider.future);
}

void main() {
  group('the model is declared, not sampled', () {
    test('every surface answers for every state (#1582)', () {
      for (final row in kStateModel) {
        for (final state in SurfaceState.values) {
          expect(row.states.contains(state) || row.gaps.containsKey(state),
              isTrue,
              reason: '${row.surface} says nothing about ${state.name}');
        }
      }
    });

    test('the model only grows', () {
      final asserted =
          kStateModel.fold<int>(0, (n, row) => n + row.states.length);
      expect(asserted, greaterThanOrEqualTo(_stateFloor),
          reason: '$asserted states asserted, down from $_stateFloor. '
              'Raise the floor when it rises; never lower it');
    });

    test('every gap names an issue and a date', () {
      final dated = RegExp(r'#\d+ \(20\d\d-\d\d-\d\d\)');
      for (final row in kStateModel) {
        for (final gap in row.gaps.entries) {
          expect(dated.hasMatch(gap.value), isTrue,
              reason: '${row.surface}/${gap.key.name}: "${gap.value}" is a '
                  'gap without an issue and a date, which is an excuse');
        }
      }
    });
  });

  group('New-member defaults — unresolved is not empty (#1563)', () {
    testWidgets('LOADING offers no control and claims nothing', (tester) async {
      await _pumpDefaults(tester, defaults: null);

      expect(find.byType(LoadingView), findsOneWidget);
      expect(_controls, findsNothing,
          reason: 'a control on a value nobody has chosen yet is how #1563 '
              'saved 100%/blocked over a configured 50%/pay-as-you-go');
      expect(find.byType(InlineBanner), findsNothing,
          reason: 'a read still in flight is not a failure');
      expect(find.textContaining('Nothing chosen'), findsNothing,
          reason: 'unresolved must not read as EMPTY — "nothing chosen" is '
              'a statement about the workspace, not about the network');
    });

    testWidgets('ERROR says so, keeps the controls away, and offers the read '
        'again', (tester) async {
      var retried = 0;
      await _pumpDefaults(tester,
          defaults: null, failed: true, onRetry: () => retried++);

      expect(find.byType(InlineBanner), findsOneWidget);
      expect(find.textContaining('could not be read'), findsOneWidget);
      expect(find.byType(LoadingView), findsNothing,
          reason: 'a failure that still shows a spinner is a read that '
              'never answers');
      expect(_controls, findsNothing);

      await tester.tap(_retry);
      await tester.pump();
      expect(retried, 1, reason: 'the retry has to reach the caller');
    });

    testWidgets('EMPTY is not a failure: nothing is chosen, and choosing is '
        'offered', (tester) async {
      await _pumpDefaults(tester,
          defaults: const NewMemberDefaults(
              subscriptionPct: 100,
              overagePolicy: OveragePolicy.blocked,
              configured: false));

      expect(find.textContaining('Nothing chosen'), findsOneWidget);
      expect(_controls, findsOneWidget,
          reason: 'empty means nobody has decided yet, so the decision is '
              'offered — an empty value is never presented as a failure');
      expect(find.byType(InlineBanner), findsNothing);
      expect(find.byType(LoadingView), findsNothing);
    });

    testWidgets('READY and CHANGED: the value is shown, and moving it '
        'reports the new one', (tester) async {
      final reported = <int>[];
      await _pumpDefaults(tester,
          defaults: const NewMemberDefaults(
              subscriptionPct: 50,
              overagePolicy: OveragePolicy.payg,
              configured: true),
          onChanged: reported.add);

      expect(find.textContaining('What somebody starts with'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);

      await tester.tap(_controls);
      await tester.pump();
      expect(reported, [55],
          reason: 'the change reaches the caller as a domain value, which '
              'is what a save would send');
    });
  });

  group('Managed identity — refused, empty and failed are three things '
      '(#1561)', () {
    test('LOADING: the read has no value, so nothing reads it as empty',
        () async {
      final repo = _Identity();

      final container = ProviderContainer(
        overrides: [workspaceRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      final read = container.read(managedIdentityProvider('m-1'));

      expect(read.isLoading, isTrue);
      expect(read.hasValue, isFalse,
          reason: 'a pending read that already answers with an empty '
              'identity is #1561 exactly: the form opens on blanks');
      repo.gate.complete(PersonalInfo.empty);
    });

    test('REFUSED is an answer: the rule does not name you', () async {
      // The refusal as the server sends it: `managed_identity_of` (0161)
      // raises 42501 when the access rule does not name the caller, and
      // `knownRefusalOf` reads the server's message, not a string.
      final repo = _Identity()
        ..failWith = const PostgrestException(
            message: 'not allowed to read this profile', code: '42501');
      final read = await _read(repo);

      expect(read.refused, isTrue);
      expect(read.identity, PersonalInfo.empty);
    });

    test('EMPTY is not refused: a profile whose identity was never filled in',
        () async {
      final repo = _Identity()..gate.complete(PersonalInfo.empty);
      final read = await _read(repo);

      expect(read.refused, isFalse,
          reason: 'an empty identity is a form with nothing in it yet; a '
              'refusal is a form nobody may open. The two share a value '
              'and must not share a state');
      expect(read.identity, PersonalInfo.empty);
    });

    test('ERROR stays an error: a dropped connection is not an answer',
        () async {
      final repo = _Identity()..failWith = Exception('connection closed');

      await expectLater(_read(repo), throwsA(isA<Exception>()),
          reason: 'swallowing a transport failure into a refusal is how a '
              'form opens blank on a dropped connection and saves the '
              'blanks over the stored identity');
    });

    test('READY: what the server holds arrives whole', () async {
      const stored = PersonalInfo(firstName: 'Ana', lastName: 'Roux');
      final repo = _Identity()..gate.complete(stored);
      final read = await _read(repo);

      expect(read.refused, isFalse);
      expect(read.identity.firstName, 'Ana');
    });
  });

  group('Availability — stale is never presented as authoritative (#1305 S3)',
      () {
    setUpAll(initializeDateFormatting);
    setUp(StaleReads.instance.reset);
    tearDown(StaleReads.instance.reset);

    Future<void> pumpBanner(WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: StaleAvailabilityBanner()),
        ),
      ));
      await tester.pump();
    }

    testWidgets('READY: a live read says nothing', (tester) async {
      await pumpBanner(tester);

      expect(find.byKey(const ValueKey('reserve-availability-live')),
          findsOneWidget);
      expect(find.byType(InlineBanner), findsNothing);
    });

    testWidgets('STALE: what is drawn is dated, and can be asked again',
        (tester) async {
      await pumpBanner(tester);
      StaleReads.instance
          .served('resv:2026-09-20', DateTime(2026, 9, 20, 8, 30));
      await tester.pump();

      expect(find.byKey(const ValueKey('reserve-stale-banner')), findsOneWidget,
          reason: 'availability answered from the cache that looks exactly '
              'like a live answer is how a member books a seat that was '
              'taken ten minutes ago');
      expect(find.byKey(const ValueKey('reserve-availability-live')),
          findsNothing);
      expect(_retry, findsOneWidget,
          reason: 'saying the data is old without offering to refresh it '
              'leaves the member with nothing to do about it');

      // And it goes away by itself when the network comes back — a
      // banner that outlives the condition is the next false state.
      StaleReads.instance.fresh('resv:2026-09-20');
      await tester.pump();
      expect(find.byKey(const ValueKey('reserve-stale-banner')), findsNothing);
    });
  });
}
