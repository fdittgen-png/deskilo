// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1915 — a person files a rights request from Privacy & data and sees
// when the space answers by; and before erasing, the app says what goes,
// what stays and why, and what lies outside this installation.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/privacy/privacy_policy.dart';
import 'package:deskilo/features/profile/application/rights_requests.dart';
import 'package:deskilo/features/profile/domain/profile.dart';
import 'package:deskilo/features/profile/domain/rights_request.dart';
import 'package:deskilo/features/profile/presentation/widgets/erasure_preview_view.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/fake_profile_repository.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/open_my_account.dart';

Future<FakeProfileRepository> _pump(WidgetTester tester) async {
  final profile = FakeProfileRepository(
    profiles: [
      const Profile(
        id: 'user-1',
        displayName: 'Test User',
        privacyAcceptedVersion: kPrivacyPolicyVersion,
      ),
    ],
    accepted: true,
  );
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        profile: profile,
        floorPlan: FakeFloorPlanRepository()..seedSmallPlan(),
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  return profile;
}

void main() {
  test('the server request parses, the extended date wins', () {
    final r = RightsRequest.fromJson({
      'id': 'r1',
      'kind': 'access',
      'status': 'extended',
      'received_at': '2025-01-31T11:00:00Z',
      'due_on': '2025-02-28',
      'extended_due_on': '2025-04-30',
      'extension_reason': 'Several archived stores must be searched',
    });
    expect(r.dueOn, DateTime(2025, 2, 28));
    expect(r.answerBy, DateTime(2025, 4, 30));
  });

  test('a client request id is a v4 UUID, new for each submission', () {
    final a = newClientRequestId();
    final b = newClientRequestId();
    expect(
      RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      ).hasMatch(a),
      isTrue,
    );
    expect(a, isNot(b));
  });

  testWidgets('a request is filed from Privacy & data and says when the '
      'space answers', (tester) async {
    final profile = await _pump(tester);
    await openMyPrivacy(tester);
    final tile = find.byKey(const ValueKey('privacy-rights-requests'));
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.text('No request yet.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rights-request-new')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rights-kind-rectification')));
    await tester.enterText(
      find.byKey(const ValueKey('rights-request-details')),
      'My postal address is wrong',
    );
    await tester.tap(find.byKey(const ValueKey('rights-request-send')));
    await tester.pumpAndSettle();
    expect(profile.rightsRequests.single.kind, 'rectification');
    expect(profile.rightsRequests.single.details, 'My postal address is wrong');
    expect(find.textContaining('Received — answer due by'), findsOneWidget);
  });

  testWidgets('erasing first says what goes, what stays and what lies '
      'outside this installation', (tester) async {
    final preview = ErasurePreview.fromJson({
      'removed': [
        {'store': 'custom_answers', 'count': 2},
        {'store': 'messages_sent', 'count': 0},
      ],
      'retained': [
        {'store': 'invoices', 'count': 3, 'basis': 'x', 'period': 'y'},
        {'store': 'ledger_entries', 'count': 5, 'basis': 'x', 'period': 'y'},
        {'store': 'membership_row', 'count': 1, 'basis': 'x', 'period': 'y'},
      ],
      'pending_external': [
        {'store': 'other_installations'},
      ],
    });
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ErasurePreviewView(preview: preview)),
      ),
    );
    expect(find.textContaining('Your answers to the space'), findsOneWidget);
    expect(
      find.textContaining('Messages you sent'),
      findsNothing,
      reason: 'nothing to remove is not listed',
    );
    expect(
      find.textContaining('accounting evidence'),
      findsOneWidget,
      reason: 'invoices and ledger read as one line',
    );
    expect(find.textContaining('pseudonymous, not anonymous'), findsOneWidget);
    expect(find.textContaining('separate controller'), findsOneWidget);
  });

  test('every new rights string exists in all five languages', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      expect(l10n.rightsRequestsTitle, isNotEmpty);
      expect(l10n.rightsKindPortability, isNotEmpty);
      expect(l10n.erasureStoreMembership, isNotEmpty);
      expect(l10n.rightsStatusReceived('1 Jan'), contains('1 Jan'));
    }
  });
}
