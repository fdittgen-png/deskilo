// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3963 (c) — recording privacy and WhatsApp in the reference business.
// Recording privacy IS the mode (the flag is the only switch there is): on,
// every name the Demo prints is replaced by an invented one from the first
// screen, so the Demo keeps it off and says why; the owner can still turn it
// on for the session, and the cast returns when it is turned off. WhatsApp:
// the Demo opens with the space's group link, the owner changes it, and a
// member reads it where members read it.
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/seed/demo_flags.dart';
import 'package:deskilo/core/privacy/recording_privacy.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/demo_whatsapp_journeys.dart';

void main() {
  test('the stated reason says the flag is the mode itself', () {
    final reason = demoFeaturesLeftOff[WorkspaceFeature.recordingPrivacy]!;
    expect(reason, contains('the mode itself'));
    expect(reason, contains('turn it on'));
    expect(
      '. '.allMatches(reason).length,
      lessThanOrEqualTo(1),
      reason: 'one sentence',
    );
  });

  test(
    'the owner turns the mode on for the session, and the cast returns',
    () async {
      final f = DemoFixture.build();
      bool on() => resolveEnabledFeatures(
        f.workspaces.workspaces.firstWhere((w) => w.id == 'ws-1').featureFlags,
      ).contains(WorkspaceFeature.recordingPrivacy);
      expect(on(), isFalse, reason: 'the Demo opens with its own cast');
      final real = f.workspaces.memberNames['member-2']!;
      await f.workspaces.setFeatureFlags('ws-1', {'recordingPrivacy': true});
      expect(on(), isTrue);
      expect(recordingName('member-2', real), isNot(real));
      await f.workspaces.setFeatureFlags('ws-1', {'recordingPrivacy': false});
      expect(on(), isFalse);
      expect(f.workspaces.memberNames['member-2'], real);
    },
  );

  test('the Demo opens with a group link and a member reads it', () async {
    final f = DemoFixture.build();
    final seeded = whatsappGroupOf(f);
    expect(seeded, startsWith(WhatsappGroupRules.linkPrefix));
    expect(seeded.contains('example'), isFalse);
    f.becomePersona(DemoPersona.member);
    expect(whatsappGroupUriOf(f)?.toString(), seeded);
  });

  test('the owner stores a new group link and a member reads it', () async {
    expect(await whatsappJourney(), isTrue);
  });
}
