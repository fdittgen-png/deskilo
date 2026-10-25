// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2867 — the setup steps hold together with the rest of the app: every
// step reads in all five languages, opens a route the router registers,
// and the features the levels turn on are counted against the steps that
// set them up. The count is a ratchet: it may only fall, so a level
// feature added without a step shows up as one more.
import 'package:deskilo/app/route_classes.dart';
import 'package:deskilo/features/workspace/domain/setup_levels.dart';
import 'package:deskilo/features/workspace/domain/setup_step_reach.dart';
import 'package:deskilo/features/workspace/domain/setup_steps.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Level features no step reaches, on 2026-10-25: none. Every one is a
/// step's own, taken in by a step's page, or a switch with nothing to set
/// up (#2871, `setup_step_reach.dart`). It stays at zero.
const _withoutStepBaseline = 0;

/// Level features that are a switch with nothing to set up: once the
/// level turns them on they work, or each person chooses for themselves
/// (#2871). Every other level feature is a step's own or taken in by a
/// step's page (`setupStepTakesIn`).
const _switches = <WorkspaceFeature>{
  // Booking and the plan read what is already set up.
  WorkspaceFeature.seriesBooking,
  WorkspaceFeature.seatDayTimeline,
  WorkspaceFeature.calendarFileExport,
  WorkspaceFeature.autoCheckInOut,
  WorkspaceFeature.capacityKpi,
  WorkspaceFeature.singleRoomLevelNames,
  WorkspaceFeature.planMemberPhotos,
  WorkspaceFeature.uniqueMonograms,
  // Owner delegations: the switch is the decision.
  WorkspaceFeature.bookForOthers,
  WorkspaceFeature.adminLevelAssign,
  WorkspaceFeature.adminSeatBlocking,
  WorkspaceFeature.adminInvoicing,
  // The community, the calendar and the messenger as members use them.
  WorkspaceFeature.membersDirectory,
  WorkspaceFeature.personalInfo,
  WorkspaceFeature.memberPage,
  WorkspaceFeature.memberOrigin,
  WorkspaceFeature.guestParticipation,
  WorkspaceFeature.whatsappIntegration,
  WorkspaceFeature.calendarTab,
  WorkspaceFeature.calendarHub,
  WorkspaceFeature.calendarViews,
  WorkspaceFeature.calendarValidations,
  WorkspaceFeature.eventsTab,
  WorkspaceFeature.notificationGrouping,
  WorkspaceFeature.messagesHub,
  WorkspaceFeature.richMessageRefs,
  WorkspaceFeature.messageGestures,
  WorkspaceFeature.messageForwarding,
  WorkspaceFeature.messageMentions,
  WorkspaceFeature.captureProtection,
  // Money read and worked through, from what pricing and invoicing hold.
  WorkspaceFeature.dataAccessLog,
  WorkspaceFeature.financeFaces,
  WorkspaceFeature.memberReports,
  WorkspaceFeature.workspaceStatus,
  WorkspaceFeature.usageReport,
  WorkspaceFeature.usageRecords,
  WorkspaceFeature.invoiceSettlement,
  WorkspaceFeature.invoiceJourney,
  WorkspaceFeature.invoicingWizard,
  WorkspaceFeature.settlementFold,
  // The app's own surfaces and each person's preferences.
  WorkspaceFeature.formHelpHints,
  WorkspaceFeature.setupGuide,
  WorkspaceFeature.memberGettingStarted,
  WorkspaceFeature.placeFeedback,
  WorkspaceFeature.uiAnimations,
  WorkspaceFeature.regionalFormats,
  WorkspaceFeature.navigationStyle,
  WorkspaceFeature.memberAccountMenu,
  WorkspaceFeature.demoMode,
  WorkspaceFeature.documents,
  WorkspaceFeature.pdfExport,
  WorkspaceFeature.memberDataExport,
  WorkspaceFeature.workspaceOverview,
  WorkspaceFeature.decisionSurface,
  WorkspaceFeature.biReportDesigner,
  WorkspaceFeature.taskRecorder,
  WorkspaceFeature.recordingPrivacy,
  // The twin is made, and deployed to, where it is used; the server
  // wizard runs on the device, outside any space.
  WorkspaceFeature.environmentPairs,
  WorkspaceFeature.deployments,
  WorkspaceFeature.instanceWizard,
};

Set<WorkspaceFeature> _levelled() => {
  for (final levels in setupLevels.values)
    for (final level in levels) ...level.features,
};

Set<WorkspaceFeature> _withoutStep() => _levelled().difference({
  for (final s in setupSteps)
    if (s.feature != null) s.feature!,
  for (final taken in setupStepTakesIn.values) ...taken,
  ..._switches,
});

void main() {
  test('every step has its title and its hint in all five languages', () {
    final missing = [
      for (final locale in AppLocalizations.supportedLocales)
        for (final s in setupSteps)
          if (lookupAppLocalizations(locale) case final l10n)
            for (final (what, text) in [
              ('title', l10n.setupStepTitle(s.id)),
              ('hint', l10n.setupStepHint(s.id)),
            ])
              if (text == s.id || text.trim().isEmpty)
                '${locale.languageCode}: ${s.id} $what',
    ];
    expect(missing, isEmpty, reason: 'add the step to setup_guide_*.arb');
  });

  test('every step opens a route the router registers', () {
    final unknown = [
      for (final s in setupSteps)
        if (!routeRules.any((r) => r.matches(Uri.parse(s.route).path)))
          '${s.id} → ${s.route}',
    ];
    expect(unknown, isEmpty);
  });

  test('the level features without a step only ever get fewer', () {
    final count = _withoutStep().length;
    expect(
      count,
      lessThanOrEqualTo(_withoutStepBaseline),
      reason:
          'a feature joined a level without a step: take it in on the step '
          'that sets it up, or name it as a switch with nothing to set up '
          '(setupStepTakesIn, _switches). Without a step: '
          '${(_withoutStep().map((f) => f.name).toList()..sort()).join(', ')}',
    );
    expect(
      count,
      _withoutStepBaseline,
      reason: 'a step took a feature in: lower _withoutStepBaseline to $count',
    );
  });

  test('the ratchet counts what it says: no feature a step names is among '
      'those without', () {
    final named = {
      for (final s in setupSteps)
        if (s.feature != null) s.feature!,
    };
    expect(named, isNotEmpty);
    expect(_withoutStep().intersection(named), isEmpty);
  });

  test('the reach names real steps, and each feature has one home', () {
    final ids = {for (final s in setupSteps) s.id};
    expect(setupStepTakesIn.keys.where((id) => !ids.contains(id)), isEmpty);
    final own = {
      for (final s in setupSteps)
        if (s.feature != null) s.feature!,
    };
    final homes = <WorkspaceFeature, List<String>>{};
    for (final MapEntry(key: id, value: fs) in setupStepTakesIn.entries) {
      for (final f in fs) {
        (homes[f] ??= []).add(id);
      }
    }
    expect(
      [
        for (final MapEntry(key: f, value: ids) in homes.entries)
          if (ids.length > 1 || own.contains(f) || _switches.contains(f))
            f.name,
      ],
      isEmpty,
      reason: "a feature is a step's own, taken in by one step, or a switch",
    );
    expect(_switches.intersection(own), isEmpty);
  });

  test('the reach and the switches name only level features', () {
    final levelled = _levelled();
    expect(
      [
        for (final f in {
          for (final taken in setupStepTakesIn.values) ...taken,
          ..._switches,
        })
          if (!levelled.contains(f)) f.name,
      ],
      isEmpty,
    );
  });
}
