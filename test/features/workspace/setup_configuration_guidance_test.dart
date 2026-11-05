// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3282 — narrow screens keep review and apply usable with enlarged text;
// task context names the saved goal and its blocking dependency.
import 'package:deskilo/features/workspace/domain/setup_status.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_levels_screen.dart';
import 'package:deskilo/features/workspace/presentation/widgets/setup_configuration_overview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('choices stay usable at $width with enlarged French text', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const SetupLevelsScreen(),
        size: Size(width, 844),
        textScale: 2,
        locale: const Locale('fr'),
        overrides: standardTestOverrides(),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('setup-levels-apply')).hitTestable(),
        findsOneWidget,
      );
      // The review action scrolls to the real consequences without losing Apply.
      await tester.tap(find.byKey(const ValueKey('setup-choices-review')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('setup-levels-preview')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('setup-levels-apply')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'a task deep link identifies workspace, saved goal and dependency',
    (tester) async {
      final status = SetupStatus.fromJson({
        'steps': [
          {
            'step': 'online_payments',
            'milestone': 'money',
            'required': true,
            'state': 'blocked',
            'blocked_by': ['tiers'],
            'route': '/setup/step/online_payments',
          },
        ],
        'milestones': [
          {
            'milestone': 'money',
            'applies': true,
            'ready': 1,
            'required': 2,
            'reached': false,
          },
        ],
      });
      await pumpApp(
        tester,
        Scaffold(
          body: SetupTaskContext(
            workspaceName: 'Le Studio',
            stepId: 'online_payments',
            status: status,
          ),
        ),
        size: const Size(320, 640),
        textScale: 2,
      );
      await tester.pumpAndSettle();
      expect(find.text('Le Studio'), findsOneWidget);
      expect(
        find.textContaining('Ready for money · 1 of 2 done'),
        findsOneWidget,
      );
      expect(find.text('Waits for another step'), findsOneWidget);
      expect(find.textContaining('Waits for:'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
