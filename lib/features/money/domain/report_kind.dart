// SPDX-License-Identifier: 0BSD
//
// #864 — the report kinds, in ONE place.
//
// Before this, a report kind was a bare string repeated across five
// unconnected switches: the editor's chip list, its extras constant, the
// switch that reads its stored bands, the one that folds them back, and
// the ladder that supplies its defaults. Two of those five fall through
// to "then it must be a reminder", so a kind added to only four of them
// did not fail — it silently became reminder level 1.
//
// That is why "every report can export its design" could not be promised
// structurally: there was no set to iterate and nothing to check a new
// member against. This file is that set. Everything that needs to know
// what report kinds exist, or where one keeps its design, asks here.
import 'invoice_pdf_template.dart';

/// Where a kind's three bands live inside the saved template.
///
/// The document ids and the JSON keys are NOT the same namespace, and
/// pretending otherwise is what the old switches were doing by hand:
/// `invoice` is the template's own header/body/footer, `proforma` and
/// `statement` are named keys, six ids sit under `docs`, and a reminder
/// is an INDEX into an array.
sealed class ReportSlot {
  const ReportSlot();
}

/// The template's own header/body/footer — the invoice itself.
class ReportRootSlot extends ReportSlot {
  const ReportRootSlot();
}

class ReportProformaSlot extends ReportSlot {
  const ReportProformaSlot();
}

class ReportStatementSlot extends ReportSlot {
  const ReportStatementSlot();
}

/// A named key under `docs`.
class ReportDocSlot extends ReportSlot {
  const ReportDocSlot(this.key);
  final String key;
}

/// A 1-based level in the `reminders` array.
class ReportReminderSlot extends ReportSlot {
  const ReportReminderSlot(this.level);
  final int level;
}

/// One report the designer can edit and the exchange format can carry.
class ReportKind {
  const ReportKind({required this.id, required this.slot});

  /// The id used in the editor, the export file and every widget key.
  final String id;
  final ReportSlot slot;

  bool get isReminder => slot is ReportReminderSlot;
}

/// The kinds that exist regardless of configuration, in the order the
/// editor shows them.
const List<ReportKind> fixedReportKinds = [
  ReportKind(id: 'invoice', slot: ReportRootSlot()),
  ReportKind(id: 'proforma', slot: ReportProformaSlot()),
  ReportKind(id: 'statement', slot: ReportStatementSlot()),
  // #494 — the further documents.
  ReportKind(id: 'agreement', slot: ReportDocSlot('agreement')),
  ReportKind(id: 'payments', slot: ReportDocSlot('payments')),
  // #873 — the month's consumption against what was paid ahead.
  ReportKind(id: 'usage', slot: ReportDocSlot('usage')),
  ReportKind(id: 'workspace', slot: ReportDocSlot('workspace')),
  // #822 — the three structural documents.
  ReportKind(id: 'coa', slot: ReportDocSlot('coa')),
  ReportKind(id: 'badges', slot: ReportDocSlot('badges')),
  ReportKind(id: 'space_codes', slot: ReportDocSlot('space_codes')),
];

/// Every kind, including the reminder levels the dunning rules configure.
/// [reminderLevels] is 0 when dunning is off, and the reminders simply
/// do not exist then — not "exist but are hidden".
List<ReportKind> reportKinds({int reminderLevels = 0}) => [
      ...fixedReportKinds,
      for (var level = 1; level <= reminderLevels; level++)
        ReportKind(id: 'r$level', slot: ReportReminderSlot(level)),
    ];

/// The kind [id] names, or null when nothing does.
///
/// Null is the point: the old code parsed an unknown id as a reminder
/// level and carried on, so a typo edited level 1 instead of failing.
ReportKind? reportKindById(String id, {int reminderLevels = 0}) {
  for (final kind in reportKinds(reminderLevels: reminderLevels)) {
    if (kind.id == id) return kind;
  }
  return null;
}

/// The bands [template] stores for [kind], empty when it has none.
ReportBands bandsOf(InvoicePdfTemplate template, ReportKind kind) =>
    switch (kind.slot) {
      ReportRootSlot() => template.invoiceBands,
      ReportProformaSlot() => template.proforma,
      ReportStatementSlot() => template.statement,
      ReportDocSlot(:final key) =>
        template.extraDocs[key] ?? ReportBands.empty,
      ReportReminderSlot(:final level) =>
        template.reminderBands(level) ?? ReportBands.empty,
    };

/// #875 — the positioned layout of [kind], or null when it uses bands.
String? layoutOf(InvoicePdfTemplate template, ReportKind kind) =>
    template.layoutFor(kind.id);

/// [template] with [kind]'s positioned layout replaced; an empty
/// [xml] removes it, and the kind falls back to its bands.
InvoicePdfTemplate withLayout(
  InvoicePdfTemplate template,
  ReportKind kind,
  String xml,
) {
  final next = Map<String, String>.of(template.layouts);
  if (xml.trim().isEmpty) {
    next.remove(kind.id);
  } else {
    next[kind.id] = xml;
  }
  return template.copyWith(layouts: next);
}

/// [template] with [kind]'s bands replaced.
InvoicePdfTemplate withBands(
  InvoicePdfTemplate template,
  ReportKind kind,
  ReportBands bands,
) =>
    switch (kind.slot) {
      ReportRootSlot() => template.copyWith(invoice: bands),
      ReportProformaSlot() => template.copyWith(proforma: bands),
      ReportStatementSlot() => template.copyWith(statement: bands),
      ReportDocSlot(:final key) => template.withDoc(key, bands),
      ReportReminderSlot(:final level) => template.withReminder(level, bands),
    };
