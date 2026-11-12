// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3278 — the birthday row of the personal information form. It is part of
// the ONE identity form's save (the host sends it with the rest, like the
// workspace's own questions), says who can read it, and takes a day from a
// calendar bounded by what the table accepts (1900 to today), so a refused
// value cannot be typed.
import 'package:flutter/material.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_date_picker.dart';

/// Shows [value] and edits it through the platform date picker.
class BirthdayField extends StatelessWidget {
  const BirthdayField({
    super.key,
    required this.value,
    required this.today,
    required this.onChanged,
    this.enabled = true,
  });

  final DateTime? value;

  /// The workspace clock's today: the latest day a birthday can be.
  final DateTime today;
  final ValueChanged<DateTime?> onChanged;
  final bool enabled;

  Future<void> _pick(BuildContext context) async {
    final latest = DateTime(today.year, today.month, today.day);
    final picked = await showAppDatePicker(
      context: context,
      initialDate: value ?? DateTime(latest.year - 30, latest.month, latest.day),
      firstDate: DateTime(1900),
      lastDate: latest,
      helpText: context.l10n.personalBirthday,
    );
    if (picked != null) {
      onChanged(DateTime(picked.year, picked.month, picked.day));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = value == null
        ? l10n.purchasesPickDate
        : appFormatOf(context).dates(DateShape.longDate).format(value!);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: l10n.labelWithValue(l10n.personalBirthday, text),
              excludeSemantics: true,
              child: InkWell(
                key: const ValueKey('personal-info-birthday'),
                onTap: enabled ? () => _pick(context) : null,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.personalBirthday,
                    helperText: l10n.personalBirthdayHelp,
                    helperMaxLines: 4,
                    suffixIcon: const Icon(Icons.cake_outlined),
                  ),
                  child: Text(text),
                ),
              ),
            ),
          ),
          if (value != null)
            IconButton(
              key: const ValueKey('personal-info-birthday-clear'),
              tooltip: l10n.personalBirthdayClear,
              icon: const Icon(Icons.clear),
              // A 48 dp target, as every touch target here.
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: enabled ? () => onChanged(null) : null,
            ),
        ],
      ),
    );
  }
}
