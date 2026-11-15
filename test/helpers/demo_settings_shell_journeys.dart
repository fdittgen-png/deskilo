// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3964 (c) — the settings and the shell of the reference business, each
// performed the way a persona performs it: the member's account menu, the
// push line a notice travels on, the navigation a person chooses, a setting
// the owner changes, the configuration that travels in a file, the hint a
// person dismisses, the setup guide and the getting-started card the
// business holds, the formats a member chooses, and the wizard's route.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/app/route_policy.dart';
import 'package:deskilo/core/demo/data/settings_repository.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/core/demo/demo_setting_seed.dart';
import 'package:deskilo/core/demo/demo_space_ids.dart';
import 'package:deskilo/core/help/help_hint_providers.dart';
import 'package:deskilo/core/i18n/format_controller.dart';
import 'package:deskilo/core/i18n/format_prefs.dart';
import 'package:deskilo/core/navigation/navigation_style.dart';
import 'package:deskilo/core/settings/settings.dart';
import 'package:deskilo/features/profile/providers/profile_providers.dart';
import 'package:deskilo/features/reservations/application/getting_started_hint.dart';
import 'package:deskilo/features/workspace/domain/configuration_refusal.dart';
import 'package:deskilo/features/workspace/domain/notification_lines.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/domain/workspace_xml.dart';
import 'package:deskilo/features/workspace/providers/local_setup_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';

Workspace _space(DemoFixture f, String id) =>
    f.workspaces.workspaces.firstWhere((w) => w.id == id);

Set<WorkspaceFeature> _featuresOf(Workspace w) =>
    effectiveFeatures(resolveEnabledFeatures(w.featureFlags));

Future<Set<WorkspacePermission>> _permissionsOf(
  DemoFixture f,
  DemoPersona persona,
) async {
  f.becomePersona(persona);
  final member = await f.workspaces.fetchMyMember('ws-1');
  return effectivePermissions(member, _space(f, 'ws-1'));
}

/// A member sees "Account" where the others see Settings: the menu entry is
/// the member's own and asks for the feature and for nothing but everyday
/// permissions.
Future<bool> accountMenuJourney() async {
  final f = DemoFixture.build();
  final features = _featuresOf(_space(f, 'ws-1'));
  final asMember = await _permissionsOf(f, DemoPersona.member);
  bool shows(Set<WorkspacePermission> p, Set<WorkspaceFeature> on) =>
      showsMemberAccountMenu(features: on, permissions: p);
  return shows(asMember, features) &&
      !shows(await _permissionsOf(f, DemoPersona.admin), features) &&
      !shows(await _permissionsOf(f, DemoPersona.owner), features) &&
      !shows(
        asMember,
        {...features}..remove(WorkspaceFeature.memberAccountMenu),
      );
}

/// The notices the reference business sends travel on the push channel, and
/// not on it in a business that has the feature off.
bool pushLinesState() {
  final on = _featuresOf(_space(DemoFixture.build(), 'ws-1'));
  bool pushed(Set<WorkspaceFeature> f) => notificationLines(f).any(
    (l) =>
        l.event == 'pending_request' &&
        l.channels.contains(NotificationChannel.push),
  );
  return pushed(on) &&
      !pushed({...on}..remove(WorkspaceFeature.pushNotifications));
}

ProviderContainer _container(DemoFixture f) =>
    ProviderContainer(overrides: demoOverrides(f));

/// Bruno, who holds the everyday permissions on a phone, gets the bar by
/// default and the owner the menu; Bruno chooses the menu, and choosing
/// nothing brings the default back.
Future<bool> navigationJourney() async {
  final f = DemoFixture.build()..becomePersona(DemoPersona.member);
  final container = _container(f);
  try {
    final byDefault = defaultNavigationStyle(isPhone: true, everydayOnly: true);
    final owners = defaultNavigationStyle(isPhone: true, everydayOnly: false);
    final controller = container.read(
      navigationStyleControllerProvider.notifier,
    );
    await controller.set(NavigationStyle.menu);
    final chosen = await container.read(
      navigationStyleControllerProvider.future,
    );
    final stored = await f.prefs.navigationStyle.read();
    await controller.set(null);
    final cleared = await f.prefs.navigationStyle.read();
    return byDefault == NavigationStyle.classic &&
        owners == NavigationStyle.menu &&
        chosen == NavigationStyle.menu &&
        stored == NavigationStyle.menu.wire &&
        cleared == null &&
        !shellUsesMenu(platformIsWeb: false, fallback: byDefault) &&
        shellUsesMenu(platformIsWeb: false, override: chosen);
  } finally {
    container.dispose();
  }
}

