// SPDX-License-Identifier: 0BSD
import '../../events/domain/workspace_event.dart';
import 'billing_rules.dart';
import 'dunning.dart';
import 'invoice.dart';

/// #827 — the invoicing wizard's pure side: which RUN the calendar
/// calls for, which PERIOD and invoice KIND it works on, and the plan of
/// every step derived from what the workspace already holds. Nothing
/// here talks to a server; the screen feeds it providers and runs the
/// existing RPCs on the items it returns.

/// The two moments the finance person sits down: ahead of a month for
/// the subscriptions members pay in advance, and just after a month for
/// the usage, consumption and extra charges that are billed afterwards.
enum WizardRun { startOfMonth, endOfMonth }

/// The steps, in order. [summary] is the last and never "done".
enum WizardStep {
  review,
  issue,
  send,
  remind,
  payments,
  match,
  close,
  summary,
}

/// 'YYYY-MM' of the month after [now].
String wizardNextPeriod(DateTime now) {
  final next = DateTime(now.year, now.month + 1, 1);
  return '${next.year}-${next.month.toString().padLeft(2, '0')}';
}

/// 'YYYY-MM' of the month before [now].
String wizardPreviousPeriod(DateTime now) {
  final prev = DateTime(now.year, now.month - 1, 1);
  return '${prev.year}-${prev.month.toString().padLeft(2, '0')}';
}

/// The period a run works on: the coming month for subscriptions, the
/// month just finished for usage.
String wizardPeriod(WizardRun run, DateTime now) => switch (run) {
      WizardRun.startOfMonth => wizardNextPeriod(now),
      WizardRun.endOfMonth => wizardPreviousPeriod(now),
    };

/// The invoice kind a run issues.
InvoiceKind wizardKind(WizardRun run) => switch (run) {
      WizardRun.startOfMonth => InvoiceKind.subscription,
      WizardRun.endOfMonth => InvoiceKind.usage,
    };

/// Which run the date calls for: from the subscription advance window
/// before the month turns (never later than the 20th) it is the START
/// run; in the first days of a month it is the END run for the month
/// that just closed; in between, the end run is still the one with
/// work left.
WizardRun suggestedRun(DateTime now, BillingRules rules) {
  final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
  final advanceStart = daysInMonth - rules.subscriptionAdvanceDays;
  final startFrom = advanceStart < 20 ? advanceStart : 20;
  return now.day >= startFrom ? WizardRun.startOfMonth : WizardRun.endOfMonth;
}

/// Whether [line] belongs to [kind]'s document — the server's own split
/// (`invoice_lines_for`, 0142): subscription lines alone, or everything
/// else.
bool lineBelongsTo(InvoiceLine line, InvoiceKind kind) => switch (kind) {
      InvoiceKind.subscription => line.kind == 'subscription',
      InvoiceKind.usage => line.kind != 'subscription',
      InvoiceKind.full || InvoiceKind.settlement => true,
    };

/// One member on the issue step: what would be issued, or what already
/// was.
class WizardIssueItem {
  const WizardIssueItem({
    required this.memberId,
    required this.memberName,
    required this.lines,
    required this.totalCents,
    this.issued,
  });

  final String memberId;
  final String memberName;
  final List<InvoiceLine> lines;
  final int totalCents;

  /// The invoice already covering this member, period and kind — a
  /// second issue would be refused by the server, so the row is done.
  final Invoice? issued;

  bool get done => issued != null;
}

/// The issue plan: every member the previews say has something for the
/// period, split into done and to do. [previews] maps member id to the
/// server's preview (ALL kinds); the lines are narrowed to [kind].
List<WizardIssueItem> issuePlan({
  required Iterable<({String id, String name})> members,
  required Map<String, ({List<InvoiceLine> lines, int totalCents})> previews,
  required List<Invoice> invoices,
  required String period,
  required InvoiceKind kind,
}) {
  final items = <WizardIssueItem>[];
  for (final member in members) {
    final issued = invoices
        .where((i) =>
            i.memberId == member.id &&
            i.period == period &&
            !i.isVoided &&
            (i.kind == kind || i.kind == InvoiceKind.full))
        .firstOrNull;
    final preview = previews[member.id];
    final lines = [
      for (final l in preview?.lines ?? const <InvoiceLine>[])
        if (lineBelongsTo(l, kind)) l,
    ];
    if (issued == null && lines.isEmpty) continue;
    items.add(WizardIssueItem(
      memberId: member.id,
      memberName: member.name,
      lines: lines,
      totalCents: lines.fold(0, (s, l) => s + l.amountCents),
      issued: issued,
    ));
  }
  return items..sort((a, b) => a.memberName.compareTo(b.memberName));
}

/// The invoices a run issued or should have — the send step's list.
List<Invoice> issuedForRun(List<Invoice> invoices, String period, InvoiceKind kind) =>
    [
      for (final i in invoices)
        if (i.period == period &&
            !i.isVoided &&
            (i.kind == kind || i.kind == InvoiceKind.full))
          i,
    ]..sort((a, b) => a.memberName.compareTo(b.memberName));

/// Open = issued, positive, not voided, not folded into a settlement,
/// not itself paid (a confirmed match closes it).
List<Invoice> openInvoicesOf(
  List<Invoice> invoices,
  Map<String, InvoiceMatch> matches,
) =>
    [
      for (final i in invoices)
        if (!i.isVoided &&
            i.totalCents > 0 &&
            i.settledByInvoiceId == null &&
            i.kind != InvoiceKind.settlement &&
            !_closedBy(matches[i.id]))
          i,
    ];

