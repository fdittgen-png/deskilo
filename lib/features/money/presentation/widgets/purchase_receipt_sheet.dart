// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2573 — a member's receipt of several lines: each line its own amount,
// VAT rate and deductible share, what it is for and where its cost belongs.
// Submitting files it (`PurchaseReceiptFiling`). A refusal keeps the sheet
// and every entry; a retry of the same entries sends the same request ids.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/cents.dart';
import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/file_purchase_receipt.dart';
import '../../domain/purchase.dart';
import '../../providers/purchase_providers.dart';
import 'expense_sheet.dart';
import 'expense_vat_fields.dart';
import 'purchase_labels.dart';
import 'purchase_place_field.dart';

/// Opens the sheet; true once the receipt awaits its validation.
Future<bool> showPurchaseReceiptSheet(
  BuildContext context,
  String workspaceId,
) async =>
    await showAppSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PurchaseReceiptSheet(workspaceId: workspaceId),
    ) ??
    false;

typedef _VatContext = ({List<double> percents, MoneyFormat currency});

/// One line's choices beside its text fields.
class _Line {
  _Line(this.id);

  final int id;
  double rate = 0;
  String purpose = 'unresolved';
  PurchasePlace? place;
}

class _PurchaseReceiptSheet extends ConsumerStatefulWidget {
  const _PurchaseReceiptSheet({required this.workspaceId});

  final String workspaceId;

  @override
  ConsumerState<_PurchaseReceiptSheet> createState() =>
      _PurchaseReceiptSheetState();
}

class _PurchaseReceiptSheetState extends ConsumerState<_PurchaseReceiptSheet> {
  final _fields = FormControllers();
  late final _filing = PurchaseReceiptFiling(
    ref.read(purchaseCommandProvider),
    widget.workspaceId,
  );
  _VatContext? _vat;
  var _nextId = 1;
  final _lines = [_Line(0)];
  var _category = expenseCategories.first;

  @override
  void initState() {
    super.initState();
    unawaited(_loadVat());
  }

  Future<void> _loadVat() async {
    final vat = await receiptVatContext(ref);
    if (mounted) setState(() => _vat = vat);
  }

  @override
  void dispose() {
    _fields.dispose();
    super.dispose();
  }

  double? _share(_Line l) => l.rate <= 0
      ? 100
      : double.tryParse(_fields.text('share-${l.id}').replaceAll(',', '.'));

  int? _gross(_Line l) => parseCentsInput(_fields.text('gross-${l.id}'));

  int _total() => _lines.fold(0, (sum, l) => sum + (_gross(l) ?? 0));

  PurchaseLineDraft _lineDraft(_Line l, {required bool vatAsked}) {
    final description = _fields.text('desc-${l.id}');
    final gross = _gross(l) ?? 0;
    // No VAT asked here: the tax stays unknown, never zero.
    if (!vatAsked) {
      return PurchaseLineDraft(
        grossCents: gross,
        description: description,
        recognitionKind: l.purpose,
        place: l.place,
      );
    }
    return PurchaseLineDraft.atRate(
      grossCents: gross,
      percent: l.rate,
      deductiblePct: _share(l) ?? 100,
      description: description,
      recognitionKind: l.purpose,
      place: l.place,
    );
  }

  FieldErrors _validate(AppLocalizations l10n) {
    final problem = receiptProblem(
      grosses: [for (final l in _lines) _gross(l)],
      shares: [for (final l in _lines) _share(l)],
    );
    if (problem == null) return const {};
    final id = _lines[problem.line].id;
    return switch (problem.problem) {
      ReceiptProblem.amount => {'gross-$id': l10n.purchaseReceiptAmount},
      ReceiptProblem.deductible => {
        'share-$id': l10n.purchaseReceiptDeductible,
      },
    };
  }

