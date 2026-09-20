// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1247 — what needs a person, ranked by what the delay costs.
//
// `docs/ux/DECISION_SURFACE.md` is the design pass this implements, and
// its rule is the whole thing:
//
//   A line appears only when a person must decide or act. A number
//   nobody can act on is information, and information belongs to the
//   screen that owns it.
//
// `23 occupied · 4 free · 2 no-shows` is a lovely sentence and nothing
// in it is a decision. It stays on the plan. The inventory in that
// document put eight signals in and four out, and that ratio IS the
// design: a surface that ranks everything ranks nothing.
//
// This file is the ranking, as pure Dart. The screen that shows it
// feeds it from the providers that already compute each signal; nothing
// here fetches anything, so the order — the part somebody has to agree
// with — is exercised without pumping a widget.

/// What kind of thing is waiting, in the order the design ranks them.
///
/// The enum's ORDER is the ranking, so the comparison below cannot
/// drift from the document: moving a row means moving it here.
enum AttentionKind {
  /// **Money that leaves.** A payment awaiting confirmation, a reminder
  /// due today under the rules. Delay costs the space cash, or costs
  /// the member an unfair reminder.
  money,

  /// **A person waiting.** A join request, a deletion request, a role
  /// change. Somebody is blocked on an answer.
  person,

  /// **A month that closes.** Members to invoice, once the month has
  /// ended. Costs nothing today and everything on the last day.
  month,

  /// **The instance.** A schema behind the app, a doctor finding. Rare,
  /// and an owner's decision.
  instance,

  /// **Configuration that is not doing what it says.** A capability
  /// switched on and held back by a missing prerequisite.
  configuration,
}

/// One line: who or what, the decision, and since when.
///
/// [subject] and [decision] are the words the screen prints — a verb for
/// the decision, never a noun-phrase status, because the line IS the
/// button. [waitingSince] is what the reader can check the ranking
/// against; it is also the tie-break.
class Attention {
  const Attention({
    required this.kind,
    required this.subject,
    required this.decision,
    required this.waitingSince,
    this.count = 1,
  });

  final AttentionKind kind;
  final String subject;
  final String decision;
  final DateTime waitingSince;

  /// How many things this one line stands for — *issue for 7 members*.
  /// One line per decision, never one per row of data.
  final int count;
}

/// The lines in the order a person should meet them.
///
/// By what the delay costs, never by recency — and within a rank oldest
/// first, so a request that has waited three days outranks one that
/// arrived this morning. Ties after that keep their input order, which
/// makes the result stable rather than arbitrary.
List<Attention> rankAttention(Iterable<Attention> items) {
  final ranked = [...items];
  ranked.sort((a, b) {
    final byCost = a.kind.index.compareTo(b.kind.index);
    if (byCost != 0) return byCost;
    return a.waitingSince.compareTo(b.waitingSince);
  });
  return ranked;
}

/// Whether anything needs this person at all.
///
/// Its own function because the empty state is a real answer and not an
/// absence: the surface says *nothing needs you* and gets out of the
/// way, rather than showing an empty list somebody has to interpret.
bool nothingNeedsYou(Iterable<Attention> items) => items.isEmpty;
