// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Me › Finances: what I owe and what I paid, across every workspace I belong
// to (0380). A member's own documents only; issuing and chasing invoices is
// a workspace process and lives there. Amounts are minor units, each in its
// own currency — pages and currencies are never summed together.

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import '../../../core/backend/operation_context.dart' show WorkspaceTarget;
import '../../../core/text/collation.dart';
import 'account_activity.dart';
import 'finance_due.dart';
import 'finance_hosts.dart';
import 'finance_invoice.dart';

export 'finance_billed.dart';
export 'finance_due.dart';
export 'finance_invoice.dart';

class FinanceReminder {
  const FinanceReminder({
    required this.id,
    required this.invoiceId,
    required this.invoiceNumber,
    required this.workspaceName,
    required this.sentAt,
    required this.level,
    required this.automatic,
    this.workspaceId,
    this.installationId,
  });

  final String id, invoiceId, invoiceNumber, workspaceName;

  /// The workspace of the invoice this reminder is about: with [id], its
  /// identity across hosts. Null until the reminder is qualified by its
  /// invoice ([FinanceOverview.qualified]).
  final String? workspaceId;
  final String? installationId;
  WorkspaceTarget? get target => workspaceId == null || installationId == null ? null
      : WorkspaceTarget.local(installationId: installationId!, workspaceId: workspaceId!);
  String? get networkId => workspaceId == null ? null
      : installationId == null ? workspaceId : '$installationId:$workspaceId';

  /// This reminder, in [workspaceId].
  FinanceReminder inWorkspace(String? workspaceId, {String? installation}) => FinanceReminder(
        id: id,
        invoiceId: invoiceId,
        invoiceNumber: invoiceNumber,
        workspaceName: workspaceName,
        sentAt: sentAt,
        level: level,
        automatic: automatic,
        workspaceId: workspaceId,
        installationId: installation ?? installationId,
      );
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
      workspaceId: r.stringOrNull('workspace_id'),
    );
  }
}

/// #2557 C4 — one host that answered for my documents: the personal home
/// ([origin] null) or a connected installation, by origin, with the
/// workspaces whose documents it returned.
class FinanceSourceRead {
  const FinanceSourceRead({this.origin, this.installationId, this.workspaceIds = const {}});

  /// The connected host's origin; null for the personal home.
  final String? origin;
  final String? installationId;

  /// The workspaces this host returned documents of.
  final Set<String> workspaceIds;
}

class FinanceOverview {
  const FinanceOverview({
    this.sourceInstallation,
    this.invoices = const [],
    this.reminders = const [],
    this.unavailableSources = const [],
    this.answered = const [],
    this.hosts = const [],
    this.payments = const [],
    this.olderSettledLeftOut = false,
    this.billed = const [],
  });

  /// The verified identity of a single reader answer, including an empty one.
  final String? sourceInstallation;

  final List<FinanceInvoice> invoices;

  /// #4164 B2 (0911) — documents I read through a billing-access grant, never as a member: kept out of
  /// [invoices] so nothing that counts, pays or exports what I owe as a member sees them ([billedGroups]).
  final List<FinanceInvoice> billed;

  /// #3878 (0755) — an answer carries every document still owed or in my
  /// favour, and the settled ones by their newest page: true when older
  /// settled ones were left out of it.
  final bool olderSettledLeftOut;
  final List<FinanceReminder> reminders;

  /// My payments read on the connected hosts (`my_financial_activity`,
  /// kind payments, its first page), each identified by workspace and id.
  /// The personal home's own payments are its activity page's.
  final List<AccountActivity> payments;

  /// The hosts that answered this time, in the order they were read: the
  /// coverage shown above the results, beside [unavailableSources].
  final List<FinanceSourceRead> answered;

  /// The hosts whose documents could not be read this time, by origin: what
  /// is shown is complete only for the others. A host that answered an empty
  /// list is not here — zero is only ever a successful result.
  final List<String> unavailableSources;

  /// #2557 C5 — the connected hosts my personal account names, each with
  /// its own state, in the order they are read.
  final List<FinanceHostRead> hosts;

  /// #3682 — a connected host is still being read: nothing is complete.
  bool get stillReading =>
      hosts.any((h) => h.status == FinanceHostStatus.reading);

  /// Every host whose documents are not part of what is shown: the ones
  /// that did not answer, and the connected ones not answered yet. What a
  /// file notes as unavailable.
  List<String> get notAnswered => [
    ...unavailableSources,
    for (final h in hosts)
      if (h.status != FinanceHostStatus.answered) h.host.name,
  ];