/// The settings catalogue as the app ships it, read from its file, over the
/// Demo's own seed.
FakeSettingsRepository _settings() => FakeSettingsRepository.fromLoader(
  () async => [
    for (final row in jsonDecode(
      File('assets/instance/settings_registry.json').readAsStringSync(),
    ) as List<dynamic>)
      SettingDefinition.fromJson(row),
  ],
  seed: demoSettingSeed,
);

/// Ada changes how many days back a bank movement is matched to an invoice,
/// for her business alone; the value is read back with its origin, a value
/// out of its bounds and a guardrail are refused, and another business keeps
/// its own.
Future<bool> settingsJourney() async {
  final repo = _settings();
  const key = 'bank.match_window_days';
  final before = await repo.load('ws-1');
  await repo.setValue(workspaceId: 'ws-1', key: key, value: 90);
  final after = await repo.load('ws-1');
  final other = await repo.load('ws-2');
  Future<bool> refused(String k, Object v) async {
    try {
      await repo.setValue(workspaceId: 'ws-1', key: k, value: v);
      return false;
    } on ArgumentError {
      return true;
    }
  }

  final guardrail = repo.definitions.values.firstWhere((d) => !d.editable);
  return before.origins[key] == SettingOrigin.registryDefault &&
      after.origins[key] == SettingOrigin.workspace &&
      after.effective[key] == 90 &&
      other.effective[key] == before.effective[key] &&
      await refused(key, 0) &&
      await refused(guardrail.key, guardrail.defaultValue);
}

List<Object?> _feeCents(Map<String, Object?> tree) => [
  for (final b in ((tree['tables']! as Map)['fee_bands']! as List))
    (b as Map)['fee_cents'],
];

/// Ada exports her business to a file and a second business reads the file
/// back: the settings, the plan and the configuration tree travel, and the
/// tree that is exported again is the one that was imported.
Future<bool> configurationTransferJourney() async {
  final f = DemoFixture.build()..becomePersona(DemoPersona.owner);
  final tree = await f.imports.exportConfiguration('ws-1');
  final levels = [
    for (final l in await f.floorPlan.fetchLevels('ws-1'))
      (level: l, plan: await f.floorPlan.fetchPlan(l.id)),
  ];
  final xml = buildWorkspaceXml(
    workspace: _space(f, 'ws-1'),
    levels: levels,
    configuration: tree,
  );
  final read = parseWorkspaceXml(xml);
  await f.imports.importConfiguration('ws-2', read.configuration!);
  return _feeCents(tree).isNotEmpty &&
      read.settings.name == _space(f, 'ws-1').name &&
      read.levels.length == levels.length &&
      listEquals(
        _feeCents(await f.imports.exportConfiguration('ws-2')),
        _feeCents(tree),
      );
}

/// #4028 — the London house restores the head's file: the head counts in
/// euros and London in pounds, so the head's fee bands stay out of London,
/// and the answer says so with both currencies; London's own export states
/// pounds.
Future<bool> configurationFromAnotherCurrencyJourney() async {
  final f = DemoFixture.build()..becomePersona(DemoPersona.owner);
  final head = _space(f, 'ws-1');
  final tree = await f.imports.exportConfiguration(head.id);
  final xml = buildWorkspaceXml(
    workspace: head,
    levels: const [],
    configuration: tree,
  );
  final read = parseWorkspaceXml(xml);
  final refused = await f.imports
      .importConfiguration(demoLondonSpaceId, read.configuration!);
  final london = await f.imports.exportConfiguration(demoLondonSpaceId);
  return _feeCents(tree).isNotEmpty &&
      refused.any((r) =>
          r.entity == 'tariffs' &&
          r.code == ConfigurationRefusalCode.currency &&
          r.source == head.currencyCode &&
          r.target == 'GBP') &&
      (((london['tables'] as Map?)?['fee_bands'] as List?)?.isEmpty ?? true) &&
      (london['workspace'] as Map?)?['currency_code'] == 'GBP';
}