bool _closedBy(InvoiceMatch? match) =>
    match != null &&
    match.status == 'confirmed' &&
    match.resolution != 'under_accepted';

/// A reminder the rules say is due.
class WizardRemindItem {
  const WizardRemindItem({required this.invoice, required this.level});
  final Invoice invoice;
  final int level;
}

/// Everything overdue by the dunning rules, with the level the next
/// reminder carries. Partially paid invoices stay in: the remainder is
/// still owed (the auto sweep skips them, the person should not).
List<WizardRemindItem> remindPlan({
  required List<Invoice> invoices,
  required Map<String, InvoiceMatch> matches,
  required Map<String, ({int count, DateTime last})> reminders,
  required DunningRules rules,
  required DateTime now,
}) {
  final due = <WizardRemindItem>[];
  for (final invoice in openInvoicesOf(invoices, matches)) {
    final match = matches[invoice.id];
    if (match != null && match.status == 'pending') continue;
    final sent = reminders[invoice.id];
    final level = dueReminderLevel(
      issuedAt: invoice.issuedAt,
      reminderCount: sent?.count ?? 0,
      lastReminderAt: sent?.last,
      rules: rules,
      now: now,
    );
    if (level != null) due.add(WizardRemindItem(invoice: invoice, level: level));
  }
  return due..sort((a, b) => a.invoice.issuedAt.compareTo(b.invoice.issuedAt));
}

/// Payments members declared that still wait for a decision.
List<WorkspaceEvent> pendingPayments(List<WorkspaceEvent> events) => [
      for (final e in events)
        if (e.type == EventType.payment && e.status == EventStatus.pending) e,
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

/// How the close step groups what is still open for one member.
class WizardCloseGroup {
  const WizardCloseGroup({
    required this.memberId,
    required this.memberName,
    required this.open,
    required this.partial,
  });

  final String memberId;
  final String memberName;

  /// Open, unmatched invoices — two or more can be regrouped into one.
  final List<Invoice> open;

  /// Invoices with a standing partial payment — a write-off closes the
  /// remainder.
  final List<Invoice> partial;

  bool get canSettle => open.length >= 2;
}

/// The close plan: per member, what can be regrouped and what can be
/// written off; plus the credit notes waiting for a refund.
({List<WizardCloseGroup> groups, List<Invoice> refunds}) closePlan({
  required List<Invoice> invoices,
  required Map<String, InvoiceMatch> matches,
}) {
  final byMember = <String, WizardCloseGroup>{};
  for (final invoice in openInvoicesOf(invoices, matches)) {
    final match = matches[invoice.id];
    if (match != null && match.status == 'pending') continue;
    final group = byMember[invoice.memberId] ??
        WizardCloseGroup(
          memberId: invoice.memberId,
          memberName: invoice.memberName,
          open: [],
          partial: [],
        );
    if (match != null && match.resolution == 'under_accepted') {
      group.partial.add(invoice);
    } else {
      group.open.add(invoice);
    }
    byMember[invoice.memberId] = group;
  }
  final refunds = [
    for (final i in invoices)
      if (!i.isVoided && i.totalCents < 0 && matches[i.id] == null) i,
  ];
  final groups = byMember.values
      .where((g) => g.canSettle || g.partial.isNotEmpty)
      .toList()
    ..sort((a, b) => a.memberName.compareTo(b.memberName));
  return (groups: groups, refunds: refunds);
}

/// What one run did — the summary's numbers, counted as the person
/// acts, never re-derived (a payment validated here is one more even
/// when the list behind refreshes).
class WizardTally {
  const WizardTally({
    this.issued = 0,
    this.shared = 0,
    this.reminded = 0,
    this.paymentsDecided = 0,
    this.paymentsRegistered = 0,
    this.matched = 0,
    this.settled = 0,
    this.writeoffs = 0,
    this.refunds = 0,
  });

  final int issued;
  final int shared;
  final int reminded;
  final int paymentsDecided;
  final int paymentsRegistered;
  final int matched;
  final int settled;
  final int writeoffs;
  final int refunds;

  WizardTally copyWith({
    int? issued,
    int? shared,
    int? reminded,
    int? paymentsDecided,
    int? paymentsRegistered,
    int? matched,
    int? settled,
    int? writeoffs,
    int? refunds,
  }) =>
      WizardTally(
        issued: issued ?? this.issued,
        shared: shared ?? this.shared,
        reminded: reminded ?? this.reminded,
        paymentsDecided: paymentsDecided ?? this.paymentsDecided,
        paymentsRegistered: paymentsRegistered ?? this.paymentsRegistered,
        matched: matched ?? this.matched,
        settled: settled ?? this.settled,
        writeoffs: writeoffs ?? this.writeoffs,
        refunds: refunds ?? this.refunds,
      );

  int get total =>
      issued +
      shared +
      reminded +
      paymentsDecided +
      paymentsRegistered +
      matched +
      settled +
      writeoffs +
      refunds;
}

/// The wizard's session state: the run, where the person is, what was
/// done. Kept alive across the steps and the sheets they open.
class WizardState {
  const WizardState({
    this.run = WizardRun.endOfMonth,
    this.step = WizardStep.review,
    this.tally = const WizardTally(),
    this.visited = const {WizardStep.review},
  });

  final WizardRun run;
  final WizardStep step;
  final WizardTally tally;
  final Set<WizardStep> visited;

  WizardState copyWith({
    WizardRun? run,
    WizardStep? step,
    WizardTally? tally,
    Set<WizardStep>? visited,
  }) =>
      WizardState(
        run: run ?? this.run,
        step: step ?? this.step,
        tally: tally ?? this.tally,
        visited: visited ?? this.visited,
      );
}