  Future<String?> _submit(AppLocalizations l10n) async {
    final vatAsked = _vat?.percents.isNotEmpty ?? false;
    final now = ref.read(clockProvider).now();
    final draft = PurchaseReceiptDraft(
      category: _category,
      // The day the member files it: the date the receipt is booked on
      // (a document without a date never reaches the books).
      originalDate: DateTime(now.year, now.month, now.day),
      lines: [for (final l in _lines) _lineDraft(l, vatAsked: vatAsked)],
    );
    try {
      return await _filing.file(draft) ? null : l10n.purchaseReceiptAmount;
    } on Object catch (e, st) {
      TraceLogger.instance.warn(
        'money',
        'purchase receipt submit failed',
        error: e,
        stackTrace: st,
      );
      return l10n.purchasesRefused;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final vat = _vat;
    if (vat == null) return const LoadingView();
    return AppFormSheet(
      title: l10n.purchaseReceiptAdd,
      submitLabel: l10n.purchaseReceiptSubmit,
      submitKey: const ValueKey('receipt-submit'),
      validate: () => _validate(l10n),
      onSubmit: () => _submit(l10n),
      builder: (context, refresh) => [
        Text(l10n.purchaseReceiptIntro),
        const FormGap(),
        DropdownButtonFormField<String>(
          key: const ValueKey('receipt-category'),
          initialValue: _category,
          decoration: InputDecoration(
            labelText: l10n.moneyExpenseCategoryLabel,
          ),
          items: [
            for (final c in expenseCategories)
              DropdownMenuItem(
                value: c,
                child: Text(expenseCategoryLabel(l10n, c)),
              ),
          ],
          onChanged: (v) => _category = v ?? _category,
        ),
        for (final l in _lines) ..._lineFields(context, l, vat, refresh),
        const FormGap(),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const ValueKey('receipt-add-line'),
            onPressed: () {
              _lines.add(_Line(_nextId++));
              refresh();
            },
            icon: const Icon(Icons.add),
            label: Text(l10n.purchaseReceiptAddLine),
          ),
        ),
        Text(
          '${l10n.purchasesTotal}: ${vat.currency.formatMinor(_total())}',
          key: const ValueKey('receipt-total'),
        ),
      ],
    );
  }

  List<Widget> _lineFields(
    BuildContext context,
    _Line l,
    _VatContext vat,
    VoidCallback refresh,
  ) {
    final l10n = context.l10n;
    return [
      const FormGap(),
      Row(
        children: [
          Expanded(
            child: Text(
              l10n.purchaseReceiptLine(_lines.indexOf(l) + 1),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          if (_lines.length > 1)
            IconButton(
              key: ValueKey('receipt-remove-${l.id}'),
              tooltip: l10n.purchaseReceiptRemoveLine,
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () {
                _lines.remove(l);
                refresh();
              },
            ),
        ],
      ),
      AppTextField(
        key: ValueKey('receipt-desc-${l.id}'),
        controller: _fields['desc-${l.id}'],
        label: l10n.purchasesDescription,
        maxLength: 500,
      ),
      AppTextField(
        key: ValueKey('receipt-gross-${l.id}'),
        controller: _fields['gross-${l.id}'],
        fieldKey: 'gross-${l.id}',
        label: l10n.purchasesGross,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => refresh(),
      ),
      if (vat.percents.isNotEmpty)
        ..._rateFields(l10n, l, vat.percents, refresh),
      const FormGap.small(),
      DropdownButtonFormField<String>(
        key: ValueKey('receipt-purpose-${l.id}'),
        initialValue: l.purpose,
        isExpanded: true,
        decoration: InputDecoration(labelText: l10n.purchasesPurpose),
        items: [
          for (final p in purchasePurposes)
            DropdownMenuItem(
              value: p,
              child: Text(purchasePurposeLabel(l10n, p)),
            ),
        ],
        onChanged: (v) => l.purpose = v ?? l.purpose,
      ),
      const FormGap.small(),
      PurchasePlaceField(
        fieldKey: 'receipt-place-${l.id}',
        workspaceId: widget.workspaceId,
        value: l.place,
        onChanged: (p) => l.place = p,
      ),
    ];
  }

  List<Widget> _rateFields(
    AppLocalizations l10n,
    _Line l,
    List<double> percents,
    VoidCallback refresh,
  ) => [
    const FormGap.small(),
    DropdownButtonFormField<double>(
      key: ValueKey('receipt-rate-${l.id}'),
      initialValue: l.rate,
      decoration: InputDecoration(labelText: l10n.expenseVatRate),
      items: [
        DropdownMenuItem(value: 0, child: Text(l10n.expenseVatNone)),
        for (final p in percents)
          DropdownMenuItem(
            value: p,
            child: Text(expenseVatPercentLabel(l10n, p)),
          ),
      ],
      onChanged: (v) {
        l.rate = v ?? 0;
        if (l.rate > 0 && _fields.text('share-${l.id}').isEmpty) {
          _fields['share-${l.id}'].text = '100';
        }
        refresh();
      },
    ),
    if (l.rate > 0)
      AppTextField(
        key: ValueKey('receipt-share-${l.id}'),
        controller: _fields['share-${l.id}'],
        fieldKey: 'share-${l.id}',
        label: l10n.expenseVatDeductible,
        helper: l10n.expenseVatDeductibleHint,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
  ];
}
