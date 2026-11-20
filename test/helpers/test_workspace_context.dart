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

WorkspaceContext _readyTestContext(String installationId) =>
    testWorkspaceContextOf(installation: installationId);

/// A workspace context a test builds with exactly the parts it wants to
/// differ: the person ([issuer], [subject]), the target ([installation],
/// [workspaceId]), the local account, and both epochs
/// (#4157 compares each of them).
WorkspaceContext testWorkspaceContextOf({
  String installation = 'inst-test',
  String workspaceId = 'ws',
  String issuer = 'https://test.local/auth/v1',
  String subject = 'p-1',
  String localUser = 'p-1',
  int personalEpoch = 1,
  int workspaceEpoch = 1,
}) => WorkspaceContext(
  identity: CanonicalIdentity(issuer: issuer, subject: subject),
  target: WorkspaceTarget.local(
    installationId: installation,
    workspaceId: workspaceId,
  ),
  workspaceLocalUserId: localUser,
  personalEpoch: personalEpoch,
  workspaceEpoch: workspaceEpoch,
  settings: SettingsCapture(
    SettingsIdentity(
      installation: installation,
      workspaceId: workspaceId,
      principal: localUser,
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

/// Which installation the selectable ready context is on ([testReadyContextOn]
/// reads it): a test sets it to switch installation while a confirmation is
/// open. The local workspace id stays the same on both, as it does between two
/// installations (#4157).
final testContextInstallation = NotifierProvider<_InstallationChoice, String>(
  _InstallationChoice.new,
);

class _InstallationChoice extends Notifier<String> {
  @override
  String build() => 'inst-a';

  void select(String installation) => state = installation;
}

/// A ready context that follows [testContextInstallation]: A until a test
/// selects another installation, with the same local workspace id.
Override testSelectableReadyWorkspaceContext() =>
    readyWorkspaceContextProvider.overrideWith(
      (ref) => _readyTestContext(ref.watch(testContextInstallation)),
    );
