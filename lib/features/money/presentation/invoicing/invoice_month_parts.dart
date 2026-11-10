// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-e -- the small parts of the Invoice-the-month review: the business
// notice, the select-all line and the words of what is missing.
import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../widgets/invoice_missing_sales_tax.dart';

/// The words of the missing essentials [keys], as the issue form says them.
String monthMissingWords(AppLocalizations l10n, List<String> keys) =>
    [for (final k in keys) invoiceMissingLabel(l10n, k)].join(', ');

/// The business's own missing essentials, said once with one Fix.
class MonthBusinessNotice extends StatelessWidget {
  const MonthBusinessNotice({
    super.key,
    required this.text,
    required this.fixLabel,
    required this.onFix,
  });

  final String text;
  final String fixLabel;
  final VoidCallback? onFix;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: const ValueKey('invoice-month-business-notice'),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: AppRadius.mdAll,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: scheme.onTertiaryContainer,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: scheme.onTertiaryContainer),
              ),
            ),
            FilledButton.tonal(
              key: const ValueKey('invoice-month-business-fix'),
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: onFix,
              child: Text(fixLabel),
            ),
          ],
        ),
      ),
    );
  }
}

/// The select-all line: one control, the box only shows its state (the same
/// shape as the kit's [SelectRow]).
class MonthAllRow extends StatelessWidget {
  const MonthAllRow({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;

  /// true: every free customer ticked; false: none; null: some.
  final bool? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    checked: value ?? false,
    mixed: value == null,
    label: label,
    excludeSemantics: true,
    // recorder-key-exempt: the semantics of the row; its InkWell carries the key.
    onTap: onTap,
    child: InkWell(
      key: const ValueKey('invoice-month-all-toggle'),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            IgnorePointer(
              // recorder-key-exempt: a picture of the line's state
              child: Checkbox(tristate: true, value: value, onChanged: (_) {}),
            ),
            Text(label),
          ],
        ),
      ),
    ),
  );
}