  /// These documents and [other]'s together, each document once: the same
  /// qualified id (workspace, then document) read from two hosts is one
  /// document, and the first reading stays. Two hosts' equal local ids in
  /// different workspaces are two documents.
  FinanceOverview merge(FinanceOverview other) {
    final mine = qualified();
    final theirs = other.qualified();
    final ids = {for (final i in mine.invoices) (i.networkId, i.id)};
    final billedIds = {for (final i in billed) (i.networkId, i.id)};
    final reminderIds = {for (final r in mine.reminders) _reminderKey(r)};
    final paymentIds = {for (final p in payments) (p.networkId, p.id)};
    return FinanceOverview(
      invoices: [
        ...mine.invoices,
        for (final i in theirs.invoices)
          if (ids.add((i.networkId, i.id))) i,
      ]..sort((a, b) {
        final source = a.networkId.compareTo(b.networkId);
        return source != 0 ? source : a.id.compareTo(b.id);
      }),
      billed: [...billed, for (final i in other.billed) if (billedIds.add((i.networkId, i.id))) i],
      reminders: [
        ...mine.reminders,
        for (final r in theirs.reminders)
          if (reminderIds.add(_reminderKey(r))) r,
      ]..sort((a, b) {
        final source = (a.networkId ?? a.workspaceName).compareTo(b.networkId ?? b.workspaceName);
        return source != 0 ? source : a.id.compareTo(b.id);
      }),
      payments: newestFirst([
        ...payments,
        for (final p in other.payments)
          if (paymentIds.add((p.networkId, p.id))) p,
      ]),
      unavailableSources: [...unavailableSources, ...other.unavailableSources],
      answered: [...answered, ...other.answered],
      hosts: [...hosts, ...other.hosts],
      olderSettledLeftOut: olderSettledLeftOut || other.olderSettledLeftOut,
    );
  }

  /// A reminder's identity: its invoice's workspace and its id (the
  /// workspace's name only while it is not qualified yet).
  static (String, String) _reminderKey(FinanceReminder r) =>
      (r.networkId ?? '${r.installationId ?? ''}:${r.workspaceName}', r.id);

  /// The same documents, each reminder qualified with the workspace of its
  /// invoice in THIS answer: one answer comes from one installation, where
  /// an invoice id is one invoice. A reminder whose invoice is not here
  /// stays as it was.
  FinanceOverview onInstallation(String installationId) {
    final local = qualified();
    return FinanceOverview(
      sourceInstallation: installationId,
      answered: answered, hosts: hosts, unavailableSources: unavailableSources,
      olderSettledLeftOut: olderSettledLeftOut,
      invoices: [for (final i in invoices) i.onInstallation(installationId)],
      billed: [for (final i in billed) i.onInstallation(installationId)],
      payments: [for (final p in payments) p.onInstallation(installationId)],
      reminders: [for (final r in local.reminders)
        r.inWorkspace(r.workspaceId, installation: installationId)],
    );
  }

  FinanceOverview qualified() {
    if (reminders.every((r) => r.workspaceId != null)) return this;
    final workspaceOf = {for (final i in invoices) (i.installationId, i.id): i.workspaceId};
    return _with(
      reminders: [
        for (final r in reminders)
          if (r.workspaceId == null && workspaceOf[(r.installationId, r.invoiceId)] != null)
            r.inWorkspace(workspaceOf[(r.installationId, r.invoiceId)])
          else
            r,
      ],
    );
  }

  /// These documents with some parts replaced.
  FinanceOverview _with({
    List<FinanceInvoice>? invoices,
    List<FinanceReminder>? reminders,
    List<AccountActivity>? payments,
    List<String>? unavailableSources,
    List<FinanceSourceRead>? answered,
    List<FinanceHostRead>? hosts,
  }) =>
      FinanceOverview(
        sourceInstallation: sourceInstallation,
        invoices: invoices ?? this.invoices,
        billed: billed,
        reminders: reminders ?? this.reminders,
        payments: payments ?? this.payments,
        unavailableSources: unavailableSources ?? this.unavailableSources,
        answered: answered ?? this.answered,
        hosts: hosts ?? this.hosts,
        olderSettledLeftOut: olderSettledLeftOut,
      );

  /// The same documents, with [payments] among them.
  FinanceOverview withPayments(List<AccountActivity> payments) =>
      _with(payments: payments);

  /// The same documents, with [source] no longer recorded as a host that
  /// did not answer: it is being read again.
  FinanceOverview withoutUnavailable(String source) => _with(
        unavailableSources: [
          for (final s in unavailableSources)
            if (s != source) s,
        ],
      );

