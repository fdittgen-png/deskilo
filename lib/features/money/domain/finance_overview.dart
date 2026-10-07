// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Me › Finances: what I owe and what I paid, across every workspace I belong
// to (0380). A member's own documents only; issuing and chasing invoices is
// a workspace process and lives there. Amounts are minor units, each in its
// own currency — pages and currencies are never summed together.

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

  factory FinanceInvoice.fromJson(Map<String, dynamic> j) => FinanceInvoice(
        id: j['id'] as String,
        workspaceId: j['workspace_id'] as String,
        workspaceName: j['workspace_name'] as String? ?? '',
        number: j['number'] as String? ?? '',
        issuedAt: DateTime.parse(j['issued_at'] as String),
        dueOn: j['due_on'] == null ? null : DateTime.parse(j['due_on'] as String),
        totalCents: j['total_cents'] as int? ?? 0,
        paidCents: j['paid_cents'] as int? ?? 0,
        currency: j['currency'] as String? ?? 'EUR',
        state: FinanceState.fromWire(j['state']),
        reminderCount: (j['reminder_count'] as num?)?.toInt() ?? 0,
        lastReminderAt: j['last_reminder_at'] == null
            ? null
            : DateTime.parse(j['last_reminder_at'] as String),
      );
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

  factory FinanceReminder.fromJson(Map<String, dynamic> j) => FinanceReminder(
        id: j['id'] as String,
        invoiceId: j['invoice_id'] as String,
        invoiceNumber: j['invoice_number'] as String? ?? '',
        workspaceName: j['workspace_name'] as String? ?? '',
        sentAt: DateTime.parse(j['sent_at'] as String),
        level: (j['level'] as num?)?.toInt() ?? 1,
        automatic: j['automatic'] as bool? ?? false,
      );
}

class FinanceOverview {
  const FinanceOverview({this.invoices = const [], this.reminders = const []});

  final List<FinanceInvoice> invoices;
  final List<FinanceReminder> reminders;

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
  FinanceOverview inWorkspace(String? workspaceId) {
    if (workspaceId == null) return this;
    final mine = [for (final i in invoices) if (i.workspaceId == workspaceId) i];
    final ids = {for (final i in mine) i.id};
    return FinanceOverview(
      invoices: mine,
      reminders: [for (final r in reminders) if (ids.contains(r.invoiceId)) r],
    );
  }

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

  factory FinanceOverview.fromJson(Map<String, dynamic> j) => FinanceOverview(
        invoices: [
          for (final r in (j['invoices'] as List<dynamic>? ?? const []))
            FinanceInvoice.fromJson(r as Map<String, dynamic>),
        ],
        reminders: [
          for (final r in (j['reminders'] as List<dynamic>? ?? const []))
            FinanceReminder.fromJson(r as Map<String, dynamic>),
        ],
      );
}
