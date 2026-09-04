// SPDX-License-Identifier: 0BSD
//
// #869 — the owner's control over where the recipient is printed.
//
// It lives in its own file rather than in the template sheet because
// that sheet is at its length budget, and because the choice is about
// the SHEET the invoice is printed on, not about the bands: it applies
// whether or not the workspace writes its own template.
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/address_window.dart';

/// Picks the window convention, with `null` meaning "follow the
/// country" — the option that must stay reachable, since the two
/// conventions put the address on opposite sides of the sheet and a
/// silent default would post half the invoices to the wrong window.
class AddressWindowField extends StatelessWidget {
  const AddressWindowField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.countryCode,
  });

  final AddressWindow? value;
  final ValueChanged<AddressWindow?> onChanged;

  /// Only used to name what "follow the country" resolves to right now,
  /// so the owner can see the effect without saving.
  final String countryCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final resolved = addressWindowForCountry(countryCode);
    String labelOf(AddressWindow window) => switch (window) {
          AddressWindow.left => l10n?.addressWindowLeft ?? 'Left (DIN 5008)',
          AddressWindow.right => l10n?.addressWindowRight ?? 'Right (French)',
          AddressWindow.off => l10n?.addressWindowOff ?? 'No window',
        };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n?.addressWindowTitle ?? 'Address window',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n?.addressWindowSubtitle ??
              'Where the recipient is printed so it shows through a '
                  'window envelope. The address field is 85 × 45 mm, '
                  '45 mm from the top of the sheet.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String>(
          key: const ValueKey('invoice-address-window'),
          initialValue: value == null ? '' : addressWindowWire(value!),
          items: [
            DropdownMenuItem(
              value: '',
              child: Text(
                '${l10n?.addressWindowCountry ?? 'Follow the country'}'
                ' — ${labelOf(resolved)}',
              ),
            ),
            for (final window in AddressWindow.values)
              DropdownMenuItem(
                value: addressWindowWire(window),
                child: Text(labelOf(window)),
              ),
          ],
          onChanged: (wire) => onChanged(
              wire == null || wire.isEmpty ? null : addressWindowFromWire(wire)),
        ),
      ],
    );
  }
}
