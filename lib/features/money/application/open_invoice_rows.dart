// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2494 — what the Open tab shows for each issued, still-open invoice:
// where it stands, which actions it offers and whether a reminder is due.
// The widgets map over these values; they decide nothing.
import '../../events/domain/workspace_event.dart';
import '../domain/dunning.dart';
import '../domain/invoice.dart';

/// One open invoice, as the Open tab lists it (`OpenInvoiceEntry`).
typedef OpenInvoiceFacts = ({Invoice invoice, InvoiceMatch? pendingMatch});

/// Every action an open invoice can offer, in the words of the hub.
enum OpenInvoiceAct {
  voidInvoice,
  proforma,
  remind,
  match,
  writeoff,

  /// The write-off was filed and waits for its quorum: a chip, no button.
  writeoffPending,
  refund,

  /// A declared payment waits for its validation: a chip, no button.
  matchPending,
  confirmInEvents,
}

/// Where an open invoice stands in the classic list (#504, #508).
enum OpenInvoiceStanding {
  /// A NEGATIVE document the workspace pays back: void or refund.
  creditNote,

  /// A standing partial match: the remainder is still owed.
  partiallyPaid,

  /// A match waits for its validation.
  matchPending,

  /// Nothing matched yet.
  open,
}

/// One action, and whether it is drawn as a labelled tonal button.
typedef OpenInvoiceActChoice = ({OpenInvoiceAct act, bool tonal});

/// One card of the classic Open list.
class OpenInvoiceRow {
  const OpenInvoiceRow({
    required this.entry,
    required this.standing,
    required this.acts,
    this.dueLevel,
    this.figureCents,
  });

  final OpenInvoiceFacts entry;
  final OpenInvoiceStanding standing;

  /// The actions, in the order the card shows them.
  final List<OpenInvoiceActChoice> acts;

  /// The dunning level that is due (#472), or null.
  final int? dueLevel;

  /// What the figure beside the actions says: the refund on a credit
  /// note, the remainder on a partial match; null otherwise.
  final int? figureCents;

  bool get reminderDue => dueLevel != null;
}

/// The classic Open list's decisions (the journey view has its own).
abstract final class OpenInvoiceRows {
  /// The ids of the invoices whose write-off is filed and pending (#504).
  static Set<String> pendingWriteoffs(Iterable<WorkspaceEvent> events) => {
    for (final event in events)
      if (event.isPending && event.type == EventType.invoiceWriteoff)
        event.payload['invoice_id'] as String? ?? '',
  };

  /// The due dunning level of every open invoice when dunning is on
  /// (#472). A credit note owes the member nothing and is never reminded
  /// (#508).
  static Map<String, int?> dueLevels(
    List<OpenInvoiceFacts> open, {
    required bool dunningOn,
    required Map<String, ({int count, DateTime last})> reminders,
    required DunningRules rules,
    required DateTime now,
  }) {
    if (!dunningOn) return const {};
    return {
      for (final e in open)
        if (e.invoice.totalCents > 0)
          e.invoice.id: dueReminderLevel(
            dueOn: e.invoice.dueOn,
            issuedAt: e.invoice.issuedAt,
            reminderCount: reminders[e.invoice.id]?.count ?? 0,
            lastReminderAt: reminders[e.invoice.id]?.last,
            rules: rules,
            now: now,
          ),
    };
  }

  static OpenInvoiceStanding standingOf(OpenInvoiceFacts entry) {
    final match = entry.pendingMatch;
    if (entry.invoice.totalCents < 0 && match == null) {
      return OpenInvoiceStanding.creditNote;
    }
    if (match != null && !match.pending) {
      return OpenInvoiceStanding.partiallyPaid;
    }
    if (match != null) return OpenInvoiceStanding.matchPending;
    return OpenInvoiceStanding.open;
  }

  /// One row per open invoice, in the list's order.
  static List<OpenInvoiceRow> of(
    List<OpenInvoiceFacts> open, {
    required Map<String, int?> dueLevels,
    required Set<String> pendingWriteoffs,
  }) => [
    for (final entry in open)
      _row(
        entry,
        dueLevels[entry.invoice.id],
        pendingWriteoffs.contains(entry.invoice.id),
      ),
  ];

  static OpenInvoiceRow _row(
    OpenInvoiceFacts entry,
    int? dueLevel,
    bool writeoffPending,
  ) {
    final standing = standingOf(entry);
    final invoice = entry.invoice;
    return OpenInvoiceRow(
      entry: entry,
      standing: standing,
      dueLevel: dueLevel,
      figureCents: switch (standing) {
        OpenInvoiceStanding.creditNote => -invoice.totalCents,
        OpenInvoiceStanding.partiallyPaid =>
          invoice.totalCents - entry.pendingMatch!.paidCents,
        _ => null,
      },
      acts: switch (standing) {
        OpenInvoiceStanding.creditNote => const [
          (act: OpenInvoiceAct.voidInvoice, tonal: false),
          (act: OpenInvoiceAct.refund, tonal: true),
        ],
        OpenInvoiceStanding.partiallyPaid => [
          (act: OpenInvoiceAct.remind, tonal: false),
          (act: OpenInvoiceAct.match, tonal: true),
          if (writeoffPending)
            (act: OpenInvoiceAct.writeoffPending, tonal: false)
          else
            (act: OpenInvoiceAct.writeoff, tonal: true),
        ],
        OpenInvoiceStanding.matchPending => const [
          (act: OpenInvoiceAct.matchPending, tonal: false),
        ],
        OpenInvoiceStanding.open => const [
          (act: OpenInvoiceAct.voidInvoice, tonal: false),
          (act: OpenInvoiceAct.proforma, tonal: false),
          (act: OpenInvoiceAct.remind, tonal: false),
          (act: OpenInvoiceAct.match, tonal: true),
        ],
      },
    );
  }

  /// The journey card's secondary actions (#812): everything the
  /// lifecycle still permits besides the [primary] move, which carries
  /// the label.
  static List<OpenInvoiceActChoice> journeyActs(
    OpenInvoiceFacts entry, {
    required OpenInvoiceAct? primary,
    required bool writeoffPending,
  }) {
    final creditNote = entry.invoice.totalCents < 0;
    final match = entry.pendingMatch;
    final partial = match != null && !match.pending;
    final pending = match != null && match.pending;
    final settled = partial || pending;
    return [
      if (!settled) (act: OpenInvoiceAct.voidInvoice, tonal: false),
      if (!creditNote && !settled) (act: OpenInvoiceAct.proforma, tonal: false),
      if (!creditNote && !pending && primary != OpenInvoiceAct.remind)
        (act: OpenInvoiceAct.remind, tonal: false),
      if (!creditNote && !pending && primary != OpenInvoiceAct.match)
        (act: OpenInvoiceAct.match, tonal: primary == null),
      if (partial && writeoffPending)
        (act: OpenInvoiceAct.writeoffPending, tonal: false)
      else if (partial)
        (act: OpenInvoiceAct.writeoff, tonal: false),
      if (creditNote && primary != OpenInvoiceAct.refund)
        (act: OpenInvoiceAct.refund, tonal: true),
      if (pending) (act: OpenInvoiceAct.matchPending, tonal: false),
    ];
  }
}
