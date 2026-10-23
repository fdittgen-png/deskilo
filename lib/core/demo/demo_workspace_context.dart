// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2561 L4 -- the demonstration's workspace context. The real provider
// resolves the selected workspace's host and reads its calendar and tax
// reference through that host's client; a demonstration has no host. Its
// context is the same shape over the space's own in-memory repository
// (routed per space, demo_space_routing.dart) and the tax reference snapshot
// the app installed from its bundled copy at start-up (a demonstration has
// no installation to read rows from), at Demo's one fictional installation.
import 'package:flutter_riverpod/misc.dart' show Override;

import '../../features/workspace/providers/settings_providers.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import '../backend/operation_context.dart';
import '../settings/settings.dart';
import '../settings/settings_capture.dart';
import '../vat/tax_reference_active.dart';
import '../vat/tax_reference_snapshot.dart';

/// [workspaceContextProvider] in a Demo scope at [installationId].
Override demoWorkspaceContext(String installationId) =>
    workspaceContextProvider.overrideWith((ref) async {
      final personalAnswer = ref.watch(personalContextProvider.future);
      final workspaceAnswer = ref.watch(currentWorkspaceProvider.future);
      // The settings join when they are read; the calendar does not wait
      // for them (a demonstration's are the bundled defaults).
      final settings = ref.watch(currentSettingsCaptureProvider).value;
      final rules = ref.watch(workspaceRepositoryProvider);
      final person = await personalAnswer;
      final workspace = await workspaceAnswer;
      if (person == null || workspace == null) return null;
      final calendar = captureWorkspaceCalendar(
        rules,
        workspace.id,
        workspace.timezone,
      );
      return WorkspaceContext(
        identity: person.identity,
        target: WorkspaceTarget.local(
          installationId: installationId,
          workspaceId: workspace.id,
        ),
        workspaceLocalUserId: person.personalLocalUserId,
        personalEpoch: person.personalEpoch,
        workspaceEpoch: 1,
        settings: settings ??
            SettingsCapture(
              SettingsIdentity(
                installation: installationId,
                workspaceId: workspace.id,
                principal: person.personalLocalUserId,
              ),
              SettingsSet.defaults(const []),
            ),
        calendar: await calendar,
        taxReference: TaxReferenceSnapshot(ActiveTaxReference.current),
      );
    });
