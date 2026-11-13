// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2867 — Attention's set-up lines read the setup guide's status when the
// guide is on: the steps its next milestone can take now, each opening its
// own screen. With the guide off they stay the readiness sections.
import 'package:deskilo/core/demo/data/local_setup_repository.dart';
import 'package:deskilo/features/workspace/domain/attention.dart';
import 'package:deskilo/features/workspace/domain/setup_status.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/domain/workspace_readiness.dart';
import 'package:deskilo/features/workspace/providers/attention_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/test_workspace_context.dart';

final _status = SetupStatus.fromJson({
  'steps': [
    {
      'step': 'basics',
      'milestone': 'bookable',
      'required': true,
      'state': 'ready',
      'route': '/workspace-settings',
    },
    {
      'step': 'places',
      'milestone': 'bookable',
      'required': true,
      'state': 'needs_configuration',
      'route': '/editor',
    },
    {
      'step': 'invite',
      'milestone': 'bookable',
      'required': false,
      'state': 'needs_configuration',
      'route': '/workspace-code',
    },
  ],
  'milestones': [
    {
      'milestone': 'bookable',
      'applies': true,
      'required': 2,
      'ready': 1,
      'reached': false,
    },
  ],
});

const _sections = [
  ReadinessSection(
    area: ReadinessArea.resources,
    state: ReadinessState.needsConfiguration,
    required: true,
    route: '/editor',
  ),
];

Future<List<Attention>> _lines({
  required bool guide,
  Workspace Function(Workspace)? shape,
}) async {
  final repo = FakeWorkspaceRepository.withWorkspace();
  if (shape != null) repo.workspaces[0] = shape(repo.workspaces[0]);
  final container = ProviderContainer(
    overrides: [
      ...standardTestOverrides(
        workspace: repo,
        localSetup: FakeLocalSetupRepository(
          status: _status,
          readinessSections: _sections,
        ),
      ),
      enabledFeaturesSyncProvider.overrideWithValue({
        if (guide) WorkspaceFeature.setupGuide,
      }),
      myPermissionsProvider.overrideWithValue(const {
        WorkspacePermission.manageConfiguration,
      }),
      testReadyWorkspaceContext(),
    ],
  );
  addTearDown(container.dispose);
  final keep = container.listen(attentionProvider, (_, _) {});
  addTearDown(keep.close);
  final all = await container.read(attentionProvider.future);
  return [
    for (final a in all)
      if (a.kind == AttentionKind.configuration &&
          a.action != AttentionAction.unblock)
        a,
  ];
}

void main() {
  test('with the guide on, the lines are the steps the next milestone can '
      'take now', () async {
    final lines = await _lines(guide: true);
    expect(
      [for (final l in lines) (l.action, l.subject, l.route)],
      [(AttentionAction.setUpStep, 'places', '/editor')],
      reason: 'basics is done and invite is optional',
    );
  });

  test('with the guide off, the lines stay the readiness sections', () async {
    final lines = await _lines(guide: false);
    expect(
      [for (final l in lines) (l.action, l.route)],
      [(AttentionAction.setUp, '/editor')],
    );
  });

  // #3850 — a Swiss business's document language, given by the server
  // (0753), waits for a configurer; saving it confirms it. Never blocking.
  test('a business whose document language waits for confirmation gets a '
      'to-do, and none once confirmed', () async {
    List<AttentionAction> confirm(List<Attention> lines) => [
          for (final l in lines)
            if (l.action == AttentionAction.confirmLanguage) l.action,
        ];
    final waiting = await _lines(
      guide: false,
      shape: (w) => w.copyWith(
          countryCode: 'CH', defaultLocale: 'de', documentLanguageConfirmed: false),
    );
    expect(confirm(waiting), [AttentionAction.confirmLanguage]);
    final confirmed = await _lines(
      guide: false,
      shape: (w) => w.copyWith(countryCode: 'CH', defaultLocale: 'de'),
    );
    expect(confirm(confirmed), isEmpty);
    // A country with one shipped language has nothing to choose.
    final france = await _lines(
      guide: false,
      shape: (w) => w.copyWith(countryCode: 'FR', documentLanguageConfirmed: false),
    );
    expect(confirm(france), isEmpty);
  });
}
