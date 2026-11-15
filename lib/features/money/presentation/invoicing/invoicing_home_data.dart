// SPDX-License-Identifier: AGPL-3.0-or-later
//
// What the invoicing home shows, as one value (moved out of
// invoicing_home.dart).
import 'package:flutter/material.dart';

import '../../application/receivables.dart';
import '../../application/receivables_answers.dart';
import 'invoicing_home.dart' show InvoicingSource;

/// What the home shows: the receivables on [today], the month [toInvoice],
/// the payments [received], the reminder [mode] and the sources that
/// [failed]. [currency] is the workspace's (what an empty card says in).
@immutable
class InvoicingHomeData {
  const InvoicingHomeData({
    required this.receivables,
    required this.today,
    required this.month,
    required this.currency,
    required this.mode,
    this.toInvoice = const [],
    this.toInvoiceMonth = '',
    this.received = const [],
    this.failed = const {},
    this.holdsUnassigned = const {},
    this.creditsKnown = true,
    this.originalsToKeep = 0,
  });

  final List<Receivable> receivables;
  final DateTime today;

  /// The current month in words ("November").
  final String month;

  /// The month still to invoice in words ("October").
  final String toInvoiceMonth;
  final String currency;
  final ReminderMode mode;
  final List<ToInvoice> toInvoice;
  final List<ReceivedPayment> received;
  final Set<InvoicingSource> failed;

  /// The customers who hold money received and not assigned
  /// (`holdsUnassignedMoney`): matched first, never reminded.
  final Set<String> holdsUnassigned;

  /// Whether the customers' credits were read. Until then nobody is known
  /// to hold money, so no reminder is offered and "Share reminders by
  /// hand" says it is checking the received payments.
  final bool creditsKnown;

  /// #3853 — how many issued invoices wait for their original to be kept,
  /// for someone who may keep them.
  final int originalsToKeep;
}
