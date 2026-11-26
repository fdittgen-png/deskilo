// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4405 -- what a quote and a standalone invoice share while they are written: one draft (the subject, two dates, the buyer's
// reference and order, optional notes, the lines) and one widget that shows it. What differs is data: the words, the keys of the
// date fields, the people to choose from and the dates proposed. A change to how a commercial document is composed is made once.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/features/enabled_feature_keys.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/form_kit.dart';
import '../../domain/invoice_goods.dart';
import '../../domain/standalone_invoice.dart';
import '../../providers/line_units_provider.dart';
import '../../providers/money_providers.dart' show vatRatesProvider;
import '../../providers/standalone_invoice_providers.dart' show invoiceGoodsItemsProvider;
import 'standalone_line_form.dart';

/// What a commercial document holds while it is composed. The dates are what the person set: null until they do, so a screen
/// proposes its own default (the business's day, the payment term, the validity) and shows it.
class CommercialDocumentDraft {
  final reference = TextEditingController();
  final order = TextEditingController();
  final notes = TextEditingController();
  final List<StandaloneLineForm> lines = [StandaloneLineForm()];

  /// The customer the document is made out to.
  String? subject;

  /// The first date (the service date of an invoice, the issue date of a quote) and the last (the due date, the validity), as set.
  DateTime? startDate;
  DateTime? endDate;

  /// The first date as shown: the one set, else [today].
  DateTime startOn(DateTime today) => startDate ?? today;

  /// The last date as shown: the one set, else the one [proposed] for the first date shown (the payment term, the validity).
  DateTime endOn(DateTime today, DateTime Function(DateTime start) proposed) => endDate ?? proposed(startOn(today));

  /// What was typed in the reference, the order and the notes, trimmed.
  String get referenceText => reference.text.trim();
  String get orderText => order.text.trim();
  String get notesText => notes.text.trim();

  /// Gives the lines the identities the server kept for them, so the next save keeps them.
  void takeLineIds(List<StandaloneLine> saved) => attachLineIds(lines, saved);

  /// Replaces the lines with [from] (one empty line when there are none).
  void replaceLines(List<StandaloneLine> from) {
    for (final l in lines) {
      l.dispose();
    }
    lines
      ..clear()
      ..addAll([for (final line in from) StandaloneLineForm(from: line), if (from.isEmpty) StandaloneLineForm()]);
  }

  /// The lines as the composer sends them.
  List<StandaloneLine> toLines(BuildContext context) => [for (final l in lines) l.toLine(context)];

  void dispose() {
    reference.dispose();
    order.dispose();
    notes.dispose();
    for (final l in lines) {
      l.dispose();
    }
  }
}

/// The words and keys one document kind gives the composer.
class DocumentComposerWords {
  const DocumentComposerWords({
    required this.keyPrefix,
    required this.customerHint,
    required this.startLabel,
    required this.startKey,
    required this.endLabel,
    required this.endKey,
    required this.referenceLabel,
    required this.orderLabel,
    this.notesLabel,
    this.noCustomers,
  });

  /// The prefix of the keys shared by both kinds (`<prefix>-customer`, `-reference`, `-order`, `-line-editor-<i>`, `-add-line`).
  final String keyPrefix;
  final String customerHint;
  final String startLabel;
  final String startKey;
  final String endLabel;
  final String endKey;
  final String referenceLabel;
  final String orderLabel;

  /// The notes field's label, or null where the document has no notes.
  final String? notesLabel;

  /// What to say instead of the customer picker when there is nobody to choose, or null for an empty picker.
  final String? noCustomers;
}

/// The fields and the lines of a commercial document: the customer, two dates, the buyer's reference and order, the notes where the
/// document has them, and the line editors.
class DocumentComposer extends ConsumerWidget {
  const DocumentComposer({
    super.key,
    required this.workspaceId,
    required this.draft,
    required this.words,
    required this.customers,
    required this.startShown,
    required this.endShown,
    required this.locked,
    required this.onChanged,
    this.pieces = false,
    this.onReferenceChanged,
  });

  final String workspaceId;
  final CommercialDocumentDraft draft;
  final DocumentComposerWords words;

