// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4178 (F4) -- the words of the engagement screens that more than one of them
// says: a state, what was ordered, where it came from, a refusal, an amount and a
// date. Pure over the localizations: the screens only place them.
import 'package:flutter/material.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/service_fulfilment.dart';

/// The state a person reads.
String engagementStateLabel(AppLocalizations l10n, FulfilmentState state) =>
    switch (state) {
      FulfilmentState.ordered => l10n.engagementStateOrdered,
      FulfilmentState.started => l10n.engagementStateStarted,
      FulfilmentState.done => l10n.engagementStateDone,
      FulfilmentState.cancelled => l10n.engagementStateCancelled,
    };

/// The label of the step that takes an engagement to [to].
String engagementStepLabel(AppLocalizations l10n, FulfilmentState to) =>
    switch (to) {
      FulfilmentState.started => l10n.engagementStart,
      FulfilmentState.done => l10n.engagementFinish,
      FulfilmentState.cancelled => l10n.engagementCancel,
      FulfilmentState.ordered => l10n.engagementStateOrdered,
    };

/// What was ordered: "3 session · Coaching".
String engagementScopeLine(FulfilmentScope scope) => [
  [scope.quantity, scope.unit].where((p) => p.isNotEmpty).join(' '),
  scope.description,
].where((p) => p.isNotEmpty).join(' · ');

/// Where the engagement came from.
String engagementSourceLine(AppLocalizations l10n, ServiceFulfilment e) {
  final quote = e.quote;
  if (e.source.kind == 'quote' && quote != null) {
    return l10n.engagementFromQuote(quote.reference ?? '');
  }
  if (e.source.kind == 'invoice' && e.invoices.isNotEmpty) {
    return l10n.engagementFromInvoice(e.invoices.first.number);
  }
  return l10n.engagementDirect;
}

/// What to say for a refusal of the server; nothing was written.
String engagementRefusalText(AppLocalizations l10n, FulfilmentRefusal refusal) =>
    switch (refusal.kind) {
      FulfilmentRefusalKind.stale => l10n.engagementRefusedStale,
      FulfilmentRefusalKind.state => l10n.engagementRefusedState,
      FulfilmentRefusalKind.requestReused => l10n.engagementRefusedReused,
      FulfilmentRefusalKind.incomplete => l10n.engagementRefusedIncomplete,
      FulfilmentRefusalKind.unknown => l10n.engagementRefusedUnknown,
      FulfilmentRefusalKind.featureOff => l10n.engagementRefusedOff,
      FulfilmentRefusalKind.notAllowed => l10n.engagementRefusedDenied,
    };

/// An amount in its own currency, in the reader's format.
String engagementAmount(BuildContext context, int cents, String currency) =>
    personalFormatOf(context).moneyNamed(currency).formatMinor(cents);

/// A day, in the reader's own locale and the business's clock.
String engagementDate(BuildContext context, DateTime d) => appFormatOf(context).date(d);
