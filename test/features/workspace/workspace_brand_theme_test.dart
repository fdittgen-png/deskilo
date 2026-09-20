// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1289 — the theme reads the workspace's seed only through the flag,
// and a test that injects nothing sees the product palette.
import 'package:deskilo/app/theme.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

Future<int?> _seed(
  WidgetTester tester, {
  required Map<String, dynamic> branding,
  required bool flagOn,
}) async {
  final workspace = FakeWorkspaceRepository.withWorkspace(
    featureFlags: {'workspaceBranding': flagOn},
  );
  workspace.workspaces[0] = workspace.workspaces[0].copyWith(branding: branding);
  int? read;
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(workspace: workspace),
      child: Consumer(
        builder: (context, ref, _) {
          read = ref.watch(workspaceBrandSeedProvider);
          return const SizedBox();
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return read;
}

void main() {
  testWidgets('flag on and a seed chosen: the seed', (tester) async {
    expect(
      await _seed(tester, branding: {'seed_color': '#1F3A5F'}, flagOn: true),
      0xFF1F3A5F,
    );
  });

  testWidgets('flag off: the product palette, whatever is stored',
      (tester) async {
    expect(
      await _seed(tester, branding: {'seed_color': '#1F3A5F'}, flagOn: false),
      isNull,
    );
  });

  testWidgets('flag on and nothing chosen: the product palette',
      (tester) async {
    expect(await _seed(tester, branding: const {}, flagOn: true), isNull);
  });

  test('the flag is off by default, so every existing test sees the '
      'product colours', () {
    expect(featureManifest[WorkspaceFeature.workspaceBranding]!.defaultOn,
        isFalse);
  });

  test('#1289 — the derivation keeps every pair readable, and the refusal '
      'is the guard that says so before a colour is written', () {
    // Measured over 54 candidate seeds (brand_seed_survey_test): the
    // derivation nudges each label against the fill it ends on, so a
    // hex colour does not produce an unreadable scheme. The refusal is
    // not decoration: it runs at the import, and a change to the
    // derivation that stopped ensuring a pair would be caught here
    // rather than by a member who cannot read the screen.
    expect(DeskiloTheme.refusals(const Color(0xFFC2410C)), isEmpty);
    expect(DeskiloTheme.refusals(const Color(0xFFFACC15)), isEmpty);
    expect(DeskiloTheme.refusals(const Color(0xFF1F3A5F)), isEmpty);
  });
}