  /// [payments], newest first, the qualified id breaking a tie.
  static List<AccountActivity> newestFirst(Iterable<AccountActivity> payments) =>
      [...payments]..sort((a, b) {
          final time = b.occurredAt.compareTo(a.occurredAt);
          if (time != 0) return time;
          final ws = a.networkId.compareTo(b.networkId);
          return ws != 0 ? ws : a.id.compareTo(b.id);
        });

  /// The same documents, with [reading] recorded as connected hosts being
  /// read.
  FinanceOverview reading(Iterable<FinanceHost> reading) => _with(
    hosts: [
      ...hosts,
      for (final h in reading) FinanceHostRead(h, FinanceHostStatus.reading),
    ],
  );

  /// The connected host [host] in [status], with its [answer] (null when it
  /// failed) among the documents; the other hosts are as they were.
  FinanceOverview hostSettled(
    FinanceHost host,
    FinanceHostStatus status, [
    FinanceOverview? answer,
  ]) {
    answer = answer?.onInstallation(host.installationId);
    final payments = answer?.payments ?? const <AccountActivity>[];
    final read = FinanceHostRead(
      host,
      status,
      // A workspace of payments alone is answered here as well.
      workspaceIds: {
        for (final i in answer?.invoices ?? const <FinanceInvoice>[])
          i.workspaceId,
        for (final i in answer?.billed ?? const <FinanceInvoice>[])
          i.workspaceId,
        for (final p in payments) p.workspaceId,
      },
      morePaymentsBefore: payments.length < activityPageSize
          ? null
          : payments.last.cursor,
    );
    final next = _with(
      hosts: [
        for (final h in hosts)
          if (h.host.installationId == host.installationId) read else h,
      ],
    );
    return answer == null
        ? next
        : next.merge(
            FinanceOverview(
              invoices: answer.invoices,
              billed: answer.billed,
              reminders: answer.reminders,
              payments: answer.payments,
              olderSettledLeftOut: answer.olderSettledLeftOut,
            ),
          );
  }

  /// The same documents, recorded as read from [origin] (null: the
  /// personal home), with the workspaces they belong to.
  FinanceOverview answeredBy(String? origin) => _with(
        answered: [
          ...answered,
          FinanceSourceRead(
            origin: origin,
            installationId: sourceInstallation ?? {...invoices.map((i) => i.installationId), ...payments.map((p) => p.installationId)}.nonNulls.singleOrNull,
            workspaceIds: {
              for (final i in invoices) i.workspaceId,
              for (final p in payments) p.workspaceId,
            },
          ),
        ],
      );

  /// The same documents, with [source] recorded as a host that did not
  /// answer.
  FinanceOverview withUnavailable(String source) =>
      _with(unavailableSources: [...unavailableSources, source]);

  /// #4492 — their names by the workspace's own id (what a source answers with and a document is counted by), not [workspaces]' network id.
  Map<String, String> get workspaceNames => {for (final i in [...invoices, ...billed]) i.workspaceId: i.workspaceName};

  /// The workspaces my documents come from, as (id, name), by name.
  List<(String, String)> get workspaces => _byName({
    for (final i in invoices) i.networkId: i.workspaceName,
  });

  /// The workspaces my documents or my payments come from — these
  /// payments and [more] (the personal home's own) — as (id, name), by
  /// name: a workspace I only paid in has a file of its own too.
  List<(String, String)> workspacesWith(Iterable<AccountActivity> more) {
    final seen = {for (final (id, name) in workspaces) id: name};
    for (final p in [...payments, ...more]) {
      seen.putIfAbsent(p.networkId, () => p.workspaceName);
    }
    return _byName(seen);
  }

  static List<(String, String)> _byName(Map<String, String> seen) =>
      [for (final e in seen.entries) (e.key, e.value)]
        ..sort((a, b) => compareNames(a.$2, b.$2));

  /// Only [workspaceId]'s documents; every workspace when it is null. A
  /// reminder follows its invoice.
  FinanceOverview inWorkspace(String? workspaceId) => workspaceId == null
      ? this
      : where((i) => i.networkId == workspaceId);

  /// The invoices [keep] accepts, and the reminders of those invoices: a
  /// reminder follows its invoice by workspace and id, so an equal local
  /// invoice id on another host never carries it along. The payments stay;
  /// their own face narrows them.
  FinanceOverview where(bool Function(FinanceInvoice) keep) {
    final mine = [for (final i in invoices) if (keep(i)) i];
    final ids = {for (final i in mine) (i.networkId, i.id)};
    final local = {for (final i in mine) (i.installationId, i.id)};
    return _with(
      invoices: mine,
      reminders: [
        for (final r in qualified().reminders)
          if (r.workspaceId == null
              ? local.contains((r.installationId, r.invoiceId))
              : ids.contains((r.networkId!, r.invoiceId)))
            r,
      ],
    )._withBilled([for (final i in billed) if (keep(i)) i]);
  }

