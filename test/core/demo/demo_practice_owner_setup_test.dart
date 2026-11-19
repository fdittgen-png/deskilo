// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3547 — the Demo practice owner at a desk, and a coworking space (Leipzig)
// as the control: the practice's guide names its own task, a coworking
// space's keeps the words of its places.
import 'package:deskilo/core/demo/demo_space_ids.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:deskilo/l10n/dictionary_labels.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/demo_practice_owner_walk.dart';

void main() {
  testWidgets('the Demo practice owner at a desk: the same', (tester) async {
    await walkPracticeOwnerSetup(tester, const Size(1440, 900));
  });

  testWidgets('a coworking space (Leipzig) keeps the words of its places in '
      'the guide', (tester) async {
    final words = AppLocalizationsEn();
    final (_, container, router) = await openDemoSpaceAsOwner(
      tester,
      space: 'leipzig',
      size: const Size(1440, 900),
    );
    expect(
      container.read(currentWorkspaceProvider).value?.id,
      demoSecondSpaceId,
    );
    router.go('/setup/step/services');
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text(words.setupStepHint('services')), findsOneWidget);
    expect(find.text(words.setupStepHintServicesNoPlaces), findsNothing);
  });
}
