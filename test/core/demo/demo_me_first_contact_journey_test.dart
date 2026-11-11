// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3545 -- the first contact, end to end: a new person with no space meets the
// first visit, opens Discover, opens a space, asks to join, and Home then
// shows the request as sent with the "find or join a space" step done.
import 'package:deskilo/core/demo/data/profile_repository.dart';
import 'package:deskilo/core/demo/data/public_directory_repository.dart';
import 'package:deskilo/core/privacy/privacy_policy.dart';
import 'package:deskilo/features/directory/domain/public_workspace.dart';
import 'package:deskilo/features/directory/providers/admission_requests_provider.dart';
import 'package:deskilo/features/me/domain/personal_workspace_refs.dart';
import 'package:deskilo/features/me/providers/me_providers.dart';
import 'package:deskilo/features/me/providers/personal_shell_providers.dart';
import 'package:deskilo/features/profile/domain/profile.dart';
import 'package:deskilo/features/reservations/domain/my_reservations.dart';
import 'package:deskilo/features/reservations/providers/reservation_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../features/me/me_app.dart';
import '../../helpers/mock_providers.dart';

/// A host that has nothing booked: the first visit needs every source read.
class _NoBookings implements MyReservationsRepository {
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
  ) async => MyReservationsPage(
    source: source.installationId,
    items: const [],
    next: null,
    hasMore: false,
  );
}

Finder _key(String k) => find.byKey(ValueKey(k));

void main() {
  testWidgets('first visit -> Discover -> a space -> Ask to join -> Home shows '
      'the request and step 2 done', (tester) async {
    final directory = FakeDirectoryRepository();
    const page = PublicWorkspace('ws-new', 'https://demo.invalid', 'key', {
      'name': 'Atelier Nord',
      'host_type': 'company',
    });
    directory.cards.add(page);
    final router = await pumpMeApp(
      tester,
      workspace: FakeWorkspaceRepository(workspaces: []),
      directory: directory,
      profile: FakeProfileRepository(
        profiles: [
          Profile(
            id: 'user-1',
            displayName: 'Ada Lovelace',
            privacyAcceptedVersion: kPrivacyPolicyVersion,
            privacyAcceptedAt: DateTime.utc(2026, 8, 30),
          ),
        ],
      ),
      size: const Size(420, 2400),
      extraOverrides: <Override>[
        personalShellEnabledProvider.overrideWithValue(true),
        myReservationsRepositoryProvider.overrideWithValue(_NoBookings()),
        myReservationsSourcesProvider.overrideWith((ref) async => const []),
        // The account's references follow what the directory took: the
        // request made from the page makes this read again.
        personalWorkspaceRefsProvider.overrideWith((ref) async {
          ref.watch(admissionRequestsSentProvider);
          return PersonalWorkspaceRefs(
            homeInstallationId: 'inst-a',
            refs: [
              for (final _ in directory.requests)
                const PersonalWorkspaceRef(
                  networkId: 'inst-a:ws-new',
                  hostedHere: true,
                  freshness: RefFreshness.local,
                  status: RefStatus.pending,
                  label: 'Atelier Nord',
                ),
            ],
          );
        }),
      ],
    );
    await goTo(tester, router, '/me');
    expect(_key('me-first-visit'), findsOneWidget, reason: 'nothing yet');

    await tester.tap(_key('me-first-visit-browse'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/me/discover');
    expect(find.textContaining('Atelier Nord'), findsWidgets);

    await tester.tap(find.text('View').first);
    await tester.pumpAndSettle();
    final ask = _key('portal-request-membership');
    expect(ask, findsOneWidget);
    await tester.tap(ask);
    await tester.pumpAndSettle();
    expect(directory.requests, ['ws-new']);
    expect(find.text('Request pending'), findsOneWidget);

    await goTo(tester, router, '/me');
    expect(_key('me-first-visit'), findsNothing, reason: 'a request waits');
    expect(find.textContaining('Request sent'), findsWidgets);
    // Step 2 (find or join a space) is done: the one-line checklist no longer
    // names it as the next step; the next one is the first booking.
    final row = _key('me-first-steps-row');
    expect(row, findsOneWidget);
    final words = tester
        .widgetList<Text>(find.descendant(of: row, matching: find.byType(Text)))
        .map((t) => t.data ?? '')
        .join(' ');
    expect(words, isNot(contains('Find or join a space')), reason: words);
    expect(words, contains('Book your first desk'), reason: words);
  });
}
