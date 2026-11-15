// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3964 (c) — the settings and the shell of the reference business, each a
// state or an action a persona performs (see the helper for each story).
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/demo_settings_shell_journeys.dart';

void main() {
  test(
    'a member sees Account instead of Settings, an owner and an admin do not',
    () async => expect(await accountMenuJourney(), isTrue),
  );
  test(
    'the notices travel on the push channel when the feature is on',
    () => expect(pushLinesState(), isTrue),
  );
  test(
    'the navigation: the default by who and what, a choice, and back',
    () async => expect(await navigationJourney(), isTrue),
  );
  test(
    'a setting is changed for one business, read with its origin, and '
    'refused out of bounds or on a guardrail',
    () async => expect(await settingsJourney(), isTrue),
  );
  test(
    'the configuration travels in a file and is read by another business',
    () async => expect(await configurationTransferJourney(), isTrue),
  );
  test(
    'a dismissed hint stays dismissed and the hints come back',
    () async => expect(await helpHintsJourney(), isTrue),
  );
  test(
    'the setup guide holds done steps by its own records',
    () async => expect(await setupGuideJourney(), isTrue),
  );
  test(
    'the getting-started card has sections to say',
    () async => expect(await gettingStartedJourney(), isTrue),
  );
  test(
    'a member reads the business in the formats they chose',
    () async => expect(await regionalFormatsJourney(), isTrue),
  );
  test(
    'the instance wizard route stays where the flag is on and leaves where '
    'it is off',
    () => expect(instanceWizardState(), isTrue),
  );
}
