// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/providers/event_providers.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/dunning.dart';
import '../../domain/invoice.dart';
import '../../providers/money_providers.dart';
import '../invoice_journey.dart';
import '../invoice_status.dart';

/// #812 — whether the process view is on for this workspace.
bool invoiceJourneyOn(WidgetRef ref) => ref
    .watch(enabledFeaturesSyncProvider)
    .contains(WorkspaceFeature.invoiceJourney);

/// The journey of [invoice] from the live providers, or null while the
/// feature is off — every surface then falls back to the plain chips.
InvoiceJourney? watchInvoiceJourney(
  WidgetRef ref,
  Invoice invoice, {
  required InvoiceMatch? match,
  required ({int count, DateTime last})? reminder,
  String replacedByNumber = '',
}) =>
    _journey(ref, invoice,
        watch: true,
        match: match,
        reminder: reminder,
        replacedByNumber: replacedByNumber);

/// The same, read once — for callbacks that open a sheet.
InvoiceJourney? readInvoiceJourney(
  WidgetRef ref,
  Invoice invoice, {
  required InvoiceMatch? match,
  required ({int count, DateTime last})? reminder,
  String replacedByNumber = '',
}) =>
    _journey(ref, invoice,
        watch: false,
        match: match,
        reminder: reminder,
        replacedByNumber: replacedByNumber);

InvoiceJourney? _journey(
  WidgetRef ref,
  Invoice invoice, {
  required bool watch,
  required InvoiceMatch? match,
  required ({int count, DateTime last})? reminder,
  required String replacedByNumber,
}) {
  final features = watch
      ? ref.watch(enabledFeaturesSyncProvider)
      : ref.read(enabledFeaturesSyncProvider);
  if (!features.contains(WorkspaceFeature.invoiceJourney)) return null;
  final rules = watch
      ? ref.watch(dunningRulesProvider).value
      : ref.read(dunningRulesProvider).value;
  final now =
      (watch ? ref.watch(clockProvider) : ref.read(clockProvider)).now();
  final events = watch
      ? ref.watch(eventsProvider).value
      : ref.read(eventsProvider).value;
  return InvoiceJourney.of(
    invoice: invoice,
    match: match,
    reminder: reminder,
    rules: rules ?? DunningRules.defaults,
    now: now,
    facts: journeyFactsOf(invoice, match, events ?? const []),
    replacedByNumber: replacedByNumber,
  );
}

String invoiceStepLabel(AppLocalizations l10n, InvoiceStep step) =>
    switch (step) {
      InvoiceStep.issued => l10n.journeyStepIssued,
      InvoiceStep.payment => l10n.journeyStepPayment,
      InvoiceStep.confirmation =>
        l10n.journeyStepConfirmation,
      InvoiceStep.closed => l10n.journeyStepClosed,
    };

/// The four steps as a bar: a dot per step joined by a line, done steps
/// filled, the current one ringed, the closed step of an erroneous
/// invoice crossed. Labels under the dots so the bar reads without a
/// legend.
class InvoiceJourneyBar extends StatelessWidget {
  const InvoiceJourneyBar({super.key, required this.journey});

  final InvoiceJourney journey;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final steps = journey.steps;
    final labelStyle = Theme.of(context).textTheme.labelSmall;
    return Semantics(
      label: [
        for (final step in InvoiceStep.values)
          '${invoiceStepLabel(l10n, step)}: ${steps[step]!.name}',
      ].join(', '),
      child: Row(
        key: const ValueKey('invoice-journey-bar'),
        children: [
          for (final (i, step) in InvoiceStep.values.indexed)
            Expanded(
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: i == 0
                        ? const SizedBox.shrink()
                        : _connector(scheme, steps[step]!),
                  ),
                  _Dot(state: steps[step]!),
                  Expanded(
                    child: i == InvoiceStep.values.length - 1
                        ? const SizedBox.shrink()
                        : _connector(
                            scheme,
                            steps[InvoiceStep.values[i + 1]]!,
                          ),
                  ),
                ]),
                const SizedBox(height: 2),
                Text(
                  invoiceStepLabel(l10n, step),
                  key: ValueKey('invoice-journey-step-${step.name}'),
                  style: labelStyle?.copyWith(
                    color: switch (steps[step]!) {
                      InvoiceStepState.current => scheme.primary,
                      InvoiceStepState.cancelled => scheme.error,
                      InvoiceStepState.done => scheme.onSurface,
                      InvoiceStepState.todo => scheme.outline,
                    },
                    fontWeight: steps[step] == InvoiceStepState.current
                        ? FontWeight.bold
                        : null,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ]),
            ),
        ],
      ),
    );
  }

  /// The line INTO a step takes that step's colour: reached steps draw a
  /// solid line, the rest a faint one.
  Widget _connector(ColorScheme scheme, InvoiceStepState into) => Container(
        height: 2,
        color: switch (into) {
          InvoiceStepState.done || InvoiceStepState.current => scheme.primary,
          InvoiceStepState.cancelled => scheme.error,
          InvoiceStepState.todo => scheme.outlineVariant,
        },
      );
}

class _Dot extends StatelessWidget {
  const _Dot({required this.state});

  final InvoiceStepState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const size = 18.0;
    return switch (state) {
      InvoiceStepState.done => Icon(
          Icons.check_circle,
          size: size,
          color: scheme.primary,
        ),
      InvoiceStepState.current => Icon(
          Icons.radio_button_checked,
          size: size,
          color: scheme.primary,
        ),
      InvoiceStepState.cancelled => Icon(
          Icons.cancel,
          size: size,
          color: scheme.error,
        ),
      InvoiceStepState.todo => Icon(
          Icons.radio_button_unchecked,
          size: size,
          color: scheme.outline,
        ),
    };
  }
}

