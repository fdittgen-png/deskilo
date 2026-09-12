// SPDX-License-Identifier: 0BSD
//
// #1061 slice two — the ONLY place the document facts are read from the
// providers. Each gatherer is the `ref.read` prelude its builder used to
// carry, moved out unchanged, so the builder is a pure function.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../../core/time/work_hours.dart';
import '../../../l10n/app_localizations.dart';
import '../../events/domain/workspace_event.dart';
import '../../events/providers/event_providers.dart';
import '../../plan/domain/accessory.dart';
import '../../plan/domain/desk.dart';
import '../../plan/domain/floor_plan.dart';
import '../../plan/domain/level.dart';
import '../../plan/domain/office.dart';
import '../../plan/providers/accessory_providers.dart';
import '../../plan/providers/floor_plan_providers.dart';
import '../../workspace/presentation/feature_names.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/fee_band.dart';
import '../domain/invoice.dart';
import '../domain/ledger_entry.dart';
import '../domain/package.dart';
import '../domain/report_facts.dart';
import '../domain/service_item.dart';
import '../providers/money_providers.dart';
import 'invoice_documents.dart' show memberTermsFor;

AgreementFacts agreementFactsOf(WidgetRef ref) {
  final levels = ref.read(levelsProvider).value ?? const <Level>[];
  return AgreementFacts(
    now: ref.read(clockProvider).now(),
    workspace: ref.read(currentWorkspaceProvider).value,
    bands: ref.read(feeBandsProvider).value ?? const <FeeBand>[],
    services: ref.read(servicesProvider).value ?? const <ServiceItem>[],
    packages: (ref.read(packagesProvider).value?.where((p) => p.active) ??
            const <Package>[])
        .toList(),
    levels: levels,
    offices: [
      for (final level in levels)
        ...(ref.read(floorPlanProvider(level.id)).value?.offices ??
            const <Office>[]),
    ],
    // #638 — DESKS are priced (0059), billed (`desk_supplement_cents`)
    // and shown on the bill as "Desk reservations": the agreement
    // disclosed every other scale but this one, so a member could be
    // charged a price their own agreement never named.
    desks: [
      for (final level in levels)
        ...(ref.read(floorPlanProvider(level.id)).value?.desks ??
            const <Desk>[]),
    ],
    accessories: ref.read(accessoriesProvider()).value ?? const <Accessory>[],
    association: ref.read(sellerIsAssociationProvider),
  );
}

PaymentsFacts paymentsFactsOf(WidgetRef ref, String period) => PaymentsFacts(
      now: ref.read(clockProvider).now(),
      workspace: ref.read(currentWorkspaceProvider).value,
      me: ref.read(myMemberProvider).value,
      ledger: ref.read(myLedgerProvider).value ?? const <LedgerEntry>[],
      events: ref.read(eventsProvider).value ?? const <WorkspaceEvent>[],
      statement: ref.read(myStatementProvider(period)).value,
    );

WorkspaceFacts workspaceFactsOf(WidgetRef ref, AppLocalizations? l10n) {
  final levels = ref.read(levelsProvider).value ?? const <Level>[];
  return WorkspaceFacts(
    now: ref.read(clockProvider).now(),
    workspace: ref.read(currentWorkspaceProvider).value,
    association: ref.read(sellerIsAssociationProvider),
    levels: levels,
    plans: [
      for (final level in levels) ref.read(floorPlanProvider(level.id)).value,
    ].whereType<FloorPlan>().toList(),
    featureLabels: [
      for (final feature in ref.read(enabledFeaturesSyncProvider))
        featureName(l10n, feature),
    ],
    membersCount: (ref.read(workspaceMembersProvider).value ?? const []).length,
    bands: ref.read(feeBandsProvider).value ?? const <FeeBand>[],
    services: ref.read(servicesProvider).value ?? const <ServiceItem>[],
    openDays: ref.read(openWeekdaysProvider).value ?? const <int>[],
    hours: WorkHours.current,
  );
}

ReminderFacts reminderFactsOf(WidgetRef ref, Invoice invoice) => ReminderFacts(
      now: ref.read(clockProvider).now(),
      workspace: ref.read(currentWorkspaceProvider).value,
      memberTerms: memberTermsFor(ref, invoice.memberId),
    );