/// A hint a person dismisses stays dismissed on the device, and the one
/// button that brings the hints back brings them back.
Future<bool> helpHintsJourney() async {
  final f = DemoFixture.build();
  final container = _container(f);
  try {
    final hints = container.read(dismissedHelpHintsProvider.notifier);
    await container.read(dismissedHelpHintsProvider.future);
    await hints.dismiss('demo-hint');
    final stored = Set.of(f.prefs.helpHints.dismissed);
    await hints.restoreAll();
    return stored.contains('demo-hint') && f.prefs.helpHints.dismissed.isEmpty;
  } finally {
    container.dispose();
  }
}

/// The setup guide of the reference business: its steps are done or still
/// to do by its own records, read through the guide's own provider.
Future<bool> setupGuideJourney() async {
  final f = DemoFixture.build();
  final container = _container(f);
  try {
    final status = await container.read(
      workspaceSetupStatusProvider('ws-1').future,
    );
    return status.done.isNotEmpty;
  } finally {
    container.dispose();
  }
}

/// The Get started card on Reserve: Bruno, who has not booked, is pointed
/// to choosing a time over the seats the business holds; once a booking of
/// his stands, the card points to his membership instead.
Future<bool> gettingStartedJourney() async {
  final f = DemoFixture.build()..becomePersona(DemoPersona.member);
  final seats = f.floorPlan.seats.length;
  GettingStartedFacts facts(BookingEvidence? booking) => GettingStartedFacts(
    membership: const Fact.ready(MembershipStanding.member),
    workspaceName: _space(f, 'ws-1').name,
    production: true,
    dayOpen: const Fact.ready(true),
    bookableSpaces: Fact.ready(seats),
    allowance: const Fact.ready(1),
    ownBooking: Fact.ready(booking),
  );
  final mine = f.reservations.reservations.firstWhere(
    (r) => r.memberId == 'member-2',
  );
  final fresh = chooseGettingStartedHint(facts(null), dismissed: false);
  final booked = chooseGettingStartedHint(
    facts(BookingEvidence(id: mine.id, state: mine.status.name)),
    dismissed: false,
  );
  return seats > 0 &&
      fresh?.action == GettingStartedAction.chooseTime &&
      booked?.action == GettingStartedAction.viewMembership &&
      chooseGettingStartedHint(facts(null), dismissed: true) == null;
}

/// Bruno reads the business in its formats, chooses Swiss ones, and reads
/// the same business in them: the locale follows him, the currency stays
/// the business's.
Future<bool> regionalFormatsJourney() async {
  final f = DemoFixture.build()..becomePersona(DemoPersona.member);
  final container = _container(f)..listen(businessFormatProvider, (_, _) {});
  try {
    await container.read(currentWorkspaceProvider.future);
    await container.read(myProfileProvider.future);
    final before = container.read(businessFormatProvider);
    await container
        .read(myProfileEditsProvider)
        .saveFormatPrefs(const FormatPrefs(formatLocale: 'de_CH'));
    container.invalidate(myProfileProvider);
    await container.read(myProfileProvider.future);
    final after = container.read(businessFormatProvider);
    return before.locale != 'de_CH' &&
        after.locale == 'de_CH' &&
        after.currencyCode == before.currencyCode;
  } finally {
    container.dispose();
  }
}

/// Ada opens the instance wizard: the route policy lets her stay where the
/// business has the wizard on, and sends her to the server screen in a
/// business that has it off.
bool instanceWizardState() {
  final f = DemoFixture.build();
  bool stays(String id) => resolveDestination(
    const RouteRequest('/server/new-instance'),
    RouteFacts(
      auth: AuthFact.signedIn,
      featureEnabled: _featuresOf(_space(f, id)).contains,
    ),
  ).stays;

  return stays('ws-1') && !stays('ws-2');
}
