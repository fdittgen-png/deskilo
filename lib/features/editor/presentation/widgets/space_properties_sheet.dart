// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import '../../../../core/format/cents.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';

/// What the properties sheet hands back when saved.
typedef SpaceProperties = ({String name, bool bookable, int priceCents});

/// #1154 — ONE properties sheet for a whole-bookable space. The office
/// sheet (0057) and the desk sheet (0059) were the same sixty lines with
/// two words swapped; a field added to one was forgotten on the other.
/// Returns null when dismissed without saving. [keyPrefix] keeps the
/// two surfaces' widget keys distinct (`office-price-field`,
/// `desk-bookable-switch`…).
Future<SpaceProperties?> showSpacePropertiesSheet(
  BuildContext context, {
  required String title,
  required String nameLabel,
  required String name,
  required bool bookable,
  required int priceCents,
  required String keyPrefix,
}) async {
  final l10n = AppLocalizations.of(context);
  var isBookable = bookable;
  final nameField = TextEditingController(text: name);
  // Price per half-day — the 0050 level shape.
  final price = TextEditingController(
    text: priceCents == 0 ? '' : centsToMajor(priceCents),
  );
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: StatefulBuilder(
        builder: (context, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              key: ValueKey('$keyPrefix-name-field'),
              controller: nameField,
              decoration: InputDecoration(labelText: nameLabel),
            ),
            SwitchListTile(
              key: ValueKey('$keyPrefix-bookable-switch'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n?.editorBookableAsWhole ?? 'Bookable as a whole',
              ),
              value: isBookable,
              onChanged: (v) => setSheetState(() => isBookable = v),
            ),
            TextField(
              key: ValueKey('$keyPrefix-price-field'),
              controller: price,
              enabled: isBookable,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n?.levelPriceLabel ?? 'Price per half-day',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n?.commonSave ?? 'Save'),
            ),
          ],
        ),
      ),
    ),
  );
  if (saved != true) return null;
  final trimmed = nameField.text.trim();
  return (
    name: trimmed.isEmpty ? name : trimmed,
    bookable: isBookable,
    priceCents: parseCentsInput(price.text) ?? 0,
  );
}
