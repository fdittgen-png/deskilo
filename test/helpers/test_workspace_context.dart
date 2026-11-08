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
import 'package:deskilo/core/time/work_hours.dart';
import 'package:deskilo/core/time/workspace_calendar.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/core/vat/tax_reference_snapshot.dart';
import 'package:deskilo/features/workspace/domain/booking_rules_repository.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

WorkspaceContext _readyTestContext(String installationId) => WorkspaceContext(
  identity: const CanonicalIdentity(
    issuer: 'https://test.local/auth/v1',
    subject: 'p-1',
  ),
  target: WorkspaceTarget.local(installationId: installationId, workspaceId: 'ws'),
  workspaceLocalUserId: 'p-1',
  personalEpoch: 1,
  workspaceEpoch: 1,
  settings: SettingsCapture(
    SettingsIdentity(
      installation: installationId,
      workspaceId: 'ws',
      principal: 'p-1',
    ),
    SettingsSet.defaults(const []),
  ),
  calendar: WorkspaceCalendar(
    timezone: 'Europe/Paris',
    openWeekdays: const [1, 2, 3, 4, 5, 6, 7],
    workHours: WorkHours.defaults,
    closures: const [],
  ),
  taxReference: TaxReferenceSnapshot(ActiveTaxReference.current),
);

/// A ready workspace context on the snapshot the test runs on, for a widget
/// test that builds its own overrides and only needs the workspace's tax
/// reference to be there (#3403).
Override testReadyWorkspaceContext({String installationId = 'inst-test'}) =>
    readyWorkspaceContextProvider.overrideWithValue(
      _readyTestContext(installationId),
    );

/// Whether [testSwitchableReadyWorkspaceContext] answers a context: a test
/// flips it to let the context go away while a screen is open.
final testContextReady = NotifierProvider<_ContextSwitch, bool>(
  _ContextSwitch.new,
);

class _ContextSwitch extends Notifier<bool> {
  @override
  bool build() => true;

  void set({required bool ready}) => state = ready;
}

/// A ready context that follows [testContextReady].
Override testSwitchableReadyWorkspaceContext({
  String installationId = 'inst-test',
}) => readyWorkspaceContextProvider.overrideWith(
  (ref) => ref.watch(testContextReady) ? _readyTestContext(installationId) : null,
);
