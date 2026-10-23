// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Me › Finances: what I owe and what I paid, across every workspace I belong
// to (0380). A member's own documents only; issuing and chasing invoices is
// a workspace process and lives there. Amounts are minor units, each in its
// own currency — pages and currencies are never summed together.

import '../../../core/data/json_reader.dart';

/// Where one of MY invoices stands (the 0067/0068 lifecycle, as the server
/// derives it).
enum FinanceState {
  open('open'),
  awaitingValidation('awaiting_validation'),
  partiallyPaid('partially_paid'),
  paid('paid'),
  refunded('refunded'),
  closed('closed');

  const FinanceState(this.wire);
  final String wire;

  static FinanceState fromWire(Object? wire) =>
      values.where((s) => s.wire == wire).firstOrNull ?? FinanceState.open;

  /// Still owed (fully or in part).
  bool get owed => this == open || this == awaitingValidation || this == partiallyPaid;
}

class FinanceInvoice {
  const FinanceInvoice({
    required this.id,
    required this.workspaceId,
    required this.workspaceName,
    required this.number,
    required this.issuedAt,
    required this.totalCents,
    required this.paidCents,
    required this.currency,
    required this.state,
    this.dueOn,
    this.reminderCount = 0,
    this.lastReminderAt,
  });

  final String id, workspaceId, workspaceName, number, currency;
  final DateTime issuedAt;
  final DateTime? dueOn, lastReminderAt;
  final int totalCents, paidCents, reminderCount;
  final FinanceState state;

  /// What remains to pay: the whole face value until a payment is matched,
  /// the rest after a partial one, nothing once settled.
  int get remainingCents => switch (state) {
        FinanceState.open || FinanceState.awaitingValidation => totalCents,
        FinanceState.partiallyPaid => totalCents - paidCents,
        _ => 0,
      };

  bool overdueAt(DateTime now) =>
      state.owed && dueOn != null && dueOn!.isBefore(DateTime(now.year, now.month, now.day));

  factory FinanceInvoice.fromJson(Map<String, dynamic> j) {
    final r = JsonReader(j, context: 'finance_invoice');
    return FinanceInvoice(
      id: r.string('id'),
      workspaceId: r.string('workspace_id'),
      workspaceName: r.stringOr('workspace_name'),
      number: r.stringOr('number'),
      issuedAt: r.dateTime('issued_at'),
      dueOn: r.dateTimeOrNull('due_on'),
      totalCents: r.intOrNull('total_cents') ?? 0,
      paidCents: r.intOrNull('paid_cents') ?? 0,
      currency: r.stringOr('currency', 'EUR'),
      state: FinanceState.fromWire(r.json['state']),
      reminderCount: r.intOrNull('reminder_count') ?? 0,
      lastReminderAt: r.dateTimeOrNull('last_reminder_at'),
    );
  }
}

class FinanceReminder {
  const FinanceReminder({
    required this.id,
    required this.invoiceId,
    required this.invoiceNumber,
    required this.workspaceName,
    required this.sentAt,
    required this.level,
    required this.automatic,
  });

  final String id, invoiceId, invoiceNumber, workspaceName;
  final DateTime sentAt;
  final int level;
  final bool automatic;

  factory FinanceReminder.fromJson(Map<String, dynamic> j) {
    final r = JsonReader(j, context: 'finance_reminder');
    return FinanceReminder(
      id: r.string('id'),
      invoiceId: r.string('invoice_id'),
      invoiceNumber: r.stringOr('invoice_number'),
      workspaceName: r.stringOr('workspace_name'),
      sentAt: r.dateTime('sent_at'),
      level: r.intOrNull('level') ?? 1,
      automatic: r.boolOr('automatic', fallback: false),
    );
  }
}

class FinanceOverview {
  const FinanceOverview({
    this.invoices = const [],
    this.reminders = const [],
    this.unavailableSources = const [],
  });

  final List<FinanceInvoice> invoices;
  final List<FinanceReminder> reminders;

  /// The hosts whose documents could not be read this time, by origin: what
  /// is shown is complete only for the others. A host that answered an empty
  /// list is not here — zero is only ever a successful result.
  final List<String> unavailableSources;

  /// These documents and [other]'s together, each document once: the same
  /// id read from two hosts is one document, and the first reading stays.
  FinanceOverview merge(FinanceOverview other) {
    final ids = {for (final i in invoices) i.id};
    final reminderIds = {for (final r in reminders) r.id};
    return FinanceOverview(
      invoices: [
        ...invoices,
        for (final i in other.invoices)
          if (!ids.contains(i.id)) i,
      ],
      reminders: [
        ...reminders,
        for (final r in other.reminders)
          if (!reminderIds.contains(r.id)) r,
      ],
      unavailableSources: [...unavailableSources, ...other.unavailableSources],
    );
  }

  /// The same documents, with [source] recorded as a host that did not
  /// answer.
  FinanceOverview withUnavailable(String source) => FinanceOverview(
        invoices: invoices,
        reminders: reminders,
        unavailableSources: [...unavailableSources, source],
      );

  /// The workspaces my documents come from, as (id, name), by name.
  List<(String, String)> get workspaces {
    final seen = <String, String>{};
    for (final i in invoices) {
      seen.putIfAbsent(i.workspaceId, () => i.workspaceName);
    }
    return [for (final e in seen.entries) (e.key, e.value)]
      ..sort((a, b) => a.$2.toLowerCase().compareTo(b.$2.toLowerCase()));
  }

  /// Only [workspaceId]'s documents; every workspace when it is null. A
  /// reminder follows its invoice.
  FinanceOverview inWorkspace(String? workspaceId) => workspaceId == null
      ? this
      : where((i) => i.workspaceId == workspaceId);

  /// The invoices [keep] accepts, and the reminders of those invoices.
  FinanceOverview where(bool Function(FinanceInvoice) keep) {
    final mine = [for (final i in invoices) if (keep(i)) i];
    final ids = {for (final i in mine) i.id};
    return FinanceOverview(
      invoices: mine,
      reminders: [for (final r in reminders) if (ids.contains(r.invoiceId)) r],
      unavailableSources: unavailableSources,
    );
  }

  /// Production only: what Me counts. A development space holds test data
  /// and never enters a total.
  FinanceOverview production(Set<String> devWorkspaceIds) =>
      where((i) => !devWorkspaceIds.contains(i.workspaceId));

  /// The development spaces' documents, shown apart and marked DEV.
  FinanceOverview development(Set<String> devWorkspaceIds) =>
      where((i) => devWorkspaceIds.contains(i.workspaceId));

  List<FinanceInvoice> get outstanding => [
        for (final i in invoices)
          if (i.state.owed) i,
      ]..sort((a, b) => (a.dueOn ?? a.issuedAt).compareTo(b.dueOn ?? b.issuedAt));

  List<FinanceInvoice> get paid => [
        for (final i in invoices)
          if (!i.state.owed) i,
      ];

  /// Remaining per currency — never summed across currencies.
  Map<String, int> get owedByCurrency {
    final out = <String, int>{};
    for (final i in outstanding) {
      out[i.currency] = (out[i.currency] ?? 0) + i.remainingCents;
    }
    return out;
  }

  factory FinanceOverview.fromJson(Map<String, dynamic> j) {
    final r = JsonReader(j, context: 'my_finances');
    return FinanceOverview(
      invoices: r.objects('invoices', (row) => FinanceInvoice.fromJson(row.json)),
      reminders:
          r.objects('reminders', (row) => FinanceReminder.fromJson(row.json)),
    );
  }
}
