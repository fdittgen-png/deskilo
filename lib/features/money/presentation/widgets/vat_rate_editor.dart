// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/vat_catalogue.dart';
import '../../domain/vat_rate.dart';

/// One editable row of the VAT rate editor. The controllers live here so a
/// rename never rebuilds into a lost cursor.
class VatRateDraft {
  VatRateDraft(this.rate)
    : label = TextEditingController(text: rate.label),
      percent = TextEditingController(
        text: rate.percent == 0 ? '' : vatPercentText(rate.percent),
      ),
      group = rate.group,
      validFrom = rate.validFrom,
      validTo = rate.validTo,
      supersedesId = rate.supersedesId,
      exemption = TextEditingController(text: rate.exemptionReason);

  final VatRate rate;
  final TextEditingController label;
  final TextEditingController percent;

  /// The fiscal group; the category and the outside-base rule follow it at
  /// save time.
  VatGroup group;

  /// The version window and the family link; a change by law closes this
  /// one and opens the next.
  String validFrom;
  String? validTo;
  String supersedesId;
  final TextEditingController exemption;

  bool get isDated => validFrom != '1900-01-01' || validTo != null;

  void dispose() {
    label.dispose();
    percent.dispose();
    exemption.dispose();
  }
}

/// '20', '5.5' — what the owner typed, not '20.0'.
String vatPercentText(double percent) => percent == percent.roundToDouble()
    ? percent.toStringAsFixed(0)
    : percent.toString();

/// The group's name in the reader's language.
String _vatGroupName(AppLocalizations l10n, VatGroup g) => switch (g) {
  VatGroup.standard => l10n.vatGroupStandard,
  VatGroup.intermediate => l10n.vatGroupIntermediate,
  VatGroup.reduced => l10n.vatGroupReduced,
  VatGroup.superReduced => l10n.vatGroupSuperReduced,
  VatGroup.zero => l10n.vatGroupZero,
  VatGroup.exempt => l10n.vatGroupExempt,
  VatGroup.notSubject => l10n.vatGroupNotSubject,
  VatGroup.deposit => l10n.vatGroupDeposit,
  VatGroup.excise => l10n.vatGroupExcise,
};

/// Asks for the new value of a rate and the day it takes effect; true when
/// the owner confirmed. [index] names the cancel button of that row.
Future<bool?> showVatChangeByLawDialog(
  BuildContext context, {
  required int index,
  required TextEditingController percent,
  required TextEditingController date,
}) {
  final l10n = context.l10n;
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: Text(l10n.vatChangeByLaw),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.vatChangeByLawExplainer,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const ValueKey('vat-law-percent'),
            controller: percent,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l10n.vatNewPercent),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const ValueKey('vat-law-date'),
            controller: date,
            decoration: InputDecoration(labelText: l10n.vatEffectiveDate),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: ValueKey('vat-cancel-$index'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('vat-law-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.commonSave),
        ),
      ],
    ),
  );
}

/// What a rate row can do; the editor's state owns every effect.
class VatRateRowActions {
  const VatRateRowActions({
    required this.onGroup,
    required this.onChangeByLaw,
    required this.onDefault,
    required this.onRemove,
  });

  final ValueChanged<VatGroup?> onGroup;
  final VoidCallback onChangeByLaw;
  final VoidCallback onDefault;
  final VoidCallback onRemove;
}

/// One rate: its label, percent, group (when groups are on), the change by
/// law (when the history is on), the default star and the remove button.
class VatRateRow extends StatelessWidget {
  const VatRateRow({
    super.key,
    required this.index,
    required this.draft,
    required this.isDefault,
    required this.options,
    required this.actions,
  });

  final int index;
  final VatRateDraft draft;
  final bool isDefault;