/// The next move, in the reader's language and from the reader's side:
/// an issuer reads what the member does and what they do themselves; a
/// member reads "your move" when it is theirs.
String invoiceMoveText(
  BuildContext context,
  InvoiceJourney journey, {
  required Invoice invoice,
  required InvoiceMatch? match,
  required bool issuer,
}) {
  final l10n = context.l10n;
  final currency = moneyFormat(invoice.currency);
  final dateFormat = DateFormat.yMMMd(
    Localizations.maybeLocaleOf(context)?.toString(),
  );
  // #910 — the client, company included when there is no person.
  final name = invoice.clientName;
  final owed = currency.formatMinor(journey.remainingCents);
  final due = dateFormat.format(journey.dueOn);
  final late = -journey.daysToTerm;
  final declared = currency.formatMinor(journey.facts.declaredCents);
  final recorded = currency.formatMinor(journey.facts.recordedForMemberCents);
  final registered = currency.formatMinor(journey.facts.registeredCents);
  final refund = currency.formatMinor(-invoice.totalCents);
  return switch (journey.move) {
    InvoiceMove.memberPays when journey.overdue => issuer
        ? (l10n.journeyIssuerMemberPaysOverdue(name, owed, late))
        : (l10n.journeyMemberPaysOverdue(owed, late)),
    InvoiceMove.memberPays => issuer
        ? (l10n.journeyIssuerMemberPays(name, owed, due))
        : (l10n.journeyMemberPays(owed, due)),
    InvoiceMove.memberPaysRemainder => issuer
        ? (l10n.journeyIssuerMemberPaysRemainder(name, owed))
        : (l10n.journeyMemberPaysRemainder(owed)),
    InvoiceMove.adminConfirmsPayment => issuer
        ? (l10n.journeyIssuerAdminConfirms(name, declared))
        : (l10n.journeyMemberDeclared(declared)),
    InvoiceMove.memberConfirmsPayment => issuer
        ? (l10n.journeyIssuerMemberConfirms(name, recorded))
        : (l10n.journeyMemberConfirms(recorded)),
    InvoiceMove.issuerMatchesPayment => issuer
        ? (l10n.journeyIssuerMatches(registered))
        : (l10n.journeyMemberRegistered(registered)),
    InvoiceMove.validatorsDecideMatch => issuer
        ? (l10n.journeyValidatorsMatch)
        : (l10n.journeyMemberValidators),
    InvoiceMove.validatorsDecideWriteoff => issuer
        ? (l10n.journeyValidatorsWriteoff)
        : (l10n.journeyMemberWriteoff),
    InvoiceMove.issuerRefunds => issuer
        ? (l10n.journeyIssuerRefunds(name, refund))
        : (l10n.journeyMemberRefund(refund)),
    InvoiceMove.issuerReplaces => issuer
        ? (l10n.journeyIssuerReplaces)
        : (l10n.journeyMemberReplaces),
    InvoiceMove.none => _closedText(l10n, journey, match, dateFormat),
  };
}

String _closedText(
  AppLocalizations l10n,
  InvoiceJourney journey,
  InvoiceMatch? match,
  DateFormat dateFormat,
) {
  if (journey.settled) {
    return l10n.journeyClosedSettled;
  }
  final on = match == null ? '' : dateFormat.format(match.matchedAt);
  return switch (journey.lifecycle) {
    InvoiceLifecycle.paid =>
      l10n.journeyClosedPaid(on),
    InvoiceLifecycle.remainderCancelled => l10n.journeyClosedRemainder(
          match?.writeoffAt == null ? on : dateFormat.format(match!.writeoffAt!),
        ),
    InvoiceLifecycle.refunded =>
      l10n.journeyClosedRefunded(on),
    _ => l10n.journeyClosedReplaced(journey.replacedByNumber),
  };
}

/// The move as one line: an icon for WHO moves, the sentence, error tone
/// when the member is late, primary tone when it is the reader's own
/// move.
class InvoiceMoveLine extends StatelessWidget {
  const InvoiceMoveLine({
    super.key,
    required this.journey,
    required this.invoice,
    required this.match,
    required this.issuer,
  });

  final InvoiceJourney journey;
  final Invoice invoice;
  final InvoiceMatch? match;

  /// Whether the reader issues invoices (their side of the sentence).
  final bool issuer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mine = switch (journey.move.who) {
      InvoiceMover.issuer => issuer,
      InvoiceMover.member => !issuer,
      _ => false,
    };
    final color = journey.overdue
        ? scheme.error
        : mine
            ? scheme.primary
            : scheme.onSurfaceVariant;
    final icon = switch (journey.move.who) {
      InvoiceMover.member => Icons.person_outline,
      InvoiceMover.issuer => Icons.admin_panel_settings_outlined,
      InvoiceMover.validators => Icons.how_to_vote_outlined,
      InvoiceMover.nobody => Icons.check_circle_outline,
    };
    return Row(
      key: const ValueKey('invoice-move-line'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            invoiceMoveText(
              context,
              journey,
              invoice: invoice,
              match: match,
              issuer: issuer,
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: mine || journey.overdue ? FontWeight.w600 : null,
                ),
          ),
        ),
      ],
    );
  }
}
