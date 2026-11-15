// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4006 — Settings › Organisation is offered to an owner while the
// business has the organisation feature, and is gone with it off.
import 'package:deskilo/core/demo/data/workspace_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/screens/workspace_settings_screen.dart';

const _entry = ValueKey('workspace-settings-organisation');

void main() {
  for (final on in [true, false]) {
    testWidgets('with the organisation feature ${on ? 'on' : 'off'} the '
        'entry is ${on ? 'offered' : 'gone'}', (tester) async {
      await pumpWorkspaceSettings(
        tester,
        repository: FakeWorkspaceRepository.withWorkspace(
          featureFlags: {'organisation': on},
        ),
      );
      expect(find.byKey(_entry), on ? findsOneWidget : findsNothing);
    });
  }
}
