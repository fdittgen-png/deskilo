// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1514 — the fail-closed proof, and the reason the retired blur could
// never have passed it.
//
// The blur painted over the rendered result. A surface it did not know
// about rendered the name, and the mechanism did not care: the test you
// could write against it was "the widget I remembered to register is
// covered", never "no real name is on screen".
//
// This drives the REAL directory — the densest personal page there is —
// through the real providers with filming mode on, then walks every
// rendered `Text` in the tree and fails if any of them contains a real
// person's name, e-mail, telephone number or address. Nothing is
// registered, nothing is listed: the assertion is over the whole frame.
//
// And it is capable of failing: the last case is the same walk with the
// flag OFF, where every one of those values IS found. If the seam ever
// stops substituting, the first test goes red for the right reason.
import 'package:deskilo/core/privacy/recording_banner.dart';
import 'package:deskilo/core/privacy/recording_privacy.dart';
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/i18n/format_prefs.dart';
import 'package:deskilo/features/profile/domain/personal_info.dart';
import 'package:deskilo/features/profile/domain/profile.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_profile_repository.dart';
import '../../helpers/mock_providers.dart';

/// What a real workspace carries, and what must never be filmed.
const _realNames = ['Marie Dupont', 'Ahmed Benali', 'Sofia Lindgren'];
const _realEmails = ['marie.dupont@gmail.com', 'ahmed.benali@free.fr'];
const _realPhones = ['+33762456325', '+491701234567'];
const _realAddress = '14 rue de la Paix';

Member _member(int n) => Member(
      id: 'member-$n',
      workspaceId: 'ws-1',
      userId: 'user-$n',
      isAdmin: false,
      isOwner: n == 1,
      status: MemberStatus.active,
    );

({FakeWorkspaceRepository workspace, FakeProfileRepository profile})
    _seed({required bool filming}) {
  final workspace = FakeWorkspaceRepository.withWorkspace(
    featureFlags: {'memberPage': false, 'recordingPrivacy': filming},
  )
    ..myMember = _member(1)
    ..otherMembers.addAll([_member(2), _member(3)])
    ..memberNames = {
      'member-1': _realNames[0],
      'member-2': _realNames[1],
      'member-3': _realNames[2],
    };

  final profile = FakeProfileRepository(profiles: [
    Profile(
      id: 'user-1',
      displayName: _realNames[0],
      whatsapp: _realPhones[0],
      address: '$_realAddress, 34120 Pézenas',
      identity: PersonalInfo(
        firstName: 'Marie',
        lastName: 'Dupont',
        street: _realAddress,
        city: 'Pézenas',
        phone: _realPhones[0],
        email: _realEmails[0],
      ),
      lastSeenAt: kTestNow,
    ),
    Profile(
      id: 'user-2',
      displayName: _realNames[1],
      whatsapp: _realPhones[1],
      statusText: _realEmails[1],
      lastSeenAt: kTestNow,
    ),
    Profile(id: 'user-3', displayName: _realNames[2]),
  ]);
  return (workspace: workspace, profile: profile);
}

/// Every string the frame is currently showing.
List<String> _renderedText(WidgetTester tester) => [
      for (final text in tester.widgetList<Text>(find.byType(Text)))
        text.data ?? text.textSpan?.toPlainText() ?? '',
    ];

/// The personal values from [_seed] that [rendered] is showing.
List<String> _leaks(List<String> rendered) => [
      for (final secret in [
        ..._realNames,
        ..._realEmails,
        ..._realPhones,
        _realAddress,
      ])
        for (final line in rendered)
          if (line.contains(secret)) '"$secret" in "$line"',
    ];

Future<void> _pumpDirectory(
  WidgetTester tester, {
  required FakeWorkspaceRepository workspace,
  required FakeProfileRepository profile,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        timeZoneMode: TimeZoneMode.device,
        workspace: workspace,
        profile: profile,
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Members'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('filming mode: no real person is anywhere on the frame '
      '(#1514)', (tester) async {
    final seed = _seed(filming: true);
    await _pumpDirectory(
      tester,
      workspace: seed.workspace,
      profile: seed.profile,
    );

    final rendered = _renderedText(tester);
    expect(
      _leaks(rendered),
      isEmpty,
      reason: 'a real person reached the frame while filming mode was on. '
          'The seam is lib/core/privacy/recording_privacy.dart; whatever '
          'rendered this did not come through it.',
    );

    // Not merely blank: the page is still the page, showing invented
    // people, or the "recording" would be of an empty product.
    final shown = recordingPersonFor('member-2').fullName;
    expect(rendered.any((l) => l.contains(shown)), isTrue,
        reason: 'the directory must still show somebody — $shown');

    // And the strip that says so is on the frame, permanently.
    expect(find.byKey(RecordingBanner.bannerKey), findsOneWidget);
  });

  testWidgets('the same walk with filming mode OFF finds every one of '
      'them — so the rule can fail', (tester) async {
    final seed = _seed(filming: false);
    await _pumpDirectory(
      tester,
      workspace: seed.workspace,
      profile: seed.profile,
    );

    final leaks = _leaks(_renderedText(tester));
    expect(
      leaks,
      isNotEmpty,
      reason: 'with the flag off the directory shows the real names it is '
          'given. A rule that cannot fire is a gate nothing can trip.',
    );
    expect(find.byKey(RecordingBanner.bannerKey), findsNothing);
  });
}