  /// The people to choose from: id and name.
  final List<({String id, String name})> customers;

  /// The dates the fields show: what was set, else what the screen proposes.
  final DateTime startShown;
  final DateTime endShown;
  final bool locked;

  /// Called after any edit: the screen rebuilds (and, for an invoice, drops its checked preview).
  final VoidCallback onChanged;

  /// Whether a goods line names the pieces it takes (an invoice does; a quote offers the item only).
  final bool pieces;

  /// Called when the reference or order is typed, for a screen that must know (an invoice's preview goes stale).
  final VoidCallback? onReferenceChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = words.keyPrefix;
    final rates = ref.watch(vatRatesProvider).value ?? const <VatRate>[]; // empty-ok: the rates only offer a choice; none leaves the business's default
    // #4433 -- with the goods ledger on, a line may sell an item kept in stock, and name its pieces where they are tagged
    final keys = ref.watch(enabledFeatureKeysProvider);
    final goods = featureOn(keys, 'stockManagement', byDefault: false)
        ? ref.watch(invoiceGoodsItemsProvider(workspaceId)).value ?? const <InvoiceGoodsItem>[] // empty-ok: the items only offer a choice; none leaves every line a service
        : const <InvoiceGoodsItem>[];
    final namesPieces = pieces && featureOn(keys, 'stockTags', byDefault: false);
    final units = ref.watch(lineUnitsProvider(workspaceId));
    final typed = onReferenceChanged ?? () {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (customers.isEmpty && words.noCustomers != null)
          Text(words.noCustomers!, key: ValueKey('$p-no-customers'))
        else
          DropdownButtonFormField<String>(
            key: ValueKey('$p-customer'),
            isExpanded: true,
            initialValue: draft.subject,
            decoration: InputDecoration(labelText: l.invoicingColCustomer),
            hint: Text(words.customerHint),
            items: [
              for (final c in customers) DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: locked
                ? null
                : (v) {
                    draft.subject = v;
                    onChanged();
                  },
          ),
        const FormGap(),
        AppDateField(
          key: ValueKey(words.startKey),
          label: words.startLabel,
          value: startShown,
          enabled: !locked,
          onChanged: (d) {
            draft.startDate = d.date;
            onChanged();
          },
        ),
        const FormGap(),
        AppDateField(
          key: ValueKey(words.endKey),
          label: words.endLabel,
          value: endShown,
          enabled: !locked,
          onChanged: (d) {
            draft.endDate = d.date;
            onChanged();
          },
        ),
        const FormGap(),
        AppTextField(
          key: ValueKey('$p-reference'),
          controller: draft.reference,
          label: words.referenceLabel,
          enabled: !locked,
          onChanged: (_) => typed(),
        ),
        const FormGap(),
        AppTextField(
          key: ValueKey('$p-order'),
          controller: draft.order,
          label: words.orderLabel,
          enabled: !locked,
          onChanged: (_) => typed(),
        ),
        const FormGap(),
        if (words.notesLabel != null) ...[
          AppTextField(key: ValueKey('$p-notes'), controller: draft.notes, label: words.notesLabel!, enabled: !locked),
          const FormGap(),
        ],
        Text(l.standaloneInvoiceLines, style: Theme.of(context).textTheme.titleMedium?.strong),
        for (final (i, line) in draft.lines.indexed)
          StandaloneLineEditor(
            key: ValueKey('$p-line-editor-$i'),
            index: i,
            form: line,
            rates: rates,
            goods: goods,
            pieces: namesPieces,
            units: units,
            enabled: !locked,
            onChanged: onChanged,
            onRemove: draft.lines.length > 1
                ? () {
                    draft.lines.removeAt(i).dispose();
                    onChanged();
                  }
                : null,
          ),
        TextButton.icon(
          key: ValueKey('$p-add-line'),
          onPressed: locked
              ? null
              : () {
                  draft.lines.add(StandaloneLineForm());
                  onChanged();
                },
          icon: const Icon(Icons.add),
          label: Text(l.standaloneInvoiceAddLine),
        ),
      ],
    );
  }
}