  /// The same documents, with [billed] in place of the billing-access ones.
  FinanceOverview _withBilled(List<FinanceInvoice> billed) => FinanceOverview(
        sourceInstallation: sourceInstallation,
        invoices: invoices,
        billed: billed,
        reminders: reminders,
        payments: payments,
        unavailableSources: unavailableSources,
        answered: answered,
        hosts: hosts,
        olderSettledLeftOut: olderSettledLeftOut,
      );

  /// Production only: what Me counts. A development space holds test data
  /// and never enters a total.
  FinanceOverview production(Set<String> devWorkspaceIds) =>
      where((i) => !devWorkspaceIds.contains(i.networkId));

  /// The development spaces' documents, shown apart and marked DEV.
  FinanceOverview development(Set<String> devWorkspaceIds) =>
      where((i) => devWorkspaceIds.contains(i.networkId));

  List<FinanceInvoice> get outstanding => [
        for (final i in invoices)
          if (i.state.owed) i,
      ]..sort((a, b) => (a.dueOn ?? a.issuedAt).compareTo(b.dueOn ?? b.issuedAt));

  List<FinanceInvoice> get paid => [
        for (final i in invoices)
          if (!i.state.owed) i,
      ];

  /// What I still have to pay: never a credit note not used yet (money due
  /// TO me, #3599) nor what I paid that is being validated (#3682, #3877).
  List<FinanceInvoice> get payable => [
        for (final i in outstanding)
          if (!i.isCreditNote && i.toPay) i,
      ];

  /// #3682 — from a host without the server's figures, an invoice awaiting
  /// validation is paid whole on my side and owed nowhere.
  bool _validatingWhole(FinanceInvoice i) =>
      i.stillDueCents == null && !i.isCreditNote && i.state == FinanceState.awaitingValidation;

  /// What I paid that waits for confirmation, per currency: not owed.
  Map<String, int> get beingValidatedByCurrency => _byCode([
        for (final i in outstanding)
          if (!i.isCreditNote && i.beingValidatedCents > 0) (i.currency, i.beingValidatedCents),
      ]);

  /// What remains open with each business, per currency: its invoices to
  /// pay less its own credit notes not used yet. A credit lowers what I pay
  /// the business that issued it, never another one's — one payee.
  Map<(String, String), int> get _openByPayee {
    final out = <(String, String), int>{};
    for (final i in outstanding.where((i) => !_validatingWhole(i))) {
      final payee = (i.networkId, i.currency);
      out[payee] = (out[payee] ?? 0) + i.remainingCents;
    }
    return out;
  }

  /// [sign] of what is open with each business, summed per currency: 1 for
  /// what I owe, -1 for what I am owed.
  Map<String, int> _openByCurrency(int sign) => _byCode([
        for (final e in _openByPayee.entries)
          if (e.value * sign > 0) (e.key.$2, e.value * sign),
      ]);

  /// [cents] summed per currency, ordered by currency code.
  static Map<String, int> _byCode(Iterable<(String, int)> cents) {
    final out = <String, int>{};
    for (final (code, c) in cents) { out[code] = (out[code] ?? 0) + c; }
    return {for (final code in out.keys.toList()..sort()) code: out[code]!};
  }

  /// What I owe per currency — never summed across currencies, and each
  /// business's own credit taken off its own invoices only.
  Map<String, int> get owedByCurrency => _openByCurrency(1);

  /// What businesses still hold for me per currency: the credit notes not
  /// used yet, beyond what I owe the business that issued them.
  Map<String, int> get inMyFavourByCurrency => _openByCurrency(-1);

  /// The currencies in which an invoice of mine is past its due day.
  Set<String> overdueCurrencies(DateTime now) => {
        for (final i in payable)
          if (i.overdueAt(now)) i.currency,
      };

  factory FinanceOverview.fromJson(Map<String, dynamic> j) {
    final r = JsonReader(j, context: 'my_finances');
    final all = r.objects('invoices', (row) => FinanceInvoice.fromJson(row.json));
    // #4164 B2 — a document read through a billing-access grant is kept apart
    // from the first read: its reminders follow it, never my own list.
    final billed = [for (final i in all) if (i.billingOnly) i];
    final billedIds = {for (final i in billed) i.id};
    return FinanceOverview(
      invoices: [for (final i in all) if (!i.billingOnly) i],
      billed: billed,
      reminders: [
        for (final x in r.objects('reminders', (row) => FinanceReminder.fromJson(row.json)))
          if (!billedIds.contains(x.invoiceId)) x,
      ],
      olderSettledLeftOut: r.boolOr('settled_cut', fallback: false),
    ).qualified();
  }
}
