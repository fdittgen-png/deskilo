// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2561 L4 -- the selected workspace's context in a widget test: the same
// shape the app captures (person, target, epochs, settings, calendar, tax
// reference), built from the in-memory repository instead of a resolved
// host, so the calendar providers that now read the context see the fake's
// open days, hours and closures.
import 'package:deskilo/core/backend/operation_context.dart';
import 'package:deskilo/core/settings/settings.dart';
import 'package:deskilo/core/settings/settings_capture.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/core/vat/tax_reference_snapshot.dart';
import 'package:deskilo/features/workspace/domain/booking_rules_repository.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/misc.dart';

/// Overrides [workspaceContextProvider] with a context over [rules], on
/// [installationId]. The tax reference is the snapshot the test runs on.
Override testWorkspaceContext(
  BookingRulesRepository rules, {
  required String installationId,
}) =>
    workspaceContextProvider.overrideWith((ref) async {
      final personalAnswer = ref.watch(personalContextProvider.future);
      final workspaceAnswer = ref.watch(currentWorkspaceProvider.future);
      final person = await personalAnswer;
      final workspace = await workspaceAnswer;
      if (person == null || workspace == null) return null;
      return WorkspaceContext(
        identity: person.identity,
        target: WorkspaceTarget.local(
          installationId: installationId,
          workspaceId: workspace.id,
        ),
        workspaceLocalUserId: person.personalLocalUserId,
        personalEpoch: person.personalEpoch,
        workspaceEpoch: 1,
        settings: SettingsCapture(
          SettingsIdentity(
            installation: installationId,
            workspaceId: workspace.id,
            principal: person.personalLocalUserId,
          ),
          SettingsSet.defaults(const []),
        ),
        calendar: await captureWorkspaceCalendar(
          rules,
          workspace.id,
          workspace.timezone,
        ),
        taxReference: TaxReferenceSnapshot(ActiveTaxReference.current),
      );
    });
