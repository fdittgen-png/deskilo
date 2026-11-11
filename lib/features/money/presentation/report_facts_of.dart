// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1061 slice two — the ONLY place the document facts are read from the
// providers. Each gatherer is the `ref.read` prelude its builder used to
// carry, moved out unchanged, so the builder is a pure function.
//
// #3680 — a document is never built on a read that did not answer: a
// gatherer takes `requireValue`, which throws while a read runs or after it
// failed, so the action that prints says it failed instead of printing an
// agreement without its prices or a payment list without its payments.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../../core/time/work_hours.dart';
import '../../../l10n/app_localizations.dart';
import '../../events/providers/event_providers.dart';
import '../../plan/domain/desk.dart';
import '../../plan/domain/floor_plan.dart';
import '../../plan/domain/office.dart';
import '../../plan/providers/accessory_providers.dart';
import '../../plan/providers/floor_plan_providers.dart';
import '../../workspace/presentation/feature_names.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/package.dart';
import '../domain/report_data_sample.dart';
import '../domain/report_facts.dart';
import '../providers/money_providers.dart';

AgreementFacts agreementFactsOf(WidgetRef ref) {
  final levels = ref.read(levelsProvider).requireValue;
  return AgreementFacts(
    now: ref.read(clockProvider).now(),
    workspace: ref.read(currentWorkspaceProvider).value,
    bands: ref.read(feeBandsProvider).requireValue,
    services: ref.read(servicesProvider).requireValue,
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
    accessories: ref.read(accessoriesProvider()).requireValue,
    association: ref.read(sellerIsAssociationProvider),
  );
}

PaymentsFacts paymentsFactsOf(WidgetRef ref, String period) => PaymentsFacts(
      now: ref.read(clockProvider).now(),
      workspace: ref.read(currentWorkspaceProvider).value,
      me: ref.read(myMemberProvider).value,
      ledger: ref.read(myLedgerProvider).requireValue,
      events: ref.read(eventsProvider).requireValue,
      statement: ref.read(myStatementProvider(period)).value,
    );

WorkspaceFacts workspaceFactsOf(WidgetRef ref, AppLocalizations l10n) {
  final levels = ref.read(levelsProvider).requireValue;
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
    membersCount: ref.read(workspaceMembersProvider).requireValue.length,
    bands: ref.read(feeBandsProvider).requireValue,
    services: ref.read(servicesProvider).requireValue,
    openDays: ref.read(openWeekdaysProvider).requireValue,
    hours: WorkHours.current,
  );
}

/// #3680 — the agreement's facts READ, for an action that prints it: each
/// read is awaited (an auto-disposed read is not left half-loaded between a
/// warm-up and the build), and a failed one fails the action.
Future<AgreementFacts> readAgreementFacts(WidgetRef ref) async {
  final levels = await ref.read(levelsProvider.future);
  final plans = [
    for (final level in levels) await ref.read(floorPlanProvider(level.id).future),
  ];
  return AgreementFacts(
    now: ref.read(clockProvider).now(),
    workspace: ref.read(currentWorkspaceProvider).value,
    bands: await ref.read(feeBandsProvider.future),
    services: await ref.read(servicesProvider.future),
    packages: [
      for (final p in await ref.read(packagesProvider.future))
        if (p.active) p,
    ],
    levels: levels,
    offices: [for (final plan in plans) ...plan.offices],
    desks: [for (final plan in plans) ...plan.desks],
    accessories: await ref.read(accessoriesProvider().future),
    association: ref.read(sellerIsAssociationProvider),
  );
}

/// #3680 — the payments letter's facts READ, as [readAgreementFacts].
Future<PaymentsFacts> readPaymentsFacts(WidgetRef ref, String period) async =>
    PaymentsFacts(
      now: ref.read(clockProvider).now(),
      workspace: ref.read(currentWorkspaceProvider).value,
      me: ref.read(myMemberProvider).value,
      ledger: await ref.read(myLedgerProvider.future),
      events: await ref.read(eventsProvider.future),
      statement: await ref.read(myStatementProvider(period).future),
    );

/// #3680 — the workspace document's facts READ, as [readAgreementFacts].
Future<WorkspaceFacts> readWorkspaceFacts(
  WidgetRef ref,
  AppLocalizations l10n,
) async {
  final levels = await ref.read(levelsProvider.future);
  return WorkspaceFacts(
    now: ref.read(clockProvider).now(),
    workspace: ref.read(currentWorkspaceProvider).value,
    association: ref.read(sellerIsAssociationProvider),
    levels: levels,
    plans: [
      for (final level in levels)
        await ref.read(floorPlanProvider(level.id).future),
    ],
    featureLabels: [
      for (final feature in ref.read(enabledFeaturesSyncProvider))
        featureName(l10n, feature),
    ],
    membersCount: (await ref.read(workspaceMembersProvider.future)).length,
    bands: await ref.read(feeBandsProvider.future),
    services: await ref.read(servicesProvider.future),
    openDays: await ref.read(openWeekdaysProvider.future),
    hours: WorkHours.current,
  );
}

ReminderFacts reminderFactsOf(WidgetRef ref, Invoice invoice) => ReminderFacts(
      now: ref.read(clockProvider).now(),
      workspace: ref.read(currentWorkspaceProvider).value,
      memberTerms: memberTermsFor(ref, invoice.memberId),
    );

/// The setup guide's sample invoice: the current workspace, [seller] laid
/// over its stored identity, its line taxed as an issued one would be.
SampleInvoiceFacts sampleInvoiceFactsOf(WidgetRef ref, {SellerDraft? seller}) {
  final workspace = ref.read(currentWorkspaceProvider).value;
  return SampleInvoiceFacts(
    now: ref.read(clockProvider).now(),
    workspace: workspace,
    seller: seller,
    vatPercent: sampleVatPercentOf(
      seller?.vatRegime ?? workspace?.vatRegime ?? '',
      ref.read(vatRatesProvider).requireValue,
    ),
  );
}

/// #881 — the member's own payment conditions, from the members list
/// already loaded; null when they inherit the workspace's.
/// #1916 — the member's stated customer capacity (wire), null when not
/// stated or unknown here.
String? memberCapacityFor(WidgetRef ref, String memberId) => ref
    .read(workspaceMembersProvider)
    .value
    ?.where((m) => m.id == memberId)
    .firstOrNull
    ?.customerCapacity;

PaymentTerms? memberTermsFor(WidgetRef ref, String memberId) => ref
    .read(workspaceMembersProvider)
    .value
    ?.where((m) => m.id == memberId)
    .firstOrNull
    ?.paymentTerms;
