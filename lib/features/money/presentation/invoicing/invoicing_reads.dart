// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-d -- one reader for the invoicing screens: the home and the
// invoice page read an invoice the same way, from the same matches,
// reminders, rules, holds, transmissions and payment events, so the page
// and the line it was opened from cannot say two different things.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/time/clock.dart';
import '../../domain/dunning.dart';
import '../../providers/money_providers.dart';
import '../widgets/invoice_journey_view.dart';
import 'receivables_adapter.dart';

/// The reader of the invoices as receivables, now.
final invoicingReaderProvider = Provider.autoDispose<ReceivablesReader>(
  (ref) => ReceivablesReader(
    matches: ref.watch(invoiceMatchesProvider).value ?? const {},
    reminders: ref.watch(invoiceRemindersProvider).value ?? const {},
    rules: ref.watch(dunningRulesProvider).value ?? DunningRules.defaults,
    now: ref.watch(clockProvider).now(),
    // The business's calendar day, from the workspace's own context.
    dayOf: ref.watch(invoicingBusinessProvider).dayOf,
    eventFactsOf: ref.watch(invoiceEventFactsProvider),
    transmissions: ref.watch(invoiceTransmissionsProvider).value ?? const {},
    held: {...?ref.watch(dunningHoldsProvider).value?.keys},
  ),
);
