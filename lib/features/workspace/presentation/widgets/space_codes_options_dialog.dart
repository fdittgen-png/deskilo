// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/space_codes_pdf.dart';

/// What the dialog pops: card size, the barcode's own size (#596),
/// and the selected info entries.
typedef SpaceCodesOptions = ({
  SpaceCardSize size,
  SpaceQrSize qrSize,
  Set<SpaceCardInfo> info,
});

/// #584/#596 — the space-card export options: card size (S/M/L), the
/// QR code's own size (S/M/L, independent of the card), and which
/// information rides each card. Pops the choices, or null on cancel;
/// defaults are the historical card (medium/medium, all info).
class SpaceCodesOptionsDialog extends StatefulWidget {
  const SpaceCodesOptionsDialog({super.key});

  @override
  State<SpaceCodesOptionsDialog> createState() =>
      _SpaceCodesOptionsDialogState();
}

class _SpaceCodesOptionsDialogState extends State<SpaceCodesOptionsDialog> {
  SpaceCardSize _size = SpaceCardSize.medium;
  SpaceQrSize _qrSize = SpaceQrSize.medium;
  final Set<SpaceCardInfo> _info = {...SpaceCardInfo.values};

  String _sizeLabel(AppLocalizations? l10n, SpaceCardSize size) =>
      switch (size) {
        SpaceCardSize.small => l10n?.spaceCardSizeSmall ?? 'Small',
        SpaceCardSize.medium => l10n?.spaceCardSizeMedium ?? 'Medium',
        SpaceCardSize.large => l10n?.spaceCardSizeLarge ?? 'Large',
      };

  String _qrSizeLabel(AppLocalizations? l10n, SpaceQrSize size) =>
      switch (size) {
        SpaceQrSize.small => l10n?.spaceCardSizeSmall ?? 'Small',
        SpaceQrSize.medium => l10n?.spaceCardSizeMedium ?? 'Medium',
        SpaceQrSize.large => l10n?.spaceCardSizeLarge ?? 'Large',
      };

  String _infoLabel(AppLocalizations? l10n, SpaceCardInfo info) =>
      switch (info) {
        SpaceCardInfo.workspace => l10n?.spaceCardInfoWorkspace ?? 'Workspace',
        SpaceCardInfo.level => l10n?.spaceKindLevel ?? 'Level',
        SpaceCardInfo.room => l10n?.spaceKindOffice ?? 'Office',
        SpaceCardInfo.table => l10n?.spaceKindDesk ?? 'Desk',
        SpaceCardInfo.chair => l10n?.spaceKindSeat ?? 'Seat',
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n?.spaceCodesTitle ?? 'Space QR codes (PDF)'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n?.spaceCardSizeLabel ?? 'Card size'),
            const SizedBox(height: 4),
            SegmentedButton<SpaceCardSize>(
              segments: [
                for (final size in SpaceCardSize.values)
                  ButtonSegment(
                    value: size,
                    label: Text(
                      _sizeLabel(l10n, size),
                      key: ValueKey('space-card-size-${size.name}'),
                    ),
                  ),
              ],
              selected: {_size},
              onSelectionChanged: (selection) =>
                  setState(() => _size = selection.first),
            ),
            const SizedBox(height: 16),
            Text(l10n?.spaceQrSizeLabel ?? 'QR code size'),
            const SizedBox(height: 4),
            SegmentedButton<SpaceQrSize>(
              segments: [
                for (final size in SpaceQrSize.values)
                  ButtonSegment(
                    value: size,
                    label: Text(
                      _qrSizeLabel(l10n, size),
                      key: ValueKey('space-qr-size-${size.name}'),
                    ),
                  ),
              ],
              selected: {_qrSize},
              onSelectionChanged: (selection) =>
                  setState(() => _qrSize = selection.first),
            ),
            const SizedBox(height: 16),
            Text(l10n?.spaceCardInfoLabel ?? 'Information on the card'),
            for (final info in SpaceCardInfo.values)
              CheckboxListTile(
                key: ValueKey('space-card-info-${info.wire}'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(_infoLabel(l10n, info)),
                value: _info.contains(info),
                onChanged: (checked) => setState(() {
                  checked == true ? _info.add(info) : _info.remove(info);
                }),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
        FilledButton(
          key: const ValueKey('space-codes-export'),
          onPressed: () => Navigator.of(context).pop(
              (size: _size, qrSize: _qrSize, info: Set.of(_info))),
          child: Text(l10n?.commonSave ?? 'Save'),
        ),
      ],
    );
  }
}