  /// Whether the group picker and the change-by-law button show.
  final ({bool groupsOn, bool historyOn}) options;
  final VatRateRowActions actions;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: ValueKey('vat-rate-label-$index'),
              controller: draft.label,
              maxLength: 60,
              decoration: InputDecoration(
                labelText: l10n.vatRateLabelField,
                counterText: '',
                suffixIcon: HelpDot(
                  l10n.helpTopicVat,
                  anchor: HelpAnchor.moneyVatRates,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 112,
            child: TextField(
              key: ValueKey('vat-rate-percent-$index'),
              controller: draft.percent,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(labelText: l10n.vatRatePercentField),
            ),
          ),
          if (options.groupsOn) ...[
            const SizedBox(width: AppSpacing.sm),
            SizedBox(width: 150, child: _groupPicker(l10n)),
          ],
          // The new value from a date, as a new version.
          if (options.historyOn)
            IconButton(
              key: ValueKey('vat-rate-law-$index'),
              tooltip: l10n.vatChangeByLaw,
              icon: const Icon(Icons.update_outlined),
              onPressed: actions.onChangeByLaw,
            ),
          // A star rather than a radio: it reads as "this is the one" at a
          // glance and stays one tap either way.
          IconButton(
            key: ValueKey('vat-rate-default-$index'),
            tooltip: l10n.vatRateDefaultTooltip,
            icon: Icon(
              isDefault ? Icons.star : Icons.star_border,
              color: isDefault ? Theme.of(context).colorScheme.primary : null,
            ),
            onPressed: actions.onDefault,
          ),
          IconButton(
            key: ValueKey('vat-rate-remove-$index'),
            tooltip: l10n.vatRateRemoveTooltip,
            icon: const Icon(Icons.delete_outline),
            onPressed: actions.onRemove,
          ),
        ],
      ),
    );
  }

  Widget _groupPicker(AppLocalizations l10n) =>
      DropdownButtonFormField<VatGroup>(
        key: ValueKey('vat-rate-group-$index'),
        initialValue: draft.group,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: l10n.vatGroupLabel,
          // The group is its own documented object, and its own paragraph
          // in the guide.
          suffixIcon: HelpDot(
            l10n.helpTopicVat,
            anchor: HelpAnchor.moneyVatGroups,
          ),
        ),
        items: [
          for (final g in VatGroup.values)
            DropdownMenuItem(value: g, child: Text(_vatGroupName(l10n, g))),
        ],
        onChanged: actions.onGroup,
      );
}

/// The version windows, one line for each rate that has one.
class VatRateValidityLines extends StatelessWidget {
  const VatRateValidityLines({super.key, required this.drafts});

  final List<VatRateDraft> drafts;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, draft) in drafts.indexed)
          if (draft.isDated)
            Padding(
              key: ValueKey('vat-rate-validity-$index'),
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                [
                  draft.label.text,
                  if (draft.validFrom != '1900-01-01')
                    '${l10n.vatSince} ${draft.validFrom}',
                  if (draft.validTo != null)
                    '${l10n.vatUntil} ${draft.validTo}',
                ].join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
      ],
    );
  }
}

/// With groups on: the exemption reason of every exempt or out-of-scope
/// rate, then the country's examples of each group.
class VatGroupSection extends StatelessWidget {
  const VatGroupSection({
    super.key,
    required this.drafts,
    required this.countryCode,
  });

  final List<VatRateDraft> drafts;
  final String countryCode;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, draft) in drafts.indexed)
          if (draft.group.category == 'E' || draft.group.category == 'O')
            Padding(
              key: ValueKey('vat-rate-exemption-$index'),
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: TextField(
                controller: draft.exemption,
                decoration: InputDecoration(
                  labelText:
                      '${draft.label.text} · ${l10n.vatExemptionReasonField}',
                ),
              ),
            ),
        Padding(
          key: const ValueKey('vat-group-examples'),
          padding: const EdgeInsets.only(
            top: AppSpacing.sm,
            bottom: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.vatGroupExamples,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (final e in vatGroupExamples(countryCode))
                Text(
                  '${_vatGroupName(l10n, e.group)} — ${e.example}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
